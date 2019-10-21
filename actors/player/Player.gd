extends KinematicBody2D
class_name Player

export (int) var speed = 200
export (float) var rotation_speed = 1.5

var velocity = Vector2()
var rotation_dir = 0

puppet func setNetworkPosition(pos: Vector2):
	self.position = pos
	
puppet func setNetworkRotation(rot: float):
	self.rotation = rot
	
func get_input(delta):
	if not is_network_master():
		return
	
	rotation_dir = 0
	velocity = Vector2()
	if Input.is_action_pressed('ui_right'):
		rotation_dir += 1
	if Input.is_action_pressed('ui_left'):
		rotation_dir -= 1
	if Input.is_action_pressed('ui_down'):
		velocity = Vector2(-speed, 0).rotated(rotation)
	if Input.is_action_pressed('ui_up'):
		velocity = Vector2(speed, 0).rotated(rotation)
	
	rotation += rotation_dir * rotation_speed * delta

func _physics_process(delta):
	get_input(delta)
	
	if is_network_master():
		velocity = move_and_slide(velocity)
		
		rpc_unreliable("setNetworkPosition", position)
		rpc_unreliable("setNetworkRotation", rotation)

func set_current_player():
	$Camera.current = true
