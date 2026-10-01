extends Control

## Simple crosshair drawn at the screen center: four short lines and an optional dot.
## Bullets aim through the exact screen center, so this always marks where shots land.

@export_group("Shape")
## Length of each of the four lines, in pixels.
@export var line_length: float = 7.0
## Empty space between the center and each line, in pixels.
@export var gap: float = 5.0
@export var thickness: float = 2.0
@export var show_center_dot: bool = true
@export var center_dot_radius: float = 1.5

@export_group("Colors")
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)
## Dark outline so the crosshair stays readable on bright surfaces.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.55)
@export var outline_width: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = (size * 0.5).floor()
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]

	if outline_width > 0.0:
		for direction in directions:
			_draw_line_segment(center, direction, thickness + (outline_width * 2.0), outline_width, outline_color)
		if show_center_dot:
			draw_circle(center, center_dot_radius + outline_width, outline_color)

	for direction in directions:
		_draw_line_segment(center, direction, thickness, 0.0, color)
	if show_center_dot:
		draw_circle(center, center_dot_radius, color)


func _draw_line_segment(center: Vector2, direction: Vector2, width: float, extend: float, draw_color: Color) -> void:
	var start: Vector2 = center + (direction * (gap - extend))
	var end: Vector2 = center + (direction * (gap + line_length + extend))
	draw_line(start, end, draw_color, width)
