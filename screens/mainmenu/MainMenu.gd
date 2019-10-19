extends Control

onready var joinDialog := get_node("JoinGameDialog")
onready var serverIpEditText := get_node("JoinGameDialog/ServerIpTextEdit")

var playerName: String = ""

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
	
	var success = Network.joinGame(serverIp, playerName)
	if success:
		get_tree().change_scene('res://screens/lobby/Lobby.tscn')

func _on_CancelButton_pressed():
	joinDialog.hide()

func _on_JoinGameDialog_about_to_show():
	serverIpEditText.text = Network.DEFAULT_IP
