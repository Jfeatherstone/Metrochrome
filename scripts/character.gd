extends CharacterBody3D

@onready var camera_tether: SpringArm3D = $camera_parent/camera_tether
@onready var camera_mount: Node3D = $camera_parent/camera_tether/camera_mount

@onready var animation_player: AnimationPlayer = $character_body/UAL1_Standard/AnimationPlayer
@onready var character_body: Node3D = $character_body

# We have several cameras which can each only see certain objects
@onready var camera_red: Camera3D = $camera_parent/camera_tether/camera_mount/camera_red
@onready var camera_green: Camera3D = $camera_parent/camera_tether/camera_mount/camera_green
@onready var camera_blue: Camera3D = $camera_parent/camera_tether/camera_mount/camera_blue
# This needs the onready flag because otherwise it will be filled with null
# values since it will load before the nodes are properly linked.
@onready var cameras = [camera_red, camera_green, camera_blue]
# These are the visible layers that the cameras above correspond to.
const SWITCHABLE_VISIBLE_LAYERS = [2, 3, 4]
# All cameras can see layer 1.
const DEFAULT_VISION_LAYERS = [1]

# The collision layers assigned to each camera view
const SWITCHABLE_COLLISION_LAYERS = [2, 3, 4]
const DEFAULT_COLLISION_LAYERS = [1]
const DEATH_COLLISION_LAYER = 8

var current_layer_index = 0

# These control nodes are the HUD specific to each camera. They contain the
# color filters, etc.
@onready var red_control: Control = $player_hud/red_control
@onready var green_control: Control = $player_hud/green_control
@onready var blue_control: Control = $player_hud/blue_control
@onready var canvas_control_layers = [red_control, green_control, blue_control]

# We have two raycast objects for vaulting, since we want to have a slightly
# larger range when we are in-air. This prevents the user from not being able
# to vault if you can nearly reach the platform just by jumping.
# All of these raycasts are placed within the charater_body node so that they
# get properly rotated with the movement of the model.
@onready var vault_raycast: RayCast3D = $character_body/vault_raycast
@onready var air_vault_raycast: RayCast3D = $character_body/air_vault_raycast
@onready var overhead_collision_raycast: RayCast3D = $character_body/overhead_collision_raycast



const CAMERA_TETHER_MAX_DISTANCE = 3
const CAMERA_TETHER_MIN_DISTANCE = 1
const CAMERA_MOVE_SPEED = 0.01
const CHARACTER_HEIGHT = 1.85

# This is the speed scale that matches the Walk animation to a walk_speed of 1.
# Found by experimenting with different values and seeing what looks right.
var walk_animation_scale_default = 1.15
# This is the speed scale that matches the Sprint animation to a walk_speed of 1.
var sprint_animation_scale_default = 0.3
var jump_animation_scale_default = 1.0

var walk_speed = 2.
var sprint_speed = 5.
var jump_speed = 5.

# Time taken for a vault in seconds
const VAULT_DURATION = 0.6 # [s]
const VAULT_VERTICAL_PADDING = 0.02 # [m]
const VAULT_FORWARD_DISTANCE = 0.2 # [m]

# This is not given in the same units as the speeds above, but is the fractional
# weight of the new direction compared to the old one. It should be in the range
# (0, 1], with 1 meaning instant turning, and smaller numbers meaning smoother
# turning.
var directional_turning_speed = 0.2

# This is a reduction factor, so it divides the above number.
var directional_turning_speed_reduction = 3.
const AIR_DIRECTIONAL_TURNING_SPEED_REDUCTION = 2.

var floor_deceleration = 0.4
var air_deceleration = 0.05

# This is the speed the character is currently moving with.
var speed = walk_speed

# The previous direction we were facing, for implementing directional turning
# speed
var previous_direction = Vector3(0, 0, 0)

var is_sprinting = false
var is_jumping = false
var is_falling = false
var is_vaulting = false

var remaining_locked_time = 0

var camera_sensitivity_horizontal = 0.25
var camera_sensitivity_vertical = 0.25


func _ready():
	# Capture the mouse so we can use it to change the camera.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Set the camera and collision layer to the first one by default
	update_active_collision_layers()
	update_active_visible_layers()
	
	
func _input(event):
	# Rotate the camera based on mouse movement
	if event is InputEventMouseMotion:
		rotate_y(-camera_sensitivity_horizontal * deg_to_rad(event.relative.x))
		camera_tether.rotate_x(-camera_sensitivity_vertical * deg_to_rad(event.relative.y))
		
		# Counter-rotate the character model so that moving the camera doesn't
		# rotate the character.
		character_body.rotate_y(camera_sensitivity_horizontal * deg_to_rad(event.relative.x))

		
func _physics_process(delta: float) -> void:
	# Update which collision and vision layer we are on.
	#if Input.is_action_just_pressed("switch_camera"):
	#	current_layer_index = (current_layer_index + 1) % len(cameras)
	#	# Set the active collision layers
	#	update_active_collision_layers()
	#	# Set the active visible layers
	#	update_active_visible_layers()
		
	# If the camera is colliding with something, move the camera closer so it
	# doesn't collide. Otherwise, move the camera towards its max tether distance.
	#var current_camera_distance = (camera_mount.global_position - camera_tether.global_position).length()
	#var tether_direction = (camera_mount.global_position - camera_tether.global_position).normalized()
	#var mount_target_distance = camera_mount.global_position
	#if camera_collision_raycast.is_colliding():
		#var collision_distance = (camera_collision_raycast.get_collision_point() - camera_tether.global_position).length()
		#var target_distance = move_toward(current_camera_distance, max(collision_distance, CAMERA_TETHER_MIN_DISTANCE), CAMERA_MOVE_SPEED)
		#camera_mount.global_position = camera_tether.global_position - tether_direction * max(CAMERA_TETHER_MIN_DISTANCE, target_distance)
#
	#else:
	#camera_mount.global_position = camera_tether.global_position - tether_direction * (min(CAMERA_TETHER_MAX_DISTANCE, current_camera_distance * (1 + CAMERA_MOVE_SPEED)))
	#print(current_camera_distance)
	
	# Don't do any physics processing while we're vaulting.
	if is_vaulting:
		return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jumping and vaulting
	if Input.is_action_just_pressed("jump"):
		# Even if we aren't on the floor, we still could potentially
		# vault on top of an object.
		# For that to be possible, we need to have the vault raycast object
		# be colliding, and our overhead raycast *not* be colliding.
		
		var vaulted = false
		if !overhead_collision_raycast.is_colliding():
			if is_on_floor() and vault_raycast.is_colliding():
				vaulted = _handle_vault(vault_raycast.get_collision_point())
					
			# Otherwise we just do a normal jump
			elif !is_on_floor() and air_vault_raycast.is_colliding():
				vaulted = _handle_vault(air_vault_raycast.get_collision_point())
				
		if !vaulted and is_on_floor():
			_handle_jump()
						
	# If we reach the highest point of the jump and start moving down, we
	# are no longer jumping, we are falling
	if is_jumping and velocity.y <= 0:
		is_jumping = false
		is_falling = true
		
		# Playing the falling animation
		#animation_player.speed_scale = sprint_animation_scale_default
		animation_player.play('Jump')
		
	#print(animation_player.current_animation)
	
	# When we hit the floor, do the landing animation.
	# TODO This doesn't really work.
	if is_falling and is_on_floor():
		is_falling = false
		animation_player.play('Jump_Land')
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var movement_input_pressed = !direction.is_zero_approx()
	var direction_persistence = direction.dot(previous_direction)
	
	# If we are making quite a big change in direction, we should further reduce
	# the directional turning speed
	var effective_directional_turning_speed = directional_turning_speed
	if direction_persistence < 0:
		effective_directional_turning_speed /= directional_turning_speed_reduction
	
	if !is_on_floor():
		effective_directional_turning_speed /= AIR_DIRECTIONAL_TURNING_SPEED_REDUCTION
		
	# Compute the new direction incorporating the turning speed
	direction = (direction * effective_directional_turning_speed) + (previous_direction * (1 - effective_directional_turning_speed))
	
	# Can only switch from sprint to walk if we are on the ground
	# Also, we continue sprinting if we were last frame and we are still moving
	# in mostly the same direction.
	if is_on_floor():
		if Input.is_action_pressed("sprint") or (is_sprinting and movement_input_pressed and direction_persistence > 0):
			speed = sprint_speed
			is_sprinting = true
		else:
			speed = walk_speed
			is_sprinting = false
			
	# Allow adjustments to movement in the air, but animations won't play
	if movement_input_pressed:
		# Play appropriate animations, as long as we aren't in the air
		if is_on_floor() and !is_jumping:
			if is_sprinting:
				if animation_player.current_animation != 'Sprint':
					animation_player.speed_scale = speed * sprint_animation_scale_default
					animation_player.play('Sprint')
			else:
				if animation_player.current_animation != 'Walk':
					animation_player.speed_scale = speed * walk_animation_scale_default
					animation_player.play('Walk')

		# Make the character model properly face the direction of movement
		if remaining_locked_time <= 0:
			character_body.look_at(position + direction)
			
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
	elif is_on_floor() and !is_jumping:
		# Lower the velocity, given a feeling of momentum.
		velocity.x = move_toward(velocity.x, 0, floor_deceleration)
		velocity.z = move_toward(velocity.z, 0, floor_deceleration)
		
	else:
		# Lower the velocity, given a feeling of momentum.
		velocity.x = move_toward(velocity.x, 0, air_deceleration)
		velocity.z = move_toward(velocity.z, 0, air_deceleration)
		
		
	# Once we reach zero velocity, play the idle animation.
	if velocity.is_zero_approx():
		if animation_player.current_animation != 'Idle':
			animation_player.speed_scale = 0.5
			animation_player.play('Idle')
			
	# Note the current direction so we can use it for next frame
	previous_direction = direction
		
	if remaining_locked_time > 0:
		remaining_locked_time -= delta
	else:
		move_and_slide()

func update_active_visible_layers():
	var active_index = current_layer_index
	# Set the appropriate camera as the current one.
	# This is what makes world objects visible or not visible based on what
	# layers each camera can see. See SWITCHABLE_VISIBLE_LAYERS for the exact indices.
	cameras[current_layer_index].make_current()
	
	# Originally I tried to just put the control layers on different visibility
	# layers too, but I guess 3d camera's don't respect that for 2d canvas items,
	# so we just toggle visibility directly
	for i in range(len(canvas_control_layers)):
		canvas_control_layers[i].visible = i == active_index


func update_active_collision_layers():
	var active_index = current_layer_index
	# Set the collision layer of character. Note that you have to set both the
	# layer (for collision) and the mask (for detecting collisions).
	for i in range(len(SWITCHABLE_COLLISION_LAYERS)):
		set_collision_layer_value(SWITCHABLE_COLLISION_LAYERS[i], i == active_index)
		set_collision_mask_value(SWITCHABLE_COLLISION_LAYERS[i], i == active_index)

	# Now we also have to update the raycast object and things.
	for i in range(len(SWITCHABLE_COLLISION_LAYERS)):
		air_vault_raycast.set_collision_mask_value(SWITCHABLE_COLLISION_LAYERS[i], i == active_index)
		vault_raycast.set_collision_mask_value(SWITCHABLE_COLLISION_LAYERS[i], i == active_index)
		overhead_collision_raycast.set_collision_mask_value(SWITCHABLE_COLLISION_LAYERS[i], i == active_index)
		
	# Spring arms don't have the nice set_collision_mask_value function, so we
	# have to manually set the binary value.
	# An example value would be: 0b00000000_00000000_00000000_00001101
	# The first bit is layer 32, last bit is layer 1, so this value would enable
	# layers 1, 3, and 4.
	
	# First, enable the default layers.
	var bit_value = 0b0
	for i in range(len(DEFAULT_COLLISION_LAYERS)):
		bit_value = bit_value | (1 << DEFAULT_COLLISION_LAYERS[i] - 1)
		
	# Now enable the switchable layer
	bit_value = bit_value | (1 << SWITCHABLE_COLLISION_LAYERS[active_index] - 1)
	camera_tether.collision_mask = bit_value
	
	# DEBUG
	#var layer_values = []
	#for i in range(3):
		#layer_values.append(self.get_collision_layer_value(SWITCHABLE_COLLISION_LAYERS[i]))
	#print(layer_values)


func _handle_jump():
	# Add our jump velocity, and say that we are currently jumping
	velocity.y = jump_speed
	is_jumping = true
	
	# Now we play the Jump_Start animation
	animation_player.speed_scale = 1
	animation_player.play('Jump_Start')
	
	
func _handle_vault(ledge_point: Vector3):
	"""
	Handles vaulting onto objects.
	
	Returns
	-------
	true
		Vaulting was successful.
	false
		Vaulting was unsuccessful.
	"""
	# TODO: Do a head check
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		ledge_point,
		ledge_point + Vector3(0, CHARACTER_HEIGHT, 0),
		collision_mask
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)

	if result:
		return false
		
	is_vaulting = true
	# Set our velocity to zero
	velocity = Vector3.ZERO
	
	# The forward direction is based on the orientation of the character model,
	# not the camera, so we need to do a little math to get that direction.
	var forward_dir = -character_body.basis.z
	var destination_pos = ledge_point + forward_dir * VAULT_FORWARD_DISTANCE
	
	var start_pos = global_position
	# Use a fixed size of our character at 0.5
	var mid_pos = start_pos.lerp(destination_pos, 0.5) + Vector3(0, 0.5, 0)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	# Create a bound version of the function with the positions already filled
	# out, making this a single argument method (where that argument is the scalar t).
	var bound_bezier_move = _bezier_move.bind(start_pos, mid_pos, destination_pos + Vector3(0, VAULT_VERTICAL_PADDING, 0))
	# 0 and 1 are the start and final values of t for the above function.
	tween.tween_method(bound_bezier_move, 0., 1., VAULT_DURATION)
	# Set the is_vaulting variable back to false after the completion of the
	# interpolation.
	tween.tween_callback(func(): is_vaulting = false)
	
	# TODO: Play an animation, this doesn't really work yet because we need to
	# not have this immediately overwritten by walking or running. I probably
	# need to make a proper animation queue.
	animation_player.play("Crouch_Idle")
	
	# true since we could successfully vault.
	return true

func _bezier_move(t: float, start:Vector3, mid:Vector3, end:Vector3):
	var a = start.lerp(mid, t)
	var b = mid.lerp(end, t)
	global_position = a.lerp(b, t)


func _on_death_plane_body_entered(body: Node3D) -> void:
	"""
	What happens when the player intersects a death plane.
	"""
	self.velocity = Vector3.ZERO
	self.global_position = get_tree().current_scene.global_position
