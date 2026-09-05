# 散策画面の背景（差し替え用）

FieldScene（第6弾）の背景PNGを置く場所です。

- ファイル名は画面ID（`data/FieldMaps.gd` の `id`）に対応：例 `riverbank.png`（河原と土手）。
- パスは `FieldMaps.gd` の各画面 `bg`（例：`res://assets/field/riverbank.png`）。
- **PNGが無ければ**、`FieldBackground` がコード描画のプレースホルダを自動表示します（絵が未着でも動く）。
- 差し替えの約束：**同じ画面ID・同じ表示サイズ（1152×648にフィット）・同じ道の位置**で入れ替えれば、
  コードを触らず絵だけ差し替えられます（当たり判定＝道は `FieldMaps.roads` 側で持っているため）。
- いまは仮：Nano Banana Pro 出力の 16:9 PNG をそのまま置いてOK。後日 320×180 のドット絵へ。
