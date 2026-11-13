extends "res://addons/forge/test.gd"
## The HUD kit's checks: godot --headless --path . -s tests/ui_test.gd
## Every page of ui/hud_gallery.tscn in both layouts: touch targets, text contrast, words per line,
## the alert's pulse rate, and the colour choke point (no colour literals in ui code).

const Hud := preload("res://ui/hud.gd")
const MAX_WORDS := 8  # Kid UX: at most 8 words per card line
const MIN_CONTRAST := 4.5  # XAG 102 and WCAG 1.4.3 for text (design/research/sizes.md B)
const MAX_FLASHES := 3.0  # per second, Kid UX


func play() -> bool:
	# a phone-shaped window (2400 x 1080 is 1600 x 720 on the canvas), so the phone layout is drawn unshrunk
	await shape(SHAPES[1])
	var g: Control = load("res://ui/hud_gallery.tscn").instantiate()
	root.add_child(g)
	await frames(2)
	# the worst backdrops a see-through panel can sit on: the bright horizon haze and the dark shade
	var backdrops: Array[Color] = [Hud.color("horizon"), Hud.color("surface")]
	var buttons := 0
	var labels := 0
	for layout: String in ["laptop", "phone"]:
		for p: String in g.PAGES:
			g.set_view("%s_%s" % [layout, p])
			await frames(2)  # containers sort on the next frame
			var state: Dictionary = g.render_game_to_text()
			check(state.components.size() > 0, "%s_%s shows no component" % [layout, p])
			for n: Node in g.find_children("*", "Control", true, false):
				var c := n as Control
				if not c.is_visible_in_tree():
					continue
				var where := "%s_%s %s" % [layout, p, g.get_path_to(c)]
				if c is Button:
					buttons += 1
					var b := c as Button
					if layout == "phone":
						# measured on the phone's own canvas, not the shrunk preview inside the bezel
						var h: float = b.get_global_rect().size.y / g.screen.scale.y
						check(h >= TARGET, "%s is %.0f scene px tall, a touch target needs %.0f" % [where, h, TARGET])
					if b.text:
						_contrast(b.get_theme_color("font_color"), b.get_theme_stylebox("normal"), backdrops, where)
				elif c is Label:
					labels += 1
					var l := c as Label
					var words := l.text.split(" ", false).size()
					check(words <= MAX_WORDS, "%s has %d words: '%s'" % [where, words, l.text])
					var panel := _panel_of(l)
					if check(panel != null, "%s sits on the bare world with no panel behind it" % where):
						_contrast(l.get_theme_color("font_color"), panel, backdrops, where)
	check(buttons > 0, "the gallery has buttons")
	print("checked %d buttons and %d labels over %d views" % [buttons, labels, g.PAGES.size() * 2])
	var toast: Script = load("res://ui/components/alert_toast.gd")
	var pulse: float = toast.get_script_constant_map().PULSE_SECONDS
	check(1.0 / pulse <= MAX_FLASHES, "the alert pulses %.1f times a second" % (1.0 / pulse))
	_no_colour_literals("res://ui/")
	_no_colour_literals("res://ui/components/")
	_loading_tokens()
	return true


## The web shell (web/shell.html) and the boot splash colour (project.godot) cannot read design.json, so they hold
## copies of its tokens: the loading screens must not drift from the HUD.
func _loading_tokens() -> void:
	var colors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://design.json")).colors
	var found := RegEx.create_from_string("--([a-z-]+): (#[0-9a-f]{6});").search_all(FileAccess.get_file_as_string("res://web/shell.html"))
	check(found.size() >= 4, "web/shell.html declares its colour tokens")
	for m: RegExMatch in found:
		check(colors.get(m.get_string(1), "") == m.get_string(2), "web/shell.html --%s is %s, design.json says %s" % [m.get_string(1), m.get_string(2), colors.get(m.get_string(1), "nothing")])
	var bg: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	check(bg.to_html(false) == Hud.color("surface").to_html(false), "the boot splash colour %s is not the surface token" % bg.to_html(false))


## The style a text sits on: its own button, or the nearest panel above it with a fill.
func _panel_of(n: Control) -> StyleBox:
	var at: Node = n
	while at is Control:
		var c := at as Control
		var s: StyleBox = null
		if c is Button:
			s = c.get_theme_stylebox("normal")
		elif c is PanelContainer:
			s = c.get_theme_stylebox("panel")
		var flat := s as StyleBoxFlat
		if flat and flat.draw_center and flat.bg_color.a > 0.0:
			return flat
		at = at.get_parent()
	return null


func _contrast(text: Color, style: StyleBox, backdrops: Array[Color], where: String) -> void:
	var flat := style as StyleBoxFlat
	if not check(flat != null, "%s has no flat style to measure" % where):
		return
	for under: Color in backdrops:
		var bg := under.lerp(Color(flat.bg_color, 1.0), flat.bg_color.a)
		var r := _ratio(text, bg)
		check(r >= MIN_CONTRAST, "%s text contrast %.2f:1 over %s" % [where, r, under.to_html(false)])


func _ratio(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## ui/theme.tres (from design.json) is the one place HUD colours come from. theme_builder.gd reads the
## tokens, so it is the one script allowed to make colours; Color.TRANSPARENT is allowed everywhere.
func _no_colour_literals(dir: String) -> void:
	var re := RegEx.create_from_string("Color\\(|Color\\.(?!TRANSPARENT)[A-Z]|#[0-9a-fA-F]{6}\\b|Color\\.html")
	for f: String in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd") or f == "theme_builder.gd":
			continue
		var src := FileAccess.get_file_as_string(dir + f)
		for line: String in src.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			check(re.search(line) == null, "%s%s has a colour literal: %s" % [dir, f, line.strip_edges()])
