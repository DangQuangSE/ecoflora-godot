class_name WeatherOverlay
extends CanvasLayer

@onready var _rain: CPUParticles2D = $RainParticles
@onready var _wind: CPUParticles2D = $WindParticles
@onready var _day_night: ColorRect = $DayNightOverlay

const TRANSITION_SEC := 0.6

var _tween: Tween = null

func _ready() -> void:
	pass  # WeatherManager pushes initial state via apply_state() immediately after add_child()

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
			var base_alpha := 0.15 if state.is_day else 0.5
			_tween_overlay(Color(0.15, 0.15, 0.15, base_alpha))

		WeatherState.Condition.RAINY:
			_set_particles(true, false, 150, 100,
				Vector3(0.0, 1.0, 0.0), 5.0)
			var night_extra := 0.0 if state.is_day else 0.3
			_tween_overlay(Color(0.0, 0.05, 0.1, 0.1 + night_extra))

		WeatherState.Condition.STORM:
			_set_particles(true, true, 300, 100,
				Vector3(sin(deg_to_rad(25.0)), cos(deg_to_rad(25.0)), 0.0), 15.0)
			var night_extra := 0.0 if state.is_day else 0.3
			_tween_overlay(Color(0.0, 0.0, 0.05, 0.2 + night_extra))

		_:
			push_warning("WeatherOverlay.apply_state: unhandled condition %d" % state.condition)

func _set_particles(rain_on: bool, wind_on: bool, rain_amt: int, wind_amt: int,
		rain_dir: Vector3 = Vector3(0, 1, 0), rain_spread: float = 5.0) -> void:
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
