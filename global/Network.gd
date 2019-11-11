extends Node

signal player_updated
signal new_player_registered
signal player_removed
signal receive_lobby_state

const DEFAULT_IP := '127.0.0.1'
const DEFAULT_PORT := 31400
const MAX_PLAYERS := 15

enum PlayerType {Hider, Seeker, Random }

class GameData:
	var players = {}
	var playerName: String
	var numGames := 0
	var currentMapId: int
	var sharedSeed: int

var gameData: GameData

onready var upnp = UPNP.new()

func _ready():
	gameData = GameData.new()
	
	get_tree().connect('connected_to_server', self, 'on_connected_to_server')
	get_tree().connect('network_peer_disconnected', self, 'on_player_disconnect')
	get_tree().connect('server_disconnected', self, 'on_server_disconnect')
	
	# Begin discovery asap
	upnp.discover()
	
	gameData.sharedSeed = OS.get_unix_time()

func get_current_player() -> PlayerLobbyData:
	return gameData.players[get_current_player_id()]
	
func get_current_player_id() -> int:
	return get_tree().get_network_unique_id();
	
func disconnect_from_game():
	reset_game()

func broadcast_all_player_data():
	# Only the network server can update everyone's player data
	if not get_tree().is_network_server():
		return
	
	for player_id in gameData.players:
		var player = gameData.players[player_id]
		var dto = player.toDTO()
		rpc('set_player_data', player_id, dto)

remote func set_player_data(playerId: int, playerDto: Dictionary):
	var playerData = PlayerLobbyData.new()
	playerData.fromDTO(playerDto)
	self.gameData.players[playerId] = playerData
	emit_signal('player_updated', playerId, self.gameData.players[playerId])

func broadcast_set_player_lobby_type(playerId: int, playerType: int):
	rpc('set_player_lobby_type', playerId, playerType)

remotesync func set_player_lobby_type(playerId: int, playerType: int):
	self.gameData.players[playerId].lobby_type = playerType
	emit_signal('player_updated', playerId, self.gameData.players[playerId])
	
func broadcast_set_player_assigned_type(playerId: int, playerType: int):
	rpc('set_player_assigned_type', playerId, playerType)

remotesync func set_player_assigned_type(playerId: int, playerType: int):
	self.gameData.players[playerId].assigned_type = playerType
	emit_signal('player_updated', playerId, self.gameData.players[playerId])

func host_game(name: String) -> bool:
	self.gameData.playerName = name
	
	var selfData = PlayerLobbyData.new()
	selfData.name = gameData.playerName
	selfData.lobby_type = PlayerType.Random
	gameData.players[1] = selfData
	
	var peer = NetworkedMultiplayerENet.new()
	#peer.allow_object_decoding = true
	var result = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	
	if result == OK:
		get_tree().set_network_peer(peer)
		emit_signal('new_player_registered', 1, get_current_player())
		return true
	else:
		return false

func join_game(name: String, serverIp: String) -> bool:
	self.gameData.playerName = name
		
	var peer = NetworkedMultiplayerENet.new()
	#peer.allow_object_decoding = true
	var result = peer.create_client(serverIp, DEFAULT_PORT)
	
	if result == OK:
		get_tree().set_network_peer(peer)
		
		return true
	else:
		return false

func on_player_disconnect(id):
	print('Player disconnect: ' + str(id))
	self.gameData.players.erase(id)
	emit_signal('player_removed', id)
	
func on_connected_to_server():
	var currentPlayerId = get_tree().get_network_unique_id()
	print('Connected.  Assigned to player %d' % currentPlayerId)
	
	var selfData = PlayerLobbyData.new()
	selfData.name = gameData.playerName
	selfData.lobby_type = PlayerType.Random
	
	# Send the new player to the server for distribution,
	# await other player info
	rpc_id(1, 'on_new_player_server', currentPlayerId, selfData.toDTO())

remote func on_new_player_server(newPlayerId: int, playerDataDTO: Dictionary):
	var orderedPlayers = self.gameData.players.keys()
	orderedPlayers.sort()
	
	for playerId in orderedPlayers:
		var existingPlayer = self.gameData.players[playerId]
		rpc_id(newPlayerId, 'on_new_player_client', playerId, existingPlayer.toDTO())
	
	# Register the new player and tell all the new clients about them
	var playerDataReal := PlayerLobbyData.new()
	playerDataReal.fromDTO(playerDataDTO)
	self.gameData.players[newPlayerId] = playerDataReal
	rpc('on_new_player_client', newPlayerId, playerDataDTO)
	emit_signal('new_player_registered', newPlayerId, playerDataReal)

remote func on_new_player_client(newPlayerId: int, playerDataDTO: Dictionary):
	var playerDataReal := PlayerLobbyData.new()
	playerDataReal.fromDTO(playerDataDTO)
	self.gameData.players[newPlayerId] = playerDataReal
	emit_signal('new_player_registered', newPlayerId, playerDataReal)

# 1) A client calls this in their Lobby's _ready() function
func request_lobby_state():
	if not get_tree().is_network_server():
		rpc_id(1, 'send_lobby_state', get_tree().get_network_unique_id())

# 2) The server receives the request to update a client's Lobby
remote func send_lobby_state(id: int):
	# If you send 1 as the ID, it will broadcast the update to all clients
	if id == 1:
		rpc('receive_lobby_state', self.gameData.currentMapId, self.gameData.numGames, self.gameData.sharedSeed)
	else:
		rpc_id(id, 'receive_lobby_state', self.gameData.currentMapId, self.gameData.numGames, self.gameData.sharedSeed)

# 3) The new client receives the lobby state data, and emits a singal
# letting the lobby know the data is ready
remotesync func receive_lobby_state(mapId: int, games: int, sharedSeed: int):
	self.gameData.numGames = games
	self.gameData.currentMapId = mapId
	self.gameData.sharedSeed = sharedSeed
	emit_signal('receive_lobby_state', mapId)

func broadcast_lobby_state():
	if not get_tree().is_network_server():
		return
		
	send_lobby_state(1)

func on_server_disconnect():
	reset_game()

# Update all the clients with the server's state
func broadcast_game_complete():
	if not get_tree().is_network_server():
		return
	
	self.gameData.numGames += 1
	# Generate a new random shared seed for the next game
	self.gameData.sharedSeed = OS.get_unix_time()
	broadcast_all_player_data()
	broadcast_lobby_state()

func reset_game():
	get_tree().network_peer.close_connection()
	# Cleanup all state related to the game session
	self.gameData = GameData.new()
	# Return to the main menu
	# If we have a more legit "game management" class, this could instead signal to that class
	get_tree().change_scene('res://screens/mainmenu/MainMenu.tscn')

func enable_upnp():
	if upnp.get_device_count() > 0:
		upnp.add_port_mapping(DEFAULT_PORT)

func disable_upnp():
	if upnp.get_device_count() > 0:
		upnp.delete_port_mapping(DEFAULT_PORT)

func get_external_ip() -> String:
	if upnp.get_device_count() > 0:
		return upnp.query_external_address()
	else:
		return ''
