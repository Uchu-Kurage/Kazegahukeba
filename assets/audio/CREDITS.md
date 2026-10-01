# 音源のクレジット

`assets/audio/` に置いたファイルは `AudioManager` が合成音より優先して鳴らします
（無いものは従来どおりコード合成）。外部素材を足したらここに出典とライセンスを書くこと。

| ファイル | 用途 | 出典 | ライセンス | 加工 |
| --- | --- | --- | --- | --- |
| `step_gravel.wav` | 足音（河原・河口＝砂利） | Kenney「Starter Kit FPS」`sounds/walking.ogg`（[KenneyNL/Starter-Kit-FPS](https://github.com/KenneyNL/Starter-Kit-FPS) @185fd23） | MIT（© Kenney） | 一歩分を切り出し、22.05kHz モノラル・ピーク -10dBFS に正規化 |
| `step_dirt.wav` | 足音（畦道・土の道） | 同上 | MIT（© Kenney） | 別の一歩を切り出し、2.5kHz ローパスで土っぽく丸めて正規化 |
| `step_stone.wav` | 足音（商店街・参道・学校＝石畳・舗装） | 同上 | MIT（© Kenney） | 別の一歩を切り出し、500Hz ハイパスで硬めにして正規化 |
| `step_grass.wav` | 足音（丘・畑・田＝草地） | Kenney「Starter Kit 3D Platformer」`sounds/walking.ogg`（[KenneyNL/Starter-Kit-3D-Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) @3fa8a04） | CC0（同リポジトリ README で効果音は CC0 と明記） | 一歩分を切り出して正規化 |

`step_wood.wav`（家＝板の間）は合う素材が無かったので、合成音のまま。

## MIT License（Starter Kit FPS 由来の音源）

Copyright (c) 2025 Kenney

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
