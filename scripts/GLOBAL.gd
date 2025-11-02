extends Node
var look_sensitivity : float = 0.1
var events_on_story : Array[String]

func add_event_on_story(event : String, callable : Callable = func(): pass):
	events_on_story.append(event)
	callable.call_deferred()

func change_master_volume(new_vol : float, interpolation_time : float = 0):
	var tween : Tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(set_volume, 0.0, new_vol, interpolation_time)
	

func set_volume(new_volume : float):
	AudioServer.set_bus_volume_db(3, new_volume)
