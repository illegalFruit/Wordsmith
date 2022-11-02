extends Node

var players = {}
var upnp = UPNP.new() 
var external_ip = ""

func _ready():
	get_tree().connect("network_peer_connected", self, "player_connected")
	get_tree().connect("network_peer_disconnected", self, "player_disconnected")
	upnp.discover(2000, 2, "InternetGatewayDevice")
	external_ip = upnp.query_external_address()

func create_host():
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(12335, 12335, "GodotGame", "TCP")
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(12335, 14)
	get_tree().network_peer = peer
	players.clear()
	register_player({"id":get_tree().get_network_unique_id(), 
						"name":generate_username(),
						"team":"Spectator"})

func create_client():
	var encoded_ip = get_tree().current_scene.find_node("IPInput").text
	var decoded_ip = Marshalls.base64_to_utf8(encoded_ip)
	print("Attempting to connect to: ", decoded_ip)
	var peer = NetworkedMultiplayerENet.new()
	var err = peer.create_client(decoded_ip, 12335)
	get_tree().network_peer = peer
	players.clear()
	register_player({"id":get_tree().get_network_unique_id(), 
					"name":generate_username(),
					"team":"Spectator"})

func player_connected(id):
	rpc_id(id, "register_player", {"id":get_tree().get_network_unique_id(),
									"name":players[get_tree().get_network_unique_id()].name,
									"team":players[get_tree().get_network_unique_id()].team})
	Game.RedrawTeams()

func player_disconnected(id):
	if get_tree().current_scene.filename == "res://Scene/PreGame.tscn":
		players.erase(id)
		Game.RedrawTeams()

func generate_username():
	var name_bank = ["Abra", "Bagon", "Carnivine", "Darkrai", "Eevee", "Flareon",
					"Gardevoir", "Hattrem", "Ivysaur", "Jirachi", "Kabuto", "Lairon",
					"Machamp", "Natu", "Oddish", "Palkia", "Quagsire", "Raichu",
					"Salazzle", "Tangela", "Umbreon", "Victreebel", "Wailord", "Yanma", "Zapdos"]
	randomize()
	return name_bank[randi() % name_bank.size()] 

class player:
	var name : String
	var team : String
remote func register_player(peer_info):
	var peer = player.new()
	peer.name = peer_info["name"]
	peer.team = peer_info["team"]
	players[peer_info["id"]] = peer
	# Upon everyone having an updated players, call redraw on current teams
	# We dont call this if this is the first call on adding the self to players
	if peer_info["id"] != get_tree().get_network_unique_id():
		Game.RedrawTeams()

