extends Node2D

var players = []

func _ready():
	players.append(get_node("player"))