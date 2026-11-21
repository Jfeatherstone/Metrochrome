extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Assign this pause menu to the game manager
	GameManager.pause_menu = self
	# Start with pause menu invisible
	self.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func toggle_visibility():
	"""
	""" 
	self.visible = !self.visible
	#blurred_background.texture = get_viewport().get_texture()

func _on_resume_button_pressed() -> void:
	GameManager.toggle_pause()
