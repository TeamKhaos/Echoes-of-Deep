extends Control

@onready var hud_slot_1 = $Item1/Icon
@onready var hud_slot_2 = $Item2/Icon
@export var default_icon: Texture2D = preload("res://resources/images/food.png")

func _ready():
	hud_slot_1.texture = default_icon
	hud_slot_2.texture = null

func set_inventory(inv: Inventory):
	if not inv:
		push_warning("⚠️ Inventario inválido recibido en HUD")
		return

	var items = inv.get_items()
	print("🔹 Total de ítems en inventario (HUD):", items.size())

	# SLOT 1
	if items.size() > 0:
		var proto = items[0].get_prototype()
		var icon_path = ""

		if proto:
			print("🧩 Prototype detectado:", proto)

			# Intentamos acceder directamente a _properties
			var props = null
			if "_properties" in proto:
				props = proto["_properties"]
			elif proto.has_method("get") and proto.get("_properties") != null:
				props = proto.get("_properties")

			if typeof(props) == TYPE_DICTIONARY:
				print("📦 _properties encontrados:", props)
				if props.has("image"):
					icon_path = props["image"]
					print("🎨 Icon path encontrado:", icon_path)
				else:
					print("⚠️ _properties no contiene 'image'")
			else:
				print("⚠️ _properties no accesible o no es diccionario:", props)
		else:
			print("⚠️ No se obtuvo prototype del ítem")

		hud_slot_1.texture = load(icon_path) if icon_path != "" else default_icon
	else:
		hud_slot_1.texture = null


	# SLOT 2
	if items.size() > 1:
		var proto = items[1].get_prototype()
		var icon_path = ""

		if proto:
			print("🧩 Prototype detectado:", proto)

			# Intentamos acceder directamente a _properties
			var props = null
			if "_properties" in proto:
				props = proto["_properties"]
			elif proto.has_method("get") and proto.get("_properties") != null:
				props = proto.get("_properties")

			if typeof(props) == TYPE_DICTIONARY:
				print("📦 _properties encontrados:", props)
				if props.has("image"):
					icon_path = props["image"]
					print("🎨 Icon path encontrado:", icon_path)
				else:
					print("⚠️ _properties no contiene 'image'")
			else:
				print("⚠️ _properties no accesible o no es diccionario:", props)
		else:
			print("⚠️ No se obtuvo prototype del ítem")

		hud_slot_2.texture = load(icon_path) if icon_path != "" else default_icon
	else:
		hud_slot_2.texture = null
