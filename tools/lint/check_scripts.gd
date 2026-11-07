extends Node

## Compiles every project script so Redot reports its warnings. tools/lint/lint.py raises them to errors and
## reads this scene's output.

const MARKER := "@@LINT@@"
const SKIPPED_DIRECTORIES: Array[String] = ["res://addons", "res://.godot"]


func _ready() -> void:
	for path in _scripts_under("res://"):
		print(MARKER + path)
		ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	get_tree().quit()


func _scripts_under(directory: String) -> Array[String]:
	var scripts: Array[String] = []
	if directory.trim_suffix("/") in SKIPPED_DIRECTORIES:
		return scripts

	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".gd"):
			scripts.append(directory.path_join(file))
	for child in DirAccess.get_directories_at(directory):
		if not child.begins_with("."):
			scripts.append_array(_scripts_under(directory.path_join(child)))

	return scripts
