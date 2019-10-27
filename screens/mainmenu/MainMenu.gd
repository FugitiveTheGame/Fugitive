extends Node

onready var joinDialog := $JoinGameDialog
onready var serverIpEditText := $JoinGameDialog/Center/Verticle/ServerIpTextEdit

var playerName: String = ""

func _ready():
	print('test__')
	assert(get_tree().connect("connected_to_server", self, "on_server_joined") == OK)

func _on_HostGameButton_pressed():
	if playerName == "":
		return
	
	var success = Network.hostGame(playerName)
	if success:
		get_tree().change_scene('res://screens/lobby/Lobby.tscn')

func _on_JoinGameButton_pressed():
	if playerName == "":
		return
	
	joinDialog.popup_centered()

func _on_PlayerNameTextEdit_text_changed(text):
	playerName = text

func _on_ConnectButton_pressed():
	joinDialog.hide()
	
	var serverIp: String
	serverIp = serverIpEditText.text
	
	if serverIp == "":
		return
	
	assert(Network.joinGame(playerName, serverIp))

func _on_CancelButton_pressed():
	joinDialog.hide()

func _on_JoinGameDialog_about_to_show():
	serverIpEditText.text = Network.DEFAULT_IP

func on_server_joined():
	assert(get_tree().change_scene('res://screens/lobby/Lobby.tscn') == OK)
