extends CanvasLayer

signal debris_changed(percent: float)

## Pixel size of one debris piece on screen (matches _spawn_glitch_block scaling).
@export var block_size: int = 80
## Grid cell size in pixels for coverage tracking (smaller = more accurate, slightly more work).
@export var tracker_cell_size: int = 16
@export var glitch_anim_texture_path: String = "res://scenes/effects/glitch_animation.png"
@export var glitch_pick_count: int = 5
@export var glitch_crop_padding_px: int = 2
@export var glitch_brightness_threshold: float = 0.08
@export var glitch_downsample: int = 4

@export var glitch_sheet_paths: Array[String] = [
	"res://scenes/effects/glitch_frames/horizontal_glitch_sheet.png",
	"res://scenes/effects/glitch_frames/vertical_tear_sheet.png",
	"res://scenes/effects/glitch_frames/vortex_circular_sheet.png",
	"res://scenes/effects/glitch_frames/diagonal_slash_sheet.png",
	"res://scenes/effects/glitch_frames/checkerboard_corruption_sheet.png",
]
@export var glitch_anim_frames_count: int = 4
@export var glitch_anim_fps: float = 6.0

@export var clear_anim_duration: float = 0.25

var debris_percent: float = 0.0
var _glitch_anim_texture: Texture2D = null
var _glitch_choices: Array[Texture2D] = []
var _sprite_frames_choices: Array[SpriteFrames] = []

var _grid_cols: int = 0
var _grid_rows: int = 0
var _grid: PackedByteArray = PackedByteArray()
var _filled_cells: int = 0

@onready var debris_root: Node2D = $DebrisRoot

func _rect_area_desc(a: Rect2i, b: Rect2i) -> bool:
	return (a.size.x * a.size.y) > (b.size.x * b.size.y)

func _append_neighbors4(q: Array[Vector2i], p: Vector2i, mw: int, mh: int) -> void:
	var x: int = p.x
	var y: int = p.y
	if x > 0:
		q.append(Vector2i(x - 1, y))
	if x < mw - 1:
		q.append(Vector2i(x + 1, y))
	if y > 0:
		q.append(Vector2i(x, y - 1))
	if y < mh - 1:
		q.append(Vector2i(x, y + 1))

func _ready() -> void:
	add_to_group("debris_overlay")
	_init_coverage_tracker()
	# Try animated sprite sheets first, fall back to static BFS extraction.
	_sprite_frames_choices = _build_sprite_frames()
	if _sprite_frames_choices.is_empty():
		var tex := load(glitch_anim_texture_path)
		if tex is Texture2D:
			_glitch_anim_texture = tex
			_glitch_choices = _build_glitch_choices(tex)


func setup_map_size(_size: Vector2) -> void:
	# Debris covers the screen, not the map — use viewport size
	_init_coverage_tracker()

func _init_coverage_tracker() -> void:
	var sz: Vector2 = get_viewport().get_visible_rect().size
	if sz.x <= 1.0 or sz.y <= 1.0:
		sz = Vector2(1280.0, 720.0)
	var cs: int = maxi(tracker_cell_size, 1)
	_grid_cols = maxi(1, ceili(sz.x / float(cs)))
	_grid_rows = maxi(1, ceili(sz.y / float(cs)))
	_grid.resize(_grid_cols * _grid_rows)
	_grid.fill(0)
	_filled_cells = 0
	debris_percent = 0.0


func _mark_debris_coverage(center: Vector2) -> void:
	if _grid_cols < 1 or _grid_rows < 1:
		_init_coverage_tracker()
	var half := float(block_size) * 0.5
	var r := Rect2(center.x - half, center.y - half, float(block_size), float(block_size))
	var cs := float(maxi(tracker_cell_size, 1))
	var x0: int = clampi(int(floor(r.position.x / cs)), 0, _grid_cols - 1)
	var y0: int = clampi(int(floor(r.position.y / cs)), 0, _grid_rows - 1)
	var x1: int = clampi(int(floor((r.position.x + r.size.x - 0.001) / cs)), 0, _grid_cols - 1)
	var y1: int = clampi(int(floor((r.position.y + r.size.y - 0.001) / cs)), 0, _grid_rows - 1)
	for gy in range(y0, y1 + 1):
		var row_off: int = gy * _grid_cols
		for gx in range(x0, x1 + 1):
			var idx: int = row_off + gx
			if _grid[idx] == 0:
				_grid[idx] = 1
				_filled_cells += 1
	var total_cells: int = _grid_cols * _grid_rows
	debris_percent = (100.0 * float(_filled_cells) / float(total_cells)) if total_cells > 0 else 0.0

func get_debris_percent() -> float:
	return debris_percent

func add_debris(world_pos: Vector2, _enemy_type: String) -> void:
	# Convert world position to screen position (CanvasLayer uses screen coords)
	var screen_pos := _world_to_screen(world_pos)
	_spawn_glitch_block(screen_pos)
	_mark_debris_coverage(screen_pos)
	debris_changed.emit(debris_percent)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var vp_size := get_viewport().get_visible_rect().size
		return world_pos - camera.global_position + vp_size / 2.0
	return world_pos

func defrag_clear(percent_to_clear: float = 35.0) -> void:
	var children := debris_root.get_children()
	if children.is_empty():
		return
	var count_to_remove := int(ceil(children.size() * (percent_to_clear / 100.0)))
	count_to_remove = mini(count_to_remove, children.size())
	# Shuffle and pick random debris to remove
	var shuffled := children.duplicate()
	shuffled.shuffle()
	var to_remove := shuffled.slice(0, count_to_remove)
	_animate_clear(to_remove)
	# Recalculate coverage after removal
	_recalculate_coverage(to_remove)

func _build_sprite_frames() -> Array[SpriteFrames]:
	var out: Array[SpriteFrames] = []
	for path in glitch_sheet_paths:
		var tex := load(path)
		if not (tex is Texture2D):
			continue
		var sheet_img := (tex as Texture2D).get_image()
		if sheet_img == null:
			continue
		var frame_w: int = sheet_img.get_width() / glitch_anim_frames_count
		var frame_h: int = sheet_img.get_height()
		if frame_w < 1 or frame_h < 1:
			continue
		var sf := SpriteFrames.new()
		# Remove default animation, add ours
		if sf.has_animation(&"default"):
			sf.remove_animation(&"default")
		sf.add_animation(&"glitch")
		sf.set_animation_speed(&"glitch", glitch_anim_fps)
		sf.set_animation_loop(&"glitch", true)
		for i in range(glitch_anim_frames_count):
			var region := Rect2i(i * frame_w, 0, frame_w, frame_h)
			var frame_img := Image.create(frame_w, frame_h, true, Image.FORMAT_RGBA8)
			frame_img.blit_rect(sheet_img, region, Vector2i.ZERO)
			var frame_tex := ImageTexture.create_from_image(frame_img)
			sf.add_frame(&"glitch", frame_tex)
		out.append(sf)
	return out

func _spawn_glitch_block(pos: Vector2) -> void:
	# Prefer animated sprites from sheets.
	if not _sprite_frames_choices.is_empty():
		var sf: SpriteFrames = _sprite_frames_choices[randi() % _sprite_frames_choices.size()]
		var anim_sprite := AnimatedSprite2D.new()
		anim_sprite.sprite_frames = sf
		anim_sprite.animation = &"glitch"
		anim_sprite.centered = true
		anim_sprite.position = pos
		anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		anim_sprite.z_index = 200
		# Scale to block_size based on first frame
		var frame_tex := sf.get_frame_texture(&"glitch", 0)
		if frame_tex:
			var ts := frame_tex.get_size()
			if ts.x > 0.0 and ts.y > 0.0:
				var s := float(block_size)
				anim_sprite.scale = Vector2(s / ts.x, s / ts.y)
		anim_sprite.play(&"glitch")
		# Randomize start frame to avoid sync
		anim_sprite.frame = randi() % glitch_anim_frames_count
		debris_root.add_child(anim_sprite)
	elif not _glitch_choices.is_empty():
		# Fallback: static BFS sprites
		var sprite := Sprite2D.new()
		sprite.texture = _glitch_choices[randi() % _glitch_choices.size()]
		sprite.centered = true
		sprite.position = pos
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 200
		var ts := sprite.texture.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			var s := float(block_size)
			sprite.scale = Vector2(s / ts.x, s / ts.y)
		debris_root.add_child(sprite)
	else:
		var img := Image.create(block_size, block_size, false, Image.FORMAT_RGBA8)
		img.fill(Color.BLACK)
		var fallback_tex := ImageTexture.create_from_image(img)
		var sprite := Sprite2D.new()
		sprite.texture = fallback_tex
		sprite.centered = true
		sprite.position = pos
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = 200
		debris_root.add_child(sprite)

func _build_glitch_choices(tex: Texture2D) -> Array[Texture2D]:
	var img := tex.get_image()
	if img == null:
		return []

	var ds := maxi(glitch_downsample, 1)
	var w: int = img.get_width()
	var h: int = img.get_height()

	# Downsampled mask for connected components.
	var mw: int = maxi(int(floor(float(w) / float(ds))), 1)
	var mh: int = maxi(int(floor(float(h) / float(ds))), 1)
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(mw * mh)

	for y in range(mh):
		for x in range(mw):
			var px: Color = img.get_pixel(x * ds, y * ds)
			var lum: float = (px.r + px.g + px.b) / 3.0
			var on := (px.a > 0.1 and lum > glitch_brightness_threshold)
			mask[y * mw + x] = 1 if on else 0

	var visited: PackedByteArray = PackedByteArray()
	visited.resize(mw * mh)

	var rects: Array[Rect2i] = []

	for y in range(mh):
		for x in range(mw):
			var idx: int = int(y) * mw + int(x)
			if visited[idx] == 1 or mask[idx] == 0:
				continue
			# BFS component
			var q: Array[Vector2i] = [Vector2i(int(x), int(y))]
			visited[idx] = 1
			var minx: int = int(x)
			var miny: int = int(y)
			var maxx: int = int(x)
			var maxy: int = int(y)
			while not q.is_empty():
				var p: Vector2i = q.pop_back()
				minx = mini(minx, p.x)
				miny = mini(miny, p.y)
				maxx = maxi(maxx, p.x)
				maxy = maxi(maxy, p.y)
				var nq: Array[Vector2i] = []
				_append_neighbors4(nq, p, mw, mh)
				for n in nq:
					var nidx: int = n.y * mw + n.x
					if visited[nidx] == 1:
						continue
					visited[nidx] = 1
					if mask[nidx] == 1:
						q.append(n)

			# Scale back to full-res rect and pad/crop.
			var rx0: int = maxi(minx * ds - glitch_crop_padding_px, 0)
			var ry0: int = maxi(miny * ds - glitch_crop_padding_px, 0)
			var rx1: int = mini((maxx + 1) * ds + glitch_crop_padding_px, w)
			var ry1: int = mini((maxy + 1) * ds + glitch_crop_padding_px, h)
			var rw: int = maxi(rx1 - rx0, 1)
			var rh: int = maxi(ry1 - ry0, 1)
			# Filter out tiny junk.
			if rw * rh < 2000:
				continue
			rects.append(Rect2i(rx0, ry0, rw, rh))

	# Sort by area desc, keep top N
	rects.sort_custom(Callable(self, "_rect_area_desc"))
	if rects.size() > glitch_pick_count:
		rects = rects.slice(0, glitch_pick_count)

	var out: Array[Texture2D] = []
	for r in rects:
		var frame_img := Image.create(r.size.x, r.size.y, true, Image.FORMAT_RGBA8)
		frame_img.fill(Color(0, 0, 0, 0))
		var src := img.get_region(Rect2i(r.position, r.size))
		frame_img.blit_rect(src, Rect2i(Vector2i.ZERO, r.size), Vector2i.ZERO)
		out.append(ImageTexture.create_from_image(frame_img))

	return out

func _recalculate_coverage(removed_nodes: Array) -> void:
	# Unmark grid cells for removed debris
	var cs := float(maxi(tracker_cell_size, 1))
	var half := float(block_size) * 0.5
	for node in removed_nodes:
		if not (node is CanvasItem):
			continue
		var center: Vector2 = node.position
		var r := Rect2(center.x - half, center.y - half, float(block_size), float(block_size))
		var x0: int = clampi(int(floor(r.position.x / cs)), 0, _grid_cols - 1)
		var y0: int = clampi(int(floor(r.position.y / cs)), 0, _grid_rows - 1)
		var x1: int = clampi(int(floor((r.position.x + r.size.x - 0.001) / cs)), 0, _grid_cols - 1)
		var y1: int = clampi(int(floor((r.position.y + r.size.y - 0.001) / cs)), 0, _grid_rows - 1)
		for gy in range(y0, y1 + 1):
			var row_off: int = gy * _grid_cols
			for gx in range(x0, x1 + 1):
				var idx: int = row_off + gx
				if _grid[idx] == 1:
					_grid[idx] = 0
					_filled_cells -= 1
	var total_cells: int = _grid_cols * _grid_rows
	debris_percent = (100.0 * float(_filled_cells) / float(total_cells)) if total_cells > 0 else 0.0
	debris_changed.emit(debris_percent)

func _animate_clear(nodes: Array) -> void:
	for c in nodes:
		if not (c is CanvasItem):
			c.queue_free()
			continue
		var ci := c as CanvasItem
		var tween := ci.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ci, "modulate:a", 0.0, clear_anim_duration)
		tween.tween_property(ci, "scale", ci.scale * 0.75, clear_anim_duration)
		tween.set_parallel(false)
		tween.tween_callback(ci.queue_free)
