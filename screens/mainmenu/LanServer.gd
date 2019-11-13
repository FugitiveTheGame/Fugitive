extends VBoxContainer
class_name LanServer, 'res://utilities/server_advertiser/ServerAdvertiser.png'

signal join_server

var serverName: String
var serverIp: String
var serverPort: int
var numPlayers: int
var numGames: int

func populate(name: String, ip: String, port: int, players: int, games: int):
	self.serverName = name
	self.serverIp = ip
	self.serverPort = port
	self.numPlayers = players
	self.numGames = games
	
	$HBoxContainer/ServerNameLabel.text = self.serverName
	$PlayerCountLabel.text = "Players: %d | Game: %d" % [self.numPlayers, self.numGames]

func _on_JoinButton_pressed():
	emit_signal("join_server", self.serverIp, self.serverPort)
