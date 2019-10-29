extends Node

signal game_start

func emit_game_start():
	emit_signal("game_start")
