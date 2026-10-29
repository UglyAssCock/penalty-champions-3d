extends Node

const SAVE_PATH: String = "user://savegame_v1.json"
const EXPORT_JSON_PATH: String = "user://database_export.json"

var leagues: Array = []
var competitions: Array = []
var teams: Array = []
var players: Array = []
var trophy_cabinet: Array = []
var user_team_id: String = "team_0"
var current_season_year: int = 2026

func _ready() -> void:
    if not load_game():
        generate_default_database()
        save_game()

func generate_default_database() -> void:
    leagues.clear()
    competitions.clear()
    teams.clear()
    players.clear()
    trophy_cabinet.clear()
    current_season_year = 2026

    var country_configs: Array = [
        {
            "country": "Spain",
            "div1_name": "Primera Liga",
            "div2_name": "Segunda Liga",
            "cup_name": "Copa Iberica",
            "div1_teams": [
                ["Real Madrid CF", "RMA", "#ffffff", "#d4af37", "Santiago Arena", 91],
                ["FC Barcelona", "BAR", "#a50044", "#004d98", "Camp Nouvel", 90],
                ["Atletico Madrid", "ATM", "#cb3524", "#1b2a4a", "Metropolitano", 86],
                ["Real Sociedad", "RSO", "#0067b1", "#ffffff", "Anoeta Park", 82],
                ["Athletic Bilbao", "ATH", "#ee2523", "#ffffff", "San Mamesia", 82],
                ["Villarreal CF", "VIL", "#f5e216", "#005187", "Ceramica Ground", 80],
                ["Real Betis", "BET", "#0bb363", "#ffffff", "Villamarin", 79],
                ["Valencia CF", "VAL", "#ffffff", "#ff6600", "Mestalla Dome", 78]
            ],
            "div2_teams": [
                ["Sevilla Atletico", "SEV", "#d41920", "#ffffff", "Nervion Stadium", 76],
                ["Celta Vigo", "CEL", "#8ac3ee", "#d51f26", "Balaidos", 75],
                ["Osasuna CF", "OSA", "#0a346f", "#d91a21", "Sadar Arena", 74],
                ["Girona FC", "GIR", "#e21e26", "#ffffff", "Montilivi", 75],
                ["Mallorca SD", "MLL", "#e20613", "#000000", "Son Moix", 73],
                ["Rayo Valle", "RAY", "#ffffff", "#e53027", "Vallecas", 72],
                ["Las Palmas", "LPA", "#f5d10d", "#00539f", "Gran Canaria", 71],
                ["Deportivo Coruna", "DEP", "#00529f", "#ffffff", "Riazor", 72]
            ]
        },
        {
            "country": "England",
            "div1_name": "Premier Division",
            "div2_name": "Championship Div",
            "cup_name": "Britannia FA Cup",
            "div1_teams": [
                ["Manchester City", "MCI", "#6cabdd", "#1c2c5b", "Etihad Crown", 92],
                ["Arsenal London", "ARS", "#ef0107", "#ffffff", "Emirates Field", 89],
                ["Liverpool Red", "LIV", "#c8102e", "#f6eb61", "Anfield Road", 89],
                ["Chelsea Blue", "CHE", "#034694", "#ffffff", "Stamford Park", 84],
                ["Manchester Utd", "MUN", "#da291c", "#fbe122", "Old Traffordia", 84],
                ["Tottenham Spurs", "TOT", "#ffffff", "#132257", "North London Bowl", 83],
                ["Newcastle Magpies", "NEW", "#241f20", "#ffffff", "St James Arena", 83],
                ["Aston Villa", "AVL", "#95bfe5", "#670e36", "Villa Ground", 82]
            ],
            "div2_teams": [
                ["Brighton Seagulls", "BHA", "#0057b8", "#ffffff", "Sussex Coast", 77],
                ["West Ham Irons", "WHU", "#7a263a", "#1bb1e7", "Olympic London", 76],
                ["Everton Blues", "EVE", "#003399", "#ffffff", "Mersey Dock", 75],
                ["Fulham Cottagers", "FUL", "#ffffff", "#000000", "Craven Thames", 75],
                ["Crystal Eagles", "CRY", "#1b458f", "#c4122e", "Selhurst Park", 74],
                ["Leicester Foxes", "LEI", "#003090", "#fdbe11", "King Power", 74],
                ["Leeds United", "LEE", "#ffffff", "#1d428a", "Elland Road", 73],
                ["Nottingham Forest", "NFO", "#dd0000", "#ffffff", "Trentside", 72]
            ]
        },
        {
            "country": "Italy",
            "div1_name": "Serie A Calcio",
            "div2_name": "Serie B Calcio",
            "cup_name": "Coppa Nazionale",
            "div1_teams": [
                ["Inter Milano", "INT", "#010e80", "#000000", "San Siro Nord", 90],
                ["AC Milan", "MIL", "#fb090b", "#000000", "San Siro Sud", 87],
                ["Juventus Torino", "JUV", "#ffffff", "#111111", "Allianz Piemonte", 87],
                ["SSC Napoli", "NAP", "#12a0d7", "#003c82", "Maradona Arena", 85],
                ["AS Roma", "ROM", "#8e1f2f", "#f0bc42", "Olimpico Sud", 83],
                ["Atalanta Bergamo", "ATA", "#1e71b8", "#000000", "Gewiss Field", 84],
                ["SS Lazio", "LAZ", "#87d8f7", "#ffffff", "Olimpico Nord", 81],
                ["Fiorentina Viola", "FIO", "#482e92", "#ffffff", "Artemio Franchi", 80]
            ],
            "div2_teams": [
                ["Bologna FC", "BOL", "#1a2f48", "#a21c26", "Dall Ara", 77],
                ["Torino Granata", "TOR", "#8a1e03", "#ffffff", "Grande Torino", 75],
                ["Udinese Zebre", "UDI", "#ffffff", "#111111", "Friuli Park", 74],
                ["Genoa Grifone", "GEN", "#a8191e", "#102742", "Marassi", 74],
                ["Parma Ducali", "PAR", "#fedd00", "#004996", "Tardini", 73],
                ["Cagliari Isola", "CAG", "#a50021", "#002350", "Sardegna Arena", 72],
                ["Palermo Rosanero", "PAL", "#f3a3b5", "#111111", "Barbera", 72],
                ["Sampdoria Blucer", "SAM", "#00559d", "#d41e24", "Ferraris", 71]
            ]
        },
        {
            "country": "Germany",
            "div1_name": "1. Bundesliga",
            "div2_name": "2. Bundesliga",
            "cup_name": "DFB Pokal Cup",
            "div1_teams": [
                ["Bayern Munchen", "BAY", "#dc052d", "#ffffff", "Allianz Munchen", 91],
                ["Bayer Leverkusen", "B04", "#e32221", "#111111", "BayArena", 88],
                ["Borussia Dortmund", "BVB", "#fde100", "#111111", "Signal Iduna", 87],
                ["RB Leipzig", "RBL", "#ffffff", "#dd0741", "Red Bull Arena", 84],
                ["VfB Stuttgart", "VFB", "#ffffff", "#e32219", "Neckar Park", 82],
                ["Eintracht Frank", "SGE", "#e1000f", "#111111", "Waldstadion", 81],
                ["Wolfsburg VfL", "WOB", "#65b32e", "#ffffff", "Volkswagen Arena", 79],
                ["Freiburg SC", "SCF", "#d1121c", "#111111", "Europa Park", 79]
            ],
            "div2_teams": [
                ["Borussia Gladbach", "BMG", "#ffffff", "#1d9053", "Borussia Park", 76],
                ["Werder Bremen", "SVW", "#1d9053", "#ffffff", "Weserstadion", 75],
                ["Hoffenheim TSG", "TSG", "#1961b5", "#ffffff", "Sinsheim Arena", 75],
                ["Union Berlin", "FCU", "#d4011d", "#f5e027", "Alte Forsterei", 74],
                ["Mainz 05", "M05", "#c3141e", "#ffffff", "Mewa Arena", 73],
                ["Hamburger SV", "HSV", "#0a3f86", "#ffffff", "Volkspark", 74],
                ["Schalke Gelsenk", "S04", "#004d9d", "#ffffff", "Veltins Arena", 73],
                ["FC Koln", "KOE", "#ed1c24", "#ffffff", "RheinEnergie", 73]
            ]
        }
    ]

    var first_names: Array[String] = [
        "Federico", "Luka", "Jude", "Kylian", "Vinicius", "Robert", "Pedri", "Gavi", "Marc", "Jan",
        "Erling", "Kevin", "Bukayo", "Martin", "Mohamed", "Virgil", "Cole", "Bruno", "Son", "declan",
        "Lautaro", "Nicolo", "Rafael", "Theo", "Dusan", "Paulo", "Khvicha", "Mike", "Jamal", "Florian",
        "Harry", "Joshua", "Gregor", "Julian", "Xavi", "Alejandro", "nico", "Alvaro", "Dani", "Mateo"
    ]
    var last_names: Array[String] = [
        "Valverde", "Modric", "Bellingham", "Mbappe", "Junior", "Lewandowski", "Gonzalez", "Paez", "Ter Stegen", "Oblak",
        "Haaland", "De Bruyne", "Saka", "Odegaard", "Salah", "Van Dijk", "Palmer", "Fernandes", "Heung-Min", "Rice",
        "Martinez", "Barella", "Leao", "Hernandez", "Vlahovic", "Dybala", "Kvaratskhelia", "Maignan", "Musiala", "Wirtz",
        "Kane", "Kimmich", "Kobel", "Brandt", "Simons", "Grimaldo", "Williams", "Morata", "Olmo", "Kovacic"
    ]

    var team_counter: int = 0
    var player_counter: int = 0

    for c_idx in range(country_configs.size()):
        var cfg: Dictionary = country_configs[c_idx]
        var country: String = cfg["country"]
        var lid1: String = "league_" + str(c_idx * 2)
        var lid2: String = "league_" + str(c_idx * 2 + 1)

        leagues.append({
            "id": lid1,
            "name": cfg["div1_name"],
            "country": country,
            "division": 1,
            "num_teams": 8,
            "promo_spots": 0,
            "releg_spots": 2,
            "ucl_spots": 2,
            "uel_spots": 2,
            "sister_league_id": lid2
        })

        leagues.append({
            "id": lid2,
            "name": cfg["div2_name"],
            "country": country,
            "division": 2,
            "num_teams": 8,
            "promo_spots": 2,
            "releg_spots": 0,
            "ucl_spots": 0,
            "uel_spots": 0,
            "sister_league_id": lid1
        })

        competitions.append({
            "id": "cup_" + str(c_idx),
            "name": cfg["cup_name"],
            "country": country,
            "format": "knockout",
            "trophy_style": 2,
            "trophy_color": "#e5e4e2",
            "custom_trophy": ""
        })

        var div_arrays: Array = [cfg["div1_teams"], cfg["div2_teams"]]
        var div_lids: Array = [lid1, lid2]

        for d in range(2):
            var t_list: Array = div_arrays[d]
            var curr_lid: String = div_lids[d]
            for t_entry in t_list:
                var tid: String = "team_" + str(team_counter)
                var base_rat: int = int(t_entry[5])
                teams.append({
                    "id": tid,
                    "name": t_entry[0],
                    "short_name": t_entry[1],
                    "color1": t_entry[2],
                    "color2": t_entry[3],
                    "stadium": t_entry[4],
                    "rating": base_rat,
                    "league_id": curr_lid,
                    "country": country,
                    "logo_shape": team_counter % 4,
                    "logo_pattern": (team_counter / 2) % 4,
                    "custom_logo": ""
                })

                # Generate 20 players per team (2 GK, 6 DEF, 6 MID, 6 FWD)
                for p_slot in range(20):
                    var pid: String = "player_" + str(player_counter)
                    var pos: String = "FWD"
                    if p_slot < 2:
                        pos = "GK"
                    elif p_slot < 8:
                        pos = "DEF"
                    elif p_slot < 14:
                        pos = "MID"

                    var p_name: String = ""
                    var shirt_num: int = p_slot + 1
                    # Keep iconic names on first two teams for screenshot authenticity
                    if team_counter == 0 and p_slot == 14:
                        p_name = "VALVERDE"
                        shirt_num = 15
                    elif team_counter == 1 and p_slot == 0:
                        p_name = "TER STEGEN"
                        shirt_num = 1
                    else:
                        var fn: String = first_names[(player_counter * 7 + p_slot) % first_names.size()]
                        var ln: String = last_names[(player_counter * 13 + team_counter) % last_names.size()]
                        p_name = fn.substr(0, 1) + ". " + ln.to_upper()

                    var variance: int = (player_counter * 5 % 9) - 4
                    var ovr: int = clampi(base_rat + variance, 58, 95)
                    var is_gk: bool = (pos == "GK")

                    players.append({
                        "id": pid,
                        "name": p_name,
                        "number": shirt_num,
                        "position": pos,
                        "age": 19 + (player_counter % 16),
                        "nationality": country,
                        "team_id": tid,
                        "rating": ovr,
                        "shooting": clampi(ovr + (6 if pos == "FWD" else (-18 if is_gk else 0)), 40, 98),
                        "composure": clampi(ovr + ((player_counter % 7) - 3), 45, 98),
                        "accuracy": clampi(ovr + (4 if pos != "GK" else -15), 40, 98),
                        "reflexes": clampi(ovr + (8 if is_gk else -25), 35, 98),
                        "diving": clampi(ovr + (6 if is_gk else -25), 35, 98),
                        "positioning": clampi(ovr + (7 if is_gk else -20), 35, 98),
                        "skin_tone": player_counter % 5,
                        "hair_color": (player_counter / 3) % 5,
                        "custom_photo": "",
                        "season_apps": 0,
                        "season_goals": 0,
                        "season_assists": 0,
                        "season_pens_scored": 0,
                        "season_pens_missed": 0,
                        "season_saves": 0,
                        "career_apps": 0,
                        "career_goals": 0,
                        "career_assists": 0,
                        "career_pens_scored": 0,
                        "career_pens_missed": 0,
                        "career_saves": 0
                    })
                    player_counter += 1
                team_counter += 1

    # Add the 2 Continental Competitions (Group Stage + Knockout)
    competitions.append({
        "id": "comp_ucl",
        "name": "Continental Champions Cup",
        "country": "International",
        "format": "continental_ucl",
        "trophy_style": 0,
        "trophy_color": "#ffd700",
        "custom_trophy": ""
    })
    competitions.append({
        "id": "comp_uel",
        "name": "Continental Shield Cup",
        "country": "International",
        "format": "continental_uel",
        "trophy_style": 1,
        "trophy_color": "#ff9f1c",
        "custom_trophy": ""
    })

    user_team_id = "team_0"

func get_team(tid: String) -> Dictionary:
    for t in teams:
        if str(t.get("id", "")) == tid:
            return t
    return teams[0] if teams.size() > 0 else {}

func get_league(lid: String) -> Dictionary:
    for l in leagues:
        if str(l.get("id", "")) == lid:
            return l
    return leagues[0] if leagues.size() > 0 else {}

func get_competition(cid: String) -> Dictionary:
    for c in competitions:
        if str(c.get("id", "")) == cid:
            return c
    return competitions[0] if competitions.size() > 0 else {}

func get_teams_in_league(lid: String) -> Array:
    var out: Array = []
    for t in teams:
        if str(t.get("league_id", "")) == lid:
            out.append(t)
    return out

func get_players_in_team(tid: String) -> Array:
    var out: Array = []
    for p in players:
        if str(p.get("team_id", "")) == tid:
            out.append(p)
    out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a.get("rating", 70)) > int(b.get("rating", 70))
    )
    return out

func get_team_goalkeeper(tid: String) -> Dictionary:
    var squad: Array = get_players_in_team(tid)
    for p in squad:
        if str(p.get("position", "")) == "GK":
            return p
    if squad.size() > 0:
        return squad[0]
    return {
        "id": "gk_temp", "name": "GOALKEEPER", "number": 1, "position": "GK",
        "rating": 75, "reflexes": 75, "diving": 75, "positioning": 75
    }

func get_team_penalty_takers(tid: String) -> Array:
    var squad: Array = get_players_in_team(tid)
    var outfield: Array = []
    var gks: Array = []
    for p in squad:
        if str(p.get("position", "")) == "GK":
            gks.append(p)
        else:
            outfield.append(p)
    outfield.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var sa: int = int(a.get("shooting", 70)) + int(a.get("composure", 70)) + int(a.get("accuracy", 70))
        var sb: int = int(b.get("shooting", 70)) + int(b.get("composure", 70)) + int(b.get("accuracy", 70))
        return sa > sb
    )
    outfield.append_array(gks)
    return outfield

func serialize_all() -> Dictionary:
    return {
        "version": 1,
        "current_season_year": current_season_year,
        "user_team_id": user_team_id,
        "leagues": leagues,
        "competitions": competitions,
        "teams": teams,
        "players": players,
        "trophy_cabinet": trophy_cabinet,
        "season_state": SeasonManager.serialize_season() if SeasonManager else {}
    }

func deserialize_all(data: Dictionary) -> bool:
    if not data.has("teams") or not data.has("leagues"):
        return false
    current_season_year = int(data.get("current_season_year", 2026))
    user_team_id = str(data.get("user_team_id", "team_0"))
    leagues = data.get("leagues", [])
    competitions = data.get("competitions", [])
    teams = data.get("teams", [])
    players = data.get("players", [])
    trophy_cabinet = data.get("trophy_cabinet", [])
    if SeasonManager and data.has("season_state"):
        SeasonManager.deserialize_season(data["season_state"])
    return true

func save_game() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(serialize_all()))
        f.close()

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not f:
        return false
    var txt: String = f.get_as_text()
    f.close()
    var parsed: Variant = JSON.parse_string(txt)
    if typeof(parsed) == TYPE_DICTIONARY:
        return deserialize_all(parsed)
    return false

func export_database_json(path: String = EXPORT_JSON_PATH) -> String:
    var json_str: String = JSON.stringify(serialize_all(), "  ")
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f:
        f.store_string(json_str)
        f.close()
    return json_str

func import_database_json_string(json_str: String) -> bool:
    var parsed: Variant = JSON.parse_string(json_str)
    if typeof(parsed) == TYPE_DICTIONARY:
        var ok: bool = deserialize_all(parsed)
        if ok:
            save_game()
        return ok
    return false
