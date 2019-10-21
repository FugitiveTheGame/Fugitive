extends Control

onready var playerListControl := $MainPanel/OuterContainer/CenterContainer/PlayersContainer/PlayersScrollContainer/PlayerList
onready var startGameButton := $MainPanel/OuterContainer/StartGameButton

const MIN_PLAYERS = 1

func _ready():
	players_initialize(Network.players)
	assert(Network.connect("player_updated", self, "player_updated") == OK)
	assert(Network.connect("new_player_registered", self, "new_player_registered") == OK)
	assert(Network.connect("players_initialize", self, "players_initialize") == OK)
	assert(Network.connect("player_removed", self, "player_removed") == OK)
	
	# Only server should see start button
	if not get_tree().is_network_server():
		startGameButton.hide()

func player_updated(playerId: int, playerData: PlayerLobbyData):
	var playerControl = playerListControl.get_node(str(playerId))
	playerControl.setPlayerId(playerId)
	playerControl.setPlayerName(playerData.name)
	playerControl.setPlayerType(playerData.type)
	
func new_player_registered(playerId: int, playerData: PlayerLobbyData):
	var scene = load("res://screens/lobby/ControlPlayerLabel.tscn")
	var playerControl = scene.instance()
	playerControl.set_name(str(playerId))
	playerControl.setPlayerId(playerId)
	playerControl.setPlayerName(playerData.name)
	playerControl.setPlayerType(playerData.type)
	playerListControl.add_child(playerControl)

func players_initialize(newPlayers: Dictionary):
	var playersInOrder = newPlayers.keys()
	playersInOrder.sort()
	
	for playerId in playersInOrder:
		new_player_registered(playerId, newPlayers[playerId])
		
func player_removed(playerId: int):
	var childToRemove = playerListControl.get_node(str(playerId))
	playerListControl.remove_child(childToRemove)

func _on_StartGameButton_pressed():
	# Only the host can start the game
	if not is_network_master():
		return
	
	var selectedMap = 'res://maps/map_00/Map_00.tscn'
	
	if Network.players.size() >= MIN_PLAYERS:
		rpc('startGame', selectedMap)

sync func startGame(map):
	assert(get_tree().change_scene(map) == OK)
