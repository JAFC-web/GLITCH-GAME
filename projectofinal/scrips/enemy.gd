extends CharacterBody2D

var VELOCIDAD = 100
var VELOCIDAD_PERSECUCION = 150
var movimiento = Vector2(0,0)
var forgod = true
var GRAVITY = 980

# Variables para el sistema de daño
@export var daño_al_jugador: float = 10.0
@export var cooldown_daño: float = 2.0
@export var distancia_deteccion: float = 200.0
@export var distancia_ataque: float = 80.0

# Sistema de vida del enemigo
@export var vida_maxima: float = 50.0
@export var tiempo_invulnerabilidad: float = 0.5
@export var cooldown_entre_ataques: float = 1.0
@export var probabilidad_idle: float = 0.02
@export var duracion_idle_min: float = 2.0
@export var duracion_idle_max: float = 4.0

# Variables para recibir daño de ataques del jugador
@export var daño_por_ataque_jugador: Dictionary = {
	"ataque1": 10.0,
	"ataque2": 15.0,
	"ataque3": 15.0,
	"ataque4": 40.0,
	"especial2": 30.0,
	"especialdoble": 20.0
}

var vida_actual: float
var esta_invulnerable: bool = false
var esta_muerto: bool = false

# Diccionario para trackear cooldowns por jugador
var cooldowns_jugadores = {}

# Variables de estado
var jugador_detectado = null
var esta_persiguiendo = false
var esta_atacando = false
var puede_atacar = true
var recibiendo_dano = false
var haciendo_idle = false
var tiempo_idle_restante = 0.0

# NUEVO: Timer para forzar reset de estados
var tiempo_desde_ultimo_hit = 0.0
var tiempo_maximo_hit = 1.0  # Máximo tiempo en estado de hit

# Referencias a nodos
var detector_caida_izq = null
var detector_caida_der = null
var area_deteccion = null
var detector_ataques = null
@onready var animation_player = $AnimationPlayer
@onready var sprite = $Sprite2D

func _ready():
	vida_actual = vida_maxima
	
	# Configurar señales del Area2D si existe
	if has_node("area_deteccion"):
		area_deteccion = $area_deteccion
		area_deteccion.body_entered.connect(_on_jugador_detectado)
		area_deteccion.body_exited.connect(_on_jugador_perdido)
	
	# Verificar otros nodos
	if has_node("detector_caida_izq"):
		detector_caida_izq = $detector_caida_izq
	if has_node("detector_caida_der"):
		detector_caida_der = $detector_caida_der
	
	# Configurar detector de ataques del jugador
	if has_node("DetectorAtaques"):
		detector_ataques = $DetectorAtaques
		detector_ataques.body_entered.connect(_on_ataque_jugador_detectado)
		detector_ataques.area_entered.connect(_on_area_ataque_detectada)
	else:
		crear_detector_ataques_automatico()

func _physics_process(delta):
	if esta_muerto:
		return
	
	# Actualizar cooldowns
	actualizar_cooldowns(delta)
	
	# NUEVO: Sistema de seguridad para evitar estados bloqueados
	verificar_y_resetear_estados_bloqueados(delta)
	
	# Actualizar tiempo de idle
	if haciendo_idle:
		tiempo_idle_restante -= delta
		if tiempo_idle_restante <= 0:
			terminar_idle()
	
	# Aplicar gravedad
	movimiento.y = GRAVITY
	
	# Detectar jugador usando los RayCasts originales si no hay Area2D
	if not area_deteccion:
		detectar_jugador_con_raycast()
	
	# Lógica principal del enemigo
	if recibiendo_dano:
		movimiento.x = 0
	elif esta_atacando:
		movimiento.x = 0
	elif haciendo_idle:
		movimiento.x = 0
	elif jugador_detectado and esta_persiguiendo:
		perseguir_jugador()
	else:
		patrullar()
	
	# Aplicar movimiento
	velocity = movimiento
	move_and_slide()

# NUEVO: Sistema de seguridad para evitar estados bloqueados
func verificar_y_resetear_estados_bloqueados(delta):
	# Contar tiempo desde el último hit
	if recibiendo_dano:
		tiempo_desde_ultimo_hit += delta
		
		# Si ha pasado demasiado tiempo en estado hit, forzar reset
		if tiempo_desde_ultimo_hit > tiempo_maximo_hit:
			forzar_reset_estado_hit()
	else:
		tiempo_desde_ultimo_hit = 0.0
	
	# Verificar si la animación está bloqueada
	if animation_player.current_animation == "" or animation_player.is_playing() == false:
		# Si no hay animación reproduciéndose y debería haberla
		if recibiendo_dano or esta_atacando or haciendo_idle:
			resetear_todos_los_estados()

func forzar_reset_estado_hit():
	recibiendo_dano = false
	tiempo_desde_ultimo_hit = 0.0
	
	# Restaurar capacidad de atacar si no está atacando
	if not esta_atacando:
		puede_atacar = true
	
	# Reanudar animación apropiada
	reanudar_animacion_normal()

func resetear_todos_los_estados():
	# Resetear estados (excepto muerte)
	if not esta_muerto:
		recibiendo_dano = false
		tiempo_desde_ultimo_hit = 0.0
		
		# Solo resetear ataque si no está en progreso
		if not (animation_player.current_animation == "ataque1" and animation_player.is_playing()):
			esta_atacando = false
			puede_atacar = true
		
		# Resetear idle solo si no está en transición
		if haciendo_idle and tiempo_idle_restante <= 0:
			terminar_idle()
		
		# Reanudar animación
		reanudar_animacion_normal()

func reanudar_animacion_normal():
	# Determinar qué animación debería reproducirse
	if esta_muerto:
		return
	elif recibiendo_dano:
		animation_player.play("hit")
	elif esta_atacando:
		animation_player.play("ataque1")
	elif haciendo_idle:
		if animation_player.has_animation("idle"):
			animation_player.play("idle")
		else:
			animation_player.pause()
	else:
		animation_player.play("walk")

func detectar_jugador_con_raycast():
	var jugador_encontrado = null
	
	if has_node("detec_izq") and $detec_izq.is_colliding():
		var collider = $detec_izq.get_collider()
		if collider and collider.is_in_group("player"):
			jugador_encontrado = collider
	
	if has_node("detect_der") and $detect_der.is_colliding():
		var collider = $detect_der.get_collider()
		if collider and collider.is_in_group("player"):
			jugador_encontrado = collider
	
	if jugador_encontrado and not jugador_detectado:
		_on_jugador_detectado(jugador_encontrado)
	elif not jugador_encontrado and jugador_detectado:
		if not esta_atacando:
			_on_jugador_perdido(jugador_detectado)

func patrullar():
	var hay_suelo_adelante = true
	
	if detector_caida_der and detector_caida_izq:
		if forgod:
			hay_suelo_adelante = detector_caida_der.is_colliding()
		else:
			hay_suelo_adelante = detector_caida_izq.is_colliding()
	
	if is_on_wall() or not hay_suelo_adelante:
		forgod = not forgod
	
	if randf() < probabilidad_idle and not haciendo_idle:
		iniciar_idle()
		return
	
	if forgod:
		movimiento.x = VELOCIDAD
		sprite.flip_h = false
		animation_player.play("walk")
	else:
		movimiento.x = -VELOCIDAD
		sprite.flip_h = true
		animation_player.play("walk")

func perseguir_jugador():
	if not jugador_detectado:
		return
	
	var distancia_al_jugador = global_position.distance_to(jugador_detectado.global_position)
	
	if distancia_al_jugador <= distancia_ataque and puede_atacar and not esta_atacando:
		iniciar_ataque()
		return
	
	if esta_atacando:
		return
	
	var direccion_x = jugador_detectado.global_position.x - global_position.x
	var puede_moverse = true
	
	if detector_caida_der and detector_caida_izq:
		if direccion_x > 0:
			puede_moverse = detector_caida_der.is_colliding()
		elif direccion_x < 0:
			puede_moverse = detector_caida_izq.is_colliding()
	
	if puede_moverse:
		if direccion_x > 0:
			movimiento.x = VELOCIDAD_PERSECUCION
			sprite.flip_h = false
		else:
			movimiento.x = -VELOCIDAD_PERSECUCION
			sprite.flip_h = true
		
		animation_player.play("walk")
	else:
		esta_persiguiendo = false
		movimiento.x = 0

func iniciar_ataque():
	if not puede_atacar or esta_atacando:
		return
	
	esta_atacando = true
	puede_atacar = false
	movimiento.x = 0
	
	if jugador_detectado:
		var direccion_x = jugador_detectado.global_position.x - global_position.x
		if direccion_x > 0:
			sprite.flip_h = false
		else:
			sprite.flip_h = true
	
	animation_player.play("ataque1")
	
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: String):
	match anim_name:
		"ataque1":
			esta_atacando = false
			aplicar_dano_en_ataque()
			
			if not jugador_detectado or not esta_persiguiendo:
				puede_atacar = true
			else:
				await get_tree().create_timer(cooldown_entre_ataques).timeout
				puede_atacar = true
			
			# NUEVO: Asegurar que vuelve a animación normal
			if not esta_muerto and not recibiendo_dano:
				reanudar_animacion_normal()
		
		"hit":
			recibiendo_dano = false
			tiempo_desde_ultimo_hit = 0.0
			
			# MEJORADO: Reset más robusto después del hit
			if not esta_muerto:
				# Restaurar capacidad de atacar si no estaba atacando antes del hit
				if not esta_atacando:
					puede_atacar = true
				
				# Volver a la animación apropiada
				await get_tree().create_timer(0.1).timeout  # Pequeña pausa
				reanudar_animacion_normal()
		
		"idle":
			if haciendo_idle:
				animation_player.play("idle")

func aplicar_dano_en_ataque():
	if jugador_detectado:
		var distancia = global_position.distance_to(jugador_detectado.global_position)
		if distancia <= distancia_ataque:
			aplicar_daño_al_jugador(jugador_detectado)

func _on_jugador_detectado(body):
	if body.is_in_group("player"):
		jugador_detectado = body
		esta_persiguiendo = true
		
		if haciendo_idle:
			forzar_terminar_idle()

func _on_jugador_perdido(body):
	if body.is_in_group("player") and body == jugador_detectado:
		jugador_detectado = null
		esta_persiguiendo = false

func aplicar_daño_al_jugador(jugador):
	var jugador_id = jugador.get_instance_id()
	
	if jugador_id in cooldowns_jugadores:
		return
	
	if jugador.has_method("recibir_daño"):
		jugador.recibir_daño(daño_al_jugador)
		cooldowns_jugadores[jugador_id] = cooldown_daño

func actualizar_cooldowns(delta):
	var jugadores_a_remover = []
	
	for jugador_id in cooldowns_jugadores:
		cooldowns_jugadores[jugador_id] -= delta
		
		if cooldowns_jugadores[jugador_id] <= 0:
			jugadores_a_remover.append(jugador_id)
	
	for jugador_id in jugadores_a_remover:
		cooldowns_jugadores.erase(jugador_id)

# ===== SISTEMA DE VIDA DEL ENEMIGO =====

func recibir_daño(cantidad_daño: float):
	if esta_muerto or esta_invulnerable:
		return
	
	vida_actual -= cantidad_daño
	
	activar_invulnerabilidad()
	
	if vida_actual <= 0:
		morir()
	else:
		recibir_hit()

func recibir_hit():
	recibiendo_dano = true
	tiempo_desde_ultimo_hit = 0.0  # NUEVO: Reset del contador
	
	if haciendo_idle:
		terminar_idle()
	
	# MEJORADO: Manejo más cuidadoso del estado de ataque
	var estaba_atacando = esta_atacando
	
	# Solo cancelar ataque si no ha empezado la animación
	if esta_atacando and animation_player.current_animation != "ataque1":
		esta_atacando = false
	
	# Prevenir nuevos ataques temporalmente
	puede_atacar = false
	
	# Reproducir animación de hit
	animation_player.play("hit")
	
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	
	# MEJORADO: Timer de seguridad mejorado
	await get_tree().create_timer(0.6).timeout  # Ligeramente más que la animación
	
	# Verificar si el estado aún no se ha reseteado
	if recibiendo_dano and not esta_muerto:
		forzar_reset_estado_hit()

func activar_invulnerabilidad():
	esta_invulnerable = true
	crear_efecto_parpadeo()
	
	await get_tree().create_timer(tiempo_invulnerabilidad).timeout
	esta_invulnerable = false

func crear_efecto_parpadeo():
	var tiempo_parpadeo = 0.1
	var veces_parpadear = int(tiempo_invulnerabilidad / (tiempo_parpadeo * 2))
	
	for i in range(veces_parpadear):
		sprite.modulate.a = 0.5
		await get_tree().create_timer(tiempo_parpadeo).timeout
		sprite.modulate.a = 1.0
		await get_tree().create_timer(tiempo_parpadeo).timeout

func morir():
	esta_muerto = true
	esta_persiguiendo = false
	esta_atacando = false
	recibiendo_dano = false
	haciendo_idle = false
	
	movimiento.x = 0
	velocity = movimiento
	
	# NUEVO: Notificar al sistema de puntos que un enemigo fue eliminado
	if PointSystem:
		PointSystem.enemy_killed()
	
	animation_player.play("dead")
	
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func obtener_vida_actual() -> float:
	return vida_actual

func obtener_vida_maxima() -> float:
	return vida_maxima

func esta_vivo() -> bool:
	return not esta_muerto

func curar(cantidad: float):
	if esta_muerto:
		return
	
	vida_actual = min(vida_actual + cantidad, vida_maxima)

# ===== SISTEMA DE IDLE =====

func iniciar_idle():
	if haciendo_idle or esta_atacando or recibiendo_dano or esta_muerto:
		return
	
	haciendo_idle = true
	movimiento.x = 0
	tiempo_idle_restante = randf_range(duracion_idle_min, duracion_idle_max)
	
	if animation_player.has_animation("idle"):
		animation_player.play("idle")
	else:
		animation_player.pause()
	
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func terminar_idle():
	if not haciendo_idle:
		return
	
	haciendo_idle = false
	tiempo_idle_restante = 0.0
	
	if animation_player.has_animation("idle"):
		animation_player.play("walk")
	else:
		animation_player.play()

func forzar_terminar_idle():
	if haciendo_idle:
		terminar_idle()

# ===== SISTEMA PARA RECIBIR DAÑO DE ATAQUES DEL JUGADOR =====

func crear_detector_ataques_automatico():
	detector_ataques = Area2D.new()
	detector_ataques.name = "DetectorAtaques"
	add_child(detector_ataques)
	
	var collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = Vector2(80, 100)
	collision_shape.shape = rectangle_shape
	detector_ataques.add_child(collision_shape)
	
	detector_ataques.body_entered.connect(_on_ataque_jugador_detectado)
	detector_ataques.area_entered.connect(_on_area_ataque_detectada)

func _on_area_ataque_detectada(area: Area2D):
	var jugador = area.get_parent()
	if not jugador or not jugador.is_in_group("player"):
		return
	
	var esta_atacando_jugador = false
	if jugador.has_method("esta_atacando"):
		esta_atacando_jugador = jugador.esta_atacando()
	elif "atacando" in jugador:
		esta_atacando_jugador = jugador.atacando
	
	if not esta_atacando_jugador:
		return
	
	var animacion_actual = ""
	if "animation_player" in jugador:
		animacion_actual = jugador.animation_player.current_animation
	
	aplicar_dano_por_ataque(animacion_actual)

func _on_ataque_jugador_detectado(body: Node2D):
	if not body.is_in_group("player"):
		return
	
	var esta_atacando_jugador = false
	if body.has_method("esta_atacando"):
		esta_atacando_jugador = body.esta_atacando()
	elif "atacando" in body:
		esta_atacando_jugador = body.atacando
	
	if not esta_atacando_jugador:
		return
	
	var animacion_actual = ""
	if "animation_player" in body:
		animacion_actual = body.animation_player.current_animation
	
	aplicar_dano_por_ataque(animacion_actual)

func aplicar_dano_por_ataque(tipo_ataque: String):
	if esta_muerto or esta_invulnerable:
		return
	
	var cantidad_dano = 0.0
	
	match tipo_ataque:
		"ataque1":
			cantidad_dano = daño_por_ataque_jugador.get("ataque1", 10.0)
		"ataque2":
			cantidad_dano = daño_por_ataque_jugador.get("ataque2", 15.0)
		"ataque3":
			cantidad_dano = daño_por_ataque_jugador.get("ataque3", 15.0)
		"ataque4":
			cantidad_dano = daño_por_ataque_jugador.get("ataque4", 40.0)
		"especial2":
			cantidad_dano = daño_por_ataque_jugador.get("especial2", 30.0)
		"especialdoble":
			cantidad_dano = daño_por_ataque_jugador.get("especialdoble", 20.0)
		_:
			return
	
	recibir_daño(cantidad_dano)

func configurar_dano_ataque(tipo_ataque: String, nuevo_dano: float):
	if tipo_ataque in daño_por_ataque_jugador:
		daño_por_ataque_jugador[tipo_ataque] = nuevo_dano

func obtener_dano_ataque(tipo_ataque: String) -> float:
	return daño_por_ataque_jugador.get(tipo_ataque, 0.0)
