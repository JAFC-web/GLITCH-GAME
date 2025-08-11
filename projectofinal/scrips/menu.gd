extends Control
#MENU

# Referencia al sistema de guardado
@onready var save_system = get_node("/root/SaveSystem") # Si es AutoLoad
# O ajusta según tu estructura de nodos

func _on_npartida_pressed() -> void:
	get_tree().change_scene_to_file("res://lvls/lvl_1.tscn")

func _on_cpartida_pressed() -> void:
	# Verificar si existe un archivo de guardado antes de cargar
	if save_system and save_system.existe_guardado():
		var success = save_system.cargar()
		if success:
			print("¡Partida cargada exitosamente!")
		else:
			print("Error al cargar la partida")
	elif save_system:
		print("No hay partida guardada disponible")
		# Opcional: mostrar mensaje al jugador
	else:
		print("Error: No se pudo acceder al sistema de guardado")

func _on_salir_pressed() -> void:
	get_tree().quit()

func _on_tuto_pressed() -> void:
	get_tree().change_scene_to_file("res://lvls/mapa_1.tscn")
