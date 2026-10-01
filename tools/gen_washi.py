"""和紙の 9-slice テクスチャ（assets/ui/washi_*.png）を生成する。

UITheme.washi_paper() が StyleBoxTexture として読む。色は UITheme.WASHI / BORDER / SHADOW と合わせてある。
紙の繊維は周期的なノイズで作るので、中央をタイル張りにしても継ぎ目が出ない。

  pip install numpy pillow
  python3 tools/gen_washi.py
"""
import numpy as np
from PIL import Image

SEED = 7
WASHI = np.array([0xF5, 0xF0, 0xE6], float)   # UITheme.WASHI
FIBER = np.array([0xE2, 0xD8, 0xC2], float)   # 繊維の濃いところ（WASHI を少し土色に）
EDGE = np.array([0xCB, 0xBF, 0xA6], float)    # UITheme.BORDER
ACCENT_LINE = np.array([0x3A, 0x82, 0xB3], float)  # UITheme.ACCENT_LINE（選択中の縁）
SHADOW = np.array([0x29, 0x21, 0x14], float)  # UITheme.SHADOW の色味


def periodic_noise(rng, period, scale_x, scale_y):
	"""period×period で継ぎ目なく繰り返す、方向性のあるノイズ（0..1）。"""
	f = np.fft.fftfreq(period)
	fx, fy = np.meshgrid(f, f)
	amp = np.exp(-((fx / scale_x) ** 2 + (fy / scale_y) ** 2))
	ph = rng.uniform(0, 2 * np.pi, (period, period))
	n = np.real(np.fft.ifft2(amp * np.exp(1j * ph)))
	return (n - n.min()) / (n.max() - n.min())


def paper(rng, period):
	"""和紙の地：ふわっとしたムラ＋曲がった楮（こうぞ）の繊維。繊維は周期の端で折り返して描く。"""
	from PIL import ImageDraw, ImageFilter
	cloud = periodic_noise(rng, period, 0.03, 0.03)
	layer = Image.new("L", (period, period), 0)
	dr = ImageDraw.Draw(layer)
	n_fibers = int(period * period / 220)
	for _ in range(n_fibers):
		x, y = rng.uniform(0, period, 2)
		ang = rng.uniform(0, np.pi)
		length = rng.uniform(8, 34)
		bend = rng.uniform(-0.08, 0.08)
		val = int(rng.uniform(60, 200))
		pts = []
		for i in range(12):
			pts.append((x, y))
			ang += bend
			x += np.cos(ang) * length / 12
			y += np.sin(ang) * length / 12
		for ox in (-period, 0, period):
			for oy in (-period, 0, period):
				dr.line([(px + ox, py + oy) for px, py in pts], fill=val, width=1)
	layer = layer.filter(ImageFilter.GaussianBlur(0.45))
	fib = np.asarray(layer, float) / 255.0
	t = 0.45 * cloud + 0.9 * fib
	return np.clip(t, 0, 1)[..., None]


def rounded_rect_sdf(h, w, x0, y0, x1, y1, r):
	"""角丸長方形までの符号付き距離（内側が負）。"""
	yy, xx = np.mgrid[0:h, 0:w] + 0.5
	cx = np.clip(xx, x0 + r, x1 - r)
	cy = np.clip(yy, y0 + r, y1 - r)
	d = np.hypot(xx - cx, yy - cy) - r
	return d


def build(name, size, pad, corner, shadow_blur, shadow_dy, period, accent=False):
	rng = np.random.default_rng(SEED)
	h = w = size
	x0, y0, x1, y1 = pad, pad, w - pad, h - pad
	# 紙の地は中央（9-slice の中身）の幅で周期をそろえ、タイル張りでも継ぎ目なし。
	p = paper(rng, period)
	p = np.roll(p, (pad + corner, pad + corner), (0, 1))  # 中央の左上から1周期が始まるように
	reps = int(np.ceil(size / period)) + 1
	p = np.tile(p, (reps, reps, 1))[:h, :w]
	rgb = WASHI * (1 - p * 0.6) + FIBER * (p * 0.6)

	d = rounded_rect_sdf(h, w, x0, y0, x1, y1, corner)
	# ちぎった縁（デックル）：縁の位置を細かく揺らす。揺れも縦横で周期的にして角とつなげる。
	wob = periodic_noise(rng, size, 0.35, 0.35) - 0.5
	d = d + wob * 1.6
	inside = np.clip(0.5 - d, 0, 1)
	# 縁ぞいにうっすら濃い帯（紙の厚み）。くっきりした線にはしない。
	rim = np.clip(1 - np.abs(d + 2.0) / 2.5, 0, 1) * 0.55
	rgb = rgb * (1 - rim[..., None]) + EDGE * rim[..., None]
	if accent:
		# 選択中：縁の内側に夏空の青の線（幅 3px）。ちぎった縁の揺れに沿わせ、手で引いた線に見せる。
		line = np.clip(1.6 - np.abs(d + 2.0) / 1.0, 0, 1)
		rgb = rgb * (1 - line[..., None]) + ACCENT_LINE * line[..., None]

	# 落ち影（土の色・ふわっと）。紙の外側だけに出す。
	sd = rounded_rect_sdf(h, w, x0, y0 + shadow_dy, x1, y1 + shadow_dy, corner)
	sh = np.clip(1 - np.maximum(sd, 0) / shadow_blur, 0, 1) ** 2 * 0.22

	a_paper = inside
	a = a_paper + sh * (1 - a_paper)
	col = (rgb * a_paper[..., None] + SHADOW * (sh * (1 - a_paper))[..., None]) / np.maximum(a, 1e-6)[..., None]
	img = np.dstack([np.clip(col, 0, 255), a * 255]).astype(np.uint8)
	Image.fromarray(img, "RGBA").save(f"assets/ui/{name}.png", optimize=True)
	print(name, size, "pad", pad, "corner", corner, "margin", pad + corner)


if __name__ == "__main__":
	# 大きい枠（会話枠・日めくり）：角丸 16、影の余白 12 → 9-slice の余白 28。
	build("washi_panel", 192, 12, 16, 12, 3, 192 - 2 * 28)
	# 小さい札（話者名・操作プロンプト）：角丸 10、影の余白 6 → 余白 16。
	build("washi_tag", 96, 6, 10, 6, 2, 96 - 2 * 16)
	# 選択中の札（選択肢）：小さい札の縁に夏空の青の線を入れたもの。
	build("washi_tag_selected", 96, 6, 10, 6, 2, 96 - 2 * 16, accent=True)
