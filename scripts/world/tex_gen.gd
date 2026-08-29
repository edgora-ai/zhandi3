class_name TexGen
## 程序化贴图工厂：叶簇/草叶/花朵 alpha 贴图（零外部素材，运行时生成）


## 树叶簇贴图：圆盘内散布上百片带叶脉的叶子，alpha 裁剪
const TEX_CACHE_VERSION := 1


## 磁盘缓存：程序化贴图只在首次生成时付费，之后启动直接读 PNG（像素无损）。
static func _load_or_make(key: String, gen: Callable) -> ImageTexture:
	var dir := "user://texcache"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s_v%d.png" % [dir, key, TEX_CACHE_VERSION]
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img == null or img.is_empty():
		img = gen.call()
		img.save_png(path)
	img.generate_mipmaps() # // FIX: R3-TA5 远处墙面高频闪烁
	return ImageTexture.create_from_image(img)


static func leaf_cluster(seed: int = 42) -> ImageTexture:
	return _load_or_make("leaf%d" % seed, func() -> Image: return _gen_leaf_cluster(seed))


static func _gen_leaf_cluster(seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	for i in range(150):
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * size * 0.42
		var pos := center + Vector2(cos(ang), sin(ang)) * r
		var leaf_ang := ang + rng.randf_range(-0.8, 0.8)
		var len := rng.randf_range(15.0, 27.0)
		var wid := len * rng.randf_range(0.32, 0.45)
		var shade := rng.randf_range(0.72, 1.0)
		_draw_leaf(img, pos, leaf_ang, len, wid, shade)
	return img


static func _draw_leaf(img: Image, center: Vector2, ang: float, length: float, width: float, shade: float) -> void:
	var c := cos(ang)
	var s := sin(ang)
	var r := int(length) + 2
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var lx := dx * c + dy * s
			var ly := -dx * s + dy * c
			var t := lx / length
			if absf(t) > 1.0:
				continue
			var hw := width * (1.0 - t * t)
			if absf(ly) > hw:
				continue
			var px := int(center.x + dx)
			var py := int(center.y + dy)
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			# 叶脉略亮
			var v := minf(shade * 1.18, 1.0) if absf(ly) < 1.1 else shade
			img.set_pixel(px, py, Color(v, v, v, 1.0))


## 草丛贴图：7 根细长弯曲草叶，alpha 裁剪
static func grass_blades(seed: int = 7) -> ImageTexture:
	return _load_or_make("grass%d" % seed, func() -> Image: return _gen_grass_blades(seed))


static func _gen_grass_blades(seed: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for b in range(7):
		var base_x := 20.0 + b * 36.0 + rng.randf_range(-7.0, 7.0)
		var lean := rng.randf_range(-32.0, 32.0)
		var shade := rng.randf_range(0.78, 1.0)
		for y in range(size):
			var t := 1.0 - float(y) / (size - 1)   # 0 底部 → 1 叶尖
			var cx := base_x + lean * t * t
			var hw := maxf(0.4, 3.4 * (1.0 - t))
			var x0 := int(cx - hw)
			var x1 := int(cx + hw)
			for x in range(x0, x1 + 1):
				if x >= 0 and x < size:
					img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	return img


## 花朵贴图：5 瓣白花 + 黄色花心
## // FIX: OPT-F8/TA11 建筑墙面程序化纹理：灰泥斑驳 / 木板条纹 / 砖缝（配 uv1_triplanar 上墙）
static func wall_plaster() -> ImageTexture:
	return _load_or_make("wall_plaster", _gen_wall_plaster)

static func _gen_wall_plaster() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8) # // FIX: R3-TA5 64px 近看糊板→128
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in range(64):
		for x in range(64):
			var n := rng.randf_range(-0.06, 0.06) + 0.04 * sin(float(x) * 0.4) + 0.03 * sin(float(y) * 0.23)
			var c := 0.82 + n
			img.set_pixel(x, y, Color(c, c * 0.965, c * 0.88, 1.0))
	return img

static func wall_plank() -> ImageTexture:
	return _load_or_make("wall_plank", _gen_wall_plank)

static func _gen_wall_plank() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for y in range(64):
		var plank := y / 16
		var seam := (y % 16) == 0
		for x in range(64):
			var n := rng.randf_range(-0.05, 0.05) + 0.03 * sin(float(x) * 0.9 + float(plank) * 2.1)
			var c := 0.60 + n
			if seam:
				c *= 0.62
			if x % 32 == 0:
				c *= 0.85
			img.set_pixel(x, y, Color(c, c * 0.72, c * 0.5, 1.0))
	return img

static func wall_brick() -> ImageTexture:
	return _load_or_make("wall_brick", _gen_wall_brick)

static func _gen_wall_brick() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for y in range(64):
		var row := y / 8
		var offset := (row % 2) * 8
		for x in range(64):
			var bx := (x + offset) % 16
			var by := y % 8
			var mortar := by == 0 or bx == 0
			var n := rng.randf_range(-0.05, 0.05)
			if mortar:
				img.set_pixel(x, y, Color(0.62 + n, 0.58 + n, 0.52 + n, 1.0))
			else:
				var c := 0.72 + n
				img.set_pixel(x, y, Color(c, c * 0.72, c * 0.58, 1.0))
	return img

static func flower(seed: int = 3) -> ImageTexture:
	return _load_or_make("flower%d" % seed, func() -> Image: return _gen_flower(seed))


static func _gen_flower(seed: int) -> Image:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	for p in range(5):
		var ang := p * TAU / 5.0
		var pc := center + Vector2(cos(ang), sin(ang)) * size * 0.22
		_fill_ellipse(img, pc, ang, size * 0.20, size * 0.11, Color(1, 1, 1, 1))
	_fill_ellipse(img, center, 0.0, size * 0.11, size * 0.11, Color(0.95, 0.80, 0.20, 1))
	return img


static func _fill_ellipse(img: Image, center: Vector2, ang: float, rx: float, ry: float, col: Color) -> void:
	var c := cos(ang)
	var s := sin(ang)
	var r := int(maxf(rx, ry)) + 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var lx := dx * c + dy * s
			var ly := -dx * s + dy * c
			var d := (lx * lx) / (rx * rx) + (ly * ly) / (ry * ry)
			if d > 1.0:
				continue
			var px := int(center.x + dx)
			var py := int(center.y + dy)
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, col)
