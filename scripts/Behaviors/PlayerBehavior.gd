extends Node

export(NodePath) var levelLoaderNode
export(NodePath) var WeaponAction
export(NodePath) var GrabAction
export(NodePath) var DropAction
export(NodePath) var CraftingAction
export(NodePath) var FTLAction
export(NodePath) var EquipAction

var playerNode = null
var levelLoaderRef
var click_start_pos
var lock_input = false # when it's not player turn, inputs are locked

enum INPUT_STATE {
	hud,
	grid_targetting,
	cell_targetting
}
var _input_state = INPUT_STATE.hud

enum PLAYER_ORIGIN {
	wormhole,
	random,
	saved
}
var _current_origin = PLAYER_ORIGIN.saved
var _wormhole_src = null # for positioning the player when he goes up or down

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	levelLoaderRef = get_node(levelLoaderNode)
	
	var action = get_node(WeaponAction)
	action.connect("pressed", self, "Pressed_Weapon_Callback")
	action = get_node(GrabAction)
	action.connect("pressed", self, "Pressed_Grab_Callback")
	action = get_node(DropAction)
	action.connect("pressed", self, "Pressed_Drop_Callback")
	action = get_node(FTLAction)
	action.connect("pressed", self, "Pressed_FTL_Callback")
	action = get_node(CraftingAction)
	action.connect("pressed", self, "Pressed_Crafting_Callback")
	action = get_node(EquipAction)
	action.connect("pressed", self, "Pressed_Equip_Callback")
	
	BehaviorEvents.connect("OnLevelLoaded", self, "OnLevelLoaded_Callback")
	BehaviorEvents.connect("OnObjTurn", self, "OnObjTurn_Callback")
	BehaviorEvents.connect("OnRequestObjectUnload", self, "OnRequestObjectUnload_Callback")
	
func Pressed_Equip_Callback():
	if lock_input:
		return
	
	BehaviorEvents.emit_signal("OnPushGUI", "EquipMountList", {"object":playerNode, "callback_object":self, "callback_method":"OnEquip_Callback"})
	
# mount_to = "converter"
# mount_item = {"src":"data/json/bleh.json", "count":5}
func OnEquip_Callback(mount_item, mount_to):
	BehaviorEvents.emit_signal("OnEquipMount", playerNode, mount_to, mount_item)
	var converter = playerNode.get_attrib("mounts.converter")
	var converter_btn = get_node(CraftingAction)
	if converter == null or converter == "":
		converter_btn.visible = false
	else:
		converter_btn.visible = true
	
func Pressed_Crafting_Callback():
	if lock_input:
		return
	
	BehaviorEvents.emit_signal("OnPushGUI", "Converter", {"object":playerNode, "callback_object":self, "callback_method":"OnCraft_Callback"})
	
func OnCraft_Callback(recipe_data, input_list):
	var craftingSystem = get_parent().get_node("Crafting")
	var result = craftingSystem.Craft(recipe_data, input_list, playerNode)
	if result == Globals.CRAFT_RESULT.success:
		BehaviorEvents.emit_signal("OnLogLine", "Production sucessful")
	elif result == Globals.CRAFT_RESULT.not_enough_resources:
		BehaviorEvents.emit_signal("OnLogLine", "Missing resources")
	elif result == Globals.CRAFT_RESULT.not_enough_energy:
		BehaviorEvents.emit_signal("OnLogLine", "Not enough energy")
	else:
		BehaviorEvents.emit_signal("OnLogLine", "Crafting failed")
		
	
func Pressed_Grab_Callback():
	if lock_input:
		return
		
	BehaviorEvents.emit_signal("OnPickup", playerNode, Globals.LevelLoaderRef.World_to_Tile(playerNode.position))
	
func Pressed_Drop_Callback():
	if lock_input:
		return
		
	BehaviorEvents.emit_signal("OnPushGUI", "Inventory", {"object":playerNode, "callback_object":self, "callback_method":"OnDropIventory_Callback"})

func Pressed_FTL_Callback():
	var wormholes = Globals.LevelLoaderRef.objByType["wormhole"]
	var wormhole = null
	for w in wormholes:
		if w.position == playerNode.position:
			wormhole = w
			break
	if wormhole == null:
		return
	
	var cur_depth = Globals.LevelLoaderRef.current_depth
	
	_current_origin = PLAYER_ORIGIN.wormhole
	_wormhole_src = Globals.LevelLoaderRef._current_level_data.src
		
	BehaviorEvents.emit_signal("OnRequestLevelChange", wormhole)

func OnDropIventory_Callback(dropped_mounts, dropped_cargo):
	playerNode.init_mounts()
	for drop_data in dropped_mounts:
		BehaviorEvents.emit_signal("OnDropMount", playerNode, drop_data)
		
	var converter = playerNode.get_attrib("mounts.converter")
	var converter_btn = get_node(CraftingAction)
	if converter == null or converter == "":
		converter_btn.visible = false
	else:
		converter_btn.visible = true
		
	for drop_data in dropped_cargo:
		BehaviorEvents.emit_signal("OnDropCargo", playerNode, drop_data.src)
	
func OnRequestObjectUnload_Callback(obj):
	if obj.get_attrib("type") == "player":
		playerNode = null
	
func OnObjTurn_Callback(obj):
	if obj.get_attrib("type") == "player":
		print("On Player Turn : Unlock Input")
		lock_input = false
		
		var moved = obj.get_attrib("moving.moved")
		if  moved == true:
			obj.set_attrib("moving.moved", false)
			var tile_pos = Globals.LevelLoaderRef.World_to_Tile(obj.position)
			var content = Globals.LevelLoaderRef.levelTiles[tile_pos.x][tile_pos.y]
			var filtered = []
			var wormhole = null
			for c in content:
				if c != obj and not c.base_attributes.type in ["prop"]:
					filtered.push_back(c)
				if c != obj and c.get_attrib("type") in ["wormhole"]:
					wormhole = c
			if filtered.size() == 1:
				BehaviorEvents.emit_signal("OnLogLine", "Ship in range of " + filtered[0].get_attrib("name_id"))
			elif filtered.size() > 1:
				BehaviorEvents.emit_signal("OnLogLine", "Multiple Objects Detected")
			
			var btn = get_node(FTLAction)
			if wormhole != null:
				btn.visible = true
			else:
				btn.visible = false
	else:
		print("On AI Turn : LOCK Input !")
		lock_input = true
	
func Pressed_Weapon_Callback():
	if lock_input:
		return
		
	BehaviorEvents.emit_signal("OnLogLine", "Weapon System Online. Target ?")
	var weapon_json = playerNode.get_attrib("mounts.small_weapon_mount")
	var weapon_data = Globals.LevelLoaderRef.LoadJSON(weapon_json)
	BehaviorEvents.emit_signal("OnRequestPlayerTargetting", playerNode, weapon_data, self, "ProcessGridSelection")
	#BehaviorEvents.emit_signal("OnPushGUI", "GridPattern", null)
	_input_state = INPUT_STATE.grid_targetting
	
func OnLevelLoaded_Callback():
	print("OnLevelLoaded : unlock input")
	lock_input = false
	if playerNode == null:
		
		var save = Globals.LevelLoaderRef.cur_save
		if save == null or not save.has("player_data"):
			_current_origin = PLAYER_ORIGIN.wormhole
		
		var template = "data/json/ships/player_default.json"
		var level_id = Globals.LevelLoaderRef.GetLevelID()
		var coord
		
		if _current_origin == PLAYER_ORIGIN.random:
			var x = MersenneTwister.rand(Globals.LevelLoaderRef.levelSize.x)
			var y = MersenneTwister.rand(Globals.LevelLoaderRef.levelSize.y)
			coord = Vector2(x, y)
		
		if _current_origin == PLAYER_ORIGIN.saved && save != null && save.has("player_data"):
			#cur_save.player_data["src"] = objByType["player"][0].get_attrib("src")
			#cur_save.player_data["position_x"] = World_to_Tile(objByType["player"][0].position).y
			#cur_save.player_data["position_y"] = World_to_Tile(objByType["player"][0].position).x
			#cur_save.player_data["modified_attributes"] = objByType["player"][0].modified_attributes
			template = save.player_data.src
			coord = Vector2(save.player_data.position_x, save.player_data.position_y)
		
		var starting_wormhole = null
		if _current_origin == PLAYER_ORIGIN.wormhole:
			
			for w in levelLoaderRef.objByType["wormhole"]:
				var is_src_wormhole = _wormhole_src != null && _wormhole_src == w.get_attrib("src")
				var is_top_wormhole = starting_wormhole == null || w.modified_attributes["depth"] < starting_wormhole.modified_attributes["depth"]
				if (_wormhole_src == null && is_top_wormhole) || (is_src_wormhole):
					starting_wormhole = w
			
			coord = levelLoaderRef.World_to_Tile(starting_wormhole.position)
			
		#TODO: Pop menu for player creation ?
		var modififed_attrib = null
		if save != null && save.has("player_data"):
			modififed_attrib = save.player_data.modified_attributes
		# Modified_attrib must be passed during request so that proper IDs can be locked in objByID
		playerNode = levelLoaderRef.RequestObject("data/json/ships/player_default.json", coord, modififed_attrib)
		
		var converter = playerNode.get_attrib("mounts.converter")
		var converter_btn = get_node(CraftingAction)
		if converter == null or converter == "":
			converter_btn.visible = false
		else:
			converter_btn.visible = true
		
		# always default to saved position
		_current_origin = PLAYER_ORIGIN.saved
	


func _unhandled_input(event):
	if lock_input:
		return
		
	var dir = null
	if event is InputEventMouseButton:
		if event.is_action_pressed("touch"):
			click_start_pos = event.position
		if event.is_action_released("touch") && (click_start_pos - event.position).length_squared() < 5.0:
			var click_pos = playerNode.get_global_mouse_position()
			
			if _input_state == INPUT_STATE.grid_targetting:
				BehaviorEvents.emit_signal("OnTargetClick", click_pos)
			else:
				var player_pos = playerNode.position
				var click_dir = click_pos - player_pos
				var rot = rad2deg(Vector2(0.0, 0.0).angle_to_point(click_dir)) - 90.0
				if rot < 0:
					rot += 360
				print("player_pos ", player_pos, ", click_pos ", click_pos, ", rot ", rot)
				
				# Calculate direction based on touch relative to player position.
				# dead zone (click on sprite)
				if abs(click_dir.x) < levelLoaderRef.tileSize / 2 && abs(click_dir.y) < levelLoaderRef.tileSize / 2:
					BehaviorEvents.emit_signal("OnUseAP", playerNode, 1.0)
					BehaviorEvents.emit_signal("OnLogLine", "Cooling reactor (wait)")
					dir = null
				elif rot > 337.5 || rot <= 22.5:
					dir = Vector2(0,-1) # 8
				elif rot > 22.5 && rot <= 67.5:
					dir = Vector2(1,-1) # 9
				elif rot > 67.5 && rot <= 112.5:
					dir = Vector2(1,0) # 6
				elif rot > 112.5 && rot <= 157.5:
					dir = Vector2(1,1) # 3
				elif rot > 157.5 && rot <= 202.5:
					dir = Vector2(0,1) # 2
				elif rot > 202.5 && rot <= 247.5:
					dir = Vector2(-1,1) # 1
				elif rot > 247.5 && rot <= 292.5:
					dir = Vector2(-1,0) # 4
				elif rot > 292.5 && rot <= 337.5:
					dir = Vector2(-1,-1) # 7
				
	if event is InputEventKey && event.pressed == false:
		if event.scancode == KEY_KP_1:
			dir = Vector2(-1,1)
		if event.scancode == KEY_KP_2:
			dir = Vector2(0,1)
		if event.scancode == KEY_KP_3:
			dir = Vector2(1,1)
		if event.scancode == KEY_KP_4:
			dir = Vector2(-1,0)
		if event.scancode == KEY_KP_6:
			dir = Vector2(1,0)
		if event.scancode == KEY_KP_7:
			dir = Vector2(-1,-1)
		if event.scancode == KEY_KP_8:
			dir = Vector2(0,-1)
		if event.scancode == KEY_KP_9:
			dir = Vector2(1,-1)
		if event.scancode == KEY_KP_5:
			BehaviorEvents.emit_signal("OnUseAP", playerNode, 1.0)
			BehaviorEvents.emit_signal("OnLogLine", "Cooling reactor (wait)")			
		# GODOT cannot give me the real key that was pressed. Only the physical key
		# in En-US keyboard layout. There's no way to register a shortcut that's on a modifier (like !@#$%^&*())
		#TODO: Stay updated on this issue on their git tracker. This is serious enough to make me want to change engine
		#		On the other end. Being open-source I could probably hack something if it becomes too big an issue
		#		Check out : Godot_src\godot\scene\gui\text_edit.cpp for how they handle acutal text in input forms
		#		Check out : Godot_src\godot\core\os\input_event.cpp for how shortcut key inputs are handled
		if (event.scancode == KEY_PERIOD || event.scancode == KEY_COLON) && event.shift == true:
			Pressed_FTL_Callback()
		#print(event.scancode)
		#print ("key_period : ", KEY_PERIOD, ", key_comma : ", KEY_COLON)
	if dir != null:
		BehaviorEvents.emit_signal("OnMovement", playerNode, dir)


func ProcessGridSelection(pos):
	_input_state = INPUT_STATE.hud
	return
	