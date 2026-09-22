extends SceneTree
const Model = preload("res://scripts/network/table_round.gd")
const Settings = preload("res://scripts/match_settings.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
func _run() -> void:
	var model := Model.new()
	var settings := Settings.new()
	check(not model.start([1,0,0,0], 0, settings), "Need two actual occupants.")
	check(model.start([1,25,0,0], 0, settings), "Two seated peers can start.")
	check(not model.submit(1,"stone",1,0,1,0), "Countdown rejects submissions.")
	for now in [0,1000,2000,3000]:
		model.tick(now)
		check(model.snapshot(now).countdown == ["3","2","1","GO"][int(now/1000)], "Host countdown stages.")
	model.tick(3500)
	check(model.rules.deadline_ms == 13500, "Full first 10 seconds after GO.")
	model.rules.prefix_advisor.enabled = false
	model.rules.required_letter = "s"
	model.rules.required_prefix = "st"
	check(not model.submit(25,"stone",1,1,1,3501), "Other peer has no authority to submit.")
	check(not model.submit(1,"stone",0,1,1,3501), "Stale round must fail.")
	check(model.submit(1,"snake",1,1,1,3600) and model.rules.hearts[0] == 2, "Full prefix must be enforced by host.")
	model.tick(3820)
	check(not model.submit(1,"snake",1,1,1,3821) and model.rules.hearts[0] == 2, "Duplicate packet serial cannot lose another heart.")
	check(model.rules.deadline_ms == 13500, "Invalid feedback must preserve deadline.")
	check(model.submit(1,"stone",1,1,2,3900), "Valid retry.")
	model.tick(4120)
	check(model.phase == "MOVING" and model.active_peer() == 25, "Host changes active participant.")
	model.tick(4670)
	check(model.rules.deadline_ms == 14670 and model.turn_id == 2, "Transition ends with fresh host deadline.")
	check(model.submit(25,"epochs",1,2,1,4671), "Second peer chains normally.")
	model.tick(4891)
	model.tick(5441)
	check(model.submit(1,"STONE",1,3,3,5442) and model.rules.last_error.contains("schon benutzt"), "Host rejects repeats after chain returns.")
	model.tick(5662)
	model.tick(15441)
	model.tick(15661)
	check(model.phase == "FINISHED" and model.snapshot(15661).winner == 25, "Host timeout declares same winner snapshot.")
	settings.mature_words_allowed = true
	settings.difficulty = 2
	check(model.start([1,25,0,0],16000,settings), "Restart without changing occupancy.")
	check(model.rules.hearts == [3,3] and model.rules.used_words.is_empty() and model.round_id == 2, "Restart resets core and increments round identity.")
	check(model.mature and model.difficulty == 2, "Host settings copied at start.")
	settings.mature_words_allowed = false
	check(model.rules.validator.policy.profanity_allowed, "Running round retains settings snapshot.")
	for mode in 3:
		for mature in [false,true]:
			var variant := Model.new()
			settings.difficulty = mode
			settings.mature_words_allowed = mature
			variant.start([1,25,40,0],0,settings)
			variant.tick(3500)
			variant.rules.required_letter = "s"
			variant.rules.required_prefix = "s"
			variant.submit(1,"shit",1,1,1,3501)
			check(variant.verdict == (Model.Rules.Verdict.VALID if mature else Model.Rules.Verdict.INVALID), "Host Mature policy must govern all difficulty modes.")
			check(variant.snapshot(3501).difficulty == mode and variant.snapshot(3501).mature == mature, "Clients receive exact host settings.")
	var elimination := Model.new()
	elimination.start([1,25,40,0],0,settings)
	elimination.tick(3500)
	for attempt in 3:
		elimination.submit(1,"zzzzmadeup",1,1,attempt+1,3501+attempt*221)
		elimination.tick(3721+attempt*221)
	check(elimination.rules.hearts[0] == 0 and not elimination.rules.alive[0] and elimination.active_peer() == 25,
		"Host removes three-heart loser and advances to actual next participant.")
	print("ONLINE_ROUND_RULES: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
