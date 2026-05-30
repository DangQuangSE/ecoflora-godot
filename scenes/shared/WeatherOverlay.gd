class_name WeatherOverlay
extends CanvasLayer

@onready var _rain: CPUParticles2D = $RainParticles
@onready var _wind: CPUParticles2D = $WindParticles
@onready var _day_night: ColorRect = $DayNightOverlay

const TRANSITION_SEC := 0.6

var _tween: Tween = null

func _ready() -> void:
	# Emit rain across full screen width from above, wind from left side
	_rain.position = Vector2(360, -30)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(400, 1)
	_wind.position = Vector2(-50, 460)
	_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wind.emission_rect_extents = Vector2(1, 500)

func apply_state(state: WeatherState) -> void:
	if state == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)

	match state.condition:
		WeatherState.Condition.SUNNY:
			_set_particles(false, false, 150, 100)
			_tween_overlay(Color(0, 0, 0, 0.0 if state.is_day else 0.5))

		WeatherState.Condition.CLOUDY:
			_set_particles(false, false, 150, 100)
			var base_alpha := 0.35 if state.is_day else 0.6
			_tween_overlay(Color(0.2, 0.22, 0.28, base_alpha))

		WeatherState.Condition.RAINY:
			_set_particles(true, false, 150, 100,
				Vector2(0.0, 1.0), 5.0)
			var night_extra := 0.0 if state.is_day else 0.3
			_tween_overlay(Color(0.0, 0.05, 0.1, 0.1 + night_extra))

		WeatherState.Condition.STORM:
			_set_particles(true, true, 300, 100,
				Vector2(sin(deg_to_rad(25.0)), cos(deg_to_rad(25.0))), 15.0)
			var night_extra := 0.0 if state.is_day else 0.3
			_tween_overlay(Color(0.0, 0.0, 0.05, 0.2 + night_extra))

		_:
			push_warning("WeatherOverlay.apply_state: unhandled condition %d" % state.condition)

func _set_particles(rain_on: bool, wind_on: bool, rain_amt: int, wind_amt: int,
		rain_dir: Vector2 = Vector2(0, 1), rain_spread: float = 5.0) -> void:
	if rain_on:
		_rain.direction = rain_dir
		_rain.spread = rain_spread
		_rain.amount = mini(rain_amt, 300)
	if wind_on:
		_wind.amount = mini(wind_amt, 150)
	_rain.emitting = rain_on
	_wind.emitting = wind_on

func _tween_overlay(target_color: Color) -> void:
	_tween.tween_property(_day_night, "color", target_color, TRANSITION_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
