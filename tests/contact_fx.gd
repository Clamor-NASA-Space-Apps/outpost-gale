extends Node3D
## Fixture for the footstep and wheel dust (skills/ground-contact-fx, check 2): the sandbox, with views at
## ankle height a body length to the side of a step. Each view fires its steps the moment it is chosen, so a
## film started on it shows the contact and what follows.
##   set_view("ankle"): one walking step;  set_view("wheel"): a wheel at the rover's top speed;
##   set_view("shade"): one walking step inside the storm shelter's long shadow (the day sun is low in the
##   south, so the shadow runs north): the dust there must be no brighter than the shaded ground round it;
##   set_view("ten"): ten steps in flight at once, for draw calls.

const STEP := Vector3(2, 0, 12)  # open ground beside spawn, no rock or item on it
const SHADE := Vector3(-5.1, 0, 6.5)  # 3.5 m north of the storm shelter, in its shadow

@onready var sandbox: Node3D = $Sandbox
var world: Node3D


func _ready() -> void:
	world = sandbox.get_node("World")
	var player: Node = sandbox.get_node("Player")
	if player.has_signal("footstep"):
		for c: Dictionary in player.footstep.get_connections():
			player.footstep.disconnect(c.callable)  # only the steps this fixture fires
	Forge.register(self)


func render_game_to_text() -> Dictionary:
	return {"contact": world.dust.contact_state()}


func set_view(v: String) -> void:
	var at := SHADE if v == "shade" else STEP
	at.y = world.height_at(at.x, at.z)
	var cam: Camera3D = sandbox.get_node("ViewCam")
	# eye level at 12 cm, so a grain above it shows against the sky and not against the ground it came from
	cam.look_at_from_position(at + Vector3(1.6, 0.12, 0), at + Vector3(0, 0.12, 0))
	cam.current = true
	match v:
		"ankle", "shade":
			world.mark(at, 0.0, "foot_l")
			world.puff(at, Vector3(0, -0.3, -1.0), 0.5)
		"wheel":
			world.puff(at, Vector3(0, 0, 2.8), 1.0, "wheel")  # driving north: the rim moves south at the ground
		"ten":
			cam.look_at_from_position(at + Vector3(4.0, 1.2, 0), at + Vector3(0, 0.1, 0))
			for i in 10:
				world.puff(at + Vector3(0, 0, -0.6 * i), Vector3(0, -0.3, -1.6), 1.0)
