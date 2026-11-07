class_name SpecJsonFormatter
extends SpecBaseFormatter

## Reports gspec results as JSON lines for the VS Code test explorer (tools/vscode-gspec).
##
## Every line starts with [constant MARKER] so the extension can pick events out of the
## engine's own output.

const MARKER := "@@GSPEC@@"

var _current_file: String = ""


static func emit(event: Dictionary) -> void:
	print(MARKER + JSON.stringify(event))


static func example_id(file: String, example: SpecExample) -> String:
	return "%s::%s" % [file, example.full_description()]


func on_spec_file_start(file_path: String) -> void:
	_current_file = file_path
	emit({ "event": "file", "file": file_path })


func on_example_complete(example: SpecExample) -> void:
	var status: String = SpecExample.Status.keys()[example.status]
	emit({
		"event": "result",
		"id": example_id(_current_file, example),
		"status": status.to_lower(),
		"duration_ms": example.duration_ms,
		"failures": example.failures.map(func(failure: SpecFailure) -> String: return failure.message),
	})


func on_suite_end(
	total: int,
	passed: int,
	failed: int,
	pending: int,
	errors: int,
	duration_ms: float,
	_all_failures: Array,
) -> void:
	emit({
		"event": "done",
		"total": total,
		"passed": passed,
		"failed": failed,
		"pending": pending,
		"errors": errors,
		"duration_ms": duration_ms,
	})
