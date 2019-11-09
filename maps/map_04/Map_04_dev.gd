extends "res://maps/base/BaseMap.gd"

func _enter_tree():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(Network.DEFAULT_PORT, Network.MAX_PLAYERS)
	peer.refuse_new_connections = true
	get_tree().set_network_peer(peer)

func _ready():
	# Change this to false to play as a Hider
	var be_seeker := false
	
	var playerData = PlayerLobbyData.new()
	Network.gameData.players[1] = playerData
	
	var playerData2 = PlayerLobbyData.new()
	Network.gameData.players[2] = playerData2
	
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
	
	rpc("post_configure_game")

func pre_configure_game():
	# Skip the parent impl, we dont want none of that code in dev
	pass

remotesync func end_game(seekersWon: bool):
	Network.reset_game()
	get_tree().change_scene('res://screens/mainmenu/MainMenu.tscn')
