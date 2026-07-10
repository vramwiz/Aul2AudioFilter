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
- 詳細な実装記録、検証ログ、プリセット試聴メモは `HISTORY.md` を参照する。

## プロジェクト構成

- `Aul2AudioFilter.dpr`: AviUtl2 へ `GetFilterPluginTable` などを export する入口。各ユニットは `Source\...` の相対パスで参照する。
- `Aul2AudioFilter.dproj`: Delphi Win64 Debug / Release ビルド設定。
- `Aul2AudioMonitor.dpr`: AviUtl2 へ `RegisterPlugin` などを export する拡張プラグイン入口。波形表示 UI 用の受け皿。
- `Aul2AudioMonitor.dproj`: 拡張プラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Aul2AudioBaseInput.dpr`: AviUtl2 入力プラグイン入口。`.aul2base` 仮想ファイルを空の動画素材として開く。
- `Aul2AudioBaseInput.dproj`: 入力プラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Aul2AudioView.dpr`: `Aul2AudioBaseInput` の上に載せる表示用フィルタープラグイン入口。現時点では空の映像フィルターとして登録だけ行う。
- `Aul2AudioView.dproj`: 表示用フィルタープラグインの Delphi Win64 Debug / Release ビルド設定。出力先は `Aul2AudioFilter` と同じ配布フォルダ。
- `Source\Aul2AudioMonitorPlugin.pas`: `Aul2AudioMonitor` の拡張メニュー登録、AviUtl2 クライアントウィンドウ登録、空フォーム表示の最小実装。
- `Source\Aul2AudioBasePanel.pas`: `Aul2AudioMonitor` の `Base` ページ UI。解像度設定、レイヤーリスト、選択レイヤー生成ボタン、D&D エイリアス生成を担当する。
- `Source\Aul2AudioBaseAlias.pas`: `.aul2base` 仮想ファイル名と AviUtl2 エイリアス文字列/一時 `.object` ファイル生成。
- `Source\Aul2AudioBaseCreate.pas`: `CreateObjectFromAlias` による選択レイヤーへの直接配置。
- `Source\Aul2AudioBaseInputPlugin.pas`: `.aul2base` 入力プラグイン本体。ファイル名内の `Width_Height_MaxSec_Rate_Scale` から動画情報を作る。
- `Source\Aul2AudioViewPlugin.pas`: `Aul2AudioView` のフィルターテーブル登録。表示名は `Aul2Audio View`、グループは `Video Effects`。現時点の映像処理は成功を返すだけ。
- `Source\Aul2AudioViewRender.pas`: `Aul2AudioView` の映像描画と AviUtl2 への出力を担当する。初期確認用にチェック背景と枠線を描く。
- `Source\Aul2AudioViewRenderEqualizer.pas`: `Equalizer Bars` 表示タイプの描画を担当する。固定パターンの縦バーで描画疎通を確認する。
- `Source\Aul2AudioViewRenderUtils.pas`: ピクセルクリア、矩形塗り、単色/虹色変換など、表示タイプ間で共有する小さな描画補助。
- `Source\Aul2AudioViewSpectrum.pas`: `Local\Aul2AudioMonitorSpectrum` の読み取りとスムージングを担当する。スペクトラム系表示タイプで共有する。
- `Source\Lib\AviUtl2GpuTextureOut.pas`: Syncroh2 の PSDDraw と同じ考え方の任意 GPU texture 出力ヘルパー。初期状態では無効化し、通常は `SetImageData` で出力する。
- `Source\Aul2AudioFilterPlugin.pas`: AviUtl2 へ公開するフィルター入口、各エフェクトユニットの接続。
- `Source\Aul2AudioFilterMonitorBridge.pas`: フィルター側から共有メモリへ入力/出力ピークなどの軽量解析値を書き出す入口。
- `Source\Aul2AudioFilterPluginPreset.pas`: `プリセット` GUI 項目、詳細エフェクト設定への反映処理。
- `Source\Aul2AudioFilterPluginDelay.pas`: Delay / Echo 系の GUI 項目、状態管理、音声処理。
- `Source\Aul2AudioFilterPluginChorus.pas`: Chorus 系の GUI 項目、状態管理、音声処理。
- `Source\Lib\Aul2AudioFilterTypes.pas`: AviUtl2 フィルター SDK の Delphi 型定義。
- `Source\Lib\Aul2AudioFilterGui.pas`: `SetupPluginTable` / `AddGroup` / `AddTrack` などの GUI 項目登録ライブラリ。
- `Source\Lib\AviUtl2Plugin`: Syncroh2 から UTF-8 でコピーした AviUtl2 汎用プラグイン SDK 型定義と共有状態。
- `Source\Lib\AviUtl2Input`: AviUtl2 入力プラグイン SDK 型定義。
- `Source\Lib\DragAgent`: Syncroh2 からコピーした D&D 送信用ライブラリ。Base ページのレイヤーリスト D&D に使う。Delphi 37.0 向けに uses の名前空間を調整済み。
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

- `エコー` と `反響` は似すぎているため、必要なら用途差が分かる値へ再調整する。
- `無線` と `劣化` は `Noise` を外した状態で運用中。`Noise` の無音化や例外原因は別途調査候補とする。
- `Pitch` は簡易方式のため、声素材で `男性` / `女性` のぶつ切れや不自然さを継続確認する。
- `風邪`、`遠く` は専用プリセットとしては未追加。必要になったら既存エフェクトの組み合わせで検討する。
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
- コメントと対象の宣言/実装の間には空行を入れない。
- `property`、`procedure`、`function` 宣言は、横幅 112 文字以内に収まる場合は折り返さない。
- 日本語の文字列リテラルを持つ `.pas` は UTF-8 BOM 付きで保存する。BOM なし UTF-8 だと Delphi の単純ビルド時に文字コード判定が揺れ、GUI 表示が文字化けすることがある。

## 保守ルール

- `README.md` には利用者向けの説明を置き、細かい開発メモを増やさない。
- `note.md` には開発再開時に必要な情報だけを置く。
- 完了済みの開発記録、検証ログ、試行錯誤、日付付きの作業履歴は `HISTORY.md` に書く。
- 共通化できる処理は `Source\Lib` へ移す。
- 検証用の音声素材や生成スクリプトは `Sample` へ置く。

## `.auf2` と `.aux2` の連携検討

- 現在の `.auf2` フィルタープラグインは、AviUtl2 のフィルター設定項目でパラメーターを受け取り、`FilterProcAudio` で音声サンプルへエフェクトをかける構成。
- 課題は、フィルター設定項目だけでは波形表示、波形上へのパラメーター表示、波形上でのドラッグ編集のような独自 UI を持ちにくいこと。
- 波形表示や視覚的な編集面は `.auf2` 単体ではなく、`.aux2` の汎用プラグインで独自ウィンドウを持つ方向を検討する。
- SDK 上、`.auf2` と `.aux2` が互いを直接参照して通信するための専用 API は前提にしない。
- 確実に使える連携手段は共有メモリとする。`.auf2` 側が解析用の音声情報、現在パラメーター、ピーク、処理状態などを書き込み、`.aux2` 側が表示用に読む構成を第一候補にする。
- `.aux2` 側から `.auf2` へ編集値を返す場合も、共有メモリ上にコマンド領域や世代番号を持たせ、`.auf2` 側が安全なタイミングで取り込む形にする。
- 音声処理コールバック内では待機やブロッキング処理を避ける。共有メモリは短時間の読み書きに留め、必要ならロックフリーに近いリングバッファ、世代番号、簡単な排他で設計する。
- パイプは使えないものとして扱う。音声処理中にブロックする危険があり、AviUtl2 本体や音声処理スレッドを巻き込む可能性があるため、`.auf2`/`.aux2` 連携案から除外する。
- `.aux2` は波形ビュー、メーター、パラメーター可視化、選択範囲表示などの表示担当に寄せる。実際の音声処理の正本は引き続き `.auf2` 側に置く。
- まずは一方向連携として、`.auf2` から共有メモリへ簡易波形またはピーク列を書き出し、`.aux2` が読むだけの検証を行うのが安全。
- 共有メモリは比較的高速なので、全サンプル波形ではなくピーク列、RMS、表示幅に間引いた min/max などの簡易情報であれば波形表示用データの受け渡しにも使える可能性が高い。
- `.aux2` は自身のウィンドウ、メニュー、イベント、フォーカスなど処理機会が来た時にしか発火しない可能性がある。共有メモリは「通知」ではなく「状態置き場」として設計し、`.aux2` が読めるタイミングで最新世代を読む形にする。
- `.aux2` 側がタイマーで毎回共有メモリの変化を見に行く方式は最終手段にする。まずはウィンドウメッセージ、AviUtl2 側イベント、ユーザー操作、描画更新など、自然に発火する契機で読めないかを優先して検討する。

## Aul2AudioMonitor 波形表示メモ

- 緊急課題: Monitor / View の表示データ対応がまだ正しくない。現象として、エフェクターをかけていない場所で Monitor に波形/スペクトラムが表示され、実際にエフェクターがかかっている場所では表示されないことがある。`UpdateTick` と `FrameS` / `FrameE` による古いデータ抑制・範囲判定を入れたが、2026-07-10 時点で改善していない。次回は AviUtl2 から渡る `Object_.Frame` / `FrameS` / `FrameE` / `SampleIndex` が絶対値か相対値か、音声フィルターと View フィルターで同じ基準かを実測ログで確認する。共有メモリ側には、デバッグ用に `SourceFrame` / `SourceFrameS` / `SourceFrameE` / `SampleIndex` / `Layer` / `Index` を画面表示または一時ログ出力する必要がある。
- `.auf2` から `.aux2` への基本連携は共有メモリ `Local\Aul2AudioMonitorState` で成立済み。
- `Stage: 3`、`Generation` 増加、`SampleRate` / `SampleNum` / `ChannelNum` / `SampleIndex`、入力/出力ピークの更新まで確認済み。
- 数値ラベルの逐次更新はちらつきやすいため、通常表示では止める方針。
- 現在は共有メモリに `InputWave` / `OutputWave` を 256 点の `Single` 固定配列として持たせる。
- フィルター側では音声処理ブロックごとに L/R を読み、ステレオは平均して、各区間の絶対値最大サンプルを符号付きで 256 点へ間引く。
- モニター側は `TPaintBox` で描画し、入力を落ち着いたグリーン、出力をアンバーで重ねる。高速更新されるため、赤と青/シアンの強い組み合わせは使わない。AviUtl2 内表示では `TCustomControl` 化で点滅が悪化したため、現状は `TPaintBox` 構成を維持する。
- 周波数表示は未実装。まず時間波形の安定表示を確認してから、RMS、簡易 FFT、ピークホールドなどを追加検討する。
- 現在の時間波形表示は横軸が時間、縦軸が振幅のオシロスコープ的な表示。これは表示モードの 1 つとして残す価値がある。
- 本命として欲しい表示は、横軸が周波数、縦軸が強さのスペクトラム/FFT 表示と思われる。EQ、Muffle、VoiceDrive、Noise などの効果確認には周波数表示の方が適している。
- 周波数表示を追加する場合、`.auf2` 側で全サンプルを渡さず、64 または 128 バンド程度の軽量な input/output レベルへ集約して共有メモリへ載せる方針が良い。
- `Aul2AudioMonitor` 側は肥大化防止のため役割別ユニットへ分割済み。
  - `Aul2AudioMonitorPlugin.pas`: AviUtl2 への登録、メニュー、クライアント HWND 管理。
  - `Aul2AudioMonitorView.pas`: VCL フォーム、タイマー、共有メモリ読み取り、描画更新。
  - `Aul2AudioMonitorPaint.pas`: 波形/スペクトラム描画。
  - `Aul2AudioMonitorShared.pas`: `.auf2` と `.aux2` が共有するメモリ構造体。
- AviUtl2 上では `TPageControl` 系の利用で落ちる可能性があるため、表示切替には `TPageControl` を使わない。
- Syncroh2 の `Lib\ToolBarPanelManager\ToolBarPanelManager.pas` を `Source\Lib\ToolBarPanelManager` へコピーして利用する。`TToolBar` のボタンと複数 `TPanel` の表示/非表示で、Wave / Spectrum などの表示モードを切り替える。
- 現在の `Aul2AudioMonitorView.pas` は `ToolBarPanelManager` で `Wave` と `Spectrum` パネルを切り替える構成。`Spectrum` は 64 バンドの周波数表示として実装済み。
- スペクトラム検証中は初期表示を `Spectrum` にする。描画更新タイマーは 50ms。
- `Spectrum` 右側には `Local\Aul2AudioMonitorState` の `InputPeakL/R` と `OutputPeakL/R` を使う小型の縦 Peak Meter を表示する。面積を取りすぎないよう右端に寄せ、Input L/R と Output L/R の細い縦バー、1.0 位置のクリップ目安線を描く。
- 同じ右側領域の下部には `InputRmsL/R` と `OutputRmsL/R` から計算した Stereo Balance を表示する。中央を 0、左寄りを L、右寄りを R として、入力をグリーン、出力をアンバーの小さなマーカーで描く。
- Peak Meter は `Stage` による `wait` 表示切り替えで点滅しやすかったため、直近ピークを保持して減衰表示する。`TBitmap` へ描いてから `TPaintBox` へ転送し、非表示パネルは Invalidate しない。サイズが変わらない 50ms 更新では `SetBounds` / `Realign` しない。
- 音声処理が止まると `.auf2` は最後のスペクトラム値を書いたまま更新機会を失うため、`.aux2` 側で `Generation` 更新を監視する。
- 共有メモリには更新時刻と、音声フィルター側の `FrameS` / `FrameE` などの元フレーム情報を持たせる。Monitor 側は更新が止まった古いデータを 800ms 程度で待機表示へ戻し、View 側は現在描画フレームが共有メモリの元フレーム範囲内にある場合だけ `OutputBands` を使う。これにより、エフェクトが載っていない場所で直前のスペクトラムが残る誤表示を避ける。
- 高速更新されるメーター/スペクトラムで赤と青/シアンの強い組み合わせは禁止。一般的な DTM アプリ寄りに、入力は落ち着いたグリーン、出力はアンバー/イエロー系を使う。
- 凡例は右上固定にすると狭い幅で欠けやすいため、スペクトラムでは左上に `Input` / `Output` を並べて表示する。
- Monitor のツールバーや Base ページ UI は DPI 差で文字だけ大きくなり、固定ピクセルの高さ/幅に収まらないことがある。`ToolBarPanelManager` は caption の実測幅と DPI スケール値からボタン幅/高さを決める。Base ページの `SetBounds` 寸法も `Font.PixelsPerInch` を使ってスケールする。

## Aul2AudioMonitor 現在の表示構成

- `Wave`: 横軸が時間、縦軸が振幅の波形表示。歪み、クリップ、ディレイ、トレモロなどの確認向け。
- `Spectrum`: 横軸が周波数、縦軸が強さの 64 バンド棒グラフ表示。EQ、こもり、ノイズ、低域/高域の量を見る本命。
- `Peak Meter`: `Spectrum` 右側に入力/出力 L/R の小型縦メーターとして表示する。
- `Stereo Balance`: `Spectrum` 右側下部に入力/出力の左右バランスを小型マーカーとして表示する。
- 共有メモリは基本状態/時間波形用の `Local\Aul2AudioMonitorState` と、スペクトラム専用の `Local\Aul2AudioMonitorSpectrum` に分ける。
- `Local\Aul2AudioMonitorState` は `Header`, `Wave`, `Meter`, `Stereo` などの軽量状態を持つ。
- `Local\Aul2AudioMonitorSpectrum` は `Header`, `InputBands`, `OutputBands` を持つ。現時点は 64 バンド。
- `.auf2` 側で音声から表示用データを軽量に集約し、`.aux2` 側は描画だけを担当する。
- 生の音声サンプル全体を共有メモリに載せない。Wave は 256 点程度、Spectrum は 64 または 128 バンド程度、Meter/Stereo は少数の集計値にする。
- `.auf2` 側では 1024 サンプル上限、64 バンド、20Hz から Nyquist または 20kHz までのログ配置で簡易スペクトラムを作る。
- `.aux2` 側では `Spectrum` ページがスペクトラム専用共有メモリを読み、input をグリーン、output をアンバーの棒グラフで描画する。

## Aul2AudioBaseInput / Base ページ現状

- `Aul2AudioBaseInput.aui2` は、今後追加する描画/表示系フィルタープラグインの土台になる空の動画入力プラグイン。
- 実ファイルは不要で、仮想ファイル名 `Aul2AudioBase:1920_1080_30_30_1.aul2base` のような文字列から入力情報を復元する。
- 仮想ファイル名の形式は `Caption:Width_Height_MaxSec_Rate_Scale.aul2base`。
- 入力プラグインは動画のみを返し、32bit BI_RGB の空フレームを返す。音声は持たない。
- 現時点では共有メモリを使わない。今後追加するフィルタープラグイン側が `FILTER_PROC_VIDEO` などから width/height を取得できるかを優先確認する。
- `Aul2AudioMonitor` に `Base` ページを追加済み。`Wave` / `Spectrum` / `Base` のタブ構成。
- `Base` ページは Width / Height / Sec / FPS の入力欄、レイヤーリスト、`選択レイヤーへ作成` ボタンを持つ。
- ボタン経由の生成は成功済み。選択したレイヤーへ `.aul2base` 素材オブジェクトを配置できる。
- レイヤーリストからの D&D 生成も成功済み。`Source\Lib\DragAgent\DragAgent.pas` を使い、一時 `.object` エイリアスを作ってドロップ先へ渡す。
- D&D 用の一時ファイルは `%TEMP%\Aul2AudioFilter\Aul2AudioBase.object` に保存する。
- エイリアス内容は Syncroh2 の `AliasManagerInputBase.pas` と同じ考え方で、`動画ファイル` + `映像再生` の 2 フィルター構成。
- 現在のエイリアス内容は `動画ファイル` + `映像再生` + `Aul2Audio View` の 3 フィルター構成。
- `CreateObjectFromAlias` に渡す alias は UTF-8 文字列へ変換している。
- Base ページ UI は `Aul2AudioMonitorView.pas` に直接書かず、`Aul2AudioBasePanel.pas` に分離済み。

Base ページのリサイズ/描画注意点:

- AviUtl2 内の子ウィンドウ上では、VCL コントロールのリサイズ時に数字や枠が消えることがあった。
- Syncroh2 側の対策に合わせ、同じサイズへの `SetBounds` は避ける。
- レイアウト更新は `DisableAlign` / `EnableAlign` でまとめる。
- `RDW_ERASE` や `RDW_UPDATENOW` を強く使うと悪化したため、背景消去を避ける `RDW_NOERASE` を使う。
- 子コントロールごとの `Invalidate` 連打は避ける。
- `TDragShellFile` は、親が確定してから初期化する。コンストラクタ中に子コントロールや D&D を作ると、親ウィンドウ未確定で例外になることがある。
- `選択レイヤーへ作成` ボタンは `FSettingsPanel` の子ではなく `TAul2AudioBasePanel` 本体の子にする。設定パネルの外へ配置するため。

Base ページの現在レイアウト:

- 左側に 2 段入力: 1 段目 `Width` / `Height`、2 段目 `Second` / `FPS`。
- 入力欄の右に小型レイヤーリスト。
- レイヤーリストの右に `選択レイヤーへ作成` ボタン。
- `Base alias` ラベルと `Layer` ラベルは不要として非表示。
- 縦方向は小さく使う予定。横方向には余裕がある前提で配置する。

## Aul2AudioView 描画方針

- `Syncroh2_Filter_PSDDraw.dpr` / `PluginFilterPSDDrawOut.pas` を参考にする。
- AviUtl2 への出力は、まず安定している `Video^.SetImageData(Buffer, Width, Height)` を使う。
- PSDDraw と同じく GPU texture 出力ヘルパーは持たせるが、初期状態では `GPU_TEXTURE_OUT_STAGE1 = False` として無効化する。
- GPU 出力を試す場合は `Aul2AudioViewRender.pas` の `GPU_TEXTURE_OUT_STAGE1` を `True` にし、`GetFramebufferTexture2D` の有無、サイズ一致、フォーマット、AviUtl2 上の安定性を確認してから採用判断する。
- 描画サイズは `Video^.Object_^.Width` / `Height` を使う。まずは `Aul2AudioBaseInput` 由来のサイズがここへ入るかを検証する。
- 現時点の描画は、疎通確認用のチェック背景と緑の枠線。実際の表示内容が決まったら専用レンダーへ差し替える。
- `Aul2AudioView` は `Aul2AudioMonitor` と異なり、編集補助のモニターではなく MV 用の表示素材を生成するフィルターとして設計する。
- 主用途はイコライザー風、スペクトラム風、波形風などの音に反応する見た目の生成。画面上に数値や説明文字を出す用途は基本にしない。
- 表示種類は GUI の `select` 項目で選び、選択した種類に応じて描画する波形/バー/リングなどを切り替える構成を基本にする。
- 文字ラベルや細かい UI 説明は原則描かない。必要になった場合も MV 素材として邪魔にならない控えめな装飾に留める。
- 描画が細かくなり、CPU バッファ生成と `SetImageData` 出力では負荷や転送量が問題になる場合は GPU texture 出力を本格検討する。
- 初期実装では CPU 出力で正しさと AviUtl2 上の安定性を優先し、GPU 化は表現量や負荷の問題が見えた段階で切り替え候補にする。
- 基本表示パターンは次の 5 種類を土台にする。
  - `Wave Line`: なめらかな連続線の時間波形。オシロスコープ風の表示。
  - `Pixel Wave`: 階段状またはピクセル状の時間波形。レトロ/デジタル寄りの表示。
  - `Equalizer Bars`: 周波数帯ごとの縦棒スペクトラム。MV 用途の定番イコライザー表示。
  - `Filled Spectrum`: 周波数分布を塗りつぶし面で描くスペクトラム表示。
  - `Pulse Wave`: 中心線を基準に上下対称の縦線で振幅を出すパルス/ボイス波形表示。
- 1/2/5 は時間波形系、3/4 は周波数スペクトラム系として扱う。
- この 5 パターンを単に再現するだけではなく、色、反応の滑らかさ、残像、左右対称、丸形配置、粒子化、発光、分割数、線幅などの `+α` を持たせることで `Aul2AudioView` の存在価値を作る。
- 初期 UI は基本パターンを `select` で選び、追加表現は必要に応じて少数の共通パラメーターと種類別パラメーターへ分ける方針にする。
- 設定値の先頭は必ず表示種類 `View: Type` にする。後続の共通パラメーターや種類別パラメーターを追加しても、種類選択が最上段に来る構成を維持する。
- 描画入口の `Aul2AudioViewRender.pas` は肥大化させず、バッファ確保、出力、表示タイプごとの振り分けだけを担当する。
- 表示タイプごとの描画は `Aul2AudioViewRenderXxx.pas` へ分ける。最初の実装は `Aul2AudioViewRenderEqualizer.pas` の `Equalizer Bars`。
- スペクトラム読み取りや色変換など、複数タイプで再利用する処理は種類別ユニットへ直接書かず、`Aul2AudioViewSpectrum.pas` や `Aul2AudioViewRenderUtils.pas` へ逃がす。
- `Syncroh2` の `PluginFilterTable.pas` と同じ考え方で、select 候補は `ClearSelectList` / `AddSelectList` で構築する。ライブラリ全体はコピーせず、必要な select list 補助だけ `Aul2AudioFilterGui.pas` へ取り込んだ。
- 現時点の `View: Type` は `Equalizer Bars` / `Wave Line` / `Pixel Wave` / `Filled Spectrum` / `Pulse Wave` の 5 パターンを用意する。
- 未実装の表示タイプを選んだ場合は、実装が入るまで `Equalizer Bars` へフォールバックする。
- 共通設定として `View: Style` / `View: Density` / `View: Spacing` / `View: Color` / `View: Color Style` / `View: Smooth` を用意する。
- `View: Style` は `Solid` と `Blocks`。`Solid` は隙間なしでつながった表示、`Blocks` は四角/長方形のブロック単位の表示にする。
- `View: Density` は表示の分割数。`Equalizer Bars` ではバー本数として扱い、他のタイプでも表示密度として再利用する。
- `View: Spacing` は縦横共通の隙間。設定数を増やさないため横/縦を分けない。`Solid` では無視し、`Blocks` でのみ使う。
- ブロック形状は専用の width/height 設定を持たせず、`Density` と素材サイズから自動計算する。`Equalizer Bars` ではブロック高さをバー幅から算出し、やや横長の長方形になるようにする。
- `View: Color` は基準色。`View: Color Style` は `Solid` / `Rainbow` を用意し、`Rainbow` ではバー位置に応じて色を変える。
- `View: Smooth` は音への反応の滑らかさ。値が大きいほど変化がゆっくりになり、余韻が残る。
- `Equalizer Bars` は `Local\Aul2AudioMonitorSpectrum` の `OutputBands` を読み、モニターと同じ攻撃速め/減衰ゆっくりのスムージングをかけて白い縦バーとして描く。
- `Aul2AudioView` は MV 用素材なので、モニター側にある凡例、枠、グリッド、ピークメーター、文字表示は描かない。
- 音声データがまだ共有メモリへ来ていない場合は透明背景のままにし、説明文字や `wait` 表示は出さない。

## 2026-07-09 作業終了時点メモ

- `Aul2AudioView` は `Aul2AudioBaseInput` の上に載る MV 用表示フィルターとして基本構成ができた。
- Base ページのエイリアス生成では `動画ファイル` + `映像再生` + `Aul2Audio View` の 3 フィルター構成になっている。
- `Aul2AudioView` は `Local\Aul2AudioMonitorSpectrum` の `OutputBands` を読み、音に反応する表示を行う。
- 設定値の先頭は `View: Type`。現在の選択肢は `Equalizer Bars` / `Wave Line` / `Pixel Wave` / `Filled Spectrum` / `Pulse Wave`。
- 現時点で実装済みの表示タイプは `Equalizer Bars` のみ。未実装タイプは `Equalizer Bars` へフォールバックする。
- 共通設定として `View: Style` / `View: Density` / `View: Spacing` / `View: Color` / `View: Color Style` / `View: Smooth` を持つ。
- `View: Style` は `Solid` / `Blocks`。連結バー表示とブロック表示を切り替える。
- `View: Color Style` は `Solid` / `Rainbow`。Rainbow は左の低域を赤、右の高域を紫/ピンク方向にする。左が低音であることは確認済み。
- `Equalizer Bars` は実スペクトラムに反応し、背景透明、文字なし、枠なし、MV 素材向けの基本形としておよそ完成扱いにする。
- ユニット分割は、`Aul2AudioViewRender.pas` を描画入口、`Aul2AudioViewRenderEqualizer.pas` を Equalizer Bars、`Aul2AudioViewSpectrum.pas` をスペクトラム読み取り/スムージング、`Aul2AudioViewRenderUtils.pas` をピクセル描画補助としている。

次に再開する場合の候補:

- まず `Equalizer Bars` を AviUtl2 上で軽く再確認し、初期値のままで実用上問題ないかを見る。
- 次の表示タイプを追加するなら、`OutputBands` をそのまま使える `Filled Spectrum` が最有力。
- `Filled Spectrum` も `Aul2AudioViewRenderFilledSpectrum.pas` のように別ユニットで追加し、`Aul2AudioViewRender.pas` は振り分けだけに留める。
- `Wave Line` / `Pixel Wave` / `Pulse Wave` は時間波形系なので、必要になった時点で `Local\Aul2AudioMonitorState` の `OutputWaveMin/Max` などを読む共通ユニットを検討する。
- 新しい設定を増やす前に、既存の `Style` / `Density` / `Spacing` / `Color` / `Color Style` / `Smooth` で表現できるかを優先して考える。
- 参考元のイコライザー系 UI には `横解像度` / `縦解像度` / `横スペース` / `縦スペース` がある。
- `横解像度` / `縦解像度` は表示を構成する四角グリッドの列数/段数に近い。`Aul2AudioView` では素材サイズ自体の解像度は `Aul2AudioBaseInput` で代替済みなので、必要なら「バー数」や「縦段数」のような表示密度パラメーターとして扱う。
- `横スペース` / `縦スペース` は四角同士の隙間を制御する値と思われる。`0` にすると隙間がなくなり、四角がつながってバーや面のように表示される。
- この四角グリッド方式を採用するかは未決定。採用する場合は、連続バー表示とブロック表示を同じパラメーターで切り替えられる可能性がある。

次に再開する場合の確認候補:

- AviUtl2 を閉じた状態で `Aul2AudioMonitor.dproj` Release を再ビルドし、最新 `.aux2` を確実に反映する。AviUtl2 起動中は `.aux2` がロックされ、PostBuild のコピーだけ失敗する。
- `Base` ページで Width/Height/Sec/FPS を変更し、ボタン生成と D&D 生成の両方で `.aul2base` のファイル名に反映されるか確認する。
- 作成された `.aul2base` オブジェクトが、今後追加する表示/描画フィルター側から期待通りの width/height として取得できるか検証する。
- 表示/描画用フィルタープラグインプロジェクトとして `Aul2AudioView` を追加済み。次は `Aul2AudioBaseInput` 上でオブジェクトの width/height を取得できるか確認する。
- Base ページのボタン生成と D&D 生成で、作成されたオブジェクトに `Aul2Audio View` フィルターが自動追加されるか確認する。
- `Aul2AudioView` が `Aul2AudioBaseInput` の width/height でチェック背景と枠線を描けるか確認する。

## 2026-07-09 Aul2AudioMonitor 本採用メモ

- `Aul2AudioMonitor.aux2` は `Aul2AudioFilter.auf2` と同時配布する表示用拡張プラグインとして本採用。
- `.auf2` 側は音声処理コールバック内で入力解析、各エフェクト処理、出力解析の順に実行し、共有メモリへ表示用データを書き込む。
- `.aux2` 側は共有メモリを読むだけにし、音声処理や解析ロジックは持たない。描画/UI と AviUtl2 メニュー登録を担当する。
- 共有メモリ出力は常時有効。以前の検証用 `ENABLE_AUDIO_MONITOR_SHARED_MEMORY` const と `if` 分岐は削除し、通常機能として扱う。
- 初期表示は `Spectrum`。横軸は周波数、縦軸は強さ、64 バンド。`.aux2` は共有メモリ値を元に軽い減衰表示を行う。データなしを 0 にする必要がある場合は、描画側ではなく `.auf2` 側が 0 の表示データを書き込む方針にする。
- `Spectrum` 右側には入力/出力の L/R Peak Meter を縦バーで小さく表示する。表示は直近ピークの減衰方式で、頻繁な `wait` 切り替えによる点滅を避ける。
- `Spectrum` 右側下部には入力/出力の Stereo Balance を表示する。L/R RMS から左右の偏りを計算し、入力と出力を別色のマーカーで描く。
- `Wave` は時間軸波形として残す。横軸が時間、縦軸が振幅で、256 点の min/max 包絡線を描画する。
- 配色は DTM アプリ寄りの落ち着いた見た目を優先し、入力をグリーン、出力をアンバーとする。

## 2026-07-10 Aul2AudioView / Monitor 表示ずれメモ

- 最後のコミット状態へ戻した。今回のログ追加、Aul2AudioView のフレーム一致判定変更、Aul2AudioMonitor の保持ロジック変更、Debug 用ログユニット追加は取り消し済み。
- 現象として、Aul2AudioView はフィルター範囲内だけ正しく描画される。一方、Aul2AudioMonitor は共有メモリの最新音声データを表示する独立ウィンドウなので、タイムライン上の現在表示フレームと直接同期せず、音声先読みバッファ分だけ遅延または先行した表示に見える。
- Aul2AudioMonitor 側には Aul2AudioView のような「現在描画中の全体フレーム」が渡っていないため、同じ `SourceFrameS + SourceFrame` 照合をそのまま適用できない。Monitor を正確に同期させるには、現在の編集/再生フレームを別経路で取得するか、Monitor は「最新処理音声の観測窓」として扱う方針に分ける必要がある。
- Debug ビルドで Aul2AudioView を確認した際、表示処理中に範囲チェックエラーが出た。最後のコミットへ戻したため未修正。再調査する場合は、まず Debug range check と描画バッファアクセスの相性を確認する。

## 2026-07-10 Aul2AudioMonitor 再生時先読み対策メモ

- AviUtl2 SDK 54 の `EDIT_HANDLE` では `get_edit_state` が `restart_host_app` / `enum_effect_name` / `enum_module_info` / `get_host_app_window` の後ろにある。旧 Delphi 定義では `get_edit_info` の直後に `GetEditState` を置いていたため、`GetEditState` のつもりで `restart_host_app` を呼ぶ危険があった。`Source\Lib\AviUtl2Plugin\AviUtl2PluginTypes.pas` の `TEditHandle` は SDK 54 の順番に合わせて修正済み。
- `Aul2AudioMonitorView.pas` のツールバー右側に `State: Edit` / `State: Play` / `State: Save` 表示を追加した。再生状態の取得は描画処理中ではなく、`ReadTimer` 側で 500ms 間隔に抑えて行う。
- 再生時は `.auf2` 側の音声処理がプレビュー音声を大きく先読みし、共有メモリへ未来側のスペクトラムを書き込む。そのため `.aux2` の Monitor はそのまま最新値を描くと画面上の再生位置より先行して見える。
- 対策として、Monitor 側で共有メモリから読んだ `TAul2AudioMonitorState` / `TAul2AudioMonitorSpectrumState` を履歴配列へ保存し、`State: Play` の時だけ `PLAYBACK_DISPLAY_DELAY_MS` ms 前に近いスナップショットを描く。現在値は `Aul2AudioMonitorView.pas` の `PLAYBACK_DISPLAY_DELAY_MS = 3000`。実測では約 3 秒程度の遅延補正が必要だった。
- 履歴配列は 128 個。50ms タイマー基準では約 6.4 秒分を保持できる。遅延表示用に取り出したスナップショットは描画時点で stale 判定に落ちないよう `UpdateTick` を現在 tick に補正してから描画へ渡す。
- `Aul2AudioMonitorPaint.pas` に `ClearAudioMonitorDisplay` を追加し、描画側の保持値、ピーク、波形、スペクトラム、ステレオバランスを明示クリアできるようにした。
- クリアタイミングは「編集状態になった時」ではなく、「前回状態が `Edit` で今回状態が `Play` になった時」。この `Edit -> Play` 遷移時に再生遅延用履歴と描画保持バッファを両方クリアする。再生開始直後に遅延時間分の履歴がまだ無い場合は、古い保持値や最古履歴で代替表示せず `nil` を返し、画面が空になるようにしている。
- 編集中は最後の表示値を保持する方針を継続する。これは停止時やカーソル移動後に Monitor がすぐ空になりすぎるのを避けるため。再生時の先読み補正とは `State: Play` 判定で分けて扱う。
