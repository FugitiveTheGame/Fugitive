extends VBoxContainer
class_name LanServer

signal join_server

var serverName: String
var serverIp: String

func populate(name: String, ip: String):
	self.serverName = name
	self.serverIp = ip
	
	$HBoxContainer/ServerNameLabel.text = self.serverName

func _on_JoinButton_pressed():
	emit_signal("join_server", self.serverIp)
