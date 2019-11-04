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
const HIDER_TO_SEEKER_RATIO = 3
const MAX_SEEKERS = 5
const MAX_HIDERS = 10

# Testing values:
"""
const MIN_PLAYERS = 2
const MIN_SEEKERS = 1
const MIN_HIDERS = 1
"""

func _ready():
	randomize()
	# Maps pause the game when they end, we need to re-enable them
	get_tree().paused = false
	
	players_initialize(Network.players)
	assert(Network.connect("player_updated", self, "player_updated") == OK)
	assert(Network.connect("new_player_registered", self, "new_player_registered") == OK)
	assert(Network.connect("player_removed", self, "player_removed") == OK)
	
	assert(Network.connect("send_lobby_state", self, "send_lobby_state") == OK)
	assert(Network.connect("receive_lobby_state", self, "receive_lobby_state") == OK)
	
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
	Network.request_lobby_state()
	
	# Update all clients to the server's network state
	if get_tree().is_network_server():
		Network.send_lobby_state(1)

# Server collects it's lobby data, and passes it back to the Network
func send_lobby_state(id: int):
	if id == 1:
		Network.broadcast_update_lobby_state(mapSelectButton.selected)
	else:
		Network.update_lobby_state(id, mapSelectButton.selected)

func receive_lobby_state(mapId: int):
	update_map_selection(mapId)
	game_updated()
	update_winner()

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
	playerControl.set_player_lobby_type(playerData.lobby_type)
	playerControl.set_player_stats(playerData.stats, playerData.score())
	
	# If this is me, update my local player data
	if playerId == get_tree().get_network_unique_id():
		Network.get_current_player().lobby_type = playerData.lobby_type
	
	# Update assigned type for the player
	Network.players[playerId].assigned_type = playerData.assigned_type
	
	update_player_counts()

func update_player_counts():
	var numSeekers := 0
	var numHiders := 0
	var numRandom := 0
		
	for player_id in Network.players:
		var player = Network.players[player_id]
		if player.lobby_type == Network.PlayerType.Seeker:
			numSeekers += 1
		elif player.lobby_type == Network.PlayerType.Hider:
			numHiders += 1
		else:
			numRandom += 1
	
	var minSeekers : int = max(MIN_SEEKERS, Network.players.size() / HIDER_TO_SEEKER_RATIO)
	var minHiders : int = max(MIN_HIDERS, Network.players.size() - minSeekers)
	
	var numRandomSeekers : int = min(minSeekers - numSeekers, numRandom)
	if (numRandomSeekers < 0):
		numRandomSeekers = 0
	var numRandomHiders : int = numRandom - numRandomSeekers
	if (numRandomHiders < 0):
		numRandomHiders = 0
	
	seekerCountLabel.text = 'Cops: %d (min: %d, max: %d)' % [(numSeekers + numRandomSeekers), MIN_SEEKERS, MAX_SEEKERS]
	hiderCountLabel.text = 'Fugitives: %d (min: %d, max: %d)' % [(numHiders + numRandomHiders), MIN_HIDERS, MAX_HIDERS]
	
	if (numSeekers + numRandomSeekers > MAX_SEEKERS):
		seekerCountLabel.add_color_override("font_color", Color.red)
	elif (numSeekers + numRandomSeekers < MIN_SEEKERS):
		seekerCountLabel.add_color_override("font_color", Color.red)
	else:
		seekerCountLabel.add_color_override("font_color", Color.white)
		
	if (numHiders + numRandomHiders > MAX_HIDERS):
		hiderCountLabel.add_color_override("font_color", Color.red)
	elif (numHiders + numRandomHiders < MIN_HIDERS):
		hiderCountLabel.add_color_override("font_color", Color.red)
	else:
		hiderCountLabel.add_color_override("font_color", Color.white)

func new_player_registered(playerId: int, playerData: PlayerLobbyData):
	var scene = load("res://screens/lobby/ControlPlayerLabel.tscn")
	var playerControl = scene.instance()
	playerControl.set_name(str(playerId))
	playerControl.set_player_id(playerId)
	playerControl.set_player_name(playerData.name)
	playerControl.set_player_lobby_type(playerData.lobby_type)
	playerControl.set_player_stats(playerData.stats, playerData.score())
	playerListControl.add_child(playerControl)
	
	update_player_counts()

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
		if player.lobby_type == Network.PlayerType.Seeker:
			numSeekers += 1
		elif player.lobby_type == Network.PlayerType.Hider:
			numHiders += 1
		else:
			# If random, assume seeker allocation first, then hiders
			if (numSeekers < MIN_SEEKERS):
				numSeekers += 1
			else:
				numHiders += 1
	
	if Network.players.size() < MIN_PLAYERS:
		return false
	elif numSeekers < MIN_SEEKERS:
		return false
	elif numHiders < MIN_HIDERS:
		return false
	elif numSeekers > MAX_SEEKERS:
		return false
	elif numHiders > MAX_HIDERS:
		return false
	else:
		return true

func getSelectedMap() -> String:
	match mapSelectButton.get_selected_id():
		0:
			return 'res://maps/map_01/Map_01.tscn'
		1:
			return 'res://maps/map_02/Map_02.tscn'
		2:
			return 'res://maps/map_03/Map_03.tscn'
		25:
			return 'res://maps/map_breakin/Map_breakin.tscn'
		_:
			return 'ERROR'

func _on_StartGameButton_pressed():
	# Only the host can start the game
	if not is_network_master():
		return
	
	if not validate_game():
		return
		
	assign_random_players()
	
	var selectedMap = getSelectedMap()
	
	if Network.players.size() >= MIN_PLAYERS:
		# Starting the game, refuse any new player joins mid-game
		if get_tree().is_network_server():
			get_tree().network_peer.refuse_new_connections = true
		rpc('startGame', selectedMap)
		
class PlayerValue:
	var player_id: int
	var value: float
	var assigned_role: int
	
	static func sort(value1: PlayerValue, value2: PlayerValue):
		return value1.value < value2.value

func assign_random_players():
	var seekerCount := 0
	var hiderCount := 0
	var randomCount := 0
	
	var randomPlayerValues := []
	
	# Find the count of players in assigned types vs. random,
	# this will determine the mix of random assignments.
	for player_id in Network.players.keys():
		var player = Network.players[player_id]
		
		# By default, assign them to the type that they chose.
		player.assigned_type = player.lobby_type
		
		# Set up random assignment info if they are random,
		# and get an accurate count of assigned vs. unassigned users
		match player.lobby_type:
			Network.PlayerType.Seeker:
				seekerCount = seekerCount + 1
			Network.PlayerType.Hider:
				hiderCount = hiderCount + 1
			Network.PlayerType.Random:
				randomCount = randomCount + 1
				# Generate a random value for every random player.
				var newRandomValue := PlayerValue.new()
				newRandomValue.player_id = player_id
				newRandomValue.value = rand_range(0, 100)
				# By default, they will all be hiders.
				newRandomValue.assigned_role = Network.PlayerType.Hider
				randomPlayerValues.append(newRandomValue)
	
	# Determine how many seekers to assign to randoms.  The rest will be hiders.
	var seekersToSpawn := max(MIN_SEEKERS, Network.players.size() / HIDER_TO_SEEKER_RATIO) - seekerCount
	
	# sort the random players by their assigned seed, lowest first.
	randomPlayerValues.sort_custom(PlayerValue, "sort")
	
	# The lowest X random players will be seekers, the rest hiders.
	for index in range(0, randomPlayerValues.size()):
		if (index < seekersToSpawn):
			Network.players[randomPlayerValues[index].player_id].assigned_type = Network.PlayerType.Seeker
		else:
			Network.players[randomPlayerValues[index].player_id].assigned_type = Network.PlayerType.Hider
		
	# Now, update all clients' player assignments before we spawn them on the map.
	for player_id in Network.players.keys():
		var player = Network.players[player_id]
		Network.broadcast_set_player_assigned_type(player_id, player.assigned_type)

remotesync func startGame(map):
	get_tree().change_scene(map)

func _on_LeaveButton_pressed():
	Network.disconnect_from_game()

func _on_UPNPButton_pressed():
	Network.enable_upnp()
	#serverIpLabel.text = Network.get_external_ip()

func _on_MapSelectButton_item_selected(id):
	rpc('update_map_selection', id)

remote func update_map_selection(id):
	mapSelectButton.selected = id

func fetch_external_ip():
	$HTTPRequest.request("https://api.ipify.org/?format=json")

func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var json = parse_json(body.get_string_from_utf8())
		print('External IP: %s' % json.ip)
		serverIpLabel.text = json.ip
	else:
		print('Failed to get external IP')

func _on_HelpButton_pressed():
	var scene = preload("res://help/Help.tscn")
	var node = scene.instance()
	add_child(node)
	node.popup_centered()

func game_updated():
	var gameNumberLabel := $MainPanel/OuterContainer/GameNumberLabel
	gameNumberLabel.text = "Game: %d" % (Network.numGames+1)
