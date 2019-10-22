extends "res://maps/map_00/Map_00.gd"

func _ready():
	$players/Seeker00.set_current_player()
	$players/Seeker00.set_network_master(1)
	Network.selfData.type = Network.PlayerType.Seeker
	
	$players/Hider00.set_network_master(2)
	$players/Hider01.set_network_master(2)
	
	var peer = NetworkedMultiplayerENet.new()
	assert(peer.create_server(Network.DEFAULT_PORT, Network.MAX_PLAYERS) == OK)
	get_tree().set_network_peer(peer)
	
	self.gracePeriodTimer.wait_time = 0.5
	
	rpc("post_configure_game")

func pre_configure_game():
	# Skip the parent impl, we dont want none of that code in dev
	pass
