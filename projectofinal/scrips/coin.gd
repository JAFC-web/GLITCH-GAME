extends Area2D

# Señal para comunicar que la moneda fue recolectada
signal coin_collected(points)

# Puntos que otorga esta moneda
@export var coin_value: int = 5  # Cambiado a 5 según tu solicitud

# Efecto de sonido (opcional)
@onready var audio_player = $AudioStreamPlayer
# Animación de recolección (opcional)
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

func _ready():
	# Conectar la señal de cuando algo entra al área
	body_entered.connect(_on_body_entered)
	
	# Opcional: Animación de flotación
	create_floating_animation()

func _on_body_entered(body):
	# Verificar si es el jugador
	if body.is_in_group("player") or body.name == "Player":
		collect_coin(body)

func collect_coin(player):
	# Emitir señal con los puntos ganados (mantenida para compatibilidad)
	coin_collected.emit(coin_value)
	
	# NUEVO: Notificar al sistema de puntos
	if PointSystem:
		PointSystem.coin_collected()
	else:
		print("ADVERTENCIA: PointSystem no encontrado")
	
	# Desactivar colisión para evitar múltiples recolecciones
	collision.disabled = true
	
	# Opcional: Efecto visual antes de desaparecer
	play_collection_effect()
	
	# Reproducir sonido y esperar a que termine
	if audio_player and audio_player.stream:
		audio_player.play()
		# Esperar a que termine el sonido O el efecto visual
		var sound_length = audio_player.stream.get_length()
		await get_tree().create_timer(max(sound_length, 0.3)).timeout
	else:
		# Si no hay sonido, solo esperar el efecto visual
		await get_tree().create_timer(0.3).timeout
	
	queue_free()

func play_collection_effect():
	# Efecto de escala y fade out
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)

func create_floating_animation():
	# Animación sutil de flotación
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", position.y - 5, 1.0)
	tween.tween_property(self, "position:y", position.y + 5, 1.0)

# Función para cambiar el valor de la moneda dinámicamente
func set_coin_value(new_value: int):
	coin_value = new_value

# Función para obtener información de la moneda
func get_coin_info() -> Dictionary:
	return {
		"value": coin_value,
		"collected": collision.disabled
	}
