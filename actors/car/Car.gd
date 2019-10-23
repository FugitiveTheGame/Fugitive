extends KinematicBody2D
class_name Car

const GROUP = 'cars'

onready var enterArea := $EnterArea

export (int) var speed = 500
export (float) var rotation_speed = 2.5

var velocity := Vector2()

var driver = null
var passengers = []

const MAX_PASSENGERS = 3

remote func setNetworkPosition(pos: Vector2):
	self.position = pos
	
remote func setNetworkVelocity(vel: Vector2):
	self.velocity = vel
	
remote func setNetworkRotation(rot: float):
	self.rotation = rot

func _ready():
	add_to_group(GROUP)

# Returns the ammount to rotate by
func get_input(delta: float) -> float:
	var new_rotation := 0.0
	
	if not is_network_master():
		return new_rotation
	
	var rotation_dir = 0
	self.velocity = Vector2()
	if Input.is_action_pressed('ui_right'):
		rotation_dir += 1
	if Input.is_action_pressed('ui_left'):
		rotation_dir -= 1
	if Input.is_action_pressed('ui_down'):
		self.velocity = Vector2(-self.speed, 0).rotated(self.rotation)
	if Input.is_action_pressed('ui_up'):
		self.velocity = Vector2(self.speed, 0).rotated(self.rotation)
	
	new_rotation = rotation_dir * self.rotation_speed * delta
	return new_rotation

func _physics_process(delta: float):
	if driver != null and is_network_master():
		var new_rotation = get_input(delta)
		
		self.velocity = move_and_slide(self.velocity)
		self.rotation += new_rotation
	
		rpc_unreliable("setNetworkPosition", self.position)
		rpc_unreliable("setNetworkVelocity", self.velocity)
		rpc_unreliable("setNetworkRotation", self.rotation)
	
	# Make movement noises if moving
	#if is_moving():
		#if not footStepAudio.playing:
			#footStepAudio.playing = true
	#else:
		#if footStepAudio.playing:
			#footStepAudio.playing = false

func get_in_car(player) -> bool:
	var success := false
	if driver == null:
		driver = player
		self.set_network_master(driver.get_network_master())
		success = true
	elif passengers.size() < MAX_PASSENGERS:
		passengers.push_back(player)
		success = true
	
	return success

func get_out_of_car(player):
	var success := false
	if driver == player:
		driver = null
		# player needs to be removed as a child before we do this
		self.set_network_master(-1)
		success = true
	elif passengers.has(player):
		passengers.erase(player)
		success = true
	else:
		success = false
	return success

func is_moving() -> bool:
	return velocity.length() > 0.0
