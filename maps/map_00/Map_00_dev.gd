extends "res://maps/map_00/Map_00.gd"

func _ready():
	$players/Seeker00.set_current_player()

func pre_configure_game():
	var peer = NetworkedMultiplayerENet.new()
	assert(peer.create_server(Network.DEFAULT_PORT, Network.MAX_PLAYERS) == OK)
	get_tree().set_network_peer(peer)
