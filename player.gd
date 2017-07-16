extends RigidBody2D

# De-facto enumeration
const STATE_NORMAL = 0
const STATE_GROWING = 1
const STATE_GROWN = 2
const STATE_INACTIVE = 3
const STATE_SHRINKING = 4
const STATE_SHRUNKEN = 5
const STATE_PUDDLE = 6

# Constants
const MOVEMENT_SPEED = 250.0
const TERMINAL_VELOCITY = 100.0

# Variables
var speed_mod = 1
var can_move = true
var state = STATE_NORMAL
var stabilize_timer = 0
var can_act_again = false
var on_ground = true
var mass = 128
var max_mass = 128
var cells = {}

# Shapes
var normal_shape = CapsuleShape2D.new()
var grown_shape = CapsuleShape2D.new()
var shrunken_shape = CapsuleShape2D.new()
var puddle_shape = RectangleShape2D.new()

# Elements
var animator
var player
var mass_bar
var walls
var trail
var root
var this

func _ready():
	set_fixed_process(true)
	
	animator = get_node("sprite/animator")
	player = load("res://player.tscn")
	mass_bar = get_node("mass")
	walls = get_node("../walls")
	trail = get_node("../trail")
	root = get_parent()
	this = get_node(".")
	
	mass_bar.set_max(max_mass)
	
	normal_shape.set_height(2)
	normal_shape.set_radius(6)
	
	grown_shape.set_radius(7)
	grown_shape.set_height(11)
	
	shrunken_shape.set_radius(4)
	shrunken_shape.set_height(6)
	
	puddle_shape.set_extents(Vector2(7, 2))
	
	normalize()

func normalize(from=""):
	animator.play_backwards(from)
	animator.queue("idle")
	clear_shapes()
	add_shape(normal_shape, Matrix32(PI/2, Vector2(0, 2)))
	can_move = true
	can_act_again = false
	state = STATE_NORMAL
	speed_mod = 1

func grow():
	animator.play("grow")
	clear_shapes()
	add_shape(grown_shape, Matrix32(0, Vector2(0, -4.5)))
	state = STATE_GROWN
	speed_mod = 0.1
	stabilize_timer = 1

func shrink():
	animator.play("shrink")
	animator.queue("shrunkenidle")
	clear_shapes()
	add_shape(shrunken_shape, Matrix32(PI/2, Vector2(0, 4)))
	state = STATE_SHRUNKEN
	speed_mod = 0.5
	stabilize_timer = 1

func puddle():
	animator.play("puddle")
	clear_shapes()
	add_shape(puddle_shape, Matrix32(0, Vector2(0, 6)))
	state = STATE_PUDDLE
	can_move = false
	stabilize_timer = 1

func shoot():
	normalize("grow")
	state = STATE_INACTIVE
	can_move = false
	
	var p = player.instance()
	
	var lv = get_linear_velocity()
	lv.y -= 150
	p.set_linear_velocity(lv)
	
	var psn = get_pos()
	psn.y -= 30
	p.set_pos(psn)
	
	mass /= 2
	p.mass = mass
	
	root.players.append(p)
	root.add_child(p)

func merge(with):
	var p = player.instance()
	
	p.set_linear_velocity(get_linear_velocity()+with.get_linear_velocity()/2)
	
	p.set_pos(with.get_pos())
	
	p.mass = mass + with.mass
	p.max_mass = max_mass
	
	root.remove_child(this)
	root.players.remove(root.players.find(this))
	root.remove_child(with)
	root.players.remove(root.players.find(with))
	
	root.players.append(p)
	root.add_child(p)

func die():
	if root.players.size() > 1:
		root.players.remove(root.players.find(this))
		root.remove_child(this)
		root.players[root.players.size()-1].normalize()
	else:
		get_tree().change_scene("res://menu.tscn")

func _fixed_process(delta):
	mass_bar.set_value(mass)
	
	if not state == STATE_INACTIVE: for i in get_colliding_bodies(): if root.players.has(i): merge(i)
	
	var tp = get_pos()
	tp = Vector2(floor(tp.x/16), floor(tp.y/16))
	
	cells["current"] = tp
	cells["above"] = Vector2(tp.x, tp.y-1)
	cells["below"] = Vector2(tp.x, tp.y+1)
	cells["left"] = Vector2(tp.x-1, tp.y)
	cells["right"] = Vector2(tp.x+1, tp.y)
	
	if trail.get_cellv(tp) == -1 and not walls.get_cell(tp.x, tp.y+1) == -1 and on_ground:
		trail.set_cellv(tp, 0)
		mass -= 1
		
	if walls.get_cellv(cells["current"]) == 15:
		get_node("../temp").set_pos(Vector2(cells["current"].x*16, cells["current"].y*16))
		root.recollect()
		root.generate_player()
	
	if walls.get_cellv(cells["current"]) == 13:
		get_node("../temp").set_pos(Vector2(cells["current"].x*16, cells["current"].y*16))
		walls.set_cellv(cells["current"], 15)
		root.power_up()
	
	if walls.get_cellv(cells["current"]) == 16: die()
	if walls.get_cellv(cells["current"]) == 18: die()
	if walls.get_cellv(cells["current"]) == 17: die()
	
	if mass <= 0: die()
	
	if cells["current"].x > 92 and cells["current"].y == 20: get_tree().change_scene("res://menu.tscn")

# Main Function for Movement
func _integrate_forces(s):
	var lv = s.get_linear_velocity()
	var step = s.get_step()
	
	# Get input
	var move_left = Input.is_action_pressed("move_left")
	var move_right = Input.is_action_pressed("move_right")
	var grow = Input.is_action_pressed("grow")
	var shrink = Input.is_action_pressed("shrink")
	
	stabilize_timer -= step
	
	on_ground = false
	
	for x in range(s.get_contact_count()): if s.get_contact_local_normal(x).dot(Vector2(0, -1)) > 0.6: on_ground = true
	
	if on_ground:
		if can_move:
			if move_left and not move_right: lv.x -= MOVEMENT_SPEED*step
			if move_right and not move_left: lv.x += MOVEMENT_SPEED*step
			
			if lv.x >= TERMINAL_VELOCITY*speed_mod: lv.x = TERMINAL_VELOCITY*speed_mod
			if lv.x <= -TERMINAL_VELOCITY*speed_mod: lv.x = -TERMINAL_VELOCITY*speed_mod
	
		# Start growing if [grow] is held
		if grow and not shrink and on_ground and state == STATE_NORMAL: state = STATE_GROWING
		# Immediately grow when [shrink] is released
		if grow and state == STATE_GROWING: grow()
		# Restart timer as long as [grow] is still held
		if grow and state == STATE_GROWN: stabilize_timer = 1
		# Go back to normal when the timer is finished ticking
		if state == STATE_GROWN and stabilize_timer <= 0: normalize("grow")
		# Once [grow] is released, allow player to press [grow] again to shoot
		if not grow and state == STATE_GROWN: can_act_again = true
		# Shoot a new gel once the player presses [grow] a second time
		if grow and can_act_again and state == STATE_GROWN: shoot()
		# Start shrinking if [shrink] is held
		if shrink and not grow and state == STATE_NORMAL: state = STATE_SHRINKING
		# Immediately shrink when state is STATE_SHRINKING
		if shrink and state == STATE_SHRINKING: shrink()
		# Restart timer as long as [shrink] is still held
		if shrink and state == STATE_SHRUNKEN: stabilize_timer = 1
		# Go back to normal when the timer is finished ticking
		if state == STATE_SHRUNKEN and stabilize_timer <= 0: normalize("shrink")
		# Once [shrink] is released, allow player to press [shrink] again to puddle
		if not shrink and state == STATE_SHRUNKEN: can_act_again = true
		# Puddle when the player presses [shrink] a second time
		if shrink and can_act_again and state == STATE_SHRUNKEN: puddle()
		# Restart timer as long as [shrink] is still held
		if shrink and state == STATE_PUDDLE: stabilize_timer = 1
		# Go back to normal when the timer is finished ticking
		if state == STATE_PUDDLE and stabilize_timer <= 0: normalize("melt")
	elif can_move:
		if move_left and not move_right: lv.x -= MOVEMENT_SPEED*step
		if move_right and not move_left: lv.x += MOVEMENT_SPEED*step
		
		if lv.x >= TERMINAL_VELOCITY*speed_mod: lv.x = TERMINAL_VELOCITY*speed_mod
		if lv.x <= -TERMINAL_VELOCITY*speed_mod: lv.x = -TERMINAL_VELOCITY*speed_mod
	
	# Apply modifications
	s.set_linear_velocity(lv)