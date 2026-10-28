class_name FoodItem
extends Area3D
## Represents a consumable food item in the terrarium that can be routed to a [Gecko].

signal reached_gecko(food: FoodItem)

const CURRENCY_VALUE: int = 1

@export var food_type: HabitatEnums.FoodType = HabitatEnums.FoodType.SUPERWORM

var _is_consumed: bool = false
var _has_reached_gecko: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Consumes and removes this food item from the scene tree.
func consume() -> void:
	if _is_consumed:
		return
	_is_consumed = true
	_has_reached_gecko = true
	queue_free()


## Returns true if this food item has already been consumed.
func is_consumed() -> bool:
	return _is_consumed


func _on_body_entered(body: Node3D) -> void:
	if _is_consumed or _has_reached_gecko:
		return
	if body is Gecko or body.get_parent() is Gecko:
		_has_reached_gecko = true
		reached_gecko.emit(self)
