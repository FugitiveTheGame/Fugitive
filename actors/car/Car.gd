extends KinematicBody2D
class_name Car

# warning-ignore:unused_class_variable
# This really is used
onready var enterArea := $EnterArea
onready var drivingAudio := $DrivingAudio
onready var hornAudio := $HornAudio
onready var lockAudio := $LockAudio

export (int) var speed = 600
export (float) var rotation_speed = 2.5
export (bool) var locked := true setget set_locked, get_locked

var velocity := Vector2()

var driver = null
var passengers = []

const MAX_PASSENGERS = 3

func set_locked(lock: bool):
	locked = lock
	lockAudio.play()
	
	if locked:
		velocity = Vector2.ZERO
		print('Car locked')

func get_locked():
	return locked

remotesync func lock_the_car():
	locked = true

puppet func network_update(pos: Vector2, vel: Vector2, rot: float):
	self.position = pos
	self.velocity = vel
	self.rotation = rot

func _ready():
	add_to_group(Groups.CARS)

# Returns the ammount to rotate by
func get_input(delta: float) -> float:
	var new_rotation := 0.0
	
	if not local_player_is_driver():
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
	
	# Honk the car horn!
	if Input.is_action_pressed('car_horn'):
		if not hornAudio.playing:
			rpc('start_horn')
	elif hornAudio.playing:
		rpc('stop_horn')
	
	new_rotation = rotation_dir * self.rotation_speed * delta
	return new_rotation

func _process(delta):
	# Make movement noises if moving
	if is_moving() and driver != null:
		if not drivingAudio.playing:
			drivingAudio.playing = true
	else:
		if drivingAudio.playing:
			drivingAudio.playing = false

func _physics_process(delta: float):
	if local_player_is_driver():
		var new_rotation = get_input(delta)
		
		self.velocity = move_and_slide(self.velocity)
		self.rotation += new_rotation
		
		rpc_unreliable("network_update", self.position, self.velocity, self.rotation)
	# If we're just the server, send
	elif get_network_master() == get_tree().get_network_unique_id():
		rpc_unreliable("network_update", self.position, self.velocity, self.rotation)

remotesync func new_driver(network_id: int):
	self.set_network_master(network_id, false)

remotesync func unlock():
	locked = false
	print('Car unlockled')

func has_occupants() -> bool:
	return driver != null or passengers.size() > 0

func is_driver(player) -> bool:
	return driver == player

func get_in_car(player) -> bool:
	var success := false
	
	# The car is locked until a Seeker unlocks it by entering it
	if player.has_group(Groups.SEEKERS) or not locked:
		if driver == null:
			driver = player
			# Unlock the car once the first Seeker gets in
			if locked:
				rpc('unlock')
			rpc('new_driver', driver.get_network_master())
			success = true
		elif passengers.size() < MAX_PASSENGERS:
			# Only let the player in if they are in the same group
			# as the driver
			if player.has_group(driver._get_player_group()):
				passengers.push_back(player)
				success = true
	
	if success:
		$DoorAudio.play()
	
	return success

func get_out_of_car(player):
	var success := false
	if driver == player:
		driver = null
		# player needs to be removed as a child before we do this
		rpc('new_driver', 1)
		success = true
	elif passengers.has(player):
		passengers.erase(player)
		success = true
	else:
		success = false
	
	if success:
		$DoorAudio.play()
	
	return success

func is_moving() -> bool:
	return velocity.length() > 0.0

func local_player_is_driver():
	return driver != null and driver.get_network_master() == get_tree().get_network_unique_id()

remotesync func start_horn():
	hornAudio.playing = true
	print('Honk Honk!')

remotesync func stop_horn():
	hornAudio.playing = false

func _on_EnterArea_body_entered(body):
	if not get_tree().is_network_server():
		return
	
	# If the car is being driven by a Hider, and hits a Cop
	if self.driver != null and self.driver._get_player_node_type() == Network.PlayerType.Hider and body is Seeker:
		call_deferred('eject_hider')

func eject_hider():
	# lock it, and kick the hider out
	rpc('lock_the_car')
	self.driver.force_car_exit()
