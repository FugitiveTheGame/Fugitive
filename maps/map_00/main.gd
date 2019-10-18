extends Node2D

onready var detectionLabel := get_node("TestDetectionLabel")
onready var seeker := get_node("seeker")
onready var seeker_ray_caster := get_node("seeker/RayCast2D")

var cone_width = deg2rad(45.0)
var max_detect_distance := 300.0

func _ready():
	detectionLabel.hide()

func _physics_process(delta):
	var anySeen := false
	
	var hiders = get_tree().get_nodes_in_group("hiders")
	for hider in hiders:
		if(process_hider(hider)):
			anySeen = true
	
	if(anySeen):
		detectionLabel.show()
	else:
		detectionLabel.hide()

func process_hider(hider) -> bool:
	var isSeen = false
	
	var look_vec = seeker.to_local(hider.rect_global_position)
	seeker_ray_caster.cast_to = look_vec
	
	var look_angle = atan2(look_vec.y, look_vec.x)
	seeker_ray_caster.force_raycast_update()
	if(seeker_ray_caster.is_colliding()):
		var bodySeen = seeker_ray_caster.get_collider()
		var distance = seeker.global_position.distance_to(hider.rect_global_position)
		var hiderBody = hider.get_node("Body")
		
		if(bodySeen == hiderBody):
			var percent_visible = 1.0 - clamp(abs(look_angle / cone_width), 0.0, 1.0)
			hider.modulate.a = percent_visible
			#print("visible: %f" % percent_visible)
			
			if(look_angle < cone_width
					and look_angle  > -cone_width
					and distance <= max_detect_distance):
				isSeen = true
		else:
			hider.modulate.a = 0.0
	
	return isSeen