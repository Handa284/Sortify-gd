extends Control
@onready var high_score_label = $TextureRect/VBoxContainer/HighScoreLabel

func _ready():
	high_score_label.text = "Highest Score: " + str(GameManager.high_score)
	
func _on_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")
