extends SceneTree
const Address = preload("res://scripts/network/host_address.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	for value in ["127.0.0.1", "192.168.0.9", " localhost ", "my-pc.local", "example.com", "::1"]:
		check(Address.valid(value), "Valid host rejected: " + value)
	for value in ["", " ", "999.12.1.1", "192.168.0", "http://localhost", "host:24572", "has space", "name@host", "a..b", "-host", "host-", "0.0.0.0", "::"]:
		check(not Address.valid(value), "Invalid host accepted: " + value)
	var candidates := Address.lan_candidates([
		{"friendly":"Ethernet", "addresses":["127.0.0.1","192.168.0.9","::1"]},
		{"name":"Virtual", "addresses":["172.17.192.1","169.254.1.1","192.168.0.9"]}])
	check(candidates.size() == 2 and candidates[1] == "192.168.0.9 (Ethernet)", "LAN candidates must retain adapter names without loopback/link-local/duplicates.")
	print("HOST_ADDRESS: %s · local %s" % ["PASS" if failures == 0 else "FAIL", Address.lan_candidates()])
	quit(0 if failures == 0 else 1)
