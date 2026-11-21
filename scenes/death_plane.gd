extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.monitoring = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_death_plane_body_entered(body):
	print('entered')
