extends Node

# Configuración de vida
var vida_maxima_base: float = 100.0
var vida_actual: float = 100.0
var primera_escena: bool = true

# Sistema de escenas y checkpoints
var escenas_visitadas: Dictionary = {}
var checkpoint_vida: float = 100.0
var escena_checkpoint: String = ""

# Referencias a UI - Mejorado para TextureProgressBar
var health_bar_actual: Control = null
var texture_progress_bar: TextureProgressBar = null
var jugador_actual: Node = null

# Control de sincronización
var ui_inicializada: bool = false
var necesita_actualizacion: bool = false

# Señales para notificar cambios
signal vida_cambiada(vida_actual: float, vida_maxima: float)
signal vida_restaurada(vida_anterior: float, vida_nueva: float)
signal checkpoint_guardado(escena: String, vida: float)

func _ready():
	print("=== HealthManager Inicializado ===")
	# Conectar a cambios de escena
	get_tree().node_added.connect(_on_node_added)
	get_tree().current_scene.tree_entered.connect(_on_scene_tree_entered)
	# Esperar múltiples frames para que la escena esté completamente cargada
	call_deferred("_inicializar_con_delay")

func _inicializar_con_delay():
	"""Inicialización con delay para asegurar que la escena esté lista"""
	await get_tree().process_frame
	await get_tree().process_frame
	_buscar_elementos_iniciales()

func _on_scene_tree_entered():
	"""Se ejecuta cuando una nueva escena entra al árbol"""
	print("Nueva escena detectada, reiniciando búsqueda de UI")
	ui_inicializada = false
	texture_progress_bar = null
	health_bar_actual = null
	# Retrasar la búsqueda para que la escena esté completamente cargada
	call_deferred("_buscar_elementos_con_reintentos")

func _buscar_elementos_con_reintentos():
	"""Busca elementos con múltiples reintentos"""
	for i in range(5):  # Máximo 5 intentos
		_buscar_elementos_iniciales()
		if texture_progress_bar:
			break
		await get_tree().create_timer(0.1).timeout
	
	# Si después de todos los intentos no encontramos nada, programar búsqueda continua
	if not texture_progress_bar:
		_iniciar_busqueda_continua()

func _iniciar_busqueda_continua():
	"""Inicia una búsqueda continua hasta encontrar el TextureProgressBar"""
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(_buscar_elementos_iniciales)
	
	# Repetir cada 0.5 segundos hasta encontrar la UI
	if not texture_progress_bar:
		_iniciar_busqueda_continua()

func _buscar_elementos_iniciales():
	"""Busca elementos iniciales cuando se carga la escena"""
	if not ui_inicializada:
		_buscar_y_conectar_health_bar()
		_buscar_jugador()
		
		if texture_progress_bar:
			ui_inicializada = true
			print("UI inicializada correctamente")
			# Forzar actualización inmediata
			_actualizar_health_bar_inmediato()

func _buscar_jugador():
	"""Busca el jugador en la escena"""
	var jugadores = get_tree().get_nodes_in_group("player")
	if jugadores.size() > 0:
		jugador_actual = jugadores[0]
		print("Jugador encontrado: ", jugador_actual.name)

func _on_node_added(node: Node):
	"""Detecta cuando se agregan nuevos nodos para encontrar UI"""
	# Buscar TextureProgressBar específicamente
	if node is TextureProgressBar and not texture_progress_bar:
		health_bar_actual = node
		texture_progress_bar = node
		print("TextureProgressBar detectado: ", node.name)
		ui_inicializada = true
		# Actualizar inmediatamente y con delay por seguridad
		_actualizar_health_bar_inmediato()
		call_deferred("_actualizar_health_bar_inmediato")
		return
	
	# Buscar cualquier Control que pueda contener un TextureProgressBar
	if node is Control and not texture_progress_bar:
		var texture_bar = _buscar_texture_progress_bar_en_nodo(node)
		if texture_bar:
			health_bar_actual = node
			texture_progress_bar = texture_bar
			print("TextureProgressBar encontrado en Control: ", node.name)
			ui_inicializada = true
			_actualizar_health_bar_inmediato()
			call_deferred("_actualizar_health_bar_inmediato")
			return
	
	# Buscar jugador
	if node.is_in_group("player") and not jugador_actual:
		jugador_actual = node
		print("Jugador detectado: ", node.name)

# SISTEMA PRINCIPAL DE VIDA PERSISTENTE
func inicializar_jugador_en_escena(jugador_node: Node):
	"""Llamar desde el _ready() del jugador para sincronizar la vida"""
	if not jugador_node:
		return
	
	jugador_actual = jugador_node
	var escena_actual = get_tree().current_scene.scene_file_path
	print("Inicializando jugador en escena: ", escena_actual)
	print("Vida actual en HealthManager: ", vida_actual)
	print("Es primera escena: ", primera_escena)
	
	# Si es la primera vez que se ejecuta el juego
	if primera_escena:
		vida_maxima_base = jugador_node.vida_maxima
		vida_actual = jugador_node.vida_maxima
		primera_escena = false
		checkpoint_vida = vida_actual
		escena_checkpoint = escena_actual
		print("Primera inicialización - Vida establecida en: ", vida_actual)
	else:
		# Aplicar la vida persistente al jugador
		jugador_node.vida_actual = vida_actual
		jugador_node.vida_maxima = vida_maxima_base
		print("Vida restaurada en jugador: ", vida_actual, "/", vida_maxima_base)
		
		# Emitir señal para actualizar UI
		if jugador_node.has_signal("vida_cambiada"):
			jugador_node.vida_cambiada.emit(vida_actual, vida_maxima_base)
	
	# Conectar señales del jugador
	_conectar_jugador(jugador_node)
	
	# Buscar y conectar HealthBar existente con múltiples intentos
	_buscar_elementos_con_reintentos()
	
	# Registrar escena visitada
	escenas_visitadas[escena_actual] = {
		"vida_al_entrar": vida_actual,
		"visitado": true
	}
	
	# Múltiples intentos de actualización de UI
	call_deferred("_actualizar_health_bar_inmediato")
	get_tree().create_timer(0.1).timeout.connect(_actualizar_health_bar_inmediato)
	get_tree().create_timer(0.3).timeout.connect(_actualizar_health_bar_inmediato)

func _buscar_y_conectar_health_bar():
	"""Busca el HealthBar/TextureProgressBar en la escena actual y lo conecta"""
	print("Buscando HealthBar en la escena...")
	
	# Método 1: Buscar directamente TextureProgressBar
	var texture_bars = _obtener_todos_los_texture_progress_bars()
	if texture_bars.size() > 0:
		texture_progress_bar = texture_bars[0]
		health_bar_actual = texture_progress_bar
		print("TextureProgressBar encontrado directamente: ", texture_progress_bar.name)
		return
	
	# Método 2: Buscar por grupo si existe
	var health_bars = get_tree().get_nodes_in_group("health_ui")
	if health_bars.size() > 0:
		health_bar_actual = health_bars[0]
		var texture_bar = _buscar_texture_progress_bar_en_nodo(health_bar_actual)
		if texture_bar:
			texture_progress_bar = texture_bar
		print("HealthBar encontrado por grupo: ", health_bar_actual.name)
		return
	
	# Método 3: Buscar por nombre común
	var escena_actual = get_tree().current_scene
	var health_bar = _buscar_nodo_recursivo(escena_actual, "HealthBar")
	if not health_bar:
		health_bar = _buscar_nodo_recursivo(escena_actual, "TextureProgressBar")
	if not health_bar:
		health_bar = _buscar_nodo_recursivo(escena_actual, "BarraVida")
	
	if health_bar:
		health_bar_actual = health_bar
		if health_bar is TextureProgressBar:
			texture_progress_bar = health_bar
		else:
			var texture_bar = _buscar_texture_progress_bar_en_nodo(health_bar)
			if texture_bar:
				texture_progress_bar = texture_bar
		print("HealthBar encontrado por búsqueda: ", health_bar_actual.name)
	else:
		print("ADVERTENCIA: No se encontró ningún HealthBar en la escena")

func _obtener_todos_los_texture_progress_bars() -> Array:
	"""Obtiene todos los TextureProgressBar en la escena actual"""
	var texture_bars = []
	_buscar_texture_progress_bars_recursivo(get_tree().current_scene, texture_bars)
	return texture_bars

func _buscar_texture_progress_bars_recursivo(nodo: Node, resultado: Array):
	"""Busca TextureProgressBars recursivamente"""
	if nodo is TextureProgressBar:
		resultado.append(nodo)
	
	for hijo in nodo.get_children():
		_buscar_texture_progress_bars_recursivo(hijo, resultado)

func _buscar_texture_progress_bar_en_nodo(nodo: Node) -> TextureProgressBar:
	"""Busca un TextureProgressBar dentro de un nodo específico"""
	if nodo is TextureProgressBar:
		return nodo
	
	for hijo in nodo.get_children():
		if hijo is TextureProgressBar:
			return hijo
		
		# Buscar recursivamente
		var resultado = _buscar_texture_progress_bar_en_nodo(hijo)
		if resultado:
			return resultado
	
	return null

func _buscar_nodo_recursivo(nodo: Node, nombre_buscado: String) -> Node:
	"""Busca un nodo por nombre de forma recursiva"""
	if nodo.name.to_lower().contains(nombre_buscado.to_lower()):
		return nodo
	
	for hijo in nodo.get_children():
		var resultado = _buscar_nodo_recursivo(hijo, nombre_buscado)
		if resultado:
			return resultado
	
	return null

func _conectar_jugador(jugador_node: Node):
	"""Conecta las señales del jugador con el HealthManager"""
	# Desconectar señales previas si existen
	if jugador_node.has_signal("vida_cambiada"):
		if jugador_node.vida_cambiada.is_connected(_on_jugador_vida_cambiada):
			jugador_node.vida_cambiada.disconnect(_on_jugador_vida_cambiada)
		jugador_node.vida_cambiada.connect(_on_jugador_vida_cambiada)
	
	if jugador_node.has_signal("personaje_muerto"):
		if jugador_node.personaje_muerto.is_connected(_on_jugador_muerto):
			jugador_node.personaje_muerto.disconnect(_on_jugador_muerto)
		jugador_node.personaje_muerto.connect(_on_jugador_muerto)
	
	if jugador_node.has_signal("daño_recibido"):
		if jugador_node.daño_recibido.is_connected(_on_jugador_daño_recibido):
			jugador_node.daño_recibido.disconnect(_on_jugador_daño_recibido)
		jugador_node.daño_recibido.connect(_on_jugador_daño_recibido)

func _on_jugador_vida_cambiada(nueva_vida: float, vida_max: float):
	"""Sincronizar cuando la vida del jugador cambia"""
	vida_actual = nueva_vida
	vida_maxima_base = vida_max
	print("HealthManager sincronizado - Vida: ", vida_actual, "/", vida_maxima_base)
	
	# Actualizar UI inmediatamente
	_actualizar_health_bar_inmediato()
	
	# Emitir nuestra propia señal
	vida_cambiada.emit(vida_actual, vida_maxima_base)

func _on_jugador_daño_recibido(cantidad_daño: float):
	"""Actualizar cuando el jugador recibe daño"""
	print("Jugador recibió ", cantidad_daño, " de daño. Vida restante: ", vida_actual)
	_actualizar_health_bar_inmediato()

func _on_jugador_muerto():
	"""Manejar cuando el jugador muere"""
	print("Jugador muerto. Restaurando desde checkpoint...")
	_restaurar_desde_checkpoint()

# SISTEMA DE ACTUALIZACIÓN DE UI - COMPLETAMENTE REESCRITO
func _actualizar_health_bar_inmediato():
	"""Actualiza inmediatamente el HealthBar sin buscar referencias"""
	if not texture_progress_bar:
		print("TextureProgressBar no disponible, buscando...")
		_buscar_y_conectar_health_bar()
		
		# Si aún no se encuentra, agendar para más tarde
		if not texture_progress_bar:
			necesita_actualizacion = true
			return
	
	# Resetear completamente los valores antes de asignar
	texture_progress_bar.max_value = 100.0  # Valor temporal
	texture_progress_bar.value = 0.0       # Resetear a 0
	
	# Esperar un frame para que se apliquen los cambios
	await get_tree().process_frame
	
	# Ahora establecer los valores correctos
	texture_progress_bar.max_value = vida_maxima_base
	texture_progress_bar.value = vida_actual
	
	# Verificación adicional
	await get_tree().process_frame
	
	print("TextureProgressBar actualizado INMEDIATO:")
	print("  - Vida actual: ", vida_actual)
	print("  - Vida máxima: ", vida_maxima_base)
	print("  - Value en UI: ", texture_progress_bar.value)
	print("  - Max Value en UI: ", texture_progress_bar.max_value)
	print("  - Porcentaje calculado: ", (vida_actual / vida_maxima_base) * 100.0, "%")
	
	# Forzar redibujado
	if texture_progress_bar.has_method("queue_redraw"):
		texture_progress_bar.queue_redraw()
	
	necesita_actualizacion = false

func _actualizar_health_bar():
	"""Versión legacy mantenida por compatibilidad"""
	_actualizar_health_bar_inmediato()

# Proceso continuo para asegurar sincronización
func _process(_delta):
	"""Verifica continuamente si necesita actualizar la UI"""
	if necesita_actualizacion and texture_progress_bar:
		_actualizar_health_bar_inmediato()

# SISTEMA DE CHECKPOINTS
func guardar_checkpoint(forzar: bool = false):
	"""Guarda un checkpoint con la vida actual"""
	var escena_actual = get_tree().current_scene.scene_file_path
	
	if vida_actual > checkpoint_vida or forzar:
		checkpoint_vida = vida_actual
		escena_checkpoint = escena_actual
		print("Checkpoint guardado - Escena: ", escena_actual, " Vida: ", checkpoint_vida)
		checkpoint_guardado.emit(escena_actual, checkpoint_vida)

func _restaurar_desde_checkpoint():
	"""Restaura la vida desde el último checkpoint"""
	var vida_anterior = vida_actual
	vida_actual = checkpoint_vida
	print("Vida restaurada desde checkpoint: ", vida_anterior, " -> ", vida_actual)
	
	# Actualizar jugador y UI con múltiples intentos
	_actualizar_jugador_actual()
	call_deferred("_actualizar_health_bar_inmediato")
	get_tree().create_timer(0.1).timeout.connect(_actualizar_health_bar_inmediato)
	
	vida_restaurada.emit(vida_anterior, vida_actual)

# FUNCIONES PÚBLICAS PARA MANIPULAR LA VIDA
func dañar_jugador(cantidad: float):
	"""Daña al jugador una cantidad específica"""
	var vida_anterior = vida_actual
	vida_actual = max(vida_actual - cantidad, 0)
	
	print("Jugador dañado: ", cantidad, " puntos. Vida: ", vida_anterior, " -> ", vida_actual)
	
	_actualizar_jugador_actual()
	_actualizar_health_bar_inmediato()
	
	return vida_anterior - vida_actual

func establecer_vida(nueva_vida: float):
	"""Establece la vida a un valor específico"""
	var vida_anterior = vida_actual
	vida_actual = clamp(nueva_vida, 0, vida_maxima_base)
	
	print("Vida establecida: ", vida_anterior, " -> ", vida_actual)
	
	_actualizar_jugador_actual()
	_actualizar_health_bar_inmediato()

func establecer_vida_maxima(nueva_vida_maxima: float):
	"""Cambia la vida máxima y ajusta la vida actual si es necesario"""
	var vida_maxima_anterior = vida_maxima_base
	vida_maxima_base = nueva_vida_maxima
	
	if vida_actual > vida_maxima_base:
		vida_actual = vida_maxima_base
	
	print("Vida máxima cambiada: ", vida_maxima_anterior, " -> ", vida_maxima_base)
	
	_actualizar_jugador_actual()
	_actualizar_health_bar_inmediato()

func _actualizar_jugador_actual():
	"""Actualiza la vida del jugador actual en la escena"""
	if jugador_actual:
		jugador_actual.vida_actual = vida_actual
		jugador_actual.vida_maxima = vida_maxima_base
		
		if jugador_actual.has_signal("vida_cambiada"):
			jugador_actual.vida_cambiada.emit(vida_actual, vida_maxima_base)
	else:
		var jugadores = get_tree().get_nodes_in_group("player")
		if jugadores.size() > 0:
			var jugador = jugadores[0]
			if jugador:
				jugador_actual = jugador
				jugador.vida_actual = vida_actual
				jugador.vida_maxima = vida_maxima_base
				
				if jugador.has_signal("vida_cambiada"):
					jugador.vida_cambiada.emit(vida_actual, vida_maxima_base)

# FUNCIONES DE CONSULTA
func obtener_vida_actual() -> float:
	return vida_actual

func obtener_vida_maxima() -> float:
	return vida_maxima_base

func obtener_porcentaje_vida() -> float:
	return (vida_actual / vida_maxima_base) * 100.0

func esta_vivo() -> bool:
	return vida_actual > 0

func esta_en_vida_critica(porcentaje_critico: float = 25.0) -> bool:
	return obtener_porcentaje_vida() <= porcentaje_critico

func obtener_checkpoint_info() -> Dictionary:
	return {
		"vida": checkpoint_vida,
		"escena": escena_checkpoint
	}

# FUNCIONES DE RESET Y CONFIGURACIÓN
func resetear_sistema():
	"""Resetea completamente el sistema de vida"""
	vida_actual = vida_maxima_base
	checkpoint_vida = vida_maxima_base
	escenas_visitadas.clear()
	primera_escena = true
	ui_inicializada = false
	necesita_actualizacion = true
	
	_actualizar_jugador_actual()
	call_deferred("_actualizar_health_bar_inmediato")
	
	print("Sistema de vida reseteado completamente")

# FUNCIONES PÚBLICAS PARA CONEXIÓN MANUAL Y DEBUGGING
func conectar_texture_progress_bar_manual(tpb: TextureProgressBar):
	"""Conecta manualmente un TextureProgressBar específico"""
	texture_progress_bar = tpb
	health_bar_actual = tpb
	ui_inicializada = true
	_actualizar_health_bar_inmediato()
	print("TextureProgressBar conectado manualmente: ", tpb.name)

func forzar_actualizacion_completa():
	"""Fuerza actualización completa del sistema"""
	ui_inicializada = false
	texture_progress_bar = null
	health_bar_actual = null
	_buscar_elementos_con_reintentos()

func debug_info():
	"""Muestra información de debug del sistema"""
	print("=== DEBUG HEALTH MANAGER ===")
	print("Vida actual: ", vida_actual)
	print("Vida máxima: ", vida_maxima_base)
	print("Porcentaje: ", obtener_porcentaje_vida(), "%")
	print("UI inicializada: ", ui_inicializada)
	print("Necesita actualización: ", necesita_actualizacion)
	print("TextureProgressBar: ", texture_progress_bar)
	
	if texture_progress_bar:
		print("--- TextureProgressBar Info ---")
		print("Value: ", texture_progress_bar.value)
		print("Max Value: ", texture_progress_bar.max_value)
		print("Porcentaje en UI: ", (texture_progress_bar.value / texture_progress_bar.max_value) * 100.0, "%")
	
	print("==============================")

# FUNCIONES PARA PERSISTENCIA
func guardar_datos() -> Dictionary:
	return {
		"vida_actual": vida_actual,
		"vida_maxima_base": vida_maxima_base,
		"checkpoint_vida": checkpoint_vida,
		"escena_checkpoint": escena_checkpoint,
		"escenas_visitadas": escenas_visitadas,
		"primera_escena": primera_escena
	}

func cargar_datos(datos: Dictionary):
	vida_actual = datos.get("vida_actual", vida_maxima_base)
	vida_maxima_base = datos.get("vida_maxima_base", 100.0)
	checkpoint_vida = datos.get("checkpoint_vida", vida_maxima_base)
	escena_checkpoint = datos.get("escena_checkpoint", "")
	escenas_visitadas = datos.get("escenas_visitadas", {})
	primera_escena = datos.get("primera_escena", false)
	
	ui_inicializada = false
	necesita_actualizacion = true
	
	call_deferred("_actualizar_health_bar_inmediato")
	get_tree().create_timer(0.5).timeout.connect(_actualizar_health_bar_inmediato)
	
	print("Datos de vida cargados - Vida: ", vida_actual, "/", vida_maxima_base)
