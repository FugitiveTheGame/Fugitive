extends Control

var playerId := 0;

func setPlayerId(value: int):
	self.playerId = value

func getPlayerId() -> int:
	return self.playerId

func setPlayerName(text: String):
	self.get_node("LabelPlayerName").text = text
	
func getPlayerName() -> String:
	return self.get_node("LabelPlayerName").text
	
func set_player_type(playerType: int):
	self.get_node("OptionPlayerRole").selected = playerType

func getPlayerType() -> int:
	match self.get_node("OptionPlayerRole").get_selected_id():
		0:
			return Network.PlayerType.Hider
		1:
			return Network.PlayerType.Seeker
		_:
			return Network.PlayerType.Hider

# warning-ignore:unused_argument
func _on_OptionPlayerRole_item_selected(ID):
		Network.broadcast_set_player_type(self.playerId, self.getPlayerType())
