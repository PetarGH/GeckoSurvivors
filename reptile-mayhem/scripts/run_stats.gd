extends Node
## Stores run statistics fed by gameplay signals.

enum Format {
	COUNT,
	DURATION,
}

var _order: Array[StringName] = []
var _entries: Dictionary = {}
var _hooks: Dictionary = {}


func _ready() -> void:
	define(&"good_food", "Good food eaten", Format.COUNT)
	define(&"bad_food", "Bad food eaten", Format.COUNT)
	define(&"bad_temp_time", "Time in bad temperature", Format.DURATION)
	define(&"bad_moisture_time", "Time in bad moisture", Format.DURATION)
	define(&"total_time", "Total time", Format.DURATION)


## Registers how a stat is labeled and formatted. Existing values are kept.
func define(id: StringName, label: String, format: Format) -> void:
	if not _entries.has(id):
		_order.append(id)
		_entries[id] = {
			"label": label,
			"format": format,
			"value": 0.0,
		}
		return

	_entries[id]["label"] = label
	_entries[id]["format"] = format


## Adds 1 each time [param source] is emitted. Extra signal arguments are ignored.
func hook_count(source: Signal, id: StringName) -> void:
	_ensure_entry(id, Format.COUNT)
	_connect_hook(source, id, func(
		_a: Variant = null,
		_b: Variant = null,
		_c: Variant = null,
		_d: Variant = null
	) -> void:
		_add(id, 1.0)
	)


## Adds the signal's first float each time [param source] is emitted.
func hook_amount(source: Signal, id: StringName) -> void:
	_ensure_entry(id, Format.DURATION)
	_connect_hook(source, id, func(amount: float) -> void:
		_add(id, amount)
	)


## Clears recorded values. Definitions and live signal hooks stay in place.
func reset() -> void:
	for id: StringName in _order:
		_entries[id]["value"] = 0.0

	_drop_dead_hooks()


## Returns registered stats in definition order.
func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for id: StringName in _order:
		var entry: Dictionary = _entries[id]
		var format: Format = entry["format"]
		var value: float = entry["value"]
		result.append({
			"id": id,
			"label": entry["label"],
			"format": format,
			"value": value,
			"text": format_value(format, value),
		})

	return result


## Formats a count as a whole number, or a duration as m:ss.
func format_value(format: Format, value: float) -> String:
	if format == Format.DURATION:
		return _format_duration(value)

	return str(roundi(value))


func _connect_hook(source: Signal, id: StringName, listener: Callable) -> void:
	var key := _hook_key(source, id)
	if _hooks.has(key):
		return

	source.connect(listener)
	_hooks[key] = {
		"source": source,
		"listener": listener,
	}


func _hook_key(source: Signal, id: StringName) -> String:
	return "%d:%s:%s" % [source.get_object_id(), source.get_name(), id]


func _drop_dead_hooks() -> void:
	var stale: Array[String] = []

	for key: String in _hooks:
		var record: Dictionary = _hooks[key]
		var source: Signal = record["source"]
		var listener: Callable = record["listener"]

		if not is_instance_valid(source.get_object()) or not source.is_connected(listener):
			stale.append(key)

	for key: String in stale:
		_hooks.erase(key)


func _add(id: StringName, amount: float) -> void:
	_ensure_entry(id, Format.COUNT)
	_entries[id]["value"] = float(_entries[id]["value"]) + amount


func _ensure_entry(id: StringName, format: Format) -> void:
	if _entries.has(id):
		return

	define(id, String(id), format)


func _format_duration(seconds: float) -> String:
	var total_seconds := maxi(floori(seconds), 0)
	var minutes := int(total_seconds / 60.0)
	var remainder := total_seconds % 60
	return "%d:%02d" % [minutes, remainder]
