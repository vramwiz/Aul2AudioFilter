# Aul2AudioFilter 更新履歴

利用者向けの変更履歴です。新機能、操作上の変更、互換性に関する注意、修正された不具合を新しい順に記載します。

## 未リリース（2026-07-19）

### Aul2Audio View

- 音声に反応する映像素材として、次の3D表示を追加しました。
  - `Circular Bars (3D)`
  - `Radial Waveform (3D)`
  - `Spectrum Landscape (3D)`
  - `Waveform Tunnel (3D)`
  - `Spectrum Waterfall (3D)`
  - `Vectorscope Trail (3D)`
- ステレオの広がりと位相傾向を表示する`Vectorscope`を追加しました。
- 中央パンの声でも動きを表現できる`Comms Scope`を追加しました。現在の音声と少し前の音声からXY軌跡を作り、長方形素材でも短辺を基準とした正方形内へ描画します。
- `Comms Scope`は`Density`、`Thickness`、`Smooth`、`X Scale`、`Y Scale`、色、`Source Layer`を調整できます。
- `Vectorscope`と`Comms Scope`はガイド用の十字線を描画しない仕様にしました。必要なガイドは別素材として重ねられます。
- 編集停止中にも`Vectorscope`と`Comms Scope`が表示されるようにしました。
- 3D表示が無音時にも基準リング、最低バー、平面、最後の有音形状を表示し続ける問題を修正しました。現在位置が確定した無音の場合は透明になります。
- 履歴を使う`Spectrum Landscape (3D)`、`Spectrum Waterfall (3D)`、`Waveform Tunnel (3D)`、`Vectorscope Trail (3D)`では、音が終わると過去の形状が履歴順に奥へ進み、手前から順番に消えるようにしました。最後の履歴がなくなった瞬間に全体が急に消える表示も改善しました。
- View Typeは次の15種類になりました。
  - `Equalizer Bars`
  - `Wave Line`
  - `Pixel Wave`
  - `Filled Spectrum`
  - `Pulse Wave`
  - `Circular Spectrum`
  - `Mirror Bars`
  - `Vectorscope`
  - `Comms Scope`
  - `Circular Bars (3D)`
  - `Radial Waveform (3D)`
  - `Spectrum Landscape (3D)`
  - `Waveform Tunnel (3D)`
  - `Spectrum Waterfall (3D)`
  - `Vectorscope Trail (3D)`

> [!IMPORTANT]
> `Comms Scope`を`Vectorscope`の直後へ追加したため、3D表示のType番号が従来より1つ後ろへ変わりました。既存プロジェクトで3D表示が別の種類になった場合は、Typeを選び直してください。

### Aul2AudioController

- Controllerを配布パッケージへ追加しました。AviUtl2の`表示`メニューから開き、サウンドエフェクターの全20エフェクトを専用画面で操作できます。
- 各エフェクトへ、現在の設定や音声処理の傾向を確認する補助表示を追加しました。
  - `Delay`：原音、遅延音、フィードバックの関係
  - `EQ`：Low Cut、High Cut、Band Passの周波数特性
  - `Compressor`、`Limiter`、`NoiseGate`、`Distortion`：入出力特性
  - `BitCrusher`：量子化段階と表示中の段数
  - `Pitch`、`Muffle`、`RingMod`：周波数変化
  - `Noise`、`Whisper/Breath`、`VoiceDrive`：処理前後の波形またはXY表示
  - `Tremble`、`Wobble`、`Chorus`：変調カーブと現在位置
  - `Reverb`、`ReverseReverb/Ghost`：残響の広がり
  - `AutoGain`、`Output`：現在の音量や補正状態
- 補助表示に必要な解析は、対象エフェクトをControllerへ表示している間だけ行うようにし、通常再生時の負荷を抑えました。
- エフェクターごとの基本色を見直し、黒に近い配色を避けました。パネル上の文字は背景に応じて白または黒を使い、視認性を改善しました。
- プリセット管理画面の入力欄、一覧、登録・削除ボタンの高さを調整し、DPIが異なる環境でのずれを改善しました。
- View配置画面の`Send`をボタンへ変更し、ほかの操作ボタンと高さを揃えました。

### Aul2AudioMonitor

- 再生開始直後からViewの表示位置へ同期し、再生中に表示が先行または停止する問題を修正しました。
- 音声素材の終端後にInputとOutputが保持されたままにならず、自然に減衰するよう修正しました。
- Monitorは`Wave`と`Spectrum`の監視に集中し、View配置とユーザープリセット管理はControllerへ移動しました。

## v1.0.3（2026-07-15）

### 追加

- ユーザープリセットの登録、名前変更、並べ替え、削除、タイムラインへのドラッグ＆ドロップに対応しました。
- `Aul2Audio View`用の表示オブジェクトを配置できる画面を追加しました。

### 改善・修正

- MonitorとViewの表示タイミングを調整しました。
- プリセット管理とView配置画面のレイアウトおよびDPI対応を改善しました。
- 保存したユーザープリセットが一覧へ表示されないことがある問題を修正しました。

## v1.0.2（2026-07-12）

### 改善・修正

- 隣接する音声クリップへDelayの残響が自然に引き継がれるようにしました。
- 複数回繰り返す残響が途中で切れにくいよう改善しました。
- Monitorの表示更新と減衰を改善しました。
- 音声停止後も表示値が残ることがある問題を修正しました。

## v1.0.1（2026-07-11）

### 改善・修正

- 再生中のMonitorと`Aul2Audio View`の同期ずれを修正しました。
- 編集中の無音値によってMonitor表示が不意に上書きされる問題を修正しました。
- Monitorのツールバーを調整しました。

## v1.0.0（2026-07-10）

### Aul2Audio View

- 音声に反応する映像素材を作る`Aul2Audio View`を追加しました。
- バー、スペクトラム、時間波形、円形表示など複数のView Typeを追加しました。
- `Solid`と`Blocks`の表示スタイルに対応しました。
- 表示密度、間隔、太さ、滑らかさ、倍率、周波数範囲を調整できるようにしました。
- 1色、2色、3色および複数のカラーバリエーションに対応しました。
- `Source Layer`で解析元の音声レイヤーを指定できるようにしました。

### 改善・修正

- 複数の音声オブジェクトや複数のサウンドエフェクターを配置した場合の処理を改善しました。
- MonitorとViewを再生位置へ同期するようにしました。
- Monitorが音声より先に進んで見える問題を軽減しました。
- Viewが一時的に表示されなくなる問題と、終了時にエラーが発生する問題を修正しました。
- 高DPI環境での表示を改善しました。

## v0.0.3（2026-07-09）

### 追加

- `Aul2AudioMonitor`を追加しました。
- Input／Outputのピークメーター、クリップ目安、Wave表示、Spectrum表示を追加しました。
- 左右チャンネルの状態を確認できる表示を追加しました。

### 改善

- Wave表示を滑らかにし、点滅を抑えました。

## v0.0.2（2026-07-07）

- プラグインのアイコンを追加しました。
- 配布フォルダーと説明書を整理しました。

## v0.0.1（2026-07-07）

- AviUtl ExEdit2用の音声フィルタープラグインとして初版を公開しました。
- Delay、EQ、Compressor、VoiceDrive、Distortion、Noise、BitCrusher、Tremble、Wobble、Pitch、RingMod、Muffle、Whisper/Breath、AutoGain、NoiseGate、ReverseReverb/Ghost、Chorus、Reverb、Output、Limiterを搭載しました。
- エコー、反響、ホール、空間、ナレーション、電話、無線、拡声器、劣化、男性、女性、ロボ、恐怖、叫び、水中、壁越し、夢／回想のプリセットを追加しました。
- 音声フィルターを継続動作させるための無音音声素材を配布へ追加しました。
