extends Area2D

@onready var ani= $dummyv1/AnimationPlayer


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("p_punch"):
		_ani_change()
	pass # Replace with function body.

func _ani_change():
	var ani_current= ani.current_animation
	if ani_current == "hit":
		ani.play("idle")
		ani.play("hit")
	else:
		ani.play("hit")

func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"hit":
			ani.play("idle")
	pass # Replace with function body.
