extends Node

onready var joinDialog := $JoinGameDialog
onready var serverIpEditText := $JoinGameDialog/Center/Verticle/ServerIpTextEdit

var playerName: String = ""

func _ready():
	assert(get_tree().connect("connected_to_server", self, "on_server_joined") == OK)
	serverIpEditText.text = UserData.data.last_ip
	
	playerName = UserData.data.user_name
	$CenterContainer/PanelContainer/VBoxContainer/PlayerNameTextEdit.text = playerName

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
	
	joinDialog.popup_centered()

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
