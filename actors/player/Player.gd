extends KinematicBody2D
class_name Player

export (int) var speed = 200
export (float) var rotation_speed = 1.5

var velocity := Vector2()
var rotation_dir := 0

var frozen := false

puppet func setNetworkPosition(pos: Vector2):
	self.position = pos
	
puppet func setNetworkRotation(rot: float):
	self.rotation = rot
	
func unfreeze():
	self.frozen = false
	self.modulate = Color(1, 1, 1, 1)
	
func freeze():
	self.frozen = true
	self.velocity = Vector2(0, 0)
	self.modulate.b = 1.0
	self.modulate.r = 0.0
	self.modulate.g = 0.0
	self.modulate.a = 1.0
	
func get_input(delta):
	if not is_network_master():
		return
	
	if (self.frozen):
		return
	
	rotation_dir = 0
	self.velocity = Vector2()
	if Input.is_action_pressed('ui_right'):
		self.rotation_dir += 1
	if Input.is_action_pressed('ui_left'):
		self.rotation_dir -= 1
	if Input.is_action_pressed('ui_down'):
		self.velocity = Vector2(-self.speed, 0).rotated(self.rotation)
	if Input.is_action_pressed('ui_up'):
		self.velocity = Vector2(self.speed, 0).rotated(self.rotation)
	
	rotation += self.rotation_dir * self.rotation_speed * delta

func _physics_process(delta):
	get_input(delta)
	
	if is_network_master():
		self.velocity = move_and_slide(self.velocity)
		
		rpc_unreliable("setNetworkPosition", self.position)
		rpc_unreliable("setNetworkRotation", self.rotation)

func set_current_player():
	$Camera.current = true
