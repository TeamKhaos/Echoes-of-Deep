extends Control

# 🔹 Retícula (Crosshair)
@onready var crosshair = $Crosshair
@export var normal_crosshair: Texture2D = preload("res://resources/images/cruz.png")
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

# Velocidad de descenso por segundo
@export var hunger_decay_rate: float = 1.0

func _process(delta: float):
	_update_hunger(delta)
	_process_sanity(delta)

# 🍗 LÓGICA PRINCIPAL: Reducir hambre constantemente y actualizar barra
func _update_hunger(delta: float):
	hunger_value -= hunger_decay_rate * delta
	hunger_value = clamp(hunger_value, hunger_min, hunger_max)

	if hunger_bar:
		hunger_bar.value = hunger_value
	
	# 🔥 Activar overlay de advertencia cuando hambre es baja
	_update_hunger_warning(hunger_value <= hunger_warning_threshold)


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


# 🍎 FUNCIÓN PÚBLICA: Restaurar hambre (llamada desde ítems consumibles)
func restore_hunger(amount: float):
	hunger_value = clamp(hunger_value + amount, hunger_min, hunger_max)
	if hunger_bar:
		hunger_bar.value = hunger_value
	_update_hunger_warning(hunger_value <= hunger_warning_threshold)


# ❤️ FUNCIÓN PÚBLICA: Restaurar vida (llamada desde ítems consumibles)
func restore_health(amount: float):
	if not health_bar:
		return
	
	var new_value = clamp(health_bar.value + amount, 0, health_bar.max_value)
	health_bar.value = new_value


# ===============================
# 🧠 CORDURA / SANIDAD MENTAL
# ===============================

@onready var sanity_bar = $CorduraTexture/Cordura

var sanity_value: float = 100.0
var sanity_min: float = 0.0
var sanity_max: float = 100.0

# Velocidades de cambio
@export var sanity_decay_rate_dark: float = 2.0     # Pierde 2 puntos/seg en oscuridad
@export var sanity_restore_rate_light: float = 5.0  # Gana 5 puntos/seg cerca de luz
@export var sanity_warning_threshold: float = 30.0

var is_near_light: bool = false
var _sanity_warning_active: bool = false
var _sanity_tween: Tween = null

# 🧠 LÓGICA PRINCIPAL: Cambiar cordura según iluminación
func _process_sanity(delta: float):
	if is_near_light:
		# Restaurar cordura cerca de luz
		sanity_value += sanity_restore_rate_light * delta
	else:
		# Perder cordura en oscuridad
		sanity_value -= sanity_decay_rate_dark * delta
	
	sanity_value = clamp(sanity_value, sanity_min, sanity_max)
	
	if sanity_bar:
		sanity_bar.value = sanity_value
	
	# Activar efectos visuales si cordura es baja
	_update_sanity_warning(sanity_value <= sanity_warning_threshold)

# 💡 FUNCIÓN PÚBLICA: Actualizar estado de iluminación (llamada desde detector de luz)
func set_near_light(near_light: bool):
	is_near_light = near_light

# 🧠 EFECTO VISUAL: Advertencia cuando cordura < 30 (implementar efectos aquí)
func _update_sanity_warning(is_low: bool):
	if _sanity_warning_active == is_low:
		return
	
	_sanity_warning_active = is_low
	
	# TODO: Implementar efectos visuales para cordura baja
	# - Distorsión de pantalla
	# - Viñeta oscura
	# - Efectos de sonido
	# - Alucinaciones visuales

# 🧠 FUNCIÓN PÚBLICA: Restaurar cordura manualmente
func restore_sanity(amount: float):
	sanity_value = clamp(sanity_value + amount, sanity_min, sanity_max)
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
