class_name MockWeatherService
extends RefCounted

var mock_condition: WeatherState.Condition = WeatherState.Condition.SUNNY
var mock_sunrise_hour: int = 6   # 06:00 LOCAL time
var mock_sunset_hour: int = 18   # 18:00 LOCAL time

func get_state() -> WeatherState:
	var now := int(Time.get_unix_time_from_system())
	# bias is minutes WEST of UTC (west-positive convention) — negate to get east-positive offset
	var tz_offset_sec: int = -Time.get_time_zone_from_system().bias * 60
	var today_local_midnight_utc: int = ((now + tz_offset_sec) / 86400) * 86400 - tz_offset_sec
	var sunrise := today_local_midnight_utc + mock_sunrise_hour * 3600
	var sunset  := today_local_midnight_utc + mock_sunset_hour  * 3600
	return WeatherState.new(mock_condition, sunrise, sunset)
