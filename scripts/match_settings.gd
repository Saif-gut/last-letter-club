extends Resource
## Local match configuration. A future host can supply the same settings before start.
## The active round takes a snapshot; UI changes must not alter a running round.

@export var mature_words_allowed := false
@export_enum("Easy", "Normal", "Hard") var difficulty := 1
