# CLAUDE.md

このファイルは、このリポジトリで作業する Claude Code（および他のエージェント）向けの手引きです。
詳しい仕様・遊び方は `README.md`、実装済みの物語内容は `docs/現在の実装シナリオ.md` を参照。

## プロジェクト概要

- **Kazegahukeba（風が吹けば）**：8/31 に世界が終わる「最後の夏」40日間を過ごす、2Dドットの ADV 寄り RPG。
- エンジンは **Godot 4.6 / GDScript**（レンダラ `gl_compatibility`）。メインシーンは `scenes/Title.tscn`。
- 本編は `scenes/FieldScene`（『ぼくのなつやすみ』方式の散策・全9画面）。
  旧UIの `Town`（地図選択）／`Place`（場所内探索）／`Overworld` はコードが残置されているが本線ではない。
- `main` への push で `.github/workflows/deploy-web.yml` が Web(HTML5) に書き出し GitHub Pages へ自動公開する。

## ディレクトリ

```
project.godot   Autoload 登録・メインシーン・フォント設定
autoload/       シーンをまたいで生きるシングルトン（GameState / Nav / Dialogue / SaveData / AudioManager / Fader / Controls / TouchControls）
data/           ゲームデータと判定ロジック（class_name 付き RefCounted。Routes / Story / Endings / Timeline / Nights / *Script など）
scenes/         .tscn と対応する .gd（画面・UI・描画）。HUD / Book / Bag は Autoload として常駐
assets/         フォント・背景PNG（assets/field/）・キャラ画像。音源は assets/audio/ に置けば合成音より優先
docs/           シナリオ文書
.claude/skills/ デザイン系スキル（frontend-design / ui-ux-pro-max など）
```

## 設計の約束（崩さないこと）

- **状態は `GameState` が唯一の持ち主。** 日付（`day_index`）・時間帯（`Phase`）・関係値（`affinity`）・
  フラグ（`flags`）・立場（`stance`）などはここだけが持つ。UI は `day_changed` / `phase_changed` /
  `schedule_changed` / `inventory_changed` などのシグナルを購読して表示し直すだけ。
- **ルートはコードで分岐させず、データで足す。** 三ルート（`kuma` / `yufu` / `aoi`）は `data/Routes.gd` の
  同一データ構造（節目 milestone＝requires × aff_min × since/until × script）で定義し、`data/Story.gd` が共通に解決する。
  進行フラグ名は `{route_id}_{milestone.key}`（`Routes.flag_of()` で導出）。
- **しきい値・時期・日数は定数化して一箇所で調整する**（例：`Routes.AFF_*`、`Timeline` のフェーズ定数、
  `GameState.TOTAL_DAYS`）。マジックナンバーを散らさない。
- **シーン遷移は `Nav` 経由**（内部で `Fader.change_scene`）。直接 `change_scene_to_file` を呼ばない。
- **会話は `Dialogue.start([...])`**、台本データは `data/Dialogues.gd` と各 `*Script.gd`。テキストは仮置き（`〔仮テキスト〕`）可。
- **散策画面はデータ駆動**：画面定義・出口接続は `data/FieldMaps.gd`、歩行領域は `data/Roads.gd`。
  背景PNG（`assets/field/<画面ID>.png`）が無ければ `FieldBackground` がプレースホルダを描く。絵の差し替えでコードを触らない。
- **UIの見た目は `data/UITheme.gd` に集約**（色・不透明度・角丸・フォント）。個別シーンに色を直書きしない。
- **入力は入力アクション経由**（`Controls.gd` で登録：`walk_*` / `interact` / `skip` / `debug_*`）。
  スマホは `TouchControls.gd` が同じアクションを合成するので、新しい操作を足したらタッチUI側にも出す。
  PC・スマホ（タッチ）の両方で操作できる状態を保つ。
- Autoload の登録順には依存関係がある（シグナルを購読する `HUD` / `Book` / `Bag` は `GameState` より後、
  `TouchControls` は `Controls` より後）。追加・並べ替え時は `project.godot` のコメントに従う。

## コーディング規約

- GDScript はタブインデント、型ヒント（`:=`、`-> void` など）を付ける。
- ファイル冒頭と主要な定義に `##` のドキュメントコメントを **日本語で** 書く（既存コードと同じ密度で、「なぜ」を書く）。
- データ層は `class_name Xxx` + `extends RefCounted` の静的データ／関数として書き、Autoload に増やさない。
- `.tscn` を手で編集する場合はノードパス・`ext_resource` の id/uid を壊さないよう最小限に。
- アセット横の `*.import` / `*.uid` はコミットする。`.godot/` と `build/` はコミットしない。

## 動作確認

- この環境には通常 Godot が入っていない。入っていれば次で構文・読み込みエラーを確認できる：
  ```
  godot --headless --path . --import
  godot --headless --path . --quit
  ```
- 入っていない場合は、変更箇所の参照先（関数名・シグナル名・定数名・ノードパス）を grep で突き合わせて確認する。
- ゲーム内デバッグ：F3＝ルート到達状況、F4＝即エンディング判定、F5＝裏エンド強制再生、F6＝散策画面へ、
  F7〜F9＝葵ルート三分岐、F10＝歩行領域オーバーレイ（スマホは左上⚙のメニュー）。
- エンディングを素早く試すときは `GameState.TOTAL_DAYS` を一時的に小さくする（**コミットしない**）。
- セーブは `user://save.cfg`（周回記録・中断データ）。

## バージョン・ビルド

- `project.godot` の `config/features`（`4.6`）と `deploy-web.yml` の `GODOT_VERSION`（`4.6-stable`）は必ず一致させる。
- Web 書き出しは `export_presets.cfg` の **`variant/thread_support=false`** が前提（GitHub Pages は COOP/COEP を付けられないため）。変更しない。

## コミット・ドキュメント

- コミットメッセージは日本語で、何をなぜ直したかを一文で（例：「かばんをスマホから開けるように」）。
- 仕様・操作・ファイル構成を変えたら `README.md` も更新する。物語データを変えたら必要に応じて `docs/現在の実装シナリオ.md` も。
