# Aul2AudioFilter note

作業再開時に最初に見る開発メモ。ここには現在の方針、開発方法、コメントルール、ビルド方法を置く。

- 利用者向けの概要、配置、配布説明は `README.md` へ置く。
- 検証用 WAV の説明は `Sample\README.md` へ置く。
- 日付付きの作業記録や試行錯誤を残す場合は、将来 `HISTORY.md` を作って移す。

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
- `Sample\sine_440hz_1s.wav` を AviUtl2 へ読み込み、サウンドエフェクターを適用して WAV 出力した。
- 出力 WAV は `Sample\test_out.wav`。WAV 出力プラグインで 32bit float を選択した。
- `GetSampleData` で音声サンプルを受け取り、加工して `SetSampleData` で戻す基本経路は正常と判断する。
- 単発ディレイは正常。
- `Sample\impulse_1s.wav` を使い、`Delay: Time(ms) = 250`, `Delay: Dry = 1.0`, `Delay: Wet = 0.5` で出力した。
- 0 samples / 0.000s に元音約 `1.0`、11025 samples / 0.250s に遅延音約 `0.5` が出た。前後サンプルは 0。
- `Delay: Dry = 0.0`, `Delay: Wet = 1.0` では、0 samples が 0、11025 samples / 0.250s に約 `1.0` の遅延音だけが出た。
- `Delay: Use` を追加し、OFF の時はディレイ処理をバイパスして内部バッファをクリアする設計にした。
- `Delay: Feedback` を追加した。初期値は `0.0` で、単発ディレイと同じ挙動を保つ。
- エコー確認は `Sample\impulse_1s.wav` を使い、`Delay: Time(ms) = 250`, `Delay: Dry = 1.0`, `Delay: Wet = 1.0`, `Delay: Feedback = 0.5` を想定する。
- 期待値は 0 samples に約 `1.0`、11025 samples に約 `1.0`、22050 samples に約 `0.5`、33075 samples に約 `0.25`。
- エコー（Feedback）は正常。
- `Delay: Time(ms) = 250`, `Delay: Dry = 1.0`, `Delay: Wet = 1.0`, `Delay: Feedback = 0.5` で出力した。
- 0 samples / 0.000s に約 `1.0`、11025 samples / 0.250s に約 `1.0`、22050 samples / 0.500s に約 `0.5`、33075 samples / 0.750s に約 `0.25` が出た。
- `Delay: Stereo Mode` を追加した。選択肢は `Normal` と `Ping-Pong`。
- `Normal` は従来通り L/R を独立して処理する。
- `Ping-Pong` は L/R のディレイバッファを交差させ、左入力が右へ、右入力が左へ返るようにする。
- Ping-Pong は正常。
- `Sample\stereo_impulse_lr_1s.wav` を使い、`Delay: Time(ms) = 250`, `Delay: Dry = 1.0`, `Delay: Wet = 1.0`, `Delay: Feedback = 0.5`, `Delay: Stereo Mode = Ping-Pong` で出力した。
- 0.100s に左元音、0.200s に右元音、0.350s に左入力由来の右ディレイ、0.450s に右入力由来の左ディレイが出た。
- Feedback により 0.600s / 0.700s に約 `0.5`、0.850s / 0.950s に約 `0.25` が左右交互に出た。
- Delay 仕上げとして、`Delay: Use` OFF 時は内部バッファをクリアする。
- `Delay: Stereo Mode` 変更時も内部バッファをリセットし、`Normal` と `Ping-Pong` の状態が混ざらないようにする。
- `Chorus` を追加した。
- `Chorus: Use` 初期値は OFF。ON の時だけ Delay 後段で処理する。
- `Chorus: Delay(ms) = 15.0`, `Chorus: Depth(ms) = 5.0`, `Chorus: Rate(Hz) = 0.5`, `Chorus: Mix = 0.5` を初期値にした。
- コーラスは短い可変ディレイとして実装し、LFO 位相は `SampleIndex` から計算する。
- 小数サンプル位置は線形補間で読む。
- 検証は `Sample\sine_440hz_1s.wav` を使い、出力が元波形と一致しないこと、Peak/RMS が異常値にならないこと、NaN が出ないことをまず確認する。
- `Chorus: Stereo Mode` を追加した。選択肢は `Normal` と `Wide`。
- `Wide` は右チャンネルの LFO 位相を 180 度ずらし、左右の揺れを反対にする。
- Stereo Chorus の検証は `Sample\sine_440hz_1s.wav` で `Chorus: Stereo Mode = Wide` にし、L/R が同一波形ではなくなること、Peak/RMS が異常値にならないことを確認する。

## プロジェクト構成

- `Aul2AudioFilter.dpr`: AviUtl2 へ `GetFilterPluginTable` などを export する入口。各ユニットは `Source\...` の相対パスで参照する。
- `Aul2AudioFilter.dproj`: Delphi Win64 Debug / Release ビルド設定。
- `Source\Aul2AudioFilterPlugin.pas`: AviUtl2 へ公開するフィルター入口、各エフェクトユニットの接続。
- `Source\Aul2AudioFilterPluginPreset.pas`: `プリセット` GUI 項目、詳細エフェクト設定への反映処理。
- `Source\Aul2AudioFilterPluginDelay.pas`: Delay / Echo 系の GUI 項目、状態管理、音声処理。
- `Source\Aul2AudioFilterPluginChorus.pas`: Chorus 系の GUI 項目、状態管理、音声処理。
- `Source\Lib\Aul2AudioFilterTypes.pas`: AviUtl2 フィルター SDK の Delphi 型定義。
- `Source\Lib\Aul2AudioFilterGui.pas`: `SetupPluginTable` / `AddGroup` / `AddTrack` などの GUI 項目登録ライブラリ。
- `Source\Legacy`: 現在のビルドでは使わない旧コピーの退避場所。
- `Sample`: 正弦波、矩形波、インパルスなどの検証用 WAV を置く。
- `Win64`: Delphi の Debug / Release 中間出力。

## 検証サンプル

- エフェクター確認用の入力 WAV は `Sample` に置く。
- AviUtl2 からテスト出力した WAV は原則として `Sample\test_out.wav` に出力する。
- `Sample\test_out.wav` は検証ごとに上書きされる作業用ファイルとして扱う。
- サンプル WAV の利用者向け説明は `Sample\README.md` に置く。
- 再開時に必要な検証上の細かい仕様や不足サンプルの課題は `note.md` に追記してよい。

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

## 今後の声向け機能候補

- 追加プリセット候補は `風邪`、`ロボ`、`恐怖`、`叫び`、`ささやき`、`水中`、`男性寄り`、`女性寄り`、`壁越し`、`遠く`、`夢/回想`。
- `風邪`: ガラガラした声。EQ、Noise、Distortion、Tremble、Whisper/Breath を組み合わせる候補。
- `ロボ`: 機械がしゃべる感じ。棒読みは音声合成ソフト側で作る前提とし、こちらは RingMod、PitchStep、BitCrusher、EQ で機械質を作る。
- `恐怖`: 声が震えている感じ。Tremble、Wobble、Reverb、EQ を組み合わせる候補。
- `叫び`: 音圧を上げ、割れそうで割れない圧のある声。VoiceDrive、Compressor、Limiter、Output Gain を使う候補。
- `ささやき`: ヒソヒソ声。Whisper/Breath、EQ、Noise、Compressor、Limiter を使う候補。
- `水中`: 水中でしゃべっている感じ。Muffle、Wobble、Chorus、Reverb、EQ を使う候補。
- `男性寄り` / `女性寄り`: PitchShift と FormantShift が必要。単純なピッチ変更だけでは声質が不自然になりやすい点に注意する。
- 追加エフェクト候補は優先度順に `Output Gain`、`Tremble`、`Whisper/Breath`、`VoiceDrive`、`Wobble`、`PitchShift`、`FormantShift`、`RingMod`、`PitchStep`、`Muffle`、`AutoGain`、`NoiseGate`、`ReverseReverb/Ghost`。
- `Output Gain`: 最終段の手動音量調整。`Output: Gain(dB)` を基本項目にする。Limiter より前に置く。
- `Tremble`: 細かい音量揺れやピッチ揺れで、恐怖、風邪、水中、夢/回想に使い回す。
- `Whisper/Breath`: 息成分やヒソヒソ感を足し、ささやきや風邪に使う。
- `VoiceDrive`: 声の圧、叫び、荒さを作る。既存 Distortion より声用途に寄せる。
- `Wobble`: ゆっくりした揺らぎを作り、水中、夢/回想、恐怖に使う。
- `PitchShift` / `FormantShift`: 男性声を女性寄り、女性声を男性寄りにする中核候補。ただし実装難度が高いため、品質を確認しながら進める。

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
```

ビルド後イベントで生成された `.dll` を `.auf2` にコピーし、元の `.dll` を削除する。Release では `.rsm` も削除する。

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
- 完了済みの作業履歴を長く残す必要が出たら `HISTORY.md` を作る。
- 共通化できる処理は `Source\Lib` へ移す。
- 検証用の音声素材や生成スクリプトは `Sample` へ置く。

## Preset implementation note

- `スタイル` は初心者向けの入口としては分かりやすいが、選択後に微調整できない弱点があるため廃止した。
- 以後は `プリセット` を採用し、GUI 最上段に日本語セレクト項目 `プリセット` を置く。
- `プリセット` は音声を直接処理しない。選択後に `プリセット適用` ボタンを押すと、詳細エフェクトのパラメータへ反映する。
- `Aul2AudioFilterPluginPreset.pas` を追加した。
- `Aul2AudioFilterPlugin.pas` は `AddPresetItems` の呼び出しだけを持ち、メイン部分を肥大化させない。
- プリセット名は用途名にし、適用後に微調整できるため `（大）` などの強弱表記は使わない。
- 現在の選択肢は `なし`、`エコー`、`反響`、`ホール`、`空間`、`ナレーション`、`電話`、`無線`、`拡声器`、`劣化`。
- `エコー` と `反響` は `Delay` を使う。
- `ホール` は `Reverb`、`空間` は `Chorus` を使う。
- `ナレーション` は `EQ`、`Compressor`、`Limiter` を使う。
- `電話` は `EQ`、`Distortion`、`BitCrusher` を使う。
- `無線` は `EQ`、`Distortion`、`Noise`、`BitCrusher`、`Limiter` を使う。
- `拡声器` は `EQ`、`Compressor`、`Distortion`、`Limiter` を使う。
- `劣化` は `EQ`、`Noise`、`BitCrusher` を使う。
- `なし` を適用した場合は、プリセット管理対象の詳細エフェクトを既定値へ戻して OFF にする。
- 前回プリセットのエフェクトが残らないよう、プリセット適用時はいったん全対象エフェクトを既定OFFへ戻してから必要なエフェクトだけONにする。
- SDK の `FILTER_ITEM_SELECT` は本体からプラグインへ現在値が渡る向きで、選択だけでは他項目のGUI表示を直接更新できない。
- `プリセット適用` ボタンのコールバックから `EDIT_SECTION.set_object_item_value()` を使うと、AviUtl2 側の設定値を書き換えられる。
- ボタン方式では `プリセット` を選んだだけでは詳細パラメータを変更せず、手動調整を不意に上書きしない。
- 処理分岐には、後から意図を追いやすいよう日本語コメントを置く。

## Reverb implementation note

- `Aul2AudioFilterPluginReverb.pas` を追加した。
- `Aul2AudioFilterPlugin.pas` は `AddReverbItems` と `ProcessReverb` の呼び出しだけを持ち、リバーブ固有の GUI 項目、状態バッファ、音声処理は専用ユニットへ分離する。
- パラメーターは `Reverb: Use`, `Reverb: RoomSize`, `Reverb: Damping`, `Reverb: Dry`, `Reverb: Wet`。
- 実装は複数の短い feedback comb delay を並列に使う簡易リバーブ。`RoomSize` は feedback 量、`Damping` は feedback 側の one-pole low-pass として扱う。
- `Reverb: Use` が OFF のときは内部状態をクリアする。
- Release Win64 ビルド成功。`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2` へコピー済み。
- `Sample\impulse_tail_3s.wav` を使い、リバーブ初期値の出力を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 3.0s。
- `Reverb: Use` ON、初期値 `RoomSize = 0.5`, `Damping = 0.4`, `Dry = 1.0`, `Wet = 0.3` で、先頭の直音後に残響テールが出ることを確認した。
- Peak は L/R とも約 `0.999969482`、NaN/Inf はなし。`abs >= 0.0001` の残響は L が約 `0.3497s`、R が約 `0.3609s` まで残った。
- L/R の comb delay 差により左右差が出ることを確認した。L/R 最大差は約 `0.044998627`。
- `Reverb: RoomSize = 0.1` を確認した。Peak は L/R とも約 `0.999969482`、NaN/Inf はなし。`abs >= 0.0001` の残響は L が約 `0.1749s`、R が約 `0.1805s` までで、初期値より短くなった。
- `Reverb: RoomSize = 0.9` を確認した。Peak は L/R とも約 `0.999969482`、NaN/Inf はなし。`abs >= 0.0001` の残響は L が約 `0.7868s`、R が約 `0.8121s` までで、初期値より長くなった。`abs >= 0.000001` では L が約 `1.5736s`、R が約 `1.6242s` まで残った。
- `Reverb: Damping = 0.0` を確認した。Peak は L/R とも約 `0.999969482`、NaN/Inf はなし。`abs >= 0.0001` の残響は L が約 `0.4807s`、R が約 `0.4961s` までで、初期値 `Damping = 0.4` より強い反射が長く残った。
- `Reverb: Damping = 0.8` を確認した。Peak は L/R とも約 `0.999969482`、NaN/Inf はなし。`abs >= 0.0001` の残響は L が約 `0.2627s`、R が約 `0.2712s` までで、初期値 `Damping = 0.4` より反射が弱く短くなった。
- `Reverb: Wet = 0.0` を確認した。出力は `Sample\impulse_tail_3s.wav` と完全一致した。L/R とも差分最大値 `0`、`abs >= 0.0001` のサンプルは先頭インパルスのみ。
- `Reverb: Dry = 0.0`, `Reverb: Wet = 1.0` を確認した。前半は直音が出ず、L は約 `29.7ms`、R は約 `31.1ms` から残響音だけが出た。前半 Peak は L/R とも約 `0.149995416`、NaN/Inf はなし。
- 同じ設定の後半で `Reverb: Use = OFF` にした出力は `Sample\impulse_tail_3s.wav` と完全一致した。L/R とも差分最大値 `0`。Use OFF 時にリバーブ状態が混入しないことを確認した。
- 以上により、現在の簡易リバーブは基本機能完成扱いとする。今後の拡張候補は `Reverb: Type` による `Room` / `Hall` / `Plate` などのタイプ選択、または all-pass 追加による残響密度の向上。
- `Reverb: Type` を追加した。選択肢は `Room`, `Hall`, `Plate`。
- `Room` は短めの反射と控えめな feedback、`Hall` は従来に近い長めの反射と強めの feedback、`Plate` は短めで明るい反射として扱う。
- Type 変更時は delay line の長さが変わるため、内部リバーブ状態をリセットする。
- `ホール` プリセットは `Reverb: Type = Hall` を設定する。
- Release Win64 ビルド成功。`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2` へコピー済み。

## EQ implementation note

- ユーザー向け簡単エフェクト実現の最優先課題として `EQ` を追加した。
- `Aul2AudioFilterPluginEq.pas` を追加し、メインの `Aul2AudioFilterPlugin.pas` は `AddEqItems` と `ProcessEq` の呼び出しだけを持つ。
- パラメーターは `EQ: Use`, `EQ: Mode`, `EQ: LowCut(Hz)`, `EQ: HighCut(Hz)`, `EQ: Mix`。
- `EQ: Mode` は `Low Cut`, `High Cut`, `Band Pass`。
- 初期値は `EQ: Use` OFF、`EQ: Mode = Band Pass`, `LowCut = 300Hz`, `HighCut = 3400Hz`, `Mix = 1.0`。
- 実装は one-pole low-pass を基本にし、`Low Cut` は low-pass 状態との差分で high-pass を作る。
- `Band Pass` は low cut 後に high cut を通す。
- `Band Pass` で `HighCut <= LowCut` になった場合は、内部的に `HighCut = LowCut + 1Hz` として破綻を避ける。
- `EQ: Use` OFF 時、対象オブジェクト変更時、非連続サンプル位置、サンプルレート変更、チャンネル数変更、モード変更時は内部状態をリセットする。
- 処理順は `Delay` の後、`Chorus` / `Reverb` の前。
- Release Win64 ビルド成功。`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2` へコピー済み。
- `Sample\square_440hz_1s.wav` で `EQ: Mode = High Cut`, `HighCut = 1000Hz`, `Mix = 1.0` を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 1.0s。
- 入力は Peak/RMS とも L/R 約 `0.5`。出力は L/R Peak 約 `0.459754`、RMS 約 `0.322801`、NaN なし。
- 440Hz 成分は約 `-2.90dB`、2200Hz / 3080Hz / 4840Hz 付近の高域成分は約 `-43dB` まで落ちた。
- L/R は同一結果で、矩形波の角が丸まる High Cut として正常と判断する。
- `Sample\sine_440hz_1s.wav` で `EQ: Mode = Band Pass`, `LowCut = 300Hz`, `HighCut = 3400Hz`, `Mix = 1.0` を確認した。
- 出力は L/R Peak 約 `0.414991`、RMS 約 `0.282386`、NaN なし。440Hz 成分は約 `-1.97dB` で、通過帯域内の信号として大きく消えないことを確認した。
- 以上により、現在の簡易 EQ は基本機能完成扱いとする。
- 今後の改善候補は、カット特性を強くする 2 段化、または biquad EQ への置き換え。
- EQ の内部実装を one-pole から 2 次 biquad に置き換えた。GUI パラメーターは従来通り `EQ: Use`, `EQ: Mode`, `EQ: LowCut(Hz)`, `EQ: HighCut(Hz)`, `EQ: Mix` のまま。
- `Low Cut` は Butterworth 相当の high-pass、`High Cut` は Butterworth 相当の low-pass、`Band Pass` は high-pass 後に low-pass を通す構成。
- biquad 出力が NaN/Inf になった場合は対象フィルター状態をクリアし、異常値を後段へ流さない。
- Release Win64 ビルド成功。`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2` へコピー済み。

## Compressor implementation note

- ユーザー向け簡単エフェクト実現の優先課題として `Compressor` を追加した。
- `Aul2AudioFilterPluginCompressor.pas` を追加し、メインの `Aul2AudioFilterPlugin.pas` は `AddCompressorItems` と `ProcessCompressor` の呼び出しだけを持つ。
- パラメーターは `Compressor: Use`, `Compressor: Threshold(dB)`, `Compressor: Ratio`, `Compressor: Attack(ms)`, `Compressor: Release(ms)`, `Compressor: Makeup(dB)`, `Compressor: Mix`。
- 初期値は `Compressor: Use` OFF、`Threshold = -18dB`, `Ratio = 4.0`, `Attack = 10ms`, `Release = 120ms`, `Makeup = 0dB`, `Mix = 1.0`。
- 実装はチャンネルごとの envelope follower で入力レベルを検出し、しきい値を超えた分を Ratio に応じて下げる。
- `Compressor: Use` OFF 時、対象オブジェクト変更時、非連続サンプル位置、サンプルレート変更、チャンネル数変更時は内部状態をリセットする。
- 処理順は `EQ` の後、`Chorus` / `Reverb` の前。
- `Sample\level_steps_3s.wav` で `Threshold = -12dB`, `Ratio = 4.0`, `Attack = 5ms`, `Release = 120ms`, `Makeup = 0dB`, `Mix = 1.0` を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 3.0s。
- 0-1s の振幅 0.1 区間は Peak/RMS とも変化なし。
- 1-2s の振幅 0.5 区間は RMS が約 `0.353542` から約 `0.284857` へ下がった。
- 2-3s の振幅 0.9 区間は RMS が約 `0.636376` から約 `0.371657` へ下がった。
- 大きい音ほど RMS が下がるため、コンプレッサーとしての基本動作は正常と判断する。
- Peak は各区間で入力と同じ最大値が残るため、ピーク抑制は次の `Limiter` で扱う。

## Limiter implementation note

- ユーザー向け簡単エフェクト実現の優先課題として `Limiter` を追加した。
- `Aul2AudioFilterPluginLimiter.pas` を追加し、メインの `Aul2AudioFilterPlugin.pas` は `AddLimiterItems` と `ProcessLimiter` の呼び出しだけを持つ。
- パラメーターは `Limiter: Use`, `Limiter: Ceiling(dB)`, `Limiter: Release(ms)`, `Limiter: Mix`。
- 初期値は `Limiter: Use` OFF、`Ceiling = -1dB`, `Release = 50ms`, `Mix = 1.0`。
- 実装はサンプルごとのピークを見て、`Ceiling` を超える場合は即座にゲインを下げ、超えない場合は `Release` に従って 1.0 へ戻す。
- `Limiter: Use` OFF 時、対象オブジェクト変更時、非連続サンプル位置、サンプルレート変更、チャンネル数変更時は内部状態をリセットする。
- 処理順は `Compressor` の後、`Chorus` / `Reverb` の前。
- `Sample\level_steps_3s.wav` で `Ceiling = -6dB`, `Release = 50ms`, `Mix = 1.0` を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 3.0s。
- 0-1s の振幅 0.1 区間と 1-2s の振幅 0.5 区間は Peak/RMS とも入力と同じで、Ceiling 未満の音は変化しなかった。
- 2-3s の振幅 0.9 区間は Peak が約 `0.899963` から約 `0.501351` へ下がり、ほぼ `-6dB` に収まった。
- 2-3s の RMS は約 `0.636376` から約 `0.357988` へ下がった。
- 以上により、Limiter の基本動作は正常と判断する。

## Distortion implementation note

- ユーザー向け簡単エフェクト実現の優先課題として `Distortion` を追加した。
- `Aul2AudioFilterPluginDistortion.pas` を追加し、メインの `Aul2AudioFilterPlugin.pas` は `AddDistortionItems` と `ProcessDistortion` の呼び出しだけを持つ。
- パラメーターは `Distortion: Use`, `Distortion: Mode`, `Distortion: Drive(dB)`, `Distortion: Tone`, `Distortion: Level(dB)`, `Distortion: Mix`。
- `Distortion: Mode` は `Soft Clip`, `Hard Clip`。
- 初期値は `Distortion: Use` OFF、`Mode = Soft Clip`, `Drive = 6dB`, `Tone = 1.0`, `Level = -6dB`, `Mix = 1.0`。
- `Soft Clip` は `tanh` でなだらかに歪ませる。
- `Hard Clip` は `-1.0` から `1.0` の範囲へ直接切り詰める。
- `Tone` は歪み音の強さを元音へ少し戻す簡易的な明るさ調整として扱う。
- 処理順は `Compressor` の後、`Limiter` の前。歪みで増えたピークは後段の `Limiter` で抑える。
- `Sample\sine_440hz_1s.wav` で `Mode = Soft Clip`, `Drive = 18dB`, `Tone = 1.0`, `Level = -12dB`, `Mix = 1.0` を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 1.0s。
- 入力は L/R Peak 約 `0.499969`、RMS 約 `0.353542`。出力は L/R Peak 約 `0.251010`、RMS 約 `0.229462`、NaN なし。
- 3 次倍音 1320Hz が約 `0.084257`、5 次倍音 2200Hz が約 `0.035336`、7 次倍音 3080Hz が約 `0.015940` 出ており、Soft Clip として奇数倍音が増えることを確認した。
- 以上により、Distortion の Soft Clip 基本動作は正常と判断する。
- `Sample\sine_440hz_1s.wav` で `Mode = Hard Clip`, `Drive = 18dB`, `Tone = 1.0`, `Level = -12dB`, `Mix = 1.0` を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 1.0s。
- 出力は L/R Peak 約 `0.251189`、RMS 約 `0.237296`、NaN なし。
- 3 次倍音 1320Hz が約 `0.096631`、5 次倍音 2200Hz が約 `0.048176`、7 次倍音 3080Hz が約 `0.025241` 出ており、Soft Clip より強い奇数倍音が出ることを確認した。
- 波形先頭でも `0.251189` 付近へ平らに切り詰められており、Hard Clip 基本動作は正常と判断する。

## Noise implementation note

- ユーザー向け簡単エフェクト実現の優先課題として `Noise` を追加した。
- `Aul2AudioFilterPluginNoise.pas` を追加し、メインの `Aul2AudioFilterPlugin.pas` は `AddNoiseItems` と `ProcessNoise` の呼び出しだけを持つ。
- パラメーターは `Noise: Use`, `Noise: Mode`, `Noise: Level(dB)`, `Noise: Mix`。
- `Noise: Mode` は `White`, `Crackle`。
- 初期値は `Noise: Use` OFF、`Mode = White`, `Level = -36dB`, `Mix = 1.0`。
- `White` は疑似乱数によるホワイトノイズを足す。
- `Crackle` は小さいホワイトノイズを基本にし、まれに大きめのノイズ粒を混ぜる。
- 処理順は `Distortion` の後、`Limiter` の前。追加したノイズのピークは後段の `Limiter` で抑えられる。
- `Sample\sine_440hz_1s.wav` で `Mode = White`, `Level = -36dB`, `Mix = 1.0` を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 1.0s。
- 入力は L/R Peak 約 `0.499969`、RMS 約 `0.353542`。出力は L/R Peak 約 `0.5158`、RMS 約 `0.35366`、NaN なし。
- 出力と入力の差分は L/R とも Peak 約 `0.01584`、RMS 約 `0.0091` で、`Level = -36dB` 相当の小さいノイズが足された。
- L/R 差分 RMS は約 `0.01307` で、左右に同一ではないノイズが乗ることを確認した。
- 以上により、Noise の White 基本動作は正常と判断する。
- `Sample\sine_440hz_1s.wav` で `Mode = Crackle`, `Level = -30dB`, `Mix = 1.0` を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 1.0s。
- 出力は L Peak 約 `0.527312`、R Peak 約 `0.526943`、L/R RMS 約 `0.35356`、NaN なし。
- 出力と入力の差分は L Peak 約 `0.029906`、R Peak 約 `0.031112` で、`Level = -30dB` 付近の大きめのノイズ粒が出た。
- 差分 RMS は L 約 `0.003332`、R 約 `0.003612` で、White より常時成分が小さく、突発ノイズ寄りの挙動になった。
- 以上により、Noise の Crackle 基本動作は正常と判断する。

## BitCrusher implementation note

- ユーザー向け簡単エフェクト実現の優先課題として `BitCrusher` を追加した。
- `Aul2AudioFilterPluginBitCrusher.pas` を追加し、メインの `Aul2AudioFilterPlugin.pas` は `AddBitCrusherItems` と `ProcessBitCrusher` の呼び出しだけを持つ。
- パラメーターは `BitCrusher: Use`, `BitCrusher: BitDepth`, `BitCrusher: SampleHold`, `BitCrusher: Mix`。
- 初期値は `BitCrusher: Use` OFF、`BitDepth = 8`, `SampleHold = 4`, `Mix = 1.0`。
- `BitDepth` は振幅方向の段階数を粗くする。
- `SampleHold` は指定サンプル数だけ同じ値を出し続け、時間方向の解像度を粗くする。
- `BitCrusher: Use` OFF 時、対象オブジェクト変更時、非連続サンプル位置、チャンネル数変更時は内部状態をリセットする。
- 処理順は `Noise` の後、`Limiter` の前。粗くした音のピークは後段の `Limiter` で抑えられる。
- `Sample\sine_440hz_1s.wav` で `BitDepth = 4`, `SampleHold = 8`, `Mix = 1.0` を確認した。
- 出力 WAV は `Sample\test_out.wav`。44100Hz / stereo / 32bit float / 1.0s。
- 入力は L/R Peak 約 `0.499969`、RMS 約 `0.353542`。出力は L/R Peak 約 `0.428571`、RMS 約 `0.335727`、NaN なし。
- 出力の値は L/R とも `-0.428571`, `-0.285714`, `-0.142857`, `0`, `0.142857`, `0.285714`, `0.428571` の 7 段階になり、4bit 相当の量子化を確認した。
- 出力先頭では同じ値が 8 サンプル単位で保持され、`SampleHold = 8` の基本動作を確認した。
- 440Hz 以外の高域成分も増えており、BitCrusher の基本動作は正常と判断する。

## Output / Tremble / Whisper / VoiceDrive / Wobble implementation note

- 優先度順に `Output Gain`, `Tremble`, `Whisper/Breath`, `VoiceDrive`, `Wobble` を追加した。
- `Aul2AudioFilterPluginOutput.pas` を追加し、メインの `Aul2AudioFilterPlugin.pas` は `AddOutputItems` と `ProcessOutput` の呼び出しだけを持つ。
- `Output` のパラメーターは `Output: Use`, `Output: Gain(dB)`。
- `Output: Gain(dB)` は `-24dB` から `+24dB` の手動出力音量調整として扱う。
- 処理順は `Limiter` の直前。音量を上げた後のピーク保護を後段 Limiter に任せる。
- `Aul2AudioFilterPluginTremble.pas` を追加した。
- `Tremble` のパラメーターは `Tremble: Use`, `Tremble: Rate(Hz)`, `Tremble: Depth`, `Tremble: Mix`。
- `Tremble` は `SampleIndex` から計算した LFO で音量を周期的に下げる。音量を持ち上げないため、ピークを増やしにくい。
- `Aul2AudioFilterPluginWhisper.pas` を追加した。
- `Whisper/Breath` のパラメーターは `Whisper/Breath: Use`, `Whisper/Breath: Level(dB)`, `Whisper/Breath: Tone`, `Whisper/Breath: Mix`。
- `Whisper/Breath` は入力音量に追従する envelope follower と疑似乱数ノイズで息成分を足す。無音部へ常時ノイズが乗りにくい設計にした。
- `Whisper/Breath: Tone` は息成分の明るさを変える簡易パラメーターとして扱う。
- `Aul2AudioFilterPluginVoiceDrive.pas` を追加した。
- `VoiceDrive` のパラメーターは `VoiceDrive: Use`, `VoiceDrive: Drive(dB)`, `VoiceDrive: Body`, `VoiceDrive: Level(dB)`, `VoiceDrive: Mix`。
- `VoiceDrive` は既存 `Distortion` より声の押し出し向けにし、低域状態を少し混ぜてから `tanh` でサチュレーションする。
- 処理順は `Compressor` の後、既存 `Distortion` の前。
- `Aul2AudioFilterPluginWobble.pas` を追加した。
- `Wobble` のパラメーターは `Wobble: Use`, `Wobble: Delay(ms)`, `Wobble: Depth(ms)`, `Wobble: Rate(Hz)`, `Wobble: Mix`。
- `Wobble` は短い可変ディレイとして実装し、`Chorus` より遅く深い時間揺れを作る。
- 処理順は `Tremble` の後、`Whisper/Breath` の前。
- `Aul2AudioFilterPluginPreset.pas` のプリセットリセット対象に、追加した各エフェクトの既定値を加えた。
- 現時点では既存プリセットへ新エフェクトを積極的には組み込まず、詳細パラメーターとして手動調整できる状態にした。
- Release Win64 ビルド成功。`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2` へコピー済み。
- 次の候補は `PitchShift` / `FormantShift`。実装難度が上がるため、品質確認しながら別区切りで進める。

## PitchShift / FormantShift implementation note

- `Aul2AudioFilterPluginPitchShift.pas` を追加した。
- `PitchShift` のパラメーターは `PitchShift: Use`, `PitchShift: Semitone`, `PitchShift: Window(ms)`, `PitchShift: Mix`。
- `PitchShift: Semitone` は `-12` から `+12` までの半音単位として扱う。
- 実装は二重可変ディレイのクロスフェード方式。読み出しディレイを周期的に増減させて、再生時間を変えずに音程を変える簡易方式にした。
- `PitchShift: Window(ms)` は可変ディレイの窓長で、短いほど反応は速いが荒れやすく、長いほど滑らかだが遅れ感が出やすい。
- `PitchShift: Use` OFF 時、対象オブジェクト変更時、非連続サンプル位置、チャンネル数変更、窓長変更時は内部状態をリセットする。
- `Aul2AudioFilterPluginFormantShift.pas` を追加した。
- `FormantShift` のパラメーターは `FormantShift: Use`, `FormantShift: Shift`, `FormantShift: Amount`, `FormantShift: Mix`。
- 現在の `FormantShift` は本格的なフォルマント解析ではなく、低域成分と高域成分の重心を動かす簡易声色補正として実装した。
- `FormantShift: Shift` が正なら軽く明るい方向、負なら低く太い方向へ寄せる。
- 処理順は `Wobble` の後、`Whisper/Breath` の前。
- プリセットに `男性寄り` と `女性寄り` を追加した。
- `男性寄り` は `PitchShift: Semitone = -3`, `FormantShift: Shift = -4` を中心に、軽い EQ と Limiter を組み合わせる。
- `女性寄り` は `PitchShift: Semitone = +3`, `FormantShift: Shift = +4` を中心に、軽い EQ と Limiter を組み合わせる。
- Release Win64 ビルド成功。`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2` へコピー済み。
- 今後の改善候補は、`PitchShift` の窓つなぎ品質の確認、声素材での `男性寄り` / `女性寄り` プリセット値調整、より本格的な Formant 処理への置き換え。
- 次の追加候補は `RingMod`。

## Additional voice effect implementation note

- 必要候補の追加を進め、`RingMod`, `PitchStep`, `Muffle`, `AutoGain`, `NoiseGate`, `ReverseReverb/Ghost` を追加した。
- `Aul2AudioFilterPluginRingMod.pas` を追加した。
- `RingMod` のパラメーターは `RingMod: Use`, `RingMod: Frequency(Hz)`, `RingMod: Depth`, `RingMod: Mix`。
- `RingMod` は `SampleIndex` から計算したサイン波で振幅変調し、ロボットや機械質の声に使う。
- `Aul2AudioFilterPluginPitchStep.pas` を追加した。
- `PitchStep` のパラメーターは `PitchStep: Use`, `PitchStep: Step(semitone)`, `PitchStep: Rate(Hz)`, `PitchStep: Mix`。
- `PitchStep` は二重可変ディレイ方式を使い、指定レートで上下のピッチを交互に切り替える。
- `Aul2AudioFilterPluginMuffle.pas` を追加した。
- `Muffle` のパラメーターは `Muffle: Use`, `Muffle: Cutoff(Hz)`, `Muffle: Amount`, `Muffle: Mix`。
- `Muffle` は 2 段 one-pole low-pass を使い、水中、壁越し、遠い声などのこもりを作る。
- `Aul2AudioFilterPluginAutoGain.pas` を追加した。
- `AutoGain` のパラメーターは `AutoGain: Use`, `AutoGain: Target(dB)`, `AutoGain: Speed(ms)`, `AutoGain: MaxGain(dB)`, `AutoGain: Mix`。
- `AutoGain` は envelope follower で入力レベルを追い、目標レベルへ緩やかに近づける。ノイズや残響を持ち上げやすいため初期値は OFF のままとする。
- `Aul2AudioFilterPluginNoiseGate.pas` を追加した。
- `NoiseGate` のパラメーターは `NoiseGate: Use`, `NoiseGate: Threshold(dB)`, `NoiseGate: Attack(ms)`, `NoiseGate: Release(ms)`, `NoiseGate: Floor(dB)`。
- `NoiseGate` は小さい音を `Floor(dB)` まで抑え、ささやきやノイズ混じり素材の後処理に使う。
- `Aul2AudioFilterPluginGhost.pas` を追加した。
- GUI 名は `ReverseReverb/Ghost`。パラメーターは `ReverseReverb/Ghost: Use`, `ReverseReverb/Ghost: Size(ms)`, `ReverseReverb/Ghost: Feedback`, `ReverseReverb/Ghost: Wet`, `ReverseReverb/Ghost: Mix`。
- 現在の `ReverseReverb/Ghost` はリアルタイム処理の制約上、厳密な逆再生リバーブではなく、履歴バッファから遅れた残響影を作るゴースト系エフェクトとして扱う。
- 処理順は `PitchShift` / `FormantShift` 後に、`RingMod`, `PitchStep`, `Muffle`, `Whisper/Breath`, `AutoGain`, `NoiseGate`, `ReverseReverb/Ghost`, `Output`, `Limiter` とした。
- 追加プリセットとして `ロボ`, `恐怖`, `叫び`, `ささやき`, `水中`, `壁越し`, `夢/回想` を追加した。
- `風邪`, `遠く` は専用プリセットとしては未追加。既存の `ささやき`, `壁越し`, `Muffle`, `Noise`, `Whisper/Breath` などの組み合わせで近い調整は可能。
- Release Win64 ビルド成功。`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2` へコピー済み。
- 今後の主な作業は、AviUtl2 上で各新規エフェクトと追加プリセットを声素材で聴感確認し、強すぎる初期値や破綻しやすい値を調整すること。
- 追加後の GUI 項目数が 100 を超え、登録時に `Too many filter GUI items` の Delphi 例外が出たため、`Aul2AudioFilterGui.pas` の内部 `MAX_GUI_ITEMS` を `256` へ増やした。
- GUI 上でパラメーター名が見切れやすかったため、項目名の effect prefix を短縮した。対応は `Delay` -> `Dly`, `Compressor` -> `Comp`, `VoiceDrive` -> `Drive`, `Distortion` -> `Dist`, `BitCrusher` -> `Crush`, `Tremble` -> `Trem`, `Wobble` -> `Wob`, `PitchShift` -> `Pitch`, `FormantShift` -> `Form`, `RingMod` -> `Ring`, `PitchStep` -> `Step`, `Whisper/Breath` -> `Breath`, `AutoGain` -> `AGain`, `NoiseGate` -> `Gate`, `ReverseReverb/Ghost` -> `Ghost`, `Output` -> `Out`, `Limiter` -> `Lim`, `Chorus` -> `Cho`, `Reverb` -> `Rev`。`EQ`, `Noise`, `Muffle` はそのまま。

## Pitch effect merge note

- `PitchShift`, `FormantShift`, `PitchStep` は GUI 上の個別エフェクトとしては廃止し、`Aul2AudioFilterPluginPitch.pas` の `Pitch` エフェクトへ統合した。
- `Pitch` のパラメーターは `Pitch: Use`, `Pitch: Mode`, `Pitch: Semitone`, `Pitch: Window(ms)`, `Pitch: Formant`, `Pitch: Amount`, `Pitch: Step(semi)`, `Pitch: Rate(Hz)`, `Pitch: Mix`。
- `Pitch: Mode` は `Natural`, `Pitch Only`, `Formant Only`, `Step`。`Natural` は従来の `PitchShift` と `FormantShift` を同じグループ内で続けて処理し、男性寄り・女性寄りプリセットの挙動を維持する。
- `Step` は従来の `PitchStep` 相当で、ロボ声プリセットから使う。
- メイン処理順は `Wobble` 後に `Pitch`、その後 `RingMod`, `Muffle`... とした。旧3ユニットはプロジェクト参照から外し、ソースファイルも削除した。
- `README.md` のエフェクト一覧、パラメーター一覧、プリセット説明を `Pitch` 統合後の表記へ更新した。
- Release/Win64 ビルド成功。出力は `C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioFilter.auf2`。
