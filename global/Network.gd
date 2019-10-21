extends Node

signal players_updated

const DEFAULT_IP := '127.0.0.1'
const DEFAULT_PORT := 31400
const MAX_PLAYERS := 5

enum PlayerType {Hider, Seeker, Unset = -1}

var players = {}
var selfData = {
	name = "",
	position = Vector2(),
	type = PlayerType.Unset
}

func _ready():
	assert(get_tree().connect('network_peer_disconnected', self, 'on_player_disconnect') == OK)

func broadcastSetPlayerType(playerId: int, playerType: int):
	rpc('setPlayerType', playerId, playerType)
	
remotesync func setPlayerType(playerId: int, playerType: int):
	self.players[playerId].type = playerType
	emit_signal('players_updated')

func hostGame(playerName: String) -> bool:
	selfData.name = playerName
	selfData.type = PlayerType.Seeker
	players[1] = selfData
	
	var peer = NetworkedMultiplayerENet.new()
	var result = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	
	if result == OK:
		get_tree().set_network_peer(peer)
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
	players.erase(id)
	emit_signal('players_updated')
	
func on_connected_to_server():
	var newPlayerId = get_tree().get_network_unique_id()
	players[newPlayerId] = selfData
	rpc('send_player_info', newPlayerId, selfData)

remote func send_player_info(id, info):
	players[id] = info
	
	# Call this method on all clients, for each client
	if get_tree().is_network_server():
		for player_id in players:
			for playerInfoId in players:
				var playerInfo = players[playerInfoId]
				rpc_id(player_id, 'send_player_info', playerInfoId, playerInfo)
	
	# This is the common code that runs on all clients
	emit_signal('players_updated')	

sync func create_players():
	pass