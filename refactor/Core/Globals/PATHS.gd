extends Node

#GLOBAL VARIABLES
@onready var inventory : Inventory = get_tree().get_first_node_in_group("Inventory")
const GAME_SCENE = MENU["Game"]
const DEMO_SCENE = MENU["Demo"]

const INVENTORY = {
	"Cursor" : "res://Inventory/scenes/Cursor.tscn",
	"Slot" : "res://Inventory/scenes/InventorySlot.tscn",
}
const MENU = {
	"Demo" : "res://Inventory/scenes/Cursor.tscn" ,
	"Game" : "res://Inventory/scenes/InventorySlot.tscn",
}
