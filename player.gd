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
var double_action_timer = 0
var can_act_again = false
var normal_shape = CapsuleShape2D.new()
var grown_shape = CapsuleShape2D.new()
var shrunken_shape = CapsuleShape2D.new()
var puddle_shape = RectangleShape2D.new()

var animator
var collision

func normalize(from):
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
	can_move = false
	state = STATE_GROWN
	stabilize_timer = 1

func shrink():
	animator.play("shrink")
	animator.queue("shrunkenidle")
	clear_shapes()
	add_shape(shrunken_shape, Matrix32(PI/2, Vector2(0, 3.5)))
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
	
func _ready():
	animator = get_node("sprite/animator")
	collision = get_node("collision")
	
	normal_shape.set_height(2)
	normal_shape.set_radius(6)
	
	grown_shape.set_radius(7)
	grown_shape.set_height(11)
	
	shrunken_shape.set_radius(4.5)
	shrunken_shape.set_height(5.5)
	
	puddle_shape.set_extents(Vector2(7, 2))
	
	normalize("shrink")

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
	
	# Start growing if [grow] is held
	if grow and not shrink and state == STATE_NORMAL: state = STATE_GROWING
	# Immediately grow when [shrink] is released
	if not grow and state == STATE_GROWING: grow()
	# Restart timer as long as [grow] is still held
	if grow and state == STATE_GROWN: stabilize_timer = 1
	# Go back to normal when the timer is finished ticking
	if state == STATE_GROWN and stabilize_timer <= 0: normalize("grow")
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
	
	# Apply modifications
	s.set_linear_velocity(lv)