# Sample

フィルター検証用の WAV ファイルを置くフォルダです。

想定するサンプル:

- `sine_440hz_1s.wav`: 440Hz 正弦波。音量、歪み、位相確認用。
- `impulse_1s.wav`: 先頭 1 サンプルだけのインパルス。エコー、リバーブの遅延位置と減衰確認用。
- `impulse_tail_3s.wav`: 先頭 1 サンプルだけのインパルス + 3 秒無音。リバーブの残響確認用。
- `square_440hz_1s.wav`: 440Hz 矩形波。クリッピングや波形変化確認用。
- `stereo_impulse_lr_1s.wav`: 0.10 秒に左、0.20 秒に右のインパルス。左右チャンネル処理確認用。

共通仕様:

- 44.1kHz
- 16bit PCM
- stereo
- `impulse_tail_3s.wav` 以外は 1 秒

再生成:

```powershell
python .\generate_samples.py
```
