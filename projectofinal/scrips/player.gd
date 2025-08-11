extends CharacterBody2D

# Configuración exportada
@export_group("Movimiento")
@export var velocidad_caminar: float = 200.0
@export var fuerza_salto: float = -400.0
@export var gravedad: float = 980.0

@export_group("Dash")
@export var velocidad_dash: float = 500.0
@export var duracion_dash: float = 0.3
@export var cooldown_dash: float = 1.0

@export_group("Cooldowns de Ataques")
@export var cooldown_ataque1: float = 2.0
@export var cooldown_ataque2: float = 3.0
@export var cooldown_ataque3: float = 4.0
@export var cooldown_ataque4: float = 15.0
@export var cooldown_especial2: float = 15.0
@export var cooldown_especialdoble: float = 10.0

@export_group("Sistema de Daño de Ataques")
@export var daño_ataque1: float = 10.0
@export var daño_ataque2: float = 15.0
@export var daño_ataque3: float = 15.0
@export var daño_ataque4: float = 40.0
@export var daño_especial2: float = 30.0
@export var daño_especialdoble: float = 20.0

@export_group("Sistema de Vida")
@export var vida_maxima: float = 100.0
@export var invulnerabilidad_duracion: float = 1.0

@export_group("Detección Doble Clic")
@export var tiempo_maximo_doble_clic: float = 0.3

@export_group("Configuración de Sonidos")
@export var volumen_ataques: float = 0.0
@export var volumen_hit: float = 0.0
@export var volumen_muerte: float = 0.0
@export var volumen_dash: float = 0.0

@export_group("Delays de Sonidos de Ataques")
@export var delay_sonido_ataque1: float = 0.0
@export var delay_sonido_ataque2: float = 0.0
@export var delay_sonido_ataque3: float = 0.0
@export var delay_sonido_ataque4: float = 0.0
@export var delay_sonido_especial2: float = 0.0
@export var delay_sonido_especialdoble: float = 0.0

@export_group("Sistema de Reset")
@export var tiempo_delay_reset: float = 3.0

# Referencias a nodos (cached)
@onready var animacion_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var area_ataques: Area2D = $Area2D
@onready var sonido_ataque1: AudioStreamPlayer = $ataque1
@onready var sonido_hit: AudioStreamPlayer = $hit
@onready var sonido_muerte: AudioStreamPlayer = $muerte
@onready var sonido_ataque4: AudioStreamPlayer = $ataque4
@onready var sonido_ataque2y3: AudioStreamPlayer = $ataque2y3
@onready var sonido_dash: AudioStreamPlayer = $dash
@onready var sonido_especial2: AudioStreamPlayer = $especial2
@onready var sonido_especialdoble: AudioStreamPlayer = $especialdoble

# Enums para mejor organización
enum EstadoPlayer {
	NORMAL,
	ATACANDO,
	DASH,
	MURIENDO,
	MUERTO
}

enum TipoAtaque {
	ATAQUE1,
	ATAQUE2,
	ATAQUE3,
	ATAQUE4,
	ESPECIAL2,
	ESPECIALDOBLE
}

# Variables de estado principales
var estado_actual: EstadoPlayer = EstadoPlayer.NORMAL
var mirando_derecha: bool = true

# Sistema de vida optimizado
var vida_actual: float
var invulnerable: bool = false
var tiempo_invulnerabilidad: float = 0.0

# Sistema de inmunidad por ataques especiales
var inmune_por_ataque: bool = false
var ataques_con_inmunidad: Array[TipoAtaque] = [TipoAtaque.ATAQUE4, TipoAtaque.ESPECIALDOBLE]

# Sistema de dash optimizado
var tiempo_dash: float = 0.0
var puede_dash: bool = true
var tiempo_cooldown_dash: float = 0.0

# Sistema de ataques optimizado con diccionarios
var cooldowns_ataques: Dictionary = {}
var puede_atacar: Dictionary = {}
var ataques_config: Dictionary = {}
var atacando: bool = false
var tipo_ataque_actual: TipoAtaque

# Sistema de delays de sonidos
var timers_sonidos: Dictionary = {}
var sonidos_pendientes: Dictionary = {}

# Variables para detección de doble clic optimizadas
var ultimo_input_direccion: Dictionary = {
	"tiempo_derecha": 0.0,
	"tiempo_izquierda": 0.0,
	"ultima_direccion": 0
}

# Sistema de reset de escena y conservación de puntos
var puntos_iniciales_escena: int = 0
var vida_inicial_escena: float = 0.0
var escena_actual: String = ""
var timer_reset: Timer
var muerte_procesada: bool = false

# Constantes para animaciones
const ANIMACIONES = {
	"idle": "idle",
	"caminar": "walk",
	"saltar": "salto",
	"caer": "caer",
	"dash": "dash",
	"ataque1": "ataque1",
	"ataque2": "ataque2",
	"ataque3": "ataque3",
	"ataque4": "ataque4",
	"especial2": "especial2",
	"especialdoble": "especialdoble",
	"muerte": "muerte"
}

# Constantes para colisiones
const COLISIONES_ATAQUES = ["doble2", "doble_1", "doble", "especial_1", "especial", "4_1", "4", "2y3", "1"]

# Señales
signal vida_cambiada(vida_actual: float, vida_maxima: float)
signal personaje_muerto()
signal daño_recibido(cantidad_daño: float)
signal inmunidad_activada(tipo_ataque: TipoAtaque)
signal inmunidad_desactivada()
signal escena_reseteada(puntos_restaurados: int)

# FUNCIÓN _ready CORREGIDA
func _ready():
	add_to_group("player")
	
	# Verificar si venimos de una muerte (estado inicial incorrecto)
	if vida_actual <= 0:
		print("Detectado: Posible reinicio después de muerte")
		muerte_procesada = false  # Reset flag
	
	# Inicializar con HealthManager ANTES que otros sistemas
	_inicializar_con_health_manager()
	
	# Verificar que la vida esté en un estado válido
	_verificar_y_corregir_vida()
	
	_inicializar_sistemas()
	_conectar_señales_area_ataques()
	_configurar_sonidos()
	_conectar_señales_peligro()
	_inicializar_sistema_reset()
	
	# Guardar estado inicial después de que todo esté inicializado
	await _guardar_estado_inicial_escena()
	
	# Conexión con PointSystem
	_ready_point_system_connection()
	
	# Verificación post-escena (después de un delay)
	call_deferred("_verificar_estado_post_escena")
	
	# Debug inicial
	print("=== JUGADOR INICIALIZADO ===")
	print("Vida inicial: ", vida_actual, "/", vida_maxima)
	print("Estado: ", estado_actual)
	print("============================")

# FUNCIÓN _inicializar_con_health_manager CORREGIDA
func _inicializar_con_health_manager():
	"""Inicializa el jugador con el sistema de vida persistente"""
	if has_node("/root/HealthManager"):
		var health_manager = get_node("/root/HealthManager")
		
		# Verificar si el HealthManager tiene vida válida
		var vida_health_manager = 0.0
		if health_manager.has_method("obtener_vida_actual"):
			vida_health_manager = health_manager.obtener_vida_actual()
		
		# Si es un reinicio después de muerte, usar vida completa
		if vida_health_manager <= 0 or muerte_procesada:
			print("Reiniciando vida después de muerte o vida inválida")
			vida_actual = vida_maxima
			
			if health_manager.has_method("establecer_vida_maxima"):
				health_manager.establecer_vida_maxima(vida_maxima)
			if health_manager.has_method("restaurar_vida_completa"):
				health_manager.restaurar_vida_completa()
			elif health_manager.has_method("establecer_vida"):
				health_manager.establecer_vida(vida_maxima)
		else:
			# Si HealthManager tiene vida válida, usarla
			vida_actual = vida_health_manager
			if health_manager.has_method("obtener_vida_maxima"):
				vida_maxima = health_manager.obtener_vida_maxima()
		
		print("Jugador inicializado con HealthManager")
		print("Vida establecida: ", vida_actual, "/", vida_maxima)
	else:
		print("HealthManager no encontrado - usando vida por defecto")
		vida_actual = vida_maxima

# NUEVA FUNCIÓN: Verificar y corregir vida
func _verificar_y_corregir_vida():
	"""Verifica que la vida esté en un estado válido"""
	if vida_actual <= 0 and estado_actual == EstadoPlayer.NORMAL:
		print("CORRIGIENDO: Vida actual era 0 pero el jugador está normal")
		
		if has_node("/root/HealthManager"):
			var health_manager = get_node("/root/HealthManager")
			if health_manager.has_method("obtener_vida_actual") and health_manager.obtener_vida_actual() > 0:
				vida_actual = health_manager.obtener_vida_actual()
				print("Vida corregida desde HealthManager: ", vida_actual)
			else:
				vida_actual = vida_maxima
				if health_manager.has_method("restaurar_vida_completa"):
					health_manager.restaurar_vida_completa()
				print("Vida restaurada completamente: ", vida_actual)
		else:
			vida_actual = vida_maxima
			print("Vida restaurada a máximo: ", vida_actual)
		
		vida_cambiada.emit(vida_actual, vida_maxima)

# FUNCIÓN _guardar_estado_inicial_escena CORREGIDA
func _guardar_estado_inicial_escena():
	"""Guarda los puntos Y VIDA iniciales al entrar en la escena"""
	await get_tree().process_frame
	await get_tree().process_frame  # Esperar dos frames para asegurar inicialización
	
	var puntos_actuales = _obtener_puntos_actuales()
	
	# Solo actualizar si es la primera vez o si los puntos actuales son menores
	if puntos_iniciales_escena == 0 or puntos_actuales < puntos_iniciales_escena:
		puntos_iniciales_escena = puntos_actuales
		print("Puntos iniciales de escena guardados: ", puntos_iniciales_escena)
	
	# Guardar vida inicial de la escena
	if vida_inicial_escena == 0.0:
		vida_inicial_escena = vida_actual
		print("Vida inicial de escena guardada: ", vida_inicial_escena, "/", vida_maxima)
		
		# Guardar también en HealthManager si está disponible
		if has_node("/root/HealthManager"):
			var health_manager = get_node("/root/HealthManager")
			if health_manager.has_method("guardar_checkpoint_inicial"):
				health_manager.guardar_checkpoint_inicial()
			elif health_manager.has_method("guardar_checkpoint"):
				health_manager.guardar_checkpoint()
			print("Checkpoint inicial guardado en HealthManager")

# FUNCIÓN _inicializar_sistemas CORREGIDA
func _inicializar_sistemas():
	# IMPORTANTE: NO resetear vida_actual aquí ya que se maneja en HealthManager
	# Asegurar que tenemos vida válida como fallback
	if vida_actual <= 0:
		vida_actual = vida_maxima
		print("ADVERTENCIA: Vida actual era 0, restaurada a máximo: ", vida_maxima)
	
	estado_actual = EstadoPlayer.NORMAL
	_configurar_ataques()
	_desactivar_todas_las_colisiones()
	vida_cambiada.emit(vida_actual, vida_maxima)

func _configurar_sonidos():
	var sonidos = {
		sonido_ataque1: volumen_ataques,
		sonido_ataque2y3: volumen_ataques,
		sonido_ataque4: volumen_ataques,
		sonido_especial2: volumen_ataques,
		sonido_especialdoble: volumen_ataques,
		sonido_hit: volumen_hit,
		sonido_muerte: volumen_muerte,
		sonido_dash: volumen_dash
	}
	
	for sonido in sonidos:
		if sonido:
			sonido.volume_db = sonidos[sonido]

func _conectar_señales_area_ataques():
	if area_ataques:
		if not area_ataques.body_entered.is_connected(_on_area_ataques_body_entered):
			area_ataques.body_entered.connect(_on_area_ataques_body_entered)
		if not area_ataques.area_entered.is_connected(_on_area_ataques_area_entered):
			area_ataques.area_entered.connect(_on_area_ataques_area_entered)

func _configurar_ataques():
	ataques_config = {
		TipoAtaque.ATAQUE1: {
			"animacion": ANIMACIONES.ataque1,
			"cooldown": cooldown_ataque1,
			"permite_movimiento": true,
			"daño": daño_ataque1,
			"tiene_inmunidad": false,
			"sonido": sonido_ataque1,
			"delay_sonido": delay_sonido_ataque1
		},
		TipoAtaque.ATAQUE2: {
			"animacion": ANIMACIONES.ataque2,
			"cooldown": cooldown_ataque2,
			"permite_movimiento": false,
			"daño": daño_ataque2,
			"tiene_inmunidad": false,
			"sonido": sonido_ataque2y3,
			"delay_sonido": delay_sonido_ataque2
		},
		TipoAtaque.ATAQUE3: {
			"animacion": ANIMACIONES.ataque3,
			"cooldown": cooldown_ataque3,
			"permite_movimiento": false,
			"daño": daño_ataque3,
			"tiene_inmunidad": false,
			"sonido": sonido_ataque2y3,
			"delay_sonido": delay_sonido_ataque3
		},
		TipoAtaque.ATAQUE4: {
			"animacion": ANIMACIONES.ataque4,
			"cooldown": cooldown_ataque4,
			"permite_movimiento": false,
			"daño": daño_ataque4,
			"tiene_inmunidad": true,
			"sonido": sonido_ataque4,
			"delay_sonido": delay_sonido_ataque4
		},
		TipoAtaque.ESPECIAL2: {
			"animacion": ANIMACIONES.especial2,
			"cooldown": cooldown_especial2,
			"permite_movimiento": false,
			"daño": daño_especial2,
			"tiene_inmunidad": false,
			"sonido": sonido_especial2,
			"delay_sonido": delay_sonido_especial2
		},
		TipoAtaque.ESPECIALDOBLE: {
			"animacion": ANIMACIONES.especialdoble,
			"cooldown": cooldown_especialdoble,
			"permite_movimiento": false,
			"daño": daño_especialdoble,
			"tiene_inmunidad": true,
			"sonido": sonido_especialdoble,
			"delay_sonido": delay_sonido_especialdoble
		}
	}
	
	for tipo in ataques_config:
		puede_atacar[tipo] = true
		cooldowns_ataques[tipo] = 0.0
		timers_sonidos[tipo] = 0.0
		sonidos_pendientes[tipo] = false

# FUNCIÓN _physics_process CORREGIDA con verificación de vida
func _physics_process(delta):
	if estado_actual == EstadoPlayer.MUERTO:
		return
	
	# Verificación de seguridad: si la vida es 0 pero no estamos muriendo
	if vida_actual <= 0 and estado_actual != EstadoPlayer.MURIENDO:
		print("DETECTADO: Vida 0 sin estar muriendo - iniciando muerte")
		_iniciar_muerte()
		return
	
	if estado_actual == EstadoPlayer.MURIENDO:
		_procesar_muerte(delta)
		return
	
	_actualizar_sistemas(delta)
	_procesar_movimiento(delta)
	move_and_slide()

func _actualizar_sistemas(delta):
	_actualizar_invulnerabilidad(delta)
	_actualizar_cooldowns(delta)
	_actualizar_delays_sonidos(delta)
	_detectar_doble_clic_cancelacion(delta)
	_verificar_fin_ataque()

func _actualizar_invulnerabilidad(delta):
	if not invulnerable:
		return
		
	tiempo_invulnerabilidad -= delta
	if tiempo_invulnerabilidad <= 0:
		invulnerable = false
		sprite.modulate.a = 1.0
	else:
		var parpadeo = sin(tiempo_invulnerabilidad * 20) * 0.5 + 0.5
		sprite.modulate.a = 0.3 + (parpadeo * 0.7)

func _actualizar_cooldowns(delta):
	if not puede_dash:
		tiempo_cooldown_dash -= delta
		if tiempo_cooldown_dash <= 0:
			puede_dash = true
	
	for tipo in cooldowns_ataques:
		if not puede_atacar[tipo]:
			cooldowns_ataques[tipo] -= delta
			if cooldowns_ataques[tipo] <= 0:
				puede_atacar[tipo] = true

func _actualizar_delays_sonidos(delta):
	for tipo in timers_sonidos:
		if sonidos_pendientes[tipo]:
			timers_sonidos[tipo] -= delta
			if timers_sonidos[tipo] <= 0:
				var config = ataques_config[tipo]
				if config.sonido and not config.sonido.playing:
					config.sonido.play()
				
				sonidos_pendientes[tipo] = false
				timers_sonidos[tipo] = 0.0

func _verificar_fin_ataque():
	if estado_actual != EstadoPlayer.ATACANDO:
		return
		
	if not animacion_player.is_playing():
		_finalizar_ataque()
		return
	
	var anim_actual = animacion_player.current_animation
	var es_ataque = anim_actual in [ANIMACIONES.ataque1, ANIMACIONES.ataque2, ANIMACIONES.ataque3, 
									ANIMACIONES.ataque4, ANIMACIONES.especial2, ANIMACIONES.especialdoble]
	
	if not es_ataque:
		_finalizar_ataque()

func _finalizar_ataque():
	atacando = false
	_cancelar_sonidos_pendientes()
	
	if inmune_por_ataque:
		inmune_por_ataque = false
		inmunidad_desactivada.emit()
	
	estado_actual = EstadoPlayer.NORMAL

func _cancelar_sonidos_pendientes():
	for tipo in sonidos_pendientes:
		if sonidos_pendientes[tipo]:
			sonidos_pendientes[tipo] = false
			timers_sonidos[tipo] = 0.0

func _procesar_movimiento(delta):
	match estado_actual:
		EstadoPlayer.DASH:
			_procesar_dash(delta)
		EstadoPlayer.ATACANDO:
			_procesar_ataque(delta)
		EstadoPlayer.NORMAL:
			_procesar_movimiento_normal(delta)

func _procesar_dash(delta):
	tiempo_dash -= delta
	
	velocity.x = velocidad_dash if mirando_derecha else -velocidad_dash
	velocity.y += gravedad * delta * 0.3
	
	if not animacion_player.current_animation == ANIMACIONES.dash:
		animacion_player.play(ANIMACIONES.dash)
	
	if tiempo_dash <= 0:
		estado_actual = EstadoPlayer.NORMAL

func _procesar_ataque(delta):
	var anim_actual = animacion_player.current_animation
	var permite_movimiento = false
	
	for tipo in ataques_config:
		if ataques_config[tipo].animacion == anim_actual:
			permite_movimiento = ataques_config[tipo].permite_movimiento
			break
	
	if permite_movimiento:
		_aplicar_movimiento_horizontal(delta)
	else:
		velocity.x = 0
		_procesar_volteo_durante_ataque()
	
	_aplicar_gravedad(delta)

func _procesar_movimiento_normal(delta):
	_aplicar_gravedad(delta)
	
	var direccion = Input.get_axis("izquierda", "derecha")
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = fuerza_salto
		_reproducir_animacion(ANIMACIONES.saltar)
	
	if Input.is_action_just_pressed("dash") and puede_dash:
		_iniciar_dash()
		return
	
	_aplicar_movimiento_horizontal(delta)
	_actualizar_animacion_movimiento(direccion)

func _aplicar_movimiento_horizontal(delta):
	var direccion = Input.get_axis("izquierda", "derecha")
	
	if direccion != 0:
		velocity.x = direccion * velocidad_caminar
		_procesar_volteo(direccion)
	else:
		velocity.x = move_toward(velocity.x, 0, velocidad_caminar * delta * 3)

func _aplicar_gravedad(delta):
	if not is_on_floor():
		velocity.y += gravedad * delta

func _procesar_volteo(direccion: float):
	if (direccion > 0 and not mirando_derecha) or (direccion < 0 and mirando_derecha):
		_voltear_sprite()

func _procesar_volteo_durante_ataque():
	var direccion = Input.get_axis("izquierda", "derecha")
	if direccion != 0:
		_procesar_volteo(direccion)

func _actualizar_animacion_movimiento(direccion: float):
	if not is_on_floor():
		return
	
	if abs(direccion) > 0:
		_reproducir_animacion(ANIMACIONES.caminar)
	elif abs(velocity.x) < 10:
		_reproducir_animacion(ANIMACIONES.idle)

# FUNCIÓN recibir_daño CORREGIDA con debug mejorado
func recibir_daño(cantidad: float):
	if estado_actual == EstadoPlayer.MUERTO or estado_actual == EstadoPlayer.MURIENDO:
		print("Daño ignorado - jugador ya está muerto/muriendo")
		return
	
	if invulnerable or inmune_por_ataque:
		print("Daño ignorado - jugador invulnerable o inmune")
		return
	
	print("=== RECIBIENDO DAÑO ===")
	print("Cantidad de daño: ", cantidad)
	print("Vida antes del daño: ", vida_actual, "/", vida_maxima)
	
	# Usar HealthManager si está disponible
	if has_node("/root/HealthManager"):
		var health_manager = get_node("/root/HealthManager")
		
		# Verificar vida antes del daño
		var vida_antes = health_manager.obtener_vida_actual() if health_manager.has_method("obtener_vida_actual") else vida_actual
		print("Vida en HealthManager antes: ", vida_antes)
		
		# Aplicar daño
		if health_manager.has_method("dañar_jugador"):
			health_manager.dañar_jugador(cantidad)
		
		# Sincronizar nuestra vida local
		vida_actual = health_manager.obtener_vida_actual() if health_manager.has_method("obtener_vida_actual") else max(vida_actual - cantidad, 0)
		var vida_despues = vida_actual
		
		print("Vida en HealthManager después: ", vida_despues)
		print("Daño real aplicado: ", vida_antes - vida_despues)
	else:
		# Fallback original
		vida_actual = max(vida_actual - cantidad, 0)
		print("HealthManager no disponible - usando sistema local")
	
	print("Vida después del daño: ", vida_actual, "/", vida_maxima)
	print("======================")
	
	_reproducir_sonido_hit()
	
	daño_recibido.emit(cantidad)
	vida_cambiada.emit(vida_actual, vida_maxima)
	
	if vida_actual <= 0:
		print("Vida llegó a 0 - iniciando muerte")
		_iniciar_muerte()
	else:
		print("Jugador sobrevive - activando invulnerabilidad")
		_activar_invulnerabilidad()

func _reproducir_sonido_hit():
	if sonido_hit and not sonido_hit.playing:
		sonido_hit.play()

func _activar_invulnerabilidad():
	invulnerable = true
	tiempo_invulnerabilidad = invulnerabilidad_duracion

func _activar_inmunidad_ataque(tipo_ataque: TipoAtaque):
	inmune_por_ataque = true
	inmunidad_activada.emit(tipo_ataque)

# FUNCIÓN _iniciar_muerte CORREGIDA
func _iniciar_muerte():
	if estado_actual == EstadoPlayer.MURIENDO or estado_actual == EstadoPlayer.MUERTO:
		return
	
	if muerte_procesada:
		return
	
	muerte_procesada = true
	print("=== MUERTE INICIADA ===")
	print("Vida antes de morir: ", vida_actual, "/", vida_maxima)
	print("Puntos antes de morir: ", _obtener_puntos_actuales())
	print("Puntos iniciales a restaurar: ", puntos_iniciales_escena)
	print("Vida inicial a restaurar: ", vida_inicial_escena)
	
	estado_actual = EstadoPlayer.MURIENDO
	atacando = false
	
	# Notificar al sistema de puntos que el jugador tomó daño
	if has_node("/root/PointSystem"):
		var ps = get_node("/root/PointSystem")
		if ps.has_method("player_took_damage"):
			ps.player_took_damage()
	
	_reproducir_sonido_muerte()
	
	if inmune_por_ataque:
		inmune_por_ataque = false
		inmunidad_desactivada.emit()
	
	velocity.x = 0
	_desactivar_todas_las_colisiones()
	
	if animacion_player.has_animation(ANIMACIONES.muerte):
		animacion_player.play(ANIMACIONES.muerte)
		timer_reset.start()
	else:
		_resetear_escena_con_delay()
	
	print("======================")

# FUNCIÓN _resetear_escena CORREGIDA con restauración de vida
func _resetear_escena():
	"""Resetea la escena actual, restaura puntos Y VIDA iniciales"""
	if escena_actual.is_empty():
		escena_actual = get_tree().current_scene.scene_file_path
		if escena_actual.is_empty():
			print("ERROR: No se pudo determinar la escena actual")
			return
	
	print("=== RESETEANDO ESCENA ===")
	print("Escena: ", escena_actual)
	print("Puntos antes del reset: ", _obtener_puntos_actuales())
	print("Puntos iniciales a restaurar: ", puntos_iniciales_escena)
	print("Vida antes del reset: ", vida_actual, "/", vida_maxima)
	print("Vida inicial a restaurar: ", vida_inicial_escena, "/", vida_maxima)
	
	# 1. RESTAURAR VIDA PRIMERO
	_restaurar_vida_inicial()
	
	# 2. RESTAURAR PUNTOS
	var restauracion_exitosa = _restaurar_puntos_iniciales()
	
	# Esperar un frame para asegurar que las restauraciones se procesaron
	await get_tree().process_frame
	
	# Verificar restauraciones
	var puntos_despues = _obtener_puntos_actuales()
	print("Puntos después de restauración: ", puntos_despues)
	print("Vida después de restauración: ", vida_actual, "/", vida_maxima)
	
	if puntos_despues != puntos_iniciales_escena and restauracion_exitosa:
		print("ADVERTENCIA: Los puntos no coinciden después de la restauración")
		_restaurar_puntos_iniciales()
		await get_tree().process_frame
	
	# Emitir señales de reset
	escena_reseteada.emit(puntos_iniciales_escena)
	
	print("========================")
	
	# Cambiar la escena
	if ResourceLoader.exists(escena_actual):
		print("Cambiando a escena: ", escena_actual)
		var result = get_tree().change_scene_to_file(escena_actual)
		if result != OK:
			print("Error al cambiar escena: ", result)
			_resetear_escena_alternativo()
	else:
		print("Escena no encontrada: ", escena_actual)
		_resetear_escena_alternativo()

# NUEVA FUNCIÓN: Restaurar vida inicial
func _restaurar_vida_inicial():
	"""Restaura la vida a su valor inicial de la escena"""
	print("Restaurando vida inicial...")
	
	# Usar vida inicial si está guardada, sino usar vida máxima
	var vida_a_restaurar = vida_inicial_escena if vida_inicial_escena > 0.0 else vida_maxima
	
	# Restaurar en HealthManager si está disponible
	if has_node("/root/HealthManager"):
		var health_manager = get_node("/root/HealthManager")
		
		# Método 1: Restaurar desde checkpoint
		if health_manager.has_method("restaurar_desde_checkpoint"):
			health_manager.restaurar_desde_checkpoint()
			print("Vida restaurada desde checkpoint en HealthManager")
		# Método 2: Restaurar vida completa
		elif health_manager.has_method("restaurar_vida_completa"):
			health_manager.restaurar_vida_completa()
			print("Vida restaurada completamente en HealthManager")
		# Método 3: Establecer vida específica
		elif health_manager.has_method("establecer_vida"):
			health_manager.establecer_vida(vida_a_restaurar)
			print("Vida establecida en HealthManager: ", vida_a_restaurar)
		
		# Sincronizar nuestra vida local
		if health_manager.has_method("obtener_vida_actual"):
			vida_actual = health_manager.obtener_vida_actual()
		else:
			vida_actual = vida_a_restaurar
	else:
		# Fallback si no hay HealthManager
		vida_actual = vida_a_restaurar
		print("HealthManager no disponible - restaurando vida local a: ", vida_actual)
	
	# Resetear estado del jugador
	estado_actual = EstadoPlayer.NORMAL
	invulnerable = false
	inmune_por_ataque = false
	muerte_procesada = false
	
	# Emitir señal de cambio de vida
	vida_cambiada.emit(vida_actual, vida_maxima)
	
	print("Vida restaurada a: ", vida_actual, "/", vida_maxima)

func _resetear_escena_con_delay():
	await get_tree().create_timer(1.0).timeout
	_resetear_escena()

func _resetear_escena_alternativo():
	var escena_actual_nodo = get_tree().current_scene
	if escena_actual_nodo:
		get_tree().reload_current_scene()
		return
	
	var nombre_escena = "res://" + get_tree().current_scene.name.to_lower() + ".tscn"
	if ResourceLoader.exists(nombre_escena):
		get_tree().change_scene_to_file(nombre_escena)

func _reproducir_sonido_muerte():
	if sonido_muerte:
		sonido_muerte.play()

func _procesar_muerte(delta):
	_aplicar_gravedad(delta)

func _on_animacion_muerte_terminada():
	if animacion_player.current_animation == ANIMACIONES.muerte:
		estado_actual = EstadoPlayer.MUERTO
		personaje_muerto.emit()

# NUEVA FUNCIÓN: Verificar estado después de cambio de escena
func _verificar_estado_post_escena():
	"""Se llama después de cambiar de escena para verificar el estado"""
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("=== VERIFICACIÓN POST-ESCENA ===")
	print("Vida actual: ", vida_actual, "/", vida_maxima)
	print("Estado: ", estado_actual)
	
	# Si la vida está en 0 después del cambio de escena, corregirla
	if vida_actual <= 0:
		print("CORRIGIENDO: Vida 0 después de cambio de escena")
		_restaurar_vida_inicial()
	
	print("================================")

# FUNCIÓN MEJORADA PARA OBTENER PUNTOS ACTUALES
func _obtener_puntos_actuales() -> int:
	"""Obtiene los puntos actuales del sistema de puntos - PRIORIZA POINTSYSTEM"""
	
	# MÉTODO 1: PointSystem (Singleton)
	if has_node("/root/PointSystem"):
		var point_system = get_node("/root/PointSystem")
		if point_system.has_method("get_current_points"):
			return point_system.get_current_points()
	
	# MÉTODO 2: Buscar PointSystem en AutoLoad
	var autoload_names = ["PointSystem", "Points", "Puntos"]
	for name in autoload_names:
		var node = get_node_or_null("/root/" + name)
		if node and node.has_method("get_current_points"):
			return node.get_current_points()
	
	# MÉTODO 3: GameManager (como fallback)
	var posibles_game_managers = [
		"/root/GameManager",
		"/root/Game_Manager", 
		"/root/gamemanager",
		"/root/game_manager",
		"/root/GM"
	]
	
	for ruta in posibles_game_managers:
		var game_manager = get_node_or_null(ruta)
		if game_manager:
			var puntos = _extraer_puntos_de_nodo(game_manager)
			if puntos >= 0:
				return puntos
	
	# MÉTODO 4: Otros sistemas
	var rutas_alternativas = [
		"/root/PuntosManager",
		"/root/ScoreManager"
	]
	
	for ruta in rutas_alternativas:
		var nodo = get_node_or_null(ruta)
		if nodo:
			var puntos = _extraer_puntos_de_nodo(nodo)
			if puntos >= 0:
				return puntos
	
	return 0

func _extraer_puntos_de_nodo(nodo: Node) -> int:
	"""Extrae puntos de un nodo usando diferentes métodos"""
	if not nodo:
		return -1
	
	# Métodos de obtención
	var metodos_obtener = ["obtener_puntos", "get_puntos", "getPuntos", "get_points", "get_score", "get_current_points"]
	for metodo in metodos_obtener:
		if nodo.has_method(metodo):
			return nodo.call(metodo)
	
	# Propiedades directas
	var propiedades_puntos = ["puntos", "points", "score", "current_points"]
	for prop in propiedades_puntos:
		if prop in nodo:
			return nodo.get(prop)
	
	return -1

# FUNCIÓN MEJORADA PARA RESTAURAR PUNTOS
func _restaurar_puntos_iniciales():
	"""Restaura los puntos a su valor inicial de la escena - PRIORIZA POINTSYSTEM"""
	var restauracion_exitosa = false
	
	print("Restaurando puntos iniciales a: ", puntos_iniciales_escena)
	
	# MÉTODO 1: PointSystem (Singleton) - PRIORITARIO
	if has_node("/root/PointSystem"):
		var point_system = get_node("/root/PointSystem")
		if point_system.has_method("reset_current_points"):
			# Primero resetear a 0
			point_system.reset_current_points()
			# Luego agregar los puntos iniciales
			if puntos_iniciales_escena > 0:
				point_system.add_points(puntos_iniciales_escena, "Restauración inicial")
			restauracion_exitosa = true
			print("Puntos restaurados usando PointSystem: ", puntos_iniciales_escena)
		elif _intentar_restaurar_en_nodo(point_system, "PointSystem"):
			restauracion_exitosa = true
	
	# MÉTODO 2: Buscar en AutoLoad si no funcionó el anterior
	if not restauracion_exitosa:
		var autoload_names = ["PointSystem", "Points", "Puntos"]
		for name in autoload_names:
			var node = get_node_or_null("/root/" + name)
			if node:
				if node.has_method("reset_current_points"):
					node.reset_current_points()
					if puntos_iniciales_escena > 0:
						if node.has_method("add_points"):
							node.add_points(puntos_iniciales_escena, "Restauración inicial")
						else:
							_intentar_restaurar_en_nodo(node, "AutoLoad " + name)
					restauracion_exitosa = true
					print("Puntos restaurados usando AutoLoad ", name, ": ", puntos_iniciales_escena)
					break
				elif _intentar_restaurar_en_nodo(node, "AutoLoad " + name):
					restauracion_exitosa = true
					break
	
	# MÉTODO 3: GameManager como fallback
	if not restauracion_exitosa:
		var posibles_game_managers = [
			"/root/GameManager",
			"/root/Game_Manager", 
			"/root/gamemanager",
			"/root/game_manager",
			"/root/GM"
		]
		
		for ruta in posibles_game_managers:
			var game_manager = get_node_or_null(ruta)
			if game_manager:
				restauracion_exitosa = _intentar_restaurar_en_nodo(game_manager, "GameManager")
				if restauracion_exitosa:
					break
	
	if not restauracion_exitosa:
		print("ADVERTENCIA: No se pudo restaurar los puntos iniciales")
	
	return restauracion_exitosa

func _intentar_restaurar_en_nodo(nodo: Node, tipo_sistema: String) -> bool:
	"""Intenta restaurar puntos en un nodo específico"""
	if not nodo:
		return false
	
	print("Intentando restaurar puntos en: ", tipo_sistema)
	
	# MÉTODO A: establecer_puntos()
	if nodo.has_method("establecer_puntos"):
		nodo.establecer_puntos(puntos_iniciales_escena)
		return true
	
	# MÉTODO B: set_puntos()
	if nodo.has_method("set_puntos"):
		nodo.set_puntos(puntos_iniciales_escena)
		return true
	
	# MÉTODO C: setPuntos() (camelCase)
	if nodo.has_method("setPuntos"):
		nodo.setPuntos(puntos_iniciales_escena)
		return true
	
	# MÉTODO D: update_points()
	if nodo.has_method("update_points"):
		nodo.update_points(puntos_iniciales_escena)
		return true
	
	# MÉTODO E: set_score()
	if nodo.has_method("set_score"):
		nodo.set_score(puntos_iniciales_escena)
		return true
	
	# MÉTODO F: set_current_points()
	if nodo.has_method("set_current_points"):
		nodo.set_current_points(puntos_iniciales_escena)
		return true
	
	# MÉTODO G: restore_points_to()
	if nodo.has_method("restore_points_to"):
		nodo.restore_points_to(puntos_iniciales_escena)
		return true
	
	# MÉTODO H: Propiedad directa 'puntos'
	if "puntos" in nodo:
		nodo.puntos = puntos_iniciales_escena
		return true
	
	# MÉTODO I: Propiedad 'points'
	if "points" in nodo:
		nodo.points = puntos_iniciales_escena
		return true
	
	# MÉTODO J: Propiedad 'score'
	if "score" in nodo:
		nodo.score = puntos_iniciales_escena
		return true
	
	return false

func _inicializar_sistema_reset():
	timer_reset = Timer.new()
	timer_reset.wait_time = tiempo_delay_reset
	timer_reset.one_shot = true
	timer_reset.timeout.connect(_resetear_escena)
	add_child(timer_reset)
	
	# Obtener la escena actual con múltiples métodos
	escena_actual = get_tree().current_scene.scene_file_path
	
	if escena_actual.is_empty():
		var nombre_nodo = get_tree().current_scene.name
		escena_actual = "res://" + nombre_nodo.to_lower() + ".tscn"
		
		if not ResourceLoader.exists(escena_actual):
			var nombres_posibles = [
				"res://" + nombre_nodo + ".tscn",
				"res://scenes/" + nombre_nodo.to_lower() + ".tscn",
				"res://levels/" + nombre_nodo.to_lower() + ".tscn"
			]
			
			for nombre in nombres_posibles:
				if ResourceLoader.exists(nombre):
					escena_actual = nombre
					break

func _conectar_señales_peligro():
	var next_area = get_node_or_null("/root/Node2D/Next")
	var reset_area = get_node_or_null("/root/Node2D/Reset")
	
	if next_area and next_area is Area2D and not next_area.body_entered.is_connected(_on_next_body_entered):
		next_area.body_entered.connect(_on_next_body_entered)
	if reset_area and reset_area is Area2D and not reset_area.body_entered.is_connected(_on_reset_body_entered):
		reset_area.body_entered.connect(_on_reset_body_entered)

# SISTEMA DE DASH
func _iniciar_dash():
	if estado_actual == EstadoPlayer.MURIENDO or estado_actual == EstadoPlayer.MUERTO:
		return
		
	estado_actual = EstadoPlayer.DASH
	tiempo_dash = duracion_dash
	puede_dash = false
	tiempo_cooldown_dash = cooldown_dash
	
	_reproducir_sonido_dash()

func _reproducir_sonido_dash():
	if sonido_dash and not sonido_dash.playing:
		sonido_dash.play()

# SISTEMA DE ATAQUES CON INMUNIDAD Y SONIDOS
func _iniciar_ataque(tipo_ataque: TipoAtaque):
	if estado_actual == EstadoPlayer.MURIENDO or estado_actual == EstadoPlayer.MUERTO:
		return
	
	if estado_actual == EstadoPlayer.ATACANDO:
		return
	
	if not puede_atacar[tipo_ataque]:
		return
	
	var config = ataques_config[tipo_ataque]
	if not animacion_player.has_animation(config.animacion):
		return
	
	if estado_actual == EstadoPlayer.DASH:
		estado_actual = EstadoPlayer.NORMAL
	
	estado_actual = EstadoPlayer.ATACANDO
	atacando = true
	tipo_ataque_actual = tipo_ataque
	puede_atacar[tipo_ataque] = false
	cooldowns_ataques[tipo_ataque] = config.cooldown
	
	if config.tiene_inmunidad:
		_activar_inmunidad_ataque(tipo_ataque)
	
	_programar_sonido_ataque(tipo_ataque, config)
	
	velocity.x = 0
	animacion_player.play(config.animacion)
	
	# Conectar la señal solo si no está ya conectada
	if not animacion_player.animation_finished.is_connected(_on_ataque_terminado):
		animacion_player.animation_finished.connect(_on_ataque_terminado)

func _programar_sonido_ataque(tipo_ataque: TipoAtaque, config: Dictionary):
	var delay = config.delay_sonido
	
	if delay <= 0:
		if config.sonido and not config.sonido.playing:
			config.sonido.play()
	else:
		timers_sonidos[tipo_ataque] = delay
		sonidos_pendientes[tipo_ataque] = true

func _on_ataque_terminado():
	if estado_actual == EstadoPlayer.ATACANDO:
		_finalizar_ataque()

func _voltear_sprite():
	mirando_derecha = !mirando_derecha
	sprite.scale.x = -sprite.scale.x
	area_ataques.scale.x = -area_ataques.scale.x

func _reproducir_animacion(nombre_animacion: String):
	if estado_actual == EstadoPlayer.MURIENDO or estado_actual == EstadoPlayer.MUERTO:
		if nombre_animacion != ANIMACIONES.muerte:
			return
	
	var es_ataque = nombre_animacion in [ANIMACIONES.ataque1, ANIMACIONES.ataque2, ANIMACIONES.ataque3, 
										ANIMACIONES.ataque4, ANIMACIONES.especial2, ANIMACIONES.especialdoble]
	
	if animacion_player.has_animation(nombre_animacion):
		if es_ataque or nombre_animacion == ANIMACIONES.dash or nombre_animacion == ANIMACIONES.muerte:
			animacion_player.play(nombre_animacion)
		else:
			if estado_actual == EstadoPlayer.NORMAL and animacion_player.current_animation != nombre_animacion:
				animacion_player.play(nombre_animacion)

func _input(event):
	if estado_actual == EstadoPlayer.MURIENDO or estado_actual == EstadoPlayer.MUERTO:
		return
	
	if estado_actual == EstadoPlayer.ATACANDO:
		return
	
	# Teclas de debug
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_P:
				debug_sistema_vida()
				return
			KEY_O:
				debug_sistema_puntos()
				return
			KEY_I:
				restaurar_vida_completa()
				return
			KEY_M:
				debug_muerte_y_renacimiento()
				return
			KEY_N:
				test_muerte_y_reset()
				return
			KEY_B:
				test_restaurar_vida()
				return
	
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_iniciar_ataque(TipoAtaque.ATAQUE1)
			MOUSE_BUTTON_RIGHT:
				_iniciar_ataque(TipoAtaque.ATAQUE2)
	
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_E:
				_iniciar_ataque(TipoAtaque.ATAQUE3)
			KEY_F:
				_iniciar_ataque(TipoAtaque.ATAQUE4)
			KEY_Q:
				_iniciar_ataque(TipoAtaque.ESPECIAL2)
			KEY_R:
				_iniciar_ataque(TipoAtaque.ESPECIALDOBLE)
			KEY_SPACE:
				if is_on_floor() and estado_actual == EstadoPlayer.NORMAL:
					velocity.y = fuerza_salto
					_reproducir_animacion(ANIMACIONES.saltar)

# SISTEMA DE COLISIONES OPTIMIZADO
func _desactivar_todas_las_colisiones():
	if not area_ataques:
		return
	
	for nombre in COLISIONES_ATAQUES:
		var colision = area_ataques.get_node_or_null(nombre)
		if colision and colision is CollisionShape2D:
			colision.disabled = true

func activar_colision_especifica(nombre_colision: String):
	if not area_ataques:
		return
	
	var colision = area_ataques.get_node_or_null(nombre_colision)
	if colision and colision is CollisionShape2D:
		colision.disabled = false

func desactivar_colision_especifica(nombre_colision: String):
	if not area_ataques:
		return
	
	var colision = area_ataques.get_node_or_null(nombre_colision)
	if colision and colision is CollisionShape2D:
		colision.disabled = true

# SISTEMA DE CANCELACIÓN POR DOBLE CLIC
func _detectar_doble_clic_cancelacion(delta: float):
	ultimo_input_direccion.tiempo_derecha += delta
	ultimo_input_direccion.tiempo_izquierda += delta
	
	if estado_actual != EstadoPlayer.ATACANDO:
		return
	
	if Input.is_action_just_pressed("derecha"):
		if ultimo_input_direccion.tiempo_derecha <= tiempo_maximo_doble_clic and ultimo_input_direccion.ultima_direccion == 1:
			_cancelar_ataque("doble clic derecha")
		else:
			ultimo_input_direccion.tiempo_derecha = 0.0
			ultimo_input_direccion.ultima_direccion = 1
	
	elif Input.is_action_just_pressed("izquierda"):
		if ultimo_input_direccion.tiempo_izquierda <= tiempo_maximo_doble_clic and ultimo_input_direccion.ultima_direccion == -1:
			_cancelar_ataque("doble clic izquierda")
		else:
			ultimo_input_direccion.tiempo_izquierda = 0.0
			ultimo_input_direccion.ultima_direccion = -1
	
	if ultimo_input_direccion.tiempo_derecha > tiempo_maximo_doble_clic and ultimo_input_direccion.ultima_direccion == 1:
		ultimo_input_direccion.ultima_direccion = 0
	
	if ultimo_input_direccion.tiempo_izquierda > tiempo_maximo_doble_clic and ultimo_input_direccion.ultima_direccion == -1:
		ultimo_input_direccion.ultima_direccion = 0

func _cancelar_ataque(razon: String = "manual"):
	if estado_actual == EstadoPlayer.ATACANDO:
		print("Cancelando ataque por: ", razon)
		_finalizar_ataque()
		
		if animacion_player.is_playing():
			var anim_actual = animacion_player.current_animation
			var es_ataque = anim_actual in [ANIMACIONES.ataque1, ANIMACIONES.ataque2, ANIMACIONES.ataque3, 
											ANIMACIONES.ataque4, ANIMACIONES.especial2, ANIMACIONES.especialdoble]
			if es_ataque:
				animacion_player.stop()
		
		_desactivar_todas_las_colisiones()
		return true
	return false

# FUNCIONES DE UTILIDAD PÚBLICAS
func obtener_vida_actual() -> float:
	return vida_actual

func obtener_vida_maxima() -> float:
	return vida_maxima

func obtener_porcentaje_vida() -> float:
	return (vida_actual / vida_maxima) * 100.0

func esta_vivo() -> bool:
	return estado_actual != EstadoPlayer.MUERTO and estado_actual != EstadoPlayer.MURIENDO

func esta_invulnerable() -> bool:
	return invulnerable

func esta_inmune_por_ataque() -> bool:
	return inmune_por_ataque

func esta_completamente_inmune() -> bool:
	return invulnerable or inmune_por_ataque

func obtener_tiempo_cooldown(tipo_ataque: TipoAtaque) -> float:
	return cooldowns_ataques[tipo_ataque] if not puede_atacar[tipo_ataque] else 0.0

func esta_atacando() -> bool:
	return atacando

func obtener_daño_ataque_actual() -> float:
	if not atacando:
		return 0.0
	
	var anim_actual = animacion_player.current_animation
	for tipo in ataques_config:
		if ataques_config[tipo].animacion == anim_actual:
			return ataques_config[tipo].daño
	
	return 0.0

func obtener_daño_por_tipo_ataque(tipo_ataque: TipoAtaque) -> float:
	return ataques_config[tipo_ataque].daño

func _es_enemigo(objetivo) -> bool:
	if not objetivo:
		return false
	
	if objetivo == self or objetivo.is_in_group("player"):
		return false
	
	if objetivo.is_in_group("enemy") or objetivo.is_in_group("enemies"):
		return true
	
	if objetivo.has_method("recibir_daño") and not objetivo.is_in_group("player"):
		var nombre_nodo = objetivo.name.to_lower()
		if "enemy" in nombre_nodo or "enemigo" in nombre_nodo:
			return true
		
		if not "player" in nombre_nodo and not "jugador" in nombre_nodo:
			return true
	
	return false

func _on_area_ataques_body_entered(body):
	if not atacando:
		return
	
	if not _es_enemigo(body):
		return
	
	if body.has_method("recibir_daño"):
		var daño = obtener_daño_ataque_actual()
		if daño > 0:
			body.recibir_daño(daño)

func _on_area_ataques_area_entered(area):
	if not atacando:
		return
	
	var objetivo = area.get_parent()
	
	if not _es_enemigo(objetivo):
		return
	
	if objetivo and objetivo.has_method("recibir_daño"):
		var daño = obtener_daño_ataque_actual()
		if daño > 0:
			objetivo.recibir_daño(daño)

# FUNCIONES PARA CURACIÓN Y GESTIÓN DE VIDA
func curar_vida(cantidad: float) -> float:
	"""Cura al jugador usando el HealthManager"""
	if has_node("/root/HealthManager"):
		var health_manager = get_node("/root/HealthManager")
		var cantidad_curada = 0.0
		
		if health_manager.has_method("curar_jugador"):
			cantidad_curada = health_manager.curar_jugador(cantidad)
		
		# Actualizar nuestra vida local
		if health_manager.has_method("obtener_vida_actual"):
			vida_actual = health_manager.obtener_vida_actual()
		if health_manager.has_method("obtener_vida_maxima"):
			vida_maxima = health_manager.obtener_vida_maxima()
		
		# Emitir señal de cambio
		vida_cambiada.emit(vida_actual, vida_maxima)
		
		print("Jugador curado: ", cantidad_curada, " puntos")
		return cantidad_curada
	else:
		# Fallback si no hay HealthManager
		var vida_anterior = vida_actual
		vida_actual = min(vida_actual + cantidad, vida_maxima)
		var cantidad_curada = vida_actual - vida_anterior
		
		vida_cambiada.emit(vida_actual, vida_maxima)
		return cantidad_curada

func guardar_checkpoint_vida():
	"""Guarda un checkpoint de la vida actual"""
	if has_node("/root/HealthManager"):
		var health_manager = get_node("/root/HealthManager")
		if health_manager.has_method("guardar_checkpoint"):
			health_manager.guardar_checkpoint()
		print("Checkpoint de vida guardado")

func restaurar_vida_completa():
	"""Restaura la vida completa del jugador"""
	if has_node("/root/HealthManager"):
		var health_manager = get_node("/root/HealthManager")
		if health_manager.has_method("restaurar_vida_completa"):
			health_manager.restaurar_vida_completa()
		if health_manager.has_method("obtener_vida_actual"):
			vida_actual = health_manager.obtener_vida_actual()
	else:
		vida_actual = vida_maxima
	
	vida_cambiada.emit(vida_actual, vida_maxima)
	print("Vida restaurada completamente: ", vida_actual, "/", vida_maxima)

func sincronizar_vida_con_health_manager():
	"""Sincroniza la vida local con el HealthManager"""
	if has_node("/root/HealthManager"):
		var health_manager = get_node("/root/HealthManager")
		if health_manager.has_method("obtener_vida_actual"):
			vida_actual = health_manager.obtener_vida_actual()
		if health_manager.has_method("obtener_vida_maxima"):
			vida_maxima = health_manager.obtener_vida_maxima()
		
		vida_cambiada.emit(vida_actual, vida_maxima)
		print("Vida sincronizada: ", vida_actual, "/", vida_maxima)
		return true
	return false

func interactuar_curacion(cantidad: float):
	"""Función pública para que objetos externos curen al jugador"""
	return curar_vida(cantidad)

func obtener_info_health_manager() -> Dictionary:
	"""Obtiene información del HealthManager para debug"""
	if has_node("/root/HealthManager"):
		var health_manager = get_node("/root/HealthManager")
		var info = {}
		
		if health_manager.has_method("obtener_vida_actual"):
			info["vida_actual"] = health_manager.obtener_vida_actual()
		if health_manager.has_method("obtener_vida_maxima"):
			info["vida_maxima"] = health_manager.obtener_vida_maxima()
		if health_manager.has_method("obtener_porcentaje_vida"):
			info["porcentaje"] = health_manager.obtener_porcentaje_vida()
		if health_manager.has_method("obtener_checkpoint_info"):
			info["checkpoint"] = health_manager.obtener_checkpoint_info()
		if health_manager.has_method("esta_vivo"):
			info["esta_vivo"] = health_manager.esta_vivo()
		
		return info
	return {}

# FUNCIONES DE DEBUG Y TESTING
func debug_muerte_y_renacimiento():
	"""Debug específico para problemas de muerte y renacimiento"""
	print("=== DEBUG MUERTE Y RENACIMIENTO ===")
	print("Estado actual: ", estado_actual)
	print("Muerte procesada: ", muerte_procesada)
	print("Vida actual: ", vida_actual, "/", vida_maxima)
	print("Vida inicial escena: ", vida_inicial_escena)
	print("Puntos iniciales escena: ", puntos_iniciales_escena)
	print("Es invulnerable: ", invulnerable)
	print("Es inmune por ataque: ", inmune_por_ataque)
	
	if has_node("/root/HealthManager"):
		var hm = get_node("/root/HealthManager")
		print("--- HealthManager ---")
		if hm.has_method("obtener_vida_actual"):
			print("Vida HealthManager: ", hm.obtener_vida_actual(), "/", hm.obtener_vida_maxima())
		if hm.has_method("esta_vivo"):
			print("Está vivo (HM): ", hm.esta_vivo())
	
	print("===================================")

func test_muerte_y_reset():
	"""Función para probar el sistema de muerte sin enemigos"""
	print("=== TEST MUERTE Y RESET ===")
	debug_muerte_y_renacimiento()
	print("Simulando muerte en 3 segundos...")
	await get_tree().create_timer(3.0).timeout
	recibir_daño(vida_actual + 10)  # Asegurar muerte

func test_restaurar_vida():
	"""Función para probar la restauración de vida"""
	print("Restaurando vida manualmente...")
	_restaurar_vida_inicial()
	debug_muerte_y_renacimiento()

func forzar_restauracion_completa():
	"""Fuerza una restauración completa del jugador"""
	print("=== RESTAURACIÓN FORZADA ===")
	
	# Restaurar vida
	_restaurar_vida_inicial()
	
	# Restaurar puntos
	_restaurar_puntos_iniciales()
	
	# Reset completo del estado
	estado_actual = EstadoPlayer.NORMAL
	muerte_procesada = false
	invulnerable = false
	inmune_por_ataque = false
	atacando = false
	
	# Reset visual
	sprite.modulate.a = 1.0
	
	print("Restauración completa finalizada")
	print("===============================")

func debug_sistema_vida():
	"""Debug específico del sistema de vida con más información"""
	print("=== DEBUG SISTEMA VIDA COMPLETO ===")
	print("Vida local jugador: ", vida_actual, "/", vida_maxima)
	print("Estado actual: ", estado_actual)
	print("Es invulnerable: ", esta_invulnerable())
	print("Es inmune por ataque: ", esta_inmune_por_ataque())
	
	if has_node("/root/HealthManager"):
		var hm = get_node("/root/HealthManager")
		print("--- HealthManager ---")
		if hm.has_method("obtener_vida_actual"):
			print("Vida HealthManager: ", hm.obtener_vida_actual(), "/", hm.obtener_vida_maxima())
		if hm.has_method("obtener_porcentaje_vida"):
			print("Porcentaje vida: ", hm.obtener_porcentaje_vida(), "%")
		if hm.has_method("esta_vivo"):
			print("Está vivo (HM): ", hm.esta_vivo())
		
		if hm.has_method("obtener_checkpoint_info"):
			var checkpoint = hm.obtener_checkpoint_info()
			print("Checkpoint: ", checkpoint.vida, " en ", checkpoint.escena)
	else:
		print("HealthManager: NO DISPONIBLE")
	
	# Verificar diferencias
	if has_node("/root/HealthManager"):
		var hm = get_node("/root/HealthManager")
		if hm.has_method("obtener_vida_actual"):
			var vida_hm = hm.obtener_vida_actual()
			if vida_actual != vida_hm:
				print("⚠️  ADVERTENCIA: Desincronización de vida!")
				print("   Vida local: ", vida_actual)
				print("   Vida HealthManager: ", vida_hm)
	
	print("===================================")

func debug_sistema_puntos():
	"""Función para debuggear el sistema de puntos"""
	print("=== DEBUG SISTEMA DE PUNTOS ===")
	print("Puntos iniciales escena: ", puntos_iniciales_escena)
	print("Puntos actuales: ", _obtener_puntos_actuales())
	print("Escena actual: ", escena_actual)
	
	# Verificar PointSystem
	if has_node("/root/PointSystem"):
		var ps = get_node("/root/PointSystem")
		print("PointSystem encontrado: SÍ")
		print("Puntos en PointSystem: ", ps.get_current_points() if ps.has_method("get_current_points") else "N/A")
		print("High Score: ", ps.get_high_score() if ps.has_method("get_high_score") else "N/A")
	else:
		print("PointSystem encontrado: NO")
	
	print("===============================")

func actualizar_puntos_iniciales_forzado():
	"""Fuerza la actualización de los puntos iniciales con los puntos actuales"""
	var puntos_actuales = _obtener_puntos_actuales()
	puntos_iniciales_escena = puntos_actuales
	print("Puntos iniciales actualizados forzadamente a: ", puntos_iniciales_escena)

func test_sistema_reset():
	"""Función para probar el sistema de reset sin morir"""
	print("=== TEST SISTEMA RESET ===")
	debug_sistema_puntos()
	print("Iniciando reset en 3 segundos...")
	await get_tree().create_timer(3.0).timeout
	_resetear_escena()

# CONEXIÓN CON POINTSYSTEM
func _conectar_con_point_system():
	"""Se conecta automáticamente con PointSystem cuando esté disponible"""
	if has_node("/root/PointSystem"):
		var ps = get_node("/root/PointSystem")
		print("PointSystem detectado y conectado")
		
		# Conectar señales si existen
		if has_signal("daño_recibido") and ps.has_method("player_took_damage"):
			if not daño_recibido.is_connected(ps.player_took_damage):
				daño_recibido.connect(ps.player_took_damage)
				print("Señal de daño conectada con PointSystem")
		
		return true
	return false

func _ready_point_system_connection():
	"""Añadir al final de _ready() para conectar con PointSystem"""
	# Intentar conectar inmediatamente
	if not _conectar_con_point_system():
		# Si no está disponible, intentar después
		await get_tree().process_frame
		await get_tree().process_frame
		_conectar_con_point_system()

# FUNCIONES PARA COLISIONES CON AREAS SIGUIENTES
func _on_next_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Intentando cambiar a lvl_3.tscn...")
		
		# Verificar si el archivo existe antes de cambiar
		var ruta_siguiente = "res://lvl_3.tscn"
		if ResourceLoader.exists(ruta_siguiente):
			var result = get_tree().change_scene_to_file(ruta_siguiente)
			if result != OK:
				print("Error al cambiar de escena: ", result)
		else:
			print("El archivo ", ruta_siguiente, " no existe")
			# Intentar rutas alternativas
			var rutas_alternativas = [
				"res://lvls/lvl_3.tscn"
			]
			
			for ruta in rutas_alternativas:
				if ResourceLoader.exists(ruta):
					print("Encontrado archivo alternativo: ", ruta)
					get_tree().change_scene_to_file(ruta)
					return
			
			print("No se encontró ningún archivo de nivel 3")

func _on_reset_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("recibir_daño"):
		body.recibir_daño(vida_maxima)

func _on_next_2_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Intentando cambiar a finalboss.tscn...")
		
		# Verificar si el archivo existe antes de cambiar
		var ruta_final = "res://lvls/finalboss.tscn"
		if ResourceLoader.exists(ruta_final):
			var result = get_tree().change_scene_to_file(ruta_final)
			if result != OK:
				print("Error al cambiar de escena: ", result)
		else:
			print("El archivo ", ruta_final, " no existe")
			# Intentar rutas alternativas
			var rutas_alternativas = [
				"res://finalboss.tscn"
			]
			
			for ruta in rutas_alternativas:
				if ResourceLoader.exists(ruta):
					print("Encontrado archivo alternativo: ", ruta)
					get_tree().change_scene_to_file(ruta)
					return
			
			print("No se encontró ningún archivo de boss final")

# FUNCIONES ADICIONALES PARA CONTROL DE SONIDOS
func ajustar_volumen_ataques(nuevo_volumen: float):
	volumen_ataques = nuevo_volumen
	var sonidos_ataques = [sonido_ataque1, sonido_ataque2y3, sonido_ataque4, sonido_especial2, sonido_especialdoble]
	
	for sonido in sonidos_ataques:
		if sonido:
			sonido.volume_db = nuevo_volumen

func ajustar_delay_sonido_ataque(tipo_ataque: TipoAtaque, nuevo_delay: float):
	if tipo_ataque in ataques_config:
		ataques_config[tipo_ataque].delay_sonido = nuevo_delay
		
		if sonidos_pendientes[tipo_ataque]:
			timers_sonidos[tipo_ataque] = nuevo_delay

func obtener_delay_sonido_ataque(tipo_ataque: TipoAtaque) -> float:
	if tipo_ataque in ataques_config:
		return ataques_config[tipo_ataque].delay_sonido
	return 0.0

func ajustar_volumen_hit(nuevo_volumen: float):
	volumen_hit = nuevo_volumen
	if sonido_hit:
		sonido_hit.volume_db = nuevo_volumen

func ajustar_volumen_muerte(nuevo_volumen: float):
	volumen_muerte = nuevo_volumen
	if sonido_muerte:
		sonido_muerte.volume_db = nuevo_volumen

func ajustar_volumen_dash(nuevo_volumen: float):
	volumen_dash = nuevo_volumen
	if sonido_dash:
		sonido_dash.volume_db = nuevo_volumen

func silenciar_todos_los_sonidos():
	var todos_los_sonidos = [sonido_ataque1, sonido_hit, sonido_muerte, sonido_ataque4, 
							sonido_ataque2y3, sonido_dash, sonido_especial2, sonido_especialdoble]
	
	for sonido in todos_los_sonidos:
		if sonido and sonido.playing:
			sonido.stop()
	
	_cancelar_sonidos_pendientes()

func reactivar_sonidos():
	_configurar_sonidos()

# FUNCIONES PÚBLICAS PARA EL SISTEMA DE RESET
func obtener_puntos_iniciales_escena() -> int:
	return puntos_iniciales_escena

func actualizar_puntos_iniciales(nuevos_puntos: int):
	puntos_iniciales_escena = nuevos_puntos

func forzar_reset_escena():
	_resetear_escena()

func ajustar_tiempo_delay_reset(nuevo_tiempo: float):
	tiempo_delay_reset = nuevo_tiempo
	if timer_reset:
		timer_reset.wait_time = nuevo_tiempo

func obtener_nombre_ataque(tipo_ataque: TipoAtaque) -> String:
	match tipo_ataque:
		TipoAtaque.ATAQUE1: return "Ataque 1"
		TipoAtaque.ATAQUE2: return "Ataque 2"
		TipoAtaque.ATAQUE3: return "Ataque 3"
		TipoAtaque.ATAQUE4: return "Ataque 4"
		TipoAtaque.ESPECIAL2: return "Especial 2"
		TipoAtaque.ESPECIALDOBLE: return "Especial Doble"
		_: return "Desconocido"
