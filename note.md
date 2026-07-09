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
- `Source\Aul2AudioMonitorPlugin.pas`: `Aul2AudioMonitor` の拡張メニュー登録、AviUtl2 クライアントウィンドウ登録、空フォーム表示の最小実装。
- `Source\Aul2AudioFilterPlugin.pas`: AviUtl2 へ公開するフィルター入口、各エフェクトユニットの接続。
- `Source\Aul2AudioFilterMonitorBridge.pas`: フィルター側から共有メモリへ入力/出力ピークなどの軽量解析値を書き出す入口。
- `Source\Aul2AudioFilterPluginPreset.pas`: `プリセット` GUI 項目、詳細エフェクト設定への反映処理。
- `Source\Aul2AudioFilterPluginDelay.pas`: Delay / Echo 系の GUI 項目、状態管理、音声処理。
- `Source\Aul2AudioFilterPluginChorus.pas`: Chorus 系の GUI 項目、状態管理、音声処理。
- `Source\Lib\Aul2AudioFilterTypes.pas`: AviUtl2 フィルター SDK の Delphi 型定義。
- `Source\Lib\Aul2AudioFilterGui.pas`: `SetupPluginTable` / `AddGroup` / `AddTrack` などの GUI 項目登録ライブラリ。
- `Source\Lib\AviUtl2Plugin`: Syncroh2 から UTF-8 でコピーした AviUtl2 汎用プラグイン SDK 型定義と共有状態。
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
`Aul2AudioMonitor` 側は 50ms タイマーで共有メモリを読み、初期表示は `Spectrum`。数値中心の疎通確認表示はちらつきが大きいため通常表示から外し、描画表示を主にする。`Spectrum` 右側には小型の縦 Peak Meter を常時表示する。

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
- Peak Meter は `Stage` による `wait` 表示切り替えで点滅しやすかったため、直近ピークを保持して減衰表示する。`TBitmap` へ描いてから `TPaintBox` へ転送し、非表示パネルは Invalidate しない。サイズが変わらない 50ms 更新では `SetBounds` / `Realign` しない。
- 音声処理が止まると `.auf2` は最後のスペクトラム値を書いたまま更新機会を失うため、`.aux2` 側で `Generation` 更新を監視する。
- `Spectrum` は自動減衰も描画側の stale 判定による 0 クリアも行わない。`.aux2` は共有メモリ上の現在値をそのまま描画する。`Generation` が止まっただけでは、音声処理更新周期や停止中のプレビュー状態を正しく判定できず、データがあるのに消えるため。
- 高速更新されるメーター/スペクトラムで赤と青/シアンの強い組み合わせは禁止。一般的な DTM アプリ寄りに、入力は落ち着いたグリーン、出力はアンバー/イエロー系を使う。
- 凡例は右上固定にすると狭い幅で欠けやすいため、スペクトラムでは左上に `Input` / `Output` を並べて表示する。

## Aul2AudioMonitor 表示拡張方針

- 表示モード候補:
  - `Waveform / Oscilloscope`: 横軸が時間、縦軸が振幅。現在実装済み。歪み、クリップ、ディレイ、トレモロなどの確認向け。
  - `Spectrum Analyzer`: 横軸が周波数、縦軸が強さ。EQ、こもり、ノイズ、低域/高域の量を見る本命。
  - `Level / Peak Meter`: L/R のピーク、ピークホールド、クリップ確認向け。現在は `Spectrum` 右側の小型縦メーターとして実装済み。
  - `RMS / Loudness Meter`: 瞬間ピークではなく体感音量寄りの確認向け。LUFS は実装が重めなので後回し。
  - `Pan / Stereo Balance`: L/R バランス、パン位置、中央定位の確認向け。
  - `Correlation Meter`: ステレオ位相相関。モノラル化で消えやすい音や逆相気味の音の確認向け。
  - `Vectorscope / Goniometer`: L/R を XY 表示し、ステレオ幅、中央定位、逆相を見やすくする。
  - `Spectrogram`: 横軸が時間、縦軸が周波数、色が強さ。声やノイズの時間変化に強いが、データ量と描画負荷が大きい。
- 優先度:
  1. `Spectrum Analyzer`
  2. `Pan / Stereo Balance`
  3. `Correlation Meter`
  4. `Vectorscope / Goniometer`
  5. `Spectrogram` / `LUFS`
- 共有メモリは基本状態/時間波形用の `Local\Aul2AudioMonitorState` と、スペクトラム専用の `Local\Aul2AudioMonitorSpectrum` に分ける。
- スペクトラムがメイン表示になり、追加表示や履歴データが増える可能性が高いため、最初からスペクトラムだけ別共有メモリにする。
- `Local\Aul2AudioMonitorState` は `Header`, `Wave`, `Meter`, `Stereo` などの軽量状態を持つ。
- `Local\Aul2AudioMonitorSpectrum` は `Header`, `InputBands`, `OutputBands` を持つ。現時点は 64 バンド。
- `.auf2` 側で音声から表示用データを軽量に集約し、`.aux2` 側は描画だけを担当する。
- 生の音声サンプル全体を共有メモリに載せない。Wave は 256 点程度、Spectrum は 64 または 128 バンド程度、Meter/Stereo は少数の集計値にする。
- 例外的に共有メモリ分割を検討するケース:
  - `Spectrogram` のように履歴を多く持ち、データ量が大きくなる場合。
  - 表示ごとに更新頻度が大きく違い、読み書き競合やコピー量が問題になる場合。
  - `.aux2` 以外の外部ツールや別プラグインが特定表示だけを読む場合。
  - バージョン互換を表示機能ごとに切り離したくなった場合。
- 現段階の `Wave`, `Level`, `Pan`, `Correlation`, `Vectorscope` 程度は基本状態側でよい。`Spectrum` と将来のスペクトラム派生表示はスペクトラム専用共有メモリ側へ寄せる。
- `.auf2` 側では 1024 サンプル上限、64 バンド、20Hz から Nyquist または 20kHz までのログ配置で簡易スペクトラムを作る。
- `.aux2` 側では `Spectrum` ページがスペクトラム専用共有メモリを読み、input をグリーン、output をアンバーの棒グラフで描画する。

## 2026-07-09 Aul2AudioMonitor 本採用メモ

- `Aul2AudioMonitor.aux2` は `Aul2AudioFilter.auf2` と同時配布する表示用拡張プラグインとして本採用。
- `.auf2` 側は音声処理コールバック内で入力解析、各エフェクト処理、出力解析の順に実行し、共有メモリへ表示用データを書き込む。
- `.aux2` 側は共有メモリを読むだけにし、音声処理や解析ロジックは持たない。描画/UI と AviUtl2 メニュー登録を担当する。
- 共有メモリ出力は常時有効。以前の検証用 `ENABLE_AUDIO_MONITOR_SHARED_MEMORY` const と `if` 分岐は削除し、通常機能として扱う。
- 初期表示は `Spectrum`。横軸は周波数、縦軸は強さ、64 バンド。`.aux2` は共有メモリ値を忠実に表示する。データなしを 0 にする必要がある場合は、描画側ではなく `.auf2` 側が 0 の表示データを書き込む方針にする。
- `Spectrum` 右側には入力/出力の L/R Peak Meter を縦バーで小さく表示する。表示は直近ピークの減衰方式で、頻繁な `wait` 切り替えによる点滅を避ける。
- `Wave` は時間軸波形として残す。横軸が時間、縦軸が振幅で、256 点の min/max 包絡線を描画する。
- 配色は DTM アプリ寄りの落ち着いた見た目を優先し、入力をグリーン、出力をアンバーとする。

## Aul2AudioMonitor 次段階の課題優先順位

1. `Spectrum` の視認性改善
   - 周波数目盛り、低域/中域/高域の薄い区切り、主要帯域の補助線を追加する。
   - エフェクト確認が目的なので、ピークホールドや残像表示は慎重に扱う。必要になってから任意表示として検討する。
   - 現状の入力グリーン/出力アンバーは採用継続。

2. `Pan / Stereo Balance`
   - L/R バランス、中央定位、片寄りを確認できるようにする。
   - ボイス系、Chorus、Ping-Pong Delay、Reverb など空間系エフェクトの確認に向く。
   - `Local\Aul2AudioMonitorState` 側へ L/R RMS または L/R Peak の集計値を追加して描画する方針。

3. `Correlation Meter`
   - ステレオ位相相関を表示し、逆相気味の音やモノラル化で消えやすい音を確認する。
   - 実用性は高いが、Peak/Pan より後でよい。
   - L/R サンプルの相関を `.auf2` 側で軽量集計し、`.aux2` 側はメーターとして描画する。

4. `Vectorscope / Goniometer`
   - L/R を XY 表示し、ステレオ幅や中央定位を直感的に見る表示。
   - 見た目は有用だが描画負荷と UI 面積を使うため、Correlation Meter の後に検討する。

5. `.auf2` 側の明示的 0 クリア設計
   - `.aux2` は共有メモリ値を忠実に表示し、データなしを推測しない。
   - 停止時や対象音声がない時に 0 表示が必要なら、`.auf2` 側が安全なタイミングで 0 の表示データを書き込む。
   - AviUtl2 の音声処理コールバックが止まる場面では `.auf2` 側も発火しない可能性があるため、必要性が見えてから検討する。
