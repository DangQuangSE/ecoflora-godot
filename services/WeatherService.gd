class_name WeatherService
extends RefCounted

var endpoint: String = ""  # set via WeatherManager._ready()

func parse_response(envelope: Dictionary) -> WeatherState:
	var data: Variant = HttpHelper.unwrap_envelope(envelope)
	if data == null or not data is Dictionary:
		push_warning("WeatherService.parse_response: envelope unwrap failed")
		return null
	return _parse_weather_data(data)

func _parse_weather_data(json: Dictionary) -> WeatherState:
	if not json.has("condition") or not json.has("sunrise") or not json.has("sunset"):
		push_warning("WeatherService.parse_response: missing required fields in response")
		return null
	var condition_map := {
		"sunny":  WeatherState.Condition.SUNNY,
		"cloudy": WeatherState.Condition.CLOUDY,
		"rainy":  WeatherState.Condition.RAINY,
		"storm":  WeatherState.Condition.STORM,
	}
	var cond_str: String = str(json["condition"]).to_lower()
	if not condition_map.has(cond_str):
		push_warning("WeatherService.parse_response: unknown condition '%s'" % cond_str)
		return null
	if not (json["sunrise"] is int or json["sunrise"] is float):
		push_warning("WeatherService.parse_response: 'sunrise' is not a number")
		return null
	if not (json["sunset"] is int or json["sunset"] is float):
		push_warning("WeatherService.parse_response: 'sunset' is not a number")
		return null
	var sunrise: int = int(json["sunrise"])
	var sunset:  int = int(json["sunset"])
	if sunrise >= sunset:
		push_warning("WeatherService.parse_response: sunrise >= sunset (%d >= %d)" % [sunrise, sunset])
		return null
	return WeatherState.new(condition_map[cond_str], sunrise, sunset)
