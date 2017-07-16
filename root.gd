extends Node2D

var players = []
var mm
var cm
var temp

func _ready():
	players.append(get_node("player"))
	mm = players[0].max_mass
	
	temp = get_node("temp")
	set_process(true)
	
func _process(delta):
	cm = 0
	
	for i in players:
		cm += i.mass

func power_up():
	temp.add_child(load("res://camera.tscn").instance())
	temp.add_child(load("res://powerup.tscn").instance())
	
	get_node("temp/powerup/boost").connect("pressed", self, "boost")
	get_node("temp/powerup/max-up").connect("pressed", self, "max_up")
	
	recollect()
	
	var bar = load("res://bar.tscn").instance()
	bar.set_max(mm)
	bar.set_value(cm)
	temp.add_child(bar)

func recollect():
	for i in players:
		remove_child(i)
	
	set_process(false)

func generate_player():
	var p = load("res://player.tscn").instance()
	
	var psn = temp.get_pos()
	psn.y += 30
	p.set_pos(psn)
	
	p.mass = cm
	p.max_mass = mm
	
	for i in temp.get_children(): temp.remove_child(i)
	
	players = []
	
	players.append(p)
	add_child(p)
	
	set_process(true)

func boost():
	cm = mm
	generate_player()

func max_up():
	mm += floor(mm/5)
	generate_player()