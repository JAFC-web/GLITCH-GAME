extends Control
#PAUSE

# Referencia al sistema de guardado (ajusta la ruta según tu estructura)
@onready var save_system = get_node("/root/SaveSystem") # Si es AutoLoad
# @onready var save_system = get_node("../SaveSystem") # Ajusta según tu jerarquía

# Si el script está en otro nodo:
# @onready var save_system = get_node("../SaveSystem") # Ajusta según tu jerarquía

func _on_salir_m_pressed() -> void:
	get_tree().change_scene_to_file("res://menu/menu.tscn")

func _on_salir_j_pressed() -> void:
	get_tree().quit()

func _on_save_pressed() -> void:
	if save_system:
		var success = await save_system.guardar()
		if success:
			print("¡Juego guardado exitosamente!")
			# Opcional: mostrar mensaje visual al jugador
		else:
			print("Error al guardar el juego")
	else:
		print("Error: No se pudo acceder al sistema de guardado")
