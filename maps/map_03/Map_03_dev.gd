extends "res://maps/base/BaseMap.gd"

func _ready():
	#._ready() # We want to override ready and NOT call the base impl!
	# Change this to false to play as a Hider
	var be_seeker := true
	
	var playerData = PlayerLobbyData.new()
	Network.players[1] = playerData
	
	var playerData2 = PlayerLobbyData.new()
	Network.players[2] = playerData2
	
	# Lower this sound for testing, it's real annoying
	$SeekerReleaseAudio.volume_db = -80
	
	if be_seeker:
		$players/Seeker00.set_current_player()
		$players/Seeker00.set_network_master(1)
		playerData.assigned_type = Network.PlayerType.Seeker
		currentPlayer = $players/Seeker00
		
		$players/Hider00.set_network_master(2)
	else:
		$players/Seeker00.set_network_master(2)
		
		$players/Hider00.set_current_player()
		$players/Hider00.set_network_master(1)
		playerData.assigned_type = Network.PlayerType.Hider
		currentPlayer = $players/Hider00
	
	$players/Hider01.set_network_master(2)
	
	var peer = NetworkedMultiplayerENet.new()
	assert(peer.create_server(Network.DEFAULT_PORT, Network.MAX_PLAYERS) == OK)
	get_tree().set_network_peer(peer)
	
	rpc("post_configure_game")

func pre_configure_game():
	# Skip the parent impl, we dont want none of that code in dev
	pass
