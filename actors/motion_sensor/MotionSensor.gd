extends Node2D
class_name MotionSensor

const CONE_WIDTH = deg2rad(25.0)
const CONE_OFFSET = deg2rad(90.0)
const MAX_VISION_DISTANCE := 256.0
const MIN_VISION_DISTANCE := 128.0
const ALL_VISION_DISTANCE := 96.0

onready var rayCaster := $RayCast2D

var is_turned_on := true

func _ready():
	add_to_group(Groups.LIGHTS)
	add_to_group(Groups.MOTION_SENSORS)

func set_enabled(isOn: bool):
	rpc('on_set_enabled', isOn)

remotesync func on_set_enabled(isOn: bool):
	print('Sensor Enabled: ' + str(isOn))
	is_turned_on = isOn

func _on_MotionSensorArea_body_entered(body):
	if is_turned_on and not $Light2D.enabled:
		if get_tree().is_network_server():
			trigger_light()
			rpc('trigger_light')

remote func trigger_light():
	$Light2D.enabled = true
	$LightTriggerAudio.play()
	$AutoOffTimer.start()

func process_hider(hider: Hider):
	# Only process if this sensor is on, and the light is currently on
	if not self.is_turned_on and not $Light2D.enabled:
		return
	
	# Cast a ray between the seeker and this hider
	var look_vec = to_local(hider.global_position)
	var distance = look_vec.length()
	
	# Quick reject, ray casting is slightly expensive, don't do it if we don't have to
	if distance <= MAX_VISION_DISTANCE:
		
		rayCaster.cast_to = look_vec
		rayCaster.force_raycast_update()
		
		if(rayCaster.is_colliding()):
			
			var bodySeen = rayCaster.get_collider()
			# If the ray hits a wall or something else first, then this Hider is fully occluded
			if(bodySeen == hider):
				# If very close to the light, set full visible
				if distance <= ALL_VISION_DISTANCE:
					hider.update_visibility(1.0)
				# Otherwise do normal visibility cone
				else:
					var look_angle = atan2(look_vec.y, look_vec.x) - CONE_OFFSET
					if(look_angle < CONE_WIDTH and look_angle  > -CONE_WIDTH and distance <= MAX_VISION_DISTANCE):
						
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
						
						# If hider is in the center of the FOV, they are fully visible
						# otherwise, they will gradually fade out the further out to the edges
						# of the FOV they are. Outside the FOV cone, they are invisible.
						var fov_visibility = 1.0 - clamp(abs(look_angle / CONE_WIDTH), 0.0, 1.0)
						
						# FOV visibility can be faded out if at edge of distance visibility
						var percent_visible = fov_visibility * distance_visibility
						
						percent_visible = clamp(percent_visible, 0.0, 1.0)
						hider.update_visibility(percent_visible)

func _on_AutoOffTimer_timeout():
	$Light2D.enabled = false
