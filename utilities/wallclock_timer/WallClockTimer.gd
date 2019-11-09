# A drop in replacement for the Timer class
# This timer is completely framerate independent
# It can also be given a unix time stamp instead of a duration
# for when it should fire. This is useful for synchornizing events
# across multiple clients such as in Multiplayer
extends Node
class_name WallClockTimer, 'res://utilities/wallclock_timer/icon.png'

signal timeout

const STOPPED := -1

export (int) var wait_time: int = 0
export (bool) var auto_start: bool = false
export (bool) var one_shot: bool = true
var start_time: int = STOPPED
var end_time: int = STOPPED
var time_left: float setget set_time_left, get_time_left

func _ready():
	if auto_start:
		start()

func start(specific_end_time: int = STOPPED):
	start_time = OS.get_unix_time()
	
	if specific_end_time == STOPPED:
		end_time = start_time + wait_time
	else:
		end_time = specific_end_time

func stop():
	start_time = STOPPED

func is_stopped() -> bool:
	return start_time == STOPPED

func set_time_left(value):
	print('WallClockTimer: set_time_left is not allowed!')
	assert(false) # You can't set this!

func get_time_left() -> float:
	return (end_time - OS.get_unix_time()) as float

func _process(delta):
	if is_stopped():
		return
	
	if OS.get_unix_time() >= end_time:
		stop()
		emit_signal('timeout')
		
		# If this is not a one-shot timer, restart it
		if not one_shot:
			start()
