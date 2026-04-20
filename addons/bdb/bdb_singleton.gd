extends Node

const FILE_EXTENSION := ".bdb"
const USER_ROOT := "user://"
const BUNDLE_ROOT := "res://bdb"
const FORMAT_VERSION := 2
const META_FLAG := "__bdb__"


func CREATE(file_name: String, defaults: Dictionary = {}, create_bundle_copy: bool = false) -> Dictionary:
	var normalized_name := _normalize_file_name(file_name)
	var user_path := _get_user_path(normalized_name)
	var bundle_path := _get_bundle_path(normalized_name)
	var default_values := defaults.duplicate(true)
	var seed_payload := _build_payload(default_values, default_values.keys())
	var bundle_payload := _read_payload(bundle_path)

	if create_bundle_copy:
		if Engine.is_editor_hint():
			if bundle_payload.is_empty():
				_write_payload(bundle_path, seed_payload)
				bundle_payload = seed_payload
		elif bundle_payload.is_empty():
			push_warning("BDB: The bundled copy can only be created from the editor.")

	if not FileAccess.file_exists(user_path):
		if not bundle_payload.is_empty():
			seed_payload = bundle_payload
		_write_payload(user_path, seed_payload)

	return LOAD(normalized_name, null, default_values)


func SAVE(file_name: String, data_or_context: Variant, fields_or_order: Array = [], order: Array = []) -> Dictionary:
	var normalized_name := _normalize_file_name(file_name)
	var incoming_values := _extract_save_values(data_or_context, fields_or_order)
	var explicit_order := order.duplicate()

	if data_or_context is Dictionary and explicit_order.is_empty():
		explicit_order = fields_or_order.duplicate()

	var payload := _read_user_payload(normalized_name)
	if payload.is_empty():
		payload = _read_bundle_payload(normalized_name)

	var values := {}
	var stored_order: Array = []
	var created_at := _now_unix()

	if not payload.is_empty():
		values = payload.get("values", {}).duplicate(true)
		stored_order = payload.get("order", []).duplicate()
		created_at = int(payload.get("created_at", created_at))

	for key in incoming_values.keys():
		values[key] = incoming_values[key]
		if not stored_order.has(key):
			stored_order.append(key)

	if not explicit_order.is_empty():
		stored_order = _apply_explicit_order(explicit_order, values, stored_order)
	else:
		stored_order = _append_missing_keys(stored_order, values)

	var new_payload := _build_payload(values, stored_order, created_at)
	_write_payload(_get_user_path(normalized_name), new_payload)
	return values.duplicate(true)


func LOAD(file_name: String, request_or_target: Variant = null, defaults: Dictionary = {}) -> Variant:
	if request_or_target is Dictionary and defaults.is_empty():
		defaults = request_or_target.duplicate(true)
		request_or_target = null

	var normalized_name := _normalize_file_name(file_name)
	var payload := _read_user_payload(normalized_name)
	if payload.is_empty():
		payload = _read_bundle_payload(normalized_name)

	var values := {}
	var stored_order: Array = []

	if not payload.is_empty():
		values = payload.get("values", {}).duplicate(true)
		stored_order = payload.get("order", []).duplicate()

	for key in defaults.keys():
		if not values.has(key):
			values[key] = defaults[key]

	stored_order = _append_missing_keys(stored_order, values)

	if request_or_target == null:
		return values

	if request_or_target is String:
		return values.get(request_or_target, defaults.get(request_or_target, null))

	if request_or_target is Array:
		var requested: Array = request_or_target.duplicate()
		if requested.is_empty():
			requested = stored_order
		return _extract_requested_values(values, requested)

	if request_or_target is Object:
		_assign_values_to_object(request_or_target, values)
		return values

	push_warning("BDB: LOAD only accepts null, String, Array or Object as the second argument.")
	return values


func DELETE(file_name: String, target: Variant = null) -> bool:
	var normalized_name := _normalize_file_name(file_name)
	var user_path := _get_user_path(normalized_name)

	if target == null:
		if not FileAccess.file_exists(user_path):
			return false
		return _remove_file(user_path)

	if not FileAccess.file_exists(user_path):
		return false

	var payload := _read_user_payload(normalized_name)
	if payload.is_empty():
		return false

	var values := payload.get("values", {}).duplicate(true)
	var stored_order := payload.get("order", []).duplicate()
	var keys := _normalize_delete_targets(target)
	var changed := false

	for key in keys:
		if values.has(key):
			values.erase(key)
			stored_order.erase(key)
			changed = true

	if not changed:
		return false

	if values.is_empty():
		return _remove_file(user_path)

	var new_payload := _build_payload(values, stored_order, int(payload.get("created_at", _now_unix())))
	_write_payload(user_path, new_payload)
	return true


func save_(context: Object, file_name: String, variable_names: Array):
	return SAVE(file_name, context, variable_names)


func load_(context: Object, file_name: String, defaults: Dictionary = {}):
	return LOAD(file_name, context, defaults)


func _extract_save_values(data_or_context: Variant, fields: Array) -> Dictionary:
	if data_or_context is Dictionary:
		return data_or_context.duplicate(true)

	if data_or_context is Object:
		var values := {}
		if fields.is_empty():
			push_warning("BDB: SAVE with an Object requires the list of variable names.")
			return values

		for field in fields:
			var field_name := str(field)
			if _object_has_property(data_or_context, field_name):
				values[field_name] = data_or_context.get(field_name)
			else:
				push_warning("BDB: '%s' does not exist in the provided object and was skipped." % field_name)

		return values

	push_warning("BDB: SAVE only accepts a Dictionary or an Object.")
	return {}


func _extract_requested_values(values: Dictionary, requested: Array) -> Array:
	var result: Array = []

	for field in requested:
		result.append(values.get(str(field), null))

	return result


func _assign_values_to_object(target: Object, values: Dictionary) -> void:
	for key in values.keys():
		if _object_has_property(target, key):
			target.set(key, values[key])


func _object_has_property(target: Object, property_name: String) -> bool:
	for property_data in target.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			return true

	var script := target.get_script()
	if script != null and script.has_method("get_script_property_list"):
		for property_data in script.get_script_property_list():
			if str(property_data.get("name", "")) == property_name:
				return true

	return false


func _normalize_delete_targets(target: Variant) -> Array:
	if target is String:
		return [target]

	if target is Array:
		var keys: Array = []
		for item in target:
			keys.append(str(item))
		return keys

	push_warning("BDB: DELETE expects null, String or Array.")
	return []


func _apply_explicit_order(explicit_order: Array, values: Dictionary, fallback_order: Array) -> Array:
	var final_order: Array = []

	for item in explicit_order:
		var key := str(item)
		if key.is_empty() or final_order.has(key):
			continue

		final_order.append(key)
		if not values.has(key):
			values[key] = null

	for item in fallback_order:
		var key := str(item)
		if not final_order.has(key) and values.has(key):
			final_order.append(key)

	for key in values.keys():
		if not final_order.has(key):
			final_order.append(key)

	return final_order


func _append_missing_keys(order: Array, values: Dictionary) -> Array:
	var final_order: Array = []

	for item in order:
		var key := str(item)
		if key.is_empty() or final_order.has(key):
			continue
		if values.has(key):
			final_order.append(key)

	for key in values.keys():
		if not final_order.has(key):
			final_order.append(key)

	return final_order


func _build_payload(values: Dictionary, order: Array, created_at: int = -1) -> Dictionary:
	var now := _now_unix()
	var safe_values := values.duplicate(true)
	var safe_order := _append_missing_keys(order, safe_values)

	return {
		META_FLAG: true,
		"version": FORMAT_VERSION,
		"created_at": created_at if created_at >= 0 else now,
		"updated_at": now,
		"values": safe_values,
		"order": safe_order
	}


func _read_user_payload(file_name: String) -> Dictionary:
	return _read_payload(_get_user_path(file_name))


func _read_bundle_payload(file_name: String) -> Dictionary:
	return _read_payload(_get_bundle_path(file_name))


func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("BDB: Could not open '%s'." % path)
		return {}

	var raw := file.get_buffer(file.get_length())
	file.close()

	if raw.is_empty():
		return {}

	var decoded := bytes_to_var(raw)
	if decoded is Dictionary:
		return _sanitize_payload(decoded)

	return _parse_legacy_text(raw.get_string_from_utf8())


func _sanitize_payload(payload: Dictionary) -> Dictionary:
	var values := {}
	var raw_order: Variant = []

	if payload.get(META_FLAG, false):
		var raw_values = payload.get("values", {})
		if raw_values is Dictionary:
			values = raw_values.duplicate(true)
	else:
		values = payload.duplicate(true)

	raw_order = payload.get("order", [])
	var order: Array = raw_order.duplicate() if raw_order is Array else []
	return {
		META_FLAG: true,
		"version": int(payload.get("version", FORMAT_VERSION)),
		"created_at": int(payload.get("created_at", _now_unix())),
		"updated_at": int(payload.get("updated_at", _now_unix())),
		"values": values,
		"order": _append_missing_keys(order, values)
	}


func _parse_legacy_text(content: String) -> Dictionary:
	var values := {}
	var order: Array = []

	for record in content.split(";", false):
		var cleaned_record := record.strip_edges()
		if cleaned_record.is_empty():
			continue

		var first_comma := cleaned_record.find(",")
		if first_comma == -1:
			continue

		var variable_name := cleaned_record.substr(0, first_comma).strip_edges()
		var serialized_value := cleaned_record.substr(first_comma + 1)
		var last_comma := serialized_value.rfind(",")

		if last_comma != -1:
			var possible_type := serialized_value.substr(last_comma + 1).strip_edges()
			if possible_type.is_valid_int():
				serialized_value = serialized_value.substr(0, last_comma)

		values[variable_name] = str_to_var(serialized_value.strip_edges())
		order.append(variable_name)

	return _build_payload(values, order)


func _write_payload(path: String, payload: Dictionary) -> bool:
	_ensure_directory_for_file(path)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("BDB Error: Could not write '%s'." % path)
		return false

	file.store_buffer(var_to_bytes(payload))
	file.close()
	return true


func _remove_file(path: String) -> bool:
	var absolute_path := ProjectSettings.globalize_path(path)
	return DirAccess.remove_absolute(absolute_path) == OK


func _ensure_directory_for_file(path: String) -> void:
	var base_dir := path.get_base_dir()
	if base_dir.is_empty():
		return

	var absolute_dir := ProjectSettings.globalize_path(base_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)


func _normalize_file_name(file_name: String) -> String:
	var cleaned := file_name.strip_edges().replace("\\", "/")

	cleaned = _strip_prefix(cleaned, USER_ROOT)
	cleaned = _strip_prefix(cleaned, "res://")
	cleaned = _strip_prefix(cleaned, "bdb/")

	while cleaned.begins_with("/"):
		cleaned = cleaned.substr(1)

	if cleaned.is_empty():
		push_warning("BDB: Empty file name received. Using 'database.bdb'.")
		cleaned = "database"

	if not cleaned.ends_with(FILE_EXTENSION):
		cleaned += FILE_EXTENSION

	return cleaned


func _strip_prefix(value: String, prefix: String) -> String:
	if value.begins_with(prefix):
		return value.substr(prefix.length())
	return value


func _get_user_path(file_name: String) -> String:
	return USER_ROOT + file_name


func _get_bundle_path(file_name: String) -> String:
	return BUNDLE_ROOT + "/" + file_name


func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
