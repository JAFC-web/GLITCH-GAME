extends Node

# Señales para notificar cambios
signal points_changed(new_points: int)
signal high_score_updated(new_high_score: int)
signal scene_reset_started(initial_points: int)
signal scene_reset_completed(restored_points: int)

# Variables principales
var current_points: int = 0
var high_score: int = 0
var session_stats: Dictionary = {}

# Configuración de puntos - CAMBIADO DE const A var
var POINTS_CONFIG = {
	"enemy_kill": 10,
	"boss_kill": 100,
	"coin_collect": 5
}

# Estados del juego
var level_enemies_killed: int = 0
var damage_taken_this_level: bool = false
var level_start_time: float = 0.0

func _ready():
	# Cargar puntuación máxima guardada
	load_high_score()
	
	# Inicializar estadísticas de sesión
	reset_session_stats()
	
	# Conectar a señales del juego si existen
	_connect_game_signals()
	
	print("Sistema de puntos inicializado")
	print("Puntuación máxima: ", high_score)
	
	# NUEVO: Conexión con el sistema de jugador
	_ready_player_connection()

func _process(_delta):
	# Proceso vacío - se pueden agregar otras funcionalidades aquí si es necesario
	pass

func _connect_game_signals():
	# Intentar conectar a señales existentes del jugador y enemigos
	# Esto se ejecutará cuando los nodos estén disponibles
	get_tree().call_group("player", "_connect_to_point_system")
	get_tree().call_group("enemies", "_connect_to_point_system")
	get_tree().call_group("boss", "_connect_to_point_system")

# ===== FUNCIONES PRINCIPALES DE PUNTOS =====

func add_points(amount: int, source: String = ""):
	current_points += amount
	
	# Actualizar estadísticas
	session_stats.total_points_earned += amount
	
	# Verificar nueva puntuación máxima
	if current_points > high_score:
		high_score = current_points
		save_high_score()
		high_score_updated.emit(high_score)
		print("¡Nueva puntuación máxima: ", high_score, "!")
	
	# Emitir señal de cambio
	points_changed.emit(current_points)
	
	print("Puntos ganados: +", amount, " (", source, ") - Total: ", current_points)

func enemy_killed():
	var base_points = POINTS_CONFIG.enemy_kill
	add_points(base_points, "Enemigo eliminado")
	
	# Actualizar estadísticas
	level_enemies_killed += 1
	session_stats.enemies_killed += 1

func boss_killed():
	var base_points = POINTS_CONFIG.boss_kill
	add_points(base_points, "Jefe eliminado")
	
	# Actualizar estadísticas
	session_stats.bosses_killed += 1

func coin_collected():
	add_points(POINTS_CONFIG.coin_collect, "Moneda recolectada")
	session_stats.coins_collected += 1

func player_took_damage():
	damage_taken_this_level = true

# ===== SISTEMA DE BONUS =====



func check_perfect_level_bonus():
	# Función removida - ya no se otorgan puntos por nivel perfecto
	pass

func start_new_level():
	level_enemies_killed = 0
	damage_taken_this_level = false
	level_start_time = Time.get_time_dict_from_system().second
	print("Nuevo nivel iniciado")

func end_level():
	print("Nivel completado - Enemigos eliminados: ", level_enemies_killed)

# ===== PERSISTENCIA DE DATOS =====

func save_high_score():
	var config = ConfigFile.new()
	config.set_value("scores", "high_score", high_score)
	config.set_value("scores", "total_games", session_stats.get("total_games", 0))
	
	var error = config.save("user://high_score.cfg")
	if error == OK:
		print("Puntuación máxima guardada: ", high_score)
	else:
		print("Error al guardar puntuación máxima: ", error)

func load_high_score():
	var config = ConfigFile.new()
	var error = config.load("user://high_score.cfg")
	
	if error == OK:
		high_score = config.get_value("scores", "high_score", 0)
		var total_games = config.get_value("scores", "total_games", 0)
		print("Puntuación máxima cargada: ", high_score)
		print("Partidas jugadas: ", total_games)
	else:
		print("No se encontró archivo de puntuación, creando nuevo...")
		high_score = 0

func reset_current_points():
	current_points = 0
	points_changed.emit(current_points)
	print("Puntos reiniciados")

func reset_session_stats():
	session_stats = {
		"enemies_killed": 0,
		"bosses_killed": 0,
		"coins_collected": 0,
		"total_points_earned": 0,
		"total_games": session_stats.get("total_games", 0) + (1 if session_stats.size() > 0 else 0)
	}

# ===== GETTERS PÚBLICOS =====

func get_current_points() -> int:
	return current_points

func get_high_score() -> int:
	return high_score

func get_session_stats() -> Dictionary:
	return session_stats.duplicate()

func get_points_for_action(action: String) -> int:
	return POINTS_CONFIG.get(action, 0)

# ===== FUNCIONES DE DEBUG Y TESTING =====

func add_test_points(amount: int):
	add_points(amount, "Test")

func simulate_enemy_kill():
	enemy_killed()

func simulate_boss_kill():
	boss_killed()

func simulate_coin_collect():
	coin_collected()

func simulate_player_damage():
	player_took_damage()

func print_current_stats():
	print("=== ESTADÍSTICAS ACTUALES ===")
	print("Puntos actuales: ", current_points)
	print("Puntuación máxima: ", high_score)
	print("Estadísticas de sesión:")
	for key in session_stats:
		print("  ", key, ": ", session_stats[key])
	print("===============================")

func reset_all_data():
	"""Función para resetear todo (útil para testing)"""
	current_points = 0
	high_score = 0
	reset_session_stats()
	
	# Borrar archivo guardado
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("high_score.cfg")
	
	points_changed.emit(current_points)
	print("Todos los datos del sistema de puntos han sido reseteados")

# ===== FUNCIONES PARA CONFIGURACIÓN AVANZADA =====

func set_points_config(action: String, new_value: int):
	"""Permite cambiar la configuración de puntos en tiempo de ejecución"""
	if action in POINTS_CONFIG:
		POINTS_CONFIG[action] = new_value
		print("Puntos para '", action, "' cambiados a: ", new_value)
	else:
		print("Acción no válida: ", action)

func get_points_config() -> Dictionary:
	return POINTS_CONFIG.duplicate()

func multiply_points_temporarily(multiplier: float, duration: float):
	"""Multiplica temporalmente todos los puntos ganados"""
	var original_config = POINTS_CONFIG.duplicate()
	
	# Aplicar multiplicador
	for key in POINTS_CONFIG:
		POINTS_CONFIG[key] = int(POINTS_CONFIG[key] * multiplier)
	
	print("Multiplicador de puntos x", multiplier, " activado por ", duration, " segundos")
	
	# Restaurar después del tiempo
	await get_tree().create_timer(duration).timeout
	
	for key in original_config:
		POINTS_CONFIG[key] = original_config[key]
	
	print("Multiplicador de puntos desactivado")

# ===== FUNCIONES PARA INTEGRACIÓN CON SISTEMA DE RESET DEL JUGADOR =====

func set_current_points(new_points: int):
	"""Establece los puntos actuales a un valor específico"""
	current_points = max(new_points, 0)
	points_changed.emit(current_points)
	print("Puntos establecidos a: ", current_points)

func restore_points_to(target_points: int):
	"""Restaura los puntos a un valor específico (para el sistema de reset)"""
	var old_points = current_points
	current_points = max(target_points, 0)
	
	# Verificar si se actualiza el high score
	if current_points > high_score:
		high_score = current_points
		save_high_score()
		high_score_updated.emit(high_score)
	
	points_changed.emit(current_points)
	print("Puntos restaurados de ", old_points, " a ", current_points)

func get_points_difference_since(initial_points: int) -> int:
	"""Obtiene la diferencia de puntos desde un valor inicial"""
	return current_points - initial_points

func can_restore_to_points(target_points: int) -> bool:
	"""Verifica si se puede restaurar a un valor específico de puntos"""
	return target_points >= 0

# ===== FUNCIONES PARA DEBUG DEL SISTEMA DE RESET =====

func debug_reset_system(initial_scene_points: int):
	"""Función de debug para el sistema de reset"""
	print("=== DEBUG RESET SYSTEM ===")
	print("Puntos actuales: ", current_points)
	print("Puntos iniciales de escena: ", initial_scene_points)
	print("Diferencia: ", current_points - initial_scene_points)
	print("High Score: ", high_score)
	print("==========================")

# ===== FUNCIONES DE COMPATIBILIDAD EXTENDIDAS =====

# Para compatibilidad con diferentes nombres de funciones que podría usar el jugador
func establecer_puntos(puntos: int):
	"""Alias en español para set_current_points"""
	set_current_points(puntos)

func obtener_puntos() -> int:
	"""Alias en español para get_current_points"""
	return get_current_points()

func restaurar_puntos(puntos_objetivo: int):
	"""Alias en español para restore_points_to"""
	restore_points_to(puntos_objetivo)

# Funciones adicionales que el sistema del jugador podría buscar
func set_puntos(puntos: int):
	set_current_points(puntos)

func setPuntos(puntos: int):
	set_current_points(puntos)

func update_points(new_points: int):
	set_current_points(new_points)

func set_score(score: int):
	set_current_points(score)

# Propiedades adicionales para compatibilidad
func get_puntos() -> int:
	return current_points

func get_points() -> int:
	return current_points

func get_score() -> int:
	return current_points

# ===== SISTEMA DE NOTIFICACIÓN PARA RESET =====

func notify_scene_reset(initial_points: int):
	"""Notifica que se va a hacer un reset de escena"""
	scene_reset_started.emit(initial_points)
	restore_points_to(initial_points)
	scene_reset_completed.emit(current_points)

# ===== FUNCIÓN PARA CONECTAR CON EL JUGADOR =====

func _connect_player_signals():
	"""Intenta conectar con las señales del jugador"""
	var players = get_tree().get_nodes_in_group("player")
	
	for player in players:
		if player.has_signal("daño_recibido"):
			if not player.daño_recibido.is_connected(player_took_damage):
				player.daño_recibido.connect(player_took_damage)
				print("Conectado con señal de daño del jugador")
		
		if player.has_signal("escena_reseteada"):
			if not player.escena_reseteada.is_connected(_on_scene_reset):
				player.escena_reseteada.connect(_on_scene_reset)
				print("Conectado con señal de reset de escena del jugador")

func _on_scene_reset(restored_points: int):
	"""Callback cuando el jugador resetea la escena"""
	print("Reset de escena detectado. Puntos restaurados: ", restored_points)
	# Aquí podrías hacer acciones adicionales si es necesario

# Llamar esta función en el _ready del PointSystem (agregar al final de _ready)
func _ready_player_connection():
	"""Agregar esta llamada al final del _ready() existente"""
	# Esperar un poco antes de intentar conectar
	await get_tree().create_timer(0.1).timeout
	_connect_player_signals()

# ===== FUNCIONES UTILITARIAS PARA EL SISTEMA DE RESET =====

func save_current_state() -> Dictionary:
	"""Guarda el estado actual del sistema"""
	return {
		"current_points": current_points,
		"high_score": high_score,
		"session_stats": session_stats.duplicate()
	}

func load_state(state: Dictionary):
	"""Carga un estado previamente guardado"""
	if state.has("current_points"):
		current_points = state.current_points
		points_changed.emit(current_points)
	
	if state.has("high_score"):
		high_score = state.high_score
	
	if state.has("session_stats"):
		session_stats = state.session_stats

func reset_to_checkpoint(checkpoint_points: int):
	"""Resetea a un checkpoint específico"""
	restore_points_to(checkpoint_points)
	damage_taken_this_level = false  # Resetear el estado de daño del nivel
	print("Reset a checkpoint con ", checkpoint_points, " puntos")
