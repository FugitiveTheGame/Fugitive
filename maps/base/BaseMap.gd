extends Node2D

export (NodePath) var playersPath: NodePath
onready var players := get_node(playersPath)

export (NodePath) var gracePeriodTimerPath: NodePath
onready var gracePeriodTimer := get_node(gracePeriodTimerPath)

export (NodePath) var winZonePath: NodePath
onready var winZone : Area2D = get_node(winZonePath)

export (NodePath) var gameTimerPath: NodePath
onready var gameTimer := get_node(gameTimerPath)

export (NodePath) var gameTimerLabelPath: NodePath
onready var gameTimerLabel := get_node(gameTimerLabelPath)

export (NodePath) var playerHudPath: NodePath
onready var playerHud := get_node(playerHudPath)

export (NodePath) var staminaBarPath: NodePath
onready var staminaBar := get_node(staminaBarPath)

export (NodePath) var visibilityBarPath: NodePath
onready var visibilityBar := get_node(visibilityBarPath)

export (NodePath) var visibilityContainerPath: NodePath
onready var visibilityContainer := get_node(visibilityContainerPath)

export (NodePath) var safeZoneLabelPath: NodePath
onready var safeZoneLabel := get_node(safeZoneLabelPath)

export (NodePath) var lockCarButtonPath: NodePath
onready var lockCarButton := get_node(lockCarButtonPath)

export (NodePath) var carHornButtonPath: NodePath
onready var carHornButton := get_node(carHornButtonPath)

export (NodePath) var useButtonPath: NodePath
onready var useButton := get_node(useButtonPath)

export (NodePath) var pregameCameraPath: NodePath
onready var pregameCamera := get_node(pregameCameraPath)

export (NodePath) var gameStartTimerPath: NodePath
onready var gameStartTimer := get_node(gameStartTimerPath)

export (NodePath) var gameStartLabelPath: NodePath
onready var gameStartLabel := get_node(gameStartLabelPath)

export (NodePath) var winZonePregamePath: NodePath
onready var winZonePregame := get_node(winZonePregamePath)

export (NodePath) var pregameTeamLabelPath: NodePath
onready var pregameTeamLabel := get_node(pregameTeamLabelPath)

export (NodePath) var graceTimerLabelPath: NodePath
onready var graceTimerLabel := get_node(graceTimerLabelPath)

export (NodePath) var playerSummaryPath: NodePath
onready var playerSummary := get_node(playerSummaryPath)

export (NodePath) var gameOverDialogPath: NodePath
onready var gameOverDialog := get_node(gameOverDialogPath)

export (NodePath) var winnerLabelPath: NodePath
onready var winnerLabel := get_node(winnerLabelPath)

export (NodePath) var seekerReleaseAudioPath: NodePath
onready var seekerReleaseAudio := get_node(seekerReleaseAudioPath)

var gameOver : bool = false
var winner : int = Network.PlayerType.Random
var currentPlayer: Player

var players_done = []

func _ready():
	Network.connect("player_removed", self, "player_removed")
	
	playerHud.hide()
	pre_configure_game()

func pre_configure_game():
	get_tree().set_pause(true)
	
	print('shared seed: ' + str(Network.gameData.sharedSeed))
	# Reset the random seed for the pre-config setup
	seed(Network.gameData.sharedSeed)
	
	create_players(Network.gameData.players)
	
	# Randomly enable sensors
	var sensors = get_tree().get_nodes_in_group(Groups.MOTION_SENSORS)
	for sensor in sensors:
		# Random chance of being enabled
		if randi() % 6 == 0:
			sensor.set_enabled(true)
		else:
			sensor.set_enabled(false)
	
	# Configure the HUD for this player
	staminaBar.max_value = currentPlayer.max_stamina
	
	rpc_id(1, "done_preconfiguring", get_tree().get_network_unique_id())

remotesync func done_preconfiguring(playerIdDone):
	if not get_tree().is_network_server():
		return

	assert(not playerIdDone in players_done) # Was not added yet
	
	players_done.append(playerIdDone)
	
	print("%d players registered, %d total" % [players_done.size(), Network.gameData.players.keys().size()])
	
	if (players_done.size() == Network.gameData.players.keys().size()):
		var startTime = OS.get_unix_time() + gameStartTimer.wait_time
		print('start at: ' + str(startTime))
		rpc("post_configure_game", startTime)

remotesync func post_configure_game(startTime: int):
	get_tree().set_pause(false)
	pregameCamera.current = true
	
	winZonePregame.show()
	
	gameStartLabel.show()
	
	match currentPlayer._get_player_node_type():
		Network.PlayerType.Seeker:
			pregameTeamLabel.text = 'You are a Cop'
		Network.PlayerType.Hider:
			pregameTeamLabel.text = 'You are a Fugitive'
	
	pregameTeamLabel.show()
	
	gameStartTimer.start(startTime)
	print("*** UNPAUSED ***")

func create_players(newPlayers: Dictionary):
	# Make sure players are spawned in order on every client,
	# or else their positions might misalign
	var playerIds := newPlayers.keys()
	playerIds.sort()
	
	var seekerSpawns = get_tree().get_nodes_in_group(SpawnPoint.SEEKER_SPAWN)
	var hiderSpawns = get_tree().get_nodes_in_group(SpawnPoint.HIDER_SPAWN)
	
	seekerSpawns.shuffle()
	hiderSpawns.shuffle()
	
	for player_id in playerIds:
		var player = newPlayers[player_id]
		
		var playerNode: Player
		match player.assigned_type:
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
	if currentPlayer is Hider:
		currentPlayer.connect('current_player_hider_frozen', self, 'go_to_spectator_view')

func go_to_spectator_view():
	pregameCamera.current = true

# warning-ignore:unused_argument
func _process(delta: float):
	if (not self.gameOver):
		checkForFoundHiders()
		checkWinConditions()
		updateGameTimer()
		updateStartTimer()
		handleGraceTimer()
		updatePlayerHud()

func updatePlayerHud():
	staminaBar.value = currentPlayer.stamina
	
	# Handle dynamic touch screen UI
	if OS.has_touchscreen_ui_hint():
		if currentPlayer.car != null and currentPlayer.car.driver == currentPlayer:
			if not carHornButton.visible:
				carHornButton.show()
		elif carHornButton.visible:
			carHornButton.hide()
		
		if currentPlayer.car == null :
			var car = currentPlayer.find_car_inrange()
			
			if car != null:
				if not useButton.visible:
					useButton.show()
			elif useButton.visible:
				useButton.hide()
			
			if currentPlayer._get_player_node_type() == Network.PlayerType.Seeker and currentPlayer.can_lock_car(car):
				if not lockCarButton.visible:
					lockCarButton.show()
			elif lockCarButton.visible:
				lockCarButton.hide()
	
	if currentPlayer._get_player_node_type() == Network.PlayerType.Hider:
		visibilityBar.value = currentPlayer.current_visibility * 100.0
		
		var safeLabelShowing = safeZoneLabel.is_visible_in_tree()
		if winZone.overlaps_body(currentPlayer):
			if not safeLabelShowing:
				safeZoneLabel.show()
		elif safeLabelShowing:
			safeZoneLabel.hide()

func handleGraceTimer():
	if not gracePeriodTimer.is_stopped():
		graceTimerLabel.text = "Cops released in %d..." % self.gracePeriodTimer.time_left

func updateStartTimer():
	if not gameStartTimer.is_stopped():
		var sec = gameStartTimer.time_left as int
		gameStartLabel.text = "Starting in %d" % sec

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
	
	var curPlayerType = currentPlayer._get_player_node_type()
	
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
	get_tree().paused = true
	self.gameOver = true
	
	gameTimer.stop()
	
	if seekersWon:
		self.winner = Network.PlayerType.Seeker
		winnerLabel.text = "Cops win!"
	else:
		self.winner = Network.PlayerType.Hider
		winnerLabel.text = "Fugitives win!"
	
	var currentPlayerId := Network.get_current_player_id()
	var statsForCurrentPlayer := PlayerStats.new()
	
	# Seeker section label
	var summaryBbcode: String
	summaryBbcode = "[u]Cops:[/u]\n"
	
	# Print stats for Seeker players
	var seekers := get_tree().get_nodes_in_group(Groups.SEEKERS)
	for seeker in seekers:
		var playerId = seeker.get_network_master()
		var playerData = Network.gameData.players[playerId]
		
		playerData.stats.seeker_captures += seeker.num_captures
		
		if (playerId == currentPlayerId):
			statsForCurrentPlayer.seeker_captures += seeker.num_captures
		
		summaryBbcode += "  %s - %d captures\n" % [playerData.name, seeker.num_captures]
	
	summaryBbcode += "\n\n"
	
	# Hider section label
	summaryBbcode += "[u]Fugitives:[/u]\n"
	
	# Print stats for Hider players
	var hiders := get_tree().get_nodes_in_group(Groups.HIDERS)
	for hider in hiders:
		var playerId = hider.get_network_master()
		var playerData: PlayerLobbyData = Network.gameData.players[playerId]
		
		var statusText: String
		if hider.frozen:
			playerData.stats.hider_captures += 1
			
			if (playerId == currentPlayerId):
				statsForCurrentPlayer.hider_captures += 1
				
			statusText = 'Captured'
		else:
			playerData.stats.hider_escapes += 1
			
			if (playerId == currentPlayerId):
				statsForCurrentPlayer.hider_escapes += 1
			
			statusText = 'Escaped!'
		
		summaryBbcode += "  %s - [i]%s[/i]\n" % [playerData.name, statusText]
	
	playerSummary.bbcode_text = summaryBbcode
	
	# Save the stats for your own data
	UserData.add_to_stats(statsForCurrentPlayer)
	UserData.save_data()
	
	gameOverDialog.popup_centered()
	
	Network.broadcast_game_complete()

func _on_GracePeriodTimer_timeout():
	var seekers = get_tree().get_nodes_in_group(Groups.SEEKERS)
	for seekerNode in seekers:
		var seeker: Seeker = seekerNode
		seeker.unfreeze()
	
	graceTimerLabel.hide()
	seekerReleaseAudio.play()

func player_removed(player_id: int):
	print('Removing player: %d' % player_id)
	var playerNode = players.get_node(str(player_id))
	
	if (playerNode != null):
		print('Found node for player: %d, removing...' % player_id)
		playerNode.queue_free()

# Pregame has ended, hide all the pregame stuff and show the main phase stuff
func _on_GameStartTimer_timeout():
	gameStartLabel.hide()
	pregameTeamLabel.hide()
	winZonePregame.hide()
	
	playerHud.show()
	if currentPlayer._get_player_node_type() == Network.PlayerType.Hider:
		visibilityContainer.show()
	else:
		visibilityContainer.hide()
	
	gameTimer.start()
	updateGameTimer()
	
	gracePeriodTimer.start()
	graceTimerLabel.show()
	
	currentPlayer.set_current_player()
	
	SignalManager.emit_game_start()

remotesync func go_back_to_lobby():
	get_tree().change_scene('res://screens/lobby/Lobby.tscn')

func _on_GameTimer_timeout():
	if get_tree().is_network_server():
		rpc('end_game', true)

func _on_GameOverDialog_popup_hide():
	back_to_lobby()

func _on_BackToLobbyButton_pressed():
	back_to_lobby()

func back_to_lobby():
	# If the server goes back to lobby, bring everyone
	if get_tree().is_network_server():
		rpc('go_back_to_lobby')
	# If just one person goes back to lobby, they can go and wait for the rest
	else:
		get_tree().change_scene('res://screens/lobby/Lobby.tscn')
