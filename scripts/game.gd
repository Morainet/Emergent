extends Node2D

const WORLD = Rect2(28.0, 82.0, 944.0, 530.0)
const CAMP = Vector2(505.0, 350.0)
const ACTIONS = ["hide", "gather", "explore", "defend", "return"]
const WOLF_ACTIONS = ["hunt", "observe", "retreat", "roam"]
const AI_URL = "http://127.0.0.1:8765/decide"

var player := Vector2(470.0, 370.0)
var partner := Vector2(525.0, 371.0)
var player_hp := 100.0
var partner_hp := 100.0
var supplies := 0
var delivered := 0
var elapsed := 0.0
var pulse_cooldown := 0.0
var decision_timer := 0.0
var partner_action := "explore"
var decision_source := "local"
var message := "Find three signal shards. Bring them back to the fire."
var message_timer := 7.0
var game_over := false
var won := false
var ai_busy := false
var pack_busy := false
var pack_timer := 0.0
var pack_action := "roam"
var pack_source := "local"
var pack_hunger := 35.0
var pack_fear := 0.0
var show_ai_debug := false
var pulse_fx := 0.0
var was_night := false

var shards := [
	{"pos": Vector2(135, 165), "taken": false},
	{"pos": Vector2(855, 175), "taken": false},
	{"pos": Vector2(790, 545), "taken": false}
]
var berries := [
	{"pos": Vector2(320, 185), "ready": true},
	{"pos": Vector2(690, 205), "ready": true},
	{"pos": Vector2(255, 505), "ready": true},
	{"pos": Vector2(665, 490), "ready": true},
	{"pos": Vector2(860, 375), "ready": true}
]
var trees := [
	Vector2(90, 310), Vector2(180, 390), Vector2(260, 120),
	Vector2(350, 255), Vector2(390, 520), Vector2(600, 145),
	Vector2(730, 315), Vector2(895, 470), Vector2(920, 265),
	Vector2(90, 535), Vector2(645, 575)
]
var wolves := [
	{"pos": Vector2(115, 445), "stun": 0.0, "hit": 0.0, "hp": 3},
	{"pos": Vector2(820, 315), "stun": 0.0, "hit": 0.0, "hp": 3},
	{"pos": Vector2(585, 120), "stun": 0.0, "hit": 0.0, "hp": 3}
]

var http: HTTPRequest
var pack_http: HTTPRequest
var title_label: Label
var stats_label: Label
var hint_label: Label
var thought_label: Label
var banner_label: Label
var notice_label: Label


func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 1.8
	add_child(http)
	http.request_completed.connect(_on_ai_response)
	pack_http = HTTPRequest.new()
	pack_http.timeout = 1.8
	add_child(pack_http)
	pack_http.request_completed.connect(_on_pack_response)
	_make_ui()
	_update_ui()


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	title_label = _label(layer, Vector2(28, 13), 450, 28, 20, Color("f8deaa"))
	stats_label = _label(layer, Vector2(28, 49), 900, 25, 15, Color("c7d7c8"))
	hint_label = _label(layer, Vector2(31, 607), 940, 25, 14, Color("a7baa9"))
	thought_label = _label(layer, Vector2(573, 13), 400, 30, 16, Color("f3d69b"))
	banner_label = _label(layer, Vector2(230, 245), 540, 120, 31, Color("ffe1a1"))
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label = _label(layer, Vector2(260, 566), 480, 35, 16, Color("ffe0a8"))
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(parent: Node, pos: Vector2, width: float, height: float, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(width, height)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	if game_over:
		if Input.is_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return
	elapsed += delta
	pack_hunger = minf(100.0, pack_hunger + delta * 0.35)
	pack_fear = maxf(0.0, pack_fear - delta * 0.8)
	if _is_night() and not was_night:
		_for_new_night()
	was_night = _is_night()
	pulse_cooldown = maxf(0.0, pulse_cooldown - delta)
	pulse_fx = maxf(0.0, pulse_fx - delta)
	message_timer = maxf(0.0, message_timer - delta)
	_move_player(delta)
	_update_partner(delta)
	_update_wolves(delta)
	decision_timer -= delta
	if decision_timer <= 0.0:
		decision_timer = 2.2
		_decide()
	pack_timer -= delta
	if pack_timer <= 0.0:
		pack_timer = 2.2
		_decide_pack()
	if player_hp <= 0.0 or partner_hp <= 0.0:
		game_over = true
		message = "The forest went silent."
	_update_ui()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if game_over or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE:
		_pulse()
	elif event.keycode == KEY_E:
		_interact()
	elif event.keycode == KEY_F1:
		show_ai_debug = not show_ai_debug
	_update_ui()
	queue_redraw()


func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
	player = _clamp_world(player + direction.normalized() * 205.0 * delta)


func _update_partner(delta: float) -> void:
	var threat := _nearest_wolf(partner)
	var target := player + Vector2(30.0, 20.0)
	match partner_action:
		"hide":
			if threat != -1:
				target = partner + (partner - wolves[threat]["pos"]).normalized() * 115.0
			else:
				target = CAMP
		"gather":
			var bush := _nearest_ready_berry(partner)
			if bush != -1:
				target = berries[bush]["pos"]
				if partner.distance_to(target) < 21.0:
					berries[bush]["ready"] = false
					supplies += 1
					_say("Ari found supplies in the undergrowth.")
		"explore":
			var shard := _nearest_shard(partner)
			if shard != -1:
				target = shards[shard]["pos"] + Vector2(28, 22)
		"defend":
			if threat != -1:
				target = wolves[threat]["pos"]
				if partner.distance_to(target) < 47.0 and wolves[threat]["hit"] <= 0.0:
					wolves[threat]["stun"] = 0.5
					wolves[threat]["hit"] = 1.1
					wolves[threat]["hp"] -= 1
					pack_fear = minf(100.0, pack_fear + 12.0)
		"return":
			target = CAMP
	if partner.distance_to(target) > 13.0:
		partner = _clamp_world(partner.move_toward(_clamp_world(target), 132.0 * delta))
	if partner_action == "return" and partner.distance_to(CAMP) < 47.0 and partner_hp < 100.0 and supplies > 0:
		supplies -= 1
		partner_hp = minf(100.0, partner_hp + 20.0)
		_say("Ari used a supply to recover at camp.")


func _update_wolves(delta: float) -> void:
	var night := _is_night()
	for i in wolves.size():
		var wolf: Dictionary = wolves[i]
		if wolf["hp"] <= 0:
			continue
		wolf["stun"] = maxf(0.0, wolf["stun"] - delta)
		wolf["hit"] = maxf(0.0, wolf["hit"] - delta)
		if wolf["stun"] > 0.0:
			continue
		var target: Vector2 = player if wolf["pos"].distance_to(player) < wolf["pos"].distance_to(partner) else partner
		var distance: float = wolf["pos"].distance_to(target)
		var speed := 93.0 if night else 72.0
		match pack_action:
			"hunt":
				if distance < (390.0 if night else 245.0):
					wolf["pos"] = _clamp_world(wolf["pos"].move_toward(target, speed * delta))
			"observe":
				if distance < 84.0:
					wolf["pos"] = _clamp_world(wolf["pos"].move_toward(wolf["pos"] + (wolf["pos"] - target).normalized() * 80.0, 50.0 * delta))
				elif distance < 270.0 and distance > 140.0:
					wolf["pos"] = _clamp_world(wolf["pos"].move_toward(target, 47.0 * delta))
			"retreat":
				wolf["pos"] = _clamp_world(wolf["pos"].move_toward(_wolf_home(i), speed * 1.2 * delta))
			"roam":
				var wander := _wolf_home(i) + Vector2(45.0 * sin(elapsed * 0.6 + float(i)), 35.0 * cos(elapsed * 0.5 + float(i)))
				wolf["pos"] = _clamp_world(wolf["pos"].move_toward(wander, 32.0 * delta))
		if pack_action == "hunt" and wolf["pos"].distance_to(target) < 29.0 and wolf["hit"] <= 0.0:
			wolf["hit"] = 1.3
			pack_hunger = maxf(0.0, pack_hunger - 10.0)
			if target == player:
				player_hp -= 14.0
			else:
				partner_hp -= 17.0
			_say("A wolf struck! Use SPACE to repel it.")


func _pulse() -> void:
	if pulse_cooldown > 0.0:
		return
	pulse_cooldown = 3.5
	pulse_fx = 0.45
	var hit_count := 0
	for wolf in wolves:
		if wolf["hp"] > 0 and wolf["pos"].distance_to(player) < 100.0:
			wolf["hp"] -= 1
			wolf["stun"] = 1.3
			wolf["hit"] = 1.0
			wolf["pos"] = _clamp_world(wolf["pos"] + (wolf["pos"] - player).normalized() * 65.0)
			hit_count += 1
	if hit_count > 0:
		pack_fear = minf(100.0, pack_fear + 27.0 * float(hit_count))
		_say("The ember pulse drove the wolves back.")


func _interact() -> void:
	if player.distance_to(CAMP) < 55.0:
		if delivered >= 3:
			won = true
			game_over = true
		elif supplies > 0 and player_hp < 100.0:
			supplies -= 1
			player_hp = minf(100.0, player_hp + 30.0)
			_say("You patched yourself up by the fire.")
		else:
			_say("The fire holds. Find the remaining signal shards.")
		return
	for shard in shards:
		if not shard["taken"] and player.distance_to(shard["pos"]) < 34.0:
			shard["taken"] = true
			delivered += 1
			_say("Signal shard secured. %d / 3 found." % delivered)
			if delivered == 3:
				_say("All shards found! Return to the campfire.")
			return
	for berry in berries:
		if berry["ready"] and player.distance_to(berry["pos"]) < 32.0:
			berry["ready"] = false
			supplies += 1
			_say("Gathered one supply. Heal at the campfire.")
			return
	_say("Nothing nearby to interact with.")


func _decide() -> void:
	var local_action := _local_decision()
	partner_action = local_action
	decision_source = "local"
	if ai_busy:
		return
	var nearby := _nearest_wolf(partner)
	var enemy_distance: float = 999.0 if nearby == -1 else partner.distance_to(wolves[nearby]["pos"])
	var state := {
		"npc_hp": roundi(partner_hp),
		"player_hp": roundi(player_hp),
		"enemy_distance": roundi(enemy_distance),
		"enemy_nearby": enemy_distance < 170.0,
		"food_nearby": _nearest_ready_berry(partner) != -1,
		"supplies": supplies,
		"unfound_shards": 3 - delivered,
		"night": _is_night(),
		"camp_distance": roundi(partner.distance_to(CAMP)),
		"player_distance": roundi(partner.distance_to(player))
	}
	var error := http.request(AI_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"state": state}))
	if error == OK:
		ai_busy = true


func _local_decision() -> String:
	var threat := _nearest_wolf(partner)
	var distance: float = 999.0 if threat == -1 else partner.distance_to(wolves[threat]["pos"])
	if partner_hp < 36.0 and supplies > 0:
		return "return"
	if distance < 105.0 and partner_hp < 53.0:
		return "hide"
	if distance < 100.0 and player.distance_to(partner) < 135.0:
		return "defend"
	if supplies < 2 and _nearest_ready_berry(partner) != -1:
		return "gather"
	if delivered < 3:
		return "explore"
	return "return"


func _decide_pack() -> void:
	pack_action = _local_pack_decision()
	pack_source = "local"
	if pack_busy:
		return
	var alive := 0
	var health := 0
	var nearest := 999.0
	for wolf in wolves:
		if wolf["hp"] <= 0:
			continue
		alive += 1
		health += int(wolf["hp"])
		nearest = minf(nearest, wolf["pos"].distance_to(player))
	if alive == 0:
		return
	var state := {
		"wolf_count": alive,
		"pack_health": health,
		"pack_hunger": roundi(pack_hunger),
		"pack_fear": roundi(pack_fear),
		"player_distance": roundi(nearest),
		"player_hp": roundi(player_hp),
		"night": _is_night(),
		"camp_distance": roundi(player.distance_to(CAMP))
	}
	var error := pack_http.request(AI_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"agent": "wolf", "state": state}))
	if error == OK:
		pack_busy = true


func _local_pack_decision() -> String:
	var alive := 0
	var nearest := 999.0
	var wounded := 0
	for wolf in wolves:
		if wolf["hp"] <= 0:
			continue
		alive += 1
		if wolf["hp"] == 1:
			wounded += 1
		nearest = minf(nearest, wolf["pos"].distance_to(player))
	if alive == 0:
		return "roam"
	if pack_fear >= 45.0 or wounded >= 2:
		return "retreat"
	if nearest < 195.0:
		return "hunt" if _is_night() or pack_hunger > 55.0 else "observe"
	return "roam"


func _on_pack_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	pack_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not data.has("action"):
		return
	var action := str(data["action"])
	if not WOLF_ACTIONS.has(action):
		return
	# Damage and attack timing stay deterministic; the model selects a pack stance.
	pack_action = action
	pack_source = "Laya"


func _wolf_home(index: int) -> Vector2:
	match index:
		0: return Vector2(95.0, 440.0)
		1: return Vector2(855.0, 315.0)
		_: return Vector2(585.0, 125.0)


func _on_ai_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	ai_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not data.has("action"):
		return
	var action := str(data["action"])
	if not ACTIONS.has(action):
		return
	# The game keeps hard constraints even when the model proposes an impossible action.
	if action == "gather" and _nearest_ready_berry(partner) == -1:
		return
	if action == "explore" and delivered >= 3:
		return
	partner_action = action
	decision_source = "Laya"


func _nearest_wolf(origin: Vector2) -> int:
	var best := -1
	var distance := INF
	for i in wolves.size():
		if wolves[i]["hp"] <= 0:
			continue
		var d: float = origin.distance_to(wolves[i]["pos"])
		if d < distance:
			distance = d
			best = i
	return best


func _nearest_ready_berry(origin: Vector2) -> int:
	var best := -1
	var distance := INF
	for i in berries.size():
		if not berries[i]["ready"]:
			continue
		var d: float = origin.distance_to(berries[i]["pos"])
		if d < distance:
			distance = d
			best = i
	return best


func _nearest_shard(origin: Vector2) -> int:
	var best := -1
	var distance := INF
	for i in shards.size():
		if shards[i]["taken"]:
			continue
		var d: float = origin.distance_to(shards[i]["pos"])
		if d < distance:
			distance = d
			best = i
	return best


func _is_night() -> bool:
	return fmod(elapsed, 72.0) > 38.0


func _clamp_world(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, WORLD.position.x + 18.0, WORLD.end.x - 18.0), clampf(pos.y, WORLD.position.y + 18.0, WORLD.end.y - 18.0))


func _say(value: String) -> void:
	message = value
	message_timer = 4.0


func _for_new_night() -> void:
	for berry in berries:
		berry["ready"] = true
	for i in wolves.size():
		var wolf: Dictionary = wolves[i]
		if wolf["hp"] <= 0:
			wolf["hp"] = 3
			wolf["stun"] = 0.0
			wolf["hit"] = 0.0
			wolf["pos"] = _wolf_home(i)
	_say("Night falls. Wolves return, and the berry bushes regrow.")


func _update_ui() -> void:
	title_label.text = "EMERGENT  /  THE LAST SIGNAL"
	stats_label.text = "YOU %d HP     ARI %d HP     SUPPLIES %d     SHARDS %d/3     %s" % [maxi(0, roundi(player_hp)), maxi(0, roundi(partner_hp)), supplies, delivered, "NIGHT" if _is_night() else "DUSK"]
	thought_label.text = ("W: %s %s  |  A: %s %s" % [pack_action.to_upper(), pack_source, partner_action.to_upper(), decision_source]) if show_ai_debug else "Watch the wolves. F1: AI debug"
	var nearby_hint := ""
	if player.distance_to(CAMP) < 55.0:
		nearby_hint = "  E: heal / finish"
	elif _nearest_shard(player) != -1 and player.distance_to(shards[_nearest_shard(player)]["pos"]) < 36.0:
		nearby_hint = "  E: take shard"
	elif _nearest_ready_berry(player) != -1 and player.distance_to(berries[_nearest_ready_berry(player)]["pos"]) < 34.0:
		nearby_hint = "  E: gather"
	hint_label.text = "WASD move   SPACE repel (%.1fs)   E interact   F1 AI debug%s" % [pulse_cooldown, nearby_hint]
	notice_label.text = message if message_timer > 0.0 else ""
	banner_label.text = ("THE SIGNAL IS ALIVE\nYou and Ari made it home.\nPress R to play again" if won else "THE FOREST WINS\nPress R to try again") if game_over else ""


func _draw() -> void:
	var night := _is_night()
	var ground := Color("102a30") if night else Color("244438")
	var path_color := Color("304b43") if night else Color("547059")
	draw_rect(WORLD, ground)
	draw_rect(WORLD, Color("7da084"), false, 2.0)
	# A winding trail and small patches give the map a readable silhouette.
	var trail := PackedVector2Array([Vector2(55, 560), Vector2(210, 480), CAMP, Vector2(735, 290), Vector2(945, 145)])
	draw_polyline(trail, path_color, 49.0, true)
	draw_polyline(trail, Color("b2a67a", 0.35), 2.0, true)
	for i in 48:
		var x := 57.0 + fmod(float(i * 137), 890.0)
		var y := 105.0 + fmod(float(i * 89), 475.0)
		draw_circle(Vector2(x, y), 2.0 + float(i % 3), Color("76a879", 0.22))
	for tree in trees:
		draw_circle(tree + Vector2(8, 10), 26.0, Color(0.0, 0.0, 0.0, 0.23))
		draw_circle(tree, 25.0, Color("173d35"))
		draw_circle(tree + Vector2(-7, -8), 18.0, Color("2b6147"))
		draw_circle(tree + Vector2(7, 3), 15.0, Color("397553"))
	for berry in berries:
		if berry["ready"]:
			draw_circle(berry["pos"], 15.0, Color("295d44"))
			for off in [Vector2(-6, -5), Vector2(5, -7), Vector2(2, 6)]:
				draw_circle(berry["pos"] + off, 4.0, Color("eb8c7c"))
	for shard in shards:
		if not shard["taken"]:
			var p: Vector2 = shard["pos"]
			draw_circle(p, 27.0, Color("8fece5", 0.13))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -21), p + Vector2(12, 0), p + Vector2(0, 22), p + Vector2(-12, 0)]), Color("87efe6"))
			draw_line(p + Vector2(0, -15), p + Vector2(0, 14), Color("e1ffec"), 2.0)
	# Campfire is a stable landmark and refuge.
	draw_circle(CAMP, 66.0, Color("ffc375", 0.10))
	draw_circle(CAMP, 42.0, Color("efaa59", 0.12))
	draw_circle(CAMP, 21.0, Color("372d29"))
	draw_line(CAMP + Vector2(-14, 13), CAMP + Vector2(15, -10), Color("8d6544"), 6.0)
	draw_line(CAMP + Vector2(-14, -8), CAMP + Vector2(14, 13), Color("8d6544"), 6.0)
	var flame := 3.0 * sin(elapsed * 8.0)
	draw_colored_polygon(PackedVector2Array([CAMP + Vector2(-9, 5), CAMP + Vector2(-3, -21 - flame), CAMP + Vector2(4, -9), CAMP + Vector2(10, 5)]), Color("ffb65c"))
	draw_circle(CAMP + Vector2(0, -3), 5.0, Color("fff1b8"))
	for wolf in wolves:
		if wolf["hp"] <= 0:
			continue
		var p: Vector2 = wolf["pos"]
		draw_circle(p + Vector2(4, 5), 17.0, Color(0, 0, 0, 0.25))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -8), p + Vector2(-13, -22), p + Vector2(-2, -13), p + Vector2(4, -23), p + Vector2(15, -7), p + Vector2(13, 10), p + Vector2(-12, 10)]), Color("63717a") if wolf["stun"] <= 0.0 else Color("b3c9d0"))
		draw_circle(p + Vector2(-6, -3), 2.0, Color("ff7772"))
		draw_circle(p + Vector2(7, -3), 2.0, Color("ff7772"))
	_draw_person(partner, Color("f0b889"), Color("b47564"))
	_draw_person(player, Color("8ed8d1"), Color("478d88"))
	if pulse_fx > 0.0:
		draw_arc(player, 100.0 * (1.0 - pulse_fx / 0.45), 0, TAU, 48, Color("ffe3a4", pulse_fx / 0.45), 4.0)
	if night:
		# Light pools preserve visibility while making night dangerous.
		draw_rect(WORLD, Color("081021", 0.36))
		draw_circle(CAMP, 57.0, Color("ffbb67", 0.16))
		draw_circle(player, 37.0, Color("9be6db", 0.10))
	if game_over:
		draw_rect(WORLD, Color(0.02, 0.05, 0.07, 0.72))


func _draw_person(pos: Vector2, bright: Color, dark: Color) -> void:
	draw_circle(pos + Vector2(5, 7), 15.0, Color(0, 0, 0, 0.25))
	draw_circle(pos, 13.0, dark)
	draw_circle(pos + Vector2(0, -5), 9.0, bright)
	draw_circle(pos + Vector2(-3, -7), 1.5, Color("17313a"))
	draw_circle(pos + Vector2(4, -7), 1.5, Color("17313a"))
