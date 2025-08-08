extends Node

# --- Variabel Lokal ---
var high_score = 0
const SAVE_PATH = "user://highscore.dat"

# --- Variabel Konfigurasi Firebase ---
# GANTI DENGAN INFORMASI DARI PROYEK FIREBASE ANDA
var api_key = "AIzaSyC1GQ6CcYG40qbTU4btpD9KDJPMF5xiUho"
var project_id = "sortify-game"

# --- Variabel untuk Komunikasi ---
var http_request: HTTPRequest
var user_id = "" # Didapat setelah login anonim
var id_token = "" # Token untuk otentikasi permintaan ke Firestore

# Dipanggil saat game dimulai
func _ready():
	# Buat node HTTPRequest secara dinamis saat game berjalan
	http_request = HTTPRequest.new()
	add_child(http_request)
	
	load_high_score_local()
	login_anonymously() # Ganti nama dari init_firebase

# --- Fungsi Komunikasi Firebase via REST API ---

func login_anonymously():
	print("Attempting anonymous login via REST API...")
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + api_key
	var headers = ["Content-Type: application/json"]
	var body_dict = {"returnSecureToken": true}
	var body = JSON.stringify(body_dict)

	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Failed to start HTTPRequest, error code:", err)
		return

	var result = await http_request.request_completed
	# result = [result_code, http_status, response_headers, body_poolbytearray]
	var result_code = result[0]
	var http_status = result[1]
	var raw_body = ""
	if result.size() >= 4 and result[3] != null:
		raw_body = result[3].get_string_from_utf8()
	
	print("Request completed. result_code:", result_code, "http_status:", http_status)
	print("Raw response body:", raw_body)

	# Coba parse JSON (tambah pengecekan)
	var parsed = null
	if raw_body.length() > 0:
		parsed = JSON.parse_string(raw_body)
		# Kalau JSON.parse_string mengembalikan object, gunakan langsung; jika null, print pesan
		if parsed == null:
			print("JSON.parse_string returned null")
		else:
			# parsed diharapkan dictionary, tapi tergantung versi Godot; cek dulu
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("localId"):
				user_id = parsed["localId"]
			elif typeof(parsed) == TYPE_OBJECT and parsed.has_method("get"): # fallback
				# contoh fallback, jarang diperlukan
				user_id = parsed["localId"]
			
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("idToken"):
				id_token = parsed["idToken"]

	# Keberhasilan: RESULT_SUCCESS + HTTP 200
	if result_code == HTTPRequest.RESULT_SUCCESS and http_status == 200:
		print("Login success! User ID:", user_id)
		load_high_score_from_firebase()
	else:
		print("Firebase login failed. HTTP status:", http_status, "result_code:", result_code)
		# sudah mencetak raw_body di atas untuk debugging

func load_high_score_from_firebase():
	if user_id.is_empty():
		print("No user_id yet, skip firebase fetch")
		return

	print("Fetching high score from Firebase via REST API...")
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/highscores/%s" % [project_id, user_id]
	var headers = ["Authorization: Bearer " + id_token]

	# Buat HTTPRequest sementara supaya tidak bentrok dengan request lain
	var req = HTTPRequest.new()
	add_child(req)
	var err = req.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("Failed to start HTTPRequest for firestore, err:", err)
		req.queue_free()
		return

	var res = await req.request_completed
	# res = [result_code, http_status, response_headers, body]
	var result_code = res[0]
	var http_status = res[1]
	var raw_body = ""
	if res.size() >= 4 and res[3] != null:
		raw_body = res[3].get_string_from_utf8()

	print("Firestore fetch status:", http_status, "body:", raw_body)

	# Hapus node request sementara
	req.queue_free()

	if result_code == HTTPRequest.RESULT_SUCCESS and http_status == 200:
		var parsed = {}
		var parsed_ok = false
		# JSON.parse_string kadang return Dictionary langsung; tangani aman
		var p = JSON.parse_string(raw_body)
		if typeof(p) == TYPE_DICTIONARY:
			parsed = p
			parsed_ok = true
		elif typeof(p) == TYPE_OBJECT and p.has("get"): # fallback
			parsed = p
			parsed_ok = true

		if parsed_ok and parsed.has("fields") and parsed["fields"].has("score"):
			# integerValue biasanya string, ambil dan konversi
			var int_val = parsed["fields"]["score"].get("integerValue", "")
			var firebase_score = 0
			if typeof(int_val) == TYPE_STRING:
				firebase_score = int(int_val)
			elif typeof(int_val) == TYPE_INT:
				firebase_score = int_val
			# Pakai nilai firebase sebagai high_score jika lebih besar
			if firebase_score > high_score:
				high_score = firebase_score
				save_high_score_local()
				print("Loaded high_score from Firebase:", high_score)
			else:
				print("Firebase high score not higher than local:", firebase_score, high_score)
		else:
			print("No high score fields found in Firestore document (or parsing failed).")
	else:
		if http_status == 404:
			print("No high score document on Firestore (404) — that's OK for new user.")
		else:
			print("Failed to fetch high score from Firestore. HTTP status:", http_status, "result_code:", result_code)


func save_high_score(new_score):
	if new_score <= high_score:
		return

	high_score = new_score
	save_high_score_local()

	if user_id.is_empty():
		print("No user_id yet; skip saving to Firestore")
		return

	print("Saving new high score to Firebase via REST API...")

	# POST ke collection dengan documentId=user_id (create or overwrite)
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/highscores?documentId=%s" % [project_id, user_id]
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + id_token
	]

	var firestore_json = {
		"fields": {
			"score": {
				"integerValue": str(new_score) # firestore expects string for integerValue
			}
		}
	}
	var body = JSON.stringify(firestore_json)

	# New HTTPRequest node untuk menghindari collision
	var req = HTTPRequest.new()
	add_child(req)
	var err = req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Failed to start HTTPRequest for saving score, err:", err)
		req.queue_free()
		return

	var res = await req.request_completed
	var result_code = res[0]
	var http_status = res[1]
	var raw_body = ""
	if res.size() >= 4 and res[3] != null:
		raw_body = res[3].get_string_from_utf8()

	print("Save request completed. result_code:", result_code, "http_status:", http_status)
	print("Raw response body:", raw_body)

	req.queue_free()

	if result_code == HTTPRequest.RESULT_SUCCESS and (http_status == 200 or http_status == 201):
		print("High score saved successfully to Firestore.")
	else:
		print("Failed to save high score. HTTP status:", http_status)
		# Jika permission error, raw_body akan berisi pesan PERMISSION_DENIED atau sejenisnya

var _saved_this_game := false

func on_game_over(current_score):
	if _saved_this_game:
		return
	_saved_this_game = true

	print("Game Over. Final score:", current_score)
	save_high_score(current_score)
	# tampilkan UI game over, dsb.


# --- Fungsi Lokal (tidak berubah) ---
func save_high_score_local():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(high_score)
	file.close()

func load_high_score_local():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		high_score = file.get_var()
		file.close()
	else:
		high_score = 0
