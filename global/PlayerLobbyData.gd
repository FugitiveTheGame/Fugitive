extends Object
class_name PlayerLobbyData

const hiderEscapeMultiplier := 5

# The display name of this player, as entered by the player before
# they joined the lobby.
var name: String
# The position of this player in the world.
var position: Vector2
# The "Type" of role they chose in the lobby (Seeker, Hider, Random)
var lobby_type: int
# The "Type" they are actually assigned to in the game.  This will
# be randomly reassigned if their lobby "type" is set to Random
var assigned_type: int

# Various stats about this player.
var stats = {
	seeker_captures = 0,
	hider_captures = 0,
	hider_escapes = 0
}

func _init():
	self.name = ""
	self.position = Vector2()
	self.lobby_type = -1
	self.assigned_type = -1

func score() -> int:
	return stats.seeker_captures + (stats.hider_escapes * hiderEscapeMultiplier)

func toDTO() -> Dictionary:
	var result = {
		name = self.name,
		position = self.position,
		lobby_type = self.lobby_type,
		stats = self.stats,
		assigned_type = self.assigned_type
	}
	return result
