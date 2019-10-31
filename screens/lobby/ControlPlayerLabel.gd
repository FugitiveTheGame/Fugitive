extends VBoxContainer

var playerId := 0;

func set_player_id(value: int):
	self.playerId = value

func get_player_id() -> int:
	return self.playerId

func set_player_name(text: String):
	$MainContainer/LabelPlayerName.text = text

func set_player_stats(stats, score):
	var text = "[color=green][b][u]Score[/u][/b][/color] %d - [i][color=blue]Cop[/color] %d [color=red]Fug[/color] %d[/i]" % [score, stats.seeker_captures, stats.hider_escapes]
	$StatsLabel.bbcode_text = text

func get_player_name() -> String:
	return $MainContainer/LabelPlayerName.text

func set_player_type(playerType: int):
	$MainContainer/OptionPlayerRole.selected = playerType

func get_player_type() -> int:
	match $MainContainer/OptionPlayerRole.get_selected_id():
		0:
			return Network.PlayerType.Hider
		1:
			return Network.PlayerType.Seeker
		_:
			return Network.PlayerType.Hider

# warning-ignore:unused_argument
func _on_OptionPlayerRole_item_selected(ID):
		Network.broadcast_set_player_type(self.playerId, self.get_player_type())
