extends Node2D

onready var players := $players
onready var gracePeriodTimer := $GracePeriodTimer
onready var winZone : Area2D = $WinZone
onready var gameTimer := $GameTimer
onready var gameTimerLabel := $UiLayer/GameTimerLabel

var gameOver : bool = false
var winner : int = Network.PlayerType.Unset
var currentPlayer: Player

var players_done = []

func _ready():
	assert(Network.connect("player_removed", self, "player_removed") == OK)
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
		rpc("post_configure_game")

remotesync func post_configure_game():
	get_tree().set_pause(false)
	$PregameCamera.current = true
	print("*** UNPAUSED ***")

func create_players(newPlayers: Dictionary):
	# Make sure players are spawned in order on every client,
	# or else their positions might misalign
	var playerIds := newPlayers.keys()
	playerIds.sort()
	
	var seekerSpawns = get_tree().get_nodes_in_group(SpawnPoint.SEEKER_SPAWN)
	var hiderSpawns = get_tree().get_nodes_in_group(SpawnPoint.HIDER_SPAWN)
	
	for player_id in playerIds:
		var player = newPlayers[player_id]
		
		var playerNode: Player
		match player.type:
			Network.PlayerType.Seeker:
				playerNode = create_seeker(player_id, player, seekerSpawns.pop_front().global_position)
			Network.PlayerType.Hider:
				playerNode = create_hider(player_id, player, hiderSpawns.pop_front().global_position)
		
		# If this is our current player, set the node as such
		if get_tree().get_network_unique_id() == player_id:
			set_current_player(playerNode)

func create_seeker(id: int, player: Object, spawnPoint: Vector2) -> Player:
	var scene = preload("res://actors/seeker/Seeker.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.playerName = player.name
	node.global_position = spawnPoint
	
	players.add_child(node)
	
	return node

func create_hider(id: int, player: Object, spawnPoint: Vector2) -> Player:
	var scene = preload("res://actors/hider/Hider.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.playerName = player.name
	node.global_position = spawnPoint
	
	players.add_child(node)
	
	return node

func set_current_player(playerNode: Player):
	currentPlayer = playerNode
	playerNode.set_current_player()

# warning-ignore:unused_argument
func _process(delta: float):
	if (not self.gameOver):
		checkForFoundHiders()
		checkWinConditions()
		updateGameTimer()
		updateStartTimer()
		handleGraceTimer()

func handleGraceTimer():
	if not gracePeriodTimer.is_stopped():
		$UiLayer/GraceTimerLabel.text = "Seekers released in %d..." % self.gracePeriodTimer.time_left

func updateStartTimer():
	if not $GameStartTimer.is_stopped():
		var sec = $GameStartTimer.time_left as int
		$UiLayer/GameStartLabel.text = "Starting in %d" % sec

func updateGameTimer():
	if not gameTimer.is_stopped():
		var secondsLeft: int = gameTimer.time_left as int
		secondsLeft = max(secondsLeft, 0.0) as int
		
		var minutesLeft: int = secondsLeft / 60
		var remainingSeconds: int = secondsLeft - (minutesLeft * 60)
		
		gameTimerLabel.text = "%d:%02d" % [minutesLeft, remainingSeconds]

func checkForFoundHiders():
	var seekers = get_tree().get_nodes_in_group(Groups.SEEKERS)
	var hiders = get_tree().get_nodes_in_group(Groups.HIDERS)
	var lights = get_tree().get_nodes_in_group(Groups.LIGHTS)
	
	var curPlayerType = currentPlayer._get_player_type()
	
	# Process each hider, find if any have been seen
	for hider in hiders:
		# Re-hide Hiders every frame for Seekers
		if (curPlayerType == Network.PlayerType.Seeker):
			if not hider.frozen:
				hider.current_visibility = 0.0
			# Frozen Hiders should always be vizible to Seekers
			else:
				hider.current_visibility = 1.0
		else:
			hider.current_visibility = 0.0
		
		for seeker in seekers:
			seeker.process_hider(hider)
		
		for light in lights:
			light.process_hider(hider)

func checkWinConditions():
	# Only the server will end the game
	if not get_tree().is_network_server():
		return
	
	var allHidersFrozen := true
	var allUnfrozenSeekersInWinZone := true
	
	var hiders = get_tree().get_nodes_in_group(Groups.HIDERS)
	for hiderNode in hiders:
		var hider: Hider = hiderNode
		if (not hider.frozen):
			allHidersFrozen = false
			# Now, check if this hider is in the win zone.
			if (not winZone.overlaps_body(hider)):
				allUnfrozenSeekersInWinZone = false
	
	if allHidersFrozen or allUnfrozenSeekersInWinZone:
		self.gameOver = true # Server should set this immedately so we don't accidentally RPC again
		rpc('end_game', allHidersFrozen)

remotesync func end_game(seekersWon: bool):
	self.gameOver = true
	
	gameTimer.stop()
	
	for child in players.get_children():
		players.remove_child(child)
	
	if seekersWon:
		self.winner = Network.PlayerType.Seeker
		$UiLayer/GameOverDialog/VBoxContainer/WinnerLabel.text = "Seekers win!"
	else:
		self.winner = Network.PlayerType.Hider
		$UiLayer/GameOverDialog/VBoxContainer/WinnerLabel.text = "Hiders win!"
	$UiLayer/GameOverDialog.popup_centered()

func _on_GracePeriodTimer_timeout():
	var seekers = get_tree().get_nodes_in_group(Groups.SEEKERS)
	for seekerNode in seekers:
		var seeker: Seeker = seekerNode
		seeker.unfreeze()
	
	$UiLayer/GraceTimerLabel.hide()

func _on_BackToLobbyButton_pressed():
	assert(get_tree().change_scene('res://screens/lobby/Lobby.tscn') == OK)

func player_removed(player_id: int):
	print('Removing player: %d' % player_id)
	var playerNode = players.get_node(str(player_id))
	
	if (playerNode != null):
		print('Found node for player: %d, removing...' % player_id)
		playerNode.queue_free()

func _on_GameStartTimer_timeout():
	$UiLayer/GameStartLabel.hide()
	
	gameTimer.start()
	gameTimerLabel.show()
	updateGameTimer()
	
	gracePeriodTimer.start()
	$UiLayer/GraceTimerLabel.show()
	
	currentPlayer.set_current_player()
	
	SignalManager.emit_game_start()

func _on_GameTimer_timeout():
	if get_tree().is_network_server():
		rpc('end_game', true)
