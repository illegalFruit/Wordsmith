extends Node

var game_ongoing = false
var team_order = ["RedSpy", "RedTeam", "BluSpy", "BluTeam"]
var flipped_cards = []	# Btns of flipped cards
var team_ctr = 0
var team_turn = "RedSpy"
var red_points = 0
var blu_points = 0
var timer = Timer.new()

func _ready():
	timer.connect("timeout", self, "timer_timeout") 
	add_child(timer)

func timer_timeout():
	pass

remotesync func DisallowTeamSwap():
	get_tree().current_scene.find_node("RedSpyBtn").disabled = true
	get_tree().current_scene.find_node("RedTeamBtn").disabled = true
	get_tree().current_scene.find_node("BluSpyBtn").disabled = true
	get_tree().current_scene.find_node("BluTeamBtn").disabled = true
	get_tree().current_scene.find_node("ObsBtn").disabled = true

remotesync func RoundStart():
	team_turn = team_order[team_ctr % team_order.size()]
	var my_team = Network.players[get_tree().get_network_unique_id()].team
	var grid_childs = get_tree().current_scene.find_node("GridContainer").get_children()
	# Start visual timer
	timer.start(180)
	# Set whos turn it is on the display
	var gui_turn_label = get_tree().current_scene.find_node("WhosTurn")
	match team_turn:
		"RedSpy": gui_turn_label.text = "R e d S p y  T u r n"
		"BluSpy": gui_turn_label.text = "B l u S p y  T u r n"
		"RedTeam": gui_turn_label.text = "R e d T e a m  T u r n"
		"BluTeam": gui_turn_label.text = "B l u T e a m  T u r n"
	# Set the gui color accent
	var panel = get_tree().current_scene.find_node("TopPanel")
	if team_turn in ["RedSpy", "RedTeam"]:
		panel.get('custom_styles/panel').bg_color = Color("#ff3d3d")
	else:
		panel.get('custom_styles/panel').bg_color = Color("#5069ff")
	# Reset all panels to default. Without this all players will have 
	# spy/spectator vision. This is relevant to newGame+
	for word in grid_childs:
		word.self_modulate = Color(1, 1, 1, 1)
		
	# Check if it is my turn or not 
	# If so, do the role specific mechanism 
	# Else disable all the words besides the already flipped ones
	for card in flipped_cards:
		if card in grid_childs:
			grid_childs.erase(card)
	for child in grid_childs:
		child.find_node("Button").disabled = true
	if team_turn == my_team:
		if team_turn in ["RedSpy", "BluSpy"]:
			var popup = get_tree().current_scene.find_node("Popup")
			popup.visible = true
			popup.find_node("Input1").text = ""
			popup.find_node("Input2").text = ""	
		else:
			for child in grid_childs:
				child.find_node("Button").disabled = false
	# Spectators and Spy's always get the border outline
	if my_team in ["RedSpy", "BluSpy", "Spectator"]:
		for g in grid_childs:
			match g.find_node("Button").team:
				"Black":
					g.self_modulate = Color(1, 1, 1, 1)
				"Yellow":
					g.self_modulate = Color(0.98, 1.01, 0.68, 0.9)
				"Red":
					g.self_modulate = Color(1, 0.24, 0.24, 1)
				"Blu":
					g.self_modulate = Color(0.31, 0.41, 1, 1)


remotesync func SetHintAndGuess(caller):
	var hint_label = get_tree().current_scene.find_node("HintWord")
	var guess_label = get_tree().current_scene.find_node("GuessNum")
	hint_label.text = caller["hint"]
	guess_label.text = caller["guess"]
	team_ctr += 1
	RoundStart()

func TrySwitchTeam(_update): # {id:12345, team:RedSpy}
	# Check if valid as in space for the switch
	# Return if theres no space to swap
	var team_size = 6
	match _update["team"]:
		"RedSpy":
			for k in Network.players.keys():
				if Network.players[k].team == "RedSpy":
					return
		"BluSpy":
			for k in Network.players.keys():
				if Network.players[k].team == "BluSpy":
					return
		"RedTeam":
			var count = 0
			for k in Network.players.keys():
				if Network.players[k].team == "RedTeam":
					count += 1
			if count == team_size:
				return
		"BluTeam":
			var count = 0
			for k in Network.players.keys():
				if Network.players[k].team == "BluTeam":
					count += 1
			if count == team_size:
				return
	rpc("SwitchTeam", _update)

remotesync func SwitchTeam(_update):
	# Do switch
	Network.players[_update["id"]].team = _update["team"]
	# Always redraw teams after receiving new info
	RedrawTeams()

remotesync func ChangeScene(scene):
	match scene:
		0:
			get_tree().change_scene("res://Scene/Game.tscn")

func RedrawTeams():
	var RedSpys = get_tree().current_scene.find_node("RedSpyVBox").get_children()
	var RedTeams = get_tree().current_scene.find_node("RedTeamVBox").get_children()
	var BluSpys = get_tree().current_scene.find_node("BluSpyVBox").get_children()
	var BluTeams = get_tree().current_scene.find_node("BluTeamVBox").get_children()
	var Spectators = get_tree().current_scene.find_node("SpectatorVBox").get_children()
	# Hide all player cards
	for c in RedSpys: c.visible = false
	for c in RedTeams: c.visible = false
	for c in BluSpys: c.visible = false
	for c in BluTeams: c.visible = false
	for c in Spectators: c.visible = false
	# Redraw player nameplates according to players
	# Find the closest available free nameplate
	for k in Network.players.keys():
		match Network.players[k].team:
			"RedSpy":
				RedSpys[0].find_node("Name").text = Network.players[k].name
				RedSpys[0].visible = true
			"RedTeam":
				for child in RedTeams:
					if child.visible == false:
						child.find_node("Name").text = Network.players[k].name
						child.visible = true
						break
			"BluSpy":
				BluSpys[0].find_node("Name").text = Network.players[k].name
				BluSpys[0].visible = true
			"BluTeam":
				for child in BluTeams:
					if child.visible == false:
						child.find_node("Name").text = Network.players[k].name
						child.visible = true
						break
			"Spectator":
				for child in Spectators:
					if child.visible == false:
						child.text = Network.players[k].name
						child.visible = true
						break

func StartGame():
	randomize()
	# Create word bank 
	var sliced_words = CreateWordBank()
	# Fill buttons, returns a copy for clients
	var client_word_copy = CreateButtons(sliced_words)
	# Send others the data to make their own buttons
	rpc("CopyButtons", [client_word_copy]) # {"word":, "team":}
	# Host signals game start. Will the rpc's clash in ordering?  
	rpc("RoundStart")

remote func CopyButtons(caller):
	var _client_word_copy = caller[0]
	var default_theme = load("res://Sytle/GreyTheme.tres")
	var grid_childs = get_tree().current_scene.find_node("GridContainer").get_children()
	for n in range(grid_childs.size()):
		grid_childs[n].find_node("Label").text = _client_word_copy[n].word
		grid_childs[n].find_node("Button").team = _client_word_copy[n].team
		grid_childs[n].find_node("Button").set_theme(default_theme)
		grid_childs[n].find_node("Button").disabled = false

func CreateButtons(_wordbank):
	var teams_picker = ["Black",
						"Red","Red","Red","Red","Red","Red","Red","Red","Red",
						"Blu","Blu","Blu","Blu","Blu","Blu","Blu","Blu",
						"Yellow","Yellow","Yellow","Yellow","Yellow","Yellow","Yellow"]
	var buttons = []
	var default_theme = load("res://Sytle/GreyTheme.tres")
	var grid_childs = get_tree().current_scene.find_node("GridContainer").get_children()
	teams_picker.shuffle()
	for child in grid_childs:
		child.find_node("Label").text = _wordbank[0]
		child.find_node("Button").team = teams_picker[0]
		child.find_node("Button").disabled = false
		child.find_node("Button").set_theme(default_theme)
		buttons.append(child)
		_wordbank.remove(0)
		teams_picker.remove(0)
	# Create client copy
	var button_copy = {}
	var childs = get_tree().current_scene.find_node("GridContainer").get_children()
	for n in range(childs.size()):
		var word = childs[n].find_node("Label").text
		var team = childs[n].find_node("Button").team
		button_copy[n] = {"word":word, "team":team}
	return button_copy

func CreateWordBank():
	var current_word_bank = "dog,cat,hampster,water,fish,bowl,hair,skin,legs,arms," \
							+ "brain,forrest,dessert,tundra,plain,toy,folder,data,pixel,monitor," \
							+ "speaker,hour,time,minute,second,paper,wood,plank,runescape," \
							+ "World of Warcraft,Neverwinter"
	var words_bank = current_word_bank.rsplit(",", true, 0)
	words_bank = Array(words_bank)
	words_bank.shuffle()
	return words_bank

remotesync func WordGuessed(caller): # {"id":, "word":}
	caller = caller[0]
	var flipped_card = null
	# Find the card and Add the card so it is never touched during roundStart
	for card_obj in get_tree().current_scene.find_node("GridContainer").get_children():
		if card_obj.find_node("Label").text == caller["word"]:
			flipped_card = card_obj.find_node("Button")
			flipped_cards.append(card_obj)
			break
	# Flip card. Disable so card theme works 
	flipped_card.disabled = true
	match flipped_card.team:
		"Black":
			flipped_card.set_theme(load("res://Sytle/BlackTheme.tres"))
		"Blu":
			flipped_card.set_theme(load("res://Sytle/BluTheme.tres"))
		"Red":
			flipped_card.set_theme(load("res://Sytle/RedTheme.tres"))
		"Yellow":
			flipped_card.set_theme(load("res://Sytle/YellowTheme.tres"))
	# Determine the outcome of the chosen card 
	# Card colors: Black, Red, Blu, Yellow
	# Team colors: BluSpy, RedSpy, BluTeam, RedTeam, Spectator
	match flipped_card.team:
		"Black":
			EndGame()
		"Red":
			if Network.players[caller["id"]].team == "RedTeam":
				red_points += 1
			else:
				blu_points += 1
				team_ctr += 1
				RoundStart()
		"Blu":
			if Network.players[caller["id"]].team == "BluTeam":
				blu_points += 1
			else:
				red_points += 1
				team_ctr += 1
				RoundStart()
		"Yellow":
			team_ctr += 1
			RoundStart()
	# Check if the game ended with that guess 
	if red_points == 9: rpc("EndGame")
	elif blu_points == 8: rpc("EndGame")

remotesync func EndGame():
	timer.stop()
	# Reveal all Words
	# Get All Grey themed cards(meaning they're unflipped) 
	# and put their color border around them 
	var words = get_tree().current_scene.find_node("GridContainer").get_children()
	for word in words:
		if word.find_node("Button").has_stylebox("GreyTheme", "Button"):
			word.find_node("Button").disabled = true
			match word.find_node("Button").team:
				"Black":
					word.self_modulate = Color(0.76, 0, 0.89, 1)
				"Yellow":
					word.self_modulate = Color(0.98, 1.01, 0.68, 0.9)
				"Red":
					word.self_modulate = Color(1, 0.24, 0.24, 1)
				"Blu":
					word.self_modulate = Color(0.31, 0.41, 1, 1)
	# Will need to reset vars at some point here and go back to pregame
	flipped_cards = []
	team_ctr = 0
	team_turn = "RedSpy"
	red_points = 0
	blu_points = 0

