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
var enemy_windup := 0.0
var enemy_is_winding_up := false
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
var camera_shake := 0.0
var enemy_hit_flash := 0.0
var projectile_trail_clock := 0.0

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
	if enemy_is_winding_up:
		enemy_windup = maxf(0.0, enemy_windup - delta)
		_update_enemy_windup()
		if enemy_windup <= 0.0:
			_resolve_enemy_attack()
	invulnerability = maxf(0.0, invulnerability - delta)
	enemy_hit_flash = maxf(0.0, enemy_hit_flash - delta)
	_update_hero(delta)
	_update_enemy(delta)
	_update_actor_motion()
	_update_hit_feedback()
	_update_camera(delta)
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

	# A restrained ritual seal creates a deliberate focal point for combat.
	var seal_material := StandardMaterial3D.new()
	seal_material.albedo_color = Color(0.12, 0.22, 0.38)
	seal_material.emission_enabled = true
	seal_material.emission = Color(0.035, 0.12, 0.3)
	seal_material.roughness = 0.8
	for ring_size in [3.2, 4.5]:
		var seal_ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = float(ring_size)
		torus.outer_radius = float(ring_size) + 0.055
		seal_ring.mesh = torus
		seal_ring.position.y = 0.04
		seal_ring.material_override = seal_material
		add_child(seal_ring)
	for rune_index in range(12):
		var angle := TAU * float(rune_index) / 12.0
		var rune := MeshInstance3D.new()
		var rune_mesh := BoxMesh.new()
		rune_mesh.size = Vector3(0.18, 0.025, 0.62)
		rune.mesh = rune_mesh
		rune.position = Vector3(cos(angle) * 3.85, 0.045, sin(angle) * 3.85)
		rune.rotation.y = -angle
		rune.material_override = seal_material
		add_child(rune)

	# Broken-stone-like pillars establish a ruined arena silhouette.
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.19, 0.18, 0.23)
	for p in [Vector3(-9, 1.0, -7), Vector3(9, 1.0, -7), Vector3(-9, 1.0, 7), Vector3(9, 1.0, 7)]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(1.6, 2.0, 1.6)
		pillar.mesh = pillar_mesh
		pillar.position = p
		pillar.rotation.y = 0.12 if p.x < 0 else -0.12
		pillar.material_override = pillar_mat
		add_child(pillar)
		var crystal := MeshInstance3D.new()
		var crystal_mesh := PrismMesh.new()
		crystal_mesh.size = Vector3(0.48, 1.25, 0.48)
		crystal.mesh = crystal_mesh
		crystal.position = p + Vector3(0, 1.45, 0)
		var crystal_mat := StandardMaterial3D.new()
		crystal_mat.albedo_color = Color(0.15, 0.48, 0.8)
		crystal_mat.emission_enabled = true
		crystal_mat.emission = Color(0.06, 0.26, 0.68)
		crystal_mat.roughness = 0.28
		crystal.material_override = crystal_mat
		add_child(crystal)

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
	var actor_mesh: Mesh
	if is_hero:
		var robe := CylinderMesh.new()
		robe.top_radius = 0.22
		robe.bottom_radius = 0.48
		robe.height = 1.28
		actor_mesh = robe
	else:
		var shell := CapsuleMesh.new()
		shell.radius = 0.48
		shell.height = 1.5
		actor_mesh = shell
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "Visual"
	mesh_node.mesh = actor_mesh
	mesh_node.position.y = -0.08 if is_hero else 0.0
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
		var hood := MeshInstance3D.new()
		var hood_mesh := SphereMesh.new()
		hood_mesh.radius = 0.34
		hood_mesh.height = 0.55
		hood.mesh = hood_mesh
		hood.position = Vector3(0, 0.9, -0.04)
		var hood_mat := StandardMaterial3D.new()
		hood_mat.albedo_color = Color(0.075, 0.095, 0.19)
		hood_mat.roughness = 0.92
		hood.material_override = hood_mat
		body.add_child(hood)
		for shoulder_x in [-0.29, 0.29]:
			var shoulder := MeshInstance3D.new()
			var shoulder_mesh := SphereMesh.new()
			shoulder_mesh.radius = 0.22
			shoulder_mesh.height = 0.28
			shoulder.mesh = shoulder_mesh
			shoulder.position = Vector3(float(shoulder_x), 0.38, 0)
			var shoulder_mat := StandardMaterial3D.new()
			shoulder_mat.albedo_color = Color(0.16, 0.22, 0.43)
			shoulder_mat.metallic = 0.35
			shoulder.material_override = shoulder_mat
			body.add_child(shoulder)
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
		for shard_index in range(3):
			var shard := MeshInstance3D.new()
			var shard_mesh := PrismMesh.new()
			shard_mesh.size = Vector3(0.24, 0.82, 0.24)
			shard.mesh = shard_mesh
			shard.position = Vector3(-0.34 + float(shard_index) * 0.34, 0.32, 0.16)
			shard.rotation_degrees.z = -18.0 + float(shard_index) * 16.0
			var shard_mat := StandardMaterial3D.new()
			shard_mat.albedo_color = Color(0.24, 0.075, 0.095)
			shard_mat.roughness = 0.82
			shard.material_override = shard_mat
			body.add_child(shard)
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
	if not is_instance_valid(enemy) or enemy_is_winding_up:
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
		# Give the player a readable tell and a short dodge window before damage resolves.
		enemy_attack_cooldown = 1.25
		enemy_windup = 0.48
		enemy_is_winding_up = true
		enemy.velocity = Vector3.ZERO
		_show_message("ASHEN HOLLOW  •  WINDING UP")

func _update_enemy_windup() -> void:
	if not is_instance_valid(enemy):
		return
	var visual := enemy.get_node_or_null("Visual") as MeshInstance3D
	if visual:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.035)
		visual.scale = Vector3.ONE * (1.0 + pulse * 0.09)
		var material := visual.material_override as StandardMaterial3D
		if material:
			material.emission_enabled = true
			material.emission = Color(1.0, 0.08, 0.025) * (0.35 + pulse * 0.75)

func _resolve_enemy_attack() -> void:
	enemy_is_winding_up = false
	if not is_instance_valid(enemy) or game_over:
		return
	var visual := enemy.get_node_or_null("Visual") as MeshInstance3D
	if visual:
		visual.scale = Vector3.ONE
		var material := visual.material_override as StandardMaterial3D
		if material:
			material.emission_enabled = false
	var attack_direction := hero.global_position - enemy.global_position
	attack_direction.y = 0.0
	if attack_direction.length_squared() > 0.01:
		_spawn_enemy_strike(hero.global_position, attack_direction.normalized())
		_play_enemy_lunge(attack_direction.normalized())
	var distance := enemy.global_position.distance_to(hero.global_position)
	if distance <= 2.05 and invulnerability <= 0.0:
		hero_health -= 1
		invulnerability = 0.65
		camera_shake = 0.55
		_show_message("YOU WERE STRUCK!")
		if hero_health <= 0:
			_finish_game(false)
	else:
		_show_message("HOLLOW STRIKE  •  EVADED")


func _play_enemy_lunge(direction: Vector3) -> void:
	if not is_instance_valid(enemy):
		return
	var start_position := enemy.global_position
	var lunge_position := start_position + direction * 0.58
	var lunge := create_tween()
	lunge.tween_property(enemy, "global_position", lunge_position, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lunge.tween_property(enemy, "global_position", start_position, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_enemy_strike(at_position: Vector3, direction: Vector3) -> void:
	# A fast crimson crescent makes the Hollow's committed strike visible, even when dodged.
	var slash := MeshInstance3D.new()
	slash.name = "HollowStrikeArc"
	var arc_mesh := TorusMesh.new()
	arc_mesh.inner_radius = 0.48
	arc_mesh.outer_radius = 0.62
	slash.mesh = arc_mesh
	slash.position = at_position + Vector3(0.0, 0.92, 0.0) + direction * 0.34
	slash.rotation = Vector3(PI * 0.5, atan2(direction.x, direction.z), 0.0)
	slash.scale = Vector3(0.7, 1.0, 0.7)
	var slash_material := StandardMaterial3D.new()
	slash_material.albedo_color = Color(1.0, 0.12, 0.18, 0.9)
	slash_material.emission_enabled = true
	slash_material.emission = Color(1.0, 0.035, 0.07) * 1.8
	slash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash.material_override = slash_material
	add_child(slash)
	var slash_tween := create_tween()
	slash_tween.set_parallel(true)
	slash_tween.tween_property(slash, "scale", Vector3(1.65, 0.45, 1.65), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slash_tween.tween_property(slash, "transparency", 1.0, 0.22)
	slash_tween.chain().tween_callback(slash.queue_free)

func _update_actor_motion() -> void:
	# Lightweight procedural idle/movement motion keeps both fighters alive without skeletal rigs.
	var now := float(Time.get_ticks_msec()) * 0.001
	if is_instance_valid(hero):
		var hero_visual := hero.get_node_or_null("Visual") as MeshInstance3D
		if hero_visual:
			var moving := Vector2(hero.velocity.x, hero.velocity.z).length() > 0.2
			hero_visual.position.y = -0.08 + sin(now * (11.0 if moving else 2.2)) * (0.075 if moving else 0.025)
			hero_visual.rotation.z = sin(now * (5.5 if moving else 1.4)) * (0.045 if moving else 0.018)
	if is_instance_valid(enemy):
		var enemy_visual := enemy.get_node_or_null("Visual") as MeshInstance3D
		if enemy_visual:
			enemy_visual.position.y = sin(now * 3.1 + 1.2) * 0.045
			enemy_visual.rotation.z = sin(now * 2.0) * 0.025

func _update_hit_feedback() -> void:
	# Brief, readable flashes communicate damage without costly post-processing.
	if is_instance_valid(hero):
		var hero_visual := hero.get_node_or_null("Visual") as MeshInstance3D
		if hero_visual:
			hero_visual.visible = invulnerability <= 0.0 or int(Time.get_ticks_msec() / 90) % 2 == 0
	if is_instance_valid(enemy):
		var enemy_visual := enemy.get_node_or_null("Visual") as MeshInstance3D
		if enemy_visual and enemy_hit_flash > 0.0:
			var hit_material := enemy_visual.material_override as StandardMaterial3D
			if hit_material:
				hit_material.emission_enabled = true
				hit_material.emission = Color(0.95, 0.28, 0.12) * (enemy_hit_flash / 0.16)
		elif is_instance_valid(enemy) and not enemy_is_winding_up:
			var enemy_visual_reset := enemy.get_node_or_null("Visual") as MeshInstance3D
			if enemy_visual_reset:
				var reset_material := enemy_visual_reset.material_override as StandardMaterial3D
				if reset_material:
					reset_material.emission_enabled = false

func _update_camera(delta: float) -> void:
	if is_instance_valid(hero) and is_instance_valid(arena_camera):
		camera_shake = maxf(0.0, camera_shake - delta * 2.8)
		var shake_x := sin(Time.get_ticks_msec() * 0.07) * camera_shake * 0.13
		var shake_y := cos(Time.get_ticks_msec() * 0.09) * camera_shake * 0.09
		arena_camera.position.x = lerpf(arena_camera.position.x, hero.position.x, 0.06) + shake_x
		arena_camera.position.z = lerpf(arena_camera.position.z, hero.position.z + 10.5, 0.06) + shake_y

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
	if to_enemy.length() > 8.0:
		_show_message("TOO FAR — MOVE CLOSER")
		return
	# The spell now travels through the arena and resolves on arrival instead of applying an instant hitscan.
	var launch_position := hero.global_position + Vector3(0.0, 0.82, 0.0)
	var target_position := enemy.global_position + Vector3(0.0, 0.68, 0.0)
	_play_cast_motion()
	_spawn_bolt_effect(launch_position, target_position, enemy)
	_show_message("ARCANE BOLT  •  CAST")

func _play_cast_motion() -> void:
	var visual := hero.get_node_or_null("Visual") as MeshInstance3D
	if not visual:
		return
	var original_rotation := visual.rotation
	var cast_tween := create_tween()
	cast_tween.tween_property(visual, "rotation:z", -0.24, 0.09)
	cast_tween.tween_property(visual, "rotation:z", 0.10, 0.12)
	cast_tween.tween_property(visual, "rotation:z", original_rotation.z, 0.14)

func _spawn_bolt_effect(from: Vector3, to: Vector3, target: Node3D) -> void:
	# A bright core, translucent-looking shell and trailing motes make the projectile read as a moving object.
	var projectile := Node3D.new()
	projectile.name = "ArcaneBoltProjectile"
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.19
	core_mesh.height = 0.38
	core.mesh = core_mesh
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(0.58, 0.86, 1.0)
	core_material.emission_enabled = true
	core_material.emission = Color(0.2, 0.62, 1.0)
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = core_material
	projectile.add_child(core)
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.30
	shell_mesh.height = 0.60
	shell.mesh = shell_mesh
	var shell_material := StandardMaterial3D.new()
	shell_material.albedo_color = Color(0.18, 0.52, 1.0, 0.42)
	shell_material.emission_enabled = true
	shell_material.emission = Color(0.08, 0.28, 0.85)
	shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shell.material_override = shell_material
	projectile.add_child(shell)
	add_child(projectile)
	projectile.global_position = from
	projectile_trail_clock = 0.0
	var flight := create_tween()
	flight.set_trans(Tween.TRANS_CUBIC)
	flight.set_ease(Tween.EASE_OUT)
	flight.tween_method(Callable(self, "_animate_arcane_projectile").bind(projectile, from, to), 0.0, 1.0, 0.46)
	flight.tween_callback(Callable(self, "_finish_arcane_projectile").bind(projectile, target, to))

func _animate_arcane_projectile(progress: float, projectile: Node3D, from: Vector3, to: Vector3) -> void:
	if not is_instance_valid(projectile):
		return
	var arc_height := 1.0 + sin(progress * PI) * 1.35
	projectile.global_position = from.lerp(to, progress) + Vector3(0.0, arc_height, 0.0)
	projectile.rotation.z = progress * TAU * 1.7
	projectile.scale = Vector3.ONE * (1.0 + sin(progress * PI) * 0.18)
	projectile_trail_clock += 0.016
	if projectile_trail_clock >= 0.045:
		projectile_trail_clock = 0.0
		_spawn_arcane_mote(projectile.global_position)

func _spawn_arcane_mote(at_position: Vector3) -> void:
	var mote := MeshInstance3D.new()
	var mote_mesh := SphereMesh.new()
	mote_mesh.radius = 0.055
	mote_mesh.height = 0.11
	mote.mesh = mote_mesh
	var mote_material := StandardMaterial3D.new()
	mote_material.albedo_color = Color(0.35, 0.72, 1.0)
	mote_material.emission_enabled = true
	mote_material.emission = Color(0.16, 0.42, 1.0)
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote.material_override = mote_material
	mote.position = at_position
	add_child(mote)
	var mote_tween := create_tween()
	mote_tween.set_parallel(true)
	mote_tween.tween_property(mote, "scale", Vector3.ZERO, 0.22)
	mote_tween.tween_property(mote, "transparency", 1.0, 0.22)
	mote_tween.chain().tween_callback(mote.queue_free)

func _finish_arcane_projectile(projectile: Node3D, target: Node3D, impact_position: Vector3) -> void:
	if is_instance_valid(projectile):
		projectile.queue_free()
	if not is_instance_valid(target) or target != enemy or game_over:
		return
	enemy_health -= 1
	enemy_hit_flash = 0.16
	var recoil := (enemy.global_position - hero.global_position)
	recoil.y = 0.0
	if recoil.length_squared() > 0.01:
		enemy.global_position += recoil.normalized() * 0.28
	camera_shake = 0.9
	_spawn_impact_burst(enemy.global_position)
	var enemy_visual := enemy.get_node_or_null("Visual") as MeshInstance3D
	if enemy_visual:
		var original_scale := enemy_visual.scale
		var hit_tween := create_tween()
		enemy_visual.scale = original_scale * 1.12
		hit_tween.tween_property(enemy_visual, "scale", original_scale, 0.16)
	_show_message("ARCANE BOLT  •  IMPACT")
	if enemy_health <= 0:
		enemy.queue_free()
		enemy = null
		_show_message("ASHEN HOLLOW DEFEATED")
		_finish_game(true)

func _spawn_impact_burst(at_position: Vector3) -> void:
	for ring_index in range(2):
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.22 + float(ring_index) * 0.14
		ring_mesh.outer_radius = 0.28 + float(ring_index) * 0.14
		ring.mesh = ring_mesh
		ring.position = at_position + Vector3(0, 0.72, 0)
		var ring_mat := StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.35, 0.78, 1.0)
		ring_mat.emission_enabled = true
		ring_mat.emission = Color(0.2, 0.62, 1.0)
		ring.material_override = ring_mat
		add_child(ring)
		var burst_tween := create_tween()
		burst_tween.set_parallel(true)
		burst_tween.tween_property(ring, "scale", Vector3.ONE * (2.0 + float(ring_index) * 0.5), 0.22)
		burst_tween.tween_property(ring, "transparency", 1.0, 0.22)
		burst_tween.chain().tween_callback(ring.queue_free)

func _blink_step() -> void:
	if game_over or not is_instance_valid(hero):
		return
	var direction := Vector3(joystick_vector.x, 0, joystick_vector.y)
	if direction.length_squared() < 0.05:
		direction = -hero.global_transform.basis.z
		direction.y = 0
	if direction.length_squared() > 0.01:
		var departure := hero.global_position
		var destination := departure + direction.normalized() * BLINK_DISTANCE
		destination.x = clampf(destination.x, -17.5, 17.5)
		destination.z = clampf(destination.z, -13.5, 13.5)
		_spawn_blink_departure(departure)
		hero.global_position = destination
		_spawn_blink_arrival(destination)
		invulnerability = maxf(invulnerability, 0.22)
		_show_message("BLINK STEP  •  PHASE SHIFT")

func _spawn_blink_departure(at_position: Vector3) -> void:
	# Leave a brief spectral echo where the mage began the phase shift.
	var visual := hero.get_node_or_null("Visual") as MeshInstance3D
	if visual:
		var ghost := visual.duplicate() as MeshInstance3D
		if ghost:
			add_child(ghost)
			ghost.global_transform = visual.global_transform
			var ghost_material := StandardMaterial3D.new()
			ghost_material.albedo_color = Color(0.36, 0.68, 1.0, 0.48)
			ghost_material.emission_enabled = true
			ghost_material.emission = Color(0.16, 0.48, 1.0)
			ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ghost.material_override = ghost_material
			var fade := create_tween()
			fade.set_parallel(true)
			fade.tween_property(ghost, "transparency", 1.0, 0.24)
			fade.tween_property(ghost, "scale", Vector3.ONE * 0.62, 0.24)
			fade.chain().tween_callback(ghost.queue_free)
	_spawn_blink_ring(at_position, Color(0.22, 0.52, 1.0))

func _spawn_blink_arrival(at_position: Vector3) -> void:
	_spawn_blink_ring(at_position, Color(0.55, 0.36, 1.0))
	var visual := hero.get_node_or_null("Visual") as MeshInstance3D
	if visual:
		visual.scale = Vector3(1.18, 0.82, 1.18)
		var arrival_tween := create_tween()
		arrival_tween.tween_property(visual, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_blink_ring(at_position: Vector3, tint: Color) -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.28
	ring_mesh.outer_radius = 0.38
	ring.mesh = ring_mesh
	ring.position = at_position + Vector3(0.0, 0.09, 0.0)
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = tint
	ring_material.emission_enabled = true
	ring_material.emission = tint
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	add_child(ring)
	var burst := create_tween()
	burst.set_parallel(true)
	burst.tween_property(ring, "scale", Vector3.ONE * 2.2, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	burst.tween_property(ring, "transparency", 1.0, 0.28)
	burst.chain().tween_callback(ring.queue_free)

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
	enemy_windup = 0.0
	enemy_is_winding_up = false
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
