extends Node

const DEFAULT_IP := "127.0.0.1"
const DEFAULT_PORT := 31004
const MAX_PLAYERS := 5

var players = {}
var selfData = { name = "", position = Vector2() }

func _ready():
	get_tree().connect('network_peer_disconnected', self, 'on_player_disconnect')

func hostGame(playerName: String) -> bool:
	selfData.name = playerName
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
	players[0] = selfData
	
	get_tree().connect('connected_to_server', self, 'on_connected_to_server')
	
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
	
func on_connected_to_server():
	var newPlayerId = get_tree().get_network_unique_id()
	#players[newPlayerId] = selfData
	rpc('send_player_info', newPlayerId, selfData)

remote func send_player_info(id, info):
	# Call on all clients
	if get_tree().is_network_server():
		for player in players:
			rpc_id(player, 'send_player_info', id, info)
	
	players[id] = info