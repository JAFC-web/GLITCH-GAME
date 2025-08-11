extends Node2D

func _ready() -> void:
	# Configurar modos de procesamiento
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Popup.process_mode = Node.PROCESS_MODE_ALWAYS
	$Popup/AudioStreamPlayer.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Asegurarse de que el popup esté oculto y el juego despausado al inicio
	$Popup.visible = false
	get_tree().paused = false
	
	# Desactivar el comportamiento automático de ocultar el popup al hacer clic fuera
	if $Popup is Popup:
		$Popup.exclusive = true
	
	# Conectar señal del botón de reanudar (si existe)
	if $Popup.has_node("ResumeButton"):
		$Popup/ResumeButton.pressed.connect(_on_resume_button_pressed)
	
	print("Inicio - Popup visible: ", $Popup.visible, " | Juego pausado: ", get_tree().paused)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pausar"):
		# Alternar visibilidad del popup
		$Popup.visible = !$Popup.visible
		
		# Sincronizar pausa con visibilidad del popup
		get_tree().paused = $Popup.visible
		
		# Reproducir sonido
		$Popup/AudioStreamPlayer.play()
		
		# Depuración
		print("Tras input - Popup visible: ", $Popup.visible, " | Juego pausado: ", get_tree().paused)

func _on_resume_button_pressed() -> void:
	# Ocultar popup y despausar el juego
	$Popup.visible = false
	get_tree().paused = false
	$Popup/AudioStreamPlayer.play()
	print("Tras botón - Popup visible: ", $Popup.visible, " | Juego pausado: ", get_tree().paused)

func _process(delta: float) -> void:
	# Verificar si el estado de pausa está sincronizado con el popup
	if get_tree().paused != $Popup.visible:
		print("¡Desincronización! Popup visible: ", $Popup.visible, " | Juego pausado: ", get_tree().paused)
		# Forzar sincronización
		get_tree().paused = $Popup.visible
		print("Forzando sincronización - Juego pausado: ", get_tree().paused)
