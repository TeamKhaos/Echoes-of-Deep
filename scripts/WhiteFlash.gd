extends ColorRect
# Script para el destello blanco que aparece al llegar al final

func _ready():
	# Configurar el ColorRect para cubrir toda la pantalla
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	
	# Color blanco puro
	color = Color(1, 1, 1, 1)
	
	# Asegurarse de que esté encima de todo
	z_index = 100
	
	# Iniciar animación de fade out
	_animate_fade_out()

func _animate_fade_out():
	# Crear Tween para fade out suave
	var tween = create_tween()
	
	# Mantener blanco completo por 0.3 segundos
	tween.tween_interval(0.3)
	
	# Fade out en 0.7 segundos
	tween.tween_property(self, "modulate:a", 0.0, 0.7)
	
	# Eliminar este nodo cuando termine
	await tween.finished
	queue_free()
