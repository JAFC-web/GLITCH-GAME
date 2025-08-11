extends CharacterBody2D

# Referencias a nodos - Optimizado con verificación de existencia
@onready var animated_sprite = $AnimationPlayer
@onready var sprite2d = $Sprite2D
@onready var raycast_izq = $izq
@onready var raycast_der = $der
@onready var area_ataques = $Area2D
@onready var collision_ataque1 = $Area2D/aq1_1
@onready var collision_ataque2 = $Area2D/aq1_2

# Estados del boss
enum Estado {
	IDLE,
	PATRULLA,
	PERSEGUIR,
	ATAQUE1,
	ATAQUE2,
	ATAQUE_ESPECIAL,  # NUEVO: Ataque especial para fases avanzadas
	HIT,
	DEAD
}

# NUEVO: Sistema de fases
enum Fase {
	NORMAL,
	ENOJADO,
	FURIOSO
}

# Variables del boss - Optimizado con valores más eficientes
var estado_actual = Estado.PATRULLA
var vida_maxima = 500.0
var vida_actual = 500.0
var velocidad_base = 50.0
var velocidad_persecucion_base = 80.0
var velocidad_gravedad = 980.0
var jugador = null
var jugador_detectado = false
var puede_atacar = true
var distancia_ataque_base = 100.0
var distancia_deteccion_base = 250.0
var tiempo_entre_ataques_base = 3.0
var timer_ataque = 0.0
var direccion = 1
var esta_muerto = false
var esta_invulnerable = false
var tiempo_invulnerabilidad = 0.8

# NUEVO: Variables de fases
var fase_actual = Fase.NORMAL
var fase_anterior = Fase.NORMAL
var cambio_fase_procesado = false

# Variables calculadas según la fase
var velocidad = 50.0
var velocidad_persecucion = 80.0
var distancia_ataque = 100.0
var distancia_deteccion = 250.0
var tiempo_entre_ataques = 3.0

# Variables de patrullaje
var punto_inicial: Vector2
var distancia_patrulla_base = 150.0
var distancia_patrulla = 150.0
var limite_izq: float
var limite_der: float

# Variables para sistema de daño
var daño_ataque1_base = 25.0
var daño_ataque2_base = 30.0
var daño_ataque_especial = 45.0  # NUEVO: Daño del ataque especial
var daño_ataque1 = 25.0
var daño_ataque2 = 30.0
var cooldown_daño = 1.2
var recibiendo_dano = false

# Sistema de seguridad optimizado
var tiempo_desde_ultimo_hit = 0.0
var tiempo_maximo_hit = 1.2
var hit_timer = 0.0

# Sistema de cooldowns optimizado
var cooldowns_jugadores = {}

# RayCasts para detección de obstáculos
@onready var raycast_pared_izq = $RaycastParedIzq
@onready var raycast_pared_der = $RaycastParedDer
@onready var raycast_suelo_izq = $RaycastSueloIzq
@onready var raycast_suelo_der = $RaycastSueloDer

# Sistema para recibir daño del jugador
var detector_ataques = null
@export var daño_por_ataque_jugador: Dictionary = {
	"ataque1": 10.0,
	"ataque2": 15.0,
	"ataque3": 15.0,
	"ataque4": 40.0,
	"especial2": 30.0,
	"especialdoble": 20.0
}

# Variables optimizadas para volteo de colisiones
var mirando_derecha = true
var posiciones_originales_colisiones = {}

# Variables para control de animación de muerte
var muerte_iniciada = false
var animacion_muerte_completada = false
var animacion_muerte_reproducida = false

# NUEVO: Variables para efectos de fases
var efecto_fase_activo = false
var intensidad_parpadeo_fase = 1.0

# Señales optimizadas
signal boss_muerto
signal jugador_dañado(daño)
signal vida_cambiada(vida_nueva, vida_maxima)
signal daño_recibido(daño, vida_restante)
signal fase_cambiada(nueva_fase)  # NUEVO: Señal de cambio de fase

func _ready():
	vida_actual = vida_maxima
	
	if not animated_sprite or not sprite2d:
		push_error("Boss: Nodos críticos faltantes (AnimationPlayer o Sprite2D)")
		return
	
	punto_inicial = global_position
	_actualizar_limites_patrulla()
	
	_inicializar_sistemas()
	_actualizar_stats_por_fase()
	
	cambiar_estado(Estado.PATRULLA)
	vida_cambiada.emit(vida_actual, vida_maxima)

func _inicializar_sistemas():
	guardar_posiciones_originales_colisiones()
	_configurar_area_ataques()
	_configurar_raycasts()
	configurar_detector_ataques()
	configurar_raycast_obstaculos()
	
	if animated_sprite and not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _configurar_area_ataques():
	if area_ataques and not area_ataques.body_entered.is_connected(_on_area_ataques_body_entered):
		area_ataques.body_entered.connect(_on_area_ataques_body_entered)
		area_ataques.body_exited.connect(_on_area_ataques_body_exited)
	
	_desactivar_colisiones_ataque()

func _configurar_raycasts():
	if raycast_izq:
		raycast_izq.enabled = true
		raycast_izq.target_position = Vector2(-distancia_deteccion, 0)
	if raycast_der:
		raycast_der.enabled = true
		raycast_der.target_position = Vector2(distancia_deteccion, 0)

func _desactivar_colisiones_ataque():
	if collision_ataque1:
		collision_ataque1.disabled = true
	if collision_ataque2:
		collision_ataque2.disabled = true

# NUEVO: Sistema de fases
func verificar_cambio_fase():
	var nueva_fase = determinar_fase_por_vida()
	
	if nueva_fase != fase_actual:
		cambiar_fase(nueva_fase)

func determinar_fase_por_vida() -> Fase:
	var porcentaje_vida = get_vida_porcentaje()
	
	if porcentaje_vida <= 0.25:
		return Fase.FURIOSO
	elif porcentaje_vida <= 0.5:
		return Fase.ENOJADO
	else:
		return Fase.NORMAL

func cambiar_fase(nueva_fase: Fase):
	if nueva_fase == fase_actual:
		return
	
	fase_anterior = fase_actual
	fase_actual = nueva_fase
	cambio_fase_procesado = false
	
	_actualizar_stats_por_fase()
	_aplicar_efectos_visuales_fase()
	_procesar_cambio_fase()
	
	fase_cambiada.emit(nueva_fase)

func _actualizar_stats_por_fase():
	match fase_actual:
		Fase.NORMAL:
			velocidad = velocidad_base
			velocidad_persecucion = velocidad_persecucion_base
			distancia_ataque = distancia_ataque_base
			distancia_deteccion = distancia_deteccion_base
			tiempo_entre_ataques = tiempo_entre_ataques_base
			daño_ataque1 = daño_ataque1_base
			daño_ataque2 = daño_ataque2_base
			distancia_patrulla = distancia_patrulla_base
			intensidad_parpadeo_fase = 1.0
		
		Fase.ENOJADO:
			velocidad = velocidad_base * 1.5
			velocidad_persecucion = velocidad_persecucion_base * 1.4
			distancia_ataque = distancia_ataque_base * 1
			distancia_deteccion = distancia_deteccion_base * 2
			tiempo_entre_ataques = tiempo_entre_ataques_base * 0.8
			daño_ataque1 = daño_ataque1_base * 1.2
			daño_ataque2 = daño_ataque2_base * 1.3
			distancia_patrulla = distancia_patrulla_base * 2
			intensidad_parpadeo_fase = 1.2
		
		Fase.FURIOSO:
			velocidad = velocidad_base * 2
			velocidad_persecucion = velocidad_persecucion_base * 2.3
			distancia_ataque = distancia_ataque_base * 1
			distancia_deteccion = distancia_deteccion_base * 3
			tiempo_entre_ataques = tiempo_entre_ataques_base * 0.6
			daño_ataque1 = daño_ataque1_base * 1.4
			daño_ataque2 = daño_ataque2_base * 1.5
			distancia_patrulla = distancia_patrulla_base * 3
			intensidad_parpadeo_fase = 1.5
	
	_actualizar_limites_patrulla()
	_actualizar_raycasts_deteccion()

func _actualizar_limites_patrulla():
	limite_izq = punto_inicial.x - distancia_patrulla
	limite_der = punto_inicial.x + distancia_patrulla

func _actualizar_raycasts_deteccion():
	if raycast_izq:
		raycast_izq.target_position = Vector2(-distancia_deteccion, 0)
	if raycast_der:
		raycast_der.target_position = Vector2(distancia_deteccion, 0)

func _aplicar_efectos_visuales_fase():
	match fase_actual:
		Fase.NORMAL:
			sprite2d.modulate = Color.WHITE
		Fase.ENOJADO:
			sprite2d.modulate = Color(1.2, 0.9, 0.9)  # Tinte rojizo sutil
			_crear_efecto_transicion_fase()
		Fase.FURIOSO:
			sprite2d.modulate = Color(1.4, 0.8, 0.8)  # Tinte rojizo más intenso
			_crear_efecto_transicion_fase()

func _crear_efecto_transicion_fase():
	if efecto_fase_activo:
		return
		
	efecto_fase_activo = true
	var tiempo_parpadeo = 0.1
	var veces_parpadear = 5
	
	for i in range(veces_parpadear):
		if esta_muerto:
			break
		sprite2d.modulate.a = 0.5
		await get_tree().create_timer(tiempo_parpadeo).timeout
		sprite2d.modulate.a = 1.0
		await get_tree().create_timer(tiempo_parpadeo).timeout
	
	efecto_fase_activo = false

func _procesar_cambio_fase():
	if cambio_fase_procesado:
		return
	
	cambio_fase_procesado = true
	
	# Interrumpir estado actual si es necesario
	if estado_actual in [Estado.IDLE, Estado.PATRULLA]:
		# Hacer una pequeña animación de transición
		cambiar_estado(Estado.HIT)
		await get_tree().create_timer(0.5).timeout
		
		if not esta_muerto:
			if jugador_detectado and jugador:
				cambiar_estado(Estado.PERSEGUIR)
			else:
				cambiar_estado(Estado.PATRULLA)

func guardar_posiciones_originales_colisiones():
	if collision_ataque1:
		posiciones_originales_colisiones["ataque1"] = collision_ataque1.position
	if collision_ataque2:
		posiciones_originales_colisiones["ataque2"] = collision_ataque2.position
	if area_ataques:
		posiciones_originales_colisiones["area_ataques"] = area_ataques.position

func voltear_sprite_y_colisiones(hacia_derecha: bool):
	if hacia_derecha == mirando_derecha:
		return
	
	mirando_derecha = hacia_derecha
	sprite2d.flip_h = not hacia_derecha
	_actualizar_posiciones_colisiones(hacia_derecha)
	direccion = 1 if hacia_derecha else -1

func _actualizar_posiciones_colisiones(hacia_derecha: bool):
	for tipo in ["ataque1", "ataque2", "area_ataques"]:
		if tipo in posiciones_originales_colisiones:
			var nodo = null
			match tipo:
				"ataque1":
					nodo = collision_ataque1
				"ataque2":
					nodo = collision_ataque2
				"area_ataques":
					nodo = area_ataques
			
			if nodo:
				var pos_original = posiciones_originales_colisiones[tipo]
				nodo.position.x = pos_original.x if hacia_derecha else -pos_original.x

func configurar_detector_ataques():
	if has_node("DetectorAtaques"):
		detector_ataques = $DetectorAtaques
	else:
		detector_ataques = Area2D.new()
		detector_ataques.name = "DetectorAtaques"
		add_child(detector_ataques)
		
		var collision_shape = CollisionShape2D.new()
		var rectangle_shape = RectangleShape2D.new()
		rectangle_shape.size = Vector2(120, 140)
		collision_shape.shape = rectangle_shape
		detector_ataques.add_child(collision_shape)
	
	if not detector_ataques.body_entered.is_connected(_on_ataque_jugador_detectado):
		detector_ataques.body_entered.connect(_on_ataque_jugador_detectado)
		detector_ataques.area_entered.connect(_on_area_ataque_detectada)

func configurar_raycast_obstaculos():
	var raycast_configs = [
		{"nombre": "raycast_pared_izq", "pos": Vector2.ZERO, "target": Vector2(-40, 0)},
		{"nombre": "raycast_pared_der", "pos": Vector2.ZERO, "target": Vector2(40, 0)},
		{"nombre": "raycast_suelo_izq", "pos": Vector2(-30, 0), "target": Vector2(0, 60)},
		{"nombre": "raycast_suelo_der", "pos": Vector2(30, 0), "target": Vector2(0, 60)}
	]
	
	for config in raycast_configs:
		_crear_raycast_si_necesario(config)

func _crear_raycast_si_necesario(config: Dictionary):
	var raycast_var = get(config.nombre)
	if not raycast_var:
		var nuevo_raycast = RayCast2D.new()
		add_child(nuevo_raycast)
		nuevo_raycast.position = config.pos
		nuevo_raycast.target_position = config.target
		nuevo_raycast.enabled = true
		nuevo_raycast.collision_mask = 1
		set(config.nombre, nuevo_raycast)

func _physics_process(delta):
	if vida_actual <= 0 and not muerte_iniciada:
		_iniciar_proceso_muerte()
		return
	
	if esta_muerto:
		if estado_actual != Estado.DEAD:
			estado_dead()
		return
	
	# NUEVO: Verificar cambio de fase
	verificar_cambio_fase()
	
	_procesar_logica_normal(delta)

func _iniciar_proceso_muerte():
	if muerte_iniciada:
		return
		
	muerte_iniciada = true
	esta_muerto = true
	morir()

func _procesar_logica_normal(delta):
	actualizar_cooldowns(delta)
	verificar_y_resetear_estado_hit(delta)
	
	if not is_on_floor():
		velocity.y += velocidad_gravedad * delta
	else:
		velocity.y = 0
	
	if estado_actual != Estado.HIT:
		detectar_jugador()
	
	actualizar_timer(delta)
	_ejecutar_estado_actual(delta)
	move_and_slide()

func _ejecutar_estado_actual(delta):
	match estado_actual:
		Estado.IDLE:
			estado_idle()
		Estado.PATRULLA:
			estado_patrulla()
		Estado.PERSEGUIR:
			estado_perseguir(delta)
		Estado.ATAQUE1:
			estado_ataque1()
		Estado.ATAQUE2:
			estado_ataque2()
		Estado.ATAQUE_ESPECIAL:  # NUEVO
			estado_ataque_especial()
		Estado.HIT:
			estado_hit(delta)
		Estado.DEAD:
			estado_dead()

func detectar_jugador():
	jugador_detectado = false
	jugador = null
	
	var jugadores = get_tree().get_nodes_in_group("player")
	if jugadores.is_empty():
		return
	
	var jugador_mas_cercano = null
	var distancia_minima = distancia_deteccion
	
	for player in jugadores:
		var distancia = global_position.distance_to(player.global_position)
		if distancia <= distancia_minima:
			jugador_mas_cercano = player
			distancia_minima = distancia
	
	if jugador_mas_cercano:
		jugador = jugador_mas_cercano
		jugador_detectado = true

func estado_idle():
	if animated_sprite.current_animation != "idle":
		animated_sprite.play("idle")
	velocity.x = 0
	
	if jugador_detectado and jugador:
		cambiar_estado(Estado.PERSEGUIR)
	else:
		await get_tree().create_timer(0.5).timeout
		if not jugador_detectado:
			cambiar_estado(Estado.PATRULLA)

func estado_patrulla():
	if recibiendo_dano:
		return
		
	if animated_sprite.current_animation != "walk":
		animated_sprite.play("walk")
	
	if jugador_detectado:
		cambiar_estado(Estado.PERSEGUIR)
		return
	
	verificar_obstaculos()
	velocity.x = direccion * velocidad * 0.6
	voltear_sprite_y_colisiones(direccion == 1)
	_verificar_limites_patrullaje()

func _verificar_limites_patrullaje():
	if global_position.x <= limite_izq and direccion == -1:
		direccion = 1
		voltear_sprite_y_colisiones(true)
	elif global_position.x >= limite_der and direccion == 1:
		direccion = -1
		voltear_sprite_y_colisiones(false)

func verificar_obstaculos():
	var hay_obstaculo = false
	
	if direccion == -1:
		hay_obstaculo = _verificar_obstaculo_izquierda()
	elif direccion == 1:
		hay_obstaculo = _verificar_obstaculo_derecha()
	
	if hay_obstaculo:
		direccion *= -1

func _verificar_obstaculo_izquierda() -> bool:
	var hay_pared = raycast_pared_izq and raycast_pared_izq.is_colliding() and not _es_jugador(raycast_pared_izq.get_collider())
	var no_hay_suelo = raycast_suelo_izq and not raycast_suelo_izq.is_colliding()
	return hay_pared or no_hay_suelo

func _verificar_obstaculo_derecha() -> bool:
	var hay_pared = raycast_pared_der and raycast_pared_der.is_colliding() and not _es_jugador(raycast_pared_der.get_collider())
	var no_hay_suelo = raycast_suelo_der and not raycast_suelo_der.is_colliding()
	return hay_pared or no_hay_suelo

func _es_jugador(collider) -> bool:
	return collider and collider.is_in_group("player")

func estado_perseguir(delta):
	if recibiendo_dano:
		return
		
	if animated_sprite.current_animation != "walk":
		animated_sprite.play("walk")
	
	if jugador_detectado and jugador:
		var distancia = global_position.distance_to(jugador.global_position)
		
		if distancia <= distancia_ataque and puede_atacar:
			velocity.x = 0
			_elegir_ataque()
			return
		
		var direccion_jugador = (jugador.global_position - global_position).normalized()
		velocity.x = direccion_jugador.x * velocidad_persecucion
		
		var nueva_direccion = 1 if direccion_jugador.x > 0 else -1
		if nueva_direccion != direccion:
			voltear_sprite_y_colisiones(nueva_direccion == 1)
			direccion = nueva_direccion
	else:
		cambiar_estado(Estado.PATRULLA)

# MEJORADO: Sistema de selección de ataques por fases
func _elegir_ataque():
	var probabilidad_especial = 0.0
	
	match fase_actual:
		Fase.NORMAL:
			if randf() > 0.5:
				cambiar_estado(Estado.ATAQUE2)
			else:
				cambiar_estado(Estado.ATAQUE1)
		
		Fase.ENOJADO:
			probabilidad_especial = 0.2
			var rand_val = randf()
			
			if rand_val < probabilidad_especial:
				cambiar_estado(Estado.ATAQUE_ESPECIAL)
			elif rand_val < 0.7:
				cambiar_estado(Estado.ATAQUE2)
			else:
				cambiar_estado(Estado.ATAQUE1)
		
		Fase.FURIOSO:
			probabilidad_especial = 0.4
			var rand_val = randf()
			
			if rand_val < probabilidad_especial:
				cambiar_estado(Estado.ATAQUE_ESPECIAL)
			elif rand_val < 0.8:
				cambiar_estado(Estado.ATAQUE2)
			else:
				cambiar_estado(Estado.ATAQUE1)

func estado_ataque1():
	if animated_sprite.current_animation != "ataque1":
		animated_sprite.play("ataque1")
	velocity.x = 0
	
	if collision_ataque1:
		collision_ataque1.disabled = false
	if collision_ataque2:
		collision_ataque2.disabled = true

func estado_ataque2():
	if animated_sprite.current_animation != "ataque2":
		animated_sprite.play("ataque2")
	velocity.x = 0
	
	if collision_ataque1:
		collision_ataque1.disabled = true
	if collision_ataque2:
		collision_ataque2.disabled = false

# NUEVO: Estado de ataque especial
func estado_ataque_especial():
	var anim_especial = "ataque_especial"
	
	# Fallback a otras animaciones si no existe ataque_especial
	if not animated_sprite.has_animation(anim_especial):
		if animated_sprite.has_animation("ataque3"):
			anim_especial = "ataque3"
		else:
			anim_especial = "ataque2"  # Usar ataque2 como fallback
	
	if animated_sprite.current_animation != anim_especial:
		animated_sprite.play(anim_especial)
	velocity.x = 0
	
	# Activar ambas colisiones para ataque especial
	if collision_ataque1:
		collision_ataque1.disabled = false
	if collision_ataque2:
		collision_ataque2.disabled = false

func estado_hit(delta):
	velocity.x = 0
	hit_timer += delta
	
	if animated_sprite.has_animation("hit") and animated_sprite.current_animation != "hit":
		animated_sprite.play("hit")

func estado_dead():
	velocity.x = 0
	velocity.y = min(velocity.y, 0)
	
	if animacion_muerte_completada or animacion_muerte_reproducida:
		return
	
	animacion_muerte_reproducida = true
	
	if animated_sprite.has_animation("dead"):
		animated_sprite.play("dead")
	else:
		var animaciones_muerte = ["death", "die", "muerte"]
		var animacion_encontrada = false
		
		for anim_name in animaciones_muerte:
			if animated_sprite.has_animation(anim_name):
				animated_sprite.play(anim_name)
				animacion_encontrada = true
				break
		
		if not animacion_encontrada:
			_completar_muerte_async()

func cambiar_estado(nuevo_estado):
	if muerte_iniciada and nuevo_estado != Estado.DEAD:
		return
		
	estado_actual = nuevo_estado
	_desactivar_colisiones_ataque()
	
	match nuevo_estado:
		Estado.ATAQUE1, Estado.ATAQUE2, Estado.ATAQUE_ESPECIAL:
			puede_atacar = false
			timer_ataque = tiempo_entre_ataques
		Estado.HIT:
			recibiendo_dano = true
			hit_timer = 0.0
			tiempo_desde_ultimo_hit = 0.0
		Estado.PERSEGUIR, Estado.PATRULLA:
			recibiendo_dano = false
			hit_timer = 0.0
		Estado.DEAD:
			recibiendo_dano = false
			if raycast_izq:
				raycast_izq.enabled = false
			if raycast_der:
				raycast_der.enabled = false

func actualizar_timer(delta):
	if timer_ataque > 0:
		timer_ataque -= delta
		if timer_ataque <= 0:
			puede_atacar = true

func verificar_y_resetear_estado_hit(delta):
	if estado_actual == Estado.HIT:
		tiempo_desde_ultimo_hit += delta
		
		if tiempo_desde_ultimo_hit > tiempo_maximo_hit:
			forzar_salida_hit()
		elif animated_sprite.has_animation("hit") and not animated_sprite.is_playing() and tiempo_desde_ultimo_hit > 0.3:
			forzar_salida_hit()
	else:
		tiempo_desde_ultimo_hit = 0.0

func forzar_salida_hit():
	recibiendo_dano = false
	hit_timer = 0.0
	tiempo_desde_ultimo_hit = 0.0
	
	if jugador_detectado and jugador and not esta_muerto:
		cambiar_estado(Estado.PERSEGUIR)
	elif not esta_muerto:
		cambiar_estado(Estado.PATRULLA)

func actualizar_cooldowns(delta):
	if cooldowns_jugadores.is_empty():
		return
		
	var jugadores_a_remover = []
	
	for jugador_id in cooldowns_jugadores:
		cooldowns_jugadores[jugador_id] -= delta
		if cooldowns_jugadores[jugador_id] <= 0:
			jugadores_a_remover.append(jugador_id)
	
	for jugador_id in jugadores_a_remover:
		cooldowns_jugadores.erase(jugador_id)

func aplicar_daño_al_jugador(jugador_objetivo, daño):
	var jugador_id = jugador_objetivo.get_instance_id()
	
	if jugador_id in cooldowns_jugadores:
		return
	
	if jugador_objetivo.has_method("recibir_daño"):
		jugador_objetivo.recibir_daño(daño)
		cooldowns_jugadores[jugador_id] = cooldown_daño
		jugador_dañado.emit(daño)

func recibir_daño(cantidad_daño: float):
	if esta_muerto or esta_invulnerable or muerte_iniciada:
		return
	
	vida_actual -= cantidad_daño
	vida_actual = max(0, vida_actual)
	
	vida_cambiada.emit(vida_actual, vida_maxima)
	daño_recibido.emit(cantidad_daño, vida_actual)
	
	if vida_actual <= 0:
		_iniciar_proceso_muerte()
		return
	
	activar_invulnerabilidad()
	
	if estado_actual not in [Estado.ATAQUE1, Estado.ATAQUE2, Estado.ATAQUE_ESPECIAL]:
		cambiar_estado(Estado.HIT)

func activar_invulnerabilidad():
	esta_invulnerable = true
	crear_efecto_parpadeo()
	
	await get_tree().create_timer(tiempo_invulnerabilidad).timeout
	esta_invulnerable = false

func crear_efecto_parpadeo():
	var tiempo_parpadeo = 0.08
	var veces_parpadear = int(tiempo_invulnerabilidad / (tiempo_parpadeo * 2))
	
	for i in range(veces_parpadear):
		if esta_muerto:
			break
		sprite2d.modulate.a = 0.3 * intensidad_parpadeo_fase
		await get_tree().create_timer(tiempo_parpadeo).timeout
		sprite2d.modulate.a = 1.0
		await get_tree().create_timer(tiempo_parpadeo).timeout

func morir():
	if muerte_iniciada:
		return
		
	muerte_iniciada = true
	esta_muerto = true
	
	_desactivar_colisiones_ataque()
	if raycast_izq:
		raycast_izq.enabled = false
	if raycast_der:
		raycast_der.enabled = false
	
	cambiar_estado(Estado.DEAD)

func _completar_muerte_async():
	if animacion_muerte_completada:
		return
	await get_tree().create_timer(1.0).timeout
	if not animacion_muerte_completada:
		_completar_muerte()

func _cambiar_escena_simple():
	# Cambiar a la escena de créditos
	if ResourceLoader.exists("res://menu/ecenafinalcred.tscn"):
		get_tree().change_scene_to_file("res://menu/ecenafinalcred.tscn")

func _completar_muerte():
	if animacion_muerte_completada:
		return
		
	animacion_muerte_completada = true
	
	# NUEVO: Notificar al sistema de puntos que el boss fue eliminado
	if PointSystem:
		PointSystem.boss_killed()
	else:
		print("ADVERTENCIA: PointSystem no encontrado")
	
	boss_muerto.emit()
	
	# Cambiar a la escena de créditos después de 5 segundos
	await get_tree().create_timer(5.0).timeout
	_cambiar_escena_simple()

# Funciones de detección de ataques del jugador
func _on_area_ataque_detectada(area: Area2D):
	var jugador_atacante = area.get_parent()
	if not _validar_ataque_jugador(jugador_atacante):
		return
	
	var animacion_actual = _obtener_animacion_jugador(jugador_atacante)
	aplicar_dano_por_ataque(animacion_actual)

func _on_ataque_jugador_detectado(body: Node2D):
	if not _validar_ataque_jugador(body):
		return
	
	var animacion_actual = _obtener_animacion_jugador(body)
	aplicar_dano_por_ataque(animacion_actual)

func _validar_ataque_jugador(jugador_obj) -> bool:
	if not jugador_obj or not jugador_obj.is_in_group("player"):
		return false
	
	var esta_atacando = false
	if jugador_obj.has_method("esta_atacando"):
		esta_atacando = jugador_obj.esta_atacando()
	elif "atacando" in jugador_obj:
		esta_atacando = jugador_obj.atacando
	
	return esta_atacando

func _obtener_animacion_jugador(jugador_obj) -> String:
	if "animation_player" in jugador_obj:
		return jugador_obj.animation_player.current_animation
	return ""

func aplicar_dano_por_ataque(tipo_ataque: String):
	if esta_muerto or esta_invulnerable or muerte_iniciada:
		return
	
	var cantidad_dano = daño_por_ataque_jugador.get(tipo_ataque, 0.0)
	
	if cantidad_dano > 0:
		recibir_daño(cantidad_dano)

func _on_area_ataques_body_entered(body):
	if not body.is_in_group("player"):
		return
		
	var daño = 0.0
	
	match estado_actual:
		Estado.ATAQUE1:
			if collision_ataque1 and not collision_ataque1.disabled:
				daño = daño_ataque1
		Estado.ATAQUE2:
			if collision_ataque2 and not collision_ataque2.disabled:
				daño = daño_ataque2
		Estado.ATAQUE_ESPECIAL:
			# El ataque especial hace más daño
			if (collision_ataque1 and not collision_ataque1.disabled) or (collision_ataque2 and not collision_ataque2.disabled):
				daño = daño_ataque_especial
	
	if daño > 0:
		aplicar_daño_al_jugador(body, daño)

func _on_area_ataques_body_exited(body):
	pass

func _on_animation_finished(anim_name):
	match anim_name:
		"ataque1", "ataque2", "ataque_especial", "ataque3":
			_desactivar_colisiones_ataque()
			if jugador_detectado and jugador and not esta_muerto:
				cambiar_estado(Estado.PERSEGUIR)
			elif not esta_muerto:
				cambiar_estado(Estado.PATRULLA)
		
		"hit":
			forzar_salida_hit()
		
		"dead", "death", "die", "muerte":
			_completar_muerte()

# Funciones utilitarias
func get_vida_porcentaje() -> float:
	return vida_actual / vida_maxima if vida_maxima > 0 else 0.0

func get_vida_actual() -> float:
	return vida_actual

func get_vida_maxima() -> float:
	return vida_maxima

func esta_vivo() -> bool:
	return not esta_muerto and not muerte_iniciada

func get_fase_actual() -> Fase:
	return fase_actual

func get_nombre_fase_actual() -> String:
	match fase_actual:
		Fase.NORMAL:
			return "Normal"
		Fase.ENOJADO:
			return "Enojado"
		Fase.FURIOSO:
			return "Furioso"
		_:
			return "Desconocido"

func configurar_dano_ataque_jugador(tipo_ataque: String, nuevo_dano: float):
	if tipo_ataque in daño_por_ataque_jugador:
		daño_por_ataque_jugador[tipo_ataque] = nuevo_dano

# FUNCIONES DE TESTING Y DEBUG (Optimizadas - solo las esenciales)

func forzar_actualizacion_vida():
	vida_cambiada.emit(vida_actual, vida_maxima)

func debug_boss():
	print("=== DEBUG BOSS ===")
	print("Vida: ", vida_actual, "/", vida_maxima, " (", get_vida_porcentaje() * 100, "%)")
	print("Estado: ", Estado.keys()[estado_actual])
	print("Fase: ", get_nombre_fase_actual())
	print("Está muerto: ", esta_muerto)
	print("Está invulnerable: ", esta_invulnerable)
	print("Jugador detectado: ", jugador_detectado)
	print("Velocidad actual: ", velocidad)
	print("Velocidad persecución: ", velocidad_persecucion)
	print("Distancia ataque: ", distancia_ataque)
	print("Tiempo entre ataques: ", tiempo_entre_ataques)
	print("==================")

func test_recibir_dano(cantidad: float = 10.0):
	recibir_daño(cantidad)

func resetear_vida():
	vida_actual = vida_maxima
	esta_muerto = false
	muerte_iniciada = false
	animacion_muerte_completada = false
	animacion_muerte_reproducida = false
	esta_invulnerable = false
	recibiendo_dano = false
	
	# Resetear fase
	fase_actual = Fase.NORMAL
	fase_anterior = Fase.NORMAL
	cambio_fase_procesado = false
	_actualizar_stats_por_fase()
	_aplicar_efectos_visuales_fase()
	
	if raycast_izq:
		raycast_izq.enabled = true
	if raycast_der:
		raycast_der.enabled = true
	
	vida_cambiada.emit(vida_actual, vida_maxima)
	fase_cambiada.emit(fase_actual)
	cambiar_estado(Estado.PATRULLA)

func test_cambiar_fase(nueva_fase: Fase):
	cambiar_fase(nueva_fase)

func test_fase_enojado():
	vida_actual = vida_maxima * 0.5
	verificar_cambio_fase()

func test_fase_furioso():
	vida_actual = vida_maxima * 0.25
	verificar_cambio_fase()

func forzar_estado(nuevo_estado: Estado):
	cambiar_estado(nuevo_estado)

func limpiar_boss():
	esta_muerto = false
	muerte_iniciada = false
	animacion_muerte_completada = false
	animacion_muerte_reproducida = false
	esta_invulnerable = false
	recibiendo_dano = false
	jugador_detectado = false
	jugador = null
	puede_atacar = true
	timer_ataque = 0.0
	hit_timer = 0.0
	tiempo_desde_ultimo_hit = 0.0
	efecto_fase_activo = false
	
	cooldowns_jugadores.clear()
	vida_actual = vida_maxima
	
	# Resetear fase
	fase_actual = Fase.NORMAL
	fase_anterior = Fase.NORMAL
	cambio_fase_procesado = false
	_actualizar_stats_por_fase()
	_aplicar_efectos_visuales_fase()
	
	if raycast_izq:
		raycast_izq.enabled = true
	if raycast_der:
		raycast_der.enabled = true
	
	_desactivar_colisiones_ataque()
	sprite2d.modulate.a = 1.0
	resetear_orientacion()
	cambiar_estado(Estado.PATRULLA)
	
	vida_cambiada.emit(vida_actual, vida_maxima)
	fase_cambiada.emit(fase_actual)

func resetear_orientacion():
	mirando_derecha = true
	direccion = 1
	sprite2d.flip_h = false
	
	for tipo in posiciones_originales_colisiones:
		var nodo = null
		match tipo:
			"ataque1":
				nodo = collision_ataque1
			"ataque2":
				nodo = collision_ataque2
			"area_ataques":
				nodo = area_ataques
		
		if nodo:
			nodo.position = posiciones_originales_colisiones[tipo]

# Función de información resumida
func info_boss():
	print("=== INFO BOSS ===")
	print("Vida: ", vida_actual, "/", vida_maxima, " (", snappedf(get_vida_porcentaje() * 100, 0.1), "%)")
	print("Fase: ", get_nombre_fase_actual())
	print("Estado: ", Estado.keys()[estado_actual])
	print("Velocidad: ", velocidad, " (persecución: ", velocidad_persecucion, ")")
	print("Daño ataques: ", daño_ataque1, "/", daño_ataque2, "/", daño_ataque_especial)
	print("Distancias: ataque=", distancia_ataque, " detección=", distancia_deteccion)
	print("Tiempo entre ataques: ", tiempo_entre_ataques, "s")
	if jugador_detectado and jugador:
		print("Jugador detectado a distancia: ", snappedf(global_position.distance_to(jugador.global_position), 0.1))
	print("=================")

# Funciones de testing rápido de fases
func test_transicion_completa():
	print("=== TEST TRANSICIÓN COMPLETA ===")
	print("Iniciando en fase Normal...")
	resetear_vida()
	await get_tree().create_timer(1.0).timeout
	
	print("Cambiando a fase Enojado...")
	test_fase_enojado()
	await get_tree().create_timer(2.0).timeout
	
	print("Cambiando a fase Furioso...")
	test_fase_furioso()
	await get_tree().create_timer(2.0).timeout
	
	print("=== TEST COMPLETADO ===")

func mostrar_stats_fases():
	print("=== STATS POR FASE ===")
	
	print("NORMAL:")
	print("  Velocidad: ", velocidad_base, "/", velocidad_persecucion_base)
	print("  Daño: ", daño_ataque1_base, "/", daño_ataque2_base)
	print("  Tiempo ataques: ", tiempo_entre_ataques_base, "s")
	
	print("ENOJADO:")
	print("  Velocidad: ", velocidad_base * 1.3, "/", velocidad_persecucion_base * 1.4)
	print("  Daño: ", daño_ataque1_base * 1.2, "/", daño_ataque2_base * 1.3)
	print("  Tiempo ataques: ", tiempo_entre_ataques_base * 0.8, "s")
	
	print("FURIOSO:")
	print("  Velocidad: ", velocidad_base * 1.6, "/", velocidad_persecucion_base * 1.8)
	print("  Daño: ", daño_ataque1_base * 1.4, "/", daño_ataque2_base * 1.5)
	print("  Tiempo ataques: ", tiempo_entre_ataques_base * 0.6, "s")
	print("  Ataque especial: ", daño_ataque_especial)
	print("======================")
