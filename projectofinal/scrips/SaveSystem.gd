extends Node
#saves

#Sistema de guardado 
var ruta: String = "user://game_save.dat"

var datos: Dictionary = {
	"player": {
		"position": Vector2.ZERO,
		"health": 100.0,
		"state": "NORMAL",
		"facing_right": true
	},
	"enemies": [],
	"boss": null,
	"coins": [],
	"game_state": {
		"points": 0,
		"high_score": 0,
		"level": "",
		"combo_count": 0,
		"combo_timer": 0.0,
		"level_enemies_killed": 0,
		"damage_taken_this_level": false
	}
}

# Variable para evitar conflictos durante la carga
var cargando_datos: bool = false

func _ready():
	# Conectar señales si es necesario
	pass

func guardar() -> bool:
	print("Iniciando guardado...")
	
	# Esperar un frame para asegurar que todos los datos estén actualizados
	await get_tree().process_frame
	
	# Collect player data
	var player = get_tree().get_first_node_in_group("player")
	if player:
		datos.player.position = player.global_position
		
		# Compatibilidad para vida
		if "vida_actual" in player:
			datos.player.health = player.vida_actual
		elif player.has_method("obtener_vida_actual"):
			datos.player.health = player.obtener_vida_actual()
		elif "health" in player:
			datos.player.health = player.health
		else:
			datos.player.health = 100.0
		
		# Compatibilidad para estado
		if "estado_actual" in player and "EstadoPlayer" in player:
			# Convertir enum a string
			var estado_keys = []
			for key in player.EstadoPlayer:
				if player.EstadoPlayer[key] == player.estado_actual:
					datos.player.state = key
					break
		elif "state" in player:
			datos.player.state = str(player.state)
		
		# Compatibilidad para dirección
		if "mirando_derecha" in player:
			datos.player.facing_right = player.mirando_derecha
		elif "facing_right" in player:
			datos.player.facing_right = player.facing_right
		
		print("Datos del jugador recolectados: pos=", datos.player.position, " vida=", datos.player.health, " estado=", datos.player.state)
	else:
		print("ADVERTENCIA: No se encontró jugador para guardar")
	
	# Collect enemies data - MEJORADO
	datos.enemies.clear()
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() == 0:
		enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and _enemy_esta_vivo(enemy):
			var enemy_data = {
				"position": enemy.global_position,
				"health": _get_enemy_health(enemy),
				"facing_right": _get_enemy_facing(enemy),
				"state": _get_enemy_state(enemy),
				"idle": _get_enemy_idle_state(enemy),
				"idle_time": _get_enemy_idle_time(enemy),
				"name": enemy.name,
				"scene_path": enemy.scene_file_path if "scene_file_path" in enemy else ""
			}
			datos.enemies.append(enemy_data)
			print("Enemigo guardado: ", enemy.name, " pos=", enemy_data.position, " vida=", enemy_data.health)
	print("Total enemigos guardados: ", datos.enemies.size())
	
	# Collect boss data - MEJORADO
	var boss = get_tree().get_first_node_in_group("boss")
	if boss and is_instance_valid(boss) and _boss_esta_vivo(boss):
		datos.boss = {
			"position": boss.global_position,
			"health": _get_boss_health(boss),
			"facing_right": _get_boss_facing(boss),
			"state": _get_boss_state(boss),
			"phase": _get_boss_phase(boss),
			"name": boss.name
		}
		print("Datos del jefe guardados: ", boss.name, " vida=", datos.boss.health, " fase=", datos.boss.phase)
	else:
		datos.boss = null
		print("No hay jefe vivo para guardar")
	
	# Collect coins data
	datos.coins.clear()
	var coins = get_tree().get_nodes_in_group("coins")
	for coin in coins:
		if coin and is_instance_valid(coin) and _coin_no_recolectada(coin):
			var coin_data = {
				"position": coin.global_position,
				"value": _get_coin_value(coin),
				"name": coin.name
			}
			datos.coins.append(coin_data)
	print("Monedas guardadas: ", datos.coins.size())
	
	# Collect game state
	_recopilar_estado_juego()
	
	# Guardar nivel actual
	datos.game_state.level = get_tree().current_scene.scene_file_path
	print("Nivel actual guardado: ", datos.game_state.level)
	
	# Save to file
	print("Guardando archivo en: ", ruta)
	var archivo = FileAccess.open(ruta, FileAccess.WRITE)
	if archivo:
		archivo.store_var(datos)
		archivo.close()
		print("¡Juego guardado exitosamente!")
		print("Datos guardados: jugador=", datos.player.position, " enemigos=", datos.enemies.size())
		return true
	else:
		var error = FileAccess.get_open_error()
		print("Error al guardar archivo. Código: ", error)
		return false

func cargar() -> bool:
	print("=== INICIANDO CARGA ===")
	
	if not FileAccess.file_exists(ruta):
		print("No existe archivo de guardado en: ", ruta)
		return false
	
	var archivo = FileAccess.open(ruta, FileAccess.READ)
	if not archivo:
		var error = FileAccess.get_open_error()
		print("Error al abrir archivo para cargar. Código: ", error)
		return false
	
	datos = archivo.get_var()
	archivo.close()
	
	if not datos:
		print("Error: datos cargados están vacíos o corruptos")
		return false
	
	print("Archivo leído exitosamente")
	print("Datos cargados: jugador en ", datos.player.position, ", ", datos.enemies.size(), " enemigos")
	
	cargando_datos = true
	
	# Verificar si necesitamos cambiar de escena
	var escena_actual = get_tree().current_scene.scene_file_path
	var escena_guardada = datos.game_state.level
	
	print("Escena actual: ", escena_actual)
	print("Escena guardada: ", escena_guardada)
	
	if escena_guardada != escena_actual and ResourceLoader.exists(escena_guardada):
		print("Necesario cambiar de escena. Cargando: ", escena_guardada)
		# Conectar señal para aplicar datos después del cambio de escena
		get_tree().tree_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)
		
		var result = get_tree().change_scene_to_file(escena_guardada)
		if result != OK:
			print("Error al cambiar de escena: ", result)
			cargando_datos = false
			return false
		
		# El resto de la carga se hará en _on_scene_changed
		return true
	else:
		# Estamos en la escena correcta, aplicar datos inmediatamente
		await get_tree().process_frame  # Esperar un frame
		return _aplicar_todos_los_datos()

func _on_scene_changed():
	print("Escena cambiada, aplicando datos guardados...")
	await get_tree().process_frame  # Esperar a que la nueva escena esté lista
	await get_tree().process_frame  # Esperar un frame adicional por seguridad
	
	_aplicar_todos_los_datos()

func _aplicar_todos_los_datos() -> bool:
	print("=== APLICANDO DATOS GUARDADOS ===")
	
	# Apply game state first
	_aplicar_estado_juego()
	
	# Apply player data
	if not _aplicar_datos_jugador():
		print("Error aplicando datos del jugador")
		cargando_datos = false
		return false
	
	# Apply enemies data
	_aplicar_datos_enemigos()
	
	# Apply boss data
	_aplicar_datos_boss()
	
	# Apply coins data
	_aplicar_datos_monedas()
	
	cargando_datos = false
	print("¡Todos los datos aplicados exitosamente!")
	return true

# Funciones auxiliares para obtener datos de enemigos
func _enemy_esta_vivo(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	if "esta_muerto" in enemy:
		return not enemy.esta_muerto
	elif "is_dead" in enemy:
		return not enemy.is_dead
	elif "muerto" in enemy:
		return not enemy.muerto
	elif enemy.has_method("esta_vivo"):
		return enemy.esta_vivo()
	# Si no tiene indicadores de muerte, asumir que está vivo
	return true

func _get_enemy_health(enemy) -> float:
	if "vida_actual" in enemy:
		return enemy.vida_actual
	elif "health" in enemy:
		return enemy.health
	elif "vida" in enemy:
		return enemy.vida
	elif enemy.has_method("obtener_vida_actual"):
		return enemy.obtener_vida_actual()
	elif enemy.has_method("get_health"):
		return enemy.get_health()
	return 50.0

func _get_enemy_facing(enemy) -> bool:
	if "mirando_derecha" in enemy:
		return enemy.mirando_derecha
	elif "facing_right" in enemy:
		return enemy.facing_right
	elif "sprite" in enemy and enemy.sprite:
		return not enemy.sprite.flip_h
	elif "sprite2d" in enemy and enemy.sprite2d:
		return not enemy.sprite2d.flip_h
	return true

func _get_enemy_state(enemy) -> String:
	if "esta_persiguiendo" in enemy:
		return "PURSUING" if enemy.esta_persiguiendo else "PATROLLING"
	elif "state" in enemy:
		return str(enemy.state)
	elif "estado" in enemy:
		return str(enemy.estado)
	return "PATROLLING"

func _get_enemy_idle_state(enemy) -> bool:
	if "haciendo_idle" in enemy:
		return enemy.haciendo_idle
	elif "is_idle" in enemy:
		return enemy.is_idle
	return false

func _get_enemy_idle_time(enemy) -> float:
	if "tiempo_idle_restante" in enemy:
		return enemy.tiempo_idle_restante
	elif "idle_time_remaining" in enemy:
		return enemy.idle_time_remaining
	return 0.0

# Funciones auxiliares para obtener datos del boss
func _boss_esta_vivo(boss) -> bool:
	if not is_instance_valid(boss):
		return false
	if "esta_muerto" in boss:
		return not boss.esta_muerto
	elif "muerte_iniciada" in boss:
		return not boss.muerte_iniciada
	elif "muerto" in boss:
		return not boss.muerto
	elif boss.has_method("esta_vivo"):
		return boss.esta_vivo()
	return true

func _get_boss_health(boss) -> float:
	if "vida_actual" in boss:
		return boss.vida_actual
	elif "health" in boss:
		return boss.health
	elif boss.has_method("get_vida_actual"):
		return boss.get_vida_actual()
	return 500.0

func _get_boss_facing(boss) -> bool:
	if "mirando_derecha" in boss:
		return boss.mirando_derecha
	elif "facing_right" in boss:
		return boss.facing_right
	return true

func _get_boss_state(boss) -> String:
	if "Estado" in boss and "estado_actual" in boss:
		# Convertir enum a string
		for key in boss.Estado:
			if boss.Estado[key] == boss.estado_actual:
				return key
	elif "state" in boss:
		return str(boss.state)
	return "PATRULLA"

func _get_boss_phase(boss) -> String:
	if boss.has_method("get_nombre_fase_actual"):
		return boss.get_nombre_fase_actual()
	elif "Fase" in boss and "fase_actual" in boss:
		for key in boss.Fase:
			if boss.Fase[key] == boss.fase_actual:
				return key
	return "NORMAL"

# Funciones auxiliares para monedas
func _coin_no_recolectada(coin) -> bool:
	if "recolectada" in coin:
		return not coin.recolectada
	elif "collected" in coin:
		return not coin.collected
	elif coin.has_method("is_collected"):
		return not coin.is_collected()
	return true

func _get_coin_value(coin) -> int:
	if "valor" in coin:
		return coin.valor
	elif "coin_value" in coin:
		return coin.coin_value
	elif "value" in coin:
		return coin.value
	return 1

# Recopilar estado del juego - MEJORADO
func _recopilar_estado_juego():
	print("Recopilando estado del juego...")
	
	# Buscar sistema de puntos en múltiples ubicaciones
	var posibles_sistemas = [
		"/root/PointSystem",
		"/root/GameManager",
		"/root/Game_Manager",
		"/root/PuntosManager",
		"/root/Puntos"
	]
	
	var point_system = null
	for ruta in posibles_sistemas:
		point_system = get_node_or_null(ruta)
		if point_system:
			print("Sistema de puntos encontrado en: ", ruta)
			break
	
	# También buscar en grupos
	if not point_system:
		var nodos_grupo = get_tree().get_nodes_in_group("game_manager")
		if nodos_grupo.size() > 0:
			point_system = nodos_grupo[0]
			print("Sistema de puntos encontrado en grupo: game_manager")
	
	if point_system:
		# Obtener puntos
		if point_system.has_method("obtener_puntos"):
			datos.game_state.points = point_system.obtener_puntos()
		elif "puntos" in point_system:
			datos.game_state.points = point_system.puntos
		elif "current_points" in point_system:
			datos.game_state.points = point_system.current_points
		elif "points" in point_system:
			datos.game_state.points = point_system.points
		
		# Obtener high score
		if "high_score" in point_system:
			datos.game_state.high_score = point_system.high_score
		elif point_system.has_method("get_high_score"):
			datos.game_state.high_score = point_system.get_high_score()
		
		# Obtener combo
		if "combo_count" in point_system:
			datos.game_state.combo_count = point_system.combo_count
		if "combo_timer" in point_system:
			datos.game_state.combo_timer = point_system.combo_timer
		
		# Obtener estadísticas del nivel
		if "level_enemies_killed" in point_system:
			datos.game_state.level_enemies_killed = point_system.level_enemies_killed
		if "damage_taken_this_level" in point_system:
			datos.game_state.damage_taken_this_level = point_system.damage_taken_this_level
		
		print("Estado del juego guardado: puntos=", datos.game_state.points, " high_score=", datos.game_state.high_score)
	else:
		print("No se encontró sistema de puntos")

func _aplicar_datos_jugador() -> bool:
	print("Aplicando datos del jugador...")
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: No se encontró jugador para cargar datos")
		return false
	
	if not datos.player:
		print("ERROR: No hay datos de jugador para cargar")
		return false
	
	# Aplicar posición
	player.global_position = datos.player.position
	print("Posición del jugador aplicada: ", player.global_position)
	
	# Aplicar vida
	var vida_aplicada = false
	if "vida_actual" in player:
		player.vida_actual = datos.player.health
		vida_aplicada = true
	elif player.has_method("set_health"):
		player.set_health(datos.player.health)
		vida_aplicada = true
	elif "health" in player:
		player.health = datos.player.health
		vida_aplicada = true
	
	if vida_aplicada:
		print("Vida del jugador aplicada: ", datos.player.health)
		
		# Emitir señal de vida cambiada si existe
		if player.has_signal("vida_cambiada"):
			var vida_maxima = player.vida_maxima if "vida_maxima" in player else 100.0
			player.vida_cambiada.emit(player.vida_actual, vida_maxima)
	else:
		print("ADVERTENCIA: No se pudo aplicar la vida del jugador")
	
	# Aplicar estado
	if "EstadoPlayer" in player and "estado_actual" in player:
		var estado_enum = player.EstadoPlayer.get(datos.player.state, player.EstadoPlayer.NORMAL)
		player.estado_actual = estado_enum
		print("Estado del jugador aplicado: ", datos.player.state)
	
	# Aplicar dirección
	if "mirando_derecha" in player:
		var cambio_direccion = player.mirando_derecha != datos.player.facing_right
		player.mirando_derecha = datos.player.facing_right
		
		if cambio_direccion:
			# Voltear sprites
			if "sprite" in player and player.sprite:
				player.sprite.scale.x = abs(player.sprite.scale.x) * (1 if player.mirando_derecha else -1)
			if "area_ataques" in player and player.area_ataques:
				player.area_ataques.scale.x = abs(player.area_ataques.scale.x) * (1 if player.mirando_derecha else -1)
		print("Dirección del jugador aplicada: ", "derecha" if player.mirando_derecha else "izquierda")
	
	return true

func _aplicar_datos_enemigos():
	print("Aplicando datos de enemigos...")
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() == 0:
		enemies = get_tree().get_nodes_in_group("enemies")
	
	print("Enemigos encontrados en escena: ", enemies.size())
	print("Enemigos en datos guardados: ", datos.enemies.size())
	
	# Primero, eliminar enemigos que no deberían existir
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			var enemy_pos = enemy.global_position
			var deberia_existir = false
			
			for data in datos.enemies:
				if enemy_pos.distance_to(data.position) < 50.0:  # Tolerancia de 50 pixeles
					deberia_existir = true
					break
			
			if not deberia_existir:
				print("Eliminando enemigo que no debería existir: ", enemy.name)
				enemy.queue_free()
	
	# Luego, aplicar datos a los enemigos existentes
	for data in datos.enemies:
		var enemy_encontrado = null
		var distancia_minima = 50.0
		
		# Buscar el enemigo más cercano a la posición guardada
		for enemy in enemies:
			if enemy and is_instance_valid(enemy):
				var distancia = enemy.global_position.distance_to(data.position)
				if distancia < distancia_minima:
					enemy_encontrado = enemy
					distancia_minima = distancia
		
		if enemy_encontrado:
			# Aplicar datos al enemigo encontrado
			enemy_encontrado.global_position = data.position
			
			# Aplicar vida
			if "vida_actual" in enemy_encontrado:
				enemy_encontrado.vida_actual = data.health
			elif "health" in enemy_encontrado:
				enemy_encontrado.health = data.health
			
			# Aplicar dirección
			if "mirando_derecha" in enemy_encontrado:
				enemy_encontrado.mirando_derecha = data.facing_right
			if "sprite" in enemy_encontrado and enemy_encontrado.sprite:
				enemy_encontrado.sprite.flip_h = not data.facing_right
			elif "sprite2d" in enemy_encontrado and enemy_encontrado.sprite2d:
				enemy_encontrado.sprite2d.flip_h = not data.facing_right
			
			# Aplicar estado
			if "esta_persiguiendo" in enemy_encontrado:
				enemy_encontrado.esta_persiguiendo = (data.state == "PURSUING")
			
			# Aplicar idle
			if "haciendo_idle" in enemy_encontrado:
				enemy_encontrado.haciendo_idle = data.idle
			if "tiempo_idle_restante" in enemy_encontrado:
				enemy_encontrado.tiempo_idle_restante = data.idle_time
			
			print("Enemigo aplicado: ", enemy_encontrado.name, " pos=", enemy_encontrado.global_position, " vida=", data.health)
		else:
			print("ADVERTENCIA: No se encontró enemigo para datos en posición: ", data.position)
	
	print("Datos de enemigos aplicados")

func _aplicar_datos_boss():
	if not datos.boss:
		print("No hay datos de jefe para aplicar")
		return
	
	print("Aplicando datos del jefe...")
	
	var boss = get_tree().get_first_node_in_group("boss")
	if not boss:
		print("No se encontró jefe en la escena")
		return
	
	# Aplicar posición
	boss.global_position = datos.boss.position
	
	# Aplicar vida
	if "vida_actual" in boss:
		boss.vida_actual = datos.boss.health
		print("Vida del jefe aplicada: ", boss.vida_actual)
		
		# Emitir señal de vida cambiada
		if boss.has_signal("vida_cambiada"):
			var vida_maxima = boss.vida_maxima if "vida_maxima" in boss else 500.0
			boss.vida_cambiada.emit(boss.vida_actual, vida_maxima)
	
	# Aplicar dirección
	if "mirando_derecha" in boss:
		boss.mirando_derecha = datos.boss.facing_right
	if "sprite2d" in boss and boss.sprite2d:
		boss.sprite2d.flip_h = not datos.boss.facing_right
	
	# Aplicar estado
	if "Estado" in boss and "estado_actual" in boss:
		var estado_enum = boss.Estado.get(datos.boss.state, boss.Estado.PATRULLA)
		boss.estado_actual = estado_enum
	
	# Aplicar fase
	if "Fase" in boss and "fase_actual" in boss:
		var fase_enum = boss.Fase.get(datos.boss.phase, boss.Fase.NORMAL)
		boss.fase_actual = fase_enum
		
		# Actualizar stats por fase
		if boss.has_method("_actualizar_stats_por_fase"):
			boss._actualizar_stats_por_fase()
		if boss.has_method("_aplicar_efectos_visuales_fase"):
			boss._aplicar_efectos_visuales_fase()
	
	print("Datos del jefe aplicados: vida=", boss.vida_actual, " fase=", datos.boss.phase)

func _aplicar_datos_monedas():
	print("Aplicando datos de monedas...")
	
	var coins = get_tree().get_nodes_in_group("coins")
	var coins_to_keep = datos.coins
	
	print("Monedas en escena: ", coins.size(), " | Monedas guardadas: ", coins_to_keep.size())
	
	for coin in coins:
		if not coin or not is_instance_valid(coin):
			continue
			
		var coin_pos = coin.global_position
		var should_keep = false
		
		for coin_data in coins_to_keep:
			if coin_pos.distance_to(coin_data.position) < 10.0:  # Tolerancia de 10 pixeles
				should_keep = true
				# Aplicar valor si es diferente
				if coin.has_method("set_coin_value"):
					coin.set_coin_value(coin_data.value)
				elif "coin_value" in coin:
					coin.coin_value = coin_data.value
				elif "valor" in coin:
					coin.valor = coin_data.value
				break
		
		if not should_keep:
			print("Eliminando moneda recolectada: ", coin.name)
			coin.queue_free()
	
	print("Datos de monedas aplicados")

func _aplicar_estado_juego():
	print("Aplicando estado del juego...")
	
	if not datos.game_state:
		print("No hay datos de estado de juego")
		return
	
	# Buscar sistema de puntos
	var posibles_sistemas = [
		"/root/PointSystem",
		"/root/GameManager", 
		"/root/Game_Manager",
		"/root/PuntosManager",
		"/root/Puntos"
	]
	
	var point_system = null
	for ruta in posibles_sistemas:
		point_system = get_node_or_null(ruta)
		if point_system:
			break
	
	# También buscar en grupos
	if not point_system:
		var nodos_grupo = get_tree().get_nodes_in_group("game_manager")
		if nodos_grupo.size() > 0:
			point_system = nodos_grupo[0]
	
	if point_system:
		# Aplicar puntos
		if point_system.has_method("establecer_puntos"):
			point_system.establecer_puntos(datos.game_state.points)
		elif "puntos" in point_system:
			point_system.puntos = datos.game_state.points
		elif "current_points" in point_system:
			point_system.current_points = datos.game_state.points
		elif "points" in point_system:
			point_system.points = datos.game_state.points
		
		# Aplicar high score
		if "high_score" in point_system and datos.game_state.high_score > point_system.high_score:
			point_system.high_score = datos.game_state.high_score
		
		# Aplicar combo
		if "combo_count" in point_system:
			point_system.combo_count = datos.game_state.combo_count
		if "combo_timer" in point_system:
			point_system.combo_timer = datos.game_state.combo_timer
		
		# Aplicar estadísticas del nivel
		if "level_enemies_killed" in point_system:
			point_system.level_enemies_killed = datos.game_state.level_enemies_killed
		if "damage_taken_this_level" in point_system:
			point_system.damage_taken_this_level = datos.game_state.damage_taken_this_level
		
		# Emitir señales
		if point_system.has_signal("puntos_actualizados"):
			point_system.puntos_actualizados.emit()
		elif point_system.has_signal("points_changed"):
			point_system.points_changed.emit(point_system.current_points)
		
		print("Estado del juego aplicado: puntos=", datos.game_state.points)
	else:
		print("No se encontró sistema de puntos para aplicar estado")

# Funciones de utilidad
func existe_guardado() -> bool:
	return FileAccess.file_exists(ruta)

func eliminar_guardado() -> bool:
	if FileAccess.file_exists(ruta):
		var dir = DirAccess.open("user://")
		if dir:
			var result = dir.remove(ruta.get_file())
			if result == OK:
				print("Guardado eliminado exitosamente")
				return true
			else:
				print("Error al eliminar guardado: ", result)
	return false

func debug_mostrar_datos():
	print("=== DATOS DE GUARDADO ===")
	print("Jugador: pos=", datos.player.position, " vida=", datos.player.health, " estado=", datos.player.state)
	print("Enemigos: ", datos.enemies.size(), " enemigos guardados")
	for i in range(datos.enemies.size()):
		var enemy = datos.enemies[i]
		print("  Enemigo ", i, ": pos=", enemy.position, " vida=", enemy.health)
	print("Jefe: ", "Sí" if datos.boss else "No", " guardado")
	if datos.boss:
		print("  Jefe: vida=", datos.boss.health, " fase=", datos.boss.phase)
	print("Monedas: ", datos.coins.size(), " monedas guardadas")
	print("Estado del juego: puntos=", datos.game_state.points, " nivel=", datos.game_state.level)
	print("=========================")

# Funciones adicionales para debugging y manejo de errores
func validar_datos_guardado() -> bool:
	"""Valida que los datos guardados sean coherentes"""
	if not datos:
		return false
	
	if not datos.has("player") or not datos.has("game_state"):
		return false
	
	if not datos.player.has("position") or not datos.player.has("health"):
		return false
	
	return true

func limpiar_datos_corruptos():
	"""Limpia datos que puedan estar corruptos"""
	# Filtrar enemigos inválidos
	var enemigos_validos = []
	for enemy_data in datos.enemies:
		if enemy_data.has("position") and enemy_data.has("health") and enemy_data.health > 0:
			enemigos_validos.append(enemy_data)
	datos.enemies = enemigos_validos
	
	# Filtrar monedas inválidas
	var monedas_validas = []
	for coin_data in datos.coins:
		if coin_data.has("position") and coin_data.has("value"):
			monedas_validas.append(coin_data)
	datos.coins = monedas_validas
	
	# Validar datos del jugador
	if datos.player.health <= 0:
		datos.player.health = 1.0  # Asegurar que el jugador tenga al menos 1 de vida
	
	print("Datos limpiados: ", datos.enemies.size(), " enemigos, ", datos.coins.size(), " monedas")

func obtener_info_guardado() -> Dictionary:
	"""Devuelve información básica sobre el guardado actual"""
	if not existe_guardado():
		return {"existe": false}
	
	var archivo = FileAccess.open(ruta, FileAccess.READ)
	if not archivo:
		return {"existe": true, "valido": false, "error": "No se puede leer"}
	
	var datos_temp = archivo.get_var()
	archivo.close()
	
	if not datos_temp:
		return {"existe": true, "valido": false, "error": "Datos corruptos"}
	
	var info = {
		"existe": true,
		"valido": true,
		"jugador_vida": datos_temp.get("player", {}).get("health", 0),
		"jugador_posicion": datos_temp.get("player", {}).get("position", Vector2.ZERO),
		"enemigos_count": datos_temp.get("enemies", []).size(),
		"tiene_jefe": datos_temp.get("boss") != null,
		"monedas_count": datos_temp.get("coins", []).size(),
		"puntos": datos_temp.get("game_state", {}).get("points", 0),
		"nivel": datos_temp.get("game_state", {}).get("level", ""),
		"fecha_modificacion": FileAccess.get_modified_time(ruta)
	}
	
	return info

# Funciones para guardar/cargar configuraciones específicas
func guardar_solo_puntos() -> bool:
	"""Guarda solo el estado de puntos sin afectar posiciones de entidades"""
	_recopilar_estado_juego()
	
	var datos_puntos = {
		"game_state": datos.game_state,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var ruta_puntos = "user://points_save.dat"
	var archivo = FileAccess.open(ruta_puntos, FileAccess.WRITE)
	if archivo:
		archivo.store_var(datos_puntos)
		archivo.close()
		print("Puntos guardados exitosamente")
		return true
	return false

func cargar_solo_puntos() -> bool:
	"""Carga solo el estado de puntos"""
	var ruta_puntos = "user://points_save.dat"
	if not FileAccess.file_exists(ruta_puntos):
		return false
	
	var archivo = FileAccess.open(ruta_puntos, FileAccess.READ)
	if not archivo:
		return false
	
	var datos_puntos = archivo.get_var()
	archivo.close()
	
	if datos_puntos and datos_puntos.has("game_state"):
		datos.game_state = datos_puntos.game_state
		_aplicar_estado_juego()
		print("Puntos cargados exitosamente")
		return true
	return false

# Funciones para backup automático
func crear_backup():
	"""Crea una copia de seguridad del guardado actual"""
	if not existe_guardado():
		return false
	
	var ruta_backup = ruta.replace(".dat", "_backup.dat")
	var dir = DirAccess.open("user://")
	if dir:
		dir.copy(ruta, ruta_backup)
		print("Backup creado en: ", ruta_backup)
		return true
	return false

func restaurar_backup() -> bool:
	"""Restaura desde la copia de seguridad"""
	var ruta_backup = ruta.replace(".dat", "_backup.dat")
	if not FileAccess.file_exists(ruta_backup):
		print("No existe backup para restaurar")
		return false
	
	var dir = DirAccess.open("user://")
	if dir:
		dir.copy(ruta_backup, ruta)
		print("Backup restaurado")
		return true
	return false

# Sistema de guardado rápido (quicksave)
func guardar_rapido() -> bool:
	"""Guardado rápido que no interrumpe el gameplay"""
	var ruta_rapida = "user://quicksave.dat"
	
	# Crear datos mínimos para guardado rápido
	var datos_rapidos = {
		"player": {
			"position": Vector2.ZERO,
			"health": 100.0
		},
		"game_state": {
			"points": 0,
			"level": get_tree().current_scene.scene_file_path
		},
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Obtener datos del jugador
	var player = get_tree().get_first_node_in_group("player")
	if player:
		datos_rapidos.player.position = player.global_position
		if "vida_actual" in player:
			datos_rapidos.player.health = player.vida_actual
	
	# Obtener puntos
	_recopilar_estado_juego()
	datos_rapidos.game_state = datos.game_state
	
	var archivo = FileAccess.open(ruta_rapida, FileAccess.WRITE)
	if archivo:
		archivo.store_var(datos_rapidos)
		archivo.close()
		return true
	return false

func cargar_rapido() -> bool:
	"""Carga rápida que solo restaura jugador y puntos"""
	var ruta_rapida = "user://quicksave.dat"
	if not FileAccess.file_exists(ruta_rapida):
		return false
	
	var archivo = FileAccess.open(ruta_rapida, FileAccess.READ)
	if not archivo:
		return false
	
	var datos_rapidos = archivo.get_var()
	archivo.close()
	
	if not datos_rapidos:
		return false
	
	# Aplicar solo datos del jugador
	var player = get_tree().get_first_node_in_group("player")
	if player and datos_rapidos.has("player"):
		player.global_position = datos_rapidos.player.position
		if "vida_actual" in player:
			player.vida_actual = datos_rapidos.player.health
			if player.has_signal("vida_cambiada"):
				var vida_maxima = player.vida_maxima if "vida_maxima" in player else 100.0
				player.vida_cambiada.emit(player.vida_actual, vida_maxima)
	
	# Aplicar puntos
	if datos_rapidos.has("game_state"):
		datos.game_state = datos_rapidos.game_state
		_aplicar_estado_juego()
	
	print("Carga rápida completada")
	return true
