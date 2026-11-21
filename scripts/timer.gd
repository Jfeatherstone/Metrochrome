extends Timer

@onready var character: CharacterBody3D = $"../Character"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.start()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timeout() -> void:
	"""
	On timeout, change the active layer of the character.
	"""	
	character.current_layer_index = (character.current_layer_index + 1) % len(character.cameras)
	# Set the active collision layers
	character.update_active_collision_layers()
	# Set the active visible layers
	character.update_active_visible_layers()
