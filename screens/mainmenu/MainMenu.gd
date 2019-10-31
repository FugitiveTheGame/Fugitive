extends Node

onready var joinDialog := $JoinGameDialog
onready var serverIpEditText := $JoinGameDialog/CenterContainer/Verticle/ServerIpTextEdit

var playerName: String = ""

func _ready():
	# Maps pause the game when they end, we need to re-enable them
	get_tree().paused = false
	
	assert(get_tree().connect("connected_to_server", self, "on_server_joined") == OK)
	serverIpEditText.text = UserData.data.last_ip
	
	playerName = UserData.data.user_name
	$PanelContainer/VBoxContainer/PlayerNameTextEdit.text = playerName

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
	assert(get_tree().change_scene('res://screens/lobby/Lobby.tscn') == OK)

func _on_HelpButton_pressed():
	var scene = preload("res://help/Help.tscn")
	var node = scene.instance()
	add_child(node)
	node.popup_centered()
