extends KinematicBody2D
class_name Car

const GROUP = 'cars'

onready var enterArea := $EnterArea

export (int) var speed = 500
export (float) var rotation_speed = 2.5

func _ready():
	add_to_group(GROUP)
