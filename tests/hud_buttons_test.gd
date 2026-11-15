extends "res://addons/forge/test.gd"
## The use prompt and the HUD's top-right buttons, after the 15 Nov playtest: the prompt sits low in the middle and
## big enough to learn E from (it was small in the bottom right corner); the settings gear is gone from a keyboard's
## HUD (Esc opens settings); the book and the "?" each carry their key, and that key works, because in play the
## mouse turns the view and a click never reaches them. The morning note is calm and kid-worded.
##   godot --headless --path . --fixed-fps 60 -s tests/hud_buttons_test.gd
## Under xvfb-run (no --headless) it also saves the HUD with the prompt up to user://hud_prompt.png.

const OLD_H := 50.0  # the prompt with its hold ring, canvas px, at HEAD on 15 Nov (theme sizes, before this change)
const SOURCES := "res://ui/components/sources_card.tscn"

var game: Node3D
var hud: Control


func _init() -> void:
	watchdog = 400.0


func play() -> bool:
	game = load("res://sandbox/sandbox.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	for i in 600:
		if not game.busy():
			break
		await process_frame
	hud = game.hud
	await buttons()
	await prompt()
	words()
	return true


func buttons() -> void:
	check(not game.settings.gear.is_visible_in_tree(), "no settings gear on a keyboard's HUD")
	check(hud.gear_slot.get_global_rect().size.x > 0.0, "the gear's place still holds the book and the ? off the compass")
	action(&"settings")
	action(&"settings", false)
	await frames(2)
	check(game.settings.is_open(), "Esc opens the settings")
	action(&"settings")
	action(&"settings", false)
	await frames(2)
	check(not game.settings.is_open(), "and Esc closes them")
	for pair: Array in [[hud.book_button, "handbook"], [hud.source_button, "sources"]]:
		var b: Button = pair[0]
		var cap: Control = b.get_node_or_null("Key")
		var k: Key = (InputMap.action_get_events(pair[1])[0] as InputEventKey).physical_keycode
		if check(cap != null and cap.is_visible_in_tree(), "%s carries a key cap" % b.name):
			var t: String = (cap.get_child(0) as Label).text
			check(t == OS.get_keycode_string(k), "%s's cap reads its bound key %s (got %s)" % [b.name, OS.get_keycode_string(k), t])
	# the "?" by its keys: Q opens the sources card, again closes it; the ? key does the same
	for k: Key in [KEY_Q, KEY_SLASH]:
		await key(k)
		check(hud.card != null and hud.card.scene_file_path == SOURCES, "%s opens the sources card" % OS.get_keycode_string(k))
		await key(k)
		check(hud.card == null, "%s again closes it" % OS.get_keycode_string(k))
	await key(KEY_TAB)
	check(hud.handbook.visible, "Tab opens the handbook")
	await key(KEY_TAB)
	check(not hud.handbook.visible, "Tab closes it")


func key(k: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.pressed = down
		send(e)
	await frames(2)


## The hero at HAB 1's drink spot: the prompt shows "Hold: Drink", centred, below the middle, 1.3 times its old
## height, at a laptop's window and a small one.
func prompt() -> void:
	var spot := await at_spot("hab1", "drink")
	if spot == null:
		return
	for s: Vector2i in [Vector2i(1280, 720), Vector2i(960, 540)]:
		var view := await shape(s)
		await frames(3)
		var p: Control = hud.prompt
		check(p.is_visible_in_tree() and "Drink" in p.line.text, "%s: the prompt is up: '%s'" % [s, p.line.text])
		var r: Rect2 = p.get_global_rect()
		check(absf(r.get_center().x - view.size.x * 0.5) <= 2.0, "%s: the prompt is centred (%s)" % [s, r])
		check(r.position.y > view.size.y * 0.5 and r.end.y < view.size.y, "%s: below the middle, on screen (%s)" % [s, r])
		var h := r.size.y / hud.scale.y
		check(h >= 1.3 * OLD_H, "%s: %.0f canvas px tall, at least 1.3 x the old %.0f" % [s, h, OLD_H])
	await shape(SHAPES[0])
	await frames(3)
	if DisplayServer.get_name() != "headless":
		var img := root.get_texture().get_image()
		img.save_png("user://hud_prompt.png")
		print("picture: ", ProjectSettings.globalize_path("user://hud_prompt.png"))


## The morning note is a line a 7 year old reads, and fills in the wake time.
func words() -> void:
	var t: String = hud.line("sleep.woke_late")
	check("%s" in t and (t % "08:10").split(" ").size() <= 8, "the late morning note: '%s'" % t)


## The first spot of `kind` on `item`, the hero at its stand looking at it (as tests/hold_test.gd at_spot()).
func at_spot(item: String, kind: String) -> Node3D:
	var box: Node3D = game.interactions
	var player: Node3D = game.player
	var spot: Node3D = null
	for it: Node3D in get_nodes_in_group("interactable"):
		if it.kind == "spot" and it.row.kind == kind and it.get_parent().name == item:
			spot = it
	if not check(spot != null, "%s has a %s spot (world.json uses)" % [item, kind]):
		return null
	var at: Vector3 = spot.stand().origin
	var hit := game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 1.5, at + Vector3.DOWN * 1.5, 1 | 2, [player.body.get_rid()]))
	at.y = (hit.position.y if hit else at.y) + 0.05
	var to: Vector3 = spot.middle() - at
	player.place(at, rad_to_deg(atan2(to.x, -to.z)))
	player.cam.snap(player.yaw)
	await frames(40)
	var down: Vector3 = spot.middle() - player.cam.lens.global_position
	player.cam.pitch = -atan2(-down.y, Vector2(down.x, down.z).length())
	await frames(1)
	box.target = null
	await frames(5)
	check(box.target == spot, "%s on %s: the target from its stand" % [kind, item])
	return spot
