extends Node2D

onready var detectionLabel : Label = $CanvasLayer/TestDetectionLabel
onready var players := $players
onready var timer := $Timer
onready var winZone : Area2D = $WinZone

var gameOver : bool = false
var winner : int = Network.PlayerType.Unset

func _ready():
	detectionLabel.hide()
	pre_configure_game()
	
func pre_configure_game():
	get_tree().set_pause(true)
	create_players(Network.players)
	rpc_id(1, "done_preconfiguring", get_tree().get_network_unique_id())
	
var players_done = []

remotesync func done_preconfiguring(playerIdDone):
	assert(get_tree().is_network_server())
	assert(not playerIdDone in players_done) # Was not added yet
	
	players_done.append(playerIdDone)
	
	print("%d players registered, %d total" % [players_done.size(), Network.players.keys().size()])
	
	if (players_done.size() == Network.players.keys().size()):
		print("*** UNPAUSING ***")
		rpc("post_configure_game")

remotesync func post_configure_game():
	get_tree().set_pause(false)
	timer.start()
	print("*** UNPAUSED ***")

func create_players(players: Dictionary):
	# Make sure players are spawned in order on every client,
	# or else their positions might misalign
	var playerIds := players.keys()
	playerIds.sort()
	
	for player_id in playerIds:
		var player = players[player_id]
		
		var playerNode: Player
		match player.type:
			Network.PlayerType.Seeker:
				playerNode = create_seeker(player_id, player)
			Network.PlayerType.Hider:
				playerNode = create_hider(player_id, player)
		
		# If this is our current player, set the node as such
		if get_tree().get_network_unique_id() == player_id:
			playerNode.set_current_player()

var seekersCount = 0

func create_seeker(id, player) -> Player:
	var scene = preload("res://actors/seeker/Seeker.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.global_position = Vector2(200 + (seekersCount * 200), 470 - (seekersCount * 200))
	
	seekersCount = seekersCount + 1
	players.add_child(node)
	
	return node

var hidersCount = 0

func create_hider(id, player) -> Player:
	var scene = preload("res://actors/hider/Hider.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.global_position = Vector2(480, 290 - (hidersCount * 200))
	hidersCount = hidersCount + 1
	
	players.add_child(node)
	
	return node

# warning-ignore:unused_argument
func _physics_process(delta):
	if (!self.gameOver):
		checkForFoundHiders()
		handleBeginGameTimer()
		checkWinConditions()
	
func handleBeginGameTimer():
	if (self.timer.time_left > 0.0):
		$CanvasLayer/TimerLabel.text = "Starting game in %d..." % self.timer.time_left

func checkForFoundHiders():
	var anySeen := false
	
	var seekers = get_tree().get_nodes_in_group("seekers")
	for seeker in seekers:
		# Process each hider, find if any have been seen
		var hiders = get_tree().get_nodes_in_group("hiders")
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
	var hiders = get_tree().get_nodes_in_group("hiders")
	for hiderNode in hiders:
		var hider: Hider = hiderNode
		if (!hider.frozen):
			allHidersFrozen = false
			# Now, check if this hider is in the win zone.
			if (!winZone.overlaps_area(hider)):
				allUnfrozenSeekersInWinZone = false
	
	if (allHidersFrozen):
		handleSeekerWin()
	elif (allUnfrozenSeekersInWinZone):
		handleHiderWin()

func handleSeekerWin():
	self.gameOver = true
	self.winner = Network.PlayerType.Seeker
	detectionLabel.text = "Seekers win!"
	detectionLabel.show()
	
func handleHiderWin():
	self.gameOver = true
	self.winner = Network.PlayerType.Hider
	detectionLabel.text = "Hiders win!"
	detectionLabel.show()

func _on_WinZone_body_entered(body):
	pass

func _on_Timer_timeout():
	var seekers = get_tree().get_nodes_in_group("seekers")
	for seekerNode in seekers:
		var seeker: Seeker = seekerNode
		seeker.unfreeze()
	$CanvasLayer/TimerLabel.hide()
