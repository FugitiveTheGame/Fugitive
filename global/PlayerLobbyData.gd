extends Object
class_name PlayerLobbyData

const hiderEscapeMultiplier := 5

var name: String
var position: Vector2
var type: int
var stats = {
	seeker_captures = 0,
	hider_captures = 0,
	hider_escapes = 0
}

func _init():
	self.name = ""
	self.position = Vector2()
	self.type = -1

func score() -> int:
	return stats.seeker_captures + (stats.hider_escapes * hiderEscapeMultiplier)

func toDTO() -> Dictionary:
	var result = {
		name = self.name,
		position = self.position,
		type = self.type,
		stats = self.stats
	}
	return result
