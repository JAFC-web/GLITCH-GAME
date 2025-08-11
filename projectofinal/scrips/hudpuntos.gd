extends Control

# Referencia al label de puntos
@onready var points_label = $puntos  # Ajusta la ruta según tu nodo

func _ready():
	# Conectar al sistema de puntos
	if PointSystem:
		PointSystem.points_changed.connect(_on_points_changed)
		
		# Mostrar puntos iniciales
		update_points_display(PointSystem.get_current_points())
		print("HUD conectado - Puntos iniciales:", PointSystem.get_current_points())
	else:
		print("ERROR: PointSystem no encontrado")

func _on_points_changed(new_points: int):
	"""Actualizar cuando cambien los puntos"""
	update_points_display(new_points)

func update_points_display(points: int):
	"""Actualizar el texto de puntos"""
	points_label.text = "Puntos: " + str(points).pad_zeros(4)
