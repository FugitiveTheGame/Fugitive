extends Node

signal player_updated
signal new_player_registered
signal player_removed

const DEFAULT_IP := '127.0.0.1'
const DEFAULT_PORT := 31400
const MAX_PLAYERS := 5

enum PlayerType {Hider, Seeker, Unset = -1}

var players = {}

var selfData : PlayerLobbyData

func _init():
	selfData = PlayerLobbyData.new()

func _ready():
	assert(get_tree().connect('network_peer_disconnected', self, 'on_player_disconnect') == OK)

func broadcastSetPlayerType(playerId: int, playerType: int):
	rpc('setPlayerType', playerId, playerType)
	
remotesync func setPlayerType(playerId: int, playerType: int):
	self.players[playerId].type = playerType
	emit_signal('player_updated', playerId, self.players[playerId])

func hostGame(playerName: String) -> bool:
	selfData.name = playerName
	selfData.type = PlayerType.Seeker
	players[1] = selfData
	
	var peer = NetworkedMultiplayerENet.new()
	var result = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	
	if result == OK:
		get_tree().set_network_peer(peer)
		emit_signal('new_player_registered', 1, selfData)
		return true
	else:
		return false
	
func joinGame(playerName: String, serverIp: String) -> bool:
	selfData.name = playerName
	selfData.type = PlayerType.Hider
	
	assert(get_tree().connect('connected_to_server', self, 'on_connected_to_server') == OK)
	
	var peer = NetworkedMultiplayerENet.new()
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
	var newPlayerId = get_tree().get_network_unique_id()
	
	# Send the new player to the server for distribution,
	# await other player info
	rpc_id(1, 'on_new_player_server', newPlayerId, self.selfData.toDTO())

remote func on_new_player_server(newPlayerId: int, playerDataDTO: Dictionary):
	var orderedPlayers = self.players.keys()
	orderedPlayers.sort()
	
	for playerId in orderedPlayers:
		var existingPlayer = self.players[playerId]
		rpc_id(newPlayerId, 'on_new_player_client', playerId, existingPlayer.toDTO())
		
	# Register the new player and tell all the new clients about them
	var playerDataReal := fromDTO(playerDataDTO)
	self.players[newPlayerId] = playerDataReal
	rpc('on_new_player_client', newPlayerId, playerDataDTO)
	emit_signal('new_player_registered', newPlayerId, playerDataReal)
	
remote func on_new_player_client(newPlayerId: int, playerDataDTO: Dictionary):
	var playerDataReal := fromDTO(playerDataDTO)
	self.players[newPlayerId] = playerDataReal
	emit_signal('new_player_registered', newPlayerId, playerDataReal)

static func fromDTO(dict: Dictionary) -> PlayerLobbyData:
	var result := PlayerLobbyData.new()
	result.name = dict.name
	result.position = dict.position
	result.type = dict.type
	return result
