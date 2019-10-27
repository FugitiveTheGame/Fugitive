extends Player
class_name Hider

func _get_player_group() -> String:
	return Groups.HIDERS

func _on_Area2D_body_entered(body):
	# Freeze tag! Unfreeze your friends!
	if body is Player and body.has_group(Groups.HIDERS):
		if body.frozen:
			body.unfreeze()
