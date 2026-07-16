# Aul2AudioFilter note

作業再開時に最初に見る開発メモ。ここには現在の方針、開発方法、コメントルール、ビルド方法を置く。

- 利用者向けの概要、配置、配布説明は `README.md` へ置く。
- 検証用 WAV の説明は `Sample\README.md` へ置く。
- 完了済みの開発記録、検証ログ、試行錯誤、日付付きの作業履歴は `HISTORY.md` へ書く。

## 現在の方針

- 主要機能は完成しており、通常利用できる状態。現在、既知の必須課題はない。
- 新しいエフェクト、プリセット、View Type、音質表現の追加は現在の課題に含めない。明確な要望が出た場合に改めて検討する。
- 内部プロジェクト名は `Aul2AudioFilter`。
- AviUtl2 上の表示名は「サウンドエフェクター」。
- Syncroh2 とは別プロジェクトとして、`D:\DelphiProg\test\Syncroh2` と同層の `D:\DelphiProg\test\Aul2AudioFilter` で開発する。
- Syncroh2 のフィルター系ビルド設定、`.dll` から `.auf2` へのコピー方式、GUI 項目登録方式を参考にする。
- 音声フィルターの検証は WAV を基本にする。MP3 は当面使わない。
- AviUtl2 上のパラメーター名は英語表記にする。日本語表示名はプラグイン名や説明に留める。
- 例外として、最上段の用途別入口は `プリセット` という日本語 GUI 項目にする。
- `プリセット` は直接音声処理をせず、詳細エフェクトの初期値を設定する入口として扱う。
- グループ分けしても項目名が後続エフェクトと紛らわしくなる可能性があるため、効果固有の項目は `Delay: Wet` のように効果名を prefix する。
- 複数音声素材へまとめて適用する場合は、AviUtl2 の通常の「グループ制御」ではなく「グループ制御（音声）」を使う。
- 本プラグインは音楽制作向けではなく、声、セリフ、効果音素材に用途が伝わる加工をすばやくかける道具として設計する。
- `Aul2Audio View` は `Source Layer` を最上段に置き、`Auto` または表示レイヤー `Layer 1`..`Layer 64` から解析元を選ぶ。
- 立体構造を持つ新しい View Type のデータ構成と AviUtl2 への受け渡し方法は [`AviUtl2_3Dデータ受け渡し設計.md`](AviUtl2_3Dデータ受け渡し設計.md) を参照する。
- `Aul2Audio View` の `X Scale` / `Y Scale` / `Z Scale` は描画座標または表示反応だけを倍率調整する。`100` が基準、範囲は `10..500` で、音声処理や解析値には影響させない。`Z Scale` は3D Typeだけで使う。
- 共有メモリ上は内部 0-based レイヤー別スロットで保持し、GUI と Monitor 表示では AviUtl2 の表示レイヤーに合わせて 1-based で扱う。
- `Source Layer = Auto` は最後に更新されたレイヤーを表示し、レイヤー指定時はその表示レイヤー由来の波形/スペクトラムだけを読む。
- エフェクトの GUI 並びは、プリセットを除き、実際に音声へ処理される順番へ揃える。利用者が上から順に音が変わると理解できる状態を保つ。
- 最終段の `Output: Gain(dB)` で出力音量を調整し、その後段の Limiter でピークを保護する。
- `AutoGain` は独立した任意エフェクトとして扱い、必要な場合だけ有効にする。

## 検証状況

- 主要機能の実装と基本検証は完了済み。同期の微調整を除き、既知の必須課題はない。
- プラグインテストは正常。
- `GetSampleData` で音声サンプルを受け取り、加工して `SetSampleData` で戻す基本経路は正常。
- Delay / Ping-Pong / Chorus / Reverb / EQ / Compressor / Limiter / Distortion / Noise / BitCrusher などの基本動作は検証済み。
- 追加プリセットは `夢/回想` まで一通り試聴済み。
- `無線` と `劣化` は `Noise` 使用時に無音化や AviUtl2 側の例外が出る可能性があったため、プリセットからは `Noise` を外している。
- `FilterProcAudio` 全体は `try..except` で保護し、音声処理中の Delphi 例外が AviUtl2 まで漏れないようにしている。
- 詳細な実装記録、検証ログ、プリセット試聴メモは `HISTORY.md` を参照する。
- `Aul2Audio View` の `Vectorscope`、短辺基準の正方形描画、`X Scale` / `Y Scale` は実機確認済み。表示負荷も実用上問題ない。

## プロジェクト構成

- `Aul2AudioFilter.dpr`: AviUtl2 へ `GetFilterPluginTable` などを export する入口。各ユニットは `Source\...` の相対パスで参照する。
- `Aul2AudioFilter.dproj`: Delphi Win64 Debug / Release ビルド設定。
- `Aul2AudioMonitor.dpr`: AviUtl2 へ `RegisterPlugin` などを export する拡張プラグイン入口。波形表示 UI 用の受け皿。
- `Aul2AudioMonitor.dproj`: 拡張プラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Aul2AudioController.dpr`: AviUtl2 へ `RegisterPlugin` などを export する設定補助拡張プラグイン入口。
- `Aul2AudioController.dproj`: Controller の Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Aul2AudioBaseInput.dpr`: AviUtl2 入力プラグイン入口。`.aul2base` 仮想ファイルを空の動画素材として開く。
- `Aul2AudioBaseInput.dproj`: 入力プラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Aul2AudioView.dpr`: `Aul2AudioBaseInput` の上に載せる MV 用表示フィルタープラグイン入口。
- `Aul2AudioView.dproj`: 表示用フィルタープラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Source\Aul2AudioMonitorPlugin.pas`: `Aul2AudioMonitor` の拡張メニュー登録、AviUtl2 クライアントウィンドウ登録、フォーム表示管理。
- `Source\Aul2AudioControllerPlugin.pas`: `Aul2AudioController` の拡張メニュー登録、AviUtl2 クライアントウィンドウ登録、マウス進入時の同期発火とフォーム表示管理。
- `Source\Aul2AudioControllerEffectDefinition.pas`: 全20エフェクターの名前、日本語LED表記、配色、選択項目、ノブ範囲、Alias項目名を一元管理する。
- `Source\Aul2AudioControllerSync.pas`: 選択中Objectのエイリアス取得、対象フィルター探索、選択中エフェクターの定義に基づく読み込みと項目単位の書き込みを担当する。
- `Source\Aul2AudioControllerView.pas`: Controller のVCLフォーム、エフェクター切り替え、パラメーター操作、View配置、ユーザープリセット管理の画面切り替えを担当する。
- `Source\Aul2AudioControllerLampSwitch.pas`: エフェクターON/OFF用のギターエフェクター風LEDスイッチ。発光表示、全面クリック、キーボード操作を担当する。
- `Source\Aul2AudioControllerVolumeControl.pas`: 連続数値パラメーター用の音響機器風ノブ、値欄、縦横ドラッグ、ホイール、直接入力を担当する。
- `Source\Aul2AudioBasePanel.pas`: Controllerの `波形表示オブジェクトの配置` UI。解像度設定、レイヤーリスト、選択レイヤー生成ボタン、D&Dエイリアス生成を担当する。Monitor用の横配置も復活可能な形で残す。
- `Source\Aul2AudioPresetPanel.pas`: Controllerの `エフェクトプリセットの管理` UI。選択Objectのプリセット登録、一覧の名前編集、グループ制御（音声）のD&D生成を担当する。Monitor用の横配置も復活可能な形で残す。
- `Source\Aul2AudioPresetModel.pas`: ユーザープリセットとエイリアス要素のRTTIモデル、二重セクションINIの保存と読み込みを担当する。
- `Source\Aul2AudioBaseAlias.pas`: `.aul2base` 仮想ファイル名と AviUtl2 エイリアス文字列/一時 `.object` ファイル生成。
- `Source\Aul2AudioBaseCreate.pas`: `CreateObjectFromAlias` による選択レイヤーへの直接配置。
- `Source\Aul2AudioBaseInputPlugin.pas`: `.aul2base` 入力プラグイン本体。ファイル名内の `Width_Height_MaxSec_Rate_Scale` から動画情報を作る。
- `Source\Aul2AudioViewPlugin.pas`: `Aul2AudioView` のフィルターテーブル登録。表示名は `Aul2Audio View`、グループは `Video Effects`。View 用の各 GUI パラメーターを登録し、最上段に解析元を選ぶ `Source Layer` を置く。
- `Source\Aul2AudioViewRender.pas`: `Aul2AudioView` の映像描画と AviUtl2 への出力を担当する。表示タイプごとの描画ユニットへ振り分ける。
- `Source\Aul2AudioViewRenderEqualizer.pas`: `Equalizer Bars` 表示タイプの描画を担当する。
- `Source\Aul2AudioViewRenderFilledSpectrum.pas`: `Filled Spectrum` 表示タイプの描画を担当する。
- `Source\Aul2AudioViewRenderWaveLine.pas`: `Wave Line` 表示タイプの描画を担当する。
- `Source\Aul2AudioViewRenderPixelWave.pas`: `Pixel Wave` 表示タイプの描画を担当する。
- `Source\Aul2AudioViewRenderPulseWave.pas`: `Pulse Wave` 表示タイプの描画を担当する。
- `Source\Aul2AudioViewRenderRadialWaveform3D.pas`: `Radial Waveform (3D)` の円周波形メッシュ生成、編集時波形保持、3D直接描画を担当する。
- `Source\Aul2AudioViewRenderSpectrumLandscape3D.pas`: `Spectrum Landscape (3D)` のスペクトラム履歴地形メッシュ生成、編集時地形保持、3D直接描画を担当する。
- `Source\Aul2AudioViewRenderWaveformTunnel3D.pas`: `Waveform Tunnel (3D)` の波形履歴取得、流動履歴、円形断面トンネルメッシュ生成、編集時形状保持、3D直接描画を担当する。
- `Source\Aul2AudioViewRenderVectorscope.pas`: `Vectorscope` の短辺基準座標、L/R変換、点列描画を担当する。
- `Source\Aul2AudioViewRenderUtils.pas`: ピクセルクリア、矩形塗り、View 用色取得など、表示タイプ間で共有する小さな描画補助。
- `Source\Aul2AudioViewSpectrum.pas`: `Local\Aul2AudioMonitorSpectrum` の読み取りとスムージングを担当する。スペクトラム系表示タイプで共有する。
- `Source\Aul2AudioViewWave.pas`: `Local\Aul2AudioMonitorState` の時間波形読み取りを担当する。時間波形系表示タイプで共有する。
- `Source\Aul2AudioViewVector.pas`: `Local\Aul2AudioViewVector` の履歴から現在フレームとレイヤーに対応するL/R代表点を選ぶ。
- `Source\Lib\Color\Aul2ColorUtils.pas`: Syncroh2 の PianoRoll 色処理を参考に切り出した、RGB/HSV 変換と RGB / HSV短方向 / HSV長方向の補間ライブラリ。
- `Source\Lib\Color\Aul2ColorPalette.pas`: View の色バリエーション候補をまとめたパレットライブラリ。`Color Variation` と `Color Blend` から利用する。
- `Source\Lib\AviUtl2GpuTextureOut.pas`: Syncroh2 の PSDDraw と同じ考え方の任意 GPU texture 出力ヘルパー。初期状態では無効化し、通常は `SetImageData` で出力する。
- `Source\Aul2AudioFilterPlugin.pas`: AviUtl2 へ公開するフィルター入口、各エフェクトユニットの接続。
- `Source\Aul2AudioFilterMonitorBridge.pas`: フィルター側から共有メモリへ入力/出力ピークなどの軽量解析値を書き出す入口。対象音声オブジェクトの内部レイヤー別スロットへ書き込む。
- `Source\Aul2AudioFilterPluginPreset.pas`: `プリセット` GUI 項目、詳細エフェクト設定への反映処理。
- `Source\Aul2AudioFilterPluginDelay.pas`: Delay / Echo 系の GUI 項目、状態管理、音声処理。
- `Source\Aul2AudioFilterPluginChorus.pas`: Chorus 系の GUI 項目、状態管理、音声処理。
- `Source\Lib\Aul2AudioFilterTypes.pas`: AviUtl2 フィルター SDK の Delphi 型定義。
- `Source\Lib\Aul2AudioFilterGui.pas`: `SetupPluginTable` / `AddGroup` / `AddTrack` などの GUI 項目登録ライブラリ。
- `Source\Lib\AviUtl2Plugin`: Syncroh2 から UTF-8 でコピーした AviUtl2 汎用プラグイン SDK 型定義と共有状態。
- `Source\Lib\AviUtl2Input`: AviUtl2 入力プラグイン SDK 型定義。
- `Source\Lib\DragAgent`: Syncroh2 からコピーした D&D 送信用ライブラリ。Base ページのレイヤーリスト D&D に使う。Delphi 37.0 向けに uses の名前空間を調整済み。
- `Source\Lib\ListBoxEdit`: Syncroh2からコピーしたインライン編集対応ListBox。Preset一覧のダブルクリック名前編集に使う。
- `Source\Lib\PresetSupport\Serialization\Section`: ユーザープリセットINIの二重セクション管理に使う。
- `Source\Lib\SharedMemory`: Syncroh2 から UTF-8 でコピーした共有メモリ基礎ライブラリ。
- `Source\Lib\AudioMonitor`: Filter、Monitor、Viewで共有する表示用構造体。Vectorscope専用の小型共有履歴もここへ置く。
- `Source\Legacy`: 現在のビルドでは使わない旧コピーの退避場所。
- `Sample`: 正弦波、矩形波、インパルスなどの検証用 WAV を置く。
- `Win64`: Delphi の Debug / Release 中間出力。

## 検証サンプル

- エフェクター確認用の入力 WAV は `Sample` に置く。
- AviUtl2 からテスト出力した WAV は原則として `Sample\test_out.wav` に出力する。
- `Sample\test_out.wav` は検証ごとに上書きされる作業用ファイルとして扱う。
- サンプル WAV の利用者向け説明は `Sample\README.md` に置く。
- 再開時に必要な検証上の細かい仕様や不足サンプルの課題は `note.md` に置く。完了済みの検証ログは `HISTORY.md` へ移す。

既存サンプル:

- `sine_440hz_1s.wav`: 440Hz 正弦波。44.1kHz / stereo / 16bit PCM / 1 秒。振幅は 0.5。音量、位相、コーラス、EQ、歪みの基本確認に使う。
- `square_440hz_1s.wav`: 440Hz 矩形波。44.1kHz / stereo / 16bit PCM / 1 秒。振幅は 0.5。クリッピング、歪み、フィルターによる角の丸まり確認に使う。
- `impulse_1s.wav`: 先頭 1 サンプルだけ L/R とも 1.0 のインパルス。44.1kHz / stereo / 16bit PCM / 1 秒。Delay や Reverb の遅延位置、減衰確認に使う。
- `impulse_tail_3s.wav`: 先頭 1 サンプルだけ L/R とも 1.0 のインパルス + 3 秒無音。44.1kHz / stereo / 16bit PCM / 3 秒。Reverb の残響テール確認に使う。
- `stereo_impulse_lr_1s.wav`: 0.10 秒に左だけ 1.0、0.20 秒に右だけ 1.0 のインパルス。44.1kHz / stereo / 16bit PCM / 1 秒。左右チャンネル処理、Ping-Pong、Stereo Mode 確認に使う。
- `level_steps_3s.wav`: 1 秒ごとに振幅 0.1、0.5、0.9 へ変わる 440Hz 正弦波。44.1kHz / stereo / 16bit PCM / 3 秒。Compressor / Limiter の確認に使う。

不足したら追加してよいサンプル候補:

- `voice_like_1s.wav`: 声に近い複合波形。Telephone、Radio、Megaphone、Announcement、Narration Clear の確認用。
- `low_high_mix_1s.wav`: 低域と高域を混ぜた波形。Low Cut / High Cut / Band Pass の効き確認用。
- `noise_floor_3s.wav`: 小さいノイズを含む素材。Noise 追加やノイズ混入時の聞こえ方確認用。

## ユニット分割方針

- `Aul2AudioFilterPlugin.pas` は肥大化させず、AviUtl2 入口と各エフェクトユニットの呼び出しだけを担当する。
- エフェクト固有の GUI 項目、状態バッファ、処理関数は `Aul2AudioFilterPluginXxx.pas` へ分ける。
- 新しいエフェクトを追加する場合は、原則として `Aul2AudioFilterPluginXxx.pas` を追加し、`AddXxxItems` と `ProcessXxx` を公開する。
- エフェクト処理順は `Aul2AudioFilterPlugin.pas` の `FilterProcAudio` で管理する。
- GUI 登録順は `GetFilterTable` 内の `AddXxxItems` 呼び出し順で管理し、原則として `FilterProcAudio` の `ProcessXxx` 呼び出し順と一致させる。

## ビルド方法

Debug Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\Aul2AudioFilter\Aul2AudioFilter.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Release Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\Aul2AudioFilter\Aul2AudioFilter.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

出力先:

```text
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioMonitor.aux2
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioController.aux2
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioBaseInput.aui2
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioView.auf2
```

ビルド後イベントで生成された `.dll` を `.auf2` にコピーし、元の `.dll` を削除する。Release では `.rsm` も削除する。
`Aul2AudioMonitor` は `.dll` を `.aux2` にコピーする。Release では元の `.dll` と `.rsm` を削除する。
`Aul2AudioController` も `.dll` を `.aux2` にコピーし、Release では元の `.dll` と `.rsm` を削除する。

`Aul2AudioMonitor` は AviUtl2 の編集メニューに `Aul2AudioMonitor` を追加し、Wave / Spectrum を切り替えて表示する拡張プラグインとして本採用する。
フィルター側は `Local\Aul2AudioMonitorState` と `Local\Aul2AudioMonitorSpectrum` へ常時表示用データを書き出す。検証用の `ENABLE_AUDIO_MONITOR_SHARED_MEMORY` const と分岐は削除済み。
`Aul2AudioMonitor` 側は 50ms タイマーで共有メモリを読み、初期表示は `Spectrum`。数値中心の疎通確認表示はちらつきが大きいため通常表示から外し、描画表示を主にする。`Spectrum` 右側には小型の縦 Peak Meter と Stereo Balance を常時表示する。

## コメントルール

`D:\DelphiProg\test\VideoMiner\note.md` のコメントルールをベースにする。

- コメントは、処理を読めば分かることではなく、目的、責務、注意点、状態の意味を補うために書く。
- 古い仕様や現在の実装と食い違うコメントは、見つけた時点で更新する。
- 不要なコメントや重複したコメントを増やしすぎない。
- `var` ブロック内にローカル関数やローカル手続きを内包しない。必要な補助処理は同じ `implementation` 内の独立した関数/手続きとして切り出す。
- ユニット先頭には、そのユニットの目的や担当範囲を `//` コメントで記述する。
- フィールドや定数のコメントは右側に 1 行で置き、同じブロック内では `:`、`=`、`//` の位置を揃える。
- レコード定義のフィールドは、同じレコード内でフィールド名、`:`、型名、行末の `//` の位置を揃え、各フィールドの用途や値の意味をコメントに書く。
- コメントと対象の宣言/実装の間には空行を入れない。
- `interface` に公開する `procedure` / `function` には、呼び出し側から見た責務、入出力、重要な副作用を宣言直前の `//` コメントで書く。
- `property`、`procedure`、`function` 宣言は、横幅 112 文字以内に収まる場合は折り返さない。
- 日本語の文字列リテラルを持つ `.pas` は UTF-8 BOM 付きで保存する。BOM なし UTF-8 だと Delphi の単純ビルド時に文字コード判定が揺れ、GUI 表示が文字化けすることがある。

## 保守ルール

- `README.md` には利用者向けの説明を置き、細かい開発メモを増やさない。
- `note.md` には開発再開時に必要な情報だけを置く。
- 完了済みの開発記録、検証ログ、試行錯誤、日付付きの作業履歴は `HISTORY.md` に書く。
- 共通化できる処理は `Source\Lib` へ移す。
- 検証用の音声素材や生成スクリプトは `Sample` へ置く。

## Aul2AudioMonitor 現状

- `Aul2AudioMonitor.aux2` は `Aul2AudioFilter.auf2` と同時配布する表示用拡張プラグイン。
- `.auf2` 側は共有メモリへ表示用データを書き出し、`.aux2` 側は描画/UI だけを担当する。
- 表示は `Wave` / `Spectrum` のツールバー構成。初期表示は `Spectrum`。View配置とPreset管理はControllerへ移行済み。
- `Wave` は 256 点程度の時間波形表示。`Spectrum` は 64 バンドの周波数表示で、入力はグリーン、出力はアンバー。
- `Spectrum` 右側には Peak Meter と Stereo Balance を表示する。
- 共有メモリは基本状態/時間波形用の `Local\Aul2AudioMonitorState` とスペクトラム用の `Local\Aul2AudioMonitorSpectrum` に分ける。
- 生の音声サンプル全体は共有メモリに載せない。Wave、Spectrum、Meter、Stereo は表示用に軽量集計した値だけを使う。
- 再生中の Monitor は共有メモリ履歴リングから現在フレームに最も近い解析値を選び、十分に同期が取れている。詳細な同期調査履歴は `HISTORY.md` を参照する。
- Monitor内のView／Preset実装は将来の復活に備えて保持するが、`ENABLE_MONITOR_EDIT_PAGES = False` としてボタン、ページ、編集パネルを生成しない。

## Aul2AudioController 現状

- 全20エフェクトの設定操作に加え、選択リスト末尾に `エフェクトプリセットの管理`、`波形表示オブジェクトの配置` をこの順で表示する。
- `エフェクトプリセットの管理` は登録、インライン確認付き削除、起動時読込、名前のインライン編集、`Ctrl+Up` / `Ctrl+Down` の並べ替え、タイムラインへのD&Dを提供する。削除確認は選択変更やページ再表示などで必ず解除する。
- プリセット保存先はドキュメントの `Aul2AudioFilter\UserPresets.ini`。エイリアスをRTTIモデルへ分解し、二重セクション形式の可読なINIとして管理する。
- `波形表示オブジェクトの配置` はWidth、Height、Seconds、FPS、配置レイヤーを受け取り、Sendまたはレイヤー一覧のD&Dで `Aul2Audio View` 用オブジェクトを配置する。
- Controllerは縦長・正方形を基本とし、Presetは一覧の下に登録・削除、View配置は設定欄の下にレイヤー一覧とSendを置く。

## Aul2AudioBaseInput / Base 現状

- `Aul2AudioBaseInput.aui2` は `Aul2Audio View` の土台になる空の動画入力プラグイン。
- 仮想ファイル名 `Aul2AudioBase:1920_1080_30_30_1.aul2base` のような文字列から `Width_Height_MaxSec_Rate_Scale` を復元する。
- 入力プラグインは動画のみを返し、32bit BI_RGB の空フレームを返す。音声は持たない。
- Monitor の `View` ページから `.aul2base` 素材を生成できる。
- 生成されるエイリアスは `動画ファイル` + `映像再生` + `Aul2Audio View` の 3 フィルター構成。
- `Aul2AudioBasePanel.pas` は Width / Height / Sec / FPS、レイヤーリスト、選択レイヤー生成、D&D エイリアス生成を担当する。

## Aul2AudioView 現状

- `Aul2AudioView` は `Aul2AudioBaseInput` の上に載る MV 用表示フィルター。編集補助ではなく、音に反応する見た目を生成する用途。
- 描画は背景透明、文字なし、枠なし、グリッドなしを基本にする。
- 出力は安定優先で `Video^.SetImageData(Buffer, Width, Height)` を使う。GPU texture 出力はヘルパーだけ保持し、通常は無効。
- 表示タイプは `Equalizer Bars` / `Mirror Bars` / `Filled Spectrum` / `Circular Spectrum` / `Wave Line` / `Pixel Wave` / `Pulse Wave` / `Vectorscope` / `Circular Bars (3D)` / `Radial Waveform (3D)` / `Spectrum Landscape (3D)` / `Waveform Tunnel (3D)` の 12 種類。
- `Circular Bars (3D)` は既存スペクトラム値から円周状の直方体バーを生成し、SDK の `draw_poly()` でフレームバッファへ直接描画する3D Type。`Solid` / `Blocks`、`Density`、`Spacing`、`Thickness`、`Base Radius`、X/Y/Z Scale、色、周波数範囲を反映する。共有メモリは追加せず、描画失敗時はCPU版 `Circular Spectrum` へ戻す。
- `Radial Waveform (3D)` は現在の時間波形を円周上の厚み付きリボンへ変換し、SDK の `draw_poly()` で3D描画する。波形の位相移動が円周上の自然な回転として見える。X/Y/Z Scale、`Density`、`Thickness`、`Base Radius`、`Smooth`、色を反映し、薄い元形状を見やすくするためZ ScaleだけType固有の6倍感度を持つ。共有メモリは追加せず、描画失敗時は `Wave Line` へ戻す。
- `Spectrum Landscape (3D)` は既存のスペクトラム履歴を周波数=X、振幅=Y、時間履歴=Zの四角形グリッドへ変換し、SDK の `draw_poly()` で3D描画する。最大32列とし、`Solid`は連続地形、`Blocks`は独立した履歴帯として描く。`Density`、`Spacing`、`Thickness`、`Smooth`、X/Y/Z Scale、色、周波数範囲を反映する。`Base Radius`は円形座標を持たないため使用しない。共有メモリは追加せず、描画失敗時は `Filled Spectrum` へ戻す。
- `Waveform Tunnel (3D)` は既存共有メモリから現在フレーム以前の波形履歴を最大32断面取得し、円形断面としてZ方向へ並べる。再生中はView内の流動履歴で断面を奥へ送り、編集中はカーソル位置に合わせて共有履歴を毎回組み直す。`Solid`は断面間を接続した両端面付きの厚み付きトンネル、`Blocks`は独立リング列として `draw_poly()` で描く。`Density`、`Spacing`、`Thickness`、`Base Radius`、`Smooth`、X/Y/Z Scale、色を反映し、共有メモリは追加しない。`Smooth`は先頭だけでなく履歴方向にも適用する。`Solid`では`Thickness`を壁厚、`Spacing`を断面間隔として分離する。同期履歴がない編集時は指定レイヤーの最新値、それも無効なら最後の有効形状へ戻す。描画失敗時は `Wave Line` へ戻す。スペクトラム専用の周波数範囲、高域強調、周波数軸設定は意図的に使用しない。Release Win64ビルド、再生中の流動、編集カーソル追従、各パラメーター、Solidの壁厚・端面、Blocksのリング列を実機確認済みで、完成扱いとする。
- 新しい3D View Typeを追加する際は、再生中だけでなく編集停止中の表示も必ず考慮する。編集停止中は同期対象の音声履歴が得られず無音値へ落ちて形状が消える場合があるため、既存3D Typeと同様に、指定レイヤーの最新値へのフォールバックと最後の有効値の保持を実装する。Play／Encode中の本当の無音は保持せず、そのまま無音として扱う。
- スペクトラム系は `Local\Aul2AudioMonitorSpectrum`、時間波形系は `Local\Aul2AudioMonitorState`、`Vectorscope` は `Local\Aul2AudioViewVector` の処理後Output L/R代表点を読む。
- 共通パラメーターは `Type`, `Style`, `Density`, `Spacing`, `Thickness`, `Base Radius`, `Smooth`, `X Scale`, `Y Scale`, `Z Scale`, 色、周波数範囲設定。
- バー、面、時間波形は用意された画像の幅と高さを使って描画する。`Circular Spectrum` と `Vectorscope` は短辺から作る中央正方形を基準にし、変形は `X Scale` / `Y Scale` またはAviUtl2側で行う。
- `Vectorscope` は `X=(L-R)/2`、`Y=(L+R)/2` を基本とし、通常小さいSide成分を見やすくするためX方向だけ固定10倍の表示感度を持つ。`Circular Spectrum` のX/Y感度は通常倍率。
- `Color Variation` は `1 Color`, `2 Color`, `3 Color`, `Rainbow`, `Warm`, `Cool`, `Pastel`, `Neon`, `Mono`, `Sepia`, `Gold`, `Silver`, `Fire`, `Ice`, `Water`, `Aurora`, `Starlight`, `Sunset`, `Ocean`, `Forest`, `Cyber`, `Retro Game`。
- `Color Blend` は `Auto`, `RGB`, `HSV Short`, `HSV Long`。`Auto` では周期的な色相回転を避ける設定にする。
- `Equalizer Bars` / `Filled Spectrum` の描画マージンは `0`。必要になった場合は `VIEW_MARGIN_X` / `VIEW_MARGIN_Y` を設定項目へ昇格する。
- `Base Radius` は円形系表示の共通設定候補。`Circular Spectrum` では中心からどの半径を起点に外側へ伸ばすかを決める。今後ほかの円形 View Type を追加する場合も同じ設定値を採用する方向。
- `Circular Spectrum` はスペクトラム系の値を中心から外へ伸びる放射状表示に変換する。現時点では `Density` / `Spacing` / `Thickness` / `Base Radius` / `Smooth` / 色 / 周波数範囲設定を流用する。
- `Mirror Bars` はスペクトラム系の値を中心線から上下対称に伸びるバーへ変換する。`Density` / `Spacing` / `Thickness` / `Smooth` / 色 / 周波数範囲設定を流用する。
- 完了済みの実装経緯や試行錯誤は `HISTORY.md` の `Aul2AudioView completion note` を参照する。

## Aul2AudioView 次回3D Type候補

- `Spectrum Waterfall (3D)`: スペクトラム履歴を接続しない細い帯としてZ方向へ並べる。`Spectrum Landscape (3D)` の履歴取得と流動履歴を再利用できる。難度は低～中。
- `Vectorscope Trail (3D)`: ステレオ／位相の点列履歴をZ方向へ展開する。全レイヤー共通履歴から対象レイヤーを抽出して時間順に並べる必要がある。難度は中～やや高。

## Aul2AudioView 追加予定: パーティクル表現

- バーなどが音に反応して大きく動いた際、先端から粒子が飛び出して画面外へ消えていくパーティクル表現を追加候補とする。
- View Typeごとに元の形状や放出方向が異なるため、粒子の動きは各Typeに合わせて多少変えてよい。共通設定では具体的な動作名を固定しない。
- 共通設定は `Particle` と `Particle Count` の2項目だけとし、パーティクル固有の設定値を増やしすぎない。
- `Particle` は `None` / `Type 1` / `Type 2` ... の選択形式とする。初期値は `None` とし、従来表示と負荷へ影響させない。
- `Type 1` などの意味はView Typeごとに変えてよい。設定名を抽象化し、将来、形状や軌道を追加しやすい状態にする。
- `Particle Count` は1回に放出する数ではなく、画面内に同時存在できる粒子数の上限として扱う。候補範囲は `16..512`、初期値は少数の `64`、刻みは `16` とする。
- `Particle = None` の間も `Particle Count` の値は保持し、`Type 1` などを選択すると次の描画フレームから即時反映する。別Typeへ切り替えた場合は既存粒子を消し、新しい方式で生成し直す。
- 粒子の位置、速度、寿命などの状態はViewプラグイン内で管理し、現時点では共有メモリを増やさない方針とする。最大数を固定し、配列を再利用して負荷を抑える。

## Aul2AudioView / Monitor 再生同期の現状

- View と Monitor は再生中も現在フレーム基準で同期が取れている。
- 共有メモリは基本状態/時間波形用 version 8、スペクトラム用 version 6。各レイヤー 128 件の履歴リングを持つ。
- `Vectorscope` 専用共有メモリはversion 2。64レイヤーの最新値と全レイヤー共通256件の履歴リングへ、処理後OutputのL/R代表点64組を保持する。
- Filter 側は `AudioMonitorCaptureOutput` で最新スロットと履歴リングの両方へ書き込む。
- View / Monitor 側は `SourceFrame` を描画フレーム基準へ正規化し、現在フレームに最も近い履歴を選ぶ。距離が同じ場合のみ `UpdateTick` をタイブレークに使う。
- 詳細な工程、試行錯誤、検証結果は `HISTORY.md` の `Aul2AudioView / Monitor playback sync completion note` を参照する。
