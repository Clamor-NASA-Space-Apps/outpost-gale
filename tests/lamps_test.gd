extends "res://addons/forge/test.gd"
## The helmet lights (player/suit_lamps.gd): godot --headless --path . --fixed-fps 60 -s tests/lamps_test.gd
## Outside they come on at night and go off by day, in a room they are off, the `lamp` key toggles them, a toggle holds
## until the next dusk, dawn or door, and a lesson's allow(["none"]) is the only lock on them.

var game: Node3D
var player: Node3D
var clock: Node
var said: Array = []


func _init() -> void:
	watchdog = 600.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	player = game.get_node("Player")
	clock = game.clock
	clock.pinned = true
	player.lamps_changed.connect(func(on: bool, auto: bool) -> void: said.append([on, auto]))
	var spawn: Dictionary = game.world.landmark("spawn")
	player.place(spawn.pos, spawn.yaw)

	await sky("noon")
	check(not player.lamps_on and player.state().player.lamps.auto, "by day outside the lights are off, on auto")
	check(player.lamps.spot.light_energy <= float(game.tuning.sky.light_floor) + 1e-6, "off is a glimmer, not a light (%.4f)" % player.lamps.spot.light_energy)
	said.clear()
	await sky("night")
	check(player.lamps_on and player.lamps.auto, "at night outside they come on by themselves")
	check(said == [[true, true]], "lamps_changed(on, auto) said so once (%s)" % [said])
	await frames(int(60 * float(game.tuning.lamps.fade_s)) + 5)
	check(is_equal_approx(player.lamps.spot.light_energy, float(game.tuning.lamps.energy)), "and fade up to full")

	await press()
	check(not player.lamps_on and not player.lamps.auto, "the key turns them off by hand")
	await frames(60)
	check(not player.lamps_on, "a hand toggle holds at night")
	await sky("noon")
	check(not player.lamps_on and player.lamps.auto, "dawn hands them back to auto")
	await press()
	check(player.lamps_on and not player.lamps.auto, "by day the key turns them on")
	await frames(60)
	check(player.lamps_on, "and they stay on by day")
	await sky("night")
	check(player.lamps_on and player.lamps.auto, "dusk takes over again")

	# a room: off at night, the key still works inside
	var id := "greenhouse"
	var item: Node3D = game.world.items[id]
	player.place(item.to_global(Vector3(0, 0.3, 0)), 0.0)
	await frames(5)
	check(player.room == id, "placed in the %s (room '%s')" % [id, player.room])
	check(not player.lamps_on and player.lamps.auto, "in a room at night they are off")
	await press()
	check(player.lamps_on, "the key lights them in a room too")
	player.place(spawn.pos, spawn.yaw)
	await frames(5)
	check(player.lamps_on and player.lamps.auto, "back outside at night they are on, on auto")

	# a lesson's lock
	player.allow(["move"])
	await press()
	check(not player.lamps_on, "a lesson that allows only walking still lets the key through")
	player.allow(["none"])
	await press()
	check(not player.lamps_on, "allow([\"none\"]) blocks it")
	player.allow([])
	await press()
	check(player.lamps_on, "unlocked, the key works again")
	return true


func sky(phase: String) -> void:
	clock.jump(phase)
	await frames(3)


func press() -> void:
	action(&"lamp", true)
	await frames(2)
	action(&"lamp", false)
	await frames(2)

