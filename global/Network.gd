extends Node

signal player_updated
signal new_player_registered
signal player_removed

const DEFAULT_IP := '127.0.0.1'
const DEFAULT_PORT := 31400
const MAX_PLAYERS := 5

enum PlayerType {Hider, Seeker, Unset = -1}

var players = {}
var playerName: String

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
	
func on_server_disconnect():
	reset_game()
	
func reset_game():
	get_tree().network_peer.close_connection()
	# Cleanup all state related to the game session
	self.players = {}
	self.playerName = ""
	self.playerStats = {}
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

func enableUpnp():
	if upnp.get_device_count() > 0:
		upnp.add_port_mapping(DEFAULT_PORT)

func disableUpnp():
	if upnp.get_device_count() > 0:
		upnp.delete_port_mapping(DEFAULT_PORT)

func get_external_ip() -> String:
	if upnp.get_device_count() > 0:
		return upnp.query_external_address()
	else:
		return ''
