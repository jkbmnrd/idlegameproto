extends Control

## Main game constants
### Constants for game balance
const PRESTIGE_EXPONENT := 0.4
const BASE_PRESTIGE_COST := 1000
const PRESTIGE_COST_MULTIPLIER := 2
const PRESTIGE_SCALING_FACTOR := 100

### Offline progression
const OFFLINE_DIVISOR := 10
const MIN_OFFLINE_TIME := 60  # Seconds

### UI timings
const NOTIFICATION_DISPLAY_TIME := 0.2
const OFFLINE_NOTIFICATION_DELAY := 3.0
const RESET_NOTIFICATION_DELAY := 1.0
const AUTO_SAVE_INTERVAL := 60.0

## Main game variables
### Counters
var cans: int = 0
var usd: float = 0

### Upgradable Variables
var cans_per_click: float = 1
var usd_per_can: float = 0.05  # Each can worth $0.05 USD

### Prestige Variables
var can_prestige_count: int = 0
var can_mult: float = 1
var can_prestige_cost: int = BASE_PRESTIGE_COST
var pending_can_mult: float = 0

### Progress Tracking
var current_upgrade_index: int = 0
var current_building_index: int = 0
var total_cans_per_click: float = 0

## Game data
@export var upgrades := [
	{"usd_cost": 0.50, "bonus": 1, "name": "Plastic Bag Collector"},
	{"usd_cost": 1.25, "bonus": 1, "name": "Magnet-on-a-Stick"},
	{"usd_cost": 2.50, "bonus": 2, "name": "Shopping Cart"},
	{"usd_cost": 5.00, "bonus": 2, "name": "Folding Wagon"},
	{"usd_cost": 10.00, "bonus": 3, "name": "Bicycle Trailer"}, # 5 before $20
	
	{"usd_cost": 20.00, "bonus": 3, "name": "Motorized Scooter"},
	{"usd_cost": 30.00, "bonus": 3, "name": "Beater Pickup Truck"},
	{"usd_cost": 40.00, "bonus": 3, "name": "Refurbished Golf Cart"},
	{"usd_cost": 60.00, "bonus": 4, "name": "Junk Hauling Van"},
	{"usd_cost": 80.00, "bonus": 4, "name": "Mobile Scrap Processor"}, # 10 before $100
	
	{"usd_cost": 110.00, "bonus": 5, "name": "Aluminum Sorting Robot"},
	{"usd_cost": 150.00, "bonus": 5, "name": "Can Crushing Machine"},
	{"usd_cost": 200.00, "bonus": 5, "name": "Recycling Conveyor Belt"},
	{"usd_cost": 275.00, "bonus": 5, "name": "Industrial Baler"},
	{"usd_cost": 375.00, "bonus": 5, "name": "Automated Sorting Facility"}, # 15 before $200
	
	{"usd_cost": 500.00, "bonus": 10, "name": "City-Wide Collection Route"},
	{"usd_cost": 700.00, "bonus": 20, "name": "AI-Powered Scout Drones"},
	{"usd_cost": 1000.00, "bonus": 50, "name": "Underground Recycling Network"},
	{"usd_cost": 1500.00, "bonus": 100, "name": "Municipal Contract"},
	{"usd_cost": 2500.00, "bonus": 250, "name": "Recycling Empire"} # 20 before $4000
]

@export var buildings := [
	{"can_cost": 50, "extra_usd": 0.005, "name": "Cardboard Stand"},
	{"can_cost": 100, "extra_usd": 0.010, "name": "Dumpster Diving Spot"},
	{"can_cost": 200, "extra_usd": 0.015, "name": "Alleyway Collection Point"},
	{"can_cost": 350, "extra_usd": 0.015, "name": "Park Recycling Bin"},
	{"can_cost": 600, "extra_usd": 0.025, "name": "Convenience Store Drop-off"}, # 5 before 1000
	
	{"can_cost": 900, "extra_usd": 0.025, "name": "Apartment Complex Route"},
	{"can_cost": 1300, "extra_usd": 0.03, "name": "Sports Stadium Cleanup"},
	{"can_cost": 1800, "extra_usd": 0.03, "name": "City Park Contract"},
	{"can_cost": 2400, "extra_usd": 0.04, "name": "University Recycling Program"},
	{"can_cost": 3200, "extra_usd": 0.05, "name": "Corporate Office Partnership"}, # 10 before 2000
	
	{"can_cost": 4200, "extra_usd": 0.085, "name": "Airport Recycling Hub"},
	{"can_cost": 5500, "extra_usd": 0.085, "name": "Metro Area Collection"},
	{"can_cost": 7000, "extra_usd": 0.08, "name": "Regional Processing Center"},
	{"can_cost": 9000, "extra_usd": 0.09, "name": "State-Wide Operation"},
	{"can_cost": 12000, "extra_usd": 0.1, "name": "National Recycling Chain"}, # 15 before 4000
	
	{"can_cost": 16000, "extra_usd": 0.4, "name": "Continental Collection"},
	{"can_cost": 22000, "extra_usd": 0.5, "name": "Global Aluminum Exchange"},
	{"can_cost": 30000, "extra_usd": 0.6, "name": "Orbital Scrap Platform"},
	{"can_cost": 40000, "extra_usd": 0.7, "name": "Lunar Recycling Base"},
	{"can_cost": 60000, "extra_usd": 0.8, "name": "Interstellar Scrap Empire"} # 20 before 8000
]

func _ready():
	if not _validate_nodes():
		return
	_setup_connections()
	_load_game()
	_start_auto_save()
	_update_ui()

func _validate_nodes() -> bool:
	var required_nodes := [
		"IncrementButton", "SellCansButton", "Upgrade1Button", 
		"Upgrade2Button", "Upgrade3Button", "Building1Button",
		"Building2Button", "Building3Button", "SaveButton",
		"PrestigeCansButton", "ResetButton", "ErrorNotification"
	]
	
	for node in required_nodes:
		if not has_node(node):
			push_error("Missing required node: %s" % node)
			return false
	return true

func _setup_connections():
	$IncrementButton.pressed.connect(_on_click)
	$SellCansButton.pressed.connect(_sell_cans)
	
	for i in range(1, 4):
		get_node("Upgrade%dButton" % i).pressed.connect(_try_buy_upgrade.bind(i))
		get_node("Building%dButton" % i).pressed.connect(_try_buy_building.bind(i))
	
	$SaveButton.pressed.connect(_save_game)
	$PrestigeCansButton.pressed.connect(_try_prestige_cans)
	$ResetButton.pressed.connect(_reset_save_data)


## Core Game Functions
func _on_click():
	cans += int(cans_per_click * can_mult)
	_animate_click()
	_update_ui()

func _animate_click():
	var tween = create_tween()
	tween.tween_property($IncrementButton, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property($IncrementButton, "scale", Vector2(1, 1), 0.05)

func _sell_cans():
	if cans <= 0:
		_show_error("No cans to recycle!")
		return
	
	usd += cans * usd_per_can
	cans = 0
	_update_ui()

## Upgrade System
func _try_buy_upgrade(button_num: int):
	var upgrade_index := current_upgrade_index + (button_num - 1)
	
	if upgrade_index >= upgrades.size():
		_show_error("No more upgrades available!")
		return
	
	var upgrade := _get_valid_upgrade(upgrade_index)
	if not upgrade:
		return
	
	if usd < upgrade.usd_cost:
		_show_error("Not enough USD!")
		return
	
	_purchase_upgrade(upgrade)

func _get_valid_upgrade(index: int) -> Dictionary:
	if index >= upgrades.size() or index < 0:
		return {}
	
	var upgrade = upgrades[index]
	if not upgrade.has_all(["usd_cost", "bonus", "name"]):
		push_error("Upgrade data incomplete at index %d" % index)
		return {}
	
	return upgrade

func _purchase_upgrade(upgrade: Dictionary):
	usd -= upgrade.usd_cost
	cans_per_click += upgrade.bonus
	current_upgrade_index += 1
	_show_purchase_notification()
	_update_ui()

## Building System
func _try_buy_building(button_num: int):
	var building_index := current_building_index + (button_num - 1)
	
	if building_index >= buildings.size():
		_show_error("No more buildings available!")
		return
	
	var building := _get_valid_building(building_index)
	if not building:
		return
	
	if cans < building.can_cost:
		_show_error("Not enough cans!")
		return
	
	_purchase_building(building)

func _get_valid_building(index: int) -> Dictionary:
	if index >= buildings.size() or index < 0:
		return {}
	
	var building = buildings[index]
	if not building.has_all(["can_cost", "extra_usd", "name"]):
		push_error("Building data incomplete at index %d" % index)
		return {}
	
	return building

func _purchase_building(building: Dictionary):
	cans -= building.can_cost
	usd_per_can += building.extra_usd
	current_building_index += 1
	_show_purchase_notification()
	_update_ui()

## Prestige System
func _try_prestige_cans():
	if cans <= 0:
		_show_error("You need cans to prestige!")
		return
	
	if cans < can_prestige_cost:
		_show_error("Need %d cans to prestige!" % can_prestige_cost)
		return
	
	var prestige_gain := (pow(cans, PRESTIGE_EXPONENT) * (PRESTIGE_SCALING_FACTOR / pow(BASE_PRESTIGE_COST, PRESTIGE_EXPONENT)))
	if is_nan(prestige_gain) or is_inf(prestige_gain):
		_show_error("Invalid prestige calculation!")
		return
	
	_reset_after_prestige(prestige_gain)
	_update_ui()

func _reset_after_prestige(gain: float):
	can_mult += gain
	cans = 0
	usd = 0
	cans_per_click = 1
	usd_per_can = 0.05  # Reset to base value
	current_upgrade_index = 0
	current_building_index = 0
	can_prestige_cost *= PRESTIGE_COST_MULTIPLIER
	can_prestige_count += 1

## UI System
func _update_ui():
	_calculate_derived_values()
	_update_counters()
	_update_shop_buttons()
	_update_prestige_ui()

func _calculate_derived_values():
	total_cans_per_click = cans_per_click * can_mult
	pending_can_mult = pow(cans, PRESTIGE_EXPONENT) * (PRESTIGE_SCALING_FACTOR / pow(BASE_PRESTIGE_COST, PRESTIGE_EXPONENT))

func _update_counters():
	$CansCountLabel.text = "Cans: %d\n(+%.0f per click)" % [cans, total_cans_per_click]
	$USDCountLabel.text = "USD: $%.2f\n($%.4f per can)" % [usd, usd_per_can]
	$HoboPointsLabel.text = "Hobo Clout: %.0f\n" % can_mult
	$HoboPointsLabel.visible = can_mult > 1.0

func _update_shop_buttons():
	for i in range(1, 4):
		_update_upgrade_button(i)
		_update_building_button(i)

func _update_upgrade_button(button_num: int):
	var button := get_node("Upgrade%dButton" % button_num)
	var upgrade_index := current_upgrade_index + (button_num - 1)
	
	if upgrade_index >= upgrades.size():
		button.visible = false
		return
	
	var upgrade = upgrades[upgrade_index]
	button.text = "%s\nCost: $%.2f (+%d cans/click)" % [
		upgrade.name,
		upgrade.usd_cost,
		upgrade.bonus
	]
	button.disabled = (usd < upgrade.usd_cost)
	button.visible = true

func _update_building_button(button_num: int):
	var button := get_node("Building%dButton" % button_num)
	var building_index := current_building_index + (button_num - 1)
	
	if building_index >= buildings.size():
		button.visible = false
		return
	
	var building = buildings[building_index]
	button.text = "%s\nCost: %d cans (+$%.3f/can)" % [
		building.name,
		building.can_cost,
		building.extra_usd
	]
	button.disabled = (cans < building.can_cost)
	button.visible = true

func _update_prestige_ui():
	$PrestigeCansButton.text = "Go Hobo Royalty\nGain +%.1f Clout" % pending_can_mult
	$PrestigeCansButton.visible = cans >= can_prestige_cost

func _show_purchase_notification():
	$PurchasedNotification.show()
	await get_tree().create_timer(NOTIFICATION_DISPLAY_TIME).timeout
	$PurchasedNotification.hide()

func _show_error(message: String, duration: float = 3.0):
	$ErrorNotification.text = message
	$ErrorNotification.show()
	await get_tree().create_timer(duration).timeout
	$ErrorNotification.hide()

## Save/Load System
func _save_game():
	var save_path := "user://savegame.dat"
	var save_data := {
		"cans": cans,
		"usd": usd,
		"cans_per_click": cans_per_click,
		"usd_per_can": usd_per_can,
		"can_prestige_count": can_prestige_count,
		"can_mult": can_mult,
		"can_prestige_cost": can_prestige_cost,
		"current_upgrade_index": current_upgrade_index,
		"current_building_index": current_building_index,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		_show_error("Save failed! Error: %s" % error_string(FileAccess.get_open_error()))
		return
	
	file.store_var(save_data)
	if file.get_error() != OK:
		_show_error("Failed to write save data!")
	file.close()
	
	$SaveNotification.show()
	await get_tree().create_timer(NOTIFICATION_DISPLAY_TIME).timeout
	$SaveNotification.hide()

func _load_game():
	var save_path := "user://savegame.dat"
	if not FileAccess.file_exists(save_path):
		return
	
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		_show_error("Load failed! Error: %s" % error_string(FileAccess.get_open_error()))
		return
	
	var save_data = file.get_var()
	file.close()
	
	if not save_data is Dictionary:
		_show_error("Corrupted save data!")
		return
	
	_apply_loaded_data(save_data)
	_calculate_offline_progress(save_data.get("timestamp", Time.get_unix_time_from_system()))
	_update_ui()

func _apply_loaded_data(data: Dictionary):
	cans = data.get("cans", 0)
	usd = data.get("usd", 0)
	cans_per_click = data.get("cans_per_click", 1)
	usd_per_can = data.get("usd_per_can", 1)
	can_prestige_count = data.get("can_prestige_count", 0)
	can_mult = data.get("can_mult", 1)
	can_prestige_cost = data.get("can_prestige_cost", BASE_PRESTIGE_COST)
	current_upgrade_index = data.get("current_upgrade_index", 0)
	current_building_index = data.get("current_building_index", 0)

func _calculate_offline_progress(last_saved: int):
	var time_elapsed := Time.get_unix_time_from_system() - last_saved
	if time_elapsed <= MIN_OFFLINE_TIME:
		return
	
	var offline_cans := (time_elapsed * can_mult) / OFFLINE_DIVISOR
	cans += offline_cans
	
	$OfflineNotification.text = "You earned %d cans while offline!" % offline_cans
	$OfflineNotification.show()
	await get_tree().create_timer(OFFLINE_NOTIFICATION_DELAY).timeout
	$OfflineNotification.hide()

func _reset_save_data():
	# Reset all variables
	cans = 0
	usd = 0
	cans_per_click = 1
	usd_per_can = 0.05
	can_prestige_count = 0
	can_mult = 1
	can_prestige_cost = BASE_PRESTIGE_COST
	current_upgrade_index = 0
	current_building_index = 0
	
	# Delete save file
	var save_path := "user://savegame.dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	
	# Update UI
	_update_ui()
	$ResetNotification.show()
	await get_tree().create_timer(RESET_NOTIFICATION_DELAY).timeout
	$ResetNotification.hide()

func _start_auto_save():
	while true:
		await get_tree().create_timer(AUTO_SAVE_INTERVAL).timeout
		_save_game()
