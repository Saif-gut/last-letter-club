extends RefCounted

const Lexicon = preload("res://resources/words/english_words.tres")
const WordPolicy = preload("res://scripts/word_policy.gd")
const MAX_WORD_LENGTH := 24

static var dictionary: Dictionary = {}
var policy := WordPolicy.new()


func _init() -> void:
	if dictionary.is_empty():
		for word in Lexicon.words:
			dictionary[word] = true


func normalize(raw: String) -> String:
	return raw.strip_edges().to_lower()


func rejection_reason(raw: String, required_prefix: String, used_words: Dictionary) -> String:
	var word := normalize(raw)
	if word.is_empty():
		return "Bitte ein englisches Wort eingeben."
	if word.length() > MAX_WORD_LENGTH:
		return "Maximal 24 Buchstaben."
	for index in word.length():
		var code := word.unicode_at(index)
		if code < 97 or code > 122:
			return "Nur englische Buchstaben A–Z."
	if not word.begins_with(required_prefix):
		return "Das Wort muss mit %s beginnen." % required_prefix.to_upper()
	if used_words.has(word):
		return "Dieses Wort wurde in dieser Runde schon benutzt."
	if not dictionary.has(word):
		return "Kein Wort in der englischen Wortliste."
	if not policy.allows(word):
		return "Dieses Wort ist durch den Wortfilter gesperrt."
	return ""
