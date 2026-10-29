class_name FoodItem
extends Area3D
## Represents a consumable food item in the terrarium that can be routed to a [Gecko].

signal reached_gecko(food: FoodItem)

const CURRENCY_VALUE: int = 1

@export var food_type: HabitatEnums.FoodType = HabitatEnums.FoodType.SUPERWORM

var _is_consumed: bool = false
var _has_reached_gecko: bool = false


func _ready() -> void:
	return


## Consumes and removes this food item from the scene tree.
func consume() -> void:
	if _is_consumed:
		return
	_is_consumed = true
	_has_reached_gecko = true
	get_parent().queue_free()


## Returns true if this food item has already been consumed.
func is_consumed() -> bool:
	return _is_consumed


func notify_reached_gecko() -> void:
	if _is_consumed or _has_reached_gecko:
		return

	_has_reached_gecko = true
	reached_gecko.emit(self)
