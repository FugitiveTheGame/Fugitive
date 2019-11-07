extends "res://maps/base/BaseMap.gd"

func _enter_tree():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(Network.DEFAULT_PORT, Network.MAX_PLAYERS)
	peer.refuse_new_connections = true
	get_tree().set_network_peer(peer)

func _ready():
	# Change this to false to play as a Hider
	var be_seeker := true
	
	var playerData = PlayerLobbyData.new()
	Network.gameData.players[1] = playerData
	
	# All hiders need their network master set to 2
	var hiders = get_tree().get_nodes_in_group(Groups.HIDERS)
	var i := 1
	for hider in hiders:
		i += 1
		hider.set_network_master(i)
		var data = PlayerLobbyData.new()
		Network.gameData.players[i] = data
	
	if be_seeker:
		$players/Seeker00.set_current_player()
		$players/Seeker00.set_network_master(1)
		playerData.assigned_type = Network.PlayerType.Seeker
		currentPlayer = $players/Seeker00
	else:
		$players/Seeker00.set_network_master(2)
		
		$players/Hider00.set_current_player()
		$players/Hider00.set_network_master(1)
		playerData.assigned_type = Network.PlayerType.Hider
		currentPlayer = $players/Hider00
	
	rpc("post_configure_game")

func pre_configure_game():
	# Skip the parent impl, we dont want none of that code in dev
	pass

func _process(delta):
	var hiders = get_tree().get_nodes_in_group(Groups.HIDERS)
	
	var numHiders : int = hiders.size()
	var numHidersFrozen := 0
	
	for hider in hiders:
		if hider.frozen:
			numHidersFrozen += 1
	
	$UiLayer/HidersLabel.text = "Hiders to be found: %d/%d" % [numHidersFrozen, numHiders]
	
	if numHiders == numHidersFrozen:
		call_deferred('back_to_main_menu')
	
remotesync func end_game(seekersWon: bool):
	back_to_main_menu()

func _on_ExitButton_pressed():
	back_to_main_menu()

func back_to_main_menu():
	Network.reset_game()
	get_tree().change_scene('res://screens/mainmenu/MainMenu.tscn')
