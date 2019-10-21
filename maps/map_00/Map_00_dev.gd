extends "res://maps/map_00/Map_00.gd"

func _ready():
	$players/Seeker00.set_current_player()
	$players/Seeker00.set_network_master(1)
	
	$players/Hider00.set_network_master(2)
	$players/Hider01.set_network_master(2)
	
	var peer = NetworkedMultiplayerENet.new()
	assert(peer.create_server(Network.DEFAULT_PORT, Network.MAX_PLAYERS) == OK)
	get_tree().set_network_peer(peer)

func pre_configure_game():
	pass
