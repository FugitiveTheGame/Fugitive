extends Player
class_name Hider

signal current_player_hider_frozen

var current_visibility: float = 0.0 setget set_current_visibility

onready var idleSprite := $IdleSprite
onready var walkSprite := $WalkingSprite
onready var sprintSprite := $SprintingSprite

func _get_player_group() -> String:
	return Groups.HIDERS

func _get_player_node_type() -> int:
	return Network.PlayerType.Hider

func _frozen():
	$FreezeAudio.play()
	# Tell the map to take you to spectator view
	if is_network_master():
		emit_signal('current_player_hider_frozen')

func _unfrozen():
	$FreezeAudio.play()
	# Go back to player view
	if is_network_master():
		$Camera.current = true

func _on_Area2D_body_entered(body):
	# Freeze tag! Unfreeze your friends!
	if body is Player and body._get_player_node_type() == Network.PlayerType.Hider:
		if body.frozen:
			# Only let the network server send out this message
			if get_tree().is_network_server():
				body.unfreeze()

func _process(delta):
		# If walking, make sure we're showing the walk anim
	if is_moving_fast():
		if not sprintSprite.visible:
			idleSprite.hide()
			walkSprite.hide()
			sprintSprite.show()
	# If walking, make sure we're showing the walk anim
	elif is_moving():
		if not walkSprite.visible:
			idleSprite.hide()
			walkSprite.show()
			sprintSprite.hide()
	# We're idle, make sure we're showing the idle anim
	elif not idleSprite.visible:
		idleSprite.show()
		walkSprite.hide()
		sprintSprite.hide()

func set_current_visibility(percentVisible: float):
	current_visibility = percentVisible
	
	# If we are a Seeker, use visibility to fade hider out
	var currentPlayer = Network.get_current_player()
	if (currentPlayer.assigned_type == Network.PlayerType.Seeker):
		modulate.a = percentVisible

func update_visibility(percentVisible: float):
	# Never make a hider MORE invisible, if some one else can see the hider
	# then leave them that visible for all Seekers
	if percentVisible > self.current_visibility:
		self.current_visibility = percentVisible
