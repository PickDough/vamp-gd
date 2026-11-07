#!/usr/bin/env python3
"""Lints this project's GDScript against CONTRIBUTING.md.

Two passes:
  engine  Redot compiles every script with the GDScript warnings below raised to errors (through a temporary
          override.cfg), catching untyped, unsafe, unused and shadowed code.
  style   line-based checks for the rules Redot doesn't know: naming, file order, formatting and hygiene.

Usage:
  python3 tools/lint/lint.py                  lint the whole project
  python3 tools/lint/lint.py FILE.gd ...      only report findings in these files
  python3 tools/lint/lint.py --no-engine      skip the engine pass (faster)

Findings print as `path:line:column: rule: message`; the exit code is 1 when there are any.
Silence a line with a trailing `# lint-ignore: rule` (comma-separate several rules).
"""

import argparse
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
REDOT = os.environ.get("REDOT", "/Applications/Redot_mono.app/Contents/MacOS/Redot")
CHECK_SCENE = "res://tools/lint/check_scripts.tscn"
ENGINE_MARKER = "@@LINT@@"
# The check scene quits by itself; the limit only stops Redot if a script error prevents that.
ENGINE_FRAME_LIMIT = 600

SKIPPED_DIRECTORIES = {"addons", ".godot", ".git", "node_modules", "reports"}
# Scripts whose job is to print: test reporters and the engine-check runner.
PRINT_ALLOWED = ("spec/support/", "tools/lint/")

MAX_LINE_LENGTH = 120
TAB_WIDTH = 4
MAX_FUNCTION_LINES = 10
# Specs are long single scenarios on purpose.
FUNCTION_LENGTH_EXEMPT = ("spec/",)

# GDScript warnings the engine pass raises to errors. The project keeps them as warnings so the game still runs.
ENGINE_WARNINGS = [
    "untyped_declaration",
    "unsafe_property_access",
    "unsafe_method_access",
    "unsafe_cast",
    "unsafe_call_argument",
    "unsafe_nullable_access",
    "unused_variable",
    "unused_local_constant",
    "unused_private_class_variable",
    "unused_parameter",
    "unused_signal",
    "shadowed_variable",
    "shadowed_variable_base_class",
    "shadowed_global_identifier",
    "unassigned_variable",
    "unassigned_variable_op_assign",
    "unreachable_code",
    "standalone_expression",
    "standalone_ternary",
    "integer_division",
    "narrowing_conversion",
    "incompatible_ternary",
    "static_called_on_instance",
    "redundant_await",
    "inference_on_variant",
    "get_node_default_without_onready",
    "onready_with_export",
]

SNAKE_CASE = re.compile(r"^_?[a-z][a-z0-9]*(_[a-z0-9]+)*$")
PASCAL_CASE = re.compile(r"^[A-Z][A-Za-z0-9]*$")
CONSTANT_CASE = re.compile(r"^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$")

ENGINE_CALLBACKS = [
    "_init",
    "_enter_tree",
    "_ready",
    "_process",
    "_physics_process",
]
OTHER_VIRTUALS = {
    "_exit_tree", "_input", "_unhandled_input", "_unhandled_key_input", "_shortcut_input", "_gui_input",
    "_notification", "_draw", "_get_configuration_warnings", "_to_string", "_get", "_set", "_get_property_list",
    "_validate_property", "_property_can_revert", "_property_get_revert", "_integrate_forces", "_can_drop_data",
    "_drop_data", "_get_drag_data", "_make_custom_tooltip", "_has_point", "_static_init",
}

# Order of top-level declarations; see "File layout" in CONTRIBUTING.md.
ORDER = [
    "header annotation",
    "class name",
    "extends",
    "uses",
    "signal",
    "enum",
    "constant",
    "static variable",
    "exported variable",
    "public variable",
    "private variable",
    "onready variable",
    "static init",
    "static function",
    "engine callback",
    "other engine callback",
    "public method",
    "private method",
    "inner class",
]


class Finding:
    def __init__(self, path, line, column, rule, message):
        self.path, self.line, self.column, self.rule, self.message = path, line, column, rule, message

    def __str__(self):
        return f"{self.path}:{self.line}:{self.column}: {self.rule}: {self.message}"


def project_scripts():
    for path in sorted(ROOT.rglob("*.gd")):
        relative = path.relative_to(ROOT)
        if not SKIPPED_DIRECTORIES.intersection(relative.parts):
            yield relative


# --- engine pass ---------------------------------------------------------------------------------------------


def engine_findings():
    override = ROOT / "override.cfg"
    if override.exists():
        sys.exit(f"{override} already exists; remove it before linting.")

    lines = ["[debug]", ""] + [f"gdscript/warnings/{name}=2" for name in ENGINE_WARNINGS]
    override.write_text("\n".join(lines) + "\n")
    try:
        subprocess.run([REDOT, "--headless", "--path", str(ROOT), "--import"], capture_output=True, timeout=300)
        result = subprocess.run(
            [REDOT, "--headless", "--path", str(ROOT), "--quit-after", str(ENGINE_FRAME_LIMIT), CHECK_SCENE],
            capture_output=True,
            text=True,
            timeout=300,
        )
    except FileNotFoundError:
        sys.exit(f"Redot not found at {REDOT}; set the REDOT environment variable.")
    finally:
        override.unlink(missing_ok=True)

    return parse_engine_output(result.stdout + "\n" + result.stderr)


ENGINE_ERROR = re.compile(r"SCRIPT ERROR: (?:Parse|Compile) Error: (.*)")
ENGINE_LOCATION = re.compile(r"at: GDScript::reload \(res://(.+?):(\d+)\)")
ENGINE_NOISE = ("Failed to compile depended scripts", "Could not parse global class", "Could not resolve class")


def parse_engine_output(output):
    findings, seen = [], set()
    pending = None
    for line in output.splitlines():
        error = ENGINE_ERROR.search(line)
        if error:
            pending = error.group(1)
            continue
        location = ENGINE_LOCATION.search(line)
        if location and pending is not None:
            message = pending.replace(" (Warning treated as error.)", "")
            pending = None
            if any(noise in message for noise in ENGINE_NOISE):
                continue
            key = (location.group(1), int(location.group(2)), message)
            if key not in seen:
                seen.add(key)
                findings.append(Finding(location.group(1), int(location.group(2)), 1, "engine", message))
    return findings


# --- style pass ----------------------------------------------------------------------------------------------


def split_code_and_comment(lines):
    """Per line: the code with string contents blanked out, and the comment text (or None)."""
    result = []
    in_triple = None
    for raw in lines:
        code, comment, i = [], None, 0
        while i < len(raw):
            if in_triple:
                end = raw.find(in_triple, i)
                if end < 0:
                    code.append(" " * (len(raw) - i))
                    i = len(raw)
                    break
                code.append(" " * (end - i) + in_triple)
                i = end + 3
                in_triple = None
                continue
            char = raw[i]
            if char == "#":
                comment = raw[i:]
                break
            if raw.startswith('"""', i) or raw.startswith("'''", i):
                in_triple = raw[i:i + 3]
                code.append(in_triple)
                i += 3
                continue
            if char in "\"'":
                end = i + 1
                while end < len(raw) and raw[end] != char:
                    end += 2 if raw[end] == "\\" else 1
                code.append(char + " " * (min(end, len(raw)) - i - 1) + (char if end < len(raw) else ""))
                i = end + 1
                continue
            code.append(char)
            i += 1
        result.append(("".join(code), comment))
    return result


def visual_length(line):
    return len(line.expandtabs(TAB_WIDTH))


def ignored_rules(comment):
    if not comment:
        return set()
    match = re.search(r"lint-ignore:\s*([\w\-, ]+)", comment)
    return {rule.strip() for rule in match.group(1).split(",")} if match else set()


def to_snake_case(name):
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", "_", name).lower()


class StyleChecker:
    def __init__(self, path, text, public_uses):
        self.path = path
        self.lines = text.split("\n")
        self.parsed = split_code_and_comment(self.lines)
        self.public_uses = public_uses
        self.findings = []

    def report(self, line_index, column, rule, message):
        if rule not in ignored_rules(self.parsed[line_index][1]):
            self.findings.append(Finding(str(self.path), line_index + 1, column + 1, rule, message))

    def run(self):
        self.check_file_name()
        for index, (raw, (code, comment)) in enumerate(zip(self.lines, self.parsed)):
            self.check_formatting(index, raw, code, comment)
            self.check_hygiene(index, code)
            self.check_names(index, code)
        self.check_order_and_spacing()
        self.check_function_length()
        self.check_private_members()
        return self.findings

    # File and class names.
    def check_file_name(self):
        stem = self.path.stem
        if not SNAKE_CASE.match(stem):
            self.report(0, 0, "file-name", f"file name '{stem}' should be snake_case")
        for index, (code, _comment) in enumerate(self.parsed):
            match = re.match(r"(class_name|struct_name|trait_name)\s+(\w+)", code)
            if match:
                name = match.group(2)
                if not PASCAL_CASE.match(name):
                    self.report(index, 0, "class-name", f"'{name}' should be PascalCase")
                elif to_snake_case(name) != stem:
                    self.report(index, 0, "file-name", f"file should be named '{to_snake_case(name)}.gd' after {name}")
                return

    # Formatting.
    def check_formatting(self, index, raw, code, comment):
        if visual_length(raw) > MAX_LINE_LENGTH:
            self.report(index, MAX_LINE_LENGTH, "line-length", f"line is {visual_length(raw)} characters (max {MAX_LINE_LENGTH})")
        if raw != raw.rstrip():
            self.report(index, len(raw.rstrip()), "trailing-whitespace", "trailing whitespace")
        indent = raw[: len(raw) - len(raw.lstrip())]
        if " " in indent and raw.strip():
            self.report(index, 0, "indentation", "indent with tabs")
        for match in re.finditer(r"&&|\|\||(?<![=!<>])!(?!=)", code):
            word = {"&&": "and", "||": "or"}.get(match.group(), "not")
            self.report(index, match.start(), "boolean-operator", f"use '{word}' instead of '{match.group()}'")
        for match in re.finditer(r"(?<![\w.])\.\d|(?<![\w.])\d+\.(?![\d\w.])", code):
            self.report(index, match.start(), "number-format", f"write '{match.group()}' with digits on both sides of the point")
        for match in re.finditer(r"(?<![&^\w])'", code):
            literal_end = code.find("'", match.start() + 1)
            if literal_end > 0 and '"' not in raw[match.start():literal_end]:
                self.report(index, match.start(), "quotes", "use double quotes")
            break
        if comment is not None:
            self.check_comment(index, raw, code, comment)

    def check_comment(self, index, raw, code, comment):
        column = len(raw) - len(comment)
        if comment.startswith(("#region", "#endregion")) or re.fullmatch(r"#\s*lint-ignore:.*", comment.strip()):
            return
        if not (code.strip() == "" and column == 0 and comment.startswith("##") and index < self.first_member_line()):
            self.report(index, column, "comment", "only the script's doc comment is allowed; say it through names instead")
        elif comment.strip("#") and not comment.lstrip("#").startswith(" "):
            self.report(index, column, "comment", "put a space after '##'")

    def first_member_line(self):
        if not hasattr(self, "_first_member_line"):
            members = [index for index, kind, _name in self.declarations() if ORDER.index(kind) > ORDER.index("uses")]
            self._first_member_line = members[0] if members else len(self.lines)
        return self._first_member_line

    # Hygiene.
    def check_hygiene(self, index, code):
        path = str(self.path)
        if not path.startswith(PRINT_ALLOWED):
            match = re.search(r"\b(print|prints|printt|printraw|print_debug|print_rich)\(", code)
            if match:
                self.report(index, match.start(), "no-print", "remove debug printing (use push_warning/push_error)")
        match = re.search(r"\bpreload\(\s*\"[^\"]*\.tscn\"", self.lines[index])
        if match:
            self.report(index, match.start(), "no-scene-preload", "load scenes with load() where they're used; preloading them can create load cycles that leave exported properties unset")
        match = re.search(r"\bget_parent\(\)|get_node\(\s*\"\.\.|\$\"?\.\.", code)
        if match:
            self.report(index, match.start(), "no-reaching-up", "don't reach up the tree; take the dependency through setup() or @export")
        if not code.lstrip().startswith("@onready"):
            match = re.search(r"(?<![\w.])get_node\(|(?<![\w\"])\$[\w\"%/]", code)
            if match and not path.startswith("spec/"):
                self.report(index, match.start(), "node-reference", "reference child nodes through a typed @onready variable")
        for match in re.finditer(r"\bself\.(\w+)", code):
            if not self._is_parameter_of_enclosing_function(index, match.group(1)):
                self.report(index, match.start(), "no-self", "drop 'self.' unless it disambiguates")

    def _is_parameter_of_enclosing_function(self, index, name):
        for code, _comment in reversed(self.parsed[: index + 1]):
            match = re.match(r"\s*(static\s+)?func\s+\w+\((.*?)\)", code)
            if match:
                return re.search(rf"(^|,)\s*{re.escape(name)}\b", match.group(2)) is not None
        return False

    # Names of declarations.
    def check_names(self, index, code):
        stripped = code.strip()
        for keyword, pattern, style in (
            (r"(?:static\s+)?func", SNAKE_CASE, "snake_case"),
            ("signal", re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$"), "snake_case"),
            ("enum", PASCAL_CASE, "PascalCase"),
        ):
            match = re.match(rf"{keyword}\s+(\w+)", stripped)
            if match and not pattern.match(match.group(1)):
                self.report(index, 0, "name", f"'{match.group(1)}' should be {style}")
        match = re.match(r"(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?var\s+(\w+)", stripped)
        if match and not SNAKE_CASE.match(match.group(1)):
            self.report(index, 0, "name", f"'{match.group(1)}' should be snake_case")
        match = re.match(r"for\s+(\w+)", stripped)
        if match and not SNAKE_CASE.match(match.group(1)):
            self.report(index, 0, "name", f"'{match.group(1)}' should be snake_case")
        match = re.match(r"const\s+(\w+)\s*(?::[^=]*)?=\s*(.*)", stripped)
        if match:
            name, value = match.groups()
            holds_type = re.match(r"preload\(\s*\"[^\"]*\.gd\"\s*\)|[A-Z]\w*\.[A-Z]\w*\s*$|[A-Z]\w*\s*$", value.strip())
            if holds_type and not re.match(r"[A-Z0-9_]+\s*$", value.strip()):
                if not PASCAL_CASE.match(name):
                    self.report(index, 0, "name", f"'{name}' holds a type, so it should be PascalCase")
            elif not CONSTANT_CASE.match(name):
                self.report(index, 0, "name", f"'{name}' should be CONSTANT_CASE")
        match = re.match(r"enum\s+\w+\s*\{(.*)", stripped)
        if match:
            self.check_enum_members(index)

    def check_enum_members(self, start):
        text = []
        for code, _comment in self.parsed[start:]:
            text.append(code)
            if "}" in code:
                break
        body = " ".join(text)
        body = body[body.index("{") + 1: body.index("}")] if "}" in body else ""
        for member in body.split(","):
            name = member.split("=")[0].strip()
            if name and not CONSTANT_CASE.match(name):
                self.report(start, 0, "name", f"enum member '{name}' should be CONSTANT_CASE")

    # File layout: declaration order and blank lines.
    def declarations(self):
        """Top-level declarations as (line index, kind, name)."""
        result = []
        for index, (code, _comment) in enumerate(self.parsed):
            if not code or code[0] in " \t" or not code.strip():
                continue
            stripped = code.strip()
            kind, name = self.classify(stripped)
            if kind:
                result.append((index, kind, name))
        return result

    def classify(self, stripped):
        if re.match(r"@(tool|icon|static_unload)\b", stripped) and not re.search(r"\bvar\b|\bfunc\b", stripped):
            return "header annotation", None
        match = re.match(r"(class_name|struct_name|trait_name)\s+(\w+)", stripped)
        if match:
            return "class name", match.group(2)
        if stripped.startswith("extends"):
            return "extends", None
        if stripped.startswith("uses"):
            return "uses", None
        match = re.match(r"signal\s+(\w+)", stripped)
        if match:
            return "signal", match.group(1)
        match = re.match(r"enum\s+(\w+)", stripped)
        if match:
            return "enum", match.group(1)
        match = re.match(r"const\s+(\w+)", stripped)
        if match:
            return "constant", match.group(1)
        match = re.match(r"((?:@\w+(?:\([^)]*\))?\s+)*)(static\s+)?var\s+(\w+)", stripped)
        if match:
            annotations, is_static, name = match.groups()
            if is_static:
                return "static variable", name
            if "@onready" in annotations:
                return "onready variable", name
            if "@export" in annotations:
                return "exported variable", name
            return ("private variable" if name.startswith("_") else "public variable"), name
        match = re.match(r"(static\s+)?func\s+(\w+)", stripped)
        if match:
            is_static, name = match.groups()
            if name == "_static_init":
                return "static init", name
            if is_static:
                return ("private method" if name.startswith("_") else "static function"), name
            if name in ENGINE_CALLBACKS:
                return "engine callback", name
            if name in OTHER_VIRTUALS:
                return "other engine callback", name
            return ("private method" if name.startswith("_") else "public method"), name
        match = re.match(r"class\s+(\w+)", stripped)
        if match:
            return "inner class", match.group(1)
        return None, None

    def check_order_and_spacing(self):
        declarations = self.declarations()
        highest = -1
        callback_rank = -1
        for index, kind, name in declarations:
            rank = ORDER.index(kind)
            if rank < highest:
                label = f"{kind} '{name}'" if name else kind
                self.report(index, 0, "order", f"{label} should come before the {ORDER[highest]}s")
            highest = max(highest, rank)
            if kind == "engine callback":
                position = ENGINE_CALLBACKS.index(name)
                if position < callback_rank:
                    self.report(index, 0, "order", f"engine callback '{name}' is out of order ({', '.join(ENGINE_CALLBACKS)})")
                callback_rank = max(callback_rank, position)

        functions = [index for index, kind, _name in declarations if kind in ORDER[ORDER.index("static init"):]]
        for index in functions:
            start = index
            while start > 0 and (self.lines[start - 1].lstrip().startswith("#") or self.lines[start - 1].lstrip().startswith("@")):
                start -= 1
            blank = 0
            while start - blank - 1 >= 0 and not self.lines[start - blank - 1].strip():
                blank += 1
            if start - blank > 0 and blank != 2:
                self.report(index, 0, "blank-lines", f"put two blank lines before a function (found {blank})")

    def check_function_length(self):
        if str(self.path).startswith(FUNCTION_LENGTH_EXEMPT):
            return
        functions = [(index, name) for index, kind, name in self.declarations() if kind in ORDER[ORDER.index("static init"):-1]]
        for index, name in functions:
            body = 0
            for code, _comment in self.parsed[index + 1:]:
                if code.strip() and code[0] not in " \t":
                    break
                body += 1 if code.strip() else 0
            if body > MAX_FUNCTION_LINES:
                self.report(index, 0, "function-length", f"'{name}' has {body} lines (max {MAX_FUNCTION_LINES}); split it or move the logic into its own script or node")

    # Members other scripts don't use should be private.
    def check_private_members(self):
        for index, kind, name in self.declarations():
            if kind not in ("public variable", "public method") or name.startswith("_"):
                continue
            if self.public_uses.get(name, set()) - {str(self.path)}:
                continue
            self.report(index, 0, "private-member", f"'{name}' isn't used by other scripts or scenes; make it private ('_{name}')")


def public_member_uses(scripts):
    """Name → files (other than the declaring one) that mention it: calls through objects, subclasses calling
    inherited members, scenes setting properties, and addon base classes whose methods a script overrides."""
    uses = {}
    sources = [ROOT / path for path in scripts]
    sources += [path for path in ROOT.rglob("*") if path.suffix in (".tscn", ".tres") and ".godot" not in path.parts]
    sources += list((ROOT / "addons").rglob("*.gd"))
    for source in sources:
        relative = str(source.relative_to(ROOT))
        for name in set(re.findall(r"\b([a-z_]\w*)\b", source.read_text(errors="ignore"))):
            uses.setdefault(name, set()).add(relative)
    return uses


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="*", help="only report findings in these .gd files")
    parser.add_argument("--no-engine", action="store_true", help="skip the Redot engine pass")
    args = parser.parse_args()

    scripts = list(project_scripts())
    wanted = {str(pathlib.Path(f).resolve().relative_to(ROOT)) for f in args.files if f.endswith(".gd")}
    if args.files and not wanted:
        return 0

    findings = []
    if not args.no_engine:
        findings += engine_findings()
    uses = public_member_uses(scripts)
    for path in scripts:
        if not wanted or str(path) in wanted:
            findings += StyleChecker(path, (ROOT / path).read_text(), uses).run()

    if wanted:
        findings = [f for f in findings if f.path in wanted]
    findings.sort(key=lambda f: (f.path, f.line, f.column, f.rule))
    for finding in findings:
        print(finding)
    if findings:
        print(f"\n{len(findings)} finding(s).", file=sys.stderr)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
