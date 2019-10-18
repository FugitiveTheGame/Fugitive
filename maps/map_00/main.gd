extends Node2D

onready var detectionLabel := get_node("TestDetectionLabel")
onready var seeker := get_node("seeker")
onready var seeker_ray_caster := get_node("seeker/RayCast2D")
onready var hider_00 := get_node("hider_test")
onready var hider_00_colider := hider_00.get_node("Body")
var cone_width = deg2rad(45.0)
var max_detect_distance := 300.0

func _ready():
	detectionLabel.hide()

func _process(delta):
	var look_vec = seeker.to_local(hider_00.rect_global_position)
	seeker_ray_caster.cast_to = look_vec
	
	var look_angle = atan2(look_vec.y, look_vec.x)
	if(seeker_ray_caster.is_colliding()):
		var colliderSeen = seeker_ray_caster.get_collider()
		var distance = seeker.global_position.distance_to(hider_00.rect_global_position)
		
		if(colliderSeen == hider_00_colider
			and look_angle < cone_width
			and look_angle  > -cone_width
			and distance <= max_detect_distance):
				hider_00.show()
				detectionLabel.show()
		else:
			hider_00.hide()
			detectionLabel.hide()