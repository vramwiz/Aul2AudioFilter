# Aul2AudioFilter history

完了済みの開発記録、検証ログ、試行錯誤、プリセット調整履歴を置く。

`note.md` は作業再開時に必要な現行方針と手順だけを残す。

## 2026-07-10 Aul2AudioView Circular Spectrum

- `Aul2Audio View` の新しい View Type として `Circular Spectrum` を追加した。
- 既存のスペクトラム読み取り、`Source Layer`、周波数範囲、`High Boost`、`Smooth`、色バリエーションを流用し、専用 GUI はまだ増やさない方針にした。
- `Solid` は中心から外へ伸びる放射状の線、`Blocks` は外側へ積むセグメント表示として描画する。
- 円形系表示の共通設定候補として `Base Radius` を追加した。`Circular Spectrum` では中心からどの半径を起点に外側へ伸ばすかを `0..100` で指定する。
- `Aul2Audio View` の新しい View Type として `Mirror Bars` を追加した。中心線から上下対称に伸びるスペクトラムで、`Solid` は連続バー、`Blocks` は中心から上下へ積むブロック表示にした。

## 2026-07-10 Aul2AudioView layer source routing

- `Audio^.Object_^.Layer` がフィルター配置レイヤーではなく、制御対象の音声オブジェクトの内部 0-based レイヤーを返すことを Monitor 表示で確認した。表示上のレイヤー番号は `+1` で一致する。
- `Local\Aul2AudioMonitorState` / `Local\Aul2AudioMonitorSpectrum` を 64 レイヤー分のスロット構造へ変更した。最終更新レイヤーは `LastLayer` として保持する。
- `Aul2AudioFilter` は対象レイヤーのスロットへ波形/スペクトラムを書き、`Aul2AudioMonitor` はデバッグ表示で表示レイヤー番号を `内部 + 1` として出すようにした。
- `Aul2Audio View` に `Source Layer` を追加した。`Auto` は最後に更新されたレイヤーを読み、`Layer 1`..`Layer 64` は指定した表示レイヤー由来の解析結果だけを読む。
- `Source Layer` は利用頻度が高いため、View GUI の最上段へ移動した。
- Debug Win64 ビルドで `Aul2AudioFilter` / `Aul2AudioMonitor` / `Aul2AudioView` の成功を確認した。

## 2026-07-10 Aul2AudioMonitor/View stale display guard

- Monitor のツールバーボタンを少し小さくし、DPI 対応後の余白を詰めた。
- Monitor/View が共有メモリ上の直前データを拾い、エフェクト範囲外でも波形/スペクトラムが残る問題を調査した。
- `Local\Aul2AudioMonitorState` / `Local\Aul2AudioMonitorSpectrum` に更新時刻と元オブジェクトのフレーム範囲情報を追加した。
- Monitor は古い更新を待機表示へ戻し、View は現在描画フレームが元フレーム範囲内の時だけスペクトラムを使うようにした。
- `Aul2AudioFilter.dproj` / `Aul2AudioView.dproj` / `Aul2AudioMonitor.dproj` の Release Win64 ビルドが警告なしで成功し、各プラグイン出力先へのコピーまで確認した。

## 2026-07-09 Aul2AudioMonitor waveform/spectrum monitor adoption

- `Aul2AudioMonitor.aux2` を `Aul2AudioFilter.auf2` と同時配布する表示用拡張プラグインとして本採用した。
- `.auf2` 側の共有メモリ出力を常時有効化し、検証用 `ENABLE_AUDIO_MONITOR_SHARED_MEMORY` const と分岐を削除した。
- `Local\Aul2AudioMonitorState` で時間波形/ピーク、`Local\Aul2AudioMonitorSpectrum` でスペクトラムを渡す構成にした。
- `Spectrum` を初期表示にし、64 バンド、入力グリーン/出力アンバー、50ms 描画更新とした。自動減衰や `.aux2` 側の未更新推測クリアは行わず、共有メモリ上の現在値をそのまま描画する方針に戻した。
- `Wave` は 256 点 min/max 包絡線の時間波形として残した。
- `TPageControl` は避け、Syncroh2 由来の `ToolBarPanelManager` で `Wave` / `Spectrum` を切り替える。

## 2026-07-09 Aul2AudioView initial note

- `Aul2AudioBaseInput` の上に載せる表示用フィルタープラグインとして `Aul2AudioView` を追加した。
- 現時点では中身を空にし、`FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER` の映像フィルターとして登録だけ行う。
- AviUtl2 上の表示名は `Aul2Audio View`、グループは `Video Effects`、出力ファイルは `Aul2AudioView.auf2` とした。
- Release Win64 ビルドが警告なしで成功し、`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioView.auf2` へのコピーまで確認した。
- `Aul2AudioBaseAlias.pas` のエイリアス生成に `[0.2] effect.name=Aul2Audio View` を追加し、`Aul2AudioBaseInput` 上に表示用フィルターを自動で載せる構成にした。
- `Aul2AudioMonitor.dproj` の Release Win64 ビルドが警告なしで成功し、更新済み `Aul2AudioMonitor.aux2` へのコピーまで確認した。
- `Syncroh2_Filter_PSDDraw.dpr` / `PluginFilterPSDDrawOut.pas` を参考に、`Aul2AudioViewRender.pas` と `AviUtl2GpuTextureOut.pas` を追加した。
- PSDDraw 側の GPU texture 出力は実験フラグ `GPU_TEXTURE_OUT_STAGE1 = False` で無効化されていたため、`Aul2AudioView` も同じく GPU 経路を持つが初期状態は `SetImageData` 出力にした。
- `Aul2AudioView` の初期描画として、`Video^.Object_^.Width` / `Height` のサイズでチェック背景と枠線を描画するようにした。
- `Aul2AudioView.dproj` と `Aul2AudioFilter.dproj` の Release Win64 ビルドが警告なしで成功した。
- `Aul2AudioViewRender.pas` は入口と出力に寄せ、表示タイプごとの描画を別ユニットへ分ける方針にした。
- 最初の表示タイプとして `Aul2AudioViewRenderEqualizer.pas` を追加し、固定パターンの `Equalizer Bars` を描画するようにした。
- AviUtl2 上の GUI 項目として `View: Type` select を追加した。現時点では未実装タイプを出さず、選択肢は `Equalizer Bars` のみ。
- `Aul2AudioView.dproj` の Release Win64 ビルドが警告なしで成功し、更新済み `Aul2AudioView.auf2` へのコピーまで確認した。
- `Equalizer Bars` を固定サンプル表示から、`Local\Aul2AudioMonitorSpectrum` の `OutputBands` を読む実データ表示へ変更した。
- MV 用途に寄せるため、モニター側の凡例、枠、グリッド、ピークメーター、文字表示は持ち込まず、透明背景に白いバーだけを描画する。
- `Aul2AudioView.dproj` の Release Win64 ビルドが警告なしで成功し、更新済み `Aul2AudioView.auf2` へのコピーまで確認した。
- `Syncroh2` の `PluginFilterTable.pas` にある select list 構築方式を参考に、`Aul2AudioFilterGui.pas` へ `ClearSelectList` / `AddSelectList` を追加した。
- `View: Type` を設定値の先頭項目とし、`Equalizer Bars` / `Wave Line` / `Pixel Wave` / `Filled Spectrum` / `Pulse Wave` の 5 パターンをリストへ用意した。
- 未実装の表示タイプは、実装が入るまで `Equalizer Bars` へフォールバックする。
- `Aul2AudioView.dproj` の Release Win64 ビルドが警告なしで成功し、更新済み `Aul2AudioView.auf2` へのコピーまで確認した。
- `View: Style` / `View: Density` / `View: Spacing` / `View: Color` / `View: Color Style` / `View: Smooth` を共通設定として追加した。
- `View: Style` は `Solid` / `Blocks` とし、連結表示かブロック表示かを直接選べるようにした。
- `View: Spacing` は縦横共通の隙間として扱い、`Blocks` のときだけ使う。ブロック形状は `Density` と素材サイズから自動計算し、専用の幅/高さ設定は増やさない方針にした。
- `View: Color Style` は `Solid` / `Rainbow` を用意した。
- `Aul2AudioViewParams.pas` を追加し、表示タイプ、スタイル、色バリエーション、共通設定 record をまとめた。
- `Aul2AudioView.dproj` と `Aul2AudioFilter.dproj` の Release Win64 ビルドが警告なしで成功した。
- `Aul2AudioViewRenderEqualizer.pas` の肥大化を避けるため、ピクセル描画補助を `Aul2AudioViewRenderUtils.pas`、共有メモリのスペクトラム読み取り/スムージングを `Aul2AudioViewSpectrum.pas` へ分離した。
- `Aul2AudioView.dproj` の Release Win64 ビルドが警告なしで成功し、更新済み `Aul2AudioView.auf2` へのコピーまで確認した。

## Initial verification note

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

## Silent noise tail sample note

- AviUtl2/ExEdit2 では完全無音区間で音声フィルターが呼ばれないことがあり、Delay/Reverb などの尾もそこで出力されない。
- 1 秒の音 + 2 秒の完全無音 WAV では、後半が処理されずエコーが途切れることを確認した。
- 後半 2 秒へ -90dB 相当の極小ノイズを入れた WAV では処理が継続され、Delay の尾が正常に出ることを確認した。
- この用途のサンプル名を `Sample\無音_極小ノイズ_ループ推奨.wav` とした。-90dB 相当の極小ノイズ入り無音で、ループ配置を想定する。
- `Setup\make_release_zip.bat` で配布 zip の `Sample\無音_極小ノイズ_ループ推奨.wav` へ同梱するようにした。
- `README.md` へ、完全無音ではなく極小ノイズ入り余白を使う注意と、配布 zip に含まれるサンプルの説明を追記した。

## Hall preset listening note

- スピーカー確認で `ホール` プリセットの効果が感じにくいという指摘があった。
- `エコー` / `反響` は似すぎているためいったん保留とし、`ホール` だけを調整対象にした。
- `ホール` は `Rev: RoomSize = 0.90`, `Rev: Damping = 0.20`, `Rev: Dry = 0.85`, `Rev: Wet = 0.95` に変更した。
- 直音を少し下げ、残響量と残響時間を増やして、プリセット適用直後に広い場所の尾が分かりやすい方向へ寄せた。

## Wide preset output note

- `空間` は `Wide Chorus` のため、`ホール` と違って残響の尾ではなく左右の広がりを作る。
- スピーカー確認で `空間` の音量が小さく感じるという指摘があった。
- `Output` / `Limiter` が `Chorus` / `Reverb` より前に処理されていたため、最終段の音量調整になるよう `Chorus`, `Reverb`, `Output`, `Limiter` の順に変更した。
- `空間` プリセットは `Out: Use = 1`, `Out: Gain(dB) = 4`, `Lim: Use = 1` を追加し、Wide Chorus 後の体感音量を戻すようにした。

## Narration preset listening note

- スピーカー確認で `ナレーション` の効果が分かりにくいという指摘があった。
- 歪みやノイズは足さず、声を前に出す方向で EQ / Compressor / Output を強めた。
- `ナレーション` は `EQ: LowCut(Hz) = 140`, `EQ: HighCut(Hz) = 8500`, `Comp: Threshold(dB) = -24`, `Comp: Ratio = 4`, `Comp: Attack(ms) = 3`, `Comp: Release(ms) = 100`, `Comp: Makeup(dB) = 4`, `Out: Gain(dB) = 2`, `Lim: Use = 1` に変更した。
- まだ効果が分かりにくかったため、軽い `VoiceDrive` を追加し、`Comp: Threshold(dB) = -26`, `Comp: Ratio = 4.5`, `Comp: Release(ms) = 90`, `Comp: Makeup(dB) = 5`, `Drive: Drive(dB) = 7`, `Drive: Body = 0.35`, `Drive: Level(dB) = -2`, `Drive: Mix = 0.40`, `Out: Gain(dB) = 3` へ再調整した。

## Telephone preset output note

- `電話` は band-pass により体感音量が下がりやすいという指摘があった。
- 電話らしい帯域制限、軽い歪み、粗さは維持し、最後に `Out: Gain(dB) = 4` と `Lim: Use = 1` を追加して音量を戻すようにした。
- 音量は良くなったが効果をもう少し強くしたいという指摘があったため、`EQ: LowCut(Hz) = 450`, `EQ: HighCut(Hz) = 2800`, `Dist: Drive(dB) = 7`, `Dist: Tone = 0.75`, `Dist: Mix = 0.45`, `Crush: BitDepth = 9`, `Crush: Mix = 0.45` へ調整した。
- さらに少しだけ強めるため、`EQ: LowCut(Hz) = 500`, `EQ: HighCut(Hz) = 2600`, `Dist: Drive(dB) = 8`, `Dist: Tone = 0.80`, `Dist: Mix = 0.50`, `Crush: Mix = 0.50` へ調整した。

## Radio preset listening note

- `無線` が `電話` と似ていて違いが分かりにくいという指摘があった。
- `無線` は電話風の通話音ではなく、通信機らしい細さ、強い歪み、クラックルノイズ、粗いサンプル感を前に出す方向へ変更した。
- `無線` は `EQ: LowCut(Hz) = 650`, `EQ: HighCut(Hz) = 2400`, `Dist: Drive(dB) = 13`, `Dist: Tone = 1`, `Dist: Level(dB) = -5`, `Dist: Mix = 0.70`, `Noise: Level(dB) = -30`, `Noise: Mix = 1`, `Crush: BitDepth = 7`, `Crush: SampleHold = 3`, `Crush: Mix = 0.65`, `Out: Gain(dB) = 3` に変更した。
- その後、`無線` プリセット適用時に AviUtl2 が落ちる報告があったため、クラッシュ対策として強すぎる組み合わせを戻した。
- 安全側の `無線` は `EQ: LowCut(Hz) = 600`, `EQ: HighCut(Hz) = 2500`, `Dist: Drive(dB) = 11`, `Dist: Tone = 0.95`, `Dist: Level(dB) = -5`, `Dist: Mix = 0.60`, `Noise: Level(dB) = -36`, `Noise: Mix = 0.65`, `Crush: BitDepth = 8`, `Crush: SampleHold = 2`, `Crush: Mix = 0.50`, `Lim: Use = 1` とした。
- それでも `無線` 適用で `table.func_proc_audio() structured exception` が出る報告があったため、`無線` から `Noise` を外して、`EQ`, `Distortion`, `BitCrusher`, `Limiter` のみへ戻した。
- 併せて、音声処理中の Delphi 例外が AviUtl2 まで漏れないよう `FilterProcAudio` 全体に `try..except` の保護を追加した。例外時は `Result := 0` を返し、アプリ全体のクラッシュを避ける。
- クラッシュしなくなったが効果が弱いという指摘があったため、Noise は外したまま、`EQ: LowCut(Hz) = 700`, `EQ: HighCut(Hz) = 2300`, `Dist: Drive(dB) = 14`, `Dist: Tone = 1`, `Dist: Mix = 0.75`, `Crush: BitDepth = 7`, `Crush: SampleHold = 3`, `Crush: Mix = 0.70` へ強めた。

## Megaphone preset listening note

- `拡声器` の効果が感じにくいという指摘があった。
- 電話/無線のように極端に細くするのではなく、声の押し出し、音圧、硬い歪みを強める方向へ変更した。
- `拡声器` は `EQ: LowCut(Hz) = 550`, `EQ: HighCut(Hz) = 4800`, `Comp: Threshold(dB) = -28`, `Comp: Ratio = 6`, `Comp: Attack(ms) = 2`, `Comp: Release(ms) = 80`, `Comp: Makeup(dB) = 6`, `Drive: Drive(dB) = 12`, `Drive: Body = 0.55`, `Drive: Level(dB) = -3`, `Drive: Mix = 0.65`, `Dist: Drive(dB) = 18`, `Dist: Level(dB) = -7`, `Dist: Mix = 0.85`, `Out: Gain(dB) = 4`, `Lim: Use = 1` に変更した。
- 効果は良いが音量が大きくなるという指摘があったため、質感は維持して `Out: Gain(dB)` を `4` から `1.5` へ下げた。
- さらに聴感上 `-2.2dB` 付近が良いという確認があったため、`Out: Gain(dB) = -2.2` へ再調整した。

## Low quality preset listening note

- `劣化` プリセットで音が鳴らないという報告があった。
- `無線` と同じく `Noise` が処理例外や無音化の原因になっている可能性があるため、`劣化` からも `Noise` を外した。
- `劣化` は `EQ: LowCut(Hz) = 220`, `EQ: HighCut(Hz) = 5000`, `Dist: Drive(dB) = 5`, `Dist: Tone = 0.75`, `Dist: Level(dB) = -4`, `Dist: Mix = 0.30`, `Crush: BitDepth = 7`, `Crush: SampleHold = 5`, `Crush: Mix = 0.70`, `Out: Gain(dB) = 2`, `Lim: Use = 1` とした。
- 音は鳴るが劣化感が弱いという指摘があったため、Noise は外したまま、`EQ: LowCut(Hz) = 300`, `EQ: HighCut(Hz) = 4200`, `Dist: Drive(dB) = 8`, `Dist: Tone = 0.85`, `Dist: Mix = 0.45`, `Crush: BitDepth = 5`, `Crush: SampleHold = 10`, `Crush: Mix = 0.85`, `Out: Gain(dB) = 3` へ強めた。

## Male and female preset listening note

- `男性` はゲインが `+5dB` 必要で、声の一部が発音しないようなぶつ切れがあるという指摘があった。
- `Pitch: Mix = 1.0` で全量ピッチ処理音になっていたため、窓つなぎの弱い箇所が目立つ可能性がある。
- `男性` は `Pitch: Semitone = -2`, `Pitch: Window(ms) = 110`, `Pitch: Formant = -2.5`, `Pitch: Amount = 0.6`, `Pitch: Mix = 0.60`, `Out: Gain(dB) = 5`, `Lim: Use = 1` に変更した。
- `女性` も同様にゲインとぶつ切れを調整し、`Pitch: Semitone = 2`, `Pitch: Window(ms) = 100`, `Pitch: Formant = 2.5`, `Pitch: Amount = 0.6`, `Pitch: Mix = 0.60`, `Out: Gain(dB) = 5`, `Lim: Use = 1` とした。

## Preset listening final note

- スピーカー確認でプリセットを一通り試聴し、`夢/回想` まで確認完了とした。
- `エコー` と `反響` は似すぎているため、今回の作業では保留とした。
- `ささやき` は、ささやく感じが出にくくノイズも目立つため、プリセット一覧から削除した。`Whisper/Breath` エフェクト自体は手動調整用として残す。
- プリセット名は `男性寄り` / `女性寄り` から `男性` / `女性` へ変更した。
- `無線` と `劣化` は `Noise` 使用時に無音化や AviUtl2 側の例外が出る可能性があったため、プリセットからは `Noise` を外した。代わりに `Distortion` と `BitCrusher` を強めて質感を作る。
- `FilterProcAudio` 全体を `try..except` で保護し、音声処理中の Delphi 例外が AviUtl2 まで漏れないようにした。
- `Output` と `Limiter` は最終段で効くよう、処理順を `Chorus`, `Reverb`, `Output`, `Limiter` の順へ変更した。

最終的な主な調整値:

- `ホール`: `Rev: RoomSize = 0.90`, `Rev: Damping = 0.20`, `Rev: Dry = 0.85`, `Rev: Wet = 0.95`
- `空間`: `Cho: Stereo Mode = Wide`, `Out: Gain(dB) = 4`, `Lim: Use = 1`
- `ナレーション`: `EQ: 140-8500Hz`, `Comp: Threshold = -26`, `Comp: Ratio = 4.5`, `Drive: Mix = 0.40`, `Out: Gain(dB) = 3`
- `電話`: `EQ: 500-2600Hz`, `Dist: Drive = 8`, `Dist: Mix = 0.50`, `Crush: BitDepth = 9`, `Out: Gain(dB) = 4`
- `無線`: `EQ: 700-2300Hz`, `Dist: Drive = 14`, `Dist: Mix = 0.75`, `Crush: BitDepth = 7`, `Crush: SampleHold = 3`, `Noise: Use = 0`
- `拡声器`: `EQ: 550-4800Hz`, `Comp: Ratio = 6`, `Drive: Drive = 12`, `Dist: Drive = 18`, `Out: Gain(dB) = -2.2`
- `劣化`: `EQ: 300-4200Hz`, `Dist: Drive = 8`, `Crush: BitDepth = 5`, `Crush: SampleHold = 10`, `Out: Gain(dB) = 3`
- `男性`: `Pitch: Semitone = -2`, `Pitch: Formant = -2.5`, `Pitch: Mix = 0.60`, `Out: Gain(dB) = 5`
- `女性`: `Pitch: Semitone = 2`, `Pitch: Formant = 2.5`, `Pitch: Mix = 0.60`, `Out: Gain(dB) = 5`
- `ロボ`: `Ring: Frequency = 95`, `Ring: Mix = 0.90`, `Pitch: Mode = Step`, `Crush: BitDepth = 6`, `Out: Gain(dB) = 3`
- `恐怖`: `Trem: Depth = 0.75`, `Wob: Mix = 0.75`, `Pitch: Semitone = -1.5`, `Muffle: Cutoff = 2600`, `Ghost: Wet = 0.45`, `Rev: Wet = 0.45`, `Out: Gain(dB) = 10`
- `叫び`: `Comp: Ratio = 8`, `Drive: Drive = 18`, `Drive: Mix = 0.85`, `Dist: Mix = 0.35`, `Out: Gain(dB) = 5`
- `水中`: `Muffle: Cutoff = 850`, `Muffle: Amount = 0.95`, `Wob: Mix = 0.55`, `Cho: Mix = 0.35`, `Rev: Wet = 0.25`, `Out: Gain(dB) = 14`
- `壁越し`: `Muffle: Cutoff = 650`, `EQ: 120-1800Hz`, `Rev: Wet = 0.12`, `Out: Gain(dB) = 6`
- `夢/回想`: `Wob: Depth = 24`, `Wob: Mix = 0.62`, `Cho: Mix = 0.58`, `Ghost: Wet = 0.42`, `Rev: RoomSize = 0.72`, `Rev: Wet = 0.48`, `Out: Gain(dB) = 6`

## Aul2AudioMonitor Peak Meter note

- 優先順位 1 の `Level / Peak Meter` として、`Spectrum` 画面右側に小型の縦 Peak Meter を追加した。
- 既存の `Local\Aul2AudioMonitorState` にある `InputPeakL/R` と `OutputPeakL/R` を利用し、`.auf2` 側の共有メモリ構造は変更しない。
- 表示は入力をグリーン、出力をアンバーにし、Input L/R と Output L/R の細い縦バーと 1.0 位置のクリップ目安線を出す。
- 実装直後は横方向バーで場所を取りすぎたため、右側の小型縦バー表示へ変更した。
- 右側縦表示へ変更後、50ms 更新時の点滅を抑えるため、`TPaintBox` へ直接描かず一度 `TBitmap` に描画してから転送する方式に変更した。併せて非表示パネルは Invalidate しないようにした。
- `TCustomControl` 化は AviUtl2 内表示でかえって点滅が悪化したため採用しない。Spectrum 表示と同じ `TPaintBox` 構成に戻し、Peak Meter 側は `Stage` による `wait` 表示切り替えを避け、直近ピークを減衰表示する方式にした。
- サイズが変わらない 50ms 更新では `SetBounds` / `Realign` しないようにした。
- Spectrum の棒も瞬間値の上下で少し点滅したため、共有メモリ値を直接消すのではなく、表示用の 64 バンド配列を持ち、上昇は即時、下降は軽い減衰で描画する方式にした。
- `Wave` / `Spectrum` のボタンとパネル対応を確認し、コード上は入れ替わっていないことを確認した。ユーザー確認により、点滅している対象は棒グラフではなく折れ線表示の `Wave` 側と分かったため、256 点の min/max 包絡線にも表示用バッファを持たせ、軽く平滑化して描画する方式にした。併せて `Wave` 画面の見出しを `Wave` と明示した。
- `Wave` 側は共有メモリ状態が一瞬有効判定から外れた時に `waiting` 表示へ戻ると画面全体が点滅するため、直近の表示用 Wave がある場合は消さずに描き続けるようにした。
- ツールバーは `Wave` / `Spectrum` の順に表示されるよう、`TToolButton.Left` を明示して順序を固定した。表示パネルの対応は `Wave` -> `PanelWave`, `Spectrum` -> `PanelSpectrum` の順に保ち、初期表示だけ `Spectrum` にする。
- `Pan / Stereo Balance` として、共有メモリ状態を version 3 に上げ、`InputRmsL/R` と `OutputRmsL/R` を追加した。`.auf2` 側で L/R RMS を軽量集計し、`.aux2` 側で左右バランスを `Spectrum` 右側下部に小さく表示する。
- Stereo Balance は中央を 0、左寄りを L、右寄りを R とし、入力をグリーン、出力をアンバーのマーカーで描く。Chorus、Ping-Pong Delay、Reverb など空間系エフェクトの左右偏り確認に使う。
- 右側メーター領域は固定高さで詰まりやすいため、Peak の下端と Stereo の描画開始位置を調整し、`Stereo` ラベルとマーカーが重ならないようにした。
- `Aul2AudioMonitor.dproj` の Debug Win64 ビルドが警告なしで成功し、`Aul2AudioMonitor.aux2` へのコピーまで完了することを確認した。

## Aul2AudioBaseInput initial note

- 背景/Visual 系オブジェクトの土台として、入力プラグイン `Aul2AudioBaseInput` を追加した。
- 参照元の Syncroh2 入力ベースと同じく、仮想ファイル名 `name:width_height_seconds_rate_scale.aul2base` から解像度、長さ、FPS 情報を取得する。
- 現段階では描画や別プラグインへの通知は行わず、要求されたフレームバッファを 0 クリアして返すだけの最小構成にした。
- 参照元は共有メモリで別プラグインへ情報を送っていたが、今回は後段の描画フィルターがオブジェクト側のサイズを参照できる想定のため、共有メモリ連携は入れない。
- `Aul2AudioBaseInput.dproj` の Debug / Release Win64 ビルドが警告なしで成功し、`Aul2AudioBaseInput.aui2` へのコピーまで完了することを確認した。

## Aul2AudioMonitor playback sync investigation note

- 再生中、`.auf2` 側の音声処理がプレビュー音声を先読みして共有メモリへ未来側のスペクトラムを書き込むため、独立ウィンドウの `Aul2AudioMonitor` は画面上の再生位置より先行して見える問題を調査した。
- 最初に `PLAYBACK_DISPLAY_DELAY_MS = 3000` の固定遅延と履歴配列を試した。一定の補正にはなったが、View 側が遅延なしで合っていることと整合せず、見え方も安定しなかったため不採用とした。
- `EDIT_HANDLE.GetEditInfo` から `Frame` を取る `AviUtl2GetEditFrame` を追加し、再生中だけ現在フレームと `SourceFrameS..SourceFrameE` が一致する履歴を選ぶ方式を試した。`GetEditInfo.Frame` は再生中の実描画フレームではなく編集カーソル寄りの値を返す場合があり、`waiting audio data` になったため単独利用は不採用。
- View 側の映像描画コールバックには正しい `CurrentFrame` があるため、最初は `Local\Aul2AudioMonitorSpectrum` に `ViewFrame` / `ViewFrameUpdateTick` を追加して version 4 に上げた。しかし View 側のスペクトラム読み取りまで巻き込み、表示不能になったため撤回した。スペクトラム共有構造は version 3 へ戻した。
- 代替として、ViewFrame 専用共有メモリ `Local\Aul2AudioViewFrame` と `Aul2AudioViewFrameShared.pas` を追加した。`Aul2AudioViewSpectrum.pas` が `UpdateViewSpectrum` ごとに現在描画フレームを書き、`Aul2AudioMonitorView.pas` が `RefreshMonitorFrame` で新鮮な ViewFrame を優先して読む。
- `Aul2AudioMonitorView.pas` の再生中履歴選択は、現時点では `ViewFrame` と `SourceFrameS..SourceFrameE` が一致する履歴のうち最新 tick を選ぶ形が最も安定した。少し未来側に見えるが、他の方式より正解に近い。
- その後、`SourceFrame` の近さ、未来側除外、`SampleIndex` からのフレーム換算、サンプル単位比較、未来サンプル許容量、音声ブロック中心代表などを試したが、無表示、数秒遅れ、または 12 フレーム程度の先行に悪化したため不採用とした。
- 編集中は従来通り最新共有メモリ値と最後の描画値を保持する方針を維持する。同期課題は再生中だけに限定して扱う。
- Debug Win64 で `Aul2AudioMonitor.dproj` のビルドと `Aul2AudioMonitor.aux2` へのコピーが成功することを確認した。

## Aul2AudioView / Monitor playback sync completion note

- 2026-07-10、再生中の `Aul2AudioView` と `Aul2AudioMonitor` が AviUtl2 の音声先読みで未来側の解析値に引っ張られる問題を解決した。
- まず `Aul2AudioView` で、共有メモリの最新スロットだけを読む方式では先読み済みの未来フレームが勝つことを確認した。
- `Local\Aul2AudioMonitorState` と `Local\Aul2AudioMonitorSpectrum` にレイヤー別の履歴リングを追加した。履歴数は各レイヤー 128 件。
- 共有メモリ構造変更に伴い、Wave/基本状態側は version 8、Spectrum 側は version 6 へ更新した。
- `.auf2` 側の `AudioMonitorCaptureOutput` は、従来の最新スロットに加えて履歴リングにも同じ解析状態を書き込むようにした。
- View 側は `CurrentFrame` に対して `SourceFrame` を描画フレーム基準へ正規化し、現在フレームに最も近い履歴を選択するようにした。
- 初期実装では `SourceFrameS..SourceFrameE` に一致する履歴のうち `UpdateTick` が最新のものを選んだため、同じ音声オブジェクト範囲内で未来側・無音側が勝ち、最初の 1～2 回同期後に 0 へ収束するように見えた。
- そのため選択基準を `UpdateTick` 優先からフレーム距離優先へ変更した。距離が同じ場合のみ `UpdateTick` をタイブレークに使う。
- View は再生中の先行読み込みに対して同期が取れ、継続表示できることを確認した。
- Monitor 側は当初、`.aux2` 内で最新共有メモリ値を 50ms タイマーで独自履歴化していたため、すでに未来へ進んだ最新値を履歴化する弱点が残っていた。
- Monitor 側も View と同じく、`.auf2` 側が書いた共有メモリ履歴リングを直接スキャンする方式へ変更した。
- `Aul2AudioMonitorView.pas` の `SelectMonitorSnapshot` / `SelectSpectrumSnapshot` は、再生中に `MonitorFrame` へ最も近い履歴を選択する。編集時やフレーム取得不可時は従来通り最新スロットを使う。
- Monitor は `Local\Aul2AudioViewFrame` の新鮮な ViewFrame を優先し、なければ `AviUtl2GetEditFrame` へフォールバックする。
- ユーザー確認により、View と Monitor のどちらも再生中に十分同期が取れている状態になった。
- Release Win64 で `Aul2AudioFilter.dproj` / `Aul2AudioView.dproj` / `Aul2AudioMonitor.dproj` のビルドが成功し、`Aul2AudioFilter.auf2` / `Aul2AudioView.auf2` / `Aul2AudioMonitor.aux2` へ反映した。

## Aul2AudioView completion note

- `Aul2AudioView` は `Aul2AudioBaseInput` の上に載る MV 用表示フィルターとして完成扱いにした。
- 表示タイプは `Equalizer Bars`, `Filled Spectrum`, `Wave Line`, `Pixel Wave`, `Pulse Wave` の 5 種類。スペクトラム系は `Local\Aul2AudioMonitorSpectrum` の `OutputBands`、時間波形系は `Local\Aul2AudioMonitorState` の `OutputWave` / `OutputWaveMin` / `OutputWaveMax` を読む。
- 描画は背景透明、文字なし、枠なし、グリッドなしを基本とし、MV 素材として邪魔にならない出力にした。
- `Style` は `Solid` / `Blocks`。`Density`, `Spacing`, `Thickness`, `Smooth` を共通パラメーターとして扱う。
- `Equalizer Bars` / `Filled Spectrum` の描画マージンは `0` とした。将来的に必要になった場合は `VIEW_MARGIN_X` / `VIEW_MARGIN_Y` を設定項目へ昇格する。
- `Thickness` は `1..32` とし、`Wave Line` では線幅、`Pixel Wave` では点サイズ、`Pulse Wave` ではパルス幅として再利用する。Pixel Wave の内部 clamp も `32` に合わせた。
- 色設定は `Color Variation` 1 リストに統合した。`1 Color`, `2 Color`, `3 Color`, `Rainbow`, `Warm`, `Cool`, `Pastel`, `Neon`, `Mono`, `Sepia`, `Gold`, `Silver`, `Fire`, `Ice`, `Water`, `Aurora`, `Starlight`, `Sunset`, `Ocean`, `Forest`, `Cyber`, `Retro Game` を用意した。
- `Color Blend` は `Auto`, `RGB`, `HSV Short`, `HSV Long`。`Auto` では周期的な色相回転を避けるため、`Rainbow`, `Pastel`, `Neon`, `Cyber`, `Retro Game` を `RGB`、`Aurora` を `HSV Short` とした。`HSV Long` はユーザー指定時だけ強い色相回転として使う。
- パラメーター名は `Aul2Audio View` 内に表示されるため、`View:` prefix を外し、`Type`, `Style`, `Density`, `Spacing`, `Thickness`, `Color`, `Color Variation`, `Color Blend`, `Smooth` とした。
- `Source\Lib\Color\Aul2ColorUtils.pas` と `Source\Lib\Color\Aul2ColorPalette.pas` を追加し、RGB/HSV 変換、RGB / HSV短方向 / HSV長方向補間、パレット色取得を共通化した。
- `dcc64` で `Aul2AudioView.dpr` の直接コンパイルが通ることを確認した。
