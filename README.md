# Aul2AudioFilter

AviUtl ExEdit2 用の音声フィルタープラグインです。

プラグイン上の表示名は「サウンドエフェクター」です。エコー、リバーブ、コーラスなどの音声エフェクトを追加していくための土台として開発します。

## 現在の機能

- `Delay: Use`: ディレイの使用切り替え
- `Delay: Stereo Mode`: ディレイのステレオ処理
- `Delay: Time(ms)`: ディレイ時間
- `Delay: Dry`: 元音の出力量
- `Delay: Wet`: 遅延音の出力量
- `Delay: Feedback`: 遅延音をディレイへ戻す量
- `EQ: Use`: EQ の使用切り替え
- `EQ: Mode`: EQ の処理種類
- `EQ: LowCut(Hz)`: 低域を削り始める周波数
- `EQ: HighCut(Hz)`: 高域を削り始める周波数
- `EQ: Mix`: 元音と EQ 処理音の混合量
- `Compressor: Use`: コンプレッサーの使用切り替え
- `Compressor: Threshold(dB)`: 音量を抑え始める基準
- `Compressor: Ratio`: 基準を超えた音を抑える強さ
- `Compressor: Attack(ms)`: 大きい音に反応する速さ
- `Compressor: Release(ms)`: 抑えた音量を戻す速さ
- `Compressor: Makeup(dB)`: 処理後の音量補正
- `Compressor: Mix`: 元音とコンプレッサー処理音の混合量
- `Distortion: Use`: 歪みの使用切り替え
- `Distortion: Mode`: 歪みの種類
- `Distortion: Drive(dB)`: 歪ませる強さ
- `Distortion: Tone`: 歪み音の強さ
- `Distortion: Level(dB)`: 処理後の音量補正
- `Distortion: Mix`: 元音と歪み音の混合量
- `Noise: Use`: ノイズの使用切り替え
- `Noise: Mode`: ノイズの種類
- `Noise: Level(dB)`: 追加するノイズの音量
- `Noise: Mix`: ノイズの混合量
- `BitCrusher: Use`: ビットクラッシャーの使用切り替え
- `BitCrusher: BitDepth`: 音量の段階数を粗くする強さ
- `BitCrusher: SampleHold`: サンプル値を保持する長さ
- `BitCrusher: Mix`: 元音とビットクラッシャー処理音の混合量
- `Limiter: Use`: リミッターの使用切り替え
- `Limiter: Ceiling(dB)`: 出力ピークの上限
- `Limiter: Release(ms)`: 抑えたゲインを戻す速さ
- `Limiter: Mix`: 元音とリミッター処理音の混合量
- `Chorus: Use`: コーラスの使用切り替え
- `Chorus: Stereo Mode`: コーラスのステレオ処理
- `Chorus: Delay(ms)`: コーラスの基準ディレイ時間
- `Chorus: Depth(ms)`: コーラスの揺れ幅
- `Chorus: Rate(Hz)`: コーラスの揺れ速度
- `Chorus: Mix`: 元音とコーラス音の混合量
- `Reverb: Use`: リバーブの使用切り替え
- `Reverb: RoomSize`: 残響の長さ
- `Reverb: Damping`: 残響の高域減衰
- `Reverb: Dry`: 元音の出力量
- `Reverb: Wet`: 残響音の出力量

`Delay: Feedback` を `0.0` にすると単発ディレイ、値を上げるとエコーとして動作します。
`Delay: Stereo Mode` は `Normal` と `Ping-Pong` を選択できます。
`Delay: Use` を OFF にすると、Delay の内部バッファをクリアします。
`EQ` は音の低域や高域を削るための簡易 EQ です。`Low Cut`、`High Cut`、`Band Pass` を選択できます。
`Compressor` は大きい音を抑えて音量差を整えるためのエフェクトです。ナレーションやアナウンスを聞きやすくする用途に使います。
`Distortion` は音を軽く歪ませ、電話、無線、メガホン、古い放送のような質感を作るためのエフェクトです。
`Noise` は無線、古い録音、監視カメラ風などのざらついた質感を足すためのエフェクトです。
`BitCrusher` は音の解像度や時間方向の細かさを粗くして、低音質通話、古い機械音声、ゲーム風の質感を作るためのエフェクトです。
`Limiter` は出力ピークの上限を決め、音割れを防ぐためのエフェクトです。
`Chorus` は短いディレイ時間を LFO で揺らす簡易コーラスです。
`Chorus: Stereo Mode` は `Normal` と `Wide` を選択できます。`Wide` は右チャンネルの LFO 位相を 180 度ずらします。

パラメーター名は、AviUtl2 上で他エフェクトの項目と区別しやすいよう英語表記にしています。

## 配置

- `Aul2AudioFilter.dpr` / `Aul2AudioFilter.dproj`: Delphi プロジェクト本体
- `Aul2AudioFilterPlugin.pas`: プラグイン入口、各エフェクトユニットの接続
- `Aul2AudioFilterPluginDelay.pas`: Delay / Echo 系の GUI 項目、状態、音声処理
- `Aul2AudioFilterPluginEq.pas`: EQ 系の GUI 項目、状態、音声処理
- `Aul2AudioFilterPluginCompressor.pas`: Compressor 系の GUI 項目、状態、音声処理
- `Aul2AudioFilterPluginDistortion.pas`: Distortion 系の GUI 項目、音声処理
- `Aul2AudioFilterPluginNoise.pas`: Noise 系の GUI 項目、状態、音声処理
- `Aul2AudioFilterPluginBitCrusher.pas`: BitCrusher 系の GUI 項目、状態、音声処理
- `Aul2AudioFilterPluginLimiter.pas`: Limiter 系の GUI 項目、状態、音声処理
- `Aul2AudioFilterPluginChorus.pas`: Chorus 系の GUI 項目、状態、音声処理
- `Aul2AudioFilterPluginReverb.pas`: Reverb 系の GUI 項目、状態、音声処理
- `Lib`: 共通ライブラリ
- `Sample`: 動作確認用 WAV ファイル
- `Win64`: Debug / Release の中間出力

## 出力

ビルド後、AviUtl2 のプラグインフォルダへ `.auf2` として出力します。

```text
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2
```

開発ルールやビルド方法は [note.md](note.md) を参照してください。

## グループへの適用

複数の音声素材へまとめて効果をかけたい場合は、AviUtl2 の「グループ制御（音声）」を使います。
通常の「グループ制御」ではなく、「グループ制御（音声）」にサウンドエフェクターを追加してください。

## EQ

- `EQ: Use`: EQ の使用切り替え
- `EQ: Mode`: `Low Cut`、`High Cut`、`Band Pass` から選択
- `EQ: LowCut(Hz)`: `Low Cut` と `Band Pass` で使う低域カット周波数
- `EQ: HighCut(Hz)`: `High Cut` と `Band Pass` で使う高域カット周波数
- `EQ: Mix`: 元音と EQ 処理音の混合量

`EQ` は電話風、無線風、壁越し、アナウンス風などの効果を作るための基礎になる音質調整です。
初期状態では `EQ: Use` は OFF です。

## Compressor

- `Compressor: Use`: コンプレッサーの使用切り替え
- `Compressor: Threshold(dB)`: 音量を抑え始める基準
- `Compressor: Ratio`: 基準を超えた音を抑える強さ
- `Compressor: Attack(ms)`: 大きい音に反応する速さ
- `Compressor: Release(ms)`: 抑えた音量を戻す速さ
- `Compressor: Makeup(dB)`: 処理後の音量補正
- `Compressor: Mix`: 元音とコンプレッサー処理音の混合量

`Compressor` は小さい声と大きい声の差を整え、ナレーションやアナウンスを聞きやすくするための基礎になる音量補正です。
初期状態では `Compressor: Use` は OFF です。

## Distortion

- `Distortion: Use`: 歪みの使用切り替え
- `Distortion: Mode`: `Soft Clip`、`Hard Clip` から選択
- `Distortion: Drive(dB)`: 歪ませる強さ
- `Distortion: Tone`: 歪み音の強さ
- `Distortion: Level(dB)`: 処理後の音量補正
- `Distortion: Mix`: 元音と歪み音の混合量

`Distortion` は音を軽く荒らして、電話、無線、メガホン、古い放送のような質感を作るためのエフェクトです。
初期状態では `Distortion: Use` は OFF です。

## Noise

- `Noise: Use`: ノイズの使用切り替え
- `Noise: Mode`: `White`、`Crackle` から選択
- `Noise: Level(dB)`: 追加するノイズの音量
- `Noise: Mix`: ノイズの混合量

`Noise` は無線、古い録音、監視カメラ風などのざらついた質感を足すためのエフェクトです。
初期状態では `Noise: Use` は OFF です。

## BitCrusher

- `BitCrusher: Use`: ビットクラッシャーの使用切り替え
- `BitCrusher: BitDepth`: 音量の段階数を粗くする強さ
- `BitCrusher: SampleHold`: サンプル値を保持する長さ
- `BitCrusher: Mix`: 元音とビットクラッシャー処理音の混合量

`BitCrusher` は音の解像度や時間方向の細かさを粗くして、低音質通話、古い機械音声、ゲーム風の質感を作るためのエフェクトです。
初期状態では `BitCrusher: Use` は OFF です。

## Limiter

- `Limiter: Use`: リミッターの使用切り替え
- `Limiter: Ceiling(dB)`: 出力ピークの上限
- `Limiter: Release(ms)`: 抑えたゲインを戻す速さ
- `Limiter: Mix`: 元音とリミッター処理音の混合量

`Limiter` は大きすぎる瞬間的な音を上限以下に抑え、音割れを防ぐための仕上げ用エフェクトです。
初期状態では `Limiter: Use` は OFF です。

## Reverb

- `Reverb: Use`: リバーブの使用切り替え
- `Reverb: RoomSize`: 残響の長さ
- `Reverb: Damping`: 残響の高域減衰
- `Reverb: Dry`: 元音の出力量
- `Reverb: Wet`: 残響音の出力量

`Reverb` は複数の短いフィードバック遅延を使う簡易リバーブです。初期状態では `Reverb: Use` は OFF です。
`RoomSize`、`Damping`、`Dry/Wet`、`Use` OFF 時の動作確認まで完了しています。
