extends Node2D

# DÜĞÜM BAĞLANTILARI
@onready var click_sound = $ClickSound
@onready var bomb_sound = $BombSound
@onready var win_sound = $WinSound
@onready var menu_sound = $MenuSound
@onready var defeat_sound = $DefeatSound

# GÖRSEL VARLIKLAR
var mine_tex = preload("res://ChatGPT Image 30 Oca 2026 19_01_01.png")

# DİL VE SES AYARLARI
var sfx_enabled = true
var current_lang = "tr"
var langs = ["tr", "en", "fr"]
var lang_names = {"tr": "Türkçe", "en": "English", "fr": "Français"}

var translations = {
	"tr": {
		"title": "MAYIN TARLASI\nPRO", "start": "OYUNA BAŞLA", "leaderboard": "LİDERLİK TABLOSU",
		"settings": "AYARLAR", "exit": "ÇIKIŞ", "back": "GERİ", "sound": "SES: ", "lang": "DİL: ",
		"on": "AÇIK", "off": "KAPALI", "easy": "KOLAY", "medium": "ORTA", "hard": "ZOR",
		"xray": "RÖNTGEN", "ad": "REKLAM (+500)", "best": "EN İYİ: ", "insufficient": "PUAN YETERSİZ!",
		"win": "TEBRİKLER! 🎉", "lose": "PATLADIN! 💥", "top10": "[ 🏆 TOP 10 SKOR 🏆 ]",
		"rank": "SIRALAMA", "pause": "DURAKLAT", "resume": "DEVAM ET", "paused_title": "OYUN DURDURULDU",
		"mode_dig": "MOD: KAZMA ⛏️", "mode_flag": "MOD: BAYRAK 🚩" # Mobil için eklendi
	},
	"en": {
		"title": "MINESWEEPER\nPRO", "start": "START GAME", "leaderboard": "LEADERBOARD",
		"settings": "SETTINGS", "exit": "EXIT", "back": "BACK", "sound": "SOUND: ", "lang": "LANG: ",
		"on": "ON", "off": "OFF", "easy": "EASY", "medium": "MEDIUM", "hard": "HARD",
		"xray": "X-RAY", "ad": "WATCH AD (+500)", "best": "BEST: ", "insufficient": "NOT ENOUGH PTS!",
		"win": "CONGRATS! 🎉", "lose": "GAME OVER! 💥", "top10": "[ 🏆 TOP 10 SCORES 🏆 ]",
		"rank": "RANK", "pause": "PAUSE", "resume": "RESUME", "paused_title": "GAME PAUSED",
		"mode_dig": "MODE: DIG ⛏️", "mode_flag": "MODE: FLAG 🚩"
	},
	"fr": {
		"title": "DÉMINEUR\nPRO", "start": "JOUER", "leaderboard": "CLASSEMENT",
		"settings": "OPTIONS", "exit": "QUITTER", "back": "RETOUR", "sound": "SON: ", "lang": "LANGUE: ",
		"on": "ACTIF", "off": "DÉSACTIF", "easy": "FACILE", "medium": "MOYEN", "hard": "DIFFICILE",
		"xray": "RAYONS X", "ad": "PUB (+500)", "best": "MEILLEUR: ", "insufficient": "PTS INSUFFISANTS!",
		"win": "BRAVO! 🎉", "lose": "PERDU! 💥", "top10": "[ 🏆 TOP 10 SCORES 🏆 ]",
		"rank": "RANG", "pause": "PAUSE", "resume": "REPRENDRE", "paused_title": "JEU PAUSÉ",
		"mode_dig": "MODE: PELLE ⛏️", "mode_flag": "MODE: DRAPEAU 🚩"
	}
}

func tr_c(key):
	return translations[current_lang][key]

# OYUN AYARLARI
var grid_size = 8
var mine_count = 10
var cell_size = 60
var grid_width_px = 640

var grid = []
var mines = []
var game_finished = false
var game_started = false
var first_click_done = false
var is_xray_active = false
var is_paused = false
var is_flag_mode = false # MOBİL: Bayrak modu kontrolü

# MOBİL DOKUNMA TAKİBİ
var touch_start_time = 0.0
var long_press_threshold = 400 # ms cinsinden (0.4 saniye)

# EKONOMİ AYARLARI
var scan_cost = 200

var timer: Timer
var time_label: Label
var score_label: Label
var flag_label: Label
var best_label: Label
var result_label: Label
var main_container: Control
var pause_overlay: ColorRect
var confetti: GPUParticles2D
var ambient_particles: GPUParticles2D

var menu_buttons = []
var restart_button: Button
var pause_button: Button
var mode_toggle_button: Button # MOBİL: Mod değiştirme butonu
var xray_button: Button
var ad_button: Button

var max_time = 120
var time_left = 120
var score = 0
var flags_left = 0
var best_score = 0
var leaderboard = []

func _ready():
	randomize()
	# Mobil dokunmatik simülasyonunu aktif et
	ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", true)
	load_data()
	create_background()
	create_ambient_particles()
	create_ui_container()
	create_confetti()
	create_pause_overlay()
	create_start_menu()

# ---------- VERİ KAYIT ----------
func load_data():
	if FileAccess.file_exists("user://save.dat"):
		var f = FileAccess.open("user://save.dat", FileAccess.READ)
		var data = f.get_var()
		if data is Dictionary:
			best_score = data.get("best", 0)
			leaderboard = data.get("scores", [])
			current_lang = data.get("lang", "tr")
		f.close()

func save_data():
	leaderboard.sort()
	leaderboard.reverse()
	if leaderboard.size() > 10: leaderboard.resize(10)
	if score > best_score: best_score = score
	var f = FileAccess.open("user://save.dat", FileAccess.WRITE)
	var save_data = {"best": best_score, "scores": leaderboard, "lang": current_lang}
	f.store_var(save_data)
	f.close()

# ---------- GÖRSEL VE EFEKT ----------
func create_background():
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.12)
	bg.size = Vector2(700, 1000)
	add_child(bg)

func apply_screen_shake():
	var tween = create_tween()
	var original_pos = main_container.position
	for i in range(8):
		var rand_pos = original_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		tween.tween_property(main_container, "position", rand_pos, 0.03)
	tween.tween_property(main_container, "position", original_pos, 0.03)

func create_ambient_particles():
	ambient_particles = GPUParticles2D.new()
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(350, 500, 1)
	mat.gravity = Vector3(0, -10, 0)
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.scale_min = 1.0
	mat.scale_max = 3.0
	ambient_particles.process_material = mat
	ambient_particles.amount = 40
	ambient_particles.lifetime = 10
	ambient_particles.preprocess = 5
	ambient_particles.position = Vector2(350, 500)
	ambient_particles.modulate = Color(1, 1, 1, 0.2)
	add_child(ambient_particles)

func create_ui_container():
	main_container = Control.new()
	main_container.size = Vector2(700, 1000)
	add_child(main_container)

func create_confetti():
	confetti = GPUParticles2D.new()
	var mat = ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, 400, 0)
	mat.initial_velocity_min = 200
	mat.initial_velocity_max = 400
	mat.spread = 90.0
	mat.color = Color(1, 0.8, 0, 1)
	confetti.process_material = mat
	confetti.amount = 200
	confetti.lifetime = 2.5
	confetti.one_shot = true
	confetti.emitting = false
	confetti.position = Vector2(350, -50)
	add_child(confetti)

# ---------- DURAKLATMA SİSTEMİ ----------
func create_pause_overlay():
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0, 0, 0, 0.7)
	pause_overlay.size = Vector2(700, 1000)
	pause_overlay.visible = false
	pause_overlay.z_index = 10
	add_child(pause_overlay)
	
	var p_label = Label.new()
	p_label.name = "PauseTitle"
	p_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_label.size = Vector2(700, 100)
	p_label.position = Vector2(0, 400)
	p_label.add_theme_font_size_override("font_size", 40)
	pause_overlay.add_child(p_label)
	
	var resume_btn = Button.new()
	resume_btn.name = "ResumeBtn"
	resume_btn.size = Vector2(200, 60)
	resume_btn.position = Vector2(250, 550)
	resume_btn.pressed.connect(toggle_pause)
	pause_overlay.add_child(resume_btn)

func toggle_pause():
	if not game_started or game_finished: return
	is_paused = !is_paused
	pause_overlay.visible = is_paused
	
	if is_paused:
		timer.stop()
		pause_overlay.get_node("PauseTitle").text = tr_c("paused_title")
		pause_overlay.get_node("ResumeBtn").text = tr_c("resume")
		pause_overlay.get_node("ResumeBtn").add_theme_stylebox_override("normal", get_button_style(Color.DARK_GREEN))
	else:
		timer.start()

# ---------- STİL ----------
func get_button_style(color: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(15)
	style.border_width_bottom = 6
	style.border_color = color.darkened(0.4)
	return style

func get_cell_style(opened: bool):
	var style = StyleBoxFlat.new()
	if opened:
		style.bg_color = Color(0.08, 0.1, 0.15)
		style.set_border_width_all(1)
		style.border_color = Color(0.2, 0.2, 0.3)
	else:
		style.bg_color = Color(0.2, 0.25, 0.4)
		style.border_width_bottom = 3
		style.border_color = Color(0.1, 0.1, 0.2)
	style.set_corner_radius_all(8)
	return style

# ---------- MENÜLER ----------
func create_start_menu():
	clear_menu()
	var title = Label.new()
	title.text = tr_c("title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(150, 60)
	title.size = Vector2(400, 100)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_outline_color", Color.CYAN)
	title.add_theme_constant_override("outline_size", 12)
	main_container.add_child(title)
	menu_buttons.append(title)
	
	create_menu_button(tr_c("start"), Vector2(230, 260), Color.DARK_GREEN, show_difficulty_menu)
	create_menu_button(tr_c("leaderboard"), Vector2(230, 340), Color.GOLD, show_leaderboard_menu)
	create_menu_button(tr_c("settings"), Vector2(230, 420), Color.ORANGE, show_settings_menu)
	create_menu_button(tr_c("exit"), Vector2(230, 500), Color.DARK_RED, func(): get_tree().quit())

func show_leaderboard_menu():
	clear_menu()
	var label_list = create_label(Vector2(230, 180))
	label_list.text = tr_c("top10") + "\n"
	label_list.add_theme_font_size_override("font_size", 24)
	for i in range(leaderboard.size()):
		label_list.text += "\n" + str(i+1) + ". " + tr_c("rank") + ": " + str(leaderboard[i])
	menu_buttons.append(label_list)
	create_menu_button(tr_c("back"), Vector2(230, 550), Color.DARK_SLATE_GRAY, create_start_menu)

func show_settings_menu():
	clear_menu()
	var ses_durumu = tr_c("on") if sfx_enabled else tr_c("off")
	create_menu_button(tr_c("sound") + ses_durumu, Vector2(230, 260), Color.CYAN, toggle_sfx)
	create_menu_button(tr_c("lang") + lang_names[current_lang], Vector2(230, 340), Color.MEDIUM_PURPLE, cycle_language)
	create_menu_button(tr_c("back"), Vector2(230, 420), Color.GRAY, create_start_menu)

func cycle_language():
	var idx = langs.find(current_lang)
	current_lang = langs[(idx + 1) % langs.size()]
	save_data()
	show_settings_menu()

func create_menu_button(text, pos, color, callback):
	var btn = Button.new()
	btn.text = text
	btn.position = pos + Vector2(0, 50)
	btn.size = Vector2(240, 60)
	btn.pivot_offset = btn.size / 2
	btn.add_theme_stylebox_override("normal", get_button_style(color))
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func():
		play_sfx(menu_sound)
		callback.call()
	)
	main_container.add_child(btn)
	menu_buttons.append(btn)
	var tween = create_tween()
	tween.tween_property(btn, "position", pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return btn

func toggle_sfx():
	sfx_enabled = !sfx_enabled
	show_settings_menu()

func show_difficulty_menu():
	clear_menu()
	create_menu_button(tr_c("easy"), Vector2(230, 250), Color.CORNFLOWER_BLUE, func(): start_game_with_level(6, 6))
	create_menu_button(tr_c("medium"), Vector2(230, 330), Color.ORANGE, func(): start_game_with_level(8, 12))
	create_menu_button(tr_c("hard"), Vector2(230, 410), Color.CRIMSON, func(): start_game_with_level(12, 20))

func clear_menu():
	for b in menu_buttons:
		if is_instance_valid(b): b.queue_free()
	menu_buttons.clear()

# ---------- OYUN ----------
func start_game_with_level(size, mines_count):
	grid_size = size
	mine_count = mines_count
	flags_left = mine_count
	game_started = true
	game_finished = false
	first_click_done = false
	is_paused = false
	is_flag_mode = false # Sıfırla
	score = 0
	clear_menu()
	cell_size = int(grid_width_px / grid_size) - 4
	if cell_size > 60: cell_size = 60
	max_time = 120
	create_ui_elements()
	create_grid()
	start_timer()

func create_ui_elements():
	restart_button = create_menu_button(tr_c("back"), Vector2(20, 20), Color.DARK_SLATE_GRAY, _on_restart_pressed)
	restart_button.size = Vector2(100, 40)
	
	pause_button = Button.new()
	pause_button.text = tr_c("pause")
	pause_button.position = Vector2(130, 20)
	pause_button.size = Vector2(120, 40)
	pause_button.add_theme_stylebox_override("normal", get_button_style(Color.DARK_ORCHID))
	pause_button.pressed.connect(toggle_pause)
	main_container.add_child(pause_button)

	# MOBİL: Mod değiştirme butonu ekle
	mode_toggle_button = Button.new()
	mode_toggle_button.text = tr_c("mode_dig")
	mode_toggle_button.position = Vector2(220, 880) # Ekranın altı
	mode_toggle_button.size = Vector2(260, 60)
	mode_toggle_button.add_theme_stylebox_override("normal", get_button_style(Color.DARK_SLATE_BLUE))
	mode_toggle_button.pressed.connect(_on_mode_toggle_pressed)
	main_container.add_child(mode_toggle_button)

	xray_button = Button.new()
	xray_button.text = tr_c("xray") + " (" + str(scan_cost) + ")"
	xray_button.position = Vector2(20, 120)
	xray_button.size = Vector2(160, 45)
	xray_button.add_theme_stylebox_override("normal", get_button_style(Color.PURPLE))
	xray_button.pressed.connect(_on_xray_pressed)
	main_container.add_child(xray_button)
	
	ad_button = Button.new()
	ad_button.text = tr_c("ad")
	ad_button.position = Vector2(500, 120)
	ad_button.size = Vector2(180, 45)
	ad_button.add_theme_stylebox_override("normal", get_button_style(Color.GOLDENROD))
	ad_button.pressed.connect(_on_ad_pressed)
	main_container.add_child(ad_button)
	
	time_label = create_label(Vector2(280, 25))
	score_label = create_label(Vector2(400, 25))
	flag_label = create_label(Vector2(550, 25))
	best_label = create_label(Vector2(320, 60))
	result_label = create_label(Vector2(240, 110))
	result_label.add_theme_font_size_override("font_size", 32)

func _on_mode_toggle_pressed():
	is_flag_mode = !is_flag_mode
	mode_toggle_button.text = tr_c("mode_flag") if is_flag_mode else tr_c("mode_dig")
	var color = Color.GOLD if is_flag_mode else Color.DARK_SLATE_BLUE
	mode_toggle_button.add_theme_stylebox_override("normal", get_button_style(color))
	play_sfx(menu_sound)

func create_label(pos):
	var lbl = Label.new()
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color.YELLOW)
	main_container.add_child(lbl)
	return lbl

func create_grid():
	grid.clear()
	var total_grid_width = grid_size * (cell_size + 4)
	var offset_x = (700 - total_grid_width) / 2
	for y in range(grid_size):
		grid.append([])
		for x in range(grid_size):
			var btn = Button.new()
			btn.position = Vector2(x*(cell_size+4)+offset_x, y*(cell_size+4)+190)
			btn.size = Vector2(cell_size, cell_size)
			btn.pivot_offset = Vector2(cell_size/2, cell_size/2)
			btn.expand_icon = true
			btn.add_theme_stylebox_override("normal", get_cell_style(false))
			btn.gui_input.connect(func(event): _on_cell_input(event, x, y))
			main_container.add_child(btn)
			grid[y].append(btn)

func place_mines_safe(safe_x, safe_y):
	mines.clear()
	while mines.size() < mine_count:
		var pos = Vector2(randi()%grid_size, randi()%grid_size)
		if pos != Vector2(safe_x, safe_y) and not mines.has(pos):
			mines.append(pos)

func _on_cell_input(event, x, y):
	if game_finished or not game_started or is_xray_active or is_paused: return
	
	if event is InputEventMouseButton:
		# SOL TIK / DOKUNMA
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				touch_start_time = Time.get_ticks_msec()
			else:
				var duration = Time.get_ticks_msec() - touch_start_time
				if duration >= long_press_threshold:
					# UZUN BASMA -> Bayrak Koy (Hangi modda olursa olsun)
					toggle_flag(x, y)
				else:
					# KISA BASMA -> Mod kontrolü
					if is_flag_mode:
						toggle_flag(x, y)
					else:
						reveal_cell(x, y)
		
		# SAĞ TIK (Bilgisayar için hala kalsın)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			toggle_flag(x,y)

func reveal_cell(x,y):
	var btn = grid[y][x]
	if btn.get_meta("opened",false) or btn.text == "🚩": return
	
	if not first_click_done:
		place_mines_safe(x, y)
		first_click_done = true
	
	play_sfx(click_sound)
	btn.set_meta("opened",true)
	btn.add_theme_stylebox_override("normal", get_cell_style(true))
	
	btn.scale = Vector2(0.5, 0.5)
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if mines.has(Vector2(x,y)):
		show_mine_visual(btn)
		game_over(false)
		return
		
	var count = count_adjacent_mines(x,y)
	if count > 0:
		btn.text = str(count)
		set_number_color(btn,count)
	else:
		for i in range(-1,2):
			for j in range(-1,2):
				var nx=x+i; var ny=y+j
				if nx>=0 and ny>=0 and nx<grid_size and ny<grid_size: reveal_cell(nx,ny)
	score += 10
	update_ui()
	check_win()

func _on_xray_pressed():
	if game_finished or is_xray_active or is_paused: return
	if score >= scan_cost:
		score -= scan_cost
		activate_xray()
		update_ui()

func activate_xray():
	is_xray_active = true
	for pos in mines:
		var btn = grid[pos.y][pos.x]
		if not btn.get_meta("opened", false):
			btn.icon = mine_tex
			btn.modulate.a = 0.4
	await get_tree().create_timer(1.5).timeout
	for pos in mines:
		var btn = grid[pos.y][pos.x]
		if not btn.get_meta("opened", false):
			btn.modulate.a = 1.0
			btn.icon = null
	is_xray_active = false

func _on_ad_pressed():
	score += 500
	update_ui()

func set_number_color(btn,count):
	var colors=[Color.WHITE, Color.CORNFLOWER_BLUE, Color.LIME_GREEN, Color.CRIMSON, Color.MEDIUM_PURPLE, Color.ORANGE]
	btn.add_theme_color_override("font_color", colors[min(count,5)])

func toggle_flag(x,y):
	var btn=grid[y][x]
	if btn.get_meta("opened",false) or is_paused: return
	if btn.text=="🚩":
		btn.text=""
		flags_left+=1
	else:
		if flags_left<=0:return
		btn.text="🚩"
		btn.add_theme_color_override("font_color", Color.GOLD)
		flags_left-=1
	update_ui()

func count_adjacent_mines(x,y):
	var c=0
	for i in range(-1,2):
		for j in range(-1,2):
			if mines.has(Vector2(x+i,y+j)): c+=1
	return c

func start_timer():
	if timer: timer.queue_free()
	timer=Timer.new()
	timer.wait_time=1
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	time_left=120
	timer.start()

func _on_timer_timeout():
	if game_finished or is_paused: return
	time_left-=1
	update_ui()
	if time_left<=0: game_over(false)

func update_ui():
	time_label.text="⏳ " + str(time_left)
	score_label.text="💎 " + str(score)
	flag_label.text="💣 " + str(flags_left)
	best_label.text= tr_c("best") + str(best_score)

func show_mine_visual(btn):
	btn.text = ""
	btn.icon = mine_tex

func game_over(win):
	if game_finished: return
	game_finished=true
	timer.stop()
	if win:
		play_sfx(win_sound)
		confetti.emitting=true
		result_label.text = tr_c("win")
		leaderboard.append(score)
	else:
		play_sfx(defeat_sound)
		apply_screen_shake()
		result_label.text = tr_c("lose")
	for pos in mines: show_mine_visual(grid[pos.y][pos.x])
	save_data()
	update_ui()

func check_win():
	var opened=0
	for row in grid:
		for btn in row:
			if btn.get_meta("opened",false): opened+=1
	if opened==(grid_size*grid_size)-mine_count: game_over(true)

func play_sfx(sound):
	if sfx_enabled and is_instance_valid(sound): sound.play()

func _on_restart_pressed():
	get_tree().reload_current_scene()
