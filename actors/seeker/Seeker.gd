extends Player
class_name Seeker

const GROUP = 'seekers'

onready var seeker_ray_caster := $RayCast2D

var cone_width = deg2rad(45.0)
var max_detect_distance := 100.0

func _get_player_group() -> String:
	return GROUP

func _ready():
	._ready()
	self.freeze()

# Detect if a particular hider has been seen by the seeker
# Change the visibility of the Hider depending on if the
# seeker can see them.
func process_hider(hider: Hider) -> bool:
	var isSeen = false
	
	# Cast a ray between the seeker and this hider
	var look_vec = to_local(hider.global_position)
	seeker_ray_caster.cast_to = look_vec
	seeker_ray_caster.force_raycast_update()
	
	# Calculate the angle of this ray from the cetner of the Seeker's FOV
	var look_angle = atan2(look_vec.y, look_vec.x)
	
	# Only if ray is colliding. If it's not, and we try to do logic,
	# wierd stuff happens
	if(seeker_ray_caster.is_colliding()):
		var bodySeen = seeker_ray_caster.get_collider()
		
		# If the ray hits a wall or something else first, then this Hider is fully occluded
		if(bodySeen == hider):
			# Distance between Hider and Seeker
			var distance = global_position.distance_to(hider.global_position)
			
			# To be detected, the Hider must be inside the Seeker's FOV cone.
			#
			# Some extra game logic for distance, should have to be some what close to "detect"
			# the Hider for gameplay purposes
			if(look_angle < cone_width and look_angle  > -cone_width and distance <= max_detect_distance):
				isSeen = true
				# Don't allow capture while in a car
				if self.car == null:
					hider.freeze()
			
			if (Network.selfData.type == Network.PlayerType.Seeker):
				# If hider is in the center of Seeker's FOV, they are fully visible
				# otherwise, they will gradually fade out the further out to the edges
				# of the FOV they are. Outside the FOV cone, they are invisible.
				var percent_visible = 1.0 - clamp(abs(look_angle / cone_width), 0.0, 1.0)
				hider.modulate.a = percent_visible
				#print("visible: %f" % percent_visible)
		else:
			if (Network.selfData.type == Network.PlayerType.Seeker):
				hider.modulate.a = 0.0
	# This makes sense to me, but if we add it, the Hider flickers like crazy... why...
	#else:
		#hider.modulate.a = 0.0
	
	return isSeen
