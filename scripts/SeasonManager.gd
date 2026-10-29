extends Node

var current_week: int = 0
var max_weeks: int = 20
var fixtures: Array = []
var standings: Dictionary = {} # league_id -> Dictionary(team_id -> row)
var ucl_participants: Array = []
var uel_participants: Array = []
var last_match_report: String = ""

func _ready() -> void:
    call_deferred("_ensure_season_initialized")

func _ensure_season_initialized() -> void:
    if fixtures.is_empty():
        start_new_season(true)

func start_new_season(first_boot: bool = false) -> void:
    current_week = 0
    fixtures.clear()
    standings.clear()

    # Reset season stats on all players
    for p in GameDatabase.players:
        p["season_apps"] = 0
        p["season_goals"] = 0
        p["season_assists"] = 0
        p["season_pens_scored"] = 0
        p["season_pens_missed"] = 0
        p["season_saves"] = 0

    # Initialize league tables and double round-robin fixtures (14 league weeks for 8-team divisions)
    for l in GameDatabase.leagues:
        var lid: String = str(l["id"])
        var l_teams: Array = GameDatabase.get_teams_in_league(lid)
        standings[lid] = {}
        var tids: Array = []
        for t in l_teams:
            var tid: String = str(t["id"])
            tids.append(tid)
            standings[lid][tid] = {
                "team_id": tid,
                "played": 0,
                "won": 0,
                "drawn": 0,
                "lost": 0,
                "gf": 0,
                "ga": 0,
                "gd": 0,
                "points": 0,
                "form": []
            }
        _generate_round_robin_fixtures(lid, str(l["name"]), tids)

    # Select Continental qualifiers if empty
    if ucl_participants.size() < 8 or first_boot:
        ucl_participants.clear()
        uel_participants.clear()
        for l in GameDatabase.leagues:
            if int(l.get("division", 1)) == 1:
                var l_teams: Array = GameDatabase.get_teams_in_league(str(l["id"]))
                for i in range(min(2, l_teams.size())):
                    ucl_participants.append(str(l_teams[i]["id"]))
                for i in range(2, min(4, l_teams.size())):
                    uel_participants.append(str(l_teams[i]["id"]))

    # Schedule Continental Group Stage (Weeks 3, 6, 9) and Knockouts (Weeks 15, 17, 19)
    _schedule_continental_groups("comp_ucl", "Continental Champions Cup", ucl_participants)
    _schedule_continental_groups("comp_uel", "Continental Shield Cup", uel_participants)

    # Schedule Domestic Cup Round of 16 (Week 4), QF (Week 8), SF (Week 12), Final (Week 18)
    _schedule_domestic_cups()

    max_weeks = 20
    GameDatabase.save_game()

func _generate_round_robin_fixtures(comp_id: String, comp_name: String, tids: Array) -> void:
    var list: Array = tids.duplicate()
    if list.size() % 2 == 1:
        list.append("BYE")
    var n: int = list.size()
    if n < 2:
        return
    var rounds: int = n - 1
    var half: int = n / 2

    for r in range(rounds):
        var week_first_half: int = r
        var week_second_half: int = r + rounds
        for i in range(half):
            var t1: String = str(list[i])
            var t2: String = str(list[n - 1 - i])
            if t1 != "BYE" and t2 != "BYE":
                var home1: String = t1 if (r % 2 == 0) else t2
                var away1: String = t2 if (r % 2 == 0) else t1
                fixtures.append({
                    "id": comp_id + "_w" + str(week_first_half) + "_" + str(i),
                    "week": week_first_half,
                    "comp_id": comp_id,
                    "comp_name": comp_name,
                    "comp_type": "league",
                    "stage": "Matchday " + str(r + 1),
                    "home_id": home1,
                    "away_id": away1,
                    "played": false,
                    "home_goals": 0,
                    "away_goals": 0,
                    "pen_home": -1,
                    "pen_away": -1,
                    "summary": ""
                })
                fixtures.append({
                    "id": comp_id + "_w" + str(week_second_half) + "_" + str(i),
                    "week": week_second_half,
                    "comp_id": comp_id,
                    "comp_name": comp_name,
                    "comp_type": "league",
                    "stage": "Matchday " + str(r + 1 + rounds),
                    "home_id": away1,
                    "away_id": home1,
                    "played": false,
                    "home_goals": 0,
                    "away_goals": 0,
                    "pen_home": -1,
                    "pen_away": -1,
                    "summary": ""
                })
        # Rotate list keeping index 0 fixed
        var last_item: String = str(list.pop_back())
        list.insert(1, last_item)

func _schedule_continental_groups(comp_id: String, comp_name: String, participants: Array) -> void:
    if participants.size() < 4:
        return
    standings[comp_id] = {}
    for tid in participants:
        standings[comp_id][tid] = {
            "team_id": tid, "played": 0, "won": 0, "drawn": 0, "lost": 0,
            "gf": 0, "ga": 0, "gd": 0, "points": 0, "form": []
        }
    var group_weeks: Array[int] = [2, 5, 8, 11]
    var pairs_per_week: int = participants.size() / 2
    for w_idx in range(group_weeks.size()):
        var wk: int = group_weeks[w_idx]
        for p in range(pairs_per_week):
            var h_idx: int = (p + w_idx) % participants.size()
            var a_idx: int = (participants.size() - 1 - p + w_idx) % participants.size()
            if h_idx == a_idx:
                a_idx = (h_idx + 1) % participants.size()
            fixtures.append({
                "id": comp_id + "_grp_" + str(w_idx) + "_" + str(p),
                "week": wk,
                "comp_id": comp_id,
                "comp_name": comp_name,
                "comp_type": "continental_group",
                "stage": "Group Stage MD " + str(w_idx + 1),
                "home_id": participants[h_idx],
                "away_id": participants[a_idx],
                "played": false,
                "home_goals": 0,
                "away_goals": 0,
                "pen_home": -1,
                "pen_away": -1,
                "summary": ""
            })

func _schedule_domestic_cups() -> void:
    for c in GameDatabase.competitions:
        if str(c.get("format", "")) != "knockout":
            continue
        var country: String = str(c.get("country", ""))
        var cid: String = str(c.get("id", ""))
        var cname: String = str(c.get("name", ""))
        var country_teams: Array = []
        for t in GameDatabase.teams:
            if str(t.get("country", "")) == country:
                country_teams.append(str(t["id"]))
        for i in range(0, min(16, country_teams.size() - 1), 2):
            fixtures.append({
                "id": cid + "_r16_" + str(i),
                "week": 4,
                "comp_id": cid,
                "comp_name": cname,
                "comp_type": "knockout",
                "stage": "Round of 16",
                "home_id": country_teams[i],
                "away_id": country_teams[i + 1],
                "played": false,
                "home_goals": 0,
                "away_goals": 0,
                "pen_home": -1,
                "pen_away": -1,
                "summary": ""
            })

func get_current_week_fixtures() -> Array:
    var out: Array = []
    for f in fixtures:
        if int(f.get("week", -1)) == current_week:
            out.append(f)
    return out

func get_user_fixture_this_week() -> Dictionary:
    var utid: String = GameDatabase.user_team_id
    for f in fixtures:
        if int(f.get("week", -1)) == current_week:
            if str(f.get("home_id", "")) == utid or str(f.get("away_id", "")) == utid:
                return f
    return {}

func simulate_fixture(fix: Dictionary, force_penalties_result: Dictionary = {}) -> Dictionary:
    if bool(fix.get("played", false)):
        return fix

    var home_team: Dictionary = GameDatabase.get_team(str(fix["home_id"]))
    var away_team: Dictionary = GameDatabase.get_team(str(fix["away_id"]))
    var h_rat: float = float(home_team.get("rating", 75)) + 2.5 # Home advantage
    var a_rat: float = float(away_team.get("rating", 75))

    var diff: float = (h_rat - a_rat) * 0.065
    var h_lambda: float = clampf(1.35 + diff, 0.35, 3.8)
    var a_lambda: float = clampf(1.15 - diff, 0.25, 3.5)

    var hg: int = _sample_goals(h_lambda)
    var ag: int = _sample_goals(a_lambda)

    if force_penalties_result.has("home_goals"):
        hg = int(force_penalties_result["home_goals"])
        ag = int(force_penalties_result["away_goals"])

    fix["home_goals"] = hg
    fix["away_goals"] = ag
    fix["played"] = true

    var events: Array[String] = []
    var h_players: Array = GameDatabase.get_players_in_team(str(fix["home_id"]))
    var a_players: Array = GameDatabase.get_players_in_team(str(fix["away_id"]))

    _record_appearances_and_saves(h_players, ag)
    _record_appearances_and_saves(a_players, hg)

    for g in range(hg):
        var minute: int = randi_range(4, 90)
        var scorer: Dictionary = _pick_weighted_attacker(h_players)
        var assister: Dictionary = _pick_weighted_attacker(h_players, str(scorer.get("id", "")))
        scorer["season_goals"] = int(scorer.get("season_goals", 0)) + 1
        scorer["career_goals"] = int(scorer.get("career_goals", 0)) + 1
        if not assister.is_empty():
            assister["season_assists"] = int(assister.get("season_assists", 0)) + 1
            assister["career_assists"] = int(assister.get("career_assists", 0)) + 1
        events.append(str(minute) + "' GOAL " + str(home_team.get("short_name", "HOM")) + ": " + str(scorer.get("name", "Player")) + (" (ast. " + str(assister.get("name", "")) + ")" if not assister.is_empty() else ""))

    for g in range(ag):
        var minute: int = randi_range(4, 90)
        var scorer: Dictionary = _pick_weighted_attacker(a_players)
        var assister: Dictionary = _pick_weighted_attacker(a_players, str(scorer.get("id", "")))
        scorer["season_goals"] = int(scorer.get("season_goals", 0)) + 1
        scorer["career_goals"] = int(scorer.get("career_goals", 0)) + 1
        if not assister.is_empty():
            assister["season_assists"] = int(assister.get("season_assists", 0)) + 1
            assister["career_assists"] = int(assister.get("career_assists", 0)) + 1
        events.append(str(minute) + "' GOAL " + str(away_team.get("short_name", "AWY")) + ": " + str(scorer.get("name", "Player")) + (" (ast. " + str(assister.get("name", "")) + ")" if not assister.is_empty() else ""))

    # Simulate cards
    if randf() < 0.45 and h_players.size() > 0:
        var carded: Dictionary = h_players[randi() % h_players.size()]
        events.append(str(randi_range(15, 88)) + "' YELLOW CARD: " + str(carded.get("name", "")))
    if randf() < 0.45 and a_players.size() > 0:
        var carded2: Dictionary = a_players[randi() % a_players.size()]
        events.append(str(randi_range(15, 88)) + "' YELLOW CARD: " + str(carded2.get("name", "")))

    # Knockout draw requires penalty shootout
    var ctype: String = str(fix.get("comp_type", "league"))
    if ctype == "knockout" and hg == ag:
        if force_penalties_result.has("pen_home"):
            fix["pen_home"] = int(force_penalties_result["pen_home"])
            fix["pen_away"] = int(force_penalties_result["pen_away"])
        else:
            var pen_res: Dictionary = simulate_penalty_shootout_ai(str(fix["home_id"]), str(fix["away_id"]))
            fix["pen_home"] = int(pen_res["home_score"])
            fix["pen_away"] = int(pen_res["away_score"])
        events.append("PENALTIES: " + str(home_team.get("short_name", "")) + " " + str(fix["pen_home"]) + " - " + str(fix["pen_away"]) + " " + str(away_team.get("short_name", "")))

    fix["summary"] = "\n".join(events)
    last_match_report = str(home_team.get("name", "")) + " " + str(hg) + " - " + str(ag) + " " + str(away_team.get("name", "")) + "\n" + str(fix["summary"])

    if ctype == "league" or ctype == "continental_group":
        _update_standings_row(str(fix["comp_id"]), str(fix["home_id"]), str(fix["away_id"]), hg, ag)

    return fix

func simulate_penalty_shootout_ai(home_id: String, away_id: String) -> Dictionary:
    var h_takers: Array = GameDatabase.get_team_penalty_takers(home_id)
    var a_takers: Array = GameDatabase.get_team_penalty_takers(away_id)
    var h_gk: Dictionary = GameDatabase.get_team_goalkeeper(home_id)
    var a_gk: Dictionary = GameDatabase.get_team_goalkeeper(away_id)

    var h_score: int = 0
    var a_score: int = 0

    for round_i in range(5):
        var ht: Dictionary = h_takers[round_i % max(1, h_takers.size())]
        var at: Dictionary = a_takers[round_i % max(1, a_takers.size())]
        if _eval_single_ai_penalty(ht, a_gk):
            h_score += 1
        if _eval_single_ai_penalty(at, h_gk):
            a_score += 1

    var sd_round: int = 5
    while h_score == a_score and sd_round < 20:
        var ht2: Dictionary = h_takers[sd_round % max(1, h_takers.size())]
        var at2: Dictionary = a_takers[sd_round % max(1, a_takers.size())]
        var hs: bool = _eval_single_ai_penalty(ht2, a_gk)
        var as_bool: bool = _eval_single_ai_penalty(at2, h_gk)
        if hs:
            h_score += 1
        if as_bool:
            a_score += 1
        sd_round += 1

    if h_score == a_score:
        h_score += 1

    return {"home_score": h_score, "away_score": a_score}

func _eval_single_ai_penalty(shooter: Dictionary, keeper: Dictionary) -> bool:
    var s_skill: float = (float(shooter.get("shooting", 75)) + float(shooter.get("composure", 75)) + float(shooter.get("accuracy", 75))) / 3.0
    var k_skill: float = (float(keeper.get("reflexes", 75)) + float(keeper.get("diving", 75)) + float(keeper.get("positioning", 75))) / 3.0
    var prob: float = clampf(0.74 + (s_skill - k_skill) * 0.006, 0.42, 0.92)
    var scored: bool = randf() < prob
    if scored:
        shooter["season_pens_scored"] = int(shooter.get("season_pens_scored", 0)) + 1
        shooter["career_pens_scored"] = int(shooter.get("career_pens_scored", 0)) + 1
    else:
        shooter["season_pens_missed"] = int(shooter.get("season_pens_missed", 0)) + 1
        shooter["career_pens_missed"] = int(shooter.get("career_pens_missed", 0)) + 1
        keeper["season_saves"] = int(keeper.get("season_saves", 0)) + 1
        keeper["career_saves"] = int(keeper.get("career_saves", 0)) + 1
    return scored

func _sample_goals(lmbda: float) -> int:
    var l: float = exp(-lmbda)
    var k: int = 0
    var p: float = 1.0
    while p > l and k < 8:
        k += 1
        p *= randf()
    return max(0, k - 1)

func _record_appearances_and_saves(squad: Array, opp_goals: int) -> void:
    for i in range(min(11, squad.size())):
        var p: Dictionary = squad[i]
        p["season_apps"] = int(p.get("season_apps", 0)) + 1
        p["career_apps"] = int(p.get("career_apps", 0)) + 1
        if str(p.get("position", "")) == "GK":
            var sv: int = randi_range(1, 5)
            p["season_saves"] = int(p.get("season_saves", 0)) + sv
            p["career_saves"] = int(p.get("career_saves", 0)) + sv

func _pick_weighted_attacker(squad: Array, exclude_id: String = "") -> Dictionary:
    var candidates: Array = []
    for p in squad:
        if str(p.get("id", "")) == exclude_id or str(p.get("position", "")) == "GK":
            continue
        var weight: int = 1
        var pos: String = str(p.get("position", "MID"))
        if pos == "FWD":
            weight = 5
        elif pos == "MID":
            weight = 3
        for w in range(weight):
            candidates.append(p)
    if candidates.is_empty():
        return squad[0] if squad.size() > 0 else {}
    return candidates[randi() % candidates.size()]

func _update_standings_row(comp_id: String, home_id: String, away_id: String, hg: int, ag: int) -> void:
    if not standings.has(comp_id):
        standings[comp_id] = {}
    var table: Dictionary = standings[comp_id]
    if not table.has(home_id) or not table.has(away_id):
        return

    var h_row: Dictionary = table[home_id]
    var a_row: Dictionary = table[away_id]

    h_row["played"] = int(h_row["played"]) + 1
    a_row["played"] = int(a_row["played"]) + 1
    h_row["gf"] = int(h_row["gf"]) + hg
    h_row["ga"] = int(h_row["ga"]) + ag
    h_row["gd"] = int(h_row["gf"]) - int(h_row["ga"])

    a_row["gf"] = int(a_row["gf"]) + ag
    a_row["ga"] = int(a_row["ga"]) + hg
    a_row["gd"] = int(a_row["gf"]) - int(a_row["ga"])

    var h_form: Array = h_row.get("form", [])
    var a_form: Array = a_row.get("form", [])

    if hg > ag:
        h_row["won"] = int(h_row["won"]) + 1
        h_row["points"] = int(h_row["points"]) + 3
        a_row["lost"] = int(a_row["lost"]) + 1
        h_form.append("W")
        a_form.append("L")
    elif hg < ag:
        a_row["won"] = int(a_row["won"]) + 1
        a_row["points"] = int(a_row["points"]) + 3
        h_row["lost"] = int(h_row["lost"]) + 1
        h_form.append("L")
        a_form.append("W")
    else:
        h_row["drawn"] = int(h_row["drawn"]) + 1
        a_row["drawn"] = int(a_row["drawn"]) + 1
        h_row["points"] = int(h_row["points"]) + 1
        a_row["points"] = int(a_row["points"]) + 1
        h_form.append("D")
        a_form.append("D")

    while h_form.size() > 5:
        h_form.pop_front()
    while a_form.size() > 5:
        a_form.pop_front()
    h_row["form"] = h_form
    a_row["form"] = a_form

func get_sorted_standings(comp_id: String) -> Array:
    if not standings.has(comp_id):
        return []
    var rows: Array = standings[comp_id].values()
    rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        if int(a["points"]) != int(b["points"]):
            return int(a["points"]) > int(b["points"])
        if int(a["gd"]) != int(b["gd"]):
            return int(a["gd"]) > int(b["gd"])
        return int(a["gf"]) > int(b["gf"])
    )
    return rows

func simulate_current_week() -> void:
    for f in fixtures:
        if int(f.get("week", -1)) == current_week and not bool(f.get("played", false)):
            simulate_fixture(f)
    _check_and_advance_knockout_stages()
    current_week += 1
    if current_week >= max_weeks:
        conclude_season()
    GameDatabase.save_game()

func simulate_entire_season() -> void:
    var safety: int = 0
    var start_yr: int = GameDatabase.current_season_year
    while GameDatabase.current_season_year == start_yr and safety < 35:
        simulate_current_week()
        safety += 1

func _check_and_advance_knockout_stages() -> void:
    # Domestic Cups Progression: Week 4 (R16) -> Week 8 (QF) -> Week 12 (SF) -> Week 18 (Final)
    if current_week == 4:
        _spawn_next_cup_round(4, 8, "Quarter-Final")
    elif current_week == 8:
        _spawn_next_cup_round(8, 12, "Semi-Final")
    elif current_week == 12:
        _spawn_next_cup_round(12, 18, "Cup Final")
        # Also spawn Continental Semi-Finals from Group Top 4 at Week 15
        _spawn_continental_knockouts("comp_ucl", "Continental Champions Cup", 15)
        _spawn_continental_knockouts("comp_uel", "Continental Shield Cup", 15)
    elif current_week == 15:
        _spawn_next_cup_round(15, 19, "Continental Final")

func _spawn_next_cup_round(from_week: int, to_week: int, stage_label: String) -> void:
    var winners_by_comp: Dictionary = {}
    for f in fixtures:
        if int(f.get("week", -1)) == from_week and str(f.get("comp_type", "")) == "knockout":
            var cid: String = str(f["comp_id"])
            if not winners_by_comp.has(cid):
                winners_by_comp[cid] = {"name": str(f["comp_name"]), "list": []}
            winners_by_comp[cid]["list"].append(_get_fixture_winner(f))

    for cid in winners_by_comp.keys():
        var w_list: Array = winners_by_comp[cid]["list"]
        var cname: String = winners_by_comp[cid]["name"]
        for i in range(0, w_list.size() - 1, 2):
            fixtures.append({
                "id": cid + "_w" + str(to_week) + "_" + str(i),
                "week": to_week,
                "comp_id": cid,
                "comp_name": cname,
                "comp_type": "knockout",
                "stage": stage_label,
                "home_id": w_list[i],
                "away_id": w_list[i + 1],
                "played": false,
                "home_goals": 0,
                "away_goals": 0,
                "pen_home": -1,
                "pen_away": -1,
                "summary": ""
            })

func _spawn_continental_knockouts(comp_id: String, comp_name: String, target_week: int) -> void:
    var table: Array = get_sorted_standings(comp_id)
    if table.size() < 4:
        return
    fixtures.append({
        "id": comp_id + "_sf1",
        "week": target_week,
        "comp_id": comp_id,
        "comp_name": comp_name,
        "comp_type": "knockout",
        "stage": "Semi-Final 1",
        "home_id": str(table[0]["team_id"]),
        "away_id": str(table[3]["team_id"]),
        "played": false,
        "home_goals": 0, "away_goals": 0, "pen_home": -1, "pen_away": -1, "summary": ""
    })
    fixtures.append({
        "id": comp_id + "_sf2",
        "week": target_week,
        "comp_id": comp_id,
        "comp_name": comp_name,
        "comp_type": "knockout",
        "stage": "Semi-Final 2",
        "home_id": str(table[1]["team_id"]),
        "away_id": str(table[2]["team_id"]),
        "played": false,
        "home_goals": 0, "away_goals": 0, "pen_home": -1, "pen_away": -1, "summary": ""
    })

func _get_fixture_winner(f: Dictionary) -> String:
    var hg: int = int(f.get("home_goals", 0))
    var ag: int = int(f.get("away_goals", 0))
    if hg > ag:
        return str(f["home_id"])
    elif ag > hg:
        return str(f["away_id"])
    var ph: int = int(f.get("pen_home", 0))
    var pa: int = int(f.get("pen_away", 0))
    return str(f["home_id"]) if ph >= pa else str(f["away_id"])

func conclude_season() -> void:
    var yr: int = GameDatabase.current_season_year
    var new_ucl: Array = []
    var new_uel: Array = []

    # 1. Award League Titles & Process Promotion / Relegation
    var swaps: Array = []
    for l in GameDatabase.leagues:
        var lid: String = str(l["id"])
        var sorted: Array = get_sorted_standings(lid)
        if sorted.is_empty():
            continue
        var champ_id: String = str(sorted[0]["team_id"])
        var champ_team: Dictionary = GameDatabase.get_team(champ_id)
        GameDatabase.trophy_cabinet.append({
            "season": yr,
            "comp_id": lid,
            "comp_name": str(l["name"]),
            "winner_id": champ_id,
            "winner_name": str(champ_team.get("name", "")),
            "trophy_style": 1,
            "trophy_color": "#ffd700"
        })

        if int(l.get("division", 1)) == 1:
            var ucl_spots: int = int(l.get("ucl_spots", 2))
            var uel_spots: int = int(l.get("uel_spots", 2))
            for i in range(min(ucl_spots, sorted.size())):
                new_ucl.append(str(sorted[i]["team_id"]))
            for i in range(ucl_spots, min(ucl_spots + uel_spots, sorted.size())):
                new_uel.append(str(sorted[i]["team_id"]))

            # Relegation & Promotion with Division 2 sister league
            var sister_id: String = str(l.get("sister_league_id", ""))
            var releg_count: int = int(l.get("releg_spots", 2))
            if sister_id != "" and standings.has(sister_id):
                var div2_sorted: Array = get_sorted_standings(sister_id)
                for r in range(min(releg_count, min(sorted.size(), div2_sorted.size()))):
                    var down_tid: String = str(sorted[sorted.size() - 1 - r]["team_id"])
                    var up_tid: String = str(div2_sorted[r]["team_id"])
                    swaps.append({"team_id": down_tid, "new_league": sister_id})
                    swaps.append({"team_id": up_tid, "new_league": lid})

    for sw in swaps:
        var t: Dictionary = GameDatabase.get_team(str(sw["team_id"]))
        t["league_id"] = str(sw["new_league"])

    # 2. Record Cup & Continental Finals Winners in Trophy Cabinet
    for f in fixtures:
        var stg: String = str(f.get("stage", ""))
        if bool(f.get("played", false)) and (stg == "Cup Final" or stg == "Continental Final"):
            var win_id: String = _get_fixture_winner(f)
            var win_team: Dictionary = GameDatabase.get_team(win_id)
            var comp_obj: Dictionary = GameDatabase.get_competition(str(f["comp_id"]))
            GameDatabase.trophy_cabinet.append({
                "season": yr,
                "comp_id": str(f["comp_id"]),
                "comp_name": str(f["comp_name"]),
                "winner_id": win_id,
                "winner_name": str(win_team.get("name", "")),
                "trophy_style": int(comp_obj.get("trophy_style", 0)),
                "trophy_color": str(comp_obj.get("trophy_color", "#ffd700"))
            })

    ucl_participants = new_ucl
    uel_participants = new_uel
    GameDatabase.current_season_year += 1
    start_new_season(false)

func serialize_season() -> Dictionary:
    return {
        "current_week": current_week,
        "max_weeks": max_weeks,
        "fixtures": fixtures,
        "standings": standings,
        "ucl_participants": ucl_participants,
        "uel_participants": uel_participants
    }

func deserialize_season(data: Dictionary) -> void:
    current_week = int(data.get("current_week", 0))
    max_weeks = int(data.get("max_weeks", 20))
    fixtures = data.get("fixtures", [])
    standings = data.get("standings", {})
    ucl_participants = data.get("ucl_participants", [])
    uel_participants = data.get("uel_participants", [])
