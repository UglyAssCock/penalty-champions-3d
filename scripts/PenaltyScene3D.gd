extends Node3D

var main_ctrl: Node
var hud_root: Control
var home_team: Dictionary
var away_team: Dictionary
var fixture_context: Dictionary = {}

var home_takers: Array = []
var away_takers: Array = []
var home_gk: Dictionary
var away_gk: Dictionary

# Shootout state
var is_user_kicking: bool = true
var round_index: int = 0
var home_results: Array = [] # 1 = scored, 0 = missed
var away_results: Array = []
var home_score: int = 0
var away_score: int = 0
var shootout_over: bool = false

# Turn state: "AIMING", "BALL_IN_FLIGHT", "RESULT_PAUSE"
var phase: String = "AIMING"
var phase_timer: float = 0.0

# Aim & Difficulty variables
var base_aim_uv: Vector2 = Vector2(0.25, 0.55) # X: -1(left)..1(right), Y: 0(ground)..1(top)
var actual_aim_uv: Vector2 = Vector2(0.25, 0.55)
var gk_dive_uv: Vector2 = Vector2(0.0, 0.4)
var wobble_time: float = 0.0
var wobble_amount: float = 0.05
var power_marker_pos: float = 0.5 # 0.0 to 1.0
var power_marker_dir: float = 1.0
var power_marker_speed: float = 1.15
var sweet_spot_half_width: float = 0.14
var is_dragging_aim: bool = false

# 3D Nodes
var camera: Camera3D
var ball_node: Node3D
var kicker_node: Node3D
var keeper_node: Node3D
var net_mesh_inst: MeshInstance3D
var crowd_multimesh: MultiMeshInstance3D

# Ball physics animation
var ball_start_pos: Vector3 = Vector3(0.0, 0.24, 3.5)
var ball_target_pos: Vector3 = Vector3(0.0, 1.2, -7.5)
var ball_flight_t: float = 0.0
var keeper_target_pos: Vector3 = Vector3(0.0, 0.0, -7.35)
var keeper_target_rot_z: float = 0.0
var shot_will_score: bool = true
var shot_outcome_text: String = ""

# HUD Nodes
var home_dots_box: HBoxContainer
var away_dots_box: HBoxContainer
var home_score_lbl: Label
var away_score_lbl: Label
var status_sub_lbl: Label
var shooter_logo_rect: TextureRect
var shooter_name_lbl: Label
var shooter_stats_lbl: Label
var keeper_logo_rect: TextureRect
var keeper_name_lbl: Label
var keeper_stats_lbl: Label
var aim_reticle: Control
var power_bar_bg: Control
var power_sweet_zone: ColorRect
var power_marker_tri: Label
var shoot_btn: Button
var aim_btn: Button
var center_banner_lbl: Label

func setup_match(m_ctrl: Node, canvas: CanvasLayer, home_id: String, away_id: String, fix_ref: Dictionary) -> void:
    main_ctrl = m_ctrl
    fixture_context = fix_ref
    home_team = GameDatabase.get_team(home_id)
    away_team = GameDatabase.get_team(away_id)
    home_takers = GameDatabase.get_team_penalty_takers(home_id)
    away_takers = GameDatabase.get_team_penalty_takers(away_id)
    home_gk = GameDatabase.get_team_goalkeeper(home_id)
    away_gk = GameDatabase.get_team_goalkeeper(away_id)

    _build_3d_stadium()
    _build_hud(canvas)
    _prepare_next_kick()

func _exit_tree() -> void:
    if hud_root != null and is_instance_valid(hud_root):
        hud_root.queue_free()

func _build_3d_stadium() -> void:
    # World Environment & Stadium Night Floodlights
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.05, 0.08, 0.14)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.62, 0.68, 0.78)
    env.ambient_light_energy = 1.15
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -22, 0)
    sun.light_energy = 1.45
    sun.shadow_enabled = true
    add_child(sun)

    # Camera positioned behind and slightly left of kicker (matching screenshot)
    camera = Camera3D.new()
    camera.position = Vector3(-0.65, 1.88, 7.65)
    camera.look_at_from_position(camera.position, Vector3(0.0, 1.25, -7.5), Vector3.UP)
    camera.fov = 44.0
    add_child(camera)

    # Pitch Grass with mowed stripes
    var pitch_mesh := PlaneMesh.new()
    pitch_mesh.size = Vector2(46.0, 36.0)
    var pitch_inst := MeshInstance3D.new()
    pitch_inst.mesh = pitch_mesh
    var pitch_mat := StandardMaterial3D.new()
    pitch_mat.albedo_texture = _make_grass_texture()
    pitch_mat.roughness = 0.88
    pitch_inst.material_override = pitch_mat
    add_child(pitch_inst)

    # White pitch lines (Goal line, 18-yard box line, 6-yard box, penalty spot)
    _add_pitch_line(Vector3(0, 0.01, -7.5), Vector2(36.0, 0.14))
    _add_pitch_line(Vector3(0, 0.01, -2.0), Vector2(18.3, 0.10))
    _add_pitch_line(Vector3(-9.15, 0.01, -4.75), Vector2(0.10, 5.5))
    _add_pitch_line(Vector3(9.15, 0.01, -4.75), Vector2(0.10, 5.5))
    _add_pitch_line(Vector3(0, 0.01, 5.4), Vector2(34.0, 0.10))
    _add_pitch_line(Vector3(0, 0.015, 3.5), Vector2(0.26, 0.26)) # Penalty spot

    # 3D Goal Frame (Width 7.32m: X from -3.66 to +3.66, Height 2.44m, Z = -7.5)
    var post_mat := StandardMaterial3D.new()
    post_mat.albedo_color = Color(0.96, 0.97, 0.99)
    post_mat.roughness = 0.3

    _add_cylinder_part(Vector3(-3.66, 1.22, -7.5), 0.08, 2.44, Vector3.ZERO, post_mat)
    _add_cylinder_part(Vector3(3.66, 1.22, -7.5), 0.08, 2.44, Vector3.ZERO, post_mat)
    _add_cylinder_part(Vector3(0.0, 2.44, -7.5), 0.08, 7.48, Vector3(0, 0, 90), post_mat)
    # Back stanchions
    _add_cylinder_part(Vector3(-3.66, 1.22, -9.1), 0.05, 2.44, Vector3.ZERO, post_mat)
    _add_cylinder_part(Vector3(3.66, 1.22, -9.1), 0.05, 2.44, Vector3.ZERO, post_mat)
    _add_cylinder_part(Vector3(-3.66, 2.44, -8.3), 0.05, 1.6, Vector3(90, 0, 0), post_mat)
    _add_cylinder_part(Vector3(3.66, 2.44, -8.3), 0.05, 1.6, Vector3(90, 0, 0), post_mat)

    # Procedural 3D Goal Net Mesh
    net_mesh_inst = MeshInstance3D.new()
    net_mesh_inst.mesh = _build_goal_net_mesh()
    var net_mat := StandardMaterial3D.new()
    net_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    net_mat.albedo_color = Color(0.92, 0.94, 0.98, 0.78)
    net_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    net_mesh_inst.material_override = net_mat
    add_child(net_mesh_inst)

    # UEFA-Style Ad Boards behind the goal
    var ad_mesh := BoxMesh.new()
    ad_mesh.size = Vector3(34.0, 1.15, 0.15)
    var ad_inst := MeshInstance3D.new()
    ad_inst.mesh = ad_mesh
    ad_inst.position = Vector3(0, 0.58, -10.6)
    var ad_mat := StandardMaterial3D.new()
    ad_mat.albedo_texture = _make_ad_board_texture()
    ad_mat.roughness = 0.5
    ad_inst.material_override = ad_mat
    add_child(ad_inst)

    # 3D Stadium Stands & Animated Crowd MultiMesh behind the goal
    _build_stadium_stands_and_crowd()

    # 3D Ball on Penalty Spot
    ball_node = _build_ball_node()
    ball_node.position = ball_start_pos
    add_child(ball_node)

    # 3D Kicker and 3D Goalkeeper
    kicker_node = _build_humanoid_player(true)
    add_child(kicker_node)
    keeper_node = _build_humanoid_player(false)
    add_child(keeper_node)

func _add_pitch_line(pos: Vector3, sz: Vector2) -> void:
    var pm := PlaneMesh.new()
    pm.size = sz
    var mi := MeshInstance3D.new()
    mi.mesh = pm
    mi.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.92, 0.95, 0.92)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mi.material_override = mat
    add_child(mi)

func _add_cylinder_part(pos: Vector3, radius: float, height: float, rot_deg: Vector3, mat: Material) -> void:
    var cm := CylinderMesh.new()
    cm.top_radius = radius
    cm.bottom_radius = radius
    cm.height = height
    var mi := MeshInstance3D.new()
    mi.mesh = cm
    mi.position = pos
    mi.rotation_degrees = rot_deg
    mi.material_override = mat
    add_child(mi)

func _build_goal_net_mesh() -> ImmediateMesh:
    var im := ImmediateMesh.new()
    im.surface_begin(Mesh.PRIMITIVE_LINES)
    var x0: float = -3.66
    var x1: float = 3.66
    var y0: float = 0.0
    var y1: float = 2.44
    var z_front: float = -7.52
    var z_back: float = -9.1

    var cols: int = 38
    var rows: int = 16
    var depth_steps: int = 9

    # Back net grid
    for c in range(cols + 1):
        var x: float = lerpf(x0, x1, float(c) / float(cols))
        im.surface_add_vertex(Vector3(x, y0, z_back))
        im.surface_add_vertex(Vector3(x, y1, z_back))
        # Top roof net lines
        im.surface_add_vertex(Vector3(x, y1, z_front))
        im.surface_add_vertex(Vector3(x, y1, z_back))
    for r in range(rows + 1):
        var y: float = lerpf(y0, y1, float(r) / float(rows))
        im.surface_add_vertex(Vector3(x0, y, z_back))
        im.surface_add_vertex(Vector3(x1, y, z_back))
        # Left & right side net horizontal lines
        im.surface_add_vertex(Vector3(x0, y, z_front))
        im.surface_add_vertex(Vector3(x0, y, z_back))
        im.surface_add_vertex(Vector3(x1, y, z_front))
        im.surface_add_vertex(Vector3(x1, y, z_back))
    for d in range(depth_steps + 1):
        var z: float = lerpf(z_front, z_back, float(d) / float(depth_steps))
        im.surface_add_vertex(Vector3(x0, y0, z))
        im.surface_add_vertex(Vector3(x0, y1, z))
        im.surface_add_vertex(Vector3(x1, y0, z))
        im.surface_add_vertex(Vector3(x1, y1, z))
        im.surface_add_vertex(Vector3(x0, y1, z))
        im.surface_add_vertex(Vector3(x1, y1, z))

    im.surface_end()
    return im

func _build_stadium_stands_and_crowd() -> void:
    var stand_mat := StandardMaterial3D.new()
    stand_mat.albedo_color = Color(0.11, 0.14, 0.22)
    for tier in range(8):
        var bm := BoxMesh.new()
        bm.size = Vector3(38.0, 0.75, 1.3)
        var mi := MeshInstance3D.new()
        mi.mesh = bm
        mi.position = Vector3(0.0, 1.2 + tier * 0.68, -12.2 - tier * 1.1)
        mi.material_override = stand_mat
        add_child(mi)

    # Team Banner in right stand (like the club flag in screenshot)
    var flag_mesh := BoxMesh.new()
    flag_mesh.size = Vector3(4.2, 2.3, 0.1)
    var flag_inst := MeshInstance3D.new()
    flag_inst.mesh = flag_mesh
    flag_inst.position = Vector3(9.5, 3.0, -12.5)
    var flag_mat := StandardMaterial3D.new()
    flag_mat.albedo_texture = ProceduralArt.get_team_logo(away_team, 128)
    flag_inst.material_override = flag_mat
    add_child(flag_inst)

    # MultiMesh Crowd Spectators
    crowd_multimesh = MultiMeshInstance3D.new()
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    var spec_mesh := BoxMesh.new()
    spec_mesh.size = Vector3(0.36, 0.68, 0.28)
    var spec_mat := StandardMaterial3D.new()
    spec_mat.vertex_color_use_as_albedo = true
    spec_mesh.material = spec_mat
    mm.mesh = spec_mesh

    var total_fans: int = 360
    mm.instance_count = total_fans
    var idx: int = 0
    for tier in range(8):
        for s in range(45):
            if idx >= total_fans:
                break
            var x: float = -16.5 + s * 0.75 + randf_range(-0.12, 0.12)
            var y: float = 1.75 + tier * 0.68
            var z: float = -12.1 - tier * 1.1
            var xf := Transform3D(Basis(), Vector3(x, y, z))
            mm.set_instance_transform(idx, xf)
            var fan_col := Color(0.88, 0.90, 0.95) if (idx % 3 != 0) else Color(0.18, 0.28, 0.52)
            mm.set_instance_color(idx, fan_col)
            idx += 1

    crowd_multimesh.multimesh = mm
    add_child(crowd_multimesh)

func _build_ball_node() -> Node3D:
    var root := Node3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.22
    sm.height = 0.44
    var mi := MeshInstance3D.new()
    mi.mesh = sm
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = _make_starball_texture()
    mat.roughness = 0.35
    mi.material_override = mat
    root.add_child(mi)
    return root

func _build_humanoid_player(is_kicker: bool) -> Node3D:
    var root := Node3D.new()
    var kit_mat := StandardMaterial3D.new()
    kit_mat.albedo_color = Color(0.95, 0.95, 0.97) if is_kicker else Color(0.05, 0.65, 0.28)
    var skin_mat := StandardMaterial3D.new()
    skin_mat.albedo_color = Color(0.88, 0.69, 0.54)
    var hair_mat := StandardMaterial3D.new()
    hair_mat.albedo_color = Color(0.12, 0.10, 0.09)

    # Torso
    var torso := MeshInstance3D.new()
    var tm := BoxMesh.new()
    tm.size = Vector3(0.52, 0.72, 0.28)
    torso.mesh = tm
    torso.position = Vector3(0, 1.18, 0)
    torso.material_override = kit_mat
    torso.name = "Torso"
    root.add_child(torso)

    # Jersey Back Number + Name Plate for Kicker
    if is_kicker:
        var back_plate := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(0.46, 0.58)
        back_plate.mesh = pm
        back_plate.position = Vector3(0, 1.19, 0.145)
        back_plate.rotation_degrees = Vector3(90, 0, 0)
        back_plate.name = "JerseyBack"
        root.add_child(back_plate)

    # Shorts
    var shorts := MeshInstance3D.new()
    var shm := BoxMesh.new()
    shm.size = Vector3(0.50, 0.32, 0.27)
    shorts.mesh = shm
    shorts.position = Vector3(0, 0.72, 0)
    shorts.material_override = kit_mat
    shorts.name = "Shorts"
    root.add_child(shorts)

    # Legs
    for side in [-1, 1]:
        var leg := MeshInstance3D.new()
        var lm := CylinderMesh.new()
        lm.top_radius = 0.09
        lm.bottom_radius = 0.07
        lm.height = 0.62
        leg.mesh = lm
        leg.position = Vector3(side * 0.15, 0.31, 0)
        leg.material_override = kit_mat
        root.add_child(leg)

        # Arms
        var arm := MeshInstance3D.new()
        var am := CylinderMesh.new()
        am.top_radius = 0.07
        am.bottom_radius = 0.06
        am.height = 0.56
        arm.mesh = am
        arm.position = Vector3(side * 0.34, 1.12, 0)
        arm.rotation_degrees = Vector3(0, 0, side * -18 if is_kicker else side * -38)
        arm.material_override = kit_mat
        root.add_child(arm)

    # Head + Hair
    var head := MeshInstance3D.new()
    var hm := SphereMesh.new()
    hm.radius = 0.16
    hm.height = 0.32
    head.mesh = hm
    head.position = Vector3(0, 1.72, 0)
    head.material_override = skin_mat
    root.add_child(head)

    var hair := MeshInstance3D.new()
    var hrm := SphereMesh.new()
    hrm.radius = 0.165
    hrm.height = 0.20
    hair.mesh = hrm
    hair.position = Vector3(0, 1.79, 0.01)
    hair.material_override = hair_mat
    root.add_child(hair)

    # Red / Blue Overhead Indicator Triangle (matching screenshot!)
    var marker := MeshInstance3D.new()
    var mm := PrismMesh.new()
    mm.size = Vector3(0.22, 0.22, 0.06)
    marker.mesh = mm
    marker.position = Vector3(0, 2.15, 0)
    marker.rotation_degrees = Vector3(0, 0, 180)
    var m_mat := StandardMaterial3D.new()
    m_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m_mat.albedo_color = Color(0.95, 0.12, 0.15) if is_kicker else Color(0.10, 0.62, 0.98)
    marker.material_override = m_mat
    root.add_child(marker)

    return root

func _update_player_models_for_turn(shooter: Dictionary, keeper: Dictionary, s_team: Dictionary, k_team: Dictionary) -> void:
    # Kicker stance on left-behind the ball (matching Valverde in screenshot)
    kicker_node.position = Vector3(-1.05, 0.0, 5.15)
    kicker_node.rotation_degrees = Vector3(0, -10, 0)

    var s_col := Color.from_string(str(s_team.get("color1", "#ffffff")), Color.WHITE)
    var torso_mesh: MeshInstance3D = kicker_node.get_node("Torso")
    var t_mat := StandardMaterial3D.new()
    t_mat.albedo_color = s_col
    torso_mesh.material_override = t_mat

    var back_plate: MeshInstance3D = kicker_node.get_node("JerseyBack")
    var bp_mat := StandardMaterial3D.new()
    bp_mat.albedo_texture = _make_jersey_back_texture(str(shooter.get("name", "PLAYER")), int(shooter.get("number", 15)), s_col)
    back_plate.material_override = bp_mat

    # Goalkeeper centered on goal line
    keeper_node.position = Vector3(0.0, 0.0, -7.35)
    keeper_node.rotation_degrees = Vector3.ZERO

func _make_jersey_back_texture(p_name: String, num: int, bg_col: Color) -> ImageTexture:
    var img := Image.create(96, 128, false, Image.FORMAT_RGBA8)
    img.fill(bg_col)
    var text_col: Color = Color(0.1, 0.12, 0.16) if bg_col.get_luminance() > 0.55 else Color.WHITE
    var clean_name: String = p_name.to_upper()
    if clean_name.find(". ") != -1:
        clean_name = clean_name.split(". ")[1]
    ProceduralArt._draw_pixel_text(img, clean_name.substr(0, 8), 48, 22, 2, text_col)
    ProceduralArt._draw_pixel_text(img, str(num), 48, 72, 7, text_col)
    return ImageTexture.create_from_image(img)

func _make_grass_texture() -> ImageTexture:
    var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    for y in range(256):
        var stripe: bool = (int(y / 24) % 2 == 0)
        var base: Color = Color(0.18, 0.46, 0.19) if stripe else Color(0.15, 0.40, 0.16)
        for x in range(256):
            var n: float = randf_range(-0.02, 0.02)
            img.set_pixel(x, y, Color(base.r + n, base.g + n, base.b + n, 1.0))
    return ImageTexture.create_from_image(img)

func _make_ad_board_texture() -> ImageTexture:
    var img := Image.create(512, 64, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.05, 0.13, 0.34))
    for x in range(512):
        for y in range(64):
            # Starball circles along board
            var d1: float = Vector2(x - 200, y - 32).length()
            var d2: float = Vector2(x - 330, y - 32).length()
            if (d1 < 22.0 and int(d1) % 5 != 0) or (d2 < 22.0 and int(d2) % 5 != 0):
                img.set_pixel(x, y, Color(0.85, 0.92, 1.0))
    ProceduralArt._draw_pixel_text(img, "CHAMPIONS", 92, 32, 3, Color.WHITE)
    ProceduralArt._draw_pixel_text(img, "CHAMPIONS", 430, 32, 3, Color.WHITE)
    return ImageTexture.create_from_image(img)

func _make_starball_texture() -> ImageTexture:
    var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    img.fill(Color.WHITE)
    for y in range(128):
        for x in range(128):
            if (int(x / 22) + int(y / 22)) % 3 == 0:
                img.set_pixel(x, y, Color(0.08, 0.22, 0.56))
    return ImageTexture.create_from_image(img)

func _build_hud(canvas: CanvasLayer) -> void:
    hud_root = Control.new()
    hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
    canvas.add_child(hud_root)

    # 1. TOP-LEFT UEFA-STYLE SCOREBOARD (Matching reference image)
    var sb_panel := PanelContainer.new()
    sb_panel.position = Vector2(26, 20)
    sb_panel.custom_minimum_size = Vector2(390, 122)
    var sb_style := StyleBoxFlat.new()
    sb_style.bg_color = Color(0.04, 0.09, 0.20, 0.90)
    sb_style.border_color = Color(0.18, 0.45, 0.85, 0.9)
    sb_style.set_border_width_all(2)
    sb_style.set_corner_radius_all(6)
    sb_panel.add_theme_stylebox_override("panel", sb_style)
    hud_root.add_child(sb_panel)

    var sb_vbox := VBoxContainer.new()
    sb_vbox.add_theme_constant_override("separation", 4)
    sb_panel.add_child(sb_vbox)

    # Home row
    var h_row := HBoxContainer.new()
    h_row.add_theme_constant_override("separation", 10)
    sb_vbox.add_child(h_row)

    var h_crest := TextureRect.new()
    h_crest.custom_minimum_size = Vector2(36, 36)
    h_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    h_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    h_crest.texture = ProceduralArt.get_team_logo(home_team, 64)
    h_row.add_child(h_crest)

    var h_short := Label.new()
    h_short.text = str(home_team.get("short_name", "HOM"))
    h_short.custom_minimum_size = Vector2(56, 0)
    h_short.add_theme_font_size_override("font_size", 22)
    h_row.add_child(h_short)

    home_dots_box = HBoxContainer.new()
    home_dots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    home_dots_box.add_theme_constant_override("separation", 8)
    h_row.add_child(home_dots_box)

    home_score_lbl = Label.new()
    home_score_lbl.text = "0"
    home_score_lbl.custom_minimum_size = Vector2(36, 0)
    home_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    home_score_lbl.add_theme_font_size_override("font_size", 26)
    h_row.add_child(home_score_lbl)

    # Away row
    var a_row := HBoxContainer.new()
    a_row.add_theme_constant_override("separation", 10)
    sb_vbox.add_child(a_row)

    var a_crest := TextureRect.new()
    a_crest.custom_minimum_size = Vector2(36, 36)
    a_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    a_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    a_crest.texture = ProceduralArt.get_team_logo(away_team, 64)
    a_row.add_child(a_crest)

    var a_short := Label.new()
    a_short.text = str(away_team.get("short_name", "AWY"))
    a_short.custom_minimum_size = Vector2(56, 0)
    a_short.add_theme_font_size_override("font_size", 22)
    a_row.add_child(a_short)

    away_dots_box = HBoxContainer.new()
    away_dots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    away_dots_box.add_theme_constant_override("separation", 8)
    a_row.add_child(away_dots_box)

    away_score_lbl = Label.new()
    away_score_lbl.text = "0"
    away_score_lbl.custom_minimum_size = Vector2(36, 0)
    away_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    away_score_lbl.add_theme_font_size_override("font_size", 26)
    a_row.add_child(away_score_lbl)

    status_sub_lbl = Label.new()
    status_sub_lbl.text = "  PENALTY SHOOTOUT"
    status_sub_lbl.add_theme_font_size_override("font_size", 15)
    status_sub_lbl.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
    sb_vbox.add_child(status_sub_lbl)

    # 2. TOP-RIGHT PAUSE BUTTON (II)
    var pause_btn := Button.new()
    pause_btn.text = "II"
    pause_btn.position = Vector2(1204, 20)
    pause_btn.custom_minimum_size = Vector2(54, 54)
    pause_btn.add_theme_font_size_override("font_size", 24)
    pause_btn.pressed.connect(_on_pause_pressed)
    hud_root.add_child(pause_btn)

    # 3. GOAL AIM RETICLE (Draggable inside the 3D goal mouth on screen)
    aim_reticle = Control.new()
    aim_reticle.custom_minimum_size = Vector2(46, 46)
    var ret_ring := ColorRect.new()
    ret_ring.custom_minimum_size = Vector2(36, 36)
    ret_ring.position = Vector2(-18, -18)
    ret_ring.color = Color(1.0, 0.92, 0.15, 0.85)
    aim_reticle.add_child(ret_ring)
    var ret_inner := ColorRect.new()
    ret_inner.custom_minimum_size = Vector2(12, 12)
    ret_inner.position = Vector2(-6, -6)
    ret_inner.color = Color(0.95, 0.15, 0.15, 1.0)
    aim_reticle.add_child(ret_inner)
    hud_root.add_child(aim_reticle)

    # 4. BOTTOM-LEFT SHOOTER BAR (Crest + Number + Name + Ratings + Green Bar)
    var s_bar := PanelContainer.new()
    s_bar.position = Vector2(26, 634)
    s_bar.custom_minimum_size = Vector2(320, 62)
    s_bar.add_theme_stylebox_override("panel", sb_style)
    hud_root.add_child(s_bar)

    var s_hbox := HBoxContainer.new()
    s_hbox.add_theme_constant_override("separation", 10)
    s_bar.add_child(s_hbox)

    shooter_logo_rect = TextureRect.new()
    shooter_logo_rect.custom_minimum_size = Vector2(46, 46)
    shooter_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    shooter_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    s_hbox.add_child(shooter_logo_rect)

    var s_vbox := VBoxContainer.new()
    s_hbox.add_child(s_vbox)

    shooter_name_lbl = Label.new()
    shooter_name_lbl.add_theme_font_size_override("font_size", 18)
    s_vbox.add_child(shooter_name_lbl)

    shooter_stats_lbl = Label.new()
    shooter_stats_lbl.add_theme_font_size_override("font_size", 13)
    shooter_stats_lbl.add_theme_color_override("font_color", Color(0.2, 0.98, 0.55))
    s_vbox.add_child(shooter_stats_lbl)

    # 5. BOTTOM-RIGHT GOALKEEPER BAR (Name + Number + Ratings + Crest)
    var k_bar := PanelContainer.new()
    k_bar.position = Vector2(934, 634)
    k_bar.custom_minimum_size = Vector2(320, 62)
    k_bar.add_theme_stylebox_override("panel", sb_style)
    hud_root.add_child(k_bar)

    var k_hbox := HBoxContainer.new()
    k_hbox.alignment = BoxContainer.ALIGNMENT_END
    k_hbox.add_theme_constant_override("separation", 10)
    k_bar.add_child(k_hbox)

    var k_vbox := VBoxContainer.new()
    k_hbox.add_child(k_vbox)

    keeper_name_lbl = Label.new()
    keeper_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    keeper_name_lbl.add_theme_font_size_override("font_size", 18)
    k_vbox.add_child(keeper_name_lbl)

    keeper_stats_lbl = Label.new()
    keeper_stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    keeper_stats_lbl.add_theme_font_size_override("font_size", 13)
    keeper_stats_lbl.add_theme_color_override("font_color", Color(0.2, 0.98, 0.55))
    k_vbox.add_child(keeper_stats_lbl)

    keeper_logo_rect = TextureRect.new()
    keeper_logo_rect.custom_minimum_size = Vector2(46, 46)
    keeper_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    keeper_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    k_hbox.add_child(keeper_logo_rect)

    # 6. BOTTOM-CENTER POWER & TIMING BAR (Green / Yellow / Red with ▲ marker)
    power_bar_bg = Control.new()
    power_bar_bg.position = Vector2(500, 642)
    power_bar_bg.custom_minimum_size = Vector2(280, 26)
    hud_root.add_child(power_bar_bg)

    var pb_dark := ColorRect.new()
    pb_dark.color = Color(0.12, 0.14, 0.16, 0.92)
    pb_dark.custom_minimum_size = Vector2(280, 20)
    power_bar_bg.add_child(pb_dark)

    var pb_red := ColorRect.new()
    pb_red.color = Color(0.92, 0.18, 0.14)
    pb_red.position = Vector2(16, 4)
    pb_red.size = Vector2(248, 12)
    power_bar_bg.add_child(pb_red)

    var pb_yel := ColorRect.new()
    pb_yel.color = Color(0.96, 0.84, 0.12)
    pb_yel.position = Vector2(64, 4)
    pb_yel.size = Vector2(152, 12)
    power_bar_bg.add_child(pb_yel)

    power_sweet_zone = ColorRect.new()
    power_sweet_zone.color = Color(0.12, 0.92, 0.28)
    power_sweet_zone.position = Vector2(100, 4)
    power_sweet_zone.size = Vector2(80, 12)
    power_bar_bg.add_child(power_sweet_zone)

    power_marker_tri = Label.new()
    power_marker_tri.text = "▲"
    power_marker_tri.add_theme_font_size_override("font_size", 22)
    power_marker_tri.position = Vector2(130, 16)
    power_bar_bg.add_child(power_marker_tri)

    # 7. RIGHT-SIDE CIRCULAR AIM & SHOOT BUTTONS (Matching screenshot)
    var round_btn_style := StyleBoxFlat.new()
    round_btn_style.bg_color = Color(0.12, 0.18, 0.15, 0.88)
    round_btn_style.border_color = Color(0.65, 0.75, 0.70, 0.85)
    round_btn_style.set_border_width_all(2)
    round_btn_style.set_corner_radius_all(48)

    aim_btn = Button.new()
    aim_btn.text = "⊕\nAIM"
    aim_btn.position = Vector2(1162, 422)
    aim_btn.custom_minimum_size = Vector2(94, 94)
    aim_btn.add_theme_stylebox_override("normal", round_btn_style)
    aim_btn.pressed.connect(func() -> void:
        # Cycles quick corner presets or drag directly in goal
        var corners: Array[Vector2] = [
            Vector2(-0.72, 0.78), Vector2(0.72, 0.78),
            Vector2(-0.75, 0.22), Vector2(0.75, 0.22), Vector2(0.0, 0.55)
        ]
        base_aim_uv = corners[randi() % corners.size()]
        gk_dive_uv = base_aim_uv
    )
    hud_root.add_child(aim_btn)

    shoot_btn = Button.new()
    shoot_btn.text = "👟\nSHOOT"
    shoot_btn.position = Vector2(1162, 526)
    shoot_btn.custom_minimum_size = Vector2(94, 94)
    shoot_btn.add_theme_stylebox_override("normal", round_btn_style)
    shoot_btn.pressed.connect(_on_action_button_pressed)
    hud_root.add_child(shoot_btn)

    # Center Announcement Banner
    center_banner_lbl = Label.new()
    center_banner_lbl.position = Vector2(290, 90)
    center_banner_lbl.custom_minimum_size = Vector2(700, 64)
    center_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    center_banner_lbl.add_theme_font_size_override("font_size", 36)
    center_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.22))
    hud_root.add_child(center_banner_lbl)

    _refresh_scoreboard_dots()

func _refresh_scoreboard_dots() -> void:
    for c in home_dots_box.get_children():
        c.queue_free()
    for c in away_dots_box.get_children():
        c.queue_free()

    var total_slots: int = max(5, max(home_results.size(), away_results.size()))
    var start_idx: int = max(0, total_slots - 5)

    for i in range(start_idx, start_idx + 5):
        home_dots_box.add_child(_create_dot_indicator(home_results[i] if i < home_results.size() else -1))
        away_dots_box.add_child(_create_dot_indicator(away_results[i] if i < away_results.size() else -1))

    home_score_lbl.text = str(home_score)
    away_score_lbl.text = str(away_score)
    if round_index >= 5:
        status_sub_lbl.text = "  SUDDEN DEATH  •  ROUND " + str(round_index + 1)
    else:
        status_sub_lbl.text = "  PENALTY SHOOTOUT  •  KICK " + str(round_index + 1) + "/5"

func _create_dot_indicator(state: int) -> Panel:
    var p := Panel.new()
    p.custom_minimum_size = Vector2(22, 22)
    var st := StyleBoxFlat.new()
    st.set_corner_radius_all(11)
    if state == 1:
        st.bg_color = Color(0.08, 0.92, 0.28)
    elif state == 0:
        st.bg_color = Color(0.95, 0.16, 0.18)
    else:
        st.bg_color = Color(0.1, 0.1, 0.1, 0.3)
        st.border_color = Color(0.65, 0.72, 0.80, 0.8)
        st.set_border_width_all(2)
    p.add_theme_stylebox_override("panel", st)
    return p

func _prepare_next_kick() -> void:
    if _check_shootout_winner():
        return

    phase = "AIMING"
    ball_node.position = ball_start_pos
    var shooter: Dictionary = _get_current_shooter()
    var keeper: Dictionary = _get_current_keeper()
    var s_team: Dictionary = home_team if is_user_kicking else away_team
    var k_team: Dictionary = away_team if is_user_kicking else home_team

    _update_player_models_for_turn(shooter, keeper, s_team, k_team)
    ProceduralArt.play_sfx("whistle")

    # Update Bottom Bars with Ratings
    shooter_logo_rect.texture = ProceduralArt.get_team_logo(s_team, 64)
    shooter_name_lbl.text = str(shooter.get("number", 9)) + "  " + str(shooter.get("name", "SHOOTER"))
    var s_sho: int = int(shooter.get("shooting", 75))
    var s_cmp: int = int(shooter.get("composure", 75))
    var s_acc: int = int(shooter.get("accuracy", 75))
    shooter_stats_lbl.text = "SHO " + str(s_sho) + "  CMP " + str(s_cmp) + "  ACC " + str(s_acc)

    keeper_logo_rect.texture = ProceduralArt.get_team_logo(k_team, 64)
    keeper_name_lbl.text = str(keeper.get("name", "KEEPER")) + "  " + str(keeper.get("number", 1))
    var k_ref: int = int(keeper.get("reflexes", 75))
    var k_div: int = int(keeper.get("diving", 75))
    var k_pos: int = int(keeper.get("positioning", 75))
    keeper_stats_lbl.text = "REF " + str(k_ref) + "  DIV " + str(k_div) + "  POS " + str(k_pos)

    # Calculate Difficulty Parameters from Shooter vs Goalkeeper Ratings
    var s_avg: float = float(s_sho + s_cmp + s_acc) / 3.0
    var k_avg: float = float(k_ref + k_div + k_pos) / 3.0
    var rating_delta: float = (s_avg - k_avg) # Positive = strong shooter vs weak keeper

    # Weak shooter vs Strong keeper -> fast power bar, tiny sweet spot, heavy aim wobble
    power_marker_speed = clampf(1.25 - rating_delta * 0.022, 0.65, 2.15)
    sweet_spot_half_width = clampf(0.14 + rating_delta * 0.0035, 0.055, 0.24)
    wobble_amount = clampf(0.065 - (float(s_acc) - 70.0) * 0.002, 0.01, 0.14)

    # Resize visual green zone on the power bar
    var green_w: float = sweet_spot_half_width * 2.0 * 248.0
    power_sweet_zone.size = Vector2(green_w, 12)
    power_sweet_zone.position = Vector2(140.0 - green_w * 0.5, 4)

    if is_user_kicking:
        shoot_btn.text = "👟\nSHOOT"
        aim_btn.text = "⊕\nAIM"
        center_banner_lbl.text = "DRAG TARGET IN GOAL & TAP SHOOT!"
    else:
        shoot_btn.text = "🧤\nDIVE"
        aim_btn.text = "🧤\nZONE"
        center_banner_lbl.text = "GOALKEEPER TURN: DRAG GLOVE & TAP DIVE!"

func _get_current_shooter() -> Dictionary:
    var list: Array = home_takers if is_user_kicking else away_takers
    return list[round_index % max(1, list.size())]

func _get_current_keeper() -> Dictionary:
    return away_gk if is_user_kicking else home_gk

func _input(event: InputEvent) -> void:
    if phase != "AIMING" or shootout_over:
        return
    if event is InputEventScreenTouch or event is InputEventMouseButton:
        var pos: Vector2 = event.position
        # Check if touch is inside the upper-center goal area on screen
        if pos.x >= 260 and pos.x <= 1020 and pos.y >= 110 and pos.y <= 430:
            is_dragging_aim = event.pressed
            if is_dragging_aim:
                _update_aim_from_screen(pos)
    elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and is_dragging_aim:
        _update_aim_from_screen(event.position)

func _update_aim_from_screen(screen_pos: Vector2) -> void:
    var nx: float = clampf((screen_pos.x - 640.0) / 290.0, -1.05, 1.05)
    var ny: float = clampf(1.0 - (screen_pos.y - 140.0) / 230.0, 0.05, 1.08)
    if is_user_kicking:
        base_aim_uv = Vector2(nx, ny)
    else:
        gk_dive_uv = Vector2(nx, ny)

func _process(delta: float) -> void:
    if shootout_over:
        return

    # Subtle crowd bounce
    wobble_time += delta

    if phase == "AIMING":
        # Move power bar triangle marker back and forth
        power_marker_pos += power_marker_dir * power_marker_speed * delta
        if power_marker_pos >= 1.0:
            power_marker_pos = 1.0
            power_marker_dir = -1.0
        elif power_marker_pos <= 0.0:
            power_marker_pos = 0.0
            power_marker_dir = 1.0

        power_marker_tri.position.x = 16.0 + power_marker_pos * 248.0 - 8.0

        # Apply shooter composure/accuracy wobble to target reticle
        var target_uv: Vector2 = base_aim_uv if is_user_kicking else gk_dive_uv
        var wx: float = sin(wobble_time * 5.2) * cos(wobble_time * 3.1) * wobble_amount
        var wy: float = cos(wobble_time * 4.4) * wobble_amount * 0.8
        actual_aim_uv = target_uv + (Vector2(wx, wy) if is_user_kicking else Vector2.ZERO)

        var world_aim := Vector3(actual_aim_uv.x * 3.55, actual_aim_uv.y * 2.35, -7.5)
        aim_reticle.position = camera.unproject_position(world_aim)

        # Goalkeeper idle ready bounce
        keeper_node.position.y = abs(sin(wobble_time * 6.0)) * 0.08

    elif phase == "BALL_IN_FLIGHT":
        ball_flight_t += delta * 2.1
        var t: float = clampf(ball_flight_t, 0.0, 1.0)
        # Kicker run-up during first 0.25
        if t < 0.25:
            var rt: float = t / 0.25
            kicker_node.position = Vector3(-1.05, 0.0, 5.15).lerp(Vector3(-0.22, 0.0, 3.65), rt)
        else:
            var bt: float = (t - 0.25) / 0.75
            var flat_pos: Vector3 = ball_start_pos.lerp(ball_target_pos, bt)
            flat_pos.y += sin(bt * PI) * 0.65
            ball_node.position = flat_pos
            ball_node.rotate_x(-delta * 18.0)

            keeper_node.position = Vector3(0.0, 0.0, -7.35).lerp(keeper_target_pos, min(1.0, bt * 1.25))
            keeper_node.rotation_degrees.z = lerpf(0.0, keeper_target_rot_z, min(1.0, bt * 1.25))

        if t >= 1.0:
            _on_ball_arrived()

    elif phase == "RESULT_PAUSE":
        phase_timer -= delta
        if phase_timer <= 0.0:
            if is_user_kicking:
                is_user_kicking = false
            else:
                is_user_kicking = true
                round_index += 1
            _refresh_scoreboard_dots()
            _prepare_next_kick()

func _on_action_button_pressed() -> void:
    if phase != "AIMING" or shootout_over:
        return

    var shooter: Dictionary = _get_current_shooter()
    var keeper: Dictionary = _get_current_keeper()
    var timing_err: float = abs(power_marker_pos - 0.5) # 0.0 is dead center of green zone

    var s_sho: float = float(shooter.get("shooting", 75))
    var s_acc: float = float(shooter.get("accuracy", 75))
    var k_ref: float = float(keeper.get("reflexes", 75))
    var k_div: float = float(keeper.get("diving", 75))
    var k_pos: float = float(keeper.get("positioning", 75))

    var shot_uv: Vector2 = actual_aim_uv
    var dive_uv: Vector2 = gk_dive_uv

    if is_user_kicking:
        # User is shooting; Timing error outside sweet spot adds error or sends shot wide/high
        if timing_err > sweet_spot_half_width * 1.65:
            # Red zone: high risk of skying or pulling wide
            shot_uv.x += (0.42 if shot_uv.x >= 0.0 else -0.42) * (1.2 - (s_acc / 110.0))
            shot_uv.y += 0.45
        elif timing_err > sweet_spot_half_width:
            # Yellow zone: slight drift
            shot_uv += Vector2(randf_range(-0.18, 0.18), randf_range(-0.12, 0.22))

        # AI Goalkeeper uses Positioning & Reflexes to guess or read user's shot
        var read_chance: float = clampf(0.32 + (k_pos - s_acc) * 0.012, 0.18, 0.78)
        if randf() < read_chance:
            dive_uv = Vector2(shot_uv.x + randf_range(-0.22, 0.22), clampf(shot_uv.y, 0.15, 0.85))
        else:
            var dirs: Array[ float ] = [-0.75, 0.0, 0.75]
            dive_uv = Vector2(dirs[randi() % 3], randf_range(0.25, 0.75))
    else:
        # AI is shooting; User is diving as Goalkeeper!
        var ai_skill: float = (s_sho + s_acc + float(shooter.get("composure", 75))) / 3.0
        var miss_chance: float = clampf(0.22 - (ai_skill - 70.0) * 0.006, 0.05, 0.35)
        if randf() < miss_chance:
            shot_uv = Vector2(randf_range(-1.18, 1.18), randf_range(0.85, 1.28))
        else:
            var side: float = [-0.78, -0.45, 0.0, 0.45, 0.78][randi() % 5]
            shot_uv = Vector2(side, randf_range(0.18, 0.86))

    # Determine outcome: Off-target vs Saved vs Goal
    var in_goal_mouth: bool = (abs(shot_uv.x) <= 0.98 and shot_uv.y >= 0.0 and shot_uv.y <= 0.96)
    var dist_gk_to_ball: float = shot_uv.distance_to(dive_uv)
    # Better keeper diving + reflexes = larger save radius; harder shooter power = smaller save radius
    var save_reach: float = clampf(0.34 + (k_div + k_ref - s_sho) * 0.0045, 0.20, 0.54)
    if not is_user_kicking and timing_err <= sweet_spot_half_width:
        # Bonus reach when user times goalkeeper dive in the green zone!
        save_reach += 0.12

    if not in_goal_mouth:
        shot_will_score = false
        shot_outcome_text = "MISS! OFF TARGET!"
        ball_target_pos = Vector3(shot_uv.x * 3.85, shot_uv.y * 2.55, -8.5)
    elif dist_gk_to_ball <= save_reach:
        shot_will_score = false
        shot_outcome_text = "SAVED BY " + str(keeper.get("name", "KEEPER")) + "!"
        ball_target_pos = Vector3(shot_uv.x * 3.4, shot_uv.y * 2.2, -7.25)
    else:
        shot_will_score = true
        shot_outcome_text = "GOAL! " + str(shooter.get("name", "SCORER")) + "!"
        ball_target_pos = Vector3(shot_uv.x * 3.45, shot_uv.y * 2.25, -8.55)

    keeper_target_pos = Vector3(clampf(dive_uv.x * 3.1, -3.1, 3.1), clampf(dive_uv.y * 0.85, 0.0, 1.1), -7.30)
    if dive_uv.x < -0.2:
        keeper_target_rot_z = 68.0
    elif dive_uv.x > 0.2:
        keeper_target_rot_z = -68.0
    else:
        keeper_target_rot_z = 0.0

    ProceduralArt.play_sfx("kick")
    phase = "BALL_IN_FLIGHT"
    ball_flight_t = 0.0

func _on_ball_arrived() -> void:
    var shooter: Dictionary = _get_current_shooter()
    var keeper: Dictionary = _get_current_keeper()

    if shot_will_score:
        ProceduralArt.play_sfx("cheer")
        if is_user_kicking:
            home_score += 1
            home_results.append(1)
        else:
            away_score += 1
            away_results.append(1)
        shooter["season_pens_scored"] = int(shooter.get("season_pens_scored", 0)) + 1
        shooter["career_pens_scored"] = int(shooter.get("career_pens_scored", 0)) + 1
    else:
        if is_user_kicking:
            home_results.append(0)
        else:
            away_results.append(0)
        shooter["season_pens_missed"] = int(shooter.get("season_pens_missed", 0)) + 1
        shooter["career_pens_missed"] = int(shooter.get("career_pens_missed", 0)) + 1
        if shot_outcome_text.begins_with("SAVED"):
            keeper["season_saves"] = int(keeper.get("season_saves", 0)) + 1
            keeper["career_saves"] = int(keeper.get("career_saves", 0)) + 1

    center_banner_lbl.text = shot_outcome_text
    _refresh_scoreboard_dots()
    phase = "RESULT_PAUSE"
    phase_timer = 1.65

func _check_shootout_winner() -> bool:
    var h_taken: int = home_results.size()
    var a_taken: int = away_results.size()

    if h_taken < 5 or a_taken < 5:
        var h_rem: int = 5 - h_taken
        var a_rem: int = 5 - a_taken
        if home_score > away_score + a_rem or away_score > home_score + h_rem:
            _finish_shootout()
            return true
        return false
    else:
        if h_taken == a_taken and home_score != away_score:
            _finish_shootout()
            return true
        return false

func _finish_shootout() -> void:
    shootout_over = true
    var win_team: Dictionary = home_team if home_score > away_score else away_team
    center_banner_lbl.text = str(win_team.get("name", "WINNER")).to_upper() + " WINS (" + str(home_score) + " - " + str(away_score) + ")!"

    if not fixture_context.is_empty():
        SeasonManager.simulate_fixture(fixture_context, {
            "home_goals": int(fixture_context.get("home_goals", 1)),
            "away_goals": int(fixture_context.get("away_goals", 1)),
            "pen_home": home_score,
            "pen_away": away_score
        })
        GameDatabase.save_game()

    var end_panel := PanelContainer.new()
    end_panel.position = Vector2(420, 250)
    end_panel.custom_minimum_size = Vector2(440, 200)
    hud_root.add_child(end_panel)

    var vb := VBoxContainer.new()
    vb.alignment = BoxContainer.ALIGNMENT_CENTER
    vb.add_theme_constant_override("separation", 14)
    end_panel.add_child(vb)

    var res_lbl := Label.new()
    res_lbl.text = str(home_team.get("short_name", "HOM")) + " " + str(home_score) + " - " + str(away_score) + " " + str(away_team.get("short_name", "AWY"))
    res_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    res_lbl.add_theme_font_size_override("font_size", 28)
    vb.add_child(res_lbl)

    var rematch_btn := Button.new()
    rematch_btn.text = "PLAY REMATCH"
    rematch_btn.custom_minimum_size = Vector2(280, 48)
    rematch_btn.pressed.connect(func() -> void:
        main_ctrl.start_penalty_shootout(str(home_team["id"]), str(away_team["id"]), fixture_context)
    )
    vb.add_child(rematch_btn)

    var exit_btn := Button.new()
    exit_btn.text = "CONTINUE"
    exit_btn.custom_minimum_size = Vector2(280, 48)
    exit_btn.pressed.connect(func() -> void:
        if not fixture_context.is_empty():
            main_ctrl.show_season_screen()
        else:
            main_ctrl.show_main_menu()
    )
    vb.add_child(exit_btn)

func _on_pause_pressed() -> void:
    var pop := AcceptDialog.new()
    pop.title = "Match Paused"
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 10)

    var cam_btn := Button.new()
    cam_btn.text = "Switch Camera Angle (Standard / Broadcast Wide)"
    cam_btn.pressed.connect(func() -> void:
        if camera.position.z > 7.8:
            camera.position = Vector3(-0.65, 1.88, 7.65)
        else:
            camera.position = Vector3(0.0, 2.75, 9.5)
        camera.look_at_from_position(camera.position, Vector3(0.0, 1.25, -7.5), Vector3.UP)
    )
    vb.add_child(cam_btn)

    var restart_btn := Button.new()
    restart_btn.text = "Restart Penalty Shootout"
    restart_btn.pressed.connect(func() -> void:
        pop.hide()
        main_ctrl.start_penalty_shootout(str(home_team["id"]), str(away_team["id"]), fixture_context)
    )
    vb.add_child(restart_btn)

    var quit_btn := Button.new()
    quit_btn.text = "Quit to Main Menu"
    quit_btn.pressed.connect(func() -> void:
        pop.hide()
        main_ctrl.show_main_menu()
    )
    vb.add_child(quit_btn)

    pop.add_child(vb)
    hud_root.add_child(pop)
    pop.popup_centered(Vector2i(420, 240))
