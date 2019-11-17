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
export (bool) var is_fake := false

var velocity := InterpolatedObject.new(Vector2(), Vector2())
var is_moving := false

var driver = null
var passengers = []

const MAX_PASSENGERS = 3

func set_locked(lock: bool):
	locked = lock
	lockAudio.play()
	
	if locked:
		velocity.setTarget(Vector2.ZERO)
		print('Car locked')

func get_locked():
	return locked

remotesync func lock_the_car():
	locked = true

puppet func network_update(pos: Vector2, vel: Vector2, targetVelocity: Vector2, rot: float, isMoving: bool):
	self.position = pos
	self.velocity.setCurrentValue(vel)
	self.velocity.setTarget(targetVelocity)
	self.rotation = rot
	self.is_moving = isMoving

func _ready():
	add_to_group(Groups.CARS)

# Returns the ammount to rotate by
func get_input(delta: float) -> float:
	var new_rotation := 0.0
	
	if not local_player_is_driver():
		return new_rotation
	
	var rotation_dir = 0
	var target = Vector2()
	self.is_moving = false
	
	if Input.is_action_pressed('ui_right'):
		rotation_dir += 1
	if Input.is_action_pressed('ui_left'):
		rotation_dir -= 1
	if Input.is_action_pressed('ui_down'):
		rotation_dir *= -1
		self.is_moving = true
		target = Vector2(-self.speed, 0).rotated(self.rotation)
	if Input.is_action_pressed('ui_up'):
		self.is_moving = true
		target = Vector2(self.speed, 0).rotated(self.rotation)
	
	self.velocity.setTarget(target)
	
	if self.is_moving:
		new_rotation = rotation_dir * self.rotation_speed * delta
		driver.rotation = 0.0
	# If we are sitting still, let the driver look around
	else:
		var driver_rotation = rotation_dir * self.rotation_speed * delta
		driver.rotate(driver_rotation)
	
	return new_rotation

func _process(delta):
	# Make movement noises if moving
	if self.is_moving() and driver != null:
		if not drivingAudio.playing:
			drivingAudio.playing = true
	else:
		if drivingAudio.playing:
			drivingAudio.playing = false
	
	if local_player_is_driver():
		# Honk the car horn!
		if Input.is_action_pressed('car_horn'):
			if not hornAudio.playing:
				rpc('start_horn')
		elif hornAudio.playing:
			rpc('stop_horn')

func _physics_process(delta: float):
	if is_fake:
		return
	
	if local_player_is_driver():
		var new_rotation = get_input(delta)
		var interpolated_velocity = self.velocity.update(delta)
		var new_velocity = move_and_slide(interpolated_velocity)
		self.velocity.setTarget(new_velocity)
		self.velocity.setCurrentValue(new_velocity)
		self.rotation += new_rotation
		
		rpc_unreliable("network_update", self.position, self.velocity.getCurrentValue(), self.velocity.getTarget(), self.rotation, self.is_moving)
	# If the server owns this car, send no matter what
	elif get_network_master() == get_tree().get_network_unique_id():
		rpc_unreliable("network_update", self.position, self.velocity.getCurrentValue(), self.velocity.getTarget(), self.rotation, self.is_moving)

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
		self.velocity.setCurrentValue(Vector2())
	
	return success

func is_moving() -> bool:
	return self.is_moving

func local_player_is_driver():
	return driver != null and driver.get_network_master() == get_tree().get_network_unique_id()

remotesync func start_horn():
	if not hornAudio.playing:
		hornAudio.play()
		print('Honk Honk!')

remotesync func stop_horn():
	hornAudio.stop()

func _on_EnterArea_body_entered(body):
	if is_fake or not get_tree().is_network_server():
		return
	
	# If the car is being driven by a Hider, and hits a Cop
	if self.driver != null and self.driver._get_player_node_type() == Network.PlayerType.Hider and body is Seeker:
		call_deferred('eject_hider')

func eject_hider():
	# lock it, and kick the hider out
	rpc('lock_the_car')
	self.driver.force_car_exit()
