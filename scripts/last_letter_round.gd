extends RefCounted
## Pure local round rules. The caller supplies monotonic milliseconds for testability.
## Camera travel is outside a turn; invalid feedback never stops the deadline.

const Validator = preload("res://scripts/word_validator.gd")
const PrefixAdvisor = preload("res://scripts/prefix_advisor.gd")
const STARTING_HEARTS := 3
const TURN_MILLISECONDS := 10000
const START_LETTERS := "abcdefghijklmnopqrstuvwxyz"
const FIRST_START_LETTERS := "abcdefghijklmnoprstuvwy"
enum Verdict { IGNORED, VALID, INVALID, ELIMINATED, TIMEOUT }

var validator := Validator.new()
var prefix_advisor := PrefixAdvisor.new(validator)
var hearts: Array[int] = []
var alive: Array[bool] = []
var used_words: Dictionary = {}
var active_player := 0
var required_letter := ""
var required_prefix := ""
var awaiting_start := false
var deadline_ms := 0
var turn_running := false
var finished := false
var winner := -1
var last_error := ""


func start(player_count: int, first_player: int, now_ms: int, start_letter: String = "") -> void:
	# Convenience entry point for isolated rule tests without presentation.
	prepare(player_count, first_player)
	begin_round(now_ms, start_letter)


func prepare(player_count: int, first_player: int) -> void:
	assert(player_count >= 2)
	hearts.clear()
	alive.clear()
	for index in player_count:
		hearts.append(STARTING_HEARTS)
		alive.append(true)
	used_words.clear()
	active_player = clampi(first_player, 0, player_count - 1)
	required_letter = ""
	required_prefix = ""
	deadline_ms = 0
	turn_running = false
	awaiting_start = true
	finished = false
	winner = -1
	last_error = ""


func begin_round(now_ms: int, start_letter: String = "") -> void:
	if not awaiting_start:
		return
	awaiting_start = false
	required_letter = start_letter.to_lower() if start_letter.length() == 1 and START_LETTERS.contains(start_letter.to_lower()) else FIRST_START_LETTERS[randi_range(0, FIRST_START_LETTERS.length() - 1)]
	required_prefix = prefix_advisor.choose(required_letter, validator, used_words)
	begin_turn(now_ms)


func begin_turn(now_ms: int) -> void:
	if awaiting_start or required_letter.is_empty() or finished or not alive[active_player]:
		return
	deadline_ms = now_ms + TURN_MILLISECONDS
	turn_running = true


func seconds_left(now_ms: int) -> float:
	return maxf(0.0, float(deadline_ms - now_ms) / 1000.0)


func expire(now_ms: int) -> bool:
	if not turn_running or finished or now_ms < deadline_ms:
		return false
	last_error = "ZEIT ABGELAUFEN  /  Platz %02d ausgeschieden" % (active_player + 1)
	_eliminate_active()
	return true


func submit(raw: String, now_ms: int) -> Verdict:
	if finished or not turn_running:
		return Verdict.IGNORED
	# At the exact deadline, timeout wins over even a valid submission.
	if expire(now_ms):
		return Verdict.TIMEOUT
	last_error = validator.rejection_reason(raw, required_prefix, used_words)
	if not last_error.is_empty():
		hearts[active_player] -= 1
		if hearts[active_player] == 0:
			_eliminate_active()
			return Verdict.ELIMINATED
		return Verdict.INVALID
	var word := validator.normalize(raw)
	used_words[word] = true
	required_letter = word.right(1)
	required_prefix = prefix_advisor.choose(required_letter, validator, used_words)
	turn_running = false
	return Verdict.VALID


func advance_player() -> int:
	if finished or turn_running:
		return active_player
	for offset in range(1, alive.size() + 1):
		var candidate := (active_player + offset) % alive.size()
		if alive[candidate]:
			active_player = candidate
			break
	return active_player


func stop() -> void:
	turn_running = false
	awaiting_start = false


func _eliminate_active() -> void:
	eliminate_player(active_player)


func eliminate_player(index: int) -> bool:
	# External departures may eliminate a waiting participant without changing the deadline.
	if index < 0 or index >= alive.size() or not alive[index] or finished:
		return false
	alive[index] = false
	if index == active_player:
		turn_running = false
	if alive.count(true) <= 1:
		finished = true
		winner = alive.find(true)
		turn_running = false
		awaiting_start = false
	return true
