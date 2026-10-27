extends Node3D

## Milestone 1: first playable arena prototype.
## All geometry is intentionally placeholder art; gameplay systems are real.

const HERO_SPEED := 5.0
const BLINK_DISTANCE := 3.2
const BOLT_COOLDOWN := 0.42
const ENEMY_MAX_HEALTH := 3

var hero: CharacterBody3D
var enemy: CharacterBody3D
var enemy_health := ENEMY_MAX_HEALTH
var hero_health := 5
var bolt_cooldown := 0.0
var enemy_attack_cooldown := 0.0
var invulnerability := 0.0
var joystick_vector := Vector2.ZERO
var joystick_touch_index := -1
var joystick_center := Vector2.ZERO
var joystick_radius := 74.0
var hud_label: Label
var health_label: Label
var message_label: Label
var joystick_base: Panel
var joystick_knob: Panel
var attack_button: Button
var blink_button: Button
var restart_button: Button
var game_over := false
var arena_camera: Camera3D

func _ready() -> void:
	_build_arena()
	_build_hero()
	_spawn_enemy()
	_build_ui()
	_update_hud()
	print("Ashen Covenant M1: playable combat prototype initialized.")

func _physics_process(delta: float) -> void:
	if game_over:
		return
	bolt_cooldown = maxf(0.0, bolt_cooldown - delta)
	enemy_attack_cooldown = maxf(0.0, enemy_attack_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	_update_hero(delta)
	_update_enemy(delta)
	_update_camera()
	_update_hud()

func _build_arena() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.028, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.52, 0.72)
	environment.ambient_light_energy = 0.7
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -28, 0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	add_child(light)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 32)
	floor.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.105, 0.11, 0.15)
	floor_mat.roughness = 0.94
	floor.material_override = floor_mat
	add_child(floor)

	# Subtle stone joints add scale without heavy textures or large assets.
	var seam_mat := StandardMaterial3D.new()
	seam_mat.albedo_color = Color(0.075, 0.08, 0.105)
	seam_mat.roughness = 1.0
	for x in [-16, -12, -8, -4, 0, 4, 8, 12, 16]:
		var seam := MeshInstance3D.new()
		var seam_mesh := BoxMesh.new()
		seam_mesh.size = Vector3(0.035, 0.018, 30.0)
		seam.mesh = seam_mesh
		seam.position = Vector3(float(x), 0.012, 0)
		seam.material_override = seam_mat
		add_child(seam)
	for z in [-12, -8, -4, 0, 4, 8, 12]:
		var seam := MeshInstance3D.new()
		var seam_mesh := BoxMesh.new()
		seam_mesh.size = Vector3(38.0, 0.018, 0.035)
		seam.mesh = seam_mesh
		seam.position = Vector3(0, 0.014, float(z))
		seam.material_override = seam_mat
		add_child(seam)

	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40, 0.3, 32)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.16
	floor_body.add_child(floor_collision)
	add_child(floor_body)

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.22, 0.19, 0.28)
	for i in range(4):
		var wall := StaticBody3D.new()
		var wall_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(40.5, 1.0, 0.6) if i < 2 else Vector3(0.6, 1.0, 32.5)
		wall_mesh.mesh = box
		wall_mesh.material_override = rim_mat
		wall.add_child(wall_mesh)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		shape_node.shape = shape
		wall.add_child(shape_node)
		match i:
			0: wall.position = Vector3(0, 0.5, -16)
			1: wall.position = Vector3(0, 0.5, 16)
			2: wall.position = Vector3(-20, 0.5, 0)
			3: wall.position = Vector3(20, 0.5, 0)
		add_child(wall)

	# Broken-stone-like pillars establish a ruined arena silhouette.
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.19, 0.18, 0.23)
	for p in [Vector3(-9, 1.0, -7), Vector3(9, 1.0, -7), Vector3(-9, 1.0, 7), Vector3(9, 1.0, 7)]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(1.6, 2.0, 1.6)
		pillar.mesh = pillar_mesh
		pillar.position = p
		pillar.material_override = pillar_mat
		add_child(pillar)

	arena_camera = Camera3D.new()
	arena_camera.position = Vector3(0, 12.5, 10.5)
	arena_camera.rotation_degrees = Vector3(-50, 0, 0)
	arena_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	arena_camera.size = 13.5
	arena_camera.current = true
	add_child(arena_camera)

func _make_actor(body_name: String, color: Color, start_position: Vector3, is_hero: bool) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = body_name
	body.position = start_position
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42 if is_hero else 0.48
	capsule.height = 1.5
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Visual"
	mesh_node.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.15
	mat.roughness = 0.45
	mesh_node.material_override = mat
	body.add_child(mesh_node)

	# Readable character details: a mage's arcane focus and the Hollow's ember eyes.
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.31 if is_hero else 0.34
	head_mesh.height = 0.62 if is_hero else 0.68
	head.mesh = head_mesh
	head.position = Vector3(0, 0.79, 0)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.12, 0.17, 0.34) if is_hero else Color(0.17, 0.11, 0.14)
	head_mat.roughness = 0.72
	head.material_override = head_mat
	body.add_child(head)
	if is_hero:
		var staff := MeshInstance3D.new()
		var staff_mesh := CylinderMesh.new()
		staff_mesh.top_radius = 0.045
		staff_mesh.bottom_radius = 0.065
		staff_mesh.height = 1.55
		staff.mesh = staff_mesh
		staff.position = Vector3(0.55, 0.05, 0.0)
		staff.rotation_degrees.z = -12
		var staff_mat := StandardMaterial3D.new()
		staff_mat.albedo_color = Color(0.24, 0.17, 0.13)
		staff_mat.roughness = 0.85
		staff.material_override = staff_mat
		body.add_child(staff)
		var focus := MeshInstance3D.new()
		var focus_mesh := SphereMesh.new()
		focus_mesh.radius = 0.16
		focus_mesh.height = 0.32
		focus.mesh = focus_mesh
		focus.position = Vector3(0.68, 0.78, 0.0)
		var focus_mat := StandardMaterial3D.new()
		focus_mat.albedo_color = Color(0.3, 0.65, 1.0)
		focus_mat.emission_enabled = true
		focus_mat.emission = Color(0.12, 0.4, 1.0)
		focus.material_override = focus_mat
		body.add_child(focus)
	else:
		for eye_x in [-0.14, 0.14]:
			var eye := MeshInstance3D.new()
			var eye_mesh := SphereMesh.new()
			eye_mesh.radius = 0.055
			eye_mesh.height = 0.11
			eye.mesh = eye_mesh
			eye.position = Vector3(float(eye_x), 0.83, -0.29)
			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.12, 0.08)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(0.85, 0.035, 0.015)
			eye.material_override = eye_mat
			body.add_child(eye)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42 if is_hero else 0.48
	shape.height = 1.5
	collision.shape = shape
	body.add_child(collision)
	var glow := MeshInstance3D.new()
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 0.55 if is_hero else 0.62
	glow_mesh.bottom_radius = glow_mesh.top_radius
	glow_mesh.height = 0.035
	glow.mesh = glow_mesh
	glow.position.y = -0.72
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.25, 0.5, 1.0) if is_hero else Color(0.95, 0.18, 0.25)
	glow_mat.emission_enabled = true
	glow_mat.emission = glow_mat.albedo_color
	glow.material_override = glow_mat
	body.add_child(glow)
	add_child(body)
	return body

func _build_hero() -> void:
	hero = _make_actor("BattleMage", Color(0.27, 0.43, 0.95), Vector3(0, 0.8, 3), true)

func _spawn_enemy() -> void:
	enemy_health = ENEMY_MAX_HEALTH
	enemy = _make_actor("AshenHollow", Color(0.68, 0.22, 0.25), Vector3(0, 0.8, -4), false)

func _update_hero(delta: float) -> void:
	var input_vector := joystick_vector
	if Input.is_action_pressed("ui_left"):
		input_vector.x -= 1.0
	if Input.is_action_pressed("ui_right"):
		input_vector.x += 1.0
	if Input.is_action_pressed("ui_up"):
		input_vector.y -= 1.0
	if Input.is_action_pressed("ui_down"):
		input_vector.y += 1.0
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	var direction := Vector3(input_vector.x, 0, input_vector.y)
	hero.velocity.x = direction.x * HERO_SPEED
	hero.velocity.z = direction.z * HERO_SPEED
	hero.velocity.y = 0
	hero.move_and_slide()
	hero.position.x = clampf(hero.position.x, -17.5, 17.5)
	hero.position.z = clampf(hero.position.z, -13.5, 13.5)
	if direction.length_squared() > 0.01:
		hero.look_at(hero.global_position + direction, Vector3.UP)

func _update_enemy(delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	var to_hero := hero.global_position - enemy.global_position
	to_hero.y = 0
	var distance := to_hero.length()
	if distance > 1.45:
		var direction := to_hero.normalized()
		enemy.velocity = direction * (1.45 if distance > 2.2 else 0.7)
		enemy.velocity.y = 0
		enemy.move_and_slide()
		enemy.look_at(enemy.global_position + direction, Vector3.UP)
	elif enemy_attack_cooldown <= 0.0:
		enemy_attack_cooldown = 1.25
		if invulnerability <= 0.0:
			hero_health -= 1
			invulnerability = 0.65
			_show_message("You were struck!")
			if hero_health <= 0:
				_finish_game(false)

func _update_camera() -> void:
	if is_instance_valid(hero) and is_instance_valid(arena_camera):
		arena_camera.position.x = lerpf(arena_camera.position.x, hero.position.x, 0.06)
		arena_camera.position.z = lerpf(arena_camera.position.z, hero.position.z + 10.5, 0.06)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	health_label = Label.new()
	health_label.position = Vector2(24, 18)
	health_label.add_theme_font_size_override("font_size", 25)
	health_label.add_theme_color_override("font_color", Color(0.88, 0.91, 1.0))
	root.add_child(health_label)

	hud_label = Label.new()
	hud_label.position = Vector2(24, 52)
	hud_label.add_theme_font_size_override("font_size", 18)
	hud_label.add_theme_color_override("font_color", Color(0.65, 0.73, 0.9))
	root.add_child(hud_label)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_left = -250
	message_label.offset_top = 22
	message_label.offset_right = 250
	message_label.offset_bottom = 60
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 21)
	message_label.add_theme_color_override("font_color", Color(0.75, 0.82, 1.0))
	root.add_child(message_label)
	message_label.text = "DEFEAT THE ASHEN HOLLOW"

	# Anchor-based safe margins keep touch controls inside the visible viewport.
	joystick_base = Panel.new()
	joystick_base.set_anchors_preset(Control.PRESET_TOP_LEFT)
	joystick_base.position = Vector2(32, get_viewport().get_visible_rect().size.y - 178)
	joystick_base.size = Vector2(148, 148)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.12, 0.16, 0.27, 0.68)
	base_style.border_color = Color(0.42, 0.52, 0.78, 0.88)
	base_style.set_border_width_all(3)
	base_style.set_corner_radius_all(74)
	root.add_child(joystick_base)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	joystick_center = Vector2(106, get_viewport().get_visible_rect().size.y - 104)

	joystick_knob = Panel.new()
	joystick_knob.set_anchors_preset(Control.PRESET_TOP_LEFT)
	joystick_knob.position = Vector2(77, get_viewport().get_visible_rect().size.y - 133)
	joystick_knob.size = Vector2(58, 58)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.48, 0.61, 0.98, 0.96)
	knob_style.border_color = Color(0.78, 0.85, 1.0)
	knob_style.set_border_width_all(2)
	knob_style.set_corner_radius_all(29)
	root.add_child(joystick_knob)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)

	attack_button = _make_button(root, "ARCANE BOLT", Vector2(get_viewport().get_visible_rect().size.x - 144, get_viewport().get_visible_rect().size.y - 196), Color(0.22, 0.34, 0.78))
	attack_button.pressed.connect(_cast_arcane_bolt)
	blink_button = _make_button(root, "BLINK", Vector2(get_viewport().get_visible_rect().size.x - 144, get_viewport().get_visible_rect().size.y - 112), Color(0.42, 0.24, 0.7))
	blink_button.pressed.connect(_blink_step)
	restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.size = Vector2(100, 48)
	restart_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	restart_button.position = Vector2(get_viewport().get_visible_rect().size.x - 118, 16)
	restart_button.pressed.connect(_restart_game)
	root.add_child(restart_button)
	restart_button.visible = false

func _make_button(parent: Control, caption: String, offset: Vector2, tint: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.size = Vector2(112, 72)
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.position = offset
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = tint.darkened(0.12)
	style.border_color = tint.lightened(0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", style)
	var pressed_style := style.duplicate()
	pressed_style.bg_color = tint.lightened(0.12)
	button.add_theme_stylebox_override("pressed", pressed_style)
	parent.add_child(button)
	return button

func _draw_joystick_base() -> void:
	pass

func _input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventScreenTouch:
		var viewport_size := get_viewport().get_visible_rect().size
		var base_rect := Rect2(Vector2(32, viewport_size.y - 178), Vector2(148, 148))
		if event.pressed and base_rect.has_point(event.position) and joystick_touch_index == -1:
			joystick_touch_index = event.index
			_update_joystick(event.position)
		elif not event.pressed and event.index == joystick_touch_index:
			joystick_touch_index = -1
			joystick_vector = Vector2.ZERO
			_reset_joystick_knob()
	elif event is InputEventScreenDrag and event.index == joystick_touch_index:
		_update_joystick(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_cast_arcane_bolt()
		elif event.keycode == KEY_SHIFT:
			_blink_step()

func _update_joystick(screen_position: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var center := Vector2(106, viewport_size.y - 104)
	var delta := screen_position - center
	if delta.length() > joystick_radius:
		delta = delta.normalized() * joystick_radius
	joystick_vector = Vector2(delta.x / joystick_radius, delta.y / joystick_radius)
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(77 + delta.x, get_viewport().get_visible_rect().size.y - 133 + delta.y)

func _reset_joystick_knob() -> void:
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(77, get_viewport().get_visible_rect().size.y - 133)

func _cast_arcane_bolt() -> void:
	if game_over or bolt_cooldown > 0.0 or not is_instance_valid(enemy):
		return
	bolt_cooldown = BOLT_COOLDOWN
	var to_enemy := enemy.global_position - hero.global_position
	to_enemy.y = 0
	if to_enemy.length() <= 8.0:
		enemy_health -= 1
		_spawn_bolt_effect(hero.global_position, enemy.global_position)
		_show_message("ARCANE BOLT  •  HIT")
		if enemy_health <= 0:
			enemy.queue_free()
			enemy = null
			_show_message("ASHEN HOLLOW DEFEATED")
			_finish_game(true)
	else:
		_show_message("TOO FAR — MOVE CLOSER")

func _spawn_bolt_effect(from: Vector3, to: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.07
	cylinder.bottom_radius = 0.07
	cylinder.height = from.distance_to(to)
	beam.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.62, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.16, 0.4, 1.0)
	beam.material_override = material
	beam.position = (from + to) * 0.5 + Vector3(0, 0.7, 0)
	beam.look_at(to + Vector3(0, 0.7, 0), Vector3.UP)
	add_child(beam)
	var timer := get_tree().create_timer(0.16)
	timer.timeout.connect(beam.queue_free)

func _blink_step() -> void:
	if game_over:
		return
	var direction := Vector3(joystick_vector.x, 0, joystick_vector.y)
	if direction.length_squared() < 0.05:
		direction = -hero.global_transform.basis.z
		direction.y = 0
	if direction.length_squared() > 0.01:
		hero.global_position += direction.normalized() * BLINK_DISTANCE
		hero.position.x = clampf(hero.position.x, -17.5, 17.5)
		hero.position.z = clampf(hero.position.z, -13.5, 13.5)
		_show_message("BLINK STEP")

func _finish_game(victory: bool) -> void:
	game_over = true
	message_label.text = "VICTORY — THE HOLLOW FALLS" if victory else "YOU HAVE FALLEN"
	restart_button.visible = true
	_update_hud()

func _restart_game() -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
	hero.queue_free()
	hero_health = 5
	game_over = false
	invulnerability = 0.0
	bolt_cooldown = 0.0
	enemy_attack_cooldown = 0.0
	_build_hero()
	_spawn_enemy()
	restart_button.visible = false
	_show_message("DEFEAT THE ASHEN HOLLOW")
	_update_hud()

func _show_message(text_value: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = text_value

func _update_hud() -> void:
	if is_instance_valid(health_label):
		health_label.text = "VITALITY  " + "♥ ".repeat(maxi(hero_health, 0))
	if is_instance_valid(hud_label):
		hud_label.text = "ASHEN HOLLOW  •  " + str(maxi(enemy_health, 0)) + " / " + str(ENEMY_MAX_HEALTH) + " HP"
