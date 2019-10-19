extends Control

onready var playerListControl := get_node('PlayerList')

const MIN_PLAYERS = 1

func _ready():
	update_player_list()
	assert(Network.connect("players_updated", self, "players_updated") == OK)

func players_updated():
	update_player_list()

func update_player_list():
	for child in playerListControl.get_children():
		playerListControl.remove_child(child)
	
	for player_id in Network.players:
		var player = Network.players[player_id]
		var playerControl = Label.new()
		playerControl.text = player.name
		playerListControl.add_child(playerControl)

func _on_StartGameButton_pressed():
	if Network.players >= MIN_PLAYERS:
		get_tree().change_scene('res://maps/map_00/main.tscn')
