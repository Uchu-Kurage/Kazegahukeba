# 散策画面の背景（差し替え用）

FieldScene（第6弾）の背景PNGを置く場所です。

- ファイル名は画面ID（`data/FieldMaps.gd` の `id`）に対応：例 `riverbank.png`（河原と土手）。
- パスは `FieldMaps.gd` の各画面 `bg`（例：`res://assets/field/riverbank.png`）。
- **PNGが無ければ**、`FieldBackground` がコード描画のプレースホルダを自動表示します（絵が未着でも動く）。
- 差し替えの約束：**同じ画面ID・同じ表示サイズ（1152×648にフィット）・同じ道の位置**で入れ替えれば、
  コードを触らず絵だけ差し替えられます（当たり判定＝道は `FieldMaps.roads` 側で持っているため）。
- いまは仮：Nano Banana Pro 出力の 16:9 PNG をそのまま置いてOK。後日 320×180 のドット絵へ。

## 途中の道（road_a〜road_d）

- `road_a.png`〜`road_d.png` は、LPC のタイル素材（ElizaWy/LPC「LPC Revised」夏の地形）を
  `tools/gen_road_tiles.py` で組み立てた見下ろしの絵（素材は `tools/lpc_terrain/` に同梱）。
- 土の道は `FieldMaps` の歩ける帯（`ROAD_H` / `ROAD_V`）に合わせてある。帯を変えたらスクリプトも直して作り直す。
- 見下ろしなので、キャラはタイルと同じ縮尺で描く（`FieldMaps.TILE_ROAD_DEPTH`）。
- 出典・作者は `CREDITS.md`。

## 家＝自室（home）

- `home.png`（昼）／`home_night.png`（夜）は、LPC の室内素材を `tools/gen_room.py` で組み立てた見下ろしの一部屋
  （素材は `tools/lpc_interior/` に同梱）。夜は `<画面ID>_night.png` があれば自動でそちらを使う。
- 歩ける床（`FieldMaps` の home の `roads_override`）と調べどころ（`FieldMaps.HOME_*_POS`）は家具の配置に合わせてある。
  配置を変えたら両方そろえて直す。
- 以前の家の外観は `home_front.png`（オープニングの夢「家の前」でだけ使う）。
