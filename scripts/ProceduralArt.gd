extends Node

# Caches so procedural textures are generated once per item and reused instantly
var logo_cache: Dictionary = {}
var trophy_cache: Dictionary = {}
var player_photo_cache: Dictionary = {}

var audio_player_whistle: AudioStreamPlayer
var audio_player_kick: AudioStreamPlayer
var audio_player_crowd: AudioStreamPlayer
var sound_enabled: bool = true

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute("user://custom_images")
    _setup_procedural_audio()

func _setup_procedural_audio() -> void:
    audio_player_whistle = AudioStreamPlayer.new()
    audio_player_kick = AudioStreamPlayer.new()
    audio_player_crowd = AudioStreamPlayer.new()
    add_child(audio_player_whistle)
    add_child(audio_player_kick)
    add_child(audio_player_crowd)

    audio_player_whistle.stream = _create_tone_wav(0.45, "whistle")
    audio_player_kick.stream = _create_tone_wav(0.22, "kick")
    audio_player_crowd.stream = _create_tone_wav(1.4, "cheer")

func play_sfx(kind: String) -> void:
    if not sound_enabled:
        return
    if kind == "whistle" and audio_player_whistle:
        audio_player_whistle.play()
    elif kind == "kick" and audio_player_kick:
        audio_player_kick.play()
    elif kind == "cheer" and audio_player_crowd:
        audio_player_crowd.play()

func _create_tone_wav(duration: float, mode: String) -> AudioStreamWAV:
    var sample_rate: int = 22050
    var count: int = int(duration * sample_rate)
    var data: PackedByteArray = PackedByteArray()
    data.resize(count * 2)
    var prev: float = 0.0
    for i in range(count):
        var t: float = float(i) / float(sample_rate)
        var s: float = 0.0
        if mode == "whistle":
            var env: float = clampf(1.0 - (t / duration), 0.0, 1.0)
            var mod: float = 1.0 + 0.03 * sin(t * 140.0)
            s = sin(TAU * 2750.0 * mod * t) * 0.45 * env
        elif mode == "kick":
            var env: float = exp(-t * 20.0)
            var freq: float = 130.0 * exp(-t * 14.0) + 45.0
            s = sin(TAU * freq * t) * 0.85 * env
        else:
            var env: float = sin(clampf(t / duration, 0.0, 1.0) * PI)
            var noise: float = randf_range(-1.0, 1.0)
            prev = prev * 0.85 + noise * 0.15
            s = prev * 0.7 * env
        var pcm: int = clampi(int(s * 32000.0), -32767, 32767)
        data.encode_s16(i * 2, pcm)

    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = sample_rate
    wav.stereo = false
    wav.data = data
    return wav

func clear_cache_for_id(id_key: String) -> void:
    logo_cache.erase(id_key)
    trophy_cache.erase(id_key)
    player_photo_cache.erase(id_key)

# Loads an external image from phone gallery/storage and saves a copy in user://custom_images/
func import_custom_image(source_path: String, save_key: String) -> String:
    var img := Image.new()
    var err := img.load(source_path)
    if err != OK:
        return ""
    img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
    var dest_path: String = "user://custom_images/" + save_key + ".png"
    img.save_png(dest_path)
    clear_cache_for_id(save_key)
    return dest_path

func _load_custom_texture(path: String) -> ImageTexture:
    if path == "" or not FileAccess.file_exists(path):
        return null
    var img := Image.new()
    if img.load(path) == OK:
        return ImageTexture.create_from_image(img)
    return null

# Strictly 2D flat football club logo generator (no 3D bevels, no shadows)
func get_team_logo(team: Dictionary, size: int = 96) -> ImageTexture:
    var tid: String = str(team.get("id", "default"))
    var cache_key: String = tid + "_" + str(size)
    if logo_cache.has(cache_key):
        return logo_cache[cache_key]

    var custom_path: String = str(team.get("custom_logo", ""))
    var custom_tex := _load_custom_texture(custom_path)
    if custom_tex != null:
        logo_cache[cache_key] = custom_tex
        return custom_tex

    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))

    var c1 := Color.from_string(str(team.get("color1", "#1e5aa8")), Color(0.12, 0.35, 0.66))
    var c2 := Color.from_string(str(team.get("color2", "#f5c518")), Color(0.96, 0.77, 0.09))
    var shape_type: int = int(team.get("logo_shape", 0)) % 4
    var pattern_type: int = int(team.get("logo_pattern", 0)) % 4
    var cx: float = size * 0.5
    var cy: float = size * 0.5
    var r: float = size * 0.44

    for y in range(size):
        for x in range(size):
            var nx: float = (float(x) - cx) / r
            var ny: float = (float(y) - cy) / r
            var inside: bool = false
            var border: bool = false

            if shape_type == 0:
                # Classic flat 2D shield
                var top_ok: bool = ny >= -0.92
                var width_at_y: float = 0.88 if ny < 0.0 else max(0.0, 0.88 * (1.0 - pow(ny / 0.96, 1.35)))
                inside = top_ok and ny <= 0.95 and abs(nx) <= width_at_y
                border = inside and (ny < -0.78 or abs(nx) > width_at_y - 0.13 or ny > 0.82)
            elif shape_type == 1:
                # Flat 2D circle crest
                var d: float = sqrt(nx * nx + ny * ny)
                inside = d <= 0.95
                border = inside and d >= 0.80
            elif shape_type == 2:
                # Flat 2D diamond crest
                var md: float = abs(nx) * 1.05 + abs(ny) * 0.95
                inside = md <= 0.95
                border = inside and md >= 0.80
            else:
                # Flat 2D hexagon crest
                var qx: float = abs(nx)
                var qy: float = abs(ny)
                var hex_d: float = max(qx * 0.866 + qy * 0.5, qy)
                inside = hex_d <= 0.92
                border = inside and hex_d >= 0.78

            if inside:
                if border:
                    img.set_pixel(x, y, c2)
                else:
                    var fill_col: Color = c1
                    if pattern_type == 0:
                        # Vertical stripes (flat 2D)
                        if int(floor((nx + 1.0) * 3.5)) % 2 == 0:
                            fill_col = c1
                        else:
                            fill_col = c2
                    elif pattern_type == 1:
                        # Split halves (flat 2D)
                        fill_col = c1 if nx < 0.0 else c2
                    elif pattern_type == 2:
                        # Diagonal sash (flat 2D)
                        fill_col = c2 if abs(nx + ny * 0.85) < 0.24 else c1
                    else:
                        # Horizontal band (flat 2D)
                        fill_col = c2 if abs(ny) < 0.25 else c1
                    img.set_pixel(x, y, fill_col)

    # Draw flat 2D center badge plate + 3-letter pixel initials
    var short_name: String = str(team.get("short_name", "FC")).to_upper().substr(0, 3)
    var plate_w: int = int(size * 0.58)
    var plate_h: int = int(size * 0.26)
    var px0: int = int(cx - plate_w * 0.5)
    var py0: int = int(cy - plate_h * 0.5)
    for py in range(py0, py0 + plate_h):
        for px in range(px0, px0 + plate_w):
            if px >= 0 and px < size and py >= 0 and py < size:
                img.set_pixel(px, py, Color(0.08, 0.10, 0.14, 1.0))

    _draw_pixel_text(img, short_name, int(cx), int(cy), max(1, int(size / 36)), Color.WHITE)

    var tex := ImageTexture.create_from_image(img)
    logo_cache[cache_key] = tex
    return tex

# Flat 2D Trophy Generator
func get_trophy_icon(comp: Dictionary, size: int = 96) -> ImageTexture:
    var cid: String = str(comp.get("id", "trophy"))
    var cache_key: String = cid + "_" + str(size)
    if trophy_cache.has(cache_key):
        return trophy_cache[cache_key]

    var custom_path: String = str(comp.get("custom_trophy", ""))
    var custom_tex := _load_custom_texture(custom_path)
    if custom_tex != null:
        trophy_cache[cache_key] = custom_tex
        return custom_tex

    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))

    var metal := Color.from_string(str(comp.get("trophy_color", "#ffd700")), Color(1.0, 0.84, 0.0))
    var base_col := Color(0.22, 0.16, 0.10, 1.0)
    var style: int = int(comp.get("trophy_style", 0)) % 3
    var cx: float = size * 0.5

    for y in range(size):
        var ny: float = float(y) / float(size)
        for x in range(size):
            var nx: float = (float(x) - cx) / (size * 0.5)
            var ax: float = abs(nx)
            if ny >= 0.76 and ny <= 0.90 and ax <= 0.34:
                img.set_pixel(x, y, base_col)
            elif ny >= 0.72 and ny < 0.76 and ax <= 0.26:
                img.set_pixel(x, y, metal)
            elif style == 0:
                # Champions Cup with handles
                if ny >= 0.20 and ny < 0.56 and ax <= 0.30 * (1.0 - (ny - 0.20) * 0.7):
                    img.set_pixel(x, y, metal)
                elif ny >= 0.56 and ny < 0.72 and ax <= 0.10:
                    img.set_pixel(x, y, metal)
                elif ny >= 0.24 and ny <= 0.48 and ax >= 0.28 and ax <= 0.44:
                    if abs(ny - 0.36) > 0.07 or ax > 0.37:
                        img.set_pixel(x, y, metal)
            elif style == 1:
                # Championship Shield Plate
                var dy: float = (ny - 0.46) * 2.0
                if sqrt(nx * nx + dy * dy) <= 0.52:
                    img.set_pixel(x, y, metal)
            else:
                # Knockout Chalice
                if ny >= 0.18 and ny < 0.48 and ax <= 0.36 * (1.0 - (ny - 0.18)):
                    img.set_pixel(x, y, metal)
                elif ny >= 0.48 and ny < 0.72 and ax <= 0.08:
                    img.set_pixel(x, y, metal)

    var tex := ImageTexture.create_from_image(img)
    trophy_cache[cache_key] = tex
    return tex

# Procedural Player Portrait Generator
func get_player_photo(player: Dictionary, team_color: String = "#1e5aa8", size: int = 80) -> ImageTexture:
    var pid: String = str(player.get("id", "p0"))
    var cache_key: String = pid + "_" + str(size) + "_" + team_color
    if player_photo_cache.has(cache_key):
        return player_photo_cache[cache_key]

    var custom_path: String = str(player.get("custom_photo", ""))
    var custom_tex := _load_custom_texture(custom_path)
    if custom_tex != null:
        player_photo_cache[cache_key] = custom_tex
        return custom_tex

    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var kit_col := Color.from_string(team_color, Color(0.15, 0.38, 0.75))
    img.fill(Color(0.10, 0.14, 0.20, 1.0))

    var seed_val: int = abs(pid.hash())
    var skin_tones: Array[Color] = [
        Color(0.96, 0.82, 0.71),
        Color(0.88, 0.69, 0.54),
        Color(0.76, 0.54, 0.38),
        Color(0.55, 0.37, 0.24),
        Color(0.38, 0.25, 0.16)
    ]
    var hair_colors: Array[Color] = [
        Color(0.10, 0.09, 0.08),
        Color(0.28, 0.18, 0.10),
        Color(0.55, 0.38, 0.18),
        Color(0.82, 0.68, 0.32),
        Color(0.45, 0.16, 0.10)
    ]
    var skin: Color = skin_tones[int(player.get("skin_tone", seed_val % 5)) % 5]
    var hair: Color = hair_colors[int(player.get("hair_color", (seed_val / 5) % 5)) % 5]
    var cx: float = size * 0.5

    for y in range(size):
        var ny: float = float(y) / float(size)
        for x in range(size):
            var nx: float = (float(x) - cx) / (size * 0.5)
            # Kit shoulders
            if ny >= 0.68 and abs(nx) <= 0.72:
                img.set_pixel(x, y, kit_col)
                if ny <= 0.74 and abs(nx) <= 0.22:
                    img.set_pixel(x, y, Color.WHITE)
            # Neck
            elif ny >= 0.58 and ny < 0.70 and abs(nx) <= 0.16:
                img.set_pixel(x, y, skin.darkened(0.1))
            # Head oval
            var hx: float = nx / 0.32
            var hy: float = (ny - 0.40) / 0.22
            if hx * hx + hy * hy <= 1.0:
                if ny < 0.28 or (ny < 0.34 and abs(nx) > 0.22):
                    img.set_pixel(x, y, hair)
                else:
                    img.set_pixel(x, y, skin)
                    # Eyes
                    if abs(ny - 0.39) < 0.025 and (abs(nx - 0.11) < 0.035 or abs(nx + 0.11) < 0.035):
                        img.set_pixel(x, y, Color(0.1, 0.1, 0.1))
                    # Smile/Mouth
                    if abs(ny - 0.51) < 0.018 and abs(nx) < 0.09:
                        img.set_pixel(x, y, skin.darkened(0.32))

    var tex := ImageTexture.create_from_image(img)
    player_photo_cache[cache_key] = tex
    return tex

# Tiny 3x5 bitmap font renderer for crisp 2D initials on badges
func _draw_pixel_text(img: Image, text: String, center_x: int, center_y: int, scale: int, col: Color) -> void:
    var glyphs: Dictionary = {
        "A": ["010","101","111","101","101"],
        "B": ["110","101","110","101","110"],
        "C": ["011","100","100","100","011"],
        "D": ["110","101","101","101","110"],
        "E": ["111","100","110","100","111"],
        "F": ["111","100","110","100","100"],
        "G": ["011","100","101","101","011"],
        "H": ["101","101","111","101","101"],
        "I": ["111","010","010","010","111"],
        "J": ["001","001","001","101","010"],
        "K": ["101","101","110","101","101"],
        "L": ["100","100","100","100","111"],
        "M": ["101","111","101","101","101"],
        "N": ["110","101","101","101","101"],
        "O": ["010","101","101","101","010"],
        "P": ["110","101","110","100","100"],
        "Q": ["010","101","101","011","001"],
        "R": ["110","101","110","101","101"],
        "S": ["011","100","010","001","110"],
        "T": ["111","010","010","010","010"],
        "U": ["101","101","101","101","111"],
        "V": ["101","101","101","101","010"],
        "W": ["101","101","101","111","101"],
        "X": ["101","101","010","101","101"],
        "Y": ["101","101","010","010","010"],
        "Z": ["111","001","010","100","111"]
    }
    var char_w: int = 3 * scale
    var spacing: int = scale
    var total_w: int = text.length() * char_w + max(0, text.length() - 1) * spacing
    var start_x: int = center_x - int(total_w * 0.5)
    var start_y: int = center_y - int(5 * scale * 0.5)

    for idx in range(text.length()):
        var ch: String = text.substr(idx, 1)
        var pattern: Array = glyphs.get(ch, glyphs["O"])
        var gx: int = start_x + idx * (char_w + spacing)
        for row in range(5):
            var line: String = pattern[row]
            for col_i in range(3):
                if line.substr(col_i, 1) == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            var px: int = gx + col_i * scale + sx
                            var py: int = start_y + row * scale + sy
                            if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
                                img.set_pixel(px, py, col)
