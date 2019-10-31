extends Player
class_name Hider

onready var visibilityBar := $VisibilityBar
var current_visibility: float = 0.0 setget set_current_visibility

func _get_player_group() -> String:
	return Groups.HIDERS

func _get_player_node_type() -> int:
	return Network.PlayerType.Hider

func set_current_player():
	.set_current_player()
	visibilityBar.show()

func _frozen():
	$FreezeAudio.play()

func _unfrozen():
	$FreezeAudio.play()

func _on_Area2D_body_entered(body):
	# Freeze tag! Unfreeze your friends!
	if body is Player and body._get_player_node_type() == Network.PlayerType.Hider:
		if body.frozen:
			# Only let the network server send out this message
			if get_tree().is_network_server():
				body.unfreeze()

func set_current_visibility(percentVisible: float):
	current_visibility = percentVisible
	
	visibilityBar.value = (percentVisible * visibilityBar.max_value)
	
	# If we are a Seeker, use visibility to fade hider out
	var currentPlayer = Network.get_current_player()
	if (currentPlayer.assigned_type == Network.PlayerType.Seeker):
		modulate.a = percentVisible

func update_visibility(percentVisible: float):
	# Never make a hider MORE invisible, if some one else can see the hider
	# then leave them that visible for all Seekers
	if percentVisible > self.current_visibility:
		self.current_visibility = percentVisible
