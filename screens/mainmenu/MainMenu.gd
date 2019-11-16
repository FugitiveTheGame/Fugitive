extends Node

onready var joinDialog := $UiLayer/JoinGameDialog
onready var serverIpEditText := $UiLayer/JoinGameDialog/CenterContainer/Verticle/ServerIpTextEdit
onready var serverListContainer := $UiLayer/ServerListContainer
onready var serverList := $UiLayer/ServerListContainer/VBoxContainer/ScrollContainer/ServerList

export (NodePath) var joiningDialogPath: NodePath
onready var joiningDialog: WindowDialog = get_node(joiningDialogPath)

export (NodePath) var joinFailedDialogPath: NodePath
onready var joinFailedDialog: AcceptDialog = get_node(joinFailedDialogPath)

export (NodePath) var hostFailedDialogPath: NodePath
onready var hostFailedDialog: AcceptDialog = get_node(hostFailedDialogPath)

var playerName: String = ""

func _init():
	# window doesn't center properly on startup on HiDPI screens without explicitly calling this
	OS.center_window()

func _ready():
	# Maps pause the game when they end, we need to re-enable them
	get_tree().paused = false
	
	get_tree().connect("connected_to_server", self, "on_server_joined")
	get_tree().connect("connection_failed", self, "connection_failed")
	get_tree().connect("network_peer_disconnected", self, "network_peer_disconnected")
	get_tree().connect("server_disconnected", self, "server_disconnected")
	
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
		join_game(playerName, serverIpEditText.text)
	else:
		serverIpEditText.text = UserData.data.last_ip
		playerName = UserData.data.user_name
		
	joiningDialog.get_close_button().hide()
		
	$UiLayer/PanelContainer/VBoxContainer/PlayerNameTextEdit.text = playerName
	$UiLayer/GameVersionLabel.text = "v%s" % UserData.GAME_VERSION
	$UiLayer/PanelContainer/VBoxContainer/StatsReadoutContainer/GridContainer/LabelCaptures.text = str(UserData.data.lifetime_stats.seeker_captures)
	$UiLayer/PanelContainer/VBoxContainer/StatsReadoutContainer/GridContainer/LabelEscapes.text = str(UserData.data.lifetime_stats.hider_escapes)
	$UiLayer/PanelContainer/VBoxContainer/StatsReadoutContainer/GridContainer/LabelCaptured.text = str(UserData.data.lifetime_stats.hider_captures)

func _exit_tree():
	# Save any user data that changed
	UserData.data.last_ip = serverIpEditText.text
	UserData.data.user_name = playerName
	UserData.save_data()
	
	joiningDialog.hide()

func _on_HostGameButton_pressed():
	if playerName == "":
		return
	
	var success = Network.host_game(playerName)
	if success:
		get_tree().change_scene('res://screens/lobby/Lobby.tscn')
	else:
		Network.reset_game()
		hostFailedDialog.show()

func _on_JoinGameButton_pressed():
	if playerName == "":
		return
	
	joinDialog.popup()

func _on_PlayerNameTextEdit_text_changed(text):
	playerName = text

func _on_ConnectButton_pressed():
	self.joinDialog.hide()
	
	var serverIp: String
	serverIp = serverIpEditText.text
	
	if serverIp == "":
		joinFailedDialog.show()
	else:
		self.joiningDialog.show()
		join_game(playerName, serverIp)

func _on_CancelButton_pressed():
	joinDialog.hide()

func on_server_joined():
	print("JOINED SERVER")
	get_tree().change_scene('res://screens/lobby/Lobby.tscn')

func connection_failed():
	print("CONNECTION FAILED")

func network_peer_disconnected(id: int):
	print("PEER %d DISCONNECTED" % id)

func server_disconnected():
	print("SERVER DISCONNECTED")

func _on_HelpButton_pressed():
	var scene = preload("res://help/Help.tscn")
	var node = scene.instance()
	$UiLayer.add_child(node)
	node.popup_centered()

func _on_ExploreButton_pressed():
	get_tree().change_scene("res://maps/map_01/Explore.tscn")

func prepare_background():
	var seekers = get_tree().get_nodes_in_group(Groups.SEEKERS)
	
	for seeker in seekers:
		seeker.get_node('LockProgressBar').hide()

func join_game(playerName: String, serverIp: String, serverPort: int = Network.DEFAULT_PORT):
	
	if Network.join_game(playerName, serverIp, serverPort):
		joiningDialog.show()
	else:
		joinFailedDialog.show()

func on_join_server_request(serverIp: String, serverPort: int):
	if playerName == "":
		return
	
	join_game(playerName, serverIp, serverPort)

func _on_ServerListener_new_server(serverInfo):
	var scene = preload('res://screens/mainmenu/LanServer.tscn')
	
	var server := scene.instance() as LanServer
	server.populate(serverInfo.name, serverInfo.ip, serverInfo.port, serverInfo.players, serverInfo.numGames)
	server.connect('join_server', self, 'on_join_server_request')
	serverList.add_child(server)
	
	serverListContainer.show()

func _on_ServerListener_remove_server(serverIp: String):
	for child in serverList.get_children():
		if child.serverIp == serverIp:
			serverList.remove_child(child)
			break
	
	if serverList.get_child_count() == 0:
		serverListContainer.hide()

func _on_CancelJoiningButton_pressed():
	Network.reset_game()
	self.joiningDialog.hide()
