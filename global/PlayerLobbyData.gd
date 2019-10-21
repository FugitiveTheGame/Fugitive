extends Object
class_name PlayerLobbyData

var name: String
var position: Vector2
var type: int

func _init():
	self.name = ""
	self.position = Vector2()
	self.type = -1
	
func toDTO() -> Dictionary:
	var result = {
		name = self.name,
		position = self.position,
		type = self.type
	}
	return result