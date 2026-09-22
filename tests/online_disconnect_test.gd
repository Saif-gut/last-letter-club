extends SceneTree
const Model = preload("res://scripts/network/table_round.gd")
const Settings = preload("res://scripts/match_settings.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	for phase in ["COUNTDOWN","TYPING","FEEDBACK","MOVING"]:
		var model := Model.new()
		model.start([1,20,30,40],0,Settings.new())
		if phase != "COUNTDOWN":
			model.tick(3500)
		if phase == "FEEDBACK":
			model.submit(1,"zzzzmadeup",1,1,1,3600)
		elif phase == "MOVING":
			model.rules.required_prefix = "s"
			model.submit(1,"stone",1,1,1,3600)
			model.tick(3820)
		var active := model.active_peer()
		var other := 30
		var deadline := model.rules.deadline_ms
		check(model.remove_participant(other,3900), "Non-active departure must be accepted in " + phase)
		check(model.active_peer() == active and model.rules.deadline_ms == deadline, "Non-active departure preserves current turn in " + phase)
		check(not model.remove_participant(other,3901), "Duplicate departure is idempotent.")
		check(model.remove_participant(active,3902), "Active departure accepted in " + phase)
		check(model.active_peer() != active and model.active_peer() != other, "Immediately skip disconnected participants.")
		if phase != "COUNTDOWN":
			check(model.phase == "MOVING", "No ten-second stall after active loss.")
			model.tick(4452)
			check(model.phase == "TYPING" and model.rules.deadline_ms == 14452, "Next survivor gets full new host turn.")
		model.remove_participant(model.active_peer(),4500)
		check(model.phase == "FINISHED" and model.snapshot(4500).winner != 0, "Final survivor wins even during countdown/transition.")
	print("ONLINE_DISCONNECT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
