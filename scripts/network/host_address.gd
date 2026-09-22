extends RefCounted
## Syntax and local adapter discovery only. Does not resolve DNS or contact external services.

static func valid(address: String) -> bool:
	var value := address.strip_edges()
	if value.is_empty() or value.length() > 253:
		return false
	if value.is_valid_ip_address():
		return value not in ["0.0.0.0", "::", "255.255.255.255"]
	# Reject malformed IP literals, URLs, ports, paths and whitespace before ENet/DNS.
	if value.contains(":") or value.contains("/") or value.contains("\\"):
		return false
	var numeric := value.replace(".", "")
	if numeric.is_valid_int():
		return false
	for label: String in value.split("."):
		if label.is_empty() or label.length() > 63 or label.begins_with("-") or label.ends_with("-"):
			return false
		for character in label.to_lower():
			if not "abcdefghijklmnopqrstuvwxyz0123456789-".contains(character):
				return false
	return true


static func lan_candidates(interfaces: Array = IP.get_local_interfaces()) -> PackedStringArray:
	var rows: PackedStringArray = []
	var seen: Dictionary = {}
	for adapter: Dictionary in interfaces:
		for address: String in adapter.get("addresses", []):
			if not address.is_valid_ip_address() or address.contains(":") or seen.has(address):
				continue
			if address.begins_with("127.") or address.begins_with("169.254.") or address == "0.0.0.0":
				continue
			seen[address] = true
			rows.append("%s (%s)" % [address, adapter.get("friendly", adapter.get("name", "Adapter"))])
	rows.sort()
	return rows
