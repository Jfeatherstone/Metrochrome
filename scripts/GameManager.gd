extends Node

# This will be assigned in the pause_menu script, so we can leave it null for now.
var pause_menu: CanvasLayer = null
var game_paused = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var save_file = FileAccess.open("user://savegame.save", FileAccess.READ_WRITE)
	print(save_file.get_line())
	for i in range(save_file.get_length()):
		print(save_file.get_line())
		
	save_file.store_line('test_1')
	#print(FileAccess.file_exists("user://savegame.save"))
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:	
	if Input.is_action_just_pressed('pause'):
		toggle_pause()
			
func toggle_pause():
	game_paused = !game_paused
	get_tree().paused = game_paused
	
	if game_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	pause_menu.toggle_visibility()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print('bye')
		
		get_tree().quit() # default behavior
