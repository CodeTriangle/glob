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
var normal_shape = ConvexPolygonShape2D.new()
var grown_shape = ConvexPolygonShape2D.new()
var shrunken_shape = ConvexPolygonShape2D.new()

var animator

func _ready():
	animator = get_node("sprite/animator")
	normal_shape.set_points(Vector2Array([Vector2(2, -5), Vector2(6, -2), Vector2(7, 1), Vector2(7, 5), Vector2(4, 8), Vector2(-4, 8), Vector2(-7, 5), Vector2(-7, 1), Vector2(-6, -2), Vector2(-2, -5)]))
	grown_shape.set_points(Vector2Array([Vector2(2, -17), Vector2(6, -10), Vector2(7, -5), Vector2(7, 2), Vector2(3, 8), Vector2(-3, 8), Vector2(-7, 2), Vector2(-7, -5), Vector2(-6, -10), Vector2(-2, -17)]))
	shrunken_shape.set_points(Vector2Array([Vector2(2, -1), Vector2(7, 3), Vector2(7, 8), Vector2(-7, 8), Vector2(-7, 3), Vector2(-2, 1)]))
	add_shape(normal_shape)
	
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
	
	if can_move:
		if move_left and not move_right: lv.x -= MOVEMENT_SPEED*step
		if move_right and not move_left: lv.x += MOVEMENT_SPEED*step
		
		if lv.x >= TERMINAL_VELOCITY*speed_mod: lv.x = TERMINAL_VELOCITY*speed_mod
		if lv.x <= -TERMINAL_VELOCITY*speed_mod: lv.x = -TERMINAL_VELOCITY*speed_mod
	
	if grow and not shrink and state == STATE_NORMAL: state = STATE_GROWING
	if shrink and not grow and state == STATE_NORMAL: state = STATE_SHRINKING
	
	if not grow and state == STATE_GROWING:
		animator.play("grow")
		clear_shapes()
		add_shape(grown_shape)
		can_move = false
		state = STATE_GROWN
		stabilize_timer = 3
	
	if grow and state == STATE_GROWN: stabilize_timer = 3
	
	if state == STATE_GROWN and stabilize_timer <= 0:
		animator.play_backwards("grow")
		animator.queue("idle")
		clear_shapes()
		add_shape(normal_shape)
		can_move = true
		state = STATE_NORMAL
	
	if shrink and state == STATE_SHRINKING:
		animator.play("shrink")
		animator.queue("shrunkenidle")
		clear_shapes()
		add_shape(shrunken_shape)
		state = STATE_SHRUNKEN
		speed_mod = 0.5
		stabilize_timer = 1
		
	if shrink and state == STATE_SHRUNKEN: stabilize_timer = 1
	
	if state == STATE_SHRUNKEN and stabilize_timer <= 0:
		animator.play_backwards("shrink")
		animator.queue("idle")
		clear_shapes()
		add_shape(normal_shape)
		state = STATE_NORMAL
		speed_mod = 1
	
	# Apply modifications
	s.set_linear_velocity(lv)