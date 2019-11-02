extends Node2D

onready var players := $players
onready var gracePeriodTimer := $GracePeriodTimer
onready var winZone : Area2D = $WinZone
onready var gameTimer := $GameTimer
onready var gameTimerLabel := $UiLayer/PlayerHud/GameTimerLabel
onready var playerHud := $UiLayer/PlayerHud
onready var staminaBar := $UiLayer/PlayerHud/StaminaContainer/HBoxContainer/StaminaBar
onready var visibilityBar := $UiLayer/PlayerHud/VisibilityContainer/HBoxContainer/VisibilityBar
onready var visibilityContainer := $UiLayer/PlayerHud/VisibilityContainer
onready var safeZoneLabel := $UiLayer/PlayerHud/SafeZoneLabel

var gameOver : bool = false
var winner : int = Network.PlayerType.Random
var currentPlayer: Player

var players_done = []

func _ready():
	assert(Network.connect("player_removed", self, "player_removed") == OK)
	pre_configure_game()

func pre_configure_game():
	playerHud.hide()
	
	get_tree().set_pause(true)
	create_players(Network.players)
	
	# Configure the HUD for this player
	staminaBar.max_value = currentPlayer.max_stamina
	
	rpc_id(1, "done_preconfiguring", get_tree().get_network_unique_id())

remotesync func done_preconfiguring(playerIdDone):
	if not get_tree().is_network_server():
		return

	assert(not playerIdDone in players_done) # Was not added yet
	
	players_done.append(playerIdDone)
	
	print("%d players registered, %d total" % [players_done.size(), Network.players.keys().size()])
	
	if (players_done.size() == Network.players.keys().size()):
		rpc("post_configure_game")

remotesync func post_configure_game():
	# Server determines if sensors are on or not
	if get_tree().is_network_server():
		var sensors = get_tree().get_nodes_in_group(Groups.MOTION_SENSORS)
		for sensor in sensors:
			# 1 in 4 chance of being enabled
			if Network.random.randi_range(0, 5) == 0:
				sensor.set_enabled(true)
			else:
				sensor.set_enabled(false)
	
	get_tree().set_pause(false)
	$PregameCamera.current = true
	
	$UiLayer/GameStartLabel.show()
	
	match currentPlayer._get_player_node_type():
		Network.PlayerType.Seeker:
			$UiLayer/PregameTeamLabel.text = 'You are a Cop'
		Network.PlayerType.Hider:
			$UiLayer/PregameTeamLabel.text = 'You are a Fugitive'
	
	$UiLayer/PregameTeamLabel.show()
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
		$UiLayer/GraceTimerLabel.text = "Cops released in %d..." % self.gracePeriodTimer.time_left

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
		$UiLayer/GameOverDialog/VBoxContainer/WinnerLabel.text = "Cops win!"
	else:
		self.winner = Network.PlayerType.Hider
		$UiLayer/GameOverDialog/VBoxContainer/WinnerLabel.text = "Fugitives win!"
	
	var currentPlayerId := Network.get_current_player_id()
	var statsForCurrentPlayer := PlayerStats.new()
	
	# Seeker section label
	var summaryBbcode: String
	summaryBbcode = "[u]Cops:[/u]\n"
	
	# Print stats for Seeker players
	var seekers := get_tree().get_nodes_in_group(Groups.SEEKERS)
	for seeker in seekers:
		var playerId = seeker.get_network_master()
		var playerData = Network.players[playerId]
		
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
		var playerData: PlayerLobbyData = Network.players[playerId]
		
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
	
	var playerSummaryContainer = $UiLayer/GameOverDialog/VBoxContainer/PlayerSummary
	playerSummaryContainer.bbcode_text = summaryBbcode
	
	# Save the stats for your own data
	UserData.add_to_stats(statsForCurrentPlayer)
	UserData.save_data()
	
	$UiLayer/GameOverDialog.popup_centered()
	
	Network.broadcast_game_complete()

func _on_GracePeriodTimer_timeout():
	var seekers = get_tree().get_nodes_in_group(Groups.SEEKERS)
	for seekerNode in seekers:
		var seeker: Seeker = seekerNode
		seeker.unfreeze()
	
	$UiLayer/GraceTimerLabel.hide()
	$SeekerReleaseAudio.play()

func _on_BackToLobbyButton_pressed():
	# If the server goes back to lobby, bring everyone
	if get_tree().is_network_server():
		rpc('go_back_to_lobby')
	# If just one person goes back to lobby, they can go and wait for the rest
	else:
		assert(get_tree().change_scene('res://screens/lobby/Lobby.tscn') == OK)

func player_removed(player_id: int):
	print('Removing player: %d' % player_id)
	var playerNode = players.get_node(str(player_id))
	
	if (playerNode != null):
		print('Found node for player: %d, removing...' % player_id)
		playerNode.queue_free()

func _on_GameStartTimer_timeout():
	$UiLayer/GameStartLabel.hide()
	$UiLayer/PregameTeamLabel.hide()
	
	playerHud.show()
	if currentPlayer._get_player_node_type() == Network.PlayerType.Hider:
		visibilityContainer.show()
	else:
		visibilityContainer.hide()
	
	gameTimer.start()
	updateGameTimer()
	
	gracePeriodTimer.start()
	$UiLayer/GraceTimerLabel.show()
	
	currentPlayer.set_current_player()
	
	SignalManager.emit_game_start()

remotesync func go_back_to_lobby():
	assert(get_tree().change_scene('res://screens/lobby/Lobby.tscn') == OK)

func _on_GameTimer_timeout():
	if get_tree().is_network_server():
		rpc('end_game', true)
