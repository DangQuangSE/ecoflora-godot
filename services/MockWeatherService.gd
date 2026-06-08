class_name MockWeatherService
extends RefCounted

var mock_condition: WeatherState.Condition = WeatherState.Condition.SUNNY
var mock_is_day: bool = true

func get_state() -> WeatherState:
	var now := int(Time.get_unix_time_from_system())
	var sunrise: int
	var sunset: int
	if mock_is_day:
		sunrise = now - 43200
		sunset = now + 43200
	else:
		sunrise = now + 43200
		sunset = now + 86400
	return WeatherState.new(mock_condition, sunrise, sunset)
