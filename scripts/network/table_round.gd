extends RefCounted
## Host-only orchestration around the existing pure rules. No RPC, camera or client clock.

const Rules = preload("res://scripts/last_letter_round.gd")
var rules := Rules.new()
var participants: Array[int] = []
var participant_seats: Array[int] = []
var phase := "WAITING"
var round_id := 0
var turn_id := 0
var feedback_id := 0
var phase_end := 0
var countdown_start := 0
var verdict := Rules.Verdict.IGNORED
var feedback_word := ""
var feedback_actor := 0
var last_accepted := ""
var mature := false
var difficulty := 1
var attempts: Dictionary = {}


func start(seats: Array, now: int, settings: Resource) -> bool:
	if phase not in ["WAITING", "FINISHED"] or seats.size() - seats.count(0) < 2:
		return false
	participants.clear()
	participant_seats.clear()
	for index in seats.size():
		if seats[index] != 0:
			participants.append(seats[index])
			participant_seats.append(index)
	mature = settings.mature_words_allowed
	difficulty = settings.difficulty
	rules.validator.policy.profanity_allowed = mature
	rules.prefix_advisor.profile = rules.prefix_advisor.DifficultyProfile.for_mode(difficulty)
	rules.prepare(participants.size(), 0)
	round_id += 1
	turn_id = 0
	feedback_id = 0
	attempts.clear()
	feedback_word = ""
	last_accepted = ""
	verdict = Rules.Verdict.IGNORED
	phase = "COUNTDOWN"
	countdown_start = now
	phase_end = now + 3500
	return true


func active_peer() -> int:
	return participants[rules.active_player] if not participants.is_empty() else 0


func submit(peer_id: int, word: String, submitted_round: int, submitted_turn: int, serial: int, now: int) -> bool:
	if phase != "TYPING" or peer_id != active_peer() or submitted_round != round_id or submitted_turn != turn_id:
		return false
	if serial <= int(attempts.get(peer_id, 0)) or word.length() > Rules.Validator.MAX_WORD_LENGTH:
		return false
	attempts[peer_id] = serial
	var result := rules.submit(word, now)
	if result == Rules.Verdict.IGNORED:
		return false
	_result(result, word, now)
	return true


func tick(now: int) -> void:
	if phase in ["WAITING", "FINISHED"]:
		return
	if rules.expire(now):
		_result(Rules.Verdict.TIMEOUT, "", now)
	if phase == "COUNTDOWN" and now >= phase_end:
		rules.begin_round(now)
		turn_id += 1
		phase = "TYPING"
	elif phase == "FEEDBACK" and now >= phase_end:
		if rules.finished:
			phase = "FINISHED"
		elif verdict == Rules.Verdict.INVALID:
			phase = "TYPING" # The unchanged absolute deadline continues.
		else:
			rules.advance_player()
			phase = "MOVING"
			phase_end = now + 550
	elif phase == "MOVING" and now >= phase_end:
		rules.begin_turn(now)
		turn_id += 1
		phase = "TYPING"


func _result(result: int, word: String, now: int) -> void:
	verdict = result
	feedback_actor = active_peer()
	feedback_word = word
	if result == Rules.Verdict.VALID:
		last_accepted = rules.validator.normalize(word)
	feedback_id += 1
	phase = "FEEDBACK"
	phase_end = now + 220


func snapshot(now: int) -> Dictionary:
	var countdown := ""
	if phase == "COUNTDOWN":
		countdown = str(3 - int((now - countdown_start) / 1000)) if now < countdown_start + 3000 else "GO"
	return {"round_id": round_id, "turn_id": turn_id, "phase": phase, "server_now": now,
		"deadline": rules.deadline_ms, "turn_running": rules.turn_running, "countdown": countdown,
		"participants": participants.duplicate(), "participant_seats": participant_seats.duplicate(),
		"active_peer": active_peer(), "hearts": rules.hearts.duplicate(), "alive": rules.alive.duplicate(),
		"prefix": rules.required_prefix, "used_words": rules.used_words.keys(), "last_accepted": last_accepted,
		"winner": participants[rules.winner] if rules.winner >= 0 else 0,
		"feedback_id": feedback_id, "verdict": verdict, "feedback_actor": feedback_actor,
		"feedback_word": feedback_word, "error": rules.last_error, "mature": mature, "difficulty": difficulty}


func remove_participant(peer_id: int, now: int) -> bool:
	if phase in ["WAITING", "FINISHED"]:
		return false
	var index := participants.find(peer_id)
	var was_active := index == rules.active_player
	if not rules.eliminate_player(index):
		return false
	rules.last_error = "SPIELER %d DISCONNECTED / AUSGESCHIEDEN" % peer_id
	feedback_id += 1
	if rules.finished:
		phase = "FINISHED"
	elif was_active:
		rules.advance_player()
		if phase != "COUNTDOWN":
			phase = "MOVING"
			phase_end = now + 550
	return true
