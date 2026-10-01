"""途中の道（road_a〜d）の背景 PNG を、LPC のタイル素材から組み立てる。

素材：ElizaWy/LPC（LPC Revised）の夏の地形タイル（tools/lpc_terrain/ に同梱。OGA-BY 3.0）。
出力：assets/field/road_<x>.png（1152×648）。FieldMaps の bg パス（res://assets/field/<画面ID>.png）に
そのまま乗るので、置くだけで散策画面の背景が差し替わる（無ければ従来どおりプレースホルダ）。

道（土）の位置は FieldMaps の歩ける帯（ROAD_H / ROAD_V）に合わせてある。帯を変えたらここも直す。
タイル 32px を等倍で敷く（キャラのスプライトと同じ縮尺。FieldMaps の road_* の depth_override を参照）。
配置は乱数の種を固定しているので、何度実行しても同じ絵になる。

  pip install pillow
  python3 tools/gen_road_tiles.py
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "lpc_terrain")
OUT = os.path.join(HERE, "..", "assets", "field")

W, H = 1152, 648
T = 32
COLS, ROWS = W // T, (H + T - 1) // T  # 36 × 21（最下段は半分はみ出す）

# FieldMaps.ROAD_H = Rect2(120, 300, 912, 130) / ROAD_V = Rect2(500, 130, 152, 460) に合わせた土の道。
# 縁の草（フリンジ）が道へ 10〜14px かぶるので、土は帯より少し広く敷く。
ROAD_H_ROWS = (9, 13)    # y 288〜448
ROAD_V_COLS = (15, 20)   # x 480〜672


def load(name):
	return Image.open(os.path.join(SRC, name)).convert("RGBA")


TERRAIN = load("terrain_summer.png")
TREES = load("trees_summer.png")
PLANTS = load("plants_summer.png")
ROCKS = load("rocks_grasslands.png")
FLOWERS = load("wildflowers_summer.png")
FENCE = load("plain_fence_a.png")


def tile(cx, cy, sheet=TERRAIN):
	return sheet.crop((cx * T, cy * T, cx * T + T, cy * T + T))


def sprite(sheet, c0, r0, c1, r1):
	"""セル範囲 (c0,r0)〜(c1,r1) を切り出し、透明な余白を詰めた一つの物体として返す。"""
	im = sheet.crop((c0 * T, r0 * T, (c1 + 1) * T, (r1 + 1) * T))
	bbox = im.getbbox()
	return im.crop(bbox) if bbox else im


# --- 地面タイル（terrain_summer.png のセル座標）---
GRASS = [tile(3, 1), tile(4, 1), tile(5, 1), tile(3, 2), tile(4, 2), tile(5, 2)]
DIRT = [tile(3, 3), tile(4, 3), tile(5, 3), tile(3, 4), tile(4, 4), tile(5, 4)]
# 水面：基本の水＋さざ波の入った水を混ぜ、のっぺりさせない。
WATER = [tile(1, 11), tile(12, 16), tile(13, 16), tile(14, 16), tile(15, 16), tile(12, 17), tile(14, 17)]
# 草むらの塊（0..2, 0..2）の辺：道の縁に重ねて、草が土へ垂れかかる境目にする。
EDGE_GRASS_ABOVE = tile(1, 2)  # 上が草・下へ垂れる（道の上辺に置く）
EDGE_GRASS_BELOW = tile(1, 0)  # 下が草・上へ垂れる（道の下辺に置く）
EDGE_GRASS_LEFT = tile(2, 1)   # 左が草（縦の道の左辺に置く）
EDGE_GRASS_RIGHT = tile(0, 1)  # 右が草（縦の道の右辺に置く）
BANK_TOP = tile(1, 10)         # 上が草・下が水（川の上の岸）

# --- 物体（セル範囲から切り出し）。1セルに1つずつ描かれているものは1セルで切る ---
TREE_ROUND = [sprite(TREES, c, r, c + 2, r + 3) for c, r in ((4, 0), (7, 0), (10, 0), (4, 4), (7, 4), (4, 8), (7, 8), (10, 8))]
TREE_PINE = [sprite(TREES, c, r, c + 2, r + 3) for c, r in ((4, 12), (7, 12), (13, 12))]
BUSH = [sprite(PLANTS, c, r, c, r) for c, r in ((0, 0), (1, 0), (0, 1), (1, 1), (6, 0), (7, 0), (6, 1))]
SHRUB = [sprite(PLANTS, c, 2, c, 3) for c in (0, 1)]                     # 円錐形の低木
LEAFY = [sprite(PLANTS, c, r, c, r) for c, r in ((4, 0), (5, 0), (4, 1), (5, 1), (2, 0), (3, 0), (2, 1), (3, 1))]
FERN = [sprite(PLANTS, 6, 2, 7, 3), sprite(PLANTS, 4, 2, 4, 3), sprite(PLANTS, 5, 2, 5, 3)]
TALL_GRASS = [sprite(PLANTS, c, 0, c, 1) for c in range(8, 14)] + [sprite(PLANTS, 10, 2, 10, 3)]
LILY = [sprite(PLANTS, c, r, c, r) for c, r in ((12, 2), (13, 2), (12, 3), (13, 3))]
ROCK_BIG = [sprite(ROCKS, c, r, c + 1, r + 1) for c, r in ((0, 0), (0, 4), (0, 8), (2, 0), (2, 4), (4, 0), (4, 4), (4, 8))]
ROCK_SMALL = [sprite(ROCKS, c, r, c, r) for c, r in ((4, 2), (5, 2), (4, 3), (5, 3))] + \
	[sprite(ROCKS, c, r, c + 1, r) for c, r in ((0, 2), (0, 3), (2, 2), (2, 3))]
FENCE_H = FENCE.crop((0, 3 * T, 3 * T, 4 * T)).crop(FENCE.crop((0, 3 * T, 3 * T, 4 * T)).getbbox())


def wildflower_sprites():
	"""野の花シート（16px 刻み）から、中身のある小片を全部拾う。"""
	out = []
	for y in range(0, FLOWERS.height, 16):
		for x in range(0, FLOWERS.width, 16):
			im = FLOWERS.crop((x, y, x + 16, y + 16))
			if im.getbbox():
				out.append(im)
	return out


WILDFLOWERS = wildflower_sprites()


class Scene:
	"""一枚の背景を組む作業台。地面 → 縁 → 物体（奥から手前へ＝下端の Y 順）の順に描く。"""

	def __init__(self, seed):
		self.rng = random.Random(seed)
		self.img = Image.new("RGBA", (COLS * T, ROWS * T))
		self.objects = []  # (足元Y, x, sprite, 影の有無)
		self.blocked = []  # 物体を置かない矩形（道・川など）

	def fill(self, tiles, c0=0, r0=0, c1=COLS - 1, r1=ROWS - 1):
		for r in range(r0, r1 + 1):
			for c in range(c0, c1 + 1):
				self.img.paste(self.rng.choice(tiles) if isinstance(tiles, list) else tiles, (c * T, r * T))

	def overlay(self, t, c, r):
		self.img.alpha_composite(t, (c * T, r * T))

	def road_h(self):
		r0, r1 = ROAD_H_ROWS
		self.fill(DIRT, 0, r0, COLS - 1, r1)
		for c in range(COLS):
			self.overlay(EDGE_GRASS_ABOVE, c, r0)
			self.overlay(EDGE_GRASS_BELOW, c, r1)
		self.blocked.append((0, r0 * T - 8, W, (r1 + 1) * T + 8))

	def road_v(self):
		c0, c1 = ROAD_V_COLS
		self.fill(DIRT, c0, 0, c1, ROWS - 1)
		for r in range(ROWS):
			self.overlay(EDGE_GRASS_LEFT, c0, r)
			self.overlay(EDGE_GRASS_RIGHT, c1, r)
		self.blocked.append((c0 * T - 8, 0, (c1 + 1) * T + 8, H))

	def river_bottom(self, top_row):
		"""画面下に川（top_row が岸）。"""
		self.fill(WATER, 0, top_row, COLS - 1, ROWS - 1)
		for c in range(COLS):
			self.overlay(BANK_TOP, c, top_row)
		self.blocked.append((0, top_row * T, W, H))

	def free(self, x0, y0, x1, y1):
		for bx0, by0, bx1, by1 in self.blocked:
			if x0 < bx1 and x1 > bx0 and y0 < by1 and y1 > by0:
				return False
		return True

	def place(self, spr, foot_x, foot_y, shadow=False, force=False):
		"""物体を「足元（下端中央）」の座標で置く。道・川にかかる位置は避ける。"""
		x0 = int(foot_x - spr.width / 2)
		y0 = int(foot_y - spr.height)
		# 足元まわり（幹・根元）だけ当たりを見る（枝葉が道の上に張り出すのは自然なので許す）。
		if not force and not self.free(x0 + spr.width * 0.25, foot_y - 12, x0 + spr.width * 0.75, foot_y + 4):
			return False
		self.objects.append((foot_y, x0, y0, spr, shadow))
		return True

	def scatter(self, sprites, n, area, shadow=False):
		x0, y0, x1, y1 = area
		for _ in range(n * 4):
			if n <= 0:
				break
			if self.place(self.rng.choice(sprites), self.rng.uniform(x0, x1), self.rng.uniform(y0, y1), shadow):
				n -= 1

	def flowers(self, n, area):
		x0, y0, x1, y1 = area
		for _ in range(n):
			fx, fy = self.rng.uniform(x0, x1), self.rng.uniform(y0, y1)
			if self.free(fx - 4, fy - 4, fx + 4, fy + 4):
				spr = self.rng.choice(WILDFLOWERS)
				self.img.alpha_composite(spr, (int(fx - 8), int(fy - 8)))

	def render(self, name):
		# 影（土色の楕円をぼかして）→ 物体を足元の Y 順（奥→手前）に。
		shade = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
		d = ImageDraw.Draw(shade)
		for foot_y, x0, y0, spr, shadow in self.objects:
			if shadow:
				w = spr.width * 0.42
				cx = x0 + spr.width / 2
				d.ellipse((cx - w, foot_y - 9, cx + w, foot_y + 7), fill=(30, 40, 20, 90))
		self.img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(3)))
		for foot_y, x0, y0, spr, shadow in sorted(self.objects, key=lambda o: o[0]):
			self.img.alpha_composite(spr, (x0, y0))
		out = self.img.crop((0, 0, W, H)).convert("RGB")
		path = os.path.join(OUT, f"{name}.png")
		out.save(path, optimize=True)
		print("wrote", path)


# --- 各道の絵 -------------------------------------------------------------------
# 木は道より奥（上側）なら幹が道の上端より上に、手前（下側）なら梢が歩く帯にかからない高さに置く
# （キャラは背景より常に手前に描かれるので、木の後ろに隠れる表現ができないため）。

def road_a():
	"""畦道への道（町→自然）：左は町はずれ（柵の空き地・石）、右へ行くほど草深く、木と野の花が増える。"""
	s = Scene(101)
	s.fill(GRASS)
	s.road_h()
	# 道の奥（上）：左に柵で囲った空き地、右に木立。
	for i in range(5):
		s.place(FENCE_H, 70 + FENCE_H.width // 2 + i * FENCE_H.width, 262, force=True)
	s.scatter(ROCK_SMALL, 4, (40, 120, 400, 240))
	s.scatter(LEAFY, 5, (40, 60, 420, 240))
	s.scatter(TREE_ROUND, 6, (480, 110, 1150, 262), shadow=True)
	s.scatter(TREE_ROUND + TREE_PINE, 4, (440, 0, 1150, 140), shadow=True)
	s.scatter(BUSH, 8, (380, 60, 1140, 270), shadow=True)
	s.scatter(TALL_GRASS, 18, (380, 20, 1150, 280))
	# 道の手前（下）：草むらと野の花、右寄りに低い茂み。木は画面下端で梢が帯にかからない位置だけ。
	s.scatter(TALL_GRASS, 22, (300, 465, 1150, 640))
	s.scatter(LEAFY + BUSH, 8, (500, 480, 1120, 640), shadow=True)
	s.scatter(ROCK_SMALL, 4, (40, 465, 420, 630))
	s.place(TREE_ROUND[2], 1060, 700, shadow=True, force=True)
	s.place(TREE_PINE[0], 900, 720, shadow=True, force=True)
	s.flowers(60, (0, 0, 420, H))
	s.flowers(150, (420, 0, W, H))
	s.render("road_a")


def road_b():
	"""祭りへの参道（ゆるやかな登り）：両側に木が並ぶ並木道。足元にシダと茂み。"""
	s = Scene(202)
	s.fill(GRASS)
	s.road_v()
	for left in (True, False):
		x0, x1 = (0, 470) if left else (682, W)
		row_x = 400 if left else 752
		# 並木：道ぞいに奥から手前へ等間隔（少しずつ揺らして、整列しすぎないように）。
		for i, y in enumerate(range(120, 760, 112)):
			pick = TREE_PINE if i % 2 else TREE_ROUND
			s.place(s.rng.choice(pick), row_x + s.rng.uniform(-10, 10), y + s.rng.uniform(-6, 6), shadow=True, force=True)
		# 並木の外側：鎮守の森へ続く木立（奥ほど密に）。
		inner = (x0 + 20, 0, row_x - 90, 700) if left else (row_x + 90, 0, x1 - 20, 700)
		s.scatter(TREE_PINE + TREE_ROUND, 9, inner, shadow=True)
		s.scatter(FERN + SHRUB, 10, (x0, 40, x1, 640))
		s.scatter(LEAFY, 8, (x0, 40, x1, 640))
	s.flowers(50, (0, 0, W, H))
	s.render("road_b")


def road_c():
	"""丘への坂道（登り）：岩が増え、左は木立、右は開けた草地（町が下に開けていく感じ）。"""
	s = Scene(303)
	s.fill(GRASS)
	s.road_v()
	s.scatter(TREE_ROUND + TREE_PINE, 7, (30, 100, 420, 760), shadow=True)
	s.scatter(ROCK_BIG, 5, (40, 40, 450, 640), shadow=True)
	s.scatter(ROCK_BIG, 4, (700, 30, 1120, 420), shadow=True)
	s.scatter(ROCK_SMALL, 12, (400, 0, 780, 648))
	s.scatter(TALL_GRASS, 26, (690, 30, 1150, 640))
	s.scatter(LEAFY + FERN, 8, (30, 30, 450, 640))
	s.scatter(BUSH, 5, (720, 360, 1130, 640), shadow=True)
	s.flowers(160, (690, 0, W, H))
	s.flowers(40, (0, 0, 460, H))
	s.render("road_c")


def road_d():
	"""川沿いの道（下流へ）：道の手前に川。岸に葦、水面にスイレン、奥は木立と茂み。"""
	s = Scene(404)
	s.fill(GRASS)
	s.road_h()
	s.river_bottom(16)
	s.scatter(TREE_ROUND, 7, (30, 120, 1130, 262), shadow=True)
	s.scatter(TREE_ROUND + TREE_PINE, 4, (30, 0, 1130, 120), shadow=True)
	s.scatter(BUSH + LEAFY, 8, (30, 60, 1130, 270), shadow=True)
	s.scatter(TALL_GRASS, 12, (30, 20, 1130, 275))
	# 道と川のあいだの草地：葦（背の高い草）を岸ぞいに並べ、ところどころ岩。
	s.scatter(TALL_GRASS, 30, (0, 470, W, 518))
	s.scatter(ROCK_SMALL, 4, (60, 466, 1100, 512))
	# 水面のスイレン（川の上は物体を置かない設定なので、直接貼る）。
	for _ in range(9):
		lx, ly = s.rng.uniform(30, 1120), s.rng.uniform(560, 630)
		s.img.alpha_composite(s.rng.choice(LILY), (int(lx), int(ly)))
	s.flowers(70, (0, 0, W, 520))
	s.render("road_d")


if __name__ == "__main__":
	road_a()
	road_b()
	road_c()
	road_d()
