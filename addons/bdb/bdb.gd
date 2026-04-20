@tool
extends EditorPlugin


func _enter_tree() -> void:
	# Register the singleton automatically when the plugin is enabled.
	add_autoload_singleton("BDB", "res://addons/bdb/bdb_singleton.gd")
	print("BDB plugin enabled")


func _exit_tree() -> void:
	# Remove the singleton when the plugin is disabled.
	remove_autoload_singleton("BDB")
	print("BDB plugin disabled")
