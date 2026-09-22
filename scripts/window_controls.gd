extends Node
## Window-only shortcut, including while a table LineEdit has focus.


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
		and event.alt_pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		# Do not let Alt+Enter submit a word or the lobby IP field.
		get_viewport().set_input_as_handled()
