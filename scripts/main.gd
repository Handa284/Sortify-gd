extends Node2D

@onready var trash_scene = preload("res://scenes/trash.tscn")

# Variabel untuk menampung data permainan
var score = 0
var is_game_over = false

@onready var score_label = $HUD/ScoreLabel
@onready var game_over_screen = $GameOverScreen

@onready var spawn_timer = $TrashSpawnTimer

# Daftar tekstur sampah untuk memudahkan
var trash_textures: = {
	Trash.TrashType.ORGANIK: [
		preload("res://assets/sprite/Apple.png"),
		preload("res://assets/sprite/FishBone.png")
	],
	Trash.TrashType.B3: [ 
		preload("res://assets/sprite/Detergent.png"),
		preload("res://assets/sprite/Battery.png")
	],
	Trash.TrashType.PLASTIK: [
		preload("res://assets/sprite/PlasticBottle.png")
	]
}
var trash_types = [Trash.TrashType.ORGANIK, Trash.TrashType.B3, Trash.TrashType.PLASTIK]

func _ready():
	# Sembunyikan layar game over saat mulai
	game_over_screen.hide()
	start_game()

func start_game():
	# Reset semua variabel untuk permainan baru
	score = 0
	is_game_over = false
	update_score_label()
	game_over_screen.hide()
	await get_tree().create_timer(0.1).timeout
	spawn_timer.start()
	# Hapus sisa sampah dari permainan sebelumnya (jika ada)
	get_tree().call_group("trash_group", "queue_free")

func _on_trash_spawn_timer_timeout():
	print("DEBUG: Timer timeout! Mencoba memunculkan sampah...")
	if is_game_over:
		return

	# Buat instance sampah baru
	var new_trash = trash_scene.instantiate()

	# Pilih jenis sampah secara acak
	var random_type_index = randi() % trash_types.size()
	var selected_type = trash_types[random_type_index]
	new_trash.type = selected_type

	# Atur gambar berdasarkan jenisnya
	var tex_array = trash_textures[selected_type]
	var tex = tex_array[randi() % tex_array.size()]
	new_trash.get_node("Sprite2D").texture = tex

	# Tentukan posisi spawn acak di atas layar
	var screen_width = get_viewport_rect().size.x
	new_trash.position = Vector2(randf_range(50, screen_width - 50), -100)

	# Tambahkan sampah ke grup agar mudah dikelola
	new_trash.add_to_group("trash_group")
	add_child(new_trash)

func handle_trash_sorted(body, bin_type):
	# Cek apakah jenis sampah sesuai dengan jenis tempat sampah
	if body.type == bin_type:
		score += 10
		update_score_label()
		print("Correct! Score:", score)
	else:
		print("Wrong! Game Over.")
		game_over()

	# Hapus sampah yang sudah masuk
	body.queue_free()

func update_score_label():
	score_label.text = "Score: " + str(score)

func game_over():
	is_game_over = true
	spawn_timer.stop()
	game_over_screen.show()
	# Update teks di layar game over
	game_over_screen.get_node("ColorRect/VBoxContainer/YourScoreLabel").text = "Your Score: " + str(score)

	# Logika high score 
	GameManager.save_high_score(score)
	game_over_screen.get_node("ColorRect/VBoxContainer/HighScoreLabel").text = "Highest Score: " + str(GameManager.high_score)


func _on_bin_organik_body_entered(body):
	print("Sampah masuk ke bin Organik!")
	handle_trash_sorted(body, Trash.TrashType.ORGANIK)

func _on_bin_non_organik_body_entered(body: Node2D):
	print("Sampah masuk ke bin Plastik!")
	handle_trash_sorted(body, Trash.TrashType.PLASTIK)

func _on_bin_b_3_body_entered(body: Node2D):
	print("Sampah masuk ke bin B3!")
	handle_trash_sorted(body, Trash.TrashType.B3)

func _on_play_again_button_pressed() -> void:
	start_game()

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
