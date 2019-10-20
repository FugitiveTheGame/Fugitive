extends KinematicBody2D
class_name Seeker

export (int) var speed = 200
export (float) var rotation_speed = 1.5

var velocity = Vector2()
var rotation_dir = 0

puppet func setVelocity(vel):
  velocity = vel

puppet func setRotation(rot):
  rotation = rot

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
	rpc_unreliable("setVelocity",velocity)
	
	rotation += rotation_dir * rotation_speed * delta
	rpc_unreliable("setRotation",rotation)

func _physics_process(delta):
	get_input(delta)
	
	velocity = move_and_slide(velocity)