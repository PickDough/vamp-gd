extends Node

## Runs or lists gspec specs for the VS Code test explorer (tools/vscode-gspec).
##
## Arguments after [code]--[/code]:
##   --list           report every example without running it
##   --filter TEXT    only run examples whose full description contains TEXT
##   res://..._spec.gd  limit the run (or list) to these files; default is all of res://spec

const SPEC_DIR := "res://spec"


func _ready() -> void:
	var list_only := false
	var filter := ""
	var files: Array[String] = []

	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--list":
				list_only = true
			"--filter":
				i += 1
				filter = args[i]
			_:
				files.append(args[i])
		i += 1

	var runner := SpecRunner.new(SpecJsonFormatter.new())
	if files.is_empty():
		runner.discover(SPEC_DIR)
	else:
		for file in files:
			runner.add_spec_file(file)

	if list_only:
		_list(runner._spec_files)
		get_tree().quit(0)
		return

	if not filter.is_empty():
		runner.set_filter(filter)
	var success: bool = await runner.run()
	get_tree().quit(0 if success else 1)


func _list(files: Array[String]) -> void:
	for file in files:
		var script := load(file) as GDScript
		if script == null or not script.can_instantiate():
			SpecJsonFormatter.emit({ "event": "load_error", "file": file })
			continue

		var instance: Object = script.new()
		var spec := instance as GSpec
		if spec == null:
			continue
		spec._build_tree()
		_list_group(file, spec._get_root_group())
		spec.clear()


func _list_group(file: String, group: SpecGroup) -> void:
	for child in group.children:
		if child is SpecGroup:
			_list_group(file, child as SpecGroup)
		elif child is SpecExample:
			var example := child as SpecExample
			SpecJsonFormatter.emit({
				"event": "test",
				"id": SpecJsonFormatter.example_id(file, example),
				"file": file,
				"groups": _group_names(example.group as SpecGroup),
				"name": example.description,
			})


func _group_names(group: SpecGroup) -> Array[String]:
	var names: Array[String] = []
	while group != null and not group.description.is_empty():
		names.push_front(group.description)
		group = group.parent

	return names
