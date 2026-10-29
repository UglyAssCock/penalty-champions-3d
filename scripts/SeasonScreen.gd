extends Control

var main_ctrl: Node
var content_box: VBoxContainer
var header_lbl: Label
var team_selector: OptionButton
var active_tab: int = 0
var selected_table_id: String = "league_0"

func setup(m_ctrl: Node) -> void:
    main_ctrl = m_ctrl
    var user_team: Dictionary = GameDatabase.get_team(GameDatabase.user_team_id)
    selected_table_id = str(user_team.get("league_id", "league_0"))

    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.10, 0.18, 1.0)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var root_vbox := VBoxContainer.new()
    root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    root_vbox.offset_left = 20
    root_vbox.offset_right = -20
    root_vbox.offset_top = 14
    root_vbox.offset_bottom = -14
    root_vbox.add_theme_constant_override("separation", 10)
    add_child(root_vbox)

    # Top Bar
    var top_bar := HBoxContainer.new()
    top_bar.add_theme_constant_override("separation", 14)
    root_vbox.add_child(top_bar)

    var back_btn := Button.new()
    back_btn.text = "◄ MAIN MENU"
    back_btn.custom_minimum_size = Vector2(140, 44)
    back_btn.pressed.connect(func() -> void: main_ctrl.show_main_menu())
    top_bar.add_child(back_btn)

    header_lbl = Label.new()
    header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_lbl.add_theme_font_size_override("font_size", 22)
    header_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.22))
    top_bar.add_child(header_lbl)

    var club_lbl := Label.new()
    club_lbl.text = "MY TEAM:"
    top_bar.add_child(club_lbl)

    team_selector = OptionButton.new()
    team_selector.custom_minimum_size = Vector2(230, 44)
    for i in range(GameDatabase.teams.size()):
        var t: Dictionary = GameDatabase.teams[i]
        team_selector.add_item(str(t["name"]), i)
        if str(t["id"]) == GameDatabase.user_team_id:
            team_selector.selected = i
    team_selector.item_selected.connect(func(idx: int) -> void:
        var chosen: Dictionary = GameDatabase.teams[idx]
        GameDatabase.user_team_id = str(chosen["id"])
        selected_table_id = str(chosen.get("league_id", "league_0"))
        GameDatabase.save_game()
        _refresh_view()
    )
    top_bar.add_child(team_selector)

    # Navigation Tabs
    var tabs_bar := HBoxContainer.new()
    tabs_bar.add_theme_constant_override("separation", 10)
    root_vbox.add_child(tabs_bar)

    var tab_names: Array[String] = [
        "FIXTURES & SIMULATOR",
        "LEAGUE & CUP TABLES",
        "PLAYER STATS & LEADERS",
        "TROPHY CABINET"
    ]
    for i in range(tab_names.size()):
        var tb := Button.new()
        tb.text = tab_names[i]
        tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tb.custom_minimum_size = Vector2(0, 46)
        tb.pressed.connect(func() -> void:
            active_tab = i
            _refresh_view()
        )
        tabs_bar.add_child(tb)

    content_box = VBoxContainer.new()
    content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root_vbox.add_child(content_box)

    _refresh_view()

func _refresh_view() -> void:
    for c in content_box.get_children():
        c.queue_free()

    var ut: Dictionary = GameDatabase.get_team(GameDatabase.user_team_id)
    header_lbl.text = "SEASON " + str(GameDatabase.current_season_year) + "/" + str(GameDatabase.current_season_year + 1) + "  •  WEEK " + str(SeasonManager.current_week + 1) + "/" + str(SeasonManager.max_weeks) + "  •  " + str(ut.get("name", ""))

    if active_tab == 0:
        _build_fixtures_tab()
    elif active_tab == 1:
        _build_tables_tab()
    elif active_tab == 2:
        _build_stats_tab()
    else:
        _build_trophy_cabinet_tab()

func _build_fixtures_tab() -> void:
    var action_row := HBoxContainer.new()
    action_row.add_theme_constant_override("separation", 14)
    content_box.add_child(action_row)

    var sim_round_btn := Button.new()
    sim_round_btn.text = "⏩ SIMULATE ROUND (WEEK " + str(SeasonManager.current_week + 1) + ")"
    sim_round_btn.custom_minimum_size = Vector2(300, 48)
    sim_round_btn.pressed.connect(func() -> void:
        SeasonManager.simulate_current_week()
        _refresh_view()
    )
    action_row.add_child(sim_round_btn)

    var sim_season_btn := Button.new()
    sim_season_btn.text = "⏭ SIMULATE ENTIRE SEASON"
    sim_season_btn.custom_minimum_size = Vector2(260, 48)
    sim_season_btn.pressed.connect(func() -> void:
        SeasonManager.simulate_entire_season()
        _refresh_view()
    )
    action_row.add_child(sim_season_btn)

    var main_split := HBoxContainer.new()
    main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_split.add_theme_constant_override("separation", 16)
    content_box.add_child(main_split)

    # Left: Scrollable list of current week's fixtures
    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_split.add_child(scroll)

    var list_vb := VBoxContainer.new()
    list_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_vb.add_theme_constant_override("separation", 8)
    scroll.add_child(list_vb)

    var week_fixtures: Array = SeasonManager.get_current_week_fixtures()
    if week_fixtures.is_empty():
        var empty_lbl := Label.new()
        empty_lbl.text = "No scheduled fixtures this week. Tap 'Simulate Round' to advance."
        list_vb.add_child(empty_lbl)

    for fix in week_fixtures:
        var ht: Dictionary = GameDatabase.get_team(str(fix["home_id"]))
        var at: Dictionary = GameDatabase.get_team(str(fix["away_id"]))
        var is_user_match: bool = (str(fix["home_id"]) == GameDatabase.user_team_id or str(fix["away_id"]) == GameDatabase.user_team_id)

        var row_panel := PanelContainer.new()
        if is_user_match:
            var hi_style := StyleBoxFlat.new()
            hi_style.bg_color = Color(0.10, 0.26, 0.42, 0.95)
            hi_style.border_color = Color(1.0, 0.85, 0.2)
            hi_style.set_border_width_all(2)
            row_panel.add_theme_stylebox_override("panel", hi_style)
        list_vb.add_child(row_panel)

        var rh := HBoxContainer.new()
        rh.add_theme_constant_override("separation", 10)
        row_panel.add_child(rh)

        var comp_lbl := Label.new()
        comp_lbl.text = "[" + str(fix.get("comp_name", "")) + "]"
        comp_lbl.custom_minimum_size = Vector2(180, 0)
        comp_lbl.add_theme_font_size_override("font_size", 14)
        comp_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
        rh.add_child(comp_lbl)

        var h_logo := TextureRect.new()
        h_logo.custom_minimum_size = Vector2(32, 32)
        h_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        h_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        h_logo.texture = ProceduralArt.get_team_logo(ht, 48)
        rh.add_child(h_logo)

        var match_lbl := Label.new()
        match_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if bool(fix.get("played", false)):
            var score_txt: String = str(ht["name"]) + "  " + str(fix["home_goals"]) + " - " + str(fix["away_goals"]) + "  " + str(at["name"])
            if int(fix.get("pen_home", -1)) >= 0:
                score_txt += " (Pens " + str(fix["pen_home"]) + "-" + str(fix["pen_away"]) + ")"
            match_lbl.text = score_txt
        else:
            match_lbl.text = str(ht["name"]) + "  vs  " + str(at["name"])
        rh.add_child(match_lbl)

        var a_logo := TextureRect.new()
        a_logo.custom_minimum_size = Vector2(32, 32)
        a_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        a_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        a_logo.texture = ProceduralArt.get_team_logo(at, 48)
        rh.add_child(a_logo)

        if not bool(fix.get("played", false)):
            var sim_btn := Button.new()
            sim_btn.text = "Sim Match"
            sim_btn.custom_minimum_size = Vector2(105, 38)
            sim_btn.pressed.connect(func() -> void:
                SeasonManager.simulate_fixture(fix)
                GameDatabase.save_game()
                _refresh_view()
            )
            rh.add_child(sim_btn)

            var play_pen_btn := Button.new()
            play_pen_btn.text = "Play Shootout"
            play_pen_btn.custom_minimum_size = Vector2(125, 38)
            play_pen_btn.pressed.connect(func() -> void:
                main_ctrl.start_penalty_shootout(str(fix["home_id"]), str(fix["away_id"]), fix)
            )
            rh.add_child(play_pen_btn)

    # Right: Match Report Box
    var rep_panel := PanelContainer.new()
    rep_panel.custom_minimum_size = Vector2(360, 0)
    main_split.add_child(rep_panel)

    var rep_vb := VBoxContainer.new()
    rep_panel.add_child(rep_vb)

    var rep_title := Label.new()
    rep_title.text = "MATCH SIMULATION REPORT"
    rep_title.add_theme_font_size_override("font_size", 18)
    rep_title.add_theme_color_override("font_color", Color(0.3, 0.95, 0.55))
    rep_vb.add_child(rep_title)

    var rep_txt := TextEdit.new()
    rep_txt.editable = false
    rep_txt.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rep_txt.text = SeasonManager.last_match_report if SeasonManager.last_match_report != "" else "Tap 'Sim Match' on any fixture to view scorers, assists, cards, and shootout details."
    rep_vb.add_child(rep_txt)

func _build_tables_tab() -> void:
    var sel_row := HBoxContainer.new()
    sel_row.add_theme_constant_override("separation", 12)
    content_box.add_child(sel_row)

    var lbl := Label.new()
    lbl.text = "SELECT COMPETITION TABLE:"
    sel_row.add_child(lbl)

    var comp_opt := OptionButton.new()
    comp_opt.custom_minimum_size = Vector2(340, 42)
    var table_ids: Array[String] = []

    for l in GameDatabase.leagues:
        var lid: String = str(l["id"])
        table_ids.append(lid)
        comp_opt.add_item(str(l["country"]) + " - " + str(l["name"]) + " (Div " + str(l["division"]) + ")")
        if lid == selected_table_id:
            comp_opt.selected = table_ids.size() - 1

    table_ids.append("comp_ucl")
    comp_opt.add_item("Continental Champions Cup (Group Table)")
    if selected_table_id == "comp_ucl":
        comp_opt.selected = table_ids.size() - 1

    table_ids.append("comp_uel")
    comp_opt.add_item("Continental Shield Cup (Group Table)")
    if selected_table_id == "comp_uel":
        comp_opt.selected = table_ids.size() - 1

    comp_opt.item_selected.connect(func(idx: int) -> void:
        selected_table_id = table_ids[idx]
        _refresh_view()
    )
    sel_row.add_child(comp_opt)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_box.add_child(scroll)

    var tvb := VBoxContainer.new()
    tvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tvb.add_theme_constant_override("separation", 6)
    scroll.add_child(tvb)

    var rows: Array = SeasonManager.get_sorted_standings(selected_table_id)
    var league_info: Dictionary = GameDatabase.get_league(selected_table_id)

    for i in range(rows.size()):
        var r: Dictionary = rows[i]
        var t: Dictionary = GameDatabase.get_team(str(r["team_id"]))
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 12)
        tvb.add_child(h)

        var pos_lbl := Label.new()
        var zone_tag: String = ""
        if selected_table_id.begins_with("league_"):
            var div: int = int(league_info.get("division", 1))
            if div == 1 and i < int(league_info.get("ucl_spots", 2)):
                zone_tag = " [UCL]"
            elif div == 1 and i < int(league_info.get("ucl_spots", 2)) + int(league_info.get("uel_spots", 2)):
                zone_tag = " [SHIELD]"
            elif div == 1 and i >= rows.size() - int(league_info.get("releg_spots", 2)):
                zone_tag = " [REL]"
            elif div == 2 and i < int(league_info.get("promo_spots", 2)):
                zone_tag = " [PROMO]"
        pos_lbl.text = str(i + 1) + "." + zone_tag
        pos_lbl.custom_minimum_size = Vector2(110, 0)
        h.add_child(pos_lbl)

        var logo := TextureRect.new()
        logo.custom_minimum_size = Vector2(32, 32)
        logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        logo.texture = ProceduralArt.get_team_logo(t, 48)
        h.add_child(logo)

        var tname := Label.new()
        tname.text = str(t["name"])
        tname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        h.add_child(tname)

        var stats_lbl := Label.new()
        var form_arr: Array = r.get("form", [])
        var form_str: String = "-".join(form_arr) if not form_arr.is_empty() else "-"
        stats_lbl.text = "P:" + str(r["played"]) + "  W:" + str(r["won"]) + "  D:" + str(r["drawn"]) + "  L:" + str(r["lost"]) + "  GF:" + str(r["gf"]) + "  GA:" + str(r["ga"]) + "  GD:" + str(r["gd"]) + "   PTS: " + str(r["points"]) + "   Form: [" + form_str + "]"
        stats_lbl.custom_minimum_size = Vector2(560, 0)
        h.add_child(stats_lbl)

func _build_stats_tab() -> void:
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_box.add_child(scroll)

    var vb := VBoxContainer.new()
    vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vb.add_theme_constant_override("separation", 8)
    scroll.add_child(vb)

    var sorted_players: Array = GameDatabase.players.duplicate()
    sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if int(a.get("season_goals", 0)) != int(b.get("season_goals", 0)):
            return int(a.get("season_goals", 0)) > int(b.get("season_goals", 0))
        return int(a.get("rating", 70)) > int(b.get("rating", 70))
    )

    for i in range(min(40, sorted_players.size())):
        var p: Dictionary = sorted_players[i]
        var t: Dictionary = GameDatabase.get_team(str(p.get("team_id", "team_0")))
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 12)
        vb.add_child(row)

        var photo := TextureRect.new()
        photo.custom_minimum_size = Vector2(40, 40)
        photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        photo.texture = ProceduralArt.get_player_photo(p, str(t.get("color1", "#1e5aa8")), 64)
        row.add_child(photo)

        var info := Label.new()
        info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info.text = "#" + str(p.get("number", 9)) + " " + str(p.get("name", "")) + " (" + str(p.get("position", "")) + " • OVR " + str(p.get("rating", 75)) + ") - " + str(t.get("name", ""))
        row.add_child(info)

        var st := Label.new()
        st.text = "Season G:" + str(p.get("season_goals", 0)) + " A:" + str(p.get("season_assists", 0)) + " Pens:" + str(p.get("season_pens_scored", 0)) + "/" + str(int(p.get("season_pens_scored", 0)) + int(p.get("season_pens_missed", 0))) + " Saves:" + str(p.get("season_saves", 0)) + "  |  Career G:" + str(p.get("career_goals", 0))
        row.add_child(st)

func _build_trophy_cabinet_tab() -> void:
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_box.add_child(scroll)

    var vb := VBoxContainer.new()
    vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vb.add_theme_constant_override("separation", 10)
    scroll.add_child(vb)

    if GameDatabase.trophy_cabinet.is_empty():
        var empty := Label.new()
        empty.text = "No trophies awarded yet! Complete a season to fill the Trophy Cabinet."
        vb.add_child(empty)
        return

    for tr in GameDatabase.trophy_cabinet:
        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 16)
        vb.add_child(h)

        var t_icon := TextureRect.new()
        t_icon.custom_minimum_size = Vector2(54, 54)
        t_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        t_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        t_icon.texture = ProceduralArt.get_trophy_icon(tr, 64)
        h.add_child(t_icon)

        var win_team: Dictionary = GameDatabase.get_team(str(tr.get("winner_id", "team_0")))
        var c_logo := TextureRect.new()
        c_logo.custom_minimum_size = Vector2(46, 46)
        c_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        c_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        c_logo.texture = ProceduralArt.get_team_logo(win_team, 64)
        h.add_child(c_logo)

        var lbl := Label.new()
        lbl.add_theme_font_size_override("font_size", 20)
        lbl.text = str(tr.get("season", 2026)) + "  •  " + str(tr.get("comp_name", "Competition")) + "  —  WINNER: " + str(tr.get("winner_name", "Club"))
        h.add_child(lbl)
