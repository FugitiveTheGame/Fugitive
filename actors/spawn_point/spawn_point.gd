extends Node2D
class_name SpawnPoint

const SEEKER_SPAWN = 'seeker_spawn'
const HIDER_SPAWN = 'hider_spawn'

export(String, 'seeker_spawn', 'hider_spawn') var team = SEEKER_SPAWN

func _ready():
	add_to_group(team)
