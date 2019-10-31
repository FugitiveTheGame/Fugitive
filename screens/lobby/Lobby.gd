extends Control

onready var playerListControl := $MainPanel/OuterContainer/CenterContainer/PlayersContainer/PlayersScrollContainer/PlayerList
onready var startGameButton := $MainPanel/OuterContainer/StartGameButton
onready var upnpButton := $MainPanel/OuterContainer/HBoxContainer/UPNPButton
onready var serverIpLabel := $MainPanel/OuterContainer/ServerIpLabel
onready var seekerCountLabel := $MainPanel/OuterContainer/CenterContainer/PlayersContainer/SeekersCount
onready var hiderCountLabel := $MainPanel/OuterContainer/CenterContainer/PlayersContainer/HidersCount
onready var mapSelectButton := $MainPanel/OuterContainer/CenterContainer/OptionsContainer/MapSelectButton

# Production values:
const MIN_PLAYERS = 3
const MIN_SEEKERS = 2
const MIN_HIDERS = 1

# Testing values:
"""
const MIN_PLAYERS = 2
const MIN_SEEKERS = 1
const MIN_HIDERS = 1
"""

func _ready():
	# Maps pause the game when they end, we need to re-enable them
	get_tree().paused = false
	
	players_initialize(Network.players)
	assert(Network.connect("player_updated", self, "player_updated") == OK)
	assert(Network.connect("new_player_registered", self, "new_player_registered") == OK)
	assert(Network.connect("player_removed", self, "player_removed") == OK)
	assert(Network.connect("game_updated", self, "game_updated") == OK)
	
	update_player_counts()
	
	fetch_external_ip()
	
	# Only server should see these buttons
	if not get_tree().is_network_server():
		startGameButton.hide()
		upnpButton.hide()
		serverIpLabel.hide()
	else:
		# Returning to the lobby, allow new players to join
		get_tree().network_peer.refuse_new_connections = false
	
	update_winner()
	game_updated()

class ScoreSorter:
	static func sort(a, b):
		if a.score() > b.score():
			return true
		return false

func find_winner() -> PlayerLobbyData:
	var playersByScore = []
	
	for player in Network.players.values():
		playersByScore.push_back(player)
	
	playersByScore.sort_custom(ScoreSorter, 'sort')
	
	return playersByScore[0]

func update_winner():
	var winnerLabel := $MainPanel/OuterContainer/WinnerLabel
	if Network.numGames > 0:
		var winner = find_winner()
		
		winnerLabel.text = "Winning: %s" % [winner.name]
		winnerLabel.show()
	else:
		winnerLabel.hide()

func player_updated(playerId: int, playerData: PlayerLobbyData):
	var playerControl = playerListControl.get_node(str(playerId))
	playerControl.set_player_id(playerId)
	playerControl.set_player_name(playerData.name)
	playerControl.set_player_type(playerData.type)
	playerControl.set_player_stats(playerData.stats, playerData.score())
	
	# If this is me, update my local player data
	if playerId == get_tree().get_network_unique_id():
		Network.get_current_player().type = playerData.type
	
	update_player_counts()

func update_player_counts():
	var numSeekers := 0
	var numHiders := 0
	for player_id in Network.players:
		var player = Network.players[player_id]
		if player.type == Network.PlayerType.Seeker:
			numSeekers += 1
		elif player.type == Network.PlayerType.Hider:
			numHiders += 1
	
	seekerCountLabel.text = 'Seekers: ' + str(numSeekers) + '/' + str(MIN_SEEKERS)
	hiderCountLabel.text = 'Hiders: ' + str(numHiders) + '/' + str(MIN_HIDERS)

func new_player_registered(playerId: int, playerData: PlayerLobbyData):
	var scene = load("res://screens/lobby/ControlPlayerLabel.tscn")
	var playerControl = scene.instance()
	playerControl.set_name(str(playerId))
	playerControl.set_player_id(playerId)
	playerControl.set_player_name(playerData.name)
	playerControl.set_player_type(playerData.type)
	playerControl.set_player_stats(playerData.stats, playerData.score())
	playerListControl.add_child(playerControl)
	
	update_player_counts()
	
	# Tell the new player what map is currently selected
	if get_tree().is_network_server():
		rpc('updateMapSelection', mapSelectButton.get_selected_id())

func players_initialize(newPlayers: Dictionary):
	var playersInOrder = newPlayers.keys()
	playersInOrder.sort()
	
	for playerId in playersInOrder:
		new_player_registered(playerId, newPlayers[playerId])

func player_removed(playerId: int):
	var childToRemove = playerListControl.get_node(str(playerId))
	playerListControl.remove_child(childToRemove)
	update_player_counts()

func validate_game() -> bool:
	var numSeekers := 0
	var numHiders := 0
	for player_id in Network.players:
		var player = Network.players[player_id]
		if player.type == Network.PlayerType.Seeker:
			numSeekers += 1
		elif player.type == Network.PlayerType.Hider:
			numHiders += 1
	
	if Network.players.size() < MIN_PLAYERS:
		return false
	elif numSeekers < MIN_SEEKERS:
		return false
	elif numHiders < MIN_HIDERS:
		return false
	else:
		return true

func getSelectedMap() -> String:
	match mapSelectButton.get_selected_id():
		0:
			return 'res://maps/map_01/Map_01.tscn'
		1:
			return 'res://maps/map_02/Map_02.tscn'
		_:
			return 'ERROR'

func _on_StartGameButton_pressed():
	# Only the host can start the game
	if not is_network_master():
		return
	
	if not validate_game():
		return
	
	var selectedMap = getSelectedMap()
	
	if Network.players.size() >= MIN_PLAYERS:
		# Starting the game, refuse any new player joins mid-game
		if get_tree().is_network_server():
			get_tree().network_peer.refuse_new_connections = true
		rpc('startGame', selectedMap)

remotesync func startGame(map):
	get_tree().change_scene(map)

func _on_LeaveButton_pressed():
	Network.disconnect_from_game()

func _on_UPNPButton_pressed():
	Network.enableUpnp()
	#serverIpLabel.text = Network.get_external_ip()

func _on_MapSelectButton_item_selected(id):
	rpc('updateMapSelection', id)

remote func updateMapSelection(id):
	mapSelectButton.selected = id

func fetch_external_ip():
	$HTTPRequest.request("https://api.ipify.org/?format=json")

func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	var json = parse_json(body.get_string_from_utf8())
	print('External IP: %s' % json.ip)
	serverIpLabel.text = json.ip

func _on_HelpButton_pressed():
	var scene = preload("res://help/Help.tscn")
	var node = scene.instance()
	add_child(node)
	node.popup_centered()

func game_updated():
	var gameNumberLabel := $MainPanel/OuterContainer/GameNumberLabel
	gameNumberLabel.text = "Game: %d" % (Network.numGames+1)
