# Sample

フィルター検証用の WAV ファイルを置くフォルダです。

想定するサンプル:

- `sine_440hz_1s.wav`: 440Hz 正弦波。音量、歪み、位相確認用。
- `impulse_1s.wav`: 先頭 1 サンプルだけのインパルス。エコー、リバーブの遅延位置と減衰確認用。
- `impulse_tail_3s.wav`: 先頭 1 サンプルだけのインパルス + 3 秒無音。リバーブの残響確認用。
- `square_440hz_1s.wav`: 440Hz 矩形波。クリッピングや波形変化確認用。
- `stereo_impulse_lr_1s.wav`: 0.10 秒に左、0.20 秒に右のインパルス。左右チャンネル処理確認用。
- `level_steps_3s.wav`: 1 秒ごとに振幅 0.1、0.5、0.9 へ変わる 440Hz 正弦波。コンプレッサー、リミッター確認用。
- `echo_check_3s.wav`: 1 秒以内に短い 880Hz ビープが 3 回鳴り、残り 2 秒は完全無音。Delay の残響確認用。
- `echo_tail_silent_noise_3s.wav`: 先頭 1 秒は 880Hz、残り 2 秒は -90dB 相当の極小ノイズ。エコーやリバーブの尾を残す確認用。

共通仕様:

- 44.1kHz
- 16bit PCM
- stereo
- `impulse_tail_3s.wav`、`level_steps_3s.wav`、`echo_check_3s.wav`、`echo_tail_silent_noise_3s.wav` 以外は 1 秒

再生成:

```powershell
python .\generate_samples.py
```
