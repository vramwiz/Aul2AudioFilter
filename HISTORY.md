# Aul2AudioFilter history

完了済みの開発記録、検証ログ、試行錯誤、プリセット調整履歴を置く。

`note.md` は作業再開時に必要な現行方針と手順だけを残す。

## 2026-07-17 Aul2AudioController VoiceDrive XY completion note

- Controllerエフェクト表示の第二弾として、優先順位1の `VoiceDrive` に非線形伝達表示と実音声Input／Output XY点列を追加した。
- VoiceDrive DSPは単純な瞬時関数ではなく、700Hzの1次ローパス状態を`Body`で35%まで混ぜてからtanhサチュレーションする。そのため単一の静的カーブだけを厳密値として見せず、高域側の`LowSample = 0`相当と低域定常側の`LowSample = Input`相当をBody範囲の帯として描き、中央の設定カーブを太線で重ねる構成にした。無加工の対角基準線も表示する。
- `Source\Lib\AudioMonitor\Aul2AudioVoiceDriveXYShared.pas`を追加し、VoiceDrive処理直前／直後の対応サンプルをレイヤー別に最大256点、`Local\Aul2AudioVoiceDriveXY`で共有する。L/R平均では非線形の対応関係が崩れるため、最大2チャンネルのサンプルを別々のXY点として交互に保持する。
- `Source\Aul2AudioControllerVoiceDriveGraph.pas`を追加し、Drive、Body、Level、Mixを反映したBody範囲、中央伝達カーブ、実音声XY点、出力レンジ自動拡張を既存の最大幅300px、高さ150pxへ統合した。Body範囲と`Audio XY`の凡例には黒背景を付け、波形や点列との重なりを避けた。
- 実機確認中にVoiceDriveではなく前段のNoiseで、LCG更新`Seed * 1664525 + 1013904223`がDelphiのオーバーフローチェックにより整数例外になることが判明した。`UInt64`で演算して下位32bitを明示的に採用し、LCG本来のラップアラウンドを維持したまま例外を防いだ。
- Filter／ControllerのRelease Win64コンパイルは警告0、エラー0で成功した。ユーザー実機確認により、Drive 18dB、Body 0.65、Level -4dB、Mix 0.85で、強いS字飽和、Body範囲、実音声XY点列、無加工基準線が意図どおり表示され、実行時エラーも発生しないことを確認した。`VoiceDrive`表示を完成扱いとする。

## 2026-07-17 Aul2AudioController Noise waveform completion note

- Controllerエフェクト表示の第二弾として、優先順位1の `Noise` に処理直前／直後波形と差分波形を追加した。
- `Source\Aul2AudioControllerNoiseGraph.pas` を追加し、既存の最大幅300px、高さ150pxのグラフ領域を上下2段に分けた。上段はNoise直前のInputを緑、処理直後のOutputをアンバーで重ね、共通ピークから自動スケールする。下段は実際に加算された成分 `Output - Input` をテーマ色で描き、差分専用ピークから独立して自動スケールする。Mode、Level、Mixもヘッダーへ表示する。
- `Source\Lib\AudioMonitor\Aul2AudioNoiseWaveShared.pas` を追加し、レイヤー別のInput／Output各256点を `Local\Aul2AudioNoiseWave` でFilterとController間に共有する。Filter側の取得方法はPitch／RingModと同じ構造へ揃え、Noise処理直前にL/Rを取得し、DSP処理後にもう一度L/Rを取得してから公開する。Controllerは選択Objectのレイヤーを優先し、有効値がなければ最後に更新された音声レイヤーへフォールバックする。
- 初期版はチャンネル処理ループ内でサンプルを蓄積したが、既存の実音声表示との一貫性を優先し、Pitch／RingModと同じ明確な処理前取得、DSP、処理後取得の順へ変更した。一時的に追加したControllerタイマー再取得も不要と判断して撤去し、既存Controllerと同じスナップショット更新方式を維持した。
- 初回の有効表示では波形が凡例とスケール値の背後を通り、特に密な差分波形で文字が読みにくかった。Input、Output、Difference、上下スケール値の背後を余白付きの黒で塗り、波形との重なりを避けた。
- `Aul2AudioFilter.dproj` と `Aul2AudioController.dproj` のRelease Win64ビルドは警告0、エラー0で成功し、`.auf2`／`.aux2`へ反映した。ユーザー実機確認により、White Noise時のInput／Output、密な差分波形、独立オートスケールが正常に表示されることを確認した。黒背景による文字視認性改善も採用し、`Noise`表示を完成扱いとした。

## 2026-07-17 Aul2AudioController Limiter graph

- Controllerの次の補助表示として、`Aul2AudioControllerLimiterGraph.pas`を追加した。横軸と縦軸を-60～+12dBとし、Ceilingまでは無加工、超過部分はDSPと同じくWetをCeilingへ制限してDryとMixする定常入出力特性を描画する。
- 無加工基準線、Ceiling位置、超過時に抑制される領域の塗り、Mix、Releaseを表示する。Releaseはピーク後のゲイン回復時間なのでカーブ形状を変えない。UseがOFFでも設定形状を暗く残し、ノブ操作、設定読込、Use変更、リサイズへ追従する。
- 初回のAviUtl2実機表示ではカーブと文字は良好だったが、抑制領域の塗りが背景へ沈んでほとんど見えなかったため、塗りをアクセント色の20%から38%へ明るくした。
- `Aul2AudioController.dproj`のRelease Win64ビルドは警告・エラーなしで成功し、`Aul2AudioController.aux2`へ反映した。Ceiling、Mix、Release、ピーク制限カーブ、明るさ調整後の抑制領域をユーザー実機確認済みとし、Limiterグラフを完成扱いとする。

## 2026-07-17 Aul2AudioController NoiseGate graph

- Controllerの次の補助表示として、`Aul2AudioControllerNoiseGateGraph.pas`を追加した。横軸を入力-80～0dB、縦軸を出力-160～0dBとし、DSPと同じくThreshold未満では入力へFloor dBを加え、Threshold以上では無加工となる定常入出力特性を描画する。
- 無加工基準線、Threshold位置、ゲートが開く段差、抑制される音量領域の塗り、Floor、Attack、Releaseを表示する。UseがOFFでも設定形状を暗く残し、ノブ操作、設定読込、Use変更、リサイズへ追従する。
- `Aul2AudioController.dproj`のRelease Win64ビルドは警告・エラーなしで成功し、`Aul2AudioController.aux2`へ反映した。Threshold、Floor、段差、抑制領域、Attack／Release値をユーザー実機確認済みとした。Attack／Releaseは定常カーブの形状を変えず時間応答だけを制御する仕様で正しいことも確認し、NoiseGateグラフを完成扱いとする。

## 2026-07-17 Aul2AudioController BitCrusher graph

- Controllerの次の補助表示として、`Aul2AudioControllerBitCrusherGraph.pas`を追加した。入力-1～+1に対し、DSPと同じBitDepth別の符号付き量子化とMixを適用した静的な入出力カーブを描画する。
- 初期実装は2～8bitで全量子化区間を描いたが、ユーザー実機確認で4bitの階段は明瞭、6bitと7bitは段数が描画幅へ詰まってほぼ斜線に見えることを確認した。BitDepth固定の切替をやめ、実描画幅とDPIから1段あたり約8pxを確保できる中央範囲を計算し、必要な場合だけ自動拡大する方式へ変更した。
- 無加工基準線、BitDepth、Sample Hold、Mix、全量子化レベル数、拡大時に表示中のレベル数を表示し、ノブ操作、設定読込、Use変更、リサイズへ追従する。OFF文字は上部設定表示と重ならないようプロット内へ移した。
- 高BitDepthの実機表示では自動拡大により階段は見える一方、軸の振幅値が長い小数になったため、拡大時は軸を量子化ステップ単位の整数へ変更した。1ステップの実振幅を科学表記にしても直感的でないため削除し、`21 of 8,191 levels shown`のように全段数のうち表示中の段数を示す。上部の拡大率表記も省略した。
- `Aul2AudioController.dproj`のRelease Win64ビルドは警告・エラーなしで成功し、`Aul2AudioController.aux2`へ反映した。低～高BitDepthの階段、描画幅に応じた自動拡大、ステップ単位軸、表示中／全体レベル数の表記をユーザー実機確認済みとし、BitCrusherグラフを完成扱いとする。

## 2026-07-17 Aul2AudioController Distortion graph

- Controllerの次の補助表示として、`Aul2AudioControllerDistortionGraph.pas`を追加した。入力-1～+1に対し、DSPと同じSoft ClipのtanhまたはHard Clipの制限、Tone、Level、Mixを順に適用した静的な振幅伝達カーブを描画する。
- 無加工基準線、Driveによる正負の飽和開始位置、Mode、Drive、Tone、Level、Mixを表示する。Levelで出力が1を超える場合は縦軸を±2または±4へ段階的に拡張し、通常設定ではカーブを大きく保つ。UseがOFFでも設定形状を暗く残し、Mode、ノブ操作、設定読込、Use変更、リサイズへ追従する。
- `Aul2AudioController.dproj`のRelease Win64ビルドは警告・エラーなしで成功し、`Aul2AudioController.aux2`へ反映した。AviUtl2上でSoft ClipのS字カーブ、無加工基準線、正負の飽和位置、Drive、Tone、Level、Mixの表示をユーザー実機確認済みとし、Distortionグラフを完成扱いとする。

## 2026-07-17 Aul2AudioController Compressor graph

- Controllerのエフェクト補助表示の続きとして、`Aul2AudioControllerCompressorGraph.pas`を追加した。横軸を入力-60～0dB、縦軸を出力-60～+24dBとし、Threshold以降のRatio圧縮、Makeup、MixをDSPと同じ定常入出力式でカーブへ反映する。
- 無加工の入出力基準線、Threshold位置、Ratio、Mix、Makeup、Attack、Releaseを小型表示内へ描画する。UseがOFFでも設定形状を暗く残し、ノブ操作中、設定読込、Use変更、リサイズへ既存のDelay／EQと同じ経路で追従する。
- `Aul2AudioController.dproj`のRelease Win64ビルドは警告・エラーなしで成功し、`Aul2AudioController.aux2`へ反映した。AviUtl2上でThresholdの折れ点、無加工基準線、Ratio、Mix、Makeup、Attack、Releaseの表示をユーザー実機確認済みとし、Compressorグラフを完成扱いとする。

## 2026-07-16 Aul2AudioController effect graph completion note

- Controllerのエフェクター操作を主体としたまま、現在の設定による効果の傾向を確認できる小型の補助表示をノブ最終行の下へ追加した。最大幅300px、高さ150pxで中央配置し、ウィンドウの高さが不足する場合は操作部を優先して表示しない。Preset管理と波形表示オブジェクト配置のページにも表示しない。
- Controller内では実音声、再生位置、共有メモリ、監視タイマーを使わず、選択Objectから読み込んだ設定値とControllerで変更した値だけから描画する。マルチエフェクター全体の実測表示が必要になった場合はMonitor側の役割とする。
- 最初のDelay版は0～5000msの座標軸へ細い反射線を描いたが、余白が大きく各線の意味も読み取りにくかったため不採用とした。原音とEchoを太線で直接示し、Delay時間の矢印、Feedbackによる減衰線、最後に表示するEcho時刻を添える反射模式図へ変更した。
- Delayの主線はDPIに応じた約4px、補助線と減衰線は1pxとした。横幅と減衰レベルからEchoを1～6本に制限し、OFF時も設定文字は暗くしない。Time、Dry、Wet、Feedback、Normal/Ping-Pong、Useの変更へ追従する。ユーザー実機確認により、厳密な音声処理結果ではないが調整具合の目安として十分分かりやすい状態になった。
- 2番目としてEQの周波数特性表示を追加した。DSP実装がButterworth型2次High/Low Passであることを確認し、20Hz～20kHzの対数周波数軸、通過量0～100%、約3pxの特性カーブ、薄い通過領域、カット位置の1px縦線でLow Cut、High Cut、Band Passを近似表示する。Mixは0%のフラット線から100%のフィルター特性まで補間する。
- EQのBand PassでHigh CutがLow Cut以下の場合はDSP側と同じくLow Cutより1Hz上へ補正する。カット位置文字はLow側を縦線の左、High側を右へ逃がし、カーブや線と重なる場合も読めるよう黒に近い余白付き背景を敷いた。ユーザー実機確認により、線グラフ、塗り、Mode、Mix、カット位置の変化と文字の視認性が実用的な状態になった。
- `Aul2AudioControllerDelayGraph.pas`と`Aul2AudioControllerEqGraph.pas`を個別描画ユニットとして追加し、Controllerのテーマ色、設定読込、Mode、Use、各ノブ変更、リサイズへ連携した。ほかのエフェクターは今回実装せず、必要になった時に同じ表示領域と配置・ラベル回避方針を再利用する。
- `Aul2AudioController.dproj`のRelease Win64ビルドが警告・エラーなしで成功し、`Aul2AudioController.aux2`へ反映した。DelayとEQのAviUtl2上の表示をユーザー実機確認済みとし、この作業を完了扱いとする。

## 2026-07-16 Aul2Audio View Vectorscope Trail 3D completion note

- 14番目のView Typeとして`Vectorscope Trail (3D)`を追加した。全レイヤー共通256件のVectorscope履歴から対象レイヤーを抽出し、重複フレームは最新更新値を採用して、現在フレーム以前を新しい順に最大32層並べる。共有メモリの構造と容量は変更していない。
- 各履歴層は処理後Output L/R代表点64組を`X=(L-R)/2`、`Y=(L+R)/2`へ変換する。`Solid`は各時刻の点列を厚み付きリボンで結び、`Blocks`は独立した点タイルとして描く。履歴層同士は接続しない。
- 初期版では音が止まると共有履歴の有効値が外れて全層が急に消えた。View内に最大32層の流動履歴を追加し、無音時は中心点ではなく描画しない空層を追加して既存層をZ方向へ押し出す方式へ変更した。最後の有効層が履歴分流れ切ってから透明になる。意図的な空表示は3D描画失敗として扱わず、2D Vectorscopeへフォールバックしない。
- `Density`は点数と最大履歴層数、`Spacing`は履歴層のZ間隔、`Thickness`は`Solid`のリボン幅または`Blocks`の点タイルサイズとして反映した。履歴方向へ`Smooth`を適用し、色、`Source Layer`も反映した。円形・スペクトラム専用設定は使用しない。
- 一般的な音量では指定解像度に対して表示が小さかったためX/Y共通のType専用2.5倍感度を追加し、X方向は2D Vectorscopeと同じ相対10倍のSide感度を維持した。短辺基準の正方形では横長素材のWidthを使い切れなかったため、Xを指定Width、Yを指定Height基準の長方形座標へ変更した。
- 履歴層のZ間隔がX/Y寸法に対して小さく平面に見えたため、Z ScaleへType専用8倍感度を追加した。各層自体は平面だが、複数の時刻別層を異なるZ座標へ配置する3D構造としてカメラ上で奥行きを確認できる。
- `draw_poly()`が利用できない場合または実際の描画に失敗した場合は2D `Vectorscope`へフォールバックする。Type選択リストは14選択肢とnil終端1件の計15要素へ拡張した。
- `Aul2AudioView.dproj`のRelease Win64ビルドが警告・エラーなしで成功し、`Aul2AudioView.auf2`へ反映した。AviUtl2上の表示、無音後の流れ切り、長方形座標、X/Y専用2.5倍感度、Z専用8倍感度、各パラメーターをユーザー実機確認済みとし、`Vectorscope Trail (3D)`を完成扱いとした。これにより`note.md`に記載していた3D View Type候補は全て完了した。

## 2026-07-16 Aul2Audio View Spectrum Waterfall 3D completion note

- 13番目のView Typeとして`Spectrum Waterfall (3D)`を追加した。既存のレイヤー別スペクトラム履歴を最大32列取得し、履歴同士を接続しない独立した細い帯としてZ方向へ並べ、`draw_poly()`で直接描画する。共有メモリの構造と容量は変更していない。
- `Spectrum Landscape (3D)`が隣接履歴を面で接続した地形を作るのに対し、Waterfallは各履歴を独立させ、等高線・走査線に近い表示とした。`Solid`は周波数方向へ連続したリボン、`Blocks`は周波数方向も分割したタイル列として描く。
- 再生中はView内の流動履歴へ現在スペクトラムを追加し、無音を高さ0の帯として有音帯を奥へ流す。編集中は現在カーソル以前の共有履歴を毎回取得し直し、同期履歴がない場合は指定レイヤーの最新値、それも無効または全ゼロなら最後の有効形状を保持する。Play／Encode中の本当の無音は保持しない。
- `Density`は周波数分割数と最大履歴列数、`Spacing`は履歴帯の間隔と`Blocks`のタイル間隔、`Thickness`は帯のZ方向幅として反映した。X/Y/Z Scale、色、`Source Layer`、周波数軸、Low/High Hz、High Boostも反映した。円形座標を持たないため`Base Radius`は使用しない。
- `Smooth`は平滑化済みの先頭スペクトラムだけでなく履歴方向にも適用し、隣接する帯の急な高さ差を抑えるようにした。
- `draw_poly()`が利用できない場合または描画に失敗した場合は、同じスペクトラムを使う`Filled Spectrum`へフォールバックする。Type選択リストは13選択肢とnil終端1件の計14要素へ拡張した。
- `Aul2AudioView.dproj`のRelease Win64ビルドが警告・エラーなしで成功し、`Aul2AudioView.auf2`へ反映した。AviUtl2上の表示と各パラメーターをユーザー実機確認済みとし、`Spectrum Waterfall (3D)`を完成扱いとした。

## 2026-07-16 Aul2Audio View Waveform Tunnel 3D completion note

- 12番目のView Typeとして`Waveform Tunnel (3D)`を追加した。既存のレイヤー別時間波形履歴を最大32断面取得し、各波形を円形断面へ変換してZ方向へ並べ、`draw_poly()`で直接描画する。共有メモリの構造と容量は変更していない。
- `Solid`は履歴断面間を内外面で接続し、手前と奥の端面も持つ厚み付きトンネルとした。`Blocks`は前後・内外面を持つ独立リング列とした。
- `Density`は円周分割数と最大履歴断面数、`Spacing`は断面間隔、`Thickness`は`Solid`の壁厚または`Blocks`のリング奥行き、`Base Radius`は基準半径として反映した。X/Y/Z Scale、色、`Source Layer`も反映した。スペクトラム専用設定は使用しない。
- `Smooth`は平滑化済みの先頭波形だけでなく履歴方向にも適用し、断面間の急な形状差を抑えるようにした。
- 再生中はView内の流動履歴へ現在波形を追加し、無音をゼロ断面として有音断面を奥へ流す。編集中は共有メモリ履歴をカーソル位置以前の新しい順へ毎回組み直し、カーソル移動へ追従する。
- 初期版では編集停止中に再生用ローカル履歴を固定表示していたため形状が更新されなかった。時間波形側へ`GetViewWaveHistory`を追加し、`Spectrum Landscape (3D)`と同じ履歴再取得方式へ修正した。同期履歴がない編集時は指定レイヤーの最新値、それも無効または全ゼロなら最後の有効形状を保持する。Play／Encode中の本当の無音は保持しない。
- `draw_poly()`が利用できない場合または描画に失敗した場合は、同じ時間波形を使う`Wave Line`へフォールバックする。Type選択リストは12選択肢とnil終端1件の計13要素へ拡張した。
- `Aul2AudioView.dproj`のRelease Win64ビルドが警告・エラーなしで成功し、`Aul2AudioView.auf2`へ反映した。AviUtl2上で再生中の流動、編集カーソル追従、`Solid` / `Blocks`、履歴Smooth、Spacing、Thickness、Base Radius、X/Y/Z Scale、色をユーザー実機確認済みとし、`Waveform Tunnel (3D)`を完成扱いとした。

## 2026-07-16 Aul2Audio View Spectrum Landscape 3D completion note

- 11番目のView Typeとして`Spectrum Landscape (3D)`を追加した。既存のレイヤー別スペクトラム履歴を現在フレーム以前の新しい順へ並べ、周波数=X、振幅=Y、時間履歴=Zの四角形グリッドを`draw_poly()`で直接描画する。
- 初期版は最大64周波数点、最大32履歴列の単純な連続地形とした。`Density`、`Spacing`、X/Y/Z Scale、色、周波数範囲、高域強調を反映する。共有メモリの構造と容量は変更していない。
- 編集停止中に同期履歴がない場合は指定レイヤーの最新スペクトラムを使用し、それも無効または全ゼロなら最後の有効な地形を保持する。Play／Encode中の本当の無音は保持しない。この注意点を今後の3D Type追加時の必須事項として`note.md`へ追記した。
- `draw_poly()`が利用できない場合または描画に失敗した場合は、同じスペクトラムを使う`Filled Spectrum`へフォールバックする。
- 初期実機確認で、無音区間へ入ると共有履歴の再抽出結果がゼロへ一括置換され、地形が履歴分流れず急に消える問題を確認した。View側に表示用の流動履歴を追加し、再生フレームが進むたびに現在スペクトラムを先頭へ1列追加して既存列を奥へ送るよう修正した。無音は高さゼロの列として追加されるため、有音地形は最大履歴列数をかけて徐々に流れ切る。同一フレームの再描画では列を増やさず、編集停止中は流れを進めない。
- 共通設定との照合で未反映だった`Style`、`Thickness`、`Smooth`を追加した。`Solid`は履歴間を接続した連続地形、`Blocks`は`Thickness`をZ方向幅、`Spacing`を列間の隙間とする独立帯として描く。新しく流れ込む先頭列には既存スペクトラムTypeと同じ`Smooth`処理を適用する。`Base Radius`は円形座標を持たないTypeのため意図的に使用しない。
- Type選択リストは11選択肢とnil終端1件の計12要素へ拡張した。`Aul2AudioView.dproj`のRelease Win64ビルドは警告・エラーなしで成功し、`Aul2AudioView.auf2`へ反映した。
- AviUtl2上で地形表示、色変化、カメラによる立体確認、再生中の履歴移動、無音時に有音地形が履歴分だけ流れてから平面になる動作、編集停止中の保持をユーザー実機確認済み。共通設定の未反映項目も解消し、`Spectrum Landscape (3D)`を完成扱いとした。

## 2026-07-16 Aul2Audio View Radial Waveform 3D

- 10番目のView Typeとして`Radial Waveform (3D)`を追加した。処理後の時間波形を円周上へ割り当て、前面、背面、内側面、外側面を持つ厚み付きリボンへ変換して`draw_poly()`で直接描画する。
- 円周方向は波形内の時間位置、中心からの距離は符号付き振幅を表す。フレームごとに波形の開始サンプル位置が進むことで、周期性の強い音では位相移動が自然な回転として見える。この動きを表示特性として採用した。
- `Density`、`Thickness`、`Base Radius`、`Smooth`、X/Y/Z Scale、色設定を反映した。X/Y/Z Scaleは各3D座標軸へ直接適用し、元の厚みが小さいためZ ScaleだけType固有の6倍感度とした。
- 編集停止時に同期履歴が得られない場合は指定レイヤーの最新波形を読み、無効または全ゼロへ落ちた場合は最後の有効波形を保持する。Play／Encode中の本当の無音は保持しない。共有メモリの構造と容量は変更していない。
- `draw_poly()`が利用できない場合または描画に失敗した場合は、同じ時間波形を使う`Wave Line`へフォールバックする。
- Type追加時に選択リストのnil終端領域が不足して初期化例外になったため、`GViewTypeList`を10選択肢と終端1件の計11要素へ拡張した。
- `Aul2AudioView.dproj`のRelease Win64ビルドが警告・エラーなしで成功した。AviUtl2上で初期化、再生中の波形反応、編集停止中の保持、カメラによる厚み、X/Y/Z Scaleと専用Z感度をユーザー実機確認済み。

## 2026-07-16 Aul2Audio View initial 3D draw_poly path

- 既存のCPU描画Typeを維持したまま、Type一覧の末尾へ`Circular Bars (3D)`を追加した。
- SDK v2.10の`FILTER_PROC_VIDEO`を`draw_poly`と`set_default_anchor`まで正しい順序でDelphiへ拡張し、3D Typeだけフレームバッファ直接描画後に通常画像出力を中断するよう分岐した。
- 既存スペクトラムから最大128枚、512頂点の縦面を円周上へ生成する初期検証表示とした。頂点はView内の一時配列であり、共有メモリの構造と容量は変更していない。
- `draw_poly`が利用できない場合または描画に失敗した場合は、既存CPU版`Circular Spectrum`へフォールバックする。
- 初期実機確認でカメラ制御による3D座標変換が有効なことを確認した。未適用だった`X Scale`を横座標へ反映し、3D専用の`Z Scale`を追加して、X/Y/Zを独立して`10..500`で調整できるようにした。
- 初期の厚みがない縦面を6面の直方体へ変更した。`Spacing`を円周方向の間隔、`Thickness`を半径方向の奥行きへ反映し、`Solid`は連続バー、`Blocks`は最大32段の分割バーとして描画する。面ごとの明度差も付け、光源がない状態でも立体方向を判別できるようにした。
- `draw_poly`は編集停止中も毎回形状を再構築するため、音声更新停止後に最低高さへ戻る3D Type固有の問題へ対応した。3D描画ユニット内に最後の有効スペクトラムを保持し、Edit時に新規値が無効または全ゼロなら保持値を使用する。Play／Encode中の無音はそのままゼロとして扱い、Source Layer変更時は保持値を破棄する。共有メモリ容量は変更していない。
- カーソル移動だけの診断ログでは、Viewの同期履歴選択が全て`select=no-state`となり、編集用キャッシュを一度も作れない一方、Monitorは編集時の最新スロットを表示できていた。3D Typeに限り、Edit時に同期履歴がなければ指定レイヤーの最新スペクトラムへフォールバックするよう修正した。Play／Encode時のフレーム距離優先選択は変更していない。
- `Aul2AudioView.dproj`と`Aul2AudioFilter.dproj`のRelease Win64ビルドが警告・エラーなしで成功し、各`.auf2`への反映まで確認した。AviUtl2上の表示、カメラ制御、頂点方向は実機確認待ち。

## 2026-07-16 Aul2Audio View Vectorscope and X/Y Scale

- Monitor版Vectorscopeは削除したまま、MV用表示として`Aul2Audio View`へ8番目のType `Vectorscope`を追加した。処理後OutputのL/R代表点64組を点列で結び、同相信号を縦、左右差を横へ表示する。
- 約180 KiBの専用共有メモリ`Local\Aul2AudioViewVector`を追加した。64レイヤーの最新値と全レイヤー共通256件の履歴を持ち、既存Viewと同じく現在フレームとの距離を優先して選択する。
- Viewからの要求後だけ採取する方式は、音声が先読み済みの場合に履歴を生成できなかったため不採用とした。既存のOutput音声バッファから常時64組を取得する方式へ変更し、追加の`GetSampleData`、FFT、全サンプル走査は行わない。実機確認では負荷は実用上問題なかった。
- 点だけではHD解像度で視認しにくいため、代表点を線で接続した。自動倍率は表示基準を曖昧にするため削除し、`X=(L-R)/2`、`Y=(L+R)/2`で正規化した。
- `View Gain(%)`と試験中の`Side Gain(%)`を廃止し、共通パラメーター`X Scale` / `Y Scale`へ整理した。両方とも100を基準、範囲は10..500。Vectorscopeは小さいSide成分を見やすくするためX方向だけ固定10倍の感度とした。
- バー、面、時間波形は画像全体を使い、正方形画角を期待する`Vectorscope`と`Circular Spectrum`は画像の短辺から作る中央正方形を基準にした。Circular Spectrumは通常感度のX/Y Scaleで円形座標を変形する。
- Circular SpectrumがDebugビルドで透明になる問題は、独自の`array[0..0]`画素アクセスが範囲検査へ抵触していたことが原因だった。共通描画と同じ実アドレス計算へ変更して解消した。
- 一時診断ログでType到達、共有履歴、同期選択、Circular Spectrumの有効バンドを確認し、問題解消後に診断ユニットとログ処理を削除した。Vectorscopeの編集時／再生時表示とCircular Spectrumの描画はユーザー実機確認済み。

## 2026-07-16 Spectrogram / Vectorscope removal

- Monitorへ追加したSpectrogramとVectorscopeは、通常利用での有用性が低いため不採用とした。
- ツールバーボタンと表示ページだけでなく、両描画ユニット、Vectorscope専用共有メモリ、Filter側の要求判定、L/R代表点採取、履歴書き込みを削除した。
- MonitorはWave / Spectrumの2表示へ戻した。既存のWave、Spectrum、Peak Meter、Stereo Balance、Aul2Audio View用解析は維持する。

## 2026-07-15 Aul2AudioMonitor Input/Output vectorscope

- Monitorのツールバーへ`Vectorscope`を追加し、エフェクト処理前のInputと処理後のOutputについて、L/Rの広がりと位相傾向を並べて比較できるようにした。
- 専用共有メモリ`Local\Aul2AudioMonitorVector`へ各64組のL/R代表点とレイヤー別128件の履歴を保持し、既存のWave/Spectrum共有構造のバージョンは変更していない。
- Vectorscopeページが表示中のときだけMonitorから要求時刻を通知し、Filterは要求が250ms以内の間だけ、既存の音声バッファ読み取りから代表点を採取するようにした。FFTや追加の全サンプル走査は行わない。
- Inputをグリーン、Outputをアンバーとし、両方を同じ自動倍率で描画する。モノラルは縦、逆相成分は横へ広がる一般的な45度回転表示とした。
- FilterとMonitorのDebug／Release Win64ビルドが、警告0・エラー0で成功した。Release版を`Aul2AudioFilter.auf2`と`Aul2AudioMonitor.aux2`へ反映した。
- 編集停止中は音声コールバックが継続しないため、Vectorscope描画側の2.5秒鮮度判定で表示が消えていた。共有状態が有効な間は最後の表示を保持するよう、Wave／Spectrumと同じ編集時の扱いへ修正した。
- ユーザー実機確認により、再生中の動作と編集停止中の表示保持が正常であることを確認した。READMEの「モニターのモード」へ`Vectorscope`の用途と見方を追加した。

## 2026-07-15 Aul2AudioMonitor Input/Output spectrogram

- Monitorのツールバーへ`Spectrogram`を追加し、エフェクト処理前のInputと処理後のOutputを上下2段で表示するようにした。
- Filter側がすでに共有している64バンドの`InputBands` / `OutputBands`を再利用し、FFT処理や共有メモリ構造は追加していない。
- Spectrogramページの表示中だけ約20fpsで最大128列を蓄積し、約6.4秒の履歴として描画する。Wave／Spectrum表示中は履歴更新も描画も行わない。
- 描画負荷を抑えるため、128×64ピクセルの32bitビットマップへ直接色を書き、表示領域へ拡大する方式にした。
- Release Win64ビルドが警告0・エラー0で成功した。AviUtl2が起動中のため、`Aul2AudioMonitor.aux2`への差し替えは保留した。

## 2026-07-15 Controller release package inclusion

- `Setup\make_release_zip.bat`から呼ばれる配布スクリプトへ`Aul2AudioController.aux2`の存在チェックとコピー処理を追加した。
- `Setup\Aul2AudioFilter.zip`を再生成し、Controllerを含む5プラグイン、README、残響継続用WAVが格納されることを確認した。

## 2026-07-15 Aul2AudioController DPI layout fix

- 高DPI環境でノブ下の数値入力欄がカード下端から欠ける問題を修正した。
- 子`TEdit`の自動高さを無効にし、フォントPPIから入力欄の高さを明示的に計算するようにした。
- ノブ描画部分は固定ピクセルのまま維持し、DPIで増えた入力欄の高さだけカードと行間へ加えるようにした。
- Release Win64のDelphiコンパイルは警告0・エラー0で完了した。AviUtl2が既存の`Aul2AudioController.aux2`を使用中だったため、ビルド後のファイル差し替えは保留した。

## 2026-07-15 View / Preset migration to Aul2AudioController

- Controllerの起動直後と同期失敗時は、選択欄を残してエフェクター操作部だけを隠し、その下へサウンドエフェクターを追加した音声Objectまたはグループ制御（音声）の選択案内を表示するようにした。設定を正常に読み込めた時点で操作画面を表示する。
- `エフェクトプリセットの管理` と `波形表示オブジェクトの配置` は同期状態に関係なく選択でき、特殊ページからエフェクターへ戻った時は改めて同期を確認する。
- 未同期案内はエフェクター固有色を使わず、暗いニュートラル背景と目に優しい淡い黄色の文字にして判読性を上げた。
- プリセット削除はダイアログを使わず、状態欄の下へ `OK`／`キャンセル` を表示するインライン確認方式に変更した。一覧の選択変更、名前編集、並べ替え、D&D、ページ再表示では確認状態を解除し、確認ボタンを非表示へ戻す。
- プリセットへの新規追加であることを明確にするため、操作ボタンと利用者向け説明の表記を `保存` から `登録` へ変更した。内部のINI保存処理名は変更していない。
- Controllerの縦配置でView配置とPresetの下部余白を縮小した。通常時は状態欄を4pxだけ確保し、結果やエラーがある時だけ18pxへ広げる。Presetは削除確認中だけ一覧を縮めて `OK`／`キャンセル` 用の高さを確保する可変レイアウトとした。
- エフェクターの表示灯と説明文を分離した。表示灯はLEDの右へ現在状態を `ON`／`OFF` で描画する独立スイッチとし、機能説明はその右側の別ラベルへ表示する。
- ランプ押下中に面を固定の黒で塗っていた処理を廃止し、透明ブラシの持ち越しも防いだ。説明文とMode Caption／コンボボックスは、ノブと同じエフェクター別ボリューム色で塗った独立パネル上へ配置した。
- 説明パネルとModeパネルは、スイッチと同じ7pxの角丸領域で描画するようにした。
- Delayの文字色を黒へ変更し、Compressorのボリューム面を `#B8B8B8` へ少し明るくした。表示灯右側の説明文字は従来より2px大きくした。
- 黒いノブ上で指示線も黒になっていたDelay、EQ、Compressor、Noise、Auto Gain、Noise Gate、Chorus、Limiterは、各ベース色を明るくした指示線色へ変更した。
- View表示オブジェクトの配置とユーザープリセット管理を、Aul2AudioMonitorの補助ページからAul2AudioControllerの選択画面へ移行した。
- Controllerの選択リスト末尾は `エフェクトプリセットの管理`、`波形表示オブジェクトの配置` の順とし、縦長・正方形ウィンドウ向けの専用配置で既存パネル機能を共有する。
- MonitorはWave／Spectrumの監視に専念させた。将来の復活を容易にするためView／Presetのコードと横配置は削除せず、`ENABLE_MONITOR_EDIT_PAGES = False` の間はツールバーボタン、ページ、編集パネルを生成しない。
- READMEのView配置手順とPreset操作元をControllerへ更新し、Monitorから旧View／Preset説明を削除した。noteも現在の役割分担へ更新した。
- Aul2AudioMonitorのDebug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioMonitor.aux2` へコピーされた。

## 2026-07-15 Aul2AudioController View object placement

- Controllerの最上段選択へ `波形表示オブジェクトの配置` を追加し、選択時に幅、高さ、秒数、FPS、配置レイヤー、Send、D&Dを持つ既存の `TAul2AudioBasePanel` を表示するようにした。
- エフェクト定義数は20のまま維持し、配置画面は21番目の特殊項目として扱う。配置画面の選択中はエフェクトの読込・書込を行わない。
- Monitor側のViewページは復活が必要になる可能性を考慮して残した。機能を複製せず、MonitorとControllerが同じパネル実装を共有する。
- ControllerプロジェクトへBase生成とD&Dに必要な既存ユニット参照を追加した。Debug Win64ビルドは警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。
- Controllerは縦長・正方形で使うため、共有Baseパネルへ縦配置モードを追加した。設定欄、レイヤー一覧、Send、状態表示の順に縦へ並べ、Monitorは従来の横配置を維持する。

## 2026-07-15 Aul2AudioController preset management

- Controllerの最上段選択へ `エフェクトプリセットの管理` を追加し、MonitorのPresetページで使っている `TAul2AudioPresetPanel` を共有表示するようにした。
- Controllerでは一覧を上側へ大きく取り、その下へ保存・削除ボタンを横並び、最下部へ状態表示を置く縦配置とした。Monitorは従来の一覧左・操作欄右の横配置を維持する。
- 保存、名前のインライン編集、`Ctrl+Up` / `Ctrl+Down` の並べ替え、削除、タイムラインへのD&Dは既存処理をそのまま利用する。Preset画面の選択中はエフェクト同期を行わない。
- ControllerとMonitorのDebug Win64ビルドが警告0・エラー0で成功し、両方の `.aux2` へコピーされた。
- Controllerの選択リスト末尾は、利用頻度を考慮して `エフェクトプリセットの管理`、`波形表示オブジェクトの配置` の順にした。

## 2026-07-15 Aul2AudioController completion

- Aul2AudioControllerは全20エフェクトの表示、現在値取得、Use切り替え、選択項目、数値ノブ、ホイール、直接入力、選択中Objectへの項目単位書き込みが揃い、ユーザー確認を経て機能完成とした。
- エフェクト固有のパラメーターと配色は定義ユニットへ集約し、Viewと同期処理は共通実装を維持した。明色面の文字コントラストを含む最終配色も確認済み。
- `note.md` からControllerの検討仕様と確認課題を削除し、利用方法、操作方法、対象Object、AviUtl2の `表示` メニューからの開き方を `README.md` へ追加した。
- 配布ファイルとして `Aul2AudioController.aux2` をREADMEへ追記した。

## 2026-07-15 Aul2AudioController minimum extension plugin

- `Aul2AudioMonitor` の export とクライアント登録方式を参考に、`Aul2AudioController.dpr`、`Aul2AudioController.dproj`、`Source\Aul2AudioControllerPlugin.pas` を追加した。
- `InitializePlugin` / `UninitializePlugin` / `RegisterPlugin` を export し、AviUtl2 の編集メニューと管理クライアントウィンドウへ `Aul2AudioController` を登録する最小構成とした。
- クライアントは Win32 のダーク背景とプレースホルダー文字だけを描画する。パラメーター同期、エフェクターリスト、ノブ UI は次段階とし、依存を追加していない。
- Debug / Release Win64 ビルドが警告なしで成功し、`C:\ProgramData\aviutl2\Plugin\Aul2AudioFilter\Aul2AudioController.aux2` へコピーされることを確認した。
- `tdump` で `InitializePlugin` / `RegisterPlugin` / `UninitializePlugin` の export を確認した。

## 2026-07-15 Aul2AudioController effect definition and EQ switching

- `Source\Aul2AudioControllerEffectDefinition.pas` を追加し、エフェクター名、日本語LED表記、配色、Use項目、選択項目、ノブの表示名・Alias項目名・範囲・刻み・小数桁・単位をViewから分離した。
- Delayの既存定義を専用ユニットへ移し、EQには `Mode`、`Low Cut`、`High Cut`、`Mix` の定義を追加した。
- 同期処理をDelay固定レコードからエフェクター定義を受け取る汎用処理へ変更した。選択中ObjectのAlias取得は従来通り1回で、定義されたUse、Select、Volume項目をまとめて読む。
- エフェクターコンボでDelayとEQを切り替えると、LED表記、選択コンボ、ノブ数、範囲、単位、背景色が再構成され、選択中Objectの対応パラメーターを実際に読み書きするようにした。EQでは4個目のノブを隠して3個を上詰め配置する。
- 残り18エフェクターは従来の選択順、配色、日本語LED表記を定義ユニットへ移した。パラメーター未接続時は操作コントロールを表示せず、誤書き込みを行わない。
- `Aul2AudioController.dproj` のDebug Win64ビルドが成功し、`Aul2AudioController.aux2` へコピーされた。

## 2026-07-15 Aul2AudioController Compressor parameters

- Compressorの `Use`、`Threshold`、`Ratio`、`Attack`、`Release`、`Makeup`、`Mix` を既存の汎用定義・同期へ接続した。
- Viewが保持していたDelay由来の4個の名前付きノブを、定義側の上限と同じ7個の共通配列へ置き換えた。エフェクト追加時にViewのフィールドや分岐を増やさず、定義だけで表示数、値域、刻み、単位を切り替える。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。実機での6ノブ表示と読み書きは確認待ち。

## 2026-07-15 Aul2AudioController Voice Drive parameters

- Voice Driveの `Use`、`Drive`、`Body`、`Level`、`Mix` を既存の汎用定義・同期へ接続した。
- Viewや同期処理にはエフェクト固有処理を追加せず、定義追加だけで4ノブの表示、値域、刻み、単位、Alias項目名を切り替える構成を維持した。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。実機での4ノブ表示と読み書きは確認待ち。

## 2026-07-15 Aul2AudioController Distortion parameters

- Distortionの `Use`、`Mode`、`Drive`、`Tone`、`Level`、`Mix` を既存の汎用定義・同期へ接続した。
- `Mode` は `Soft Clip` / `Hard Clip` の選択コンボ、残りは4ノブとして表示する。View・同期・配色にはDistortion固有処理を追加していない。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。実機での表示と読み書きは確認待ち。

## 2026-07-15 Aul2AudioController Noise parameters

- Noiseの `Use`、`Mode`、`Level`、`Mix` を既存の汎用定義・同期へ接続した。
- `Mode` は `White` / `Crackle` の選択コンボ、残りは2ノブとして表示する。音声処理側で既知の無音化・例外調査候補があることは変更せず、Controllerは設定の読み書きだけを担当する。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。実機での表示と読み書きは確認待ち。

## 2026-07-15 Aul2AudioController Bit Crusher / Tremble / Wobble parameters

- 定義追加だけで接続できる連続3エフェクトをまとめ、既存の汎用表示・同期へ接続した。
- Bit Crusherは `Use`、`Bit Depth`、`Sample Hold`、`Mix` の3ノブを表示する。
- Trembleは `Use`、`Rate`、`Depth`、`Mix` の3ノブ、Wobbleは `Use`、`Delay`、`Depth`、`Rate`、`Mix` の4ノブを表示する。
- 3エフェクトとも選択コンボはなく、View・同期・配色へ固有処理を追加していない。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。実機での表示と読み書きは確認待ち。

## 2026-07-15 Aul2AudioController Pitch parameters

- Pitchの `Use`、`Mode` と7個の数値項目を既存の汎用定義・同期へ接続した。
- `Mode` は `Natural` / `Pitch Only` / `Formant Only` / `Step`。数値項目は `Semitone`、`Window`、`Formant`、`Amount`、`Step`、`Rate`、`Mix`。
- モードごとの表示切り替えは追加せず、元GUIと同様に全項目を表示する。これによりViewへPitch固有処理を持ち込まず、定義上限7ノブの検証対象とする。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。実機では7ノブの複数段配置と下端の収まりを重点確認する。

## 2026-07-15 Aul2AudioController Ring Mod / Muffle / Whisper parameters

- 定義追加だけで接続できる3エフェクトを既存の汎用表示・同期へ接続した。
- Ring Modは `Use`、`Frequency`、`Depth`、`Mix`、Muffleは `Use`、`Cutoff`、`Amount`、`Mix`、Whisperは `Use`、`Level`、`Tone`、`Mix` を表示する。
- いずれも選択コンボなしの3ノブ構成で、View・同期・配色へ固有処理を追加していない。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。実機での表示と読み書きは確認待ち。

## 2026-07-15 Aul2AudioController Auto Gain / Noise Gate / Ghost parameters

- Auto Gain、Noise Gate、Ghostを既存の汎用表示・同期へ接続した。
- Auto Gainは `Target`、`Speed`、`Max Gain`、`Mix`、Noise Gateは `Threshold`、`Attack`、`Release`、`Floor`、Ghostは `Size`、`Feedback`、`Wet`、`Mix` を表示する。
- いずれも選択コンボなしの4ノブ構成で、View・同期・配色へ固有処理を追加していない。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。実機での表示と読み書きは確認待ち。

## 2026-07-15 Aul2AudioController Chorus / Reverb / Output / Limiter parameters

- Chorus、Reverb、Output、Limiterを既存の汎用表示・同期へ接続し、全20エフェクターのパラメーター定義を揃えた。
- Chorusは `Stereo Mode` と `Delay` / `Depth` / `Rate` / `Mix`、Reverbは `Type` と `Room Size` / `Damping` / `Dry` / `Wet` を表示する。Outputは `Gain`、Limiterは `Ceiling` / `Release` / `Mix` を表示する。
- 全インデックスが固有定義を持ったため、重複していたプレースホルダー用の表示名・説明文配列と生成処理を削除した。View・同期・配色への固有分岐は追加していない。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。全20エフェクターの実機表示と読み書きは確認待ち。

## 2026-07-15 Aul2AudioController final effect colors

- ユーザー指定の全20エフェクター分のメイン色、ボリューム色、指示線色を `EFFECT_COLORS` へ反映した。Whisper/BreathはWhisper、Reverse Reverb/GhostはGhostの定義へ対応させた。
- ボリューム色と指示線色は指定されたRGB値をそのまま使う。メイン色だけは知覚明度が上限を超える場合に限り、暗いニュートラル色へ上限到達分だけ混ぜる方式へ変更した。
- 黒、ダークグレー、濃いブルー、濃いマゼンタなど、元から明度上限以下のメイン色は追加で暗くしない。従来の全色一律ブレンドは廃止した。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。

## 2026-07-15 Aul2AudioController text contrast

- EQ、Compressor、Noise、Auto Gain、Noise Gate、Chorus、Limiterは明るいボリューム面に白文字が重なっていたため、LED面、モード見出し、ノブ見出し、単位を黒文字へ変更した。
- 文字色を `EFFECT_COLORS` のエフェクター別設定へ追加し、Viewにエフェクター名による分岐を持たせない構成にした。暗い背景の数値入力欄は白文字を維持する。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。

## 2026-07-15 Aul2AudioController softer base colors

- エフェクター識別色を全面ベースへそのまま使うと長時間操作で目が疲れるため、背景色を暗いニュートラル色へブレンドするようにした。
- BOSSの代表的な実機を参考に、Delay/EQは白・銀、Compressorは青、Overdrive系は黄、Distortionは橙、Tremoloは緑、Vibrato/Pitch/Chorusは青系、Reverb/Noise Suppressorは灰系へ再割り当てした。直接対応する定番機がない処理は近い音響カテゴリの慣用色へ寄せた。
- 20色を `EFFECT_COLORS` const配列へ集約した。各行に筐体基準の `PedalColor`、ボリュームカードの `VolumeColor`、ノブ位置線の `IndicatorColor` を持たせ、それぞれ独立して変更できる。
- 広い背景面とカード外周は `PedalColor` を暗いニュートラル色へ共通比率で混ぜる。ボリュームカードと位置線は定義色をそのまま使うため、後からは該当エフェクトの1行だけで3箇所を調整できる。
- Debug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。

## 2026-07-15 Aul2AudioController volume control preview

- Controllerの肥大化を避けるため、連続数値パラメーターの描画を `Source\Aul2AudioControllerVolumeControl.pas` の `TAul2VolumeControl` へ分離した。
- Delay仮GUIの `Time(ms)` / `Dry` / `Wet` / `Feedback` のラベルとEditを、黒い立体ノブ、テーマ色の位置線、値欄を持つ表示専用コントロールへ置き換えた。
- 初期案の三角マーカーは廃止し、影付きの少し太い指示線へ変更した。外周ベベル、左上のハイライト、右下の陰影、内側の段階的な明度差を追加して円の立体感を強めた。
- ノブ下部の描画値欄を小型の読み取り専用 `TEdit` へ置き換え、単位はEditの右側へ独立表示した。単位がないパラメーターはEditが下部幅を広く使う。
- TEdit追加直後の起動時クラッシュは、Parent接続前の `LayoutValueEdit` が `ClientWidth` / `ClientHeight` を読み、Handle生成を要求して `InvalidControlOperation` になったことが例外履歴から判明した。生成中の配置計算をHandle不要の `Width` / `Height` へ変更し、子Editとノブのプロパティを完全に設定してからParentへ接続する順序および未生成ガードも維持した。
- 実機画像を基に、DPI拡大で広がっていたノブと数値Editの間隔を固定描画基準で詰めた。ノブ外側の最小角・最大角には短い終端線を追加し、回し切り位置を視覚化した。
- ノブ操作を実装した。4pxの閾値後に縦横どちらかへ操作軸を固定し、縦は上方向、横は右方向で増加する。縦の粗調整は全値域 `1/180` /px、横の微調整は `1/600` /pxとし、双方を `Aul2AudioControllerVolumeControl.pas` 先頭の独立したconstへ置いた。
- マウスキャプチャ付きドラッグ、ホイールによる刻み1単位変更、TEditのEnter/フォーカス移動確定、Esc取消、範囲制限、刻み丸めを追加した。値が変わった時だけControllerへ通知し、Delayの該当1項目だけを選択中Objectへ書き込む。失敗時は表示値を変更しない。
- ノブ操作中のTEdit文字更新でわずかにちらつくため、文字列変更中は `WM_SETREDRAW` で再描画を止め、設定後に背景消去なしで1回だけ描画するようにした。親ノブには `WS_CLIPCHILDREN` を付けてTEdit領域を親描画から除外し、値変更時のノブ再描画も指示線周辺だけに限定した。
- エフェクター選択方式を有効項目だけのリスト案から全項目入りコンボボックスへ変更し、実際の音声処理順で20エフェクターを登録した。閉じたコンボ上のホイールで前後へ移動し、先頭・末尾では停止する。ドロップダウン中は標準操作を維持する。
- この段階の選択変更は状態ラベルへのプレビュー表示だけとし、DelayのUse、Stereo Mode、ボリューム値、AviUtl2側パラメーターには接続していない。
- コンボの初期表示だけOSテーマの明るい描画になる問題に対し、Syncroh2のコンボテーマ適用を参照して、全プロパティ設定とParent接続後、フォーム表示前に `SetWindowTheme(Handle, '', '')` を適用した。エフェクターコンボを最上段へ移し、直下に将来の電源ボタン・表示灯用となる不可視の `LampSwitchHost` パネルを仮配置した。
- 上記変更直後、Parent接続前の `TComboBox.Items.Add` がHandle生成を要求して `InvalidControlOperation` になることを例外履歴で確認した。Styleと色を設定後、Parentへ接続してからItemsを登録し、最後にフォーム表示前のテーマ適用を行う順序へ修正した。
- Delayを基準に最終レイアウト調整を開始し、最上段からエフェクターコンボ、Use、`Stereo Mode`のラベルと選択コンボ、ノブ領域の順へ上詰めした。Useは将来の電源ボタン・表示灯用 `LampSwitchHost` 内へ移し、デバッグ用状態ラベルは非表示にした。Useのネイティブチェックにもフォーム表示前のダークテーマを適用した。
- `Source\Aul2AudioControllerLampSwitch.pas` を追加し、Useチェックボックスをギターエフェクター風の `TAul2LampSwitch` へ置き換えた。ON時は暗赤の外周グロー、明るい赤色LED、反射点を重ね、OFF時は消灯した暗赤表示にする。Delayの表記は「遅延音を加える」とし、LEDと文字を含む全面クリック、Space／Enter操作、既存 `Dly: Use` 同期へ対応した。
- LEDの外周グロー、本体、反射点を一回り拡大した。さらにエフェクター別テーマ色の見た目確認として、20項目それぞれに暗い青・緑・黄・赤・紫などを割り当て、コンボ選択時にRootPanel、LEDスイッチ面、各ボリュームカード面を同系色へ変更するようにした。白系文字と黒いノブの視認性を優先して低輝度に抑え、値や同期先はDelayのまま維持する。
- 初回テーマ色が抑えすぎていたため、RootPanel側だけをエフェクター本来の青・緑・黄・赤・紫などが明確に分かる中低輝度の高彩度色へ変更した。LEDスイッチ面とボリュームカード周囲は従来の暗いテーマ色を維持し、文字とノブの視認性を比較できる構成にした。
- 読み込んだ数値を値域へ正規化して270度のノブ角へ反映する。今回、ドラッグ、ホイール、直接入力、数値項目のObject書き込みは接続していない。
- Controller側は4コントロールの生成、値設定、DPIスケール、横幅に応じた折り返し配置だけを担当する。`Use` と `Stereo Mode` の既存同期は維持した。
- `Aul2AudioController.dproj` のDebug Win64ビルドが警告0・エラー0で成功し、`Aul2AudioController.aux2` へコピーされた。

## 2026-07-13 User preset completion

- `Aul2AudioMonitor` に `Preset` ページを追加し、選択中Objectのエイリアスをユーザープリセットとして保存できるようにした。
- ユーザープリセットはドキュメントの `Aul2AudioFilter\UserPresets.ini` へまとめて保存する。
- エイリアスはBase64化せずRTTIモデルへ分解し、`SectionFileManager` の二重セクション方式で読み書きする。INIを直接確認しやすい形式を維持する。
- プリセット一覧からタイムラインへD&Dすると、保存済みの設定を持つ `グループ制御（音声）` Objectを生成する。
- 一覧の項目はダブルクリックでインライン編集でき、Enterまたはフォーカス移動で確定、Escで取り消す。確定時は表示名、Preview、INIを同時更新する。
- Presetツールバーボタンは最長Captionの実測幅を基準にし、DPI環境でも末尾が切れないよう4ボタン分の幅を確保した。
- 音声Objectへフィルターを直接適用する用途は少なく、D&Dの方が操作も単純なため、選択中Objectへ設定を反映する「読み込み」機能は実装しない。
- ユーザープリセットは `グループ制御（音声）` 専用機能として完成扱いとする。

## 2026-07-12 Delay tail handoff between adjacent audio clips

- AviUtl2では音声WAVの末尾を伸ばせないため、元WAVの直後へ無音または極小ノイズWAVを配置し、`グループ制御（音声）` のDelay残響を継続できるようにした。
- AudioTraceで、元WAVと後続WAVが同じ `EffectID` / Layerを持つ別Objectとして、前後順に `FilterProcAudio` へ来ることを確認した。
- 同じ `EffectID`、同じ内部レイヤーで、前の音声から1～2フレーム以内に次の音声が `SampleIndex = 0` で開始した場合、Delayリング状態を後続Objectへ引き継ぐ。
- 無音判定には依存しないため、`Sample\無音_極小ノイズ_ループ推奨.wav` を残響テール用素材として利用できる。
- 後続ObjectのContextは再生後も残るため、未初期化時だけでなく、後続Objectが `SampleIndex = 0` から再生されるたびに直前Objectの最新Delay状態で更新する。これにより2回目以降の再生でも残響を正しく引き継ぐ。
- 重なっている音声、離れた位置の音声、別EffectのContextは従来どおり分離する。実機再生で元WAV終了後もエコーが続くことを確認済み。

## 2026-07-11 Aul2AudioView reset button

- `Aul2Audio View` の最上段へ `初期値に戻す` ボタンを追加した。
- ボタンを押すと、`Source Layer`、View Type、Style、描画量、周波数範囲など、色以外の View パラメーターを登録時の初期値へ戻す。配色は表示設定とは分けて保持する仕様とした。
- パラメーターが多い View を最初から調整し直せるようにするための機能として、`README.md` の View Parameters に利用方法を追加した。

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

- 2026-07-14、Monitorのサイズ変更後にツールバーを含む画面全体が消える現象へ再対応した。親クライアントのリサイズ途中で子ウィンドウが一時的に非表示になり、元と同じ寸法へ戻った際に早期終了して再表示されない経路を修正した。
- Syncroh2の `PluginExSyncroh2Frame.Show` / `OnToolBarChange` にある再表示、親Realign、ToolBar Invalidateの手順を参考にし、可視状態が壊れている場合は同じサイズでも `SWP_SHOWWINDOW`、選択ページ再適用、RootPanel再配置、ToolBar再描画を行う。
- 現象がPresetページ表示中に限定されるという実機確認を受け、可視性フラグの破損時だけでなく、通常のサイズ変更時にも選択ページを再適用するよう修正した。Preset内の編集コントロールが再配置された後にPanelの前面状態、RootPanel、ToolBarを順に復元する。
- 上記修正後、Preset一覧は表示されるが右側の保存・削除・状態欄が消える現象を確認した。選択ページ再適用後に `TAul2AudioPresetPanel.RefreshLayout` を呼び、子コントロールの座標、Visible、前面順を明示的に復元するよう追加修正した。
- 追加修正でも改善しなかったためページ管理を再調査した。`ToolBarPanelManager.UpdatePanels` が整列停止をToolBarの親HeaderPanelへ掛け、実際にVisibleを変更するページ群の親RootPanelを保護していなかった。描画中心のViewでは表面化しにくい一方、ListBox・Button・Editを持つPresetではウィンドウ順が崩れるため、ページ群の共通親をDisableAlign/EnableAlign/Realignするよう修正した。Preset固有のRefreshLayoutもRootPanelの最終Realign後へ移した。
- 上記ページ管理変更でPreset表示中にツールバーまで消え、悪化したため撤回した。リサイズ中に `RefreshActive` でページを非表示・再表示することを避け、現在ページを維持したままPresetパネル、一覧、保存・削除ボタン、状態欄の各ネイティブウィンドウへ `ShowWindow` を直接適用する方式へ変更した。
- ツールバーは復旧するがPreset内容はホバーするまで表示されないという実機確認から、残件を可視性ではなく再描画要求の欠落と判断した。Presetのレイアウト・可視性復旧後に `RedrawWindow` の `RDW_ALLCHILDREN` / `RDW_UPDATENOW` を使い、一覧と操作欄を即時再描画するよう変更した。
- `RedrawWindow` の即時描画ではPreset内容が完全に空になる結果だったため撤回した。Presetパネル、一覧、保存・削除ボタンをWin32 `SetWindowPos`で1px縮小して元へ戻し、`WM_SIZE`と各コントロール本来の再描画経路を発生させるダミーリサイズ方式へ変更した。
- ダミーリサイズで内容とボタンは大幅に改善したが、ListBoxの外枠だけ描画されない実機結果を受け、`SetWindowPos`へ `SWP_FRAMECHANGED` を追加した。さらに各対象ウィンドウ単体へ `RDW_FRAME` を指定し、親背景や他の子を消去せず非クライアント枠を即時再描画する。
- `SWP_FRAMECHANGED` / `RDW_FRAME` で再び全内容が表示されなくなったため撤回した。改善していた通常のダミーリサイズへ戻し、ListBox自身の非クライアント枠を `bsNone` にして、外側の `TPanel` のLowered枠で安定して表示する構成へ変更した。

- 2026-07-13、AviUtl2の `aesSave` 状態をMonitor上で `State: Encode` と表示するようにした。エンコード開始時はWave/Spectrumの表示履歴と再生同期履歴をクリアする。
- エンコード中は50msタイマーによるフレーム取得、共有メモリ読み取り、Wave/Spectrum再描画を停止する。ウィンドウ再露出など外部要因でPaintが発生した場合も空背景だけを描き、エンコード負荷を抑える。
- `Aul2Audio View` はエンコード映像に必要なWave/Spectrum解析値の読み取りと描画を継続する。一方、`Local\Aul2AudioViewFrame` への描画フレーム通知はMonitorの再生同期専用なので、エンコード中はSpectrum系・Wave系の両方で省略する。
- MonitorのViewページにある送信ボタンは、表示を `選択レイヤーへ作成` から `Send` へ変更し、幅を180px相当から64px相当へ縮小した。
- Viewページのレイヤーリスト幅を170px相当から120px相当へ縮小し、後続する `Send` ボタンと状態表示を左へ寄せた。

- 2026-07-13、Preset一覧で `Ctrl+Up` / `Ctrl+Down` を押すと、選択中のユーザープリセットを1件ずつ上下へ移動できるようにした。変更後の順序は `UserPresets.ini` へ即時保存し、名前のインライン編集中はショートカットを抑止する。AviUtl2側へキー操作が流れないよう、Syncroh2の `ShortcutAction` を共通ライブラリとしてコピーして利用した。
- 新規保存時の初期名は、件数から単純生成せず、一覧に存在しない最小番号を探して `新しいプリセット N` とする方式へ変更した。削除や並べ替え後も既存名と重複しない。
- Presetページの保存ボタン下へ削除ボタンを追加した。削除後は同じ一覧位置を選択し、末尾を削除した場合は直前、空になった場合は未選択へインデックスを補正してから新しい順序を保存する。
- Object未選択などの保存エラーはダイアログを使わず、Presetページ右側の状態ラベルへ表示する。正常な保存・削除操作では状態表示を消す。
- 実機確認により、`Ctrl+Up` / `Ctrl+Down` の並べ替え、重複しない初期名、削除後の選択位置更新、ページ内状態表示が正常に動作することを確認した。利用者向け操作説明を `README.md` へ追加した。
- `Aul2AudioMonitor.dproj` の Debug Win64 ビルドが警告なしで成功し、`Aul2AudioMonitor.aux2` へ反映した。

- 2026-07-13、Monitorへ仮の `Preset` ページを追加し、ユーザープリセット一覧からタイムラインへD&Dすると `グループ制御（音声）` Objectを配置できることを実機確認した。
- 次段階の保存機能用に一覧右側へ操作欄と仮の `保存` ボタンを追加した。既存Objectへの読み込みは実装量に対する恩恵が小さいため保留とし、GUIにも追加しない。
- `保存` ボタンでAviUtl2の選択中Objectからエイリアス全文を取得し、名前入力後に一覧と `ドキュメント\Aul2AudioFilter\UserPresets.ini` へ追加する処理を実装した。エイリアスは改行、`=`、日本語、スクリプト文字列を保持するためUTF-8文字列をBase64化して保存する。
- Presetページ初期化時に `UserPresets.ini` を読み、保存済みの名前とエイリアスを復元してListBoxへ表示する。壊れたセクションはその項目だけを無視する。
- その後、Base64では内容を確認しにくいため、PresetとAlias項目をRTTI対応クラスへ変更した。Alias全文は `Section / Key / Value` の型付き項目へ分解し、各項目を個別INIセクションへ平文保存する。D&D時はこの項目リストから `.object` 形式を再構築する方針とした。
- 旧Base64形式やAlias項目を持たない破損プリセットは起動時に一覧から除外し、次回保存時に新形式だけでファイルを再作成する。
- セクション名の階層表現を単純化するため、`SectionFileManager` を導入した。外側のPresetは `[Preset.n]`、内側のAlias項目は `<Alias.n>` とし、同じファイルを異なる括弧で2段階解析する。PresetのRTTIプロパティとAlias項目のRTTIプロパティをそれぞれ素直な `Name=Value` 形式で保存する。
- Preset一覧のD&Dは、固定のグループ制御Aliasを出す仮処理から、選択プリセットの型付き `Section / Key / Value` 項目を `.object` 形式へ再構築して一時ファイルへ保存する処理へ変更した。保存元に含まれる `グループ制御（音声）` と `サウンドエフェクター` の設定をまとめてタイムラインへ渡す。

- 2026-07-13、MonitorのWaveがAviUtl2の素材波形より小さく見える確認を受け、解析値は変更せず表示専用の `WAVE_VIEW_GAIN` を `2.5` から `5.0` へ上げた。入力・出力波形の表示振幅だけが約2倍になり、音声処理、共有メモリ、Peak/RMSには影響しない。
- `DrawWaveEnvelope` の前回座標を描画前に初期化し、Delphiの未初期化可能性警告3件を解消した。

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

- 2026-07-13、View は正常だが Monitor が約 10 フレーム早く見える実機確認を受け、Monitor の再生時参照フレームだけを ViewFrame より 10 フレーム後方へ補正した。Wave / Spectrum は同じ補正済みフレームから共有メモリ履歴を距離優先で選ぶ。View 側の同期処理と履歴リング構造は変更していない。
- `Aul2AudioMonitor.dproj` の Debug Win64 ビルドが成功し、`Aul2AudioMonitor.aux2` へ反映した。

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

## Aul2AudioController Output meter completion note

- 2026-07-17、Controllerエフェクト表示の第二弾として、優先順位1の `Output` へ実音声を使うInput／Output L/R Peakメーターと短いRMS履歴を追加した。
- `Source\Aul2AudioControllerOutputGraph.pas` を追加し、最大幅300px、高さ150pxの既存グラフ領域へ、4本の縦Peakメーターと直近48件のL/R RMS履歴を配置した。共有構造は増やさず、Monitorが使用している `Local\Aul2AudioMonitorState` の `InputPeakL/R`、`OutputPeakL/R`、`InputRmsL/R`、`OutputRmsL/R` とレイヤー別履歴リングを再利用する。
- ControllerはMonitorのような再生中の連続監視を行わない。エフェクター選択、選択Objectの再取得、Useやパラメーター変更など、既存のController更新経路で共有値をスナップショットし、常時更新用タイマーは追加しなかった。
- `Aul2AudioControllerSync.pas` に選択Objectの内部レイヤー取得を追加し、通常はそのレイヤーの共有状態と履歴を読むようにした。
- 初回実機表示では、選択中の `Root` グループ制御と実際に処理されたMonitorの音声レイヤーが異なり、表示枠は出るが `no audio data` になった。選択レイヤーに有効データがない場合は、Monitorと同じく共有ルートの最後に更新された有効音声レイヤーへフォールバックするよう修正した。
- Input色はMonitorと同じ `RGB(92,190,122)`、Output色は `RGB(224,176,72)` に固定した。当初Outputをエフェクトテーマ色で描いたため白くなったが、PeakメーターとRMS履歴の両方をMonitorと同じ緑／アンバーへ統一した。
- 起動直後はRMS履歴が1件だけの場合があり、2点以上を要求していた初期実装では履歴枠だけが空になった。履歴0件時は最新RMSを1件目として補い、1件時は現在値の水平線、2件以上では通常の時系列線を描くよう変更した。
- `Aul2AudioController.dpr` / `.dproj` に共有メモリユニットとOutputグラフユニットを追加した。Release Win64ビルドは警告0、エラー0で成功した。
- ユーザー実機確認により、Input／Output L/Rメーター、RMS履歴、グループ制御選択時のデータ取得、Monitorとの色統一、初期表示時の履歴描画が正常に動作することを確認し、`Output` 表示を完成扱いとした。

## Aul2AudioController Muffle spectrum completion note

- 2026-07-17、Controllerエフェクト表示の第二弾として、優先順位1へ繰り上がった `Muffle` に周波数特性と実音声スペクトルの重ね合わせ表示を追加した。
- `Source\Aul2AudioControllerMuffleGraph.pas` を追加し、既存の最大幅300px、高さ150pxのグラフ領域へ、20Hz～20kHzの対数周波数軸、Input／Outputスペクトル、設定特性カーブ、Cutoff位置を描画する構成にした。
- 設定特性はMuffle DSPと同じ2段の1次ローパスを複素伝達関数として計算し、原音成分、`Amount`、`Mix`を合成した最終振幅を周波数ごとに求める。`Cutoff`、`Amount`、`Mix`の変更時は共有音声を再取得せず、設定カーブだけを即時更新する。
- 実音声スペクトルはMonitorと同じ `Local\Aul2AudioMonitorSpectrum` の `InputBands` / `OutputBands`、BandCount、MinHz、MaxHzを利用し、共有構造は変更しなかった。Inputは `RGB(92,190,122)`、Outputは `RGB(224,176,72)` の細線、設定特性は太い前景線として描いた。
- Output表示で整備した選択Objectレイヤー取得を再利用した。通常は選択レイヤーのスペクトル状態を読み、グループ制御（音声）のように有効データがない場合は共有ルートの最後に更新された有効音声レイヤーへフォールバックする。
- Controllerは再生中にスペクトルを連続更新せず、エフェクター選択や選択Object再取得など既存Controllerの更新時に共有値をスナップショットする方針を維持した。
- `Aul2AudioController.dpr` / `.dproj` に `Aul2AudioMonitorSpectrumShared` とMuffleグラフユニットを追加した。Release Win64ビルドは警告0、エラー0で成功し、`Aul2AudioController.aux2` へ反映した。
- ユーザー実機確認により、MuffleのCutoff／Amount／Mix設定、Input／Outputスペクトル、Cutoff位置、配色、同一周波数軸上の重ね合わせが正常に表示されることを確認し、`Muffle` 表示を完成扱いとした。

## 2026-07-17 Aul2AudioController Pitch spectrum completion note

- Controllerエフェクト表示の第二弾として、優先順位1へ繰り上がった `Pitch` に処理前後の高解像度スペクトル表示を追加した。
- `Source\Aul2AudioControllerPitchGraph.pas` を追加し、最大幅300px、高さ150pxの既存グラフ領域へ、20Hz～20kHzの対数周波数軸、Input／Outputスペクトル、Mode、Pitch量、Mixなどの主要設定を描画する構成にした。InputはMonitorと同じ `RGB(92,190,122)`、Outputは `RGB(224,176,72)` を使う。
- `Source\Lib\AudioMonitor\Aul2AudioPitchSpectrumShared.pas` を追加し、Filter側のPitch処理直前／直後を128帯域で解析したレイヤー別最新値を `Local\Aul2AudioPitchSpectrum` で共有する。最大2048サンプル、Hann窓、20Hz～Nyquist以下20kHzの対数配置DFTを使い、Pitchが有効な場合だけ解析する。
- 初期実装ではPitchがOFFのため専用解析値が生成されず、軸と凡例だけで値が表示されなかった。OFF時または専用解析前は既存Monitorの64帯域Input／Outputスペクトルを128帯域へ線形補間して初期表示し、Pitch ON後に専用128帯域値へ自動的に切り替えるよう修正した。OFFへ戻した場合は古い専用値を残さずMonitor値を使う。
- Output／Muffleと同じ選択Objectレイヤー取得と有効音声レイヤーへのフォールバックを使う。Controllerは再生中に連続更新せず、エフェクター選択や選択Object再取得など既存の更新時だけスペクトルをスナップショットする。
- `Aul2AudioFilter.dpr` / `.dproj` と `Aul2AudioController.dpr` / `.dproj` にPitch専用共有ユニットを追加し、Controller側へPitchグラフを統合した。Filter／ControllerのRelease Win64ビルドは警告0、エラー0で成功し、`.auf2` / `.aux2` へ反映した。
- ユーザー実機確認により、初期スペクトル表示、Monitorとの配色、高解像度の前後形状、Pitch Only +7.9 semitone時にOutputがInputより高周波側へ移動する表示が正常であることを確認し、`Pitch` 表示を完成扱いとした。

## 2026-07-17 Aul2AudioController RingMod spectrum completion note

- Controllerエフェクト表示の第二弾として、優先順位1へ繰り上がった `RingMod` に処理前後スペクトルと側波帯表示を追加した。
- `Source\Aul2AudioControllerRingModGraph.pas` を追加し、最大幅300px、高さ150pxのグラフ領域へ20Hz～20kHzの対数周波数軸、Input／Outputの128帯域スペクトル、Frequency、Depth、Mixを表示する。InputはMonitorと同じ緑、Outputは同じアンバーを使う。
- RingModの振幅変調ではInputの各成分から変調周波数ぶん離れた上下側波帯が生じるため、Inputスペクトルを`-Frequency`／`+Frequency`方向へ移した予測ガイドを薄い2色で背景へ重ねた。実際のOutputと比較することでFrequency変更の効果を確認できる。
- `Source\Lib\AudioMonitor\Aul2AudioRingModSpectrumShared.pas` を追加し、RingMod処理直前／直後を最大2048サンプル、Hann窓、128帯域の対数配置DFTで解析する。レイヤー別最新値を `Local\Aul2AudioRingModSpectrum` でFilterとController間に共有し、RingModがONの場合だけ解析する。
- OFF時または専用解析前はMonitorの64帯域Input／Outputスペクトルを128帯域へ線形補間して初期表示し、ON後は専用128帯域値へ切り替える。再生中の連続更新は行わず、既存Controller更新時のスナップショットだけを描画する。
- 初回配備では描画分岐を実装していたものの、グラフ表示許可リストへRingModのエフェクト番号10を加え忘れたためグラフ全体が表示されなかった。許可リストを修正して表示させた。また、凡例の`±`が文字化けしたため`Sidebands +/-F`のASCII表記へ変更した。
- Filter／ControllerのRelease Win64ビルドは警告0、エラー0で成功し、`.auf2`／`.aux2`へ反映した。ユーザー実機確認により、Frequency 367Hz時のInput、Output、予測側波帯ガイドと設定表示が正常に描画されることを確認し、`RingMod`表示を完成扱いとした。

## 2026-07-17 Aul2AudioController Whisper/Breath graph completion note

- Controllerエフェクト表示の第二弾として、優先順位1へ繰り上がった `Whisper/Breath` の息成分表示を追加した。
- 初期版ではWhisper処理直前／直後を最大2048サンプル、Hann窓、128帯域DFTで解析する専用共有メモリを追加し、Input／Output線と処理後に増えた帯域の`Added breath`塗りを表示した。
- Whisperは周波数を移動せず元音へ小さな息ノイズを加えるため、弱いLevelでは前後線がほぼ重なる。太いOutputがInputを隠したため描画順を変えたが、OFF時にはWhisper局所の前後データが存在せず、Monitor全体のInput／Outputへフォールバックすると他エフェクトを含む別の意味になる問題が残った。
- OFF時の前後を同一に見せる案も検討したが、Monitor全体のInputを複製するとWhisperより前のエフェクトまで元へ戻ったように見えるため不採用とした。`Chain In／Chain Out`表記もON時の局所前後と意味が切り替わるため最終案には採用しなかった。
- 最終版はInput／Output比較を廃止し、MonitorのInputスペクトルを緑の`Reference`として1本だけ表示する。これはWhisper局所入力の厳密値ではなく、調整用の参考表示である。
- 青の`Breath`は実測差分ではなく、DSPの`Breath = Noise - LowNoise`に対応する1次高域通過傾向を予測表示する。ToneからDSPと同じ約900～5100Hzの境界を求め、LevelとMixを小型グラフで読める表示強度へ反映する。ON／OFFで形状やデータ元は変えず、青の明度だけを切り替えるため、ノブ変更時も一貫した意味を保つ。
- 最終仕様では専用の前後解析が不要になったため、Whisper用共有メモリ、Filter側DFT、Controller側専用状態読込を撤去し、既存の `Local\Aul2AudioMonitorSpectrum` だけを再利用する軽量構成へ戻した。
- Filter／ControllerのRelease Win64ビルドは警告0、エラー0で成功し、`.auf2`／`.aux2`へ反映した。ユーザー実機確認により、ReferenceとBreathの区別、Level／Tone／Mixへの追従、ON時の明るい青表示が見やすいことを確認し、`Whisper/Breath`表示を完成扱いとした。

## 2026-07-17 Controller表示解析の要求駆動化

- Controllerグラフ追加に伴うFilter側負荷を抑えるため、SDKの非表示 `FILTER_ITEM_DATA<T>` を使う要求駆動方式へ変更した。`Controller Request V1` はversion、GraphKind、GUIDを持ち、Controllerが選択Objectへ新しい値を書いたときに `FilterProcAudio` を発火させる。
- 最初に1 byte Dataを `00` から `01` へ変更する実験を行い、`SetObjectItemValue=True` と同時刻に新しい値で `FilterProcAudio` が発火することをDebugログで確認した。
- 本実装では `Local\Aul2AudioControllerRequestV2` の小型共有制御マップへ、現在有効なGUID、GraphKind、Controllerウィンドウ、Monitor表示、Aul2Audio Viewの直近処理時刻を保持する。Object側Dataと共有制御側のGUID／GraphKindが一致し、Controllerウィンドウが有効な場合だけController専用解析を許可する。
- Noise波形、Voice Drive XY、Pitch 128帯域Spectrum、RingMod 128帯域Spectrumを対象GraphKindの要求時だけ採取・解析・共有するよう変更した。要求がなければエフェクト本体のDSPだけを行う。
- 共通Wave／Spectrum／Meterは、ControllerのMuffle／Whisper／Output、実際に表示中のAul2AudioMonitor、直近1秒以内に処理されたAul2Audio Viewのいずれかが要求した場合だけ生成する。Monitorフォームは登録時に作られるため、単なる `IsWindow` ではなく親クライアントを含む実表示状態を50msタイマーで通知するようにした。
- DebugログでMonitor表示中に `common monitor capture enabled=True`、非表示後に `False` へ遷移することを確認した。非表示中のDelay操作ではControllerのGraphKind 1要求が発生したが、Delay自体は共通解析を要求しない。Aul2Audio Viewが同時に再評価された場合だけView要求として一時的に共通解析が有効になる。
- 共有状態へ応答GUIDを追加し、Controllerは現在要求したGUIDと一致するNoise／Voice Drive／Pitch／RingMod／Monitor状態だけを表示する。構造変更に伴い共有versionを更新し、旧サイズの同名マップとの衝突を避けるため、Monitor状態を `Local\Aul2AudioMonitorStateV9`、Spectrumを `Local\Aul2AudioMonitorSpectrumV7`、各専用マップもV2名へ変更した。
- 初回実機確認では旧名Monitor共有マップと新構造のサイズが衝突し、`TSharedMemoryBase.Create` で実行時エラーになった。マップ名へ構造versionを付ける修正後は正常起動し、Controller／Filter間でGraphKind 4とGUIDが一致する要求処理を確認した。
- Filter、Controller、Monitor、Aul2Audio ViewのDebug／Release Win64ビルドは警告0、エラー0で成功し、対応する `.auf2`／`.aux2` へ反映した。

## 2026-07-17 Aul2AudioController Tremble RMS history implementation note

- 未実装グラフの優先順位1だった `Tremble` に、処理直前／直後のRMS時間履歴を追加した。
- `Source\Lib\AudioMonitor\Aul2AudioTrembleRmsShared.pas` を追加し、レイヤーごとに192件のSampleIndex、Input RMS、Output RMSをリング保持する `Local\Aul2AudioTrembleRmsV1` をFilterとControllerで共有する。新しいController要求GUIDへ切り替わった場合や再生位置が戻った場合は履歴を初期化する。
- Filter側の `ProcessTremble` は `ControllerGraphRequested(AUDIO_CONTROLLER_GRAPH_TREMBLE)` が真の場合だけ、既存DSPループ内で前後の二乗和を集計してRMSを求める。要求がない通常処理では追加ループ、共有メモリ生成、共有書込みを行わない。
- `Source\Aul2AudioControllerTrembleGraph.pas` を追加し、-60～0dBの共通軸へInputを緑、OutputをTrembleテーマ色で表示する。SampleIndexを横軸位置へ使い、現在表示している時間幅も併記する。
- Trembleグラフ表示中だけControllerの既存100msタイマーから共有リングを読み直す。Controllerフォームが非表示の場合はポーリングしない。さらにFilter側要求検証へ `IsWindowVisible` を加え、フォームが存在していても非表示ならController専用解析を許可しないようにした。
- Filter／ControllerのRelease Win64ビルドは警告0、エラー0で成功し、`Aul2AudioFilter.auf2`／`Aul2AudioController.aux2` へ反映した。AviUtl2上の時間履歴表示と非表示時負荷は実機確認待ち。

## 2026-07-17 再生中のController要求Data書込み防止

- Controllerが新しいグラフ要求を発行するとき、選択Objectの非表示 `Controller Request V1` DataへGUIDとGraphKindを書いてFilter再評価を発火させていた。この `SetObjectItemValue` が再生中にも実行され、AviUtl2の再生を停止させる問題が判明した。
- `IssueControllerRequest` は、Object側Dataが現在の要求と一致していて書込み不要な場合だけ既存要求を継続する。新しいGUIDが必要な場合は `AviUtl2GetEditState` を確認し、再生中または出力中なら共有要求を無効化して書込みを保留する。
- 保留中はControllerへ `analysis waits for playback/output stop` と表示する。既存100msタイマーが編集状態への復帰を検出すると、現在の選択Objectを再取得してから要求Dataを自動発行する。Controllerフォームが非表示の場合は再発行しない。
- `Aul2AudioController.dproj` のRelease Win64ビルドは警告0、エラー0で成功し、`Aul2AudioController.aux2` へ反映した。再生中にControllerへ入った場合も再生が継続し、停止後に要求が発行されることは実機確認待ち。
- その後、Trembleを表示した状態から再生すると依然停止することを確認した。原因はData書込みではなく、Trembleの100ms表示更新が毎回 `CaptureSelectedObjectLayer` を呼び、再生中にも `CallEditSectionParam` 経由で編集SDKへ入っていたことだった。
- 選択レイヤーは編集状態でControllerを同期した時点にキャッシュし、Trembleの再生中更新は専用共有メモリだけを読むよう変更した。さらに `RefreshEffectState` 自体を再生・出力中は実行せず、Alias、選択Object、レイヤーの全編集SDK取得を停止後まで保留する。表示済みの同一GraphKind要求は共有制御側で維持するため、Filterからの解析値受信は継続できる。
- 修正後のController Release Win64ビルドは警告0、エラー0で成功し、更新した `Aul2AudioController.aux2` へ反映した。実機での再生継続確認待ち。
- 再生停止問題の解消後、再生中のAul2AudioMonitorが空になる問題が判明した。Monitorの50ms表示要求更新が、実表示Formに加えてAviUtl2登録用ClientWindowの `IsWindowVisible` も必須としており、再生開始時にClientWindow側の状態が切り替わると `MonitorWindow=0` を書いて共通解析を止めていた。
- 表示要求判定を、実際にWave／Spectrumを描画するMonitorFormの `Visible` と `IsWindowVisible` だけへ変更した。非表示時は従来どおり要求を0へ戻す。MonitorのRelease Win64ビルドは警告0、エラー0で成功し、更新した `Aul2AudioMonitor.aux2` へ反映した。実機確認待ち。
