class_name FoodItem
extends Area3D
## Represents a consumable food item in the terrarium that can be routed to a [Gecko].

signal reached_gecko(food: FoodItem)

const CURRENCY_VALUE: int = 1

@export var food_type: HabitatEnums.FoodType = HabitatEnums.FoodType.BUG


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


## Consumes and removes this food item from the scene tree.
func consume() -> void:
	queue_free()


func _on_area_entered(area: Area3D) -> void:
	if area is Gecko or area.get_parent() is Gecko:
		reached_gecko.emit(self)


func _on_body_entered(body: Node3D) -> void:
	if body is Gecko or body.get_parent() is Gecko:
		reached_gecko.emit(self)
