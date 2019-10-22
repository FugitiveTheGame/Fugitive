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

var velocity := Vector2()
var rotation_dir := 0

var stamina: float

var frozen := false
var frozenColor := Color.blue

func _ready():
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

# warning-ignore:unused_argument
func _process(delta: float):
	staminaBar.value = stamina

func get_input(delta: float):
	if not is_network_master():
		return
	
	if (self.frozen):
		return
	
	var curSpeed: float
	if is_sprinting():
		curSpeed = sprint_speed
	else:
		curSpeed = speed
	
	rotation_dir = 0
	self.velocity = Vector2()
	if Input.is_action_pressed('ui_right'):
		self.rotation_dir += 1
	if Input.is_action_pressed('ui_left'):
		self.rotation_dir -= 1
	if Input.is_action_pressed('ui_down'):
		self.velocity = Vector2(-curSpeed, 0).rotated(self.rotation)
	if Input.is_action_pressed('ui_up'):
		self.velocity = Vector2(curSpeed, 0).rotated(self.rotation)
	
	rotation += self.rotation_dir * self.rotation_speed * delta

func is_sprinting():
	return Input.is_action_pressed('sprint') and stamina > 0.0

func process_stamina(delta: float):
	if is_sprinting():
		stamina -= (stamina_depletion_rate * delta)
	elif not Input.is_action_pressed('sprint') and not is_moving():
		stamina += (stamina_regen_rate * delta)
	stamina = clamp(stamina, 0.0, max_stamina)

func _physics_process(delta: float):
	get_input(delta)
	
	if is_network_master():
		self.velocity = move_and_slide(self.velocity)
		process_stamina(delta)
		
		rpc_unreliable("setNetworkPosition", self.position)
		rpc_unreliable("setNetworkVelocity", self.velocity)
		rpc_unreliable("setNetworkRotation", self.rotation)
		rpc_unreliable("setNetworkStamina", self.stamina)
	
	# Make movement noises if moving
	if is_moving():
		if not footStepAudio.playing:
			footStepAudio.playing = true
	else:
		if footStepAudio.playing:
			footStepAudio.playing = false

func is_moving() -> bool:
	return velocity.length() > 0.0

func set_current_player():
	camera.current = true
