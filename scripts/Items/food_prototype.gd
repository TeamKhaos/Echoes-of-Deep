extends Node
class_name FoodPrototype

# Propiedades del ítem de comida
var _properties = {
	"name": "Food",
	"image": "res://resources/images/food.png",
	"type": "consumable",
	"hunger_restore": 30.0,  # Cuánto hambre restaura
	"health_restore": 15.0,   # Cuánta vida restaura (solo si hambre está al máximo)
	"description": "Restores hunger"
}

func get_property(key: String):
	return _properties.get(key, null)

func has_property(key: String) -> bool:
	return _properties.has(key)
