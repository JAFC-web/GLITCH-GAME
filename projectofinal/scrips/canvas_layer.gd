extends CanvasLayer

# Referencias al boss y UI
@export var boss_node: NodePath
@onready var boss = get_node(boss_node)
@onready var texture_progress: TextureProgressBar = $TextureProgressBar

# Variables para detectar cambios
var vida_anterior_boss: float = -1.0

func _ready():
	# Esperar un frame para asegurar que todo esté inicializado
	await get_tree().process_frame
	
	# Verificar que el boss esté asignado
	if not boss and boss_node != NodePath():
		boss = get_node(boss_node)
	
	if not boss:
		return
	
	# Conectar a las señales del boss
	if boss.has_signal("boss_muerto"):
		boss.boss_muerto.connect(_on_boss_muerto)
	
	if boss.has_signal("jugador_dañado"):
		boss.jugador_dañado.connect(_on_jugador_dañado)
	
	# Inicializar la barra de vida
	_inicializar_barra_vida()

func _process(delta):
	# Verificar que el boss esté disponible
	if not boss:
		return
	
	# Actualizar la barra constantemente
	_actualizar_barra_vida()
	
	# Detectar cambios de vida manualmente (sistema principal)
	_detectar_cambio_vida()

# Inicializar la barra de vida del boss
func _inicializar_barra_vida():
	if not boss or not texture_progress:
		return
	
	var vida_maxima = boss.get_vida_maxima()
	var vida_actual = boss.get_vida_actual()
	
	# Configurar la barra de progreso
	texture_progress.max_value = vida_maxima
	texture_progress.value = vida_actual
	
	# Almacenar vida inicial
	vida_anterior_boss = vida_actual

# Actualizar la barra de vida principal
func _actualizar_barra_vida():
	if not boss or not texture_progress:
		return
	
	var vida_actual = boss.get_vida_actual()
	var vida_maxima = boss.get_vida_maxima()
	
	texture_progress.max_value = vida_maxima
	texture_progress.value = vida_actual

# Función llamada cuando cambia la vida del boss (por señal)
func _on_vida_boss_cambiada(vida_nueva: float, vida_maxima: float):
	_actualizar_barra_vida_con_valores(vida_nueva, vida_maxima)
	_efecto_daño_boss()

# Función llamada cuando el boss recibe daño (por señal)
func _on_boss_recibio_daño(daño: float, vida_restante: float):
	_actualizar_barra_vida()
	_efecto_daño_boss()

# Detectar cambios de vida manualmente (respaldo)
func _detectar_cambio_vida():
	if not boss:
		return
	
	var vida_actual = boss.get_vida_actual()
	
	# Inicializar vida anterior si es la primera vez
	if vida_anterior_boss < 0:
		vida_anterior_boss = vida_actual
		return
	
	# Detectar cualquier cambio en la vida
	if abs(vida_actual - vida_anterior_boss) > 0.01:  # Usar margen para flotantes
		if vida_actual < vida_anterior_boss:
			_efecto_daño_boss()
		
		# Actualizar la barra inmediatamente
		_actualizar_barra_vida()
		
		# Actualizar vida anterior
		vida_anterior_boss = vida_actual

# Actualizar la barra con valores específicos
func _actualizar_barra_vida_con_valores(vida_actual: float, vida_maxima: float):
	if not texture_progress:
		return
	
	texture_progress.max_value = vida_maxima
	texture_progress.value = clamp(vida_actual, 0, vida_maxima)
	texture_progress.queue_redraw()

# Efecto visual cuando el boss recibe daño
func _efecto_daño_boss():
	if not texture_progress:
		return
	
	var color_original = texture_progress.modulate
	var tween = create_tween()
	tween.tween_property(texture_progress, "modulate:a", 0.3, 0.08)
	tween.tween_property(texture_progress, "modulate:a", 1.0, 0.08)
	tween.tween_property(texture_progress, "modulate:a", 0.3, 0.08)
	tween.tween_property(texture_progress, "modulate:a", 1.0, 0.08)
	tween.tween_property(texture_progress, "modulate", Color.WHITE, 0.05)
	tween.tween_property(texture_progress, "modulate", color_original, 0.15)

# Función llamada cuando el boss muere
func _on_boss_muerto():
	if texture_progress:
		var tween = create_tween()
		tween.tween_property(texture_progress, "modulate", Color.RED, 0.5)
		tween.tween_property(texture_progress, "modulate:a", 0.0, 1.0)

# Función llamada cuando el boss daña al jugador
func _on_jugador_dañado(daño: float):
	_efecto_ataque_boss()

# Efecto visual cuando el boss ataca
func _efecto_ataque_boss():
	if not texture_progress:
		return
	
	var color_original = texture_progress.modulate
	var tween = create_tween()
	tween.tween_property(texture_progress, "modulate", Color.WHITE, 0.1)
	tween.tween_property(texture_progress, "modulate", color_original, 0.2)

# Funciones de utilidad
func obtener_porcentaje_vida_boss() -> float:
	if boss:
		return boss.get_vida_porcentaje()
	return 0.0

func boss_esta_vivo() -> bool:
	if boss:
		return boss.esta_vivo()
	return false

func obtener_vida_actual_boss() -> float:
	if boss:
		return boss.get_vida_actual()
	return 0.0

func obtener_vida_maxima_boss() -> float:
	if boss:
		return boss.get_vida_maxima()
	return 0.0

func mostrar_barra_boss():
	if texture_progress:
		texture_progress.visible = true
		texture_progress.modulate.a = 1.0

func ocultar_barra_boss():
	if texture_progress:
		texture_progress.visible = false
