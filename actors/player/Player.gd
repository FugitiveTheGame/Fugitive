extends KinematicBody2D
class_name Player

export (int) var speed = 200
export (float) var rotation_speed = 1.5
export (String) var playerName: String
export (float) var max_stamina = 100.0
export (float) var stamina_depletion_rate = 100.0
export (float) var stamina_regen_rate = 25.0
export (float) var sprint_speed = 400.0

onready var camera := $Camera as Camera2D
onready var footStepAudio := $FootStepAudio as AudioStreamPlayer2D
onready var playerNameLabel := $PlayerNameLabel as Label
onready var staminaBar := $StaminaBar as ProgressBar

onready var playersNode = get_tree().get_root().get_node("base/players")

var velocity := Vector2()
var rotation_dir := 0

var stamina: float

var frozen := false
var frozenColor := Color(0, 0, 1, 1)

# This is a car this player is driving
var car: Car

func _ready():
	set_process_input(true)
	
	stamina = max_stamina
	staminaBar.max_value = max_stamina
	playerNameLabel.text = playerName

puppet func setNetworkPosition(pos: Vector2):
	self.position = pos
	
puppet func setNetworkVelocity(vel: Vector2):
	self.velocity = vel
	
puppet func setNetworkRotation(rot: float):
	self.rotation = rot

puppet func setNetworkStamina(stam: float):
	self.stamina = stam
	
func unfreeze():
	self.frozen = false
	self.modulate = Color(1, 1, 1, 1)
	
func freeze():
	self.frozen = true
	self.velocity = Vector2(0, 0)
	self.modulate = frozenColor

func _input(event):
	if(event.is_action_pressed("use")):
		if self.car == null:
			var cars = get_tree().get_nodes_in_group(Car.GROUP)
			for car in cars:
				var area = car.enterArea as Area2D
				if area.overlaps_body(self):
					call_deferred("get_in_car", car)
					break
		else:
			#call_deferred("get_out_of_car")
			get_out_of_car()

# warning-ignore:unused_argument
func _process(delta: float):
	staminaBar.value = stamina

# Returns the ammount to rotate by
func get_input(delta: float) -> float:
	var new_rotation := 0.0
	
	if not is_network_master():
		return new_rotation
	
	if self.frozen:
		return new_rotation
	
	var curSpeed: float
	if self.car == null:
		if is_sprinting():
			curSpeed = sprint_speed
		else:
			curSpeed = speed
	else:
		curSpeed = car.speed
	
	var curRotationSpeed: float
	if self.car == null:
		curRotationSpeed = self.rotation_speed
	else:
		curRotationSpeed = car.rotation_speed
	
	var velocity_rotation: float
	if self.car == null:
		velocity_rotation = self.rotation
	else:
		velocity_rotation = car.rotation
	
	rotation_dir = 0
	self.velocity = Vector2()
	if Input.is_action_pressed('ui_right'):
		self.rotation_dir += 1
	if Input.is_action_pressed('ui_left'):
		self.rotation_dir -= 1
	if Input.is_action_pressed('ui_down'):
		self.velocity = Vector2(-curSpeed, 0).rotated(velocity_rotation)
	if Input.is_action_pressed('ui_up'):
		self.velocity = Vector2(curSpeed, 0).rotated(velocity_rotation)
	
	new_rotation = self.rotation_dir * curRotationSpeed * delta
	return new_rotation

func is_sprinting():
	return Input.is_action_pressed('sprint') and stamina > 0.0

func process_stamina(delta: float):
	if is_sprinting():
		stamina -= (stamina_depletion_rate * delta)
	elif not Input.is_action_pressed('sprint') and not is_moving():
		stamina += (stamina_regen_rate * delta)
	stamina = clamp(stamina, 0.0, max_stamina)

func _physics_process(delta: float):
	var new_rotation = get_input(delta)
	
	if is_network_master():
		if car == null:
			process_stamina(delta)
			self.velocity = move_and_slide(self.velocity)
			self.rotation += new_rotation
		
			rpc_unreliable("setNetworkPosition", self.position)
			rpc_unreliable("setNetworkVelocity", self.velocity)
			rpc_unreliable("setNetworkRotation", self.rotation)
			rpc_unreliable("setNetworkStamina", self.stamina)
		else:
			self.velocity = car.move_and_slide(self.velocity)
			car.rotation += new_rotation
		
			rpc_unreliable("setNetworkPosition", car.position)
			rpc_unreliable("setNetworkVelocity", self.velocity)
			rpc_unreliable("setNetworkRotation", car.rotation)
	
	# Make movement noises if moving
	if car == null:
		if is_moving():
			if not footStepAudio.playing:
				footStepAudio.playing = true
		else:
			if footStepAudio.playing:
				footStepAudio.playing = false
	else:
		# Play car audio here
		pass

func is_moving() -> bool:
	return velocity.length() > 0.0

func set_current_player():
	camera.current = true

func get_in_car(car):
	print('Enter Car')
	self.car = car
	# Refil stamina instantly
	self.stamina = max_stamina
	
	$CollisionShape2D.disabled = true
	
	self.get_parent().remove_child(self) # error here  
	car.add_child(self)
	
	self.position = Vector2.ZERO
	self.rotation = 0

func get_out_of_car():
	print('Exit Car')
	
	self.get_parent().remove_child(self) # error here
	playersNode.add_child(self)
	
	self.global_position = car.global_position
	self.rotation = car.rotation
	
	$CollisionShape2D.disabled = false
	
	self.car = null
