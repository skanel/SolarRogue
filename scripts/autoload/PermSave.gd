extends Node


enum END_GAME_STATE {
	destroyed,
	entropy,
	won
}

#TODO: Might want to add more info about the player (cargo inventory, # of turn spent, etc.
var _perm_save = {
	"settings": {
		"default_name":"Ombarus"
	},
	"leaderboard": [
		{"player_name":"Ombarus the greatest", "final_score":100000, "status":END_GAME_STATE.won, "generated_levels":20, "died_on":-1},
		{"player_name":"Ombarus the greater", "final_score":50000, "status":END_GAME_STATE.won, "generated_levels":16, "died_on": -1},
		{"player_name":"Ombarus the great", "final_score":25000, "status":END_GAME_STATE.destroyed, "generated_levels":5, "died_on": 5},
		{"player_name":"Ombarus", "final_score":1000, "status":END_GAME_STATE.entropy, "generated_levels":2, "died_on":1}
	]
}

#TODO: Add versionning here too
var _savefile_name = "user://perm_config.save"

func _ready():
	if File.new().file_exists(_savefile_name):
		var file = File.new()
		file.open(_savefile_name, file.READ)
		var text = file.get_as_text()
		var _perm_save = JSON.parse(text)
		file.close()

func get_attrib(path, default=null):
	return Globals.get_data(_perm_save, path, default)

func set_attrib(path, val, save=true):
	Globals.set_data(_perm_save, path, val)
	if save == true:
		save()
	
func save():
	var save_game = File.new()
	save_game.open(_savefile_name, File.WRITE)
	save_game.store_line(to_json(_perm_save))
	save_game.close()
