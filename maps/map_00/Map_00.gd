extends Node2D

onready var detectionLabel : Label = $UiLayer/TestDetectionLabel
onready var players := $players
onready var gracePeriodTimer := $GracePeriodTimer
onready var winZone : Area2D = $WinZone

var gameOver : bool = false
var winner : int = Network.PlayerType.Unset
var currentPlayer: Player
var seekersCount = 0
var hidersCount = 0
var players_done = []

func _ready():
	detectionLabel.hide()
	pre_configure_game()

func pre_configure_game():
	get_tree().set_pause(true)
	create_players(Network.players)
	rpc("done_preconfiguring", get_tree().get_network_unique_id())

master func done_preconfiguring(playerIdDone):
	if not get_tree().is_network_server():
		return

	assert(not playerIdDone in players_done) # Was not added yet
	
	players_done.append(playerIdDone)
	
	print("%d players registered, %d total" % [players_done.size(), Network.players.keys().size()])
	
	if (players_done.size() == Network.players.keys().size()):
		print("*** UNPAUSING ***")
		rpc("post_configure_game")

remotesync func post_configure_game():
	get_tree().set_pause(false)
	gracePeriodTimer.start()
	print("*** UNPAUSED ***")

func create_players(newPlayers: Dictionary):
	create_car()
	
	# Make sure players are spawned in order on every client,
	# or else their positions might misalign
	var playerIds := newPlayers.keys()
	playerIds.sort()
	
	for player_id in playerIds:
		var player = newPlayers[player_id]
		
		var playerNode: Player
		match player.type:
			Network.PlayerType.Seeker:
				playerNode = create_seeker(player_id, player)
			Network.PlayerType.Hider:
				playerNode = create_hider(player_id, player)
		
		# If this is our current player, set the node as such
		if get_tree().get_network_unique_id() == player_id:
			set_current_player(playerNode)

func create_car():
	var scene = preload("res://actors/car/Car.tscn")
	var node = scene.instance()
	node.set_name('car_1')
	node.set_network_master(1)
	
	node.global_position = Vector2(240, 320)
	
	players.add_child(node)

func create_seeker(id: int, player: Object) -> Player:
	var scene = preload("res://actors/seeker/Seeker.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.playerName = player.name
	node.global_position = Vector2(200 + (seekersCount * 200), 470 - (seekersCount * 200))
	
	seekersCount = seekersCount + 1
	players.add_child(node)
	
	return node

func create_hider(id: int, player: Object) -> Player:
	var scene = preload("res://actors/hider/Hider.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.playerName = player.name
	node.global_position = Vector2(480, 290 - (hidersCount * 200))
	hidersCount = hidersCount + 1
	
	players.add_child(node)
	
	return node

func set_current_player(playerNode: Player):
	currentPlayer = playerNode
	playerNode.set_current_player()

# warning-ignore:unused_argument
func _process(delta: float):
	if (not self.gameOver):
		checkForFoundHiders()
		handleBeginGameTimer()
		checkWinConditions()

func handleBeginGameTimer():
	if (self.gracePeriodTimer.time_left > 0.0):
		$UiLayer/TimerLabel.text = "Starting game in %d..." % self.gracePeriodTimer.time_left
	else:
		$UiLayer/TimerLabel.hide()

func checkForFoundHiders():
	var anySeen := false
	
	var seekers = get_tree().get_nodes_in_group(Seeker.GROUP)
	for seeker in seekers:
		# Process each hider, find if any have been seen
		var hiders = get_tree().get_nodes_in_group(Hider.GROUP)
		for hider in hiders:
			if(seeker.process_hider(hider)):
				anySeen = true
				break
		if (anySeen):
			break
	
	# Debug: show the label if any hiders were seen
	if(anySeen):
		detectionLabel.show()
	else:
		detectionLabel.hide()

func checkWinConditions():
	var allHidersFrozen := true
	var allUnfrozenSeekersInWinZone := true
	var hiders = get_tree().get_nodes_in_group(Hider.GROUP)
	for hiderNode in hiders:
		var hider: Hider = hiderNode
		if (!hider.frozen):
			allHidersFrozen = false
			# Now, check if this hider is in the win zone.
			if (!winZone.overlaps_body(hider)):
				allUnfrozenSeekersInWinZone = false
	
	if allHidersFrozen or allUnfrozenSeekersInWinZone:
		self.gameOver = true
		
		for child in players.get_children():
			players.remove_child(child)
		
		if (allHidersFrozen):
			self.winner = Network.PlayerType.Seeker
			$UiLayer/GameOverDialog/VBoxContainer/WinnerLabel.text = "Seekers win!"
		elif (allUnfrozenSeekersInWinZone):
			self.winner = Network.PlayerType.Hider
			$UiLayer/GameOverDialog/VBoxContainer/WinnerLabel.text = "Hiders win!"
		$UiLayer/GameOverDialog.popup_centered()

func _on_GracePeriodTimer_timeout():
	var seekers = get_tree().get_nodes_in_group(Seeker.GROUP)
	for seekerNode in seekers:
		var seeker: Seeker = seekerNode
		seeker.unfreeze()
		
	var cars = get_tree().get_nodes_in_group(Car.GROUP)
	for car in cars:
		car.locked = false
	
	$UiLayer/TimerLabel.hide()

func _on_BackToLobbyButton_pressed():
	get_tree().change_scene('res://screens/lobby/Lobby.tscn')
