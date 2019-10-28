extends "res://maps/map_00/Map_00.gd"

func _ready():
	# Change this to false to play as a Hider
	var be_seeker := false
	
	var playerData = PlayerLobbyData.new()
	Network.players[1] = playerData
	
	if be_seeker:
		$players/Seeker00.set_current_player()
		$players/Seeker00.set_network_master(1)
		playerData.type = Network.PlayerType.Seeker
		
		$players/Hider00.set_network_master(2)
	else:
		$players/Seeker00.set_network_master(2)
		
		$players/Hider00.set_current_player()
		$players/Hider00.set_network_master(1)
		playerData.type = Network.PlayerType.Hider
	
	$players/Hider01.set_network_master(2)
	
	var peer = NetworkedMultiplayerENet.new()
	assert(peer.create_server(Network.DEFAULT_PORT, Network.MAX_PLAYERS) == OK)
	get_tree().set_network_peer(peer)
	
	self.gracePeriodTimer.wait_time = 0.5
	
	rpc("post_configure_game")

func pre_configure_game():
	# Skip the parent impl, we dont want none of that code in dev
	pass
