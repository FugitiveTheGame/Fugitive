extends Node

signal player_updated
signal new_player_registered
signal player_removed
signal send_lobby_state
signal receive_lobby_state

const DEFAULT_IP := '127.0.0.1'
const DEFAULT_PORT := 31400
const MAX_PLAYERS := 5

enum PlayerType {Hider, Seeker, Unset = -1}

var players = {}
var playerName: String
var numGames := 0

onready var upnp = UPNP.new()

func _ready():
	assert(get_tree().connect('connected_to_server', self, 'on_connected_to_server') == OK)
	assert(get_tree().connect('network_peer_disconnected', self, 'on_player_disconnect') == OK)
	assert(get_tree().connect('server_disconnected', self, 'on_server_disconnect') == OK)
	
	# Begin discovery asap
	upnp.discover()

func get_current_player() -> PlayerLobbyData:
	return players[get_current_player_id()]
	
func get_current_player_id() -> int:
	return get_tree().get_network_unique_id();
	
func disconnect_from_game():
	reset_game()

func broadcast_all_player_data():
	# Only the network server can update everyone's player data
	if not get_tree().is_network_server():
		return
	
	for player_id in players:
		var player = players[player_id]
		var dto = player.toDTO()
		rpc('set_player_data', player_id, dto)

remote func set_player_data(playerId: int, playerDto: Dictionary):
	var playerData = player_data_from_DTO(playerDto)
	players[playerId] = playerData
	emit_signal('player_updated', playerId, self.players[playerId])

func broadcast_set_player_type(playerId: int, playerType: int):
	rpc('set_player_type', playerId, playerType)

remotesync func set_player_type(playerId: int, playerType: int):
	self.players[playerId].type = playerType
	emit_signal('player_updated', playerId, self.players[playerId])

func host_game(name: String) -> bool:
	self.playerName = name
	
	var selfData = PlayerLobbyData.new()
	selfData.name = playerName
	selfData.type = PlayerType.Seeker
	players[1] = selfData
	
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
	self.playerName = name
		
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
	self.players.erase(id)
	emit_signal('player_removed', id)
	
func on_connected_to_server():
	var currentPlayerId = get_tree().get_network_unique_id()
	print('Connected.  Assigned to player %d' % currentPlayerId)
	
	var selfData = PlayerLobbyData.new()
	selfData.name = playerName
	selfData.type = PlayerType.Hider
	
	# Send the new player to the server for distribution,
	# await other player info
	rpc_id(1, 'on_new_player_server', currentPlayerId, selfData.toDTO())

remote func on_new_player_server(newPlayerId: int, playerDataDTO: Dictionary):
	var orderedPlayers = self.players.keys()
	orderedPlayers.sort()
	
	for playerId in orderedPlayers:
		var existingPlayer = self.players[playerId]
		rpc_id(newPlayerId, 'on_new_player_client', playerId, existingPlayer.toDTO())
	
	# Register the new player and tell all the new clients about them
	var playerDataReal := player_data_from_DTO(playerDataDTO)
	self.players[newPlayerId] = playerDataReal
	rpc('on_new_player_client', newPlayerId, playerDataDTO)
	emit_signal('new_player_registered', newPlayerId, playerDataReal)

remote func on_new_player_client(newPlayerId: int, playerDataDTO: Dictionary):
	var playerDataReal := player_data_from_DTO(playerDataDTO)
	self.players[newPlayerId] = playerDataReal
	emit_signal('new_player_registered', newPlayerId, playerDataReal)

# 1) A client calls this in their Lobby's _ready() function
func request_lobby_state():
	if not get_tree().is_network_server():
		rpc_id(1, 'send_lobby_state', get_tree().get_network_unique_id())

# 2) The server receives the request, and notifies the server's
# Lobby that it needs to respond
# If you send 1 as the ID, it will broadcast the update to all clients
remote func send_lobby_state(id: int):
	emit_signal('send_lobby_state', id)

# 3) The servers lobby collects the data, and then passes it back here,
# to the Network class so it can be transmitted back to the new client
func update_lobby_state(id: int, mapId: int):
	rpc_id(id, 'receive_lobby_state', mapId, self.numGames)

# 3a) The servers lobby collects the data, and then passes it back here,
# to the Network class so it can be transmitted back to the new client
func broadcast_update_lobby_state(mapId: int):
	rpc('receive_lobby_state', mapId, self.numGames)

# 4) The new client receives the lobby state data, and emits a singal
# letting the lobby know the data is ready
remote func receive_lobby_state(mapId: int, games: int):
	self.numGames = games
	emit_signal('receive_lobby_state', mapId)

func on_server_disconnect():
	reset_game()

# Update all the clients with the server's state
func broadcast_game_complete():
	if not get_tree().is_network_server():
		return
	
	self.numGames += 1
	broadcast_all_player_data()

func reset_game():
	get_tree().network_peer.close_connection()
	# Cleanup all state related to the game session
	self.players = {}
	self.playerName = ""
	self.numGames = 0
	# Return to the main menu
	# If we have a more legit "game management" class, this could instead signal to that class
	assert(get_tree().change_scene('res://screens/mainmenu/MainMenu.tscn') == OK)

static func player_data_from_DTO(dict: Dictionary) -> PlayerLobbyData:
	var result := PlayerLobbyData.new()
	result.name = dict.name
	result.position = dict.position
	result.type = dict.type
	result.stats = dict.stats
	return result

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
