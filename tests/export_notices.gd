extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var text := "GODOT ENGINE\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY COMPONENTS\n\n"
	for item in Engine.get_copyright_info():
		text += str(item) + "\n\n"
	for name in Engine.get_license_info():
		text += name + "\n" + Engine.get_license_info()[name] + "\n\n"
	FileAccess.open(args[0],FileAccess.WRITE).store_string(text)
	quit()
