extends KinematicBody2D
class_name Player

export (int) var speed := 200
export (float) var rotation_speed := 4.0
export (String) var playerName: String
export (float) var max_stamina := 100.0
export (float) var stamina_depletion_rate := 100.0
export (float) var stamina_regen_rate := 25.0
export (float) var sprint_speed := 400.0
export (bool) var is_fake := false

onready var camera := $Camera as Camera2D
onready var footStepAudio := $FootStepAudio as AudioStreamPlayer2D
onready var playerNameLabel := $PlayerNameLabel as Label
onready var playerCollisionShape := $Collision as CollisionShape2D

onready var playersNode = get_tree().get_root().get_node("base/players")

var velocity := Vector2()

var stamina: float

var frozen := false
var frozenColor := Color(0, 0, 1, 1)

var gameStarted := false

# This is a car this player is driving
var car = null

func _ready():
	add_to_group(_get_player_group())
	
	set_process_input(true)
	
	stamina = max_stamina
	playerNameLabel.text = playerName

func _enter_tree():
	SignalManager.connect('game_start', self, '_game_start')

func _exit_tree():
	SignalManager.disconnect('game_start', self, '_game_start')

puppet func network_update(pos: Vector2, vel: Vector2, rot: float, stam: float):
	self.position = pos
	self.velocity = vel
	self.rotation = rot
	self.stamina = stam

func _game_start():
	gameStarted = true

func unfreeze():
	rpc("onUnfreeze")

remotesync func onUnfreeze():
	self.frozen = false
	self.modulate = Color(1, 1, 1, 1)
	
	self._unfrozen()
	print('unfreeze')

func freeze():
	if is_fake:
		return
	
	rpc("onFreeze")

remotesync func onFreeze():
	self.frozen = true
	self.velocity = Vector2(0, 0)
	self.modulate = frozenColor
	
	self._frozen()
	print('freeze')

# React to being frozen
func _frozen():
	pass

# React to being frozen
func _unfrozen():
	pass

func _input(event):
	if is_fake or not is_network_master() or not gameStarted:
		return
	
	if event.is_action_pressed("use"):
		if self.car == null:
			var new_car = find_car_inrange()
			if new_car != null:
				# Tell the server you want to get into the car
				rpc_id(1, 'try_get_in_car', new_car.get_path())
			else:
				print('Nothing to use')
		elif not self.car.is_moving():
			rpc('on_car_exit')

func find_car_inrange():
	var nearest_car = null
	
	var cars = get_tree().get_nodes_in_group(Groups.CARS)
	for car in cars:
		var area = car.enterArea as Area2D
		if area.overlaps_body(self):
			nearest_car = car
			break
	return nearest_car

# Returns the ammount to rotate by
func get_input(delta: float) -> float:
	var new_rotation := 0.0
	
	if not is_network_master():
		return new_rotation
	
	if self.frozen:
		return new_rotation
	
	var curSpeed: float
	if is_sprinting():
		curSpeed = sprint_speed
	else:
		curSpeed = speed
	
	var rotation_dir: float
	self.velocity = Vector2()
	if Input.is_action_pressed("rotate_right"):
		rotation_dir = 1.0
	if Input.is_action_pressed("rotate_left"):
		rotation_dir = -1.0
	if Input.is_action_pressed("move_backward"):
		self.velocity = Vector2(-curSpeed, 0).rotated(self.rotation)
	if Input.is_action_pressed("move_forward"):
		self.velocity = Vector2(curSpeed, 0).rotated(self.rotation)
	
	new_rotation = rotation_dir * self.rotation_speed * delta
	return new_rotation

func is_moving() -> bool:
	return velocity.length() > 0.0

func is_moving_fast():
	return velocity.length() > (speed * 1.1)

func is_sprinting():
	return Input.is_action_pressed('sprint') and stamina > 0.0

func process_stamina(delta: float):
	if is_sprinting() and is_moving():
		stamina -= (stamina_depletion_rate * delta)
	elif not is_moving():
		stamina += (stamina_regen_rate * delta)
	stamina = clamp(stamina, 0.0, max_stamina)

func _physics_process(delta: float):
	if not gameStarted or is_fake:
		return
	
	# If we're in a car, do nothing
	if is_network_master():
		if self.car == null:
			var new_rotation = get_input(delta)
			process_stamina(delta)
			self.velocity = move_and_slide(self.velocity)
			rotate(new_rotation)
		# Allow passengers to look around while in a car
		elif not self.car.is_driver(self):
			var new_rotation = get_input(delta)
			rotate(new_rotation)
		
		rpc_unreliable("network_update", self.position, self.velocity, self.rotation, self.stamina)
	
	# Make movement noises if moving
	if is_moving() && is_sprinting() && car == null:
		if not footStepAudio.playing:
			footStepAudio.playing = true
	else:
		if footStepAudio.playing:
			footStepAudio.playing = false

func set_current_player():
	camera.current = true

# Only get's called on server
remotesync func try_get_in_car(car_path: NodePath):
	var new_car = get_tree().get_root().get_node(car_path)
	# If server says you got in the car, tell everyone else about it
	if new_car.get_in_car(self):
		rpc('do_get_in_car', car_path)
		self.on_car_enter(new_car)
	else:
		print('Could not get into the Car')

# Every other client now gets in the car
remote func do_get_in_car(car_path: NodePath):
	print('Server says get in car!')
	var new_car = get_tree().get_root().get_node(car_path)
	if not new_car.get_in_car(self):
		print('ERROR: Could not get into the Car, server told us to, this is goint to be a problem!')
	on_car_enter(new_car)

func on_car_enter(newCar):
	print('Enter Car')
	
	self.car = newCar
	# Refil stamina instantly
	self.stamina = max_stamina
	
	playerCollisionShape.disabled = true
	
	playersNode.remove_child(self)
	self.car.add_child(self)
	
	self.position = Vector2.ZERO
	self.rotation = 0

func force_car_exit():
	rpc('on_car_exit')

remotesync func on_car_exit():
	print('Exit Car')
	
	car.remove_child(self)
	playersNode.add_child(self)
	
	self.global_position = car.global_position
	self.rotation = car.rotation
	
	playerCollisionShape.disabled = false
	
	var oldCar = self.car
	self.car = null
	
	oldCar.get_out_of_car(self)

func _get_player_group() -> String:
	assert(false) # Sub class MUST override this
	return ''

func has_group(group: String) -> bool:
	return get_groups().has(group)

func _get_player_node_type() -> int:
	assert(false) # Sub class MUST override this
	return Network.PlayerType.Random
