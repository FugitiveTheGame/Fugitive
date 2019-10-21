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
		child.queue_free()
	
	for player_id in Network.players:
		var player = Network.players[player_id]
		var scene = load("res://screens/lobby/ControlPlayerLabel.tscn")
		var playerControl = scene.instance()
		playerControl.setPlayerId(player_id)
		playerControl.setPlayerName(player.name)
		playerListControl.add_child(playerControl)

func _on_StartGameButton_pressed():
	# Only the host can start the game
	if not is_network_master():
		return
	
	var selectedMap = 'res://maps/map_00/Map_00.tscn'
	
	if Network.players.size() >= MIN_PLAYERS:
		rpc('startGame', selectedMap)

sync func startGame(map):
	assert(get_tree().change_scene(map) == OK)
