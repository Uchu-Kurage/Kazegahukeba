"""家（自室）の背景 assets/field/home.png（昼）と home_night.png（夜）を、LPC の室内タイル素材から組み立てる。

素材：ElizaWy/LPC（LPC Revised）の床・壁・家具（tools/lpc_interior/ に同梱。OGA-BY 3.0）。
窓・風鈴・ドアは合う素材が無いので、同じドット絵の調子でここで描く。

見下ろしの一部屋。家具の位置と歩ける床（FieldMaps の home の roads_override）、
調べどころ（FieldMaps.HOME_*_POS：窓・ドア・部屋の真ん中）は、この配置に合わせてある。
配置を変えたら FieldMaps 側も直す。乱数の種は固定（何度実行しても同じ絵）。

  pip install pillow
  python3 tools/gen_room.py
"""
import os
import random

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "lpc_interior")
OUT_DIR = os.path.join(HERE, "..", "assets", "field")  # home.png（昼）と home_night.png（夜）

W, H = 1152, 648
T = 32

# 部屋の外枠（px）。上の壁は ROOM_Y0〜FLOOR_Y0、床は FLOOR_Y0〜ROOM_Y1。
ROOM_X0, ROOM_X1 = 224, 928
ROOM_Y0, FLOOR_Y0, ROOM_Y1 = 64, 192, 624
EDGE = 12  # 左右・下の壁の厚み（見下ろしで見える壁の天端）

OUTSIDE = (26, 22, 20)
WALL_CAP = (92, 64, 44)      # 壁の天端（木の縁）
BASEBOARD = (110, 72, 44)    # 巾木
BASEBOARD_DARK = (74, 48, 30)


def load(name):
	return Image.open(os.path.join(SRC, name)).convert("RGBA")


def cell(sheet, c0, r0, c1=None, r1=None, trim=True):
	c1 = c0 if c1 is None else c1
	r1 = r0 if r1 is None else r1
	im = sheet.crop((c0 * T, r0 * T, (c1 + 1) * T, (r1 + 1) * T))
	b = im.getbbox() if trim else None
	return im.crop(b) if b else im


FLOOR = load("wood_floor_a.png")
WALLS = load("painted_walls.png")
BEDS = load("beds_single_b.png")
DESK = load("desk_office.png")
CHAIR = load("chair_office.png")
SHELF = load("shelf.png")
DRESSER = load("dresser.png")
CABINET = load("cabinet.png")
TABLE = load("table_rough_wood.png")
PLANTER = load("planter.png")
RUG = load("diamond_rug.png")
CURTAINS = load("curtains.png")
POSTERS = load("posters.png")
LAMP = load("lighting_table.png")
PAPER = load("loose_paper.png")

FLOOR_TILES = [cell(FLOOR, 3, r, trim=False) for r in (0, 1, 2)]  # 落ち着いた中間色の板（1列だけ使い色をそろえる）
WALL_TILE = cell(WALLS, 4, 5, trim=False)    # 生成りの塗り壁（無地のセル）
BED = cell(BEDS, 8, 0, 9, 2)                  # 青い掛け布団のシングルベッド（頭が壁側）
DESK_SPR = cell(DESK, 0, 0, 3, 1)             # 横長の机（引き出し付き）
CHAIR_SPR = cell(CHAIR, 1, 0)                 # 机に向かう椅子（後ろ姿）
SHELF_SPR = cell(SHELF, 0, 0, 2, 0)           # 壁の棚板
DRESSER_SPR = cell(DRESSER, 5, 0, 6, 1)       # たんす（木目）
BOOKCASE_SPR = cell(CABINET, 2, 3, 3, 4)      # 本棚
LOW_TABLE_SPR = cell(TABLE, 0, 4, 2, 5)       # 低い木のテーブル（ちゃぶ台がわり）
PLANTER_SPR = cell(PLANTER, 0, 0, 1, 2)       # 鉢植え
CURTAIN_SPR = cell(CURTAINS, 16, 10, 19, 12)  # 白いレースのカーテン（左右に束ねた一組）
POSTER_SPR = cell(POSTERS, 0, 1)
LAMP_SPR = cell(LAMP, 0, 0)                   # 卓上スタンド
PAPER_SPR = cell(PAPER, 0, 0)                 # 紙（宿題のプリント）


def rug(img, x0, y0, cols, rows):
	"""菱形模様のラグ（3×3 の縁・中央のセルを敷き詰めて、好きな大きさにする）。"""
	for r in range(rows):
		for c in range(cols):
			sc = 0 if c == 0 else (2 if c == cols - 1 else 1)
			sr = 0 if r == 0 else (2 if r == rows - 1 else 1)
			img.alpha_composite(cell(RUG, sc, sr, trim=False), (x0 + c * T, y0 + r * T))


def draw_window(img, x0, y0, w, h, night=False):
	"""夏空の見える窓（木枠・ガラス越しの青空と入道雲・窓台）。夜は星空と月。素材が無いのでドットで描く。"""
	d = ImageDraw.Draw(img)
	frame = (122, 84, 52)
	frame_dark = (84, 56, 34)
	d.rectangle((x0 - 6, y0 - 6, x0 + w + 5, y0 + h + 5), fill=frame_dark)
	d.rectangle((x0 - 4, y0 - 4, x0 + w + 3, y0 + h + 3), fill=frame)
	rng = random.Random(7)
	if night:
		# 夜空：深い紺、星と月。
		for yy in range(h):
			t = yy / max(h - 1, 1)
			d.line((x0, y0 + yy, x0 + w - 1, y0 + yy), fill=(int(14 + 30 * t), int(22 + 40 * t), int(56 + 50 * t)))
		for _ in range(26):
			sx, sy = rng.uniform(x0 + 2, x0 + w - 3), rng.uniform(y0 + 2, y0 + h - 22)
			d.point((sx, sy), fill=(255, 255, 230) if rng.random() < 0.7 else (200, 220, 255))
		d.ellipse((x0 + w * 0.68, y0 + 10, x0 + w * 0.68 + 16, y0 + 26), fill=(250, 240, 200))
		d.ellipse((x0 + w * 0.68 + 5, y0 + 7, x0 + w * 0.68 + 21, y0 + 23), fill=(20, 30, 66))  # 三日月
		mountain = (24, 40, 46)
	else:
		# 空：上が濃く、下ほど白む青。
		for yy in range(h):
			t = yy / max(h - 1, 1)
			d.line((x0, y0 + yy, x0 + w - 1, y0 + yy), fill=(int(64 + 120 * t), int(150 + 80 * t), int(232 + 18 * t)))
		# 入道雲（白い丸を重ねた塊）。
		cx, cy = x0 + w * 0.62, y0 + h * 0.62
		for _ in range(14):
			rx, ry = rng.uniform(-30, 30), rng.uniform(-22, 8)
			r = rng.uniform(8, 15)
			d.ellipse((cx + rx - r, cy + ry - r, cx + rx + r, cy + ry + r), fill=(250, 252, 255))
		mountain = (96, 150, 120)
	# 遠くの山並み。
	d.polygon([(x0, y0 + h - 10), (x0 + w * 0.3, y0 + h - 20), (x0 + w * 0.55, y0 + h - 12),
		(x0 + w * 0.8, y0 + h - 22), (x0 + w, y0 + h - 14), (x0 + w, y0 + h), (x0, y0 + h)], fill=mountain)
	# 桟（十字）と窓台。
	d.rectangle((x0 + w // 2 - 2, y0, x0 + w // 2 + 1, y0 + h), fill=frame)
	d.rectangle((x0, y0 + h // 2 - 1, x0 + w, y0 + h // 2 + 1), fill=frame)
	d.rectangle((x0 - 10, y0 + h + 4, x0 + w + 9, y0 + h + 10), fill=frame_dark)
	d.rectangle((x0 - 10, y0 + h + 4, x0 + w + 9, y0 + h + 6), fill=frame)


def draw_furin(img, x, y):
	"""風鈴（ガラスの鈴・赤い絵付け・短冊）。窓辺に吊るす夏の印。"""
	d = ImageDraw.Draw(img)
	d.line((x, y - 14, x, y - 6), fill=(70, 60, 50), width=1)
	d.pieslice((x - 7, y - 7, x + 7, y + 9), 180, 360, fill=(214, 236, 246))
	d.rectangle((x - 7, y, x + 7, y + 1), fill=(214, 236, 246))
	d.arc((x - 7, y - 7, x + 7, y + 9), 180, 360, fill=(150, 190, 210))
	d.point([(x - 3, y - 3), (x + 2, y - 4), (x - 1, y - 1)], fill=(210, 60, 60))
	d.line((x, y + 1, x, y + 8), fill=(70, 60, 50))
	d.rectangle((x - 3, y + 8, x + 3, y + 20), fill=(236, 230, 210))
	d.line((x - 3, y + 8, x - 3, y + 20), fill=(190, 180, 160))


def draw_door(img, x0, y0, w, h):
	"""木のドア（2 枚パネル・真鍮のノブ）と枠。部屋から出かける口。"""
	d = ImageDraw.Draw(img)
	d.rectangle((x0 - 4, y0 - 4, x0 + w + 3, y0 + h - 1), fill=(84, 56, 34))
	d.rectangle((x0, y0, x0 + w - 1, y0 + h - 1), fill=(150, 104, 64))
	for py0, py1 in ((y0 + 6, y0 + h // 2 - 4), (y0 + h // 2 + 2, y0 + h - 8)):
		d.rectangle((x0 + 6, py0, x0 + w - 7, py1), fill=(132, 90, 54))
		d.line((x0 + 6, py0, x0 + w - 7, py0), fill=(110, 74, 44))
		d.line((x0 + 6, py0, x0 + 6, py1), fill=(110, 74, 44))
	d.ellipse((x0 + w - 11, y0 + h // 2 - 3, x0 + w - 5, y0 + h // 2 + 3), fill=(222, 186, 80))
	d.point((x0 + w - 9, y0 + h // 2 - 1), fill=(255, 240, 170))


def draw_fan(img, x, y):
	"""扇風機（白い羽根・青いガード・首振りの台）。(x, y) は台の下端中央。夏の部屋の印。"""
	d = ImageDraw.Draw(img)
	d.ellipse((x - 12, y - 6, x + 12, y + 2), fill=(70, 80, 90))
	d.ellipse((x - 11, y - 7, x + 11, y), fill=(222, 228, 232))
	d.rectangle((x - 2, y - 30, x + 1, y - 4), fill=(200, 206, 210))
	cx, cy, r = x, y - 40, 13
	d.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), fill=(60, 110, 160))
	d.ellipse((cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1), fill=(200, 230, 245))
	for a, b in ((-r + 3, -3), (3, -r + 3), (-3, r - 3)):
		d.ellipse((cx + min(a, b) // 2 - 5, cy + max(a, b) // 2 - 5, cx + min(a, b) // 2 + 5, cy + max(a, b) // 2 + 5), fill=(250, 252, 255))
	d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=(60, 110, 160))
	for k in range(-r + 3, r - 2, 4):
		d.line((cx + k, cy - r + 2, cx + k, cy + r - 2), fill=(150, 190, 215))


def build(night):
	rng = random.Random(1)
	img = Image.new("RGBA", (W, H), OUTSIDE + (255,))
	d = ImageDraw.Draw(img)

	# 床（木）→ 奥の壁（塗り壁）→ 巾木 → 壁の天端（左右・下・上）。
	for y in range(FLOOR_Y0, ROOM_Y1, T):
		for x in range(ROOM_X0, ROOM_X1, T):
			img.paste(rng.choice(FLOOR_TILES), (x, y))
	wall = Image.blend(WALL_TILE, Image.new("RGBA", WALL_TILE.size, (214, 200, 168, 255)), 0.35)  # 少し落ち着かせる
	for y in range(ROOM_Y0, FLOOR_Y0, T):
		for x in range(ROOM_X0, ROOM_X1, T):
			img.paste(wall, (x, y))
	d.rectangle((ROOM_X0, FLOOR_Y0 - 8, ROOM_X1 - 1, FLOOR_Y0 - 1), fill=BASEBOARD)
	d.line((ROOM_X0, FLOOR_Y0 - 1, ROOM_X1 - 1, FLOOR_Y0 - 1), fill=BASEBOARD_DARK)
	shade = Image.new("RGBA", (W, H))
	ImageDraw.Draw(shade).rectangle((ROOM_X0, FLOOR_Y0, ROOM_X1 - 1, FLOOR_Y0 + 10), fill=(40, 24, 10, 60))
	img.alpha_composite(shade)
	d.rectangle((ROOM_X0 - EDGE, ROOM_Y0 - EDGE, ROOM_X1 + EDGE - 1, ROOM_Y0 - 1), fill=WALL_CAP)
	d.rectangle((ROOM_X0 - EDGE, ROOM_Y0 - EDGE, ROOM_X0 - 1, ROOM_Y1 + EDGE - 1), fill=WALL_CAP)
	d.rectangle((ROOM_X1, ROOM_Y0 - EDGE, ROOM_X1 + EDGE - 1, ROOM_Y1 + EDGE - 1), fill=WALL_CAP)
	d.rectangle((ROOM_X0 - EDGE, ROOM_Y1, ROOM_X1 + EDGE - 1, ROOM_Y1 + EDGE - 1), fill=WALL_CAP)
	d.rectangle((ROOM_X0 - EDGE, ROOM_Y0 - EDGE, ROOM_X1 + EDGE - 1, ROOM_Y1 + EDGE - 1), outline=(60, 40, 26))

	# 奥の壁：窓（カーテン・風鈴）、棚、ポスター、ドア。
	draw_window(img, 512, 82, 128, 84, night)
	img.alpha_composite(CURTAIN_SPR, (576 - CURTAIN_SPR.width // 2, 76))
	draw_furin(img, 548, 98)
	img.alpha_composite(SHELF_SPR, (236, 118))
	img.alpha_composite(POSTER_SPR, (690, 104))
	draw_door(img, 856, 116, 48, 76)

	# 家具（奥＝壁ぎわから）。ベッドは頭を壁につけて左奥、たんすと本棚、机と椅子は右奥。
	img.alpha_composite(BED, (244, 176))
	img.alpha_composite(DRESSER_SPR, (330, FLOOR_Y0 - DRESSER_SPR.height + 18))
	img.alpha_composite(BOOKCASE_SPR, (410, FLOOR_Y0 - BOOKCASE_SPR.height + 12))
	desk_y = FLOOR_Y0 - DESK_SPR.height + 24
	img.alpha_composite(DESK_SPR, (700, desk_y))
	img.alpha_composite(LAMP_SPR, (712, desk_y - LAMP_SPR.height + 12))
	img.alpha_composite(PAPER_SPR, (770, desk_y + 4))
	img.alpha_composite(CHAIR_SPR, (752, desk_y + DESK_SPR.height - 10))
	draw_fan(img, 350, 262)
	# 部屋の真ん中にラグと低いテーブル、右手前に鉢植え。
	rug(img, 448, 352, 8, 5)
	img.alpha_composite(LOW_TABLE_SPR, (576 - LOW_TABLE_SPR.width // 2, 400))
	img.alpha_composite(PLANTER_SPR, (ROOM_X1 - PLANTER_SPR.width - 10, ROOM_Y1 - PLANTER_SPR.height - 6))

	if night:
		img = darken_for_night(img, lamp=(724, 150))
	out = os.path.join(OUT_DIR, "home_night.png" if night else "home.png")
	img.convert("RGB").save(out, optimize=True)
	print("wrote", out)


def darken_for_night(img, lamp):
	"""夜：部屋全体を青く沈め、机のスタンドのまわりだけ暖かい明かりを残す（窓の夜空はそのまま）。"""
	w, h = img.size
	dark = Image.new("RGBA", (w, h), (18, 22, 48, 150))
	glow = Image.new("L", (w, h), 0)
	gd = ImageDraw.Draw(glow)
	lx, ly = lamp
	for r in range(260, 0, -4):  # 中心ほど明るい（暗幕を薄くする）同心円
		gd.ellipse((lx - r, ly - r * 0.8, lx + r, ly + r * 0.8), fill=int(255 * (1 - r / 260) ** 1.4))
	gd.rectangle((512, 82, 640, 166), fill=255)  # 窓の夜空は暗幕をかけない（星と月を見せる）
	from PIL import ImageChops
	alpha = ImageChops.multiply(dark.getchannel("A"), ImageChops.invert(glow))
	dark.putalpha(alpha)
	out = img.copy()
	out.alpha_composite(dark)
	warm = Image.new("RGBA", (w, h), (255, 200, 120, 0))
	warm.putalpha(glow.point(lambda v: int(v * 0.16)))
	out.alpha_composite(warm)
	return out


if __name__ == "__main__":
	build(night=False)
	build(night=True)
