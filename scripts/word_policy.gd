extends RefCounted
## Exact normalized word matching, independent of dictionary and round rules.

const MatureLexicon = preload("res://resources/words/mature_words.tres")

var profanity_allowed := false
var blocked_words: Dictionary = {}


func _init() -> void:
	for word in MatureLexicon.words:
		blocked_words[word] = true


func allows(word: String) -> bool:
	return profanity_allowed or not blocked_words.has(word)
