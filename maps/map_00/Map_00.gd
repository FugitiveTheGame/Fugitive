extends Node2D

onready var detectionLabel := get_node("TestDetectionLabel")
onready var players := $players


func _ready():
	detectionLabel.hide()
	create_players(Network.players)

func create_players(players: Dictionary):
	# Make sure players are spawned in order on every client,
	# or else their positions might misalign
	var playerIds := players.keys()
	playerIds.sort()
	
	for player_id in playerIds:
		var player = players[player_id]
		match player.type:
			Network.PlayerType.Seeker:
				create_seeker(player_id, player)
			Network.PlayerType.Hider:
				create_hider(player_id, player)

var seekersCount = 0

func create_seeker(id, player):
	var scene = preload("res://actors/seeker/Seeker.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.global_position = Vector2(200 + (seekersCount * 200), 470 - (seekersCount * 200))
	seekersCount = seekersCount + 1
	players.add_child(node)

var hidersCount = 0

func create_hider(id, player):
	var scene = preload("res://actors/hider/Hider.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.global_position = Vector2(480, 290 - (hidersCount * 200))
	hidersCount = hidersCount + 1
	
	players.add_child(node)

# warning-ignore:unused_argument
func _physics_process(delta):
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

