extends Node2D

onready var players := $players
onready var gracePeriodTimer := $GracePeriodTimer
onready var winZone : Area2D = $WinZone
onready var gameTimerLabel := $UiLayer/GameTimerLabel

var gameOver : bool = false
var winner : int = Network.PlayerType.Unset
var currentPlayer: Player
var seekersCount = 0
var hidersCount = 0
var players_done = []

var gameStartedAt: int

func _ready():
	assert(Network.connect("player_updated", self, "player_updated") == OK)
	assert(Network.connect("new_player_registered", self, "new_player_registered") == OK)
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
		print("*** UNPAUSING ***")
		rpc("post_configure_game")

remotesync func post_configure_game():
	get_tree().set_pause(false)
	gracePeriodTimer.start()
	print("*** UNPAUSED ***")

func create_players(newPlayers: Dictionary):
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
	node.global_position = Vector2(200, 470 - (seekersCount * 200))
	
	seekersCount = seekersCount + 1
	players.add_child(node)
	
	return node

func create_hider(id: int, player: Object) -> Player:
	var scene = preload("res://actors/hider/Hider.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.playerName = player.name
	node.global_position = Vector2(480, 470 - (hidersCount * 200))
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
		updateGameTimer()

func handleBeginGameTimer():
	if (self.gracePeriodTimer.time_left > 0.0):
		$UiLayer/GraceTimerLabel.text = "Starting game in %d..." % self.gracePeriodTimer.time_left
	else:
		$UiLayer/GraceTimerLabel.hide()

func updateGameTimer():
	var secondsSoFar = OS.get_system_time_secs() - gameStartedAt
	
	var minutesSoFar = secondsSoFar / 60
	var remainingSeconds = secondsSoFar - (minutesSoFar * 60)
	
	gameTimerLabel.text = "%d:%02d" % [minutesSoFar, remainingSeconds]

func checkForFoundHiders():
	var anySeen := false
	
	var currentPlayer = Network.get_current_player()
	
	var seekers = get_tree().get_nodes_in_group(Groups.SEEKERS)
	var hiders = get_tree().get_nodes_in_group(Groups.HIDERS)
	
	# Process each hider, find if any have been seen
	for hider in hiders:
		# Re-hide Hiders every frame for Seekers
		if (currentPlayer.type == Network.PlayerType.Seeker):
			if not hider.frozen:
				hider.current_visibility = 0.0
			# Frozen Hiders should always be vizible to Seekers
			else:
				hider.current_visibility = 1.0
		else:
			hider.current_visibility = 0.0
		
		for seeker in seekers:
			if(seeker.process_hider(hider)):
				anySeen = true
				break
	
	# Debug: show the label if any hiders were seen
	#if(anySeen):
		#print('Seeker saw a hider!')

func checkWinConditions():
	# Only the server will end the game
	if not get_tree().is_network_server():
		return
	
	var allHidersFrozen := true
	var allUnfrozenSeekersInWinZone := true
	
	var seekers = get_tree().get_nodes_in_group(Groups.SEEKERS)
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
	
	$UiLayer/GameTimerLabel.hide()
	
	gameStartedAt = OS.get_system_time_secs()
	gameTimerLabel.show()
	updateGameTimer()

func _on_BackToLobbyButton_pressed():
	get_tree().change_scene('res://screens/lobby/Lobby.tscn')

func new_player_registered(player_id: int, player_data: PlayerLobbyData):
	match player_data.type:
		Network.PlayerType.Seeker:
			create_seeker(player_id, player_data)
		Network.PlayerType.Hider:
			create_hider(player_id, player_data)

func player_removed(player_id: int):
	print('Removing player: %d' % player_id)
	var playerNode = players.get_node(str(player_id))
	
	if (playerNode != null):
		print('Found node for player: %d, removing...' % player_id)
		playerNode.queue_free()

func player_updated(player_id: int, player_data: PlayerLobbyData):
	player_removed(player_id)
	new_player_registered(player_id, player_data)
