extends CanvasLayer
## Шкала силы удара и надпись «ГОЛ!».

@export var goal_show_time := 2.0

var _goal_tween: Tween
var _bar_tween: Tween

@onready var _power_bar: ProgressBar = %PowerBar
@onready var _goal_label: Label = %GoalLabel
@onready var _fill: StyleBoxFlat = _power_bar.get_theme_stylebox("fill").duplicate()


func _ready() -> void:
	_power_bar.add_theme_stylebox_override("fill", _fill)
	_power_bar.modulate.a = 0.0
	_goal_label.visible = false


func set_charge(power: float, charging: bool) -> void:
	_power_bar.value = power
	_fill.bg_color = Color(0.35, 0.85, 0.3).lerp(Color(1.0, 0.85, 0.2), minf(power * 2.0, 1.0)) \
			.lerp(Color(0.95, 0.25, 0.15), maxf(power * 2.0 - 1.0, 0.0))
	if _bar_tween:
		_bar_tween.kill()
	if charging:
		_power_bar.modulate.a = 1.0
	else:
		_bar_tween = create_tween()
		_bar_tween.tween_interval(0.3)
		_bar_tween.tween_property(_power_bar, "modulate:a", 0.0, 0.3)


func show_goal() -> void:
	if _goal_tween:
		_goal_tween.kill()
	_goal_label.visible = true
	_goal_label.pivot_offset = _goal_label.size * 0.5
	_goal_label.scale = Vector2(0.3, 0.3)
	_goal_label.modulate.a = 1.0
	_goal_tween = create_tween()
	_goal_tween.tween_property(_goal_label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_goal_tween.tween_interval(goal_show_time)
	_goal_tween.tween_property(_goal_label, "modulate:a", 0.0, 0.4)
	_goal_tween.tween_callback(_goal_label.hide)
