# Aul2AudioFilter note

作業再開時に最初に見る開発メモ。ここには現在の方針、開発方法、コメントルール、ビルド方法を置く。

- 利用者向けの概要、配置、配布説明は `README.md` へ置く。
- 検証用 WAV の説明は `Sample\README.md` へ置く。
- 完了済みの開発記録、検証ログ、試行錯誤、日付付きの作業履歴は `HISTORY.md` へ書く。

## 現在の方針

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
- `Aul2Audio View` の `View Gain(%)` は描画だけを倍率調整する。`100` が等倍、範囲は `10..500` で、音声処理や解析値には影響させない。
- 共有メモリ上は内部 0-based レイヤー別スロットで保持し、GUI と Monitor 表示では AviUtl2 の表示レイヤーに合わせて 1-based で扱う。
- `Source Layer = Auto` は最後に更新されたレイヤーを表示し、レイヤー指定時はその表示レイヤー由来の波形/スペクトラムだけを読む。
- エフェクトの GUI 並びは、プリセットを除き、実際に音声へ処理される順番へ揃える。利用者が上から順に音が変わると理解できる状態を保つ。
- 最終段にユーザーが触れる `Output: Gain(dB)` のような出力音量調整を追加する方針。音量を上げた後のピーク保護のため、最終 Limiter はその後段に置く。
- 完全自動の音量復元は、ノイズや残響まで不自然に持ち上げる可能性があるため基本機能にはしない。必要なら後で `AutoGain` として独立した任意エフェクトにする。

## 検証状況

- プラグインテストは正常。
- `GetSampleData` で音声サンプルを受け取り、加工して `SetSampleData` で戻す基本経路は正常。
- Delay / Ping-Pong / Chorus / Reverb / EQ / Compressor / Limiter / Distortion / Noise / BitCrusher などの基本動作は検証済み。
- 追加プリセットは `夢/回想` まで一通り試聴済み。
- `無線` と `劣化` は `Noise` 使用時に無音化や AviUtl2 側の例外が出る可能性があったため、プリセットからは `Noise` を外している。
- `FilterProcAudio` 全体は `try..except` で保護し、音声処理中の Delphi 例外が AviUtl2 まで漏れないようにしている。
- 緊急: 2 人分の声など複数音声素材を 1 つの `グループ制御（音声）` で処理すると、Monitor 表示だけでなくエフェクト本体も壊れる可能性が高い。最初に解くべき問題は、1 つのフィルターが複数音声を扱うケースであり、この場合は素材別の独立エフェクトではなく、グループ/バスに入った 1 本のミックス音声として扱う方針にする。現在の Delay / Chorus / Reverb / EQ / Compressor / Limiter / AutoGain / NoiseGate などの状態持ち処理は、`GDelayChannels` や `GNextSampleIndex` のようなユニット単位の単一グローバル状態を使っているため、AviUtl2 が子音声ごとに交互呼び出しする場合はリセットや履歴混入が起きる。まず `グループ制御（音声）` 時の `FilterProcAudio` 呼び出し単位を診断し、ミックス済み 1 回呼び出しなのか、子音声ごとの複数回呼び出しなのかを確認する。その後、同じフレーム上の複数音声オブジェクトそれぞれにフィルターが追加されるケースへ、Syncroh2 の `GCTX` と同様のフィルターオブジェクト別 Context 分離を適用する。
- 2026-07-10: `グループ制御（音声）` 配下の 2 音声再生ログで、同じ `EffectID` / `SampleIndex` に対して `Object_.ID` と `Layer` が異なる子音声が交互に `FilterProcAudio` へ来ることを確認した。`Delay` / `Chorus` / `Reverb` / `EQ` / `Compressor` / `Limiter` は `Object_.ID + EffectID` ごとの状態スロットへ分離済み。Debug Win64 ビルド成功、2 音声再生で改善確認済み。状態スロット管理は `Source\Aul2AudioFilterContextManager.pas` の Syncroh2 `GCTX` 方式に近い共通 Context List へ寄せた。残りの状態持ち候補は `AutoGain` / `NoiseGate` / `Ghost` / `Wobble` / `Pitch` / `Muffle` / `Whisper` / `BitCrusher` / `VoiceDrive` など。
- 2026-07-10: 同一フレームに 2 音声ファイルを置き、それぞれに別の `Aul2AudioFilter` 設定を付けると、Use OFF のエフェクトが `ClearXxxState` で全 Context を消し、もう一方の状態まで引っ張る問題を確認。`Delay` / `Chorus` / `Reverb` / `EQ` / `Compressor` / `Limiter` は、処理中に Use OFF でも全 Context を消さず何もしない方針へ変更した。プリセット適用時の明示的な `SetXxxGuiParams` では引き続き Context をクリアする。修正後、同一フレーム上の 2 音声ファイルへ別々のフィルター設定/別エフェクトをかける構成で、片方に引っ張られず正しく効くことを確認済み。
- 2026-07-10: `Aul2Audio View` と `Aul2AudioMonitor` は、再生中も現在フレーム基準で十分に同期が取れていることを確認済み。Filter 側が共有メモリへレイヤー別履歴リングを書き、View / Monitor 側が `SourceFrame` を描画フレーム基準へ正規化して現在フレームに最も近い履歴を選択する。
- 2026-07-11: 音声コールバックが数秒先まで先読みされるため、Monitor は View が共有する現在描画フレームを基準に履歴を選択する方式で同期を改善した。再生中に現在フレームへ対応する履歴が見つからない場合、先読み側の最新値へフォールバックせず、直前の Wave / Spectrum / Peak / RMS を 50ms ごとに減衰させて 0 へ収束させる。これにより無音区間で表示が持続する問題と、再生開始時に前回のバッファが表示される問題が解消し、正常表示を確認済み。
- 2026-07-12: WAV終端後もDelay残響を続けるため、同じ `EffectID` / 内部レイヤーで1～2フレーム以内に隣接する後続音声ObjectへDelayリングを引き継ぐ処理を追加した。元WAVの直後へ `Sample\無音_極小ノイズ_ループ推奨.wav` を置き、両方を同じ `グループ制御（音声）` の範囲に入れると、元WAV終了後もエコーが継続する。後続Objectが `SampleIndex = 0` から始まるたびに状態を更新するため、2回目以降の再生でも正常動作を実機確認済み。重複音声や離れたObjectのContext分離は維持する。
- 詳細な実装記録、検証ログ、プリセット試聴メモは `HISTORY.md` を参照する。

## プロジェクト構成

- `Aul2AudioFilter.dpr`: AviUtl2 へ `GetFilterPluginTable` などを export する入口。各ユニットは `Source\...` の相対パスで参照する。
- `Aul2AudioFilter.dproj`: Delphi Win64 Debug / Release ビルド設定。
- `Aul2AudioMonitor.dpr`: AviUtl2 へ `RegisterPlugin` などを export する拡張プラグイン入口。波形表示 UI 用の受け皿。
- `Aul2AudioMonitor.dproj`: 拡張プラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Aul2AudioBaseInput.dpr`: AviUtl2 入力プラグイン入口。`.aul2base` 仮想ファイルを空の動画素材として開く。
- `Aul2AudioBaseInput.dproj`: 入力プラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Aul2AudioView.dpr`: `Aul2AudioBaseInput` の上に載せる MV 用表示フィルタープラグイン入口。
- `Aul2AudioView.dproj`: 表示用フィルタープラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Source\Aul2AudioMonitorPlugin.pas`: `Aul2AudioMonitor` の拡張メニュー登録、AviUtl2 クライアントウィンドウ登録、フォーム表示管理。
- `Source\Aul2AudioBasePanel.pas`: `Aul2AudioMonitor` の `Base` ページ UI。解像度設定、レイヤーリスト、選択レイヤー生成ボタン、D&D エイリアス生成を担当する。
- `Source\Aul2AudioPresetPanel.pas`: Monitorの `Preset` ページUI。選択Objectの保存、一覧の名前編集、グループ制御（音声）のD&D生成を担当する。
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
- `Source\Aul2AudioViewRenderUtils.pas`: ピクセルクリア、矩形塗り、View 用色取得など、表示タイプ間で共有する小さな描画補助。
- `Source\Aul2AudioViewSpectrum.pas`: `Local\Aul2AudioMonitorSpectrum` の読み取りとスムージングを担当する。スペクトラム系表示タイプで共有する。
- `Source\Aul2AudioViewWave.pas`: `Local\Aul2AudioMonitorState` の時間波形読み取りを担当する。時間波形系表示タイプで共有する。
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
- `Source\Lib\AudioMonitor`: `Aul2AudioFilter` と `Aul2AudioMonitor` で共有するモニター用共有メモリ構造体。
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

## 今後の主な確認候補

- `Aul2AudioMonitor` の再生中同期は、View が共有する現在描画フレームと履歴選択を利用して改善済み。無音区間では直前の表示値を減衰させ、前回バッファや先読み側の値を表示し続けない。今後同期処理を変更する場合は、View の正常な同期処理とこの無音時減衰を崩さない。
- 最優先: 1 つのフィルターが `グループ制御（音声）` 配下の複数音声を扱う問題を先に解く。音響上は、子音声別に Delay/Reverb などの履歴を分けるのではなく、グループ/バスへ入った 1 本のミックス音声に対して 1 つのエフェクト状態を持つのが正しい方針。まず `FilterProcAudio` の一時診断で、同一フレーム/同一 `SampleIndex` 周辺に対して `Object_.ID`、`EffectID`、`Layer`、`Index`、`Num`、`SampleIndex` がどう並ぶかを確認する。AviUtl2 がミックス済み 1 回呼び出しを渡しているなら単一状態を維持し、リセット条件を見直す。子音声ごとの複数回呼び出しなら、素材別状態分離ではなく、ミックス音声として扱うために何を同一グループ入力として束ねられるかを先に判断する。
- `FilterProcAudio` の呼び出し診断は `Source\Aul2AudioFilterAudioTrace.pas` で行う。`%TEMP%\Aul2AudioFilterAudioTrace.enable` という空ファイルがある時だけ、最大 2048 行まで `%TEMP%\Aul2AudioFilterAudioTrace.log` へ `Object_.ID` / `EffectID` / `Layer` / `Index` / `Num` / `SampleIndex` などを書き出す。通常時は enable ファイルを置かない。
- 次点: 同じフレームに複数の音声オブジェクトがあり、それぞれに `Aul2AudioFilter` が追加されているケースは、Syncroh2 の `GCTX` と同様にフィルターオブジェクト別 Context で状態を分離する。対象候補は Delay、Chorus、Reverb、EQ、Compressor、Limiter、AutoGain、NoiseGate、Ghost、Wobble、Pitch、Muffle、Whisper、BitCrusher など。こちらは `Object_.ID` + `EffectID` を主キー候補にし、1 フィルター内の複数音声ミックス問題を解いた後に展開する。
- `エコー` と `反響` は似すぎているため、必要なら用途差が分かる値へ再調整する。
- `無線` と `劣化` は `Noise` を外した状態で運用中。`Noise` の無音化や例外原因は別途調査候補とする。
- `Pitch` は簡易方式のため、声素材で `男性` / `女性` のぶつ切れや不自然さを継続確認する。
- `風邪`、`遠く` は専用プリセットとしては未追加。必要になったら既存エフェクトの組み合わせで検討する。
- ユーザープリセットは `Aul2AudioMonitor` の `Preset` ページへ実装済み。選択中の `グループ制御（音声）` を保存し、一覧からタイムラインへD&Dして再利用する。選択中Objectへ設定を読み込む機能は実装しない。
- 外部 AI からの提案として、`Wobble` / `Pitch` のランダム性を強める方向を検討候補にする。周期 LFO だけでなく、古いテープのワウ・フラッターのような不規則なピッチ揺れを想定する。
- 外部 AI からの提案として、Lo-Fi 系の質感強化を検討候補にする。`BitCrusher` に加えて、8kHz / 11kHz 相当へ落とすダウンサンプリング的な音を想定する。
- 外部 AI からの提案として、複数レイヤー/グループ制御時の負荷と競合を継続確認する。`Source Layer` の個別指定で干渉回避できるが、`Auto` の安定性と多重トラック時の軽量化は確認候補に残す。
- 外部 AI からの提案として、`Aul2Audio View` の View Type 拡張を検討候補にする。円形波形、ドーナツ型スペクトラム、音量反応の明滅、不透明度やブラーの揺れなど、MV 用素材として映像表現へ直接効く描画を想定する。
- `Aul2Audio View` / `Aul2AudioMonitor` の再生同期は現状良好。今後触る場合は、共有メモリ履歴リングとフレーム距離優先選択を崩さない。
- 新しい実装作業や試聴結果を終えたら、詳細な経緯は `HISTORY.md` へ追記する。

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
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioBaseInput.aui2
C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioView.auf2
```

ビルド後イベントで生成された `.dll` を `.auf2` にコピーし、元の `.dll` を削除する。Release では `.rsm` も削除する。
`Aul2AudioMonitor` は `.dll` を `.aux2` にコピーする。Release では元の `.dll` と `.rsm` を削除する。

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
- `.auf2` 側は共有メモリへ表示用データを常時書き出し、`.aux2` 側は描画/UI だけを担当する。
- 表示は `Wave` / `Spectrum` / `View` / `Preset` のツールバー構成。初期表示は `Spectrum`。
- `Wave` は 256 点程度の時間波形表示。`Spectrum` は 64 バンドの周波数表示で、入力はグリーン、出力はアンバー。
- `Spectrum` 右側には Peak Meter と Stereo Balance を表示する。
- 共有メモリは基本状態/時間波形用の `Local\Aul2AudioMonitorState` と、スペクトラム用の `Local\Aul2AudioMonitorSpectrum` に分ける。
- 生の音声サンプル全体は共有メモリに載せない。Wave、Spectrum、Meter、Stereo は表示用に軽量集計した値だけを使う。
- 再生中の Monitor は共有メモリ履歴リングから現在フレームに最も近い解析値を選び、十分に同期が取れている。詳細な同期調査履歴は `HISTORY.md` を参照する。
- `Preset` は `グループ制御（音声）` 専用のユーザープリセット機能。保存、起動時読込、名前のインライン編集、タイムラインへのD&Dを提供する。
- 保存先はドキュメントの `Aul2AudioFilter\UserPresets.ini`。エイリアスをRTTIモデルへ分解し、二重セクション形式の可読なINIとして管理する。
- 音声Objectへ直接フィルターを適用する機会は少なく、D&Dで目的を満たせるため、選択中Objectへ反映する読み込み機能は持たせない。

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
- 表示タイプは `Equalizer Bars` / `Mirror Bars` / `Filled Spectrum` / `Circular Spectrum` / `Wave Line` / `Pixel Wave` / `Pulse Wave` の 7 種類。
- スペクトラム系は `Local\Aul2AudioMonitorSpectrum` の `OutputBands`、時間波形系は `Local\Aul2AudioMonitorState` の `OutputWave` / `OutputWaveMin` / `OutputWaveMax` を読む。
- 共通パラメーターは `Type`, `Style`, `Density`, `Spacing`, `Thickness`, `Base Radius`, `Color`, `Color Variation`, `Color Blend`, `Smooth`。
- `Color Variation` は `1 Color`, `2 Color`, `3 Color`, `Rainbow`, `Warm`, `Cool`, `Pastel`, `Neon`, `Mono`, `Sepia`, `Gold`, `Silver`, `Fire`, `Ice`, `Water`, `Aurora`, `Starlight`, `Sunset`, `Ocean`, `Forest`, `Cyber`, `Retro Game`。
- `Color Blend` は `Auto`, `RGB`, `HSV Short`, `HSV Long`。`Auto` では周期的な色相回転を避ける設定にする。
- `Equalizer Bars` / `Filled Spectrum` の描画マージンは `0`。必要になった場合は `VIEW_MARGIN_X` / `VIEW_MARGIN_Y` を設定項目へ昇格する。
- `Base Radius` は円形系表示の共通設定候補。`Circular Spectrum` では中心からどの半径を起点に外側へ伸ばすかを決める。今後ほかの円形 View Type を追加する場合も同じ設定値を採用する方向。
- `Circular Spectrum` はスペクトラム系の値を中心から外へ伸びる放射状表示に変換する。現時点では `Density` / `Spacing` / `Thickness` / `Base Radius` / `Smooth` / 色 / 周波数範囲設定を流用する。
- `Mirror Bars` はスペクトラム系の値を中心線から上下対称に伸びるバーへ変換する。`Density` / `Spacing` / `Thickness` / `Smooth` / 色 / 周波数範囲設定を流用する。
- 完了済みの実装経緯や試行錯誤は `HISTORY.md` の `Aul2AudioView completion note` を参照する。

## Aul2AudioView / Monitor 再生同期の現状

- View と Monitor は再生中も現在フレーム基準で同期が取れている。
- 共有メモリは基本状態/時間波形用 version 8、スペクトラム用 version 6。各レイヤー 128 件の履歴リングを持つ。
- Filter 側は `AudioMonitorCaptureOutput` で最新スロットと履歴リングの両方へ書き込む。
- View / Monitor 側は `SourceFrame` を描画フレーム基準へ正規化し、現在フレームに最も近い履歴を選ぶ。距離が同じ場合のみ `UpdateTick` をタイブレークに使う。
- 詳細な工程、試行錯誤、検証結果は `HISTORY.md` の `Aul2AudioView / Monitor playback sync completion note` を参照する。
