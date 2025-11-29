extends Control

# 🔹 Retícula (Crosshair)
@onready var crosshair = $Crosshair
@export var normal_crosshair: Texture2D = preload("res://resources/images/Cruz.png")
@export var interact_crosshair: Texture2D = preload("res://resources/images/SecObj.png")

# 🔹 Inventario
@onready var hud_slot_1 = $Item1/Icon
@onready var hud_slot_2 = $Item2/Icon
@export var default_icon: Texture2D = preload("res://resources/images/food.png")

# 🔹 Texto de interacción
@onready var interact_label = $InteractLabel

# 🎙️ Control del micrófono
@onready var microphone_texture_off = $"Microphone/Microphone OFF"
@onready var microphone_texture_on = $"Microphone/Microphone ON"

# 🧠 Efectos visuales de cordura
@onready var sanity_effects_overlay: ColorRect = null
var sanity_shader_material: ShaderMaterial = null

# 🔹 Variables internas
var inventory_ref: Node = null
var _is_interact_mode = false
var _is_prompt_visible := false

# 🔹 Tweens separados para evitar conflictos
var _tween_crosshair: Tween
var _tween_prompt: Tween

# 🔥 Overlay de bajo hambre
@onready var low_hunger_overlay = $CanvasLayer/ColorRect

func _ready():
	# 🧠 Inicializar efectos de cordura
	_ready_sanity_effects()
	# Inicializar el overlay invisible al inicio
	if low_hunger_overlay:
		low_hunger_overlay.modulate = Color(1, 1, 1, 0)  # Totalmente transparente
		low_hunger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Inicializar estado del micrófono
	if microphone_texture_off:
		microphone_texture_off.visible = true
	if microphone_texture_on:
		microphone_texture_on.visible = false
		


# ===============================
# 🧭 INVENTARIO
# ===============================
func set_inventory(inv: Node):
	if not inv:
		push_warning("⚠️ Inventario inválido recibido en HUD")
		return

	inventory_ref = inv
	if not inv.has_method("get_items"):
		push_error("❌ El nodo de inventario no tiene el método get_items()")
		return

	_connect_signal_safe(inv, "item_added", "_on_item_changed")
	_connect_signal_safe(inv, "item_removed", "_on_item_changed")
	_connect_signal_safe(inv, "item_moved", "_on_item_changed")
	_connect_signal_safe(inv, "item_property_changed", "_on_item_changed")

	_refresh_hud()


func _connect_signal_safe(target: Object, signal_name: String, method_name: String):
	if not target.is_connected(signal_name, Callable(self, method_name)):
		target.connect(signal_name, Callable(self, method_name))


func _on_item_changed(_item = null, _extra = null):
	_refresh_hud()


func _refresh_hud():
	if not inventory_ref:
		return

	var items = inventory_ref.get_items()

	hud_slot_1.texture = _get_item_icon(items, 0)
	hud_slot_2.texture = _get_item_icon(items, 1)


func _get_item_icon(items: Array, index: int) -> Texture2D:
	if items.size() <= index:
		return null

	var item = items[index]
	if not item or not item.has_method("get_prototype"):
		return default_icon

	var proto = item.get_prototype()
	if not proto:
		return default_icon

	var props = null
	if proto.has_method("get"):
		var candidate = proto.get("_properties")
		if typeof(candidate) == TYPE_DICTIONARY:
			props = candidate
	elif "_properties" in proto:
		props = proto["_properties"]

	if typeof(props) == TYPE_DICTIONARY and props.has("image"):
		var icon_path = props["image"]
		if icon_path != "":
			return load(icon_path)

	return default_icon


# ===============================
# 🎯 CROSSHAIR (retícula)
# ===============================
func set_crosshair_interact(active: bool):
	if _is_interact_mode == active:
		return
	_is_interact_mode = active

	if _tween_crosshair:
		_tween_crosshair.kill()

	_tween_crosshair = create_tween()
	_tween_crosshair.set_trans(Tween.TRANS_SINE)
	_tween_crosshair.set_ease(Tween.EASE_OUT)

	if active:
		_tween_crosshair.tween_property(crosshair, "scale", Vector2(1.3, 1.3), 0.15)
		crosshair.texture = interact_crosshair
	else:
		_tween_crosshair.tween_property(crosshair, "scale", Vector2(1, 1), 0.15)
		crosshair.texture = normal_crosshair


# ===============================
# 💬 TEXTO DE INTERACCIÓN
# ===============================
func show_interact_prompt(active: bool):
	if _is_prompt_visible == active:
		return
	_is_prompt_visible = active

	if _tween_prompt:
		_tween_prompt.kill()

	_tween_prompt = create_tween()
	_tween_prompt.set_trans(Tween.TRANS_SINE)
	_tween_prompt.set_ease(Tween.EASE_OUT)

	if active:
		interact_label.visible = true
		interact_label.modulate.a = 0
		_tween_prompt.tween_property(interact_label, "modulate:a", 1.0, 0.2)
	else:
		_tween_prompt.tween_property(interact_label, "modulate:a", 0.0, 0.2)
		_tween_prompt.tween_callback(Callable(self, "_hide_prompt"))


func _hide_prompt():
	interact_label.visible = false
	
# ===============================
# ❤️ Barra de Vida
# ===============================

@onready var health_bar = $VidaTexture/Vida

func set_health(value: float):
	if health_bar:
		health_bar.value = clamp(value, 0, health_bar.max_value)


# ===============================
# 🍗 HAMBRE
# ===============================

@onready var hunger_bar = $HambreTexture/Hambre

var hunger_value: float = 100.0
var hunger_min: float = 0.0
var hunger_max: float = 100.0

var _low_hunger_tween: Tween = null
var hunger_warning_threshold := 20.0
var hunger_warning_active := false

# 🚨 Daño por hambre ### NUEVO
@export var damage_per_second_at_zero_hunger: float = 2.0 
var is_starving: bool = false # Estado de inanición ### NUEVO
var _starvation_damage_accumulator: float = 0.0 # Acumulador para el daño por hambre

# Velocidad de descenso por segundo
@export var hunger_decay_rate: float = 0.95

func _process(delta: float):
	_update_hunger(delta)
	_process_sanity(delta)
	
	# 🚨 NUEVA LÓGICA: Aplicar daño por inanición si el hambre está en 0 ### NUEVO
	if is_starving:
		apply_starvation_damage(delta)


# 🍗 LÓGICA PRINCIPAL: Reducir hambre constantemente y actualizar barra
# ### MODIFICADO: Se agregó la lógica de 'is_starving'
func _update_hunger(delta: float):
	hunger_value -= hunger_decay_rate * delta
	hunger_value = clamp(hunger_value, hunger_min, hunger_max)

	if hunger_bar:
		hunger_bar.value = hunger_value
	
	# 🔥 Activar overlay de advertencia cuando hambre es baja
	_update_hunger_warning(hunger_value <= hunger_warning_threshold)
	
	# 🚨 NUEVA LÓGICA: Verificar si el hambre ha llegado a cero ### NUEVO
	is_starving = (hunger_value <= hunger_min)


# 🔥 EFECTO VISUAL: Parpadeo rojo cuando hambre < 20
func _update_hunger_warning(is_low: bool):
	if hunger_warning_active == is_low:
		return
	
	hunger_warning_active = is_low
	
	if _low_hunger_tween:
		_low_hunger_tween.kill()
	
	if is_low:
		# Crear loop infinito de parpadeo
		_low_hunger_tween = create_tween()
		_low_hunger_tween.set_loops(-1)
		_low_hunger_tween.tween_property(low_hunger_overlay,
			"modulate:a", 0.25, 0.7)
		_low_hunger_tween.tween_property(low_hunger_overlay,
			"modulate:a", 0.05, 0.7)
	else:
		# Fade out suave
		_low_hunger_tween = create_tween()
		_low_hunger_tween.tween_property(low_hunger_overlay,
			"modulate:a", 0.0, 0.4)


# 🚨 NUEVA FUNCIÓN: Aplica daño al jugador si está en inanición
func apply_starvation_damage(delta: float):
	if GLOBAL.PlayerRef and GLOBAL.PlayerRef.has_method("take_damage"):
		_starvation_damage_accumulator += damage_per_second_at_zero_hunger * delta
		
		if _starvation_damage_accumulator >= 1.0:
			var damage_to_apply = floori(_starvation_damage_accumulator)
			GLOBAL.PlayerRef.take_damage(damage_to_apply)
			_starvation_damage_accumulator -= damage_to_apply


# 🍎 FUNCIÓN PÚBLICA: Restaurar hambre (llamada desde ítems consumibles)
func restore_hunger(amount: float):
	hunger_value = clamp(hunger_value + amount, hunger_min, hunger_max)
	if hunger_bar:
		hunger_bar.value = hunger_value
	_update_hunger_warning(hunger_value <= hunger_warning_threshold)


# ❤️ FUNCIÓN PÚBLICA: Restaurar vida (llamada desde ítems consumibles)
# NOTA: Esta función se usa ahora también para el daño por inanición.
func restore_health(amount: float):
	if not health_bar:
		return
	
	var new_value = clamp(health_bar.value + amount, 0, health_bar.max_value)
	health_bar.value = new_value


# ===============================
# 🧠 CORDURA / SANIDAD MENTAL - VERSIÓN MEJORADA
# ===============================

@onready var sanity_bar = $CorduraTexture/Cordura

var sanity_value: float = 100.0
var sanity_min: float = 0.0
var sanity_max: float = 100.0

# 🔧 Velocidades ajustadas (MÁS LENTAS)
@export var sanity_decay_rate_dark: float = 0.5      # Pierde 0.5 puntos/seg en oscuridad (era 2.0)
@export var sanity_restore_rate_light: float = 3.0  # Gana 3 puntos/seg cerca de luz (era 5.0)
@export var sanity_warning_threshold: float = 20.0  # Umbral de advertencia en 20%

# 🎨 Umbrales de efectos visuales
@export var sanity_critical_threshold: float = 20.0  # < 20% = efectos críticos
@export var sanity_medium_threshold: float = 40.0    # < 40% = efectos moderados
@export var sanity_low_threshold: float = 60.0       # < 60% = efectos leves

var is_near_light: bool = false
var _sanity_warning_active: bool = false
var _sanity_tween: Tween = null

# Variables para efectos de sonido (opcional)
var _insanity_sound_timer: float = 0.0
var _whisper_cooldown: float = 0.0


# ===============================
# FUNCIÓN _ready() - AGREGAR ESTA PARTE
# ===============================

func _ready_sanity_effects():
	"""Llamar esta función desde tu _ready() existente"""
	_setup_sanity_overlay()


func _setup_sanity_overlay():
	"""Crea el overlay de efectos visuales para la cordura"""
	# Buscar o crear el CanvasLayer para efectos
	var canvas_layer = get_node_or_null("SanityEffectsLayer")
	if not canvas_layer:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "SanityEffectsLayer"
		canvas_layer.layer = 99  # Debajo del Game Over (100)
		add_child(canvas_layer)
	
	# Crear el overlay con shader
	sanity_effects_overlay = ColorRect.new()
	sanity_effects_overlay.name = "SanityEffectsOverlay"
	sanity_effects_overlay.anchors_preset = Control.PRESET_FULL_RECT
	sanity_effects_overlay.anchor_right = 1.0
	sanity_effects_overlay.anchor_bottom = 1.0
	sanity_effects_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sanity_effects_overlay.color = Color(1, 1, 1, 1)
	
	# Cargar y aplicar el shader
	var shader = load("res://resources/shaders/sanity_effects.gdshader")
	if shader:
		sanity_shader_material = ShaderMaterial.new()
		sanity_shader_material.shader = shader
		sanity_effects_overlay.material = sanity_shader_material
		
		# Inicializar parámetros del shader
		_update_shader_params(1.0)  # Comenzar con cordura al 100%
	
	canvas_layer.add_child(sanity_effects_overlay)


# ===============================
# REEMPLAZAR _process_sanity() COMPLETO
# ===============================

func _process_sanity(delta: float):
	"""Lógica principal de cordura con efectos visuales progresivos"""
	
	# 1. Actualizar valor de cordura
	if is_near_light:
		sanity_value += sanity_restore_rate_light * delta
	else:
		sanity_value -= sanity_decay_rate_dark * delta
	
	sanity_value = clamp(sanity_value, sanity_min, sanity_max)
	
	# 2. Actualizar barra visual
	if sanity_bar:
		sanity_bar.value = sanity_value
	
	# 3. Calcular porcentaje normalizado (0.0 a 1.0)
	var sanity_percent = sanity_value / sanity_max
	
	# 4. Actualizar efectos visuales del shader
	_update_shader_params(sanity_percent)
	
	# 5. Activar advertencias según umbral
	_update_sanity_warning(sanity_value <= sanity_warning_threshold)
	
	# 6. Efectos de sonido opcionales (descomentar si tienes audio)
	# _process_sanity_audio(delta, sanity_percent)


# ===============================
# NUEVA FUNCIÓN: Actualizar parámetros del shader
# ===============================

func _update_shader_params(sanity_percent: float):
	"""Actualiza los efectos visuales según el nivel de cordura"""
	if not sanity_shader_material:
		return
	
	# Pasar el tiempo para animaciones
	sanity_shader_material.set_shader_parameter("time_value", Time.get_ticks_msec() / 1000.0)
	sanity_shader_material.set_shader_parameter("sanity_level", sanity_percent)
	
	# 🔴 CORDURA CRÍTICA (< 20%)
	if sanity_percent < 0.2:
		sanity_shader_material.set_shader_parameter("glitch_intensity", 0.8)
		sanity_shader_material.set_shader_parameter("desaturation", 0.6)
		sanity_shader_material.set_shader_parameter("vignette_strength", 0.9)
		sanity_shader_material.set_shader_parameter("barrel_distortion", 0.15)
		sanity_shader_material.set_shader_parameter("chromatic_aberration", 0.015)
		sanity_shader_material.set_shader_parameter("noise_intensity", 0.4)
	
	# 🟠 CORDURA BAJA (20% - 40%)
	elif sanity_percent < 0.4:
		var intensity = (0.4 - sanity_percent) / 0.2  # 0.0 a 1.0
		sanity_shader_material.set_shader_parameter("glitch_intensity", intensity * 0.5)
		sanity_shader_material.set_shader_parameter("desaturation", intensity * 0.4)
		sanity_shader_material.set_shader_parameter("vignette_strength", intensity * 0.6)
		sanity_shader_material.set_shader_parameter("barrel_distortion", intensity * 0.08)
		sanity_shader_material.set_shader_parameter("chromatic_aberration", intensity * 0.008)
		sanity_shader_material.set_shader_parameter("noise_intensity", intensity * 0.2)
	
	# 🟡 CORDURA MEDIA (40% - 60%)
	elif sanity_percent < 0.6:
		var intensity = (0.6 - sanity_percent) / 0.2  # 0.0 a 1.0
		sanity_shader_material.set_shader_parameter("glitch_intensity", 0.0)
		sanity_shader_material.set_shader_parameter("desaturation", intensity * 0.2)
		sanity_shader_material.set_shader_parameter("vignette_strength", intensity * 0.3)
		sanity_shader_material.set_shader_parameter("barrel_distortion", 0.0)
		sanity_shader_material.set_shader_parameter("chromatic_aberration", 0.0)
		sanity_shader_material.set_shader_parameter("noise_intensity", intensity * 0.05)
	
	# 🟢 CORDURA NORMAL (> 60%)
	else:
		sanity_shader_material.set_shader_parameter("glitch_intensity", 0.0)
		sanity_shader_material.set_shader_parameter("desaturation", 0.0)
		sanity_shader_material.set_shader_parameter("vignette_strength", 0.0)
		sanity_shader_material.set_shader_parameter("barrel_distortion", 0.0)
		sanity_shader_material.set_shader_parameter("chromatic_aberration", 0.0)
		sanity_shader_material.set_shader_parameter("noise_intensity", 0.0)


# ===============================
# REEMPLAZAR _update_sanity_warning()
# ===============================

func _update_sanity_warning(is_low: bool):
	"""Muestra advertencias cuando la cordura es crítica"""
	if _sanity_warning_active == is_low:
		return
	
	_sanity_warning_active = is_low
	
	if _sanity_tween:
		_sanity_tween.kill()
	
	if is_low:
		print("aw")
		# Opcional: reproducir sonido de advertencia
		# $SanityWarningSound.play()
	else:
		print("aw")


# ===============================
# FUNCIONES PÚBLICAS (mantener las existentes)
# ===============================

func set_near_light(near_light: bool):
	"""Actualiza si el jugador está cerca de una fuente de luz"""
	is_near_light = near_light


func restore_sanity(amount: float):
	"""Restaura cordura manualmente (por ítems, eventos, etc.)"""
	sanity_value = clamp(sanity_value + amount, sanity_min, sanity_max)
	if sanity_bar:
		sanity_bar.value = sanity_value


func damage_sanity(amount: float):
	sanity_value = clamp(sanity_value - amount, sanity_min, sanity_max)
	if sanity_bar:
		sanity_bar.value = sanity_value

# ===============================
# 🎙️ FUNCIONALIDAD DEL MICRÓFONO
# ===============================

func _on_microphone_toggled(active: bool):
	if microphone_texture_off:
		microphone_texture_off.visible = not active
	if microphone_texture_on:
		microphone_texture_on.visible = active
