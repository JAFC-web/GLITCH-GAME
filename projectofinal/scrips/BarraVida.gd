# HealthManager.gd - Sistema singleton para mantener la vida entre escenas

extends Node

# Configuración de vida
var vida_maxima_base: float = 100.0
var vida_actual: float = 100.0
var primera_escena: bool = true

# Sistema de escenas y checkpoints
var escenas_visitadas: Dictionary = {}
var checkpoint_vida: float = 100.0
var escena_checkpoint: String = ""

# Señales para notificar cambios
signal vida_cambiada(vida_actual: float, vida_maxima: float)
signal vida_restaurada(vida_anterior: float, vida_nueva: float)
signal checkpoint_guardado(escena: String, vida: float)

func _ready():
	print("=== HealthManager Inicializado ===")
	# No cambiar la vida aquí, esperar a que el jugador se inicialice

# SISTEMA PRINCIPAL DE VIDA PERSISTENTE
func inicializar_jugador_en_escena(jugador_node: Node):
	"""Llamar desde el _ready() del jugador para sincronizar la vida"""
	if not jugador_node:
		return
	
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
	
	# Registrar escena visitada
	escenas_visitadas[escena_actual] = {
		"vida_al_entrar": vida_actual,
		"visitado": true
	}

func _conectar_jugador(jugador_node: Node):
	"""Conecta las señales del jugador con el HealthManager"""
	# Conectar señal de cambio de vida
	if jugador_node.has_signal("vida_cambiada"):
		if not jugador_node.vida_cambiada.is_connected(_on_jugador_vida_cambiada):
			jugador_node.vida_cambiada.connect(_on_jugador_vida_cambiada)
	
	# Conectar señal de muerte
	if jugador_node.has_signal("personaje_muerto"):
		if not jugador_node.personaje_muerto.is_connected(_on_jugador_muerto):
			jugador_node.personaje_muerto.connect(_on_jugador_muerto)
	
	# Conectar señal de daño recibido
	if jugador_node.has_signal("daño_recibido"):
		if not jugador_node.daño_recibido.is_connected(_on_jugador_daño_recibido):
			jugador_node.daño_recibido.connect(_on_jugador_daño_recibido)

func _on_jugador_vida_cambiada(nueva_vida: float, vida_max: float):
	"""Sincronizar cuando la vida del jugador cambia"""
	vida_actual = nueva_vida
	vida_maxima_base = vida_max
	print("HealthManager sincronizado - Vida: ", vida_actual, "/", vida_maxima_base)
	
	# Emitir nuestra propia señal
	vida_cambiada.emit(vida_actual, vida_maxima_base)

func _on_jugador_daño_recibido(cantidad_daño: float):
	"""Actualizar cuando el jugador recibe daño"""
	# La vida ya se actualiza en _on_jugador_vida_cambiada
	print("Jugador recibió ", cantidad_daño, " de daño. Vida restante: ", vida_actual)

func _on_jugador_muerto():
	"""Manejar cuando el jugador muere"""
	print("Jugador muerto. Restaurando desde checkpoint...")
	_restaurar_desde_checkpoint()

# SISTEMA DE CHECKPOINTS
func guardar_checkpoint(forzar: bool = false):
	"""Guarda un checkpoint con la vida actual"""
	var escena_actual = get_tree().current_scene.scene_file_path
	
	# Solo guardar si la vida es mayor que el checkpoint actual o se fuerza
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
	vida_restaurada.emit(vida_anterior, vida_actual)


func dañar_jugador(cantidad: float):
	"""Daña al jugador una cantidad específica"""
	var vida_anterior = vida_actual
	vida_actual = max(vida_actual - cantidad, 0)
	
	print("Jugador dañado: ", cantidad, " puntos. Vida: ", vida_anterior, " -> ", vida_actual)
	
	# Actualizar jugador si existe
	_actualizar_jugador_actual()
	
	return vida_anterior - vida_actual # Retorna la cantidad realmente dañada

func establecer_vida(nueva_vida: float):
	"""Establece la vida a un valor específico"""
	var vida_anterior = vida_actual
	vida_actual = clamp(nueva_vida, 0, vida_maxima_base)
	
	print("Vida establecida: ", vida_anterior, " -> ", vida_actual)
	
	# Actualizar jugador si existe
	_actualizar_jugador_actual()

func establecer_vida_maxima(nueva_vida_maxima: float):
	"""Cambia la vida máxima y ajusta la vida actual si es necesario"""
	var vida_maxima_anterior = vida_maxima_base
	vida_maxima_base = nueva_vida_maxima
	
	# Si la vida actual excede la nueva vida máxima, ajustarla
	if vida_actual > vida_maxima_base:
		vida_actual = vida_maxima_base
	
	print("Vida máxima cambiada: ", vida_maxima_anterior, " -> ", vida_maxima_base)
	
	# Actualizar jugador si existe
	_actualizar_jugador_actual()

func _actualizar_jugador_actual():
	"""Actualiza la vida del jugador actual en la escena"""
	var jugadores = get_tree().get_nodes_in_group("player")
	if jugadores.size() > 0:
		var jugador = jugadores[0]
		if jugador:
			jugador.vida_actual = vida_actual
			jugador.vida_maxima = vida_maxima_base
			
			# Emitir señal de cambio de vida
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

# FUNCIONES DE RESET Y CONFIGURACIÓN (SIN CURACIÓN AUTOMÁTICA)
func resetear_sistema():
	"""Resetea completamente el sistema de vida"""
	vida_actual = vida_maxima_base
	checkpoint_vida = vida_maxima_base
	escenas_visitadas.clear()
	primera_escena = true
	print("Sistema de vida reseteado completamente")

# FUNCIONES DE DEBUG
func debug_info():
	"""Muestra información de debug del sistema"""
	print("=== DEBUG HEALTH MANAGER ===")
	print("Vida actual: ", vida_actual)
	print("Vida máxima: ", vida_maxima_base)
	print("Porcentaje: ", obtener_porcentaje_vida(), "%")
	print("Checkpoint vida: ", checkpoint_vida)
	print("Escena checkpoint: ", escena_checkpoint)
	print("Escenas visitadas: ", escenas_visitadas.size())
	print("Es primera escena: ", primera_escena)
	print("==============================")

# FUNCIONES PARA PERSISTENCIA (OPCIONAL)
func guardar_datos() -> Dictionary:
	"""Guarda los datos del sistema para persistencia"""
	return {
		"vida_actual": vida_actual,
		"vida_maxima_base": vida_maxima_base,
		"checkpoint_vida": checkpoint_vida,
		"escena_checkpoint": escena_checkpoint,
		"escenas_visitadas": escenas_visitadas,
		"primera_escena": primera_escena
	}

func cargar_datos(datos: Dictionary):
	"""Carga los datos del sistema desde persistencia"""
	vida_actual = datos.get("vida_actual", vida_maxima_base)
	vida_maxima_base = datos.get("vida_maxima_base", 100.0)
	checkpoint_vida = datos.get("checkpoint_vida", vida_maxima_base)
	escena_checkpoint = datos.get("escena_checkpoint", "")
	escenas_visitadas = datos.get("escenas_visitadas", {})
	primera_escena = datos.get("primera_escena", false)
	
	print("Datos de vida cargados exitosamente")
	print("Vida cargada: ", vida_actual, "/", vida_maxima_base)
