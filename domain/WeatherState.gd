class_name WeatherState
extends RefCounted

enum Condition { SUNNY, CLOUDY, RAINY, STORM }

var condition: Condition
var is_day: bool
var sunrise_unix: int
var sunset_unix: int

func _init(cond: Condition, sunrise: int, sunset: int) -> void:
	condition = cond
	sunrise_unix = sunrise
	sunset_unix = sunset
	var now := int(Time.get_unix_time_from_system())
	is_day = now >= sunrise_unix and now < sunset_unix

static func make_default() -> WeatherState:
	# ±12 h window ensures is_day = true regardless of launch time — intentional safe fallback
	var base := int(Time.get_unix_time_from_system())
	var fake_sunrise := base - 43200
	var fake_sunset  := base + 43200
	return WeatherState.new(Condition.SUNNY, fake_sunrise, fake_sunset)

func equals(other: WeatherState) -> bool:
	if other == null:
		return false
	# Timestamps intentionally excluded — only condition + day/night toggle drives visual change
	return condition == other.condition and is_day == other.is_day
