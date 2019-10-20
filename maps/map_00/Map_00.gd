extends Node2D

onready var detectionLabel := get_node("TestDetectionLabel")
onready var players := $players

var cone_width = deg2rad(45.0)
var max_detect_distance := 300.0

func _ready():
	detectionLabel.hide()
	create_players(Network.players)

func create_players(players):
	for player_id in players:
		var player = players[player_id]
		match player.type:
			Network.PlayerType.Seeker:
				create_seeker(player_id, player)
			Network.PlayerType.Hider:
				create_hider(player_id, player)

func create_seeker(id, player):
	var scene = preload("res://actors/seeker/Seeker.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.global_position = Vector2(200, 470)
	
	players.add_child(node)

func create_hider(id, player):
	var scene = preload("res://actors/hider/Hider.tscn")
	var node = scene.instance()
	node.set_name(str(id))
	node.set_network_master(id)
	
	node.global_position = Vector2(480, 290)
	
	players.add_child(node)

# warning-ignore:unused_argument
func _physics_process(delta):
	var anySeen := false
	
	# Process each hider, find if any have been seen
	var hiders = get_tree().get_nodes_in_group("hiders")
	for hider in hiders:
		if(process_hider(hider)):
			anySeen = true
	
	# Debug: show the label if any hiders were seen
	if(anySeen):
		detectionLabel.show()
	else:
		detectionLabel.hide()

# Detect if a particular hider has been seen by the seeker
# Change the visibility of the Hider depending on if the
# seeker can see them.
func process_hider(hider) -> bool:
	var isSeen = false
	"""
	# Cast a ray between the seeker and this hider
	var look_vec = seeker.to_local(hider.rect_global_position)
	seeker_ray_caster.cast_to = look_vec
	seeker_ray_caster.force_raycast_update()
	
	# Calculate the angle of this ray from the cetner of the Seeker's FOV
	var look_angle = atan2(look_vec.y, look_vec.x)
	
	# Only if ray is colliding. If it's not, and we try to do logic,
	# wierd stuff happens
	if(seeker_ray_caster.is_colliding()):
		
		var bodySeen = seeker_ray_caster.get_collider()
		var hiderBody = hider.get_node("Body")
		
		# If the ray hits a wall or something else first, then this Hider is fully occluded
		if(bodySeen == hiderBody):
			# If hider is in the center of Seeker's FOV, they are fully visible
			# otherwise, they will gradually fade out the further out to the edges
			# of the FOV they are. Outside the FOV cone, they are invisible.
			var percent_visible = 1.0 - clamp(abs(look_angle / cone_width), 0.0, 1.0)
			hider.modulate.a = percent_visible
			#print("visible: %f" % percent_visible)
			
			# Distance between Hider and Seeker
			var distance = seeker.global_position.distance_to(hider.rect_global_position)
			
			# To be detected, the Hider must be inside the Seeker's FOV cone.
			#
			# Some extra game logic for distance, should have to be some what close to "detect"
			# the Hider for gameplay purposes
			if(look_angle < cone_width and look_angle  > -cone_width and distance <= max_detect_distance):
				isSeen = true
		else:
			hider.modulate.a = 0.0
	# This makes sense to me, but if we add it, the Hider flickers like crazy... why...
	#else:
		#hider.modulate.a = 0.0
	"""
	
	return isSeen