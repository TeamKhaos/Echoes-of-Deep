extends Control

@onready var game_label: Label = $CenterContainer/Panel/MarginContainer/Button_Container/GameLabel
@onready var quit_button: Button = $CenterContainer/Panel/MarginContainer/Button_Container/Quit_Button

var is_open : bool = false

func _ready() -> void:
	GLOBAL.PauseRef = self

func _unhandled_input(event):
	if event.is_action_pressed("Menu"):
		pause_menu()

## Open / Close
func pause_menu():
	match is_open:
		true:
			close()
		false:
			open()

func open():
	#Show Pause Menu
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_open = true
	get_tree().paused = true

func close():
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	is_open = false
	get_tree().paused = false


## Buttons
func _on_quit_button_pressed() -> void:
	get_tree().quit()
