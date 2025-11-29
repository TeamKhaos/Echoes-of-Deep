# EndCredits.gd
# Pantalla negra con "Gracias por jugar"
extends Control

func _ready():
	# Configurar para cubrir toda la pantalla
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	
	# Crear fondo negro
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 1)
	background.anchor_left = 0
	background.anchor_top = 0
	background.anchor_right = 1
	background.anchor_bottom = 1
	add_child(background)
	
	# Crear texto "Gracias por jugar"
	var label = Label.new()
	label.text = "Thanks for playing"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0
	label.anchor_top = 0
	label.anchor_right = 1
	label.anchor_bottom = 1
	
	# Configurar fuente grande y blanca
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	
	add_child(label)
	
	# Z-index alto para estar encima de todo
	z_index = 101
	
	# Animación de fade in
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0)
	
	print("📜 Mostrando pantalla de créditos")
