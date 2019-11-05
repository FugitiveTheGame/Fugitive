extends Node

onready var joinDialog := $JoinGameDialog
onready var serverIpEditText := $JoinGameDialog/CenterContainer/Verticle/ServerIpTextEdit

var playerName: String = ""

func _init():
	# window doesn't center properly on startup on HiDPI screens without explicitly calling this
	OS.center_window()

func _ready():
	# Maps pause the game when they end, we need to re-enable them
	get_tree().paused = false
	
	assert(get_tree().connect("connected_to_server", self, "on_server_joined") == OK)
	assert(get_tree().connect("connection_failed", self, "connection_failed") == OK)
	assert(get_tree().connect("network_peer_disconnected", self, "network_peer_disconnected") == OK)
	assert(get_tree().connect("server_disconnected", self, "server_disconnected") == OK)
	
	if OS.is_debug_build():
		$DebugButton.show()
	else:
		$DebugButton.hide()
	
	var args := OS.get_cmdline_args()
	print("Command Line args: %d" % [args.size()])
	if (args.size() > 0):
		for arg in args:
			print("    : %s" % arg)
			var keyValuePair = arg.split("=")
			
			match keyValuePair[0]:
				"--name":
					playerName = keyValuePair[1]
					# Also override the default file save path so each test user has its own settings.
					UserData.file_name = 'user://user_data-%s.json' % playerName
				"--ip":
					serverIpEditText.text = keyValuePair[1]
				_:
					print("UNKNOWN ARGUMENT %s" % keyValuePair[0])
	
	if (args.size() > 0):
		assert(Network.join_game(playerName, serverIpEditText.text))
	else:
		serverIpEditText.text = UserData.data.last_ip
		playerName = UserData.data.user_name
		
	$PanelContainer/VBoxContainer/PlayerNameTextEdit.text = playerName
	$GameVersionLabel.text = "v%s" % UserData.GAME_VERSION
	$PanelContainer/VBoxContainer/StatsReadoutContainer/GridContainer/LabelCaptures.text = str(UserData.data.lifetime_stats.seeker_captures)
	$PanelContainer/VBoxContainer/StatsReadoutContainer/GridContainer/LabelEscapes.text = str(UserData.data.lifetime_stats.hider_escapes)
	$PanelContainer/VBoxContainer/StatsReadoutContainer/GridContainer/LabelCaptured.text = str(UserData.data.lifetime_stats.hider_captures)

func _exit_tree():
	# Save any user data that changed
	UserData.data.last_ip = serverIpEditText.text
	UserData.data.user_name = playerName
	UserData.save_data()

func _on_HostGameButton_pressed():
	if playerName == "":
		return
	
	var success = Network.host_game(playerName)
	if success:
		assert(get_tree().change_scene('res://screens/lobby/Lobby.tscn') == OK)

func _on_JoinGameButton_pressed():
	if playerName == "":
		return
	
	joinDialog.popup()

func _on_PlayerNameTextEdit_text_changed(text):
	playerName = text

func _on_ConnectButton_pressed():
	joinDialog.hide()
	
	var serverIp: String
	serverIp = serverIpEditText.text
	
	if serverIp == "":
		return
	
	assert(Network.join_game(playerName, serverIp))

func _on_CancelButton_pressed():
	joinDialog.hide()

func on_server_joined():
	print("JOINED SERVER")
	assert(get_tree().change_scene('res://screens/lobby/Lobby.tscn') == OK)
	
func connection_failed():
	print("CONNECTION FAILED")

func network_peer_disconnected(id: int):
	print("PEER %d DISCONNECTED" % id)

func server_disconnected():
	print("SERVER DISCONNECTED")

func _on_HelpButton_pressed():
	var scene = preload("res://help/Help.tscn")
	var node = scene.instance()
	add_child(node)
	node.popup_centered()

func _on_DebugButton_pressed():
	assert(get_tree().change_scene("res://maps/map_01/Map_01_dev.tscn") == OK)
