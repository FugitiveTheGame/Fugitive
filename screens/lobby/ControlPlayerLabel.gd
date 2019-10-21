extends Control

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var playerId := 0;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func setPlayerId(value: int):
	self.playerId = value

func getPlayerId() -> int:
	return self.playerId

func setPlayerName(text: String):
	self.get_node("LabelPlayerName").text = text
	
func getPlayerName() -> String:
	return self.get_node("LabelPlayerName").text
	
func setPlayerType(playerType: int):
	self.get_node("OptionPlayerRole").selected = playerType

func getPlayerType() -> int:
	match self.get_node("OptionPlayerRole").get_selected_id():
		0:
			return Network.PlayerType.Hider
		1:
			return Network.PlayerType.Seeker
		_:
			return Network.PlayerType.Hider

func _on_OptionPlayerRole_item_selected(ID):
		Network.broadcastSetPlayerType(self.playerId, self.getPlayerType())
