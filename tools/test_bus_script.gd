extends Node
func _ready():
    print("bus_count=", AudioServer.bus_count)
    for i in range(AudioServer.bus_count):
        print("bus", i, "=", AudioServer.get_bus_name(i))
    get_tree().quit()
