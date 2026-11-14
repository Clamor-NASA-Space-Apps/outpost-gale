class_name Controls
## The input actions named in CONTRACTS.md, registered in code so the keys live in one place.
## Touch controls feed these same actions. No key the browser owns (Ctrl+W/T/N, F5, F11, F12), except Esc for
## settings: in a browser the first Esc only frees a captured mouse, the next one reaches the game.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"hurry": [KEY_SHIFT], "jump": [KEY_SPACE], "interact": [KEY_E],
	"lamp": [KEY_H],  # the helmet lights; L would also turn the view (look_right)
	"look_left": [KEY_J], "look_right": [KEY_L], "look_up": [KEY_I], "look_down": [KEY_K],
	"debug_sky": [KEY_B], "debug_teleport": [KEY_T], "debug_quality": [KEY_G],
	"fullscreen": [KEY_F],  # F11 is the browser's; a web page may go full screen only from a key or a tap
	"settings": [KEY_ESCAPE],
	"handbook": [KEY_TAB],  # the HUD's handbook (ui/game_hud.gd)
	"film": [KEY_P],  # P for photo: hides every HUD layer for a screen recording, and brings them back (sandbox.gd)
}
const PADS := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
}


static func register(deadzone: float) -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, deadzone)
		for k: Key in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		if PADS.has(action):
			var j := InputEventJoypadMotion.new()
			j.axis = PADS[action][0]
			j.axis_value = PADS[action][1]
			InputMap.action_add_event(action, j)
