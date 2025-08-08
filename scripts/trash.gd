class_name Trash
extends RigidBody2D

enum TrashType { ORGANIK, B3, PLASTIK }
@export var type: TrashType

var swipe_start_position := Vector2.ZERO
var swipe_end_position := Vector2.ZERO
var is_swiping := false

func _ready():
	input_pickable = true
	# Pastikan node ini juga menerima _input() global
	set_process_input(true)

# Tangani hanya PRESS di dalam collision shape
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_swiping = true
		swipe_start_position = event.position
	elif event is InputEventScreenTouch and event.is_pressed():
		is_swiping = true
		swipe_start_position = event.position

# Tangani MOTION & RELEASE di mana saja
func _input(event):
	if is_swiping:
		# Update posisi terakhir saat drag
		if event is InputEventMouseMotion:
			swipe_end_position = event.position
		elif event is InputEventScreenDrag:
			swipe_end_position = event.position

		# Deteksi RELEASE global
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and event.is_released()):
			swipe_end_position = event.position
			_apply_swipe()
			is_swiping = false

func _apply_swipe():
	var swipe_vec: Vector2 = swipe_end_position - swipe_start_position
	print("DEBUG swipe_vec:", swipe_vec)
	if abs(swipe_vec.x) > 20:
		# Definisikan strength sebagai float
		var strength: float = 2000.0
		# sign(swipe_vec.x) akan -1 atau +1
		linear_velocity.x = strength * sign(swipe_vec.x)
		print("Applied swipe, velocity.x =", linear_velocity.x)
	else:
		print("Swipe too kecil, diabaikan.")
