extends Player
class_name Seeker

onready var seeker_ray_caster := $RayCast2D
onready var win_zones := get_tree().get_nodes_in_group(Groups.WIN_ZONES)

const CONE_WIDTH = deg2rad(45.0)
const MAX_DETECT_DISTANCE := 64.0
const MAX_VISION_DISTANCE := 1000.0
const MIN_VISION_DISTANCE := 800.0

const MOVEMENT_VISIBILITY_PENALTY := 0.01
const SPRINT_VISIBILITY_PENALTY := 0.75

var num_captures := 0

func _get_player_group() -> String:
	return Groups.SEEKERS

func _get_player_node_type() -> int:
	return Network.PlayerType.Seeker

func _ready():
	._ready()
	self.freeze()

func is_in_winzone(hider) -> bool:
	for zone in win_zones:
		if zone.overlaps_body(hider):
			return true
	return false

remotesync func record_capture():
	num_captures += 1

# Detect if a particular hider has been seen by the seeker
# Change the visibility of the Hider depending on if the
# seeker can see them.
func process_hider(hider: Hider):
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
			if(look_angle < CONE_WIDTH and look_angle  > -CONE_WIDTH and distance <= MAX_DETECT_DISTANCE):
				
				# Don't allow capture while in a car, or while in a win zone
				if self.car == null and (not is_in_winzone(hider)):
					# Every client is running this part of the sim
					# But only let the server actually dispatch this very important RPC
					if not hider.frozen and get_tree().is_network_server():
						hider.freeze()
						rpc('record_capture')
			
			############################################
			# Begin visibility calculations
			############################################
			
			# At a given distance, fade the hider out
			var distance_visibility: float
			
			# Hider is too far away, make invisible regardless of FOV visibility
			if distance > MAX_VISION_DISTANCE:
				distance_visibility = 0.0
			# Hider is at the edge of distance visibility, calculate how close to the edge they are
			elif distance > MIN_VISION_DISTANCE:
				var x = distance - MIN_VISION_DISTANCE
				distance_visibility = 1.0 - (x / (MAX_VISION_DISTANCE-MIN_VISION_DISTANCE))
			# Hider is well with-in visible distance, we won't modify the FOV visibility at all
			else:
				distance_visibility = 1.0
			
			# If hider is in the center of Seeker's FOV, they are fully visible
			# otherwise, they will gradually fade out the further out to the edges
			# of the FOV they are. Outside the FOV cone, they are invisible.
			var fov_visibility = 1.0 - clamp(abs(look_angle / CONE_WIDTH), 0.0, 1.0)
			
			# FOV visibility can be faded out if at edge of distance visibility
			var percent_visible = fov_visibility * distance_visibility
			
			# If the hider is moving at all, make them a little visible
			# regaurdless of FOV/Distance
			if hider.is_moving_fast():
				percent_visible += SPRINT_VISIBILITY_PENALTY
			elif hider.is_moving():
				percent_visible += MOVEMENT_VISIBILITY_PENALTY
			percent_visible = clamp(percent_visible, 0.0, 1.0)
			#print("visible: %f" % percent_visible)
			
			# The hider's set visibility method will handle the visible effects of this
			hider.update_visibility(percent_visible)
