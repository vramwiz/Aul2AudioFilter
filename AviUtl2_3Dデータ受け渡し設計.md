# AviUtl2へ3Dデータを渡す方法と推奨設計

## 1. 結論

`Aul2AudioView` の2D表示を、将来の3D表示と共通化する考え方は妥当である。

推奨する基本方針は、次のとおり。

- FFT結果や波形などの「解析データ」は、描画方式から独立した値として保持する。
- 解析データを、表示方式ごとの `MeshBuilder` で頂点データへ変換する。
- 2D表示も `Z = 0` の平面メッシュとして表現する。
- AviUtl2へは、SDK v2.10の `FILTER_PROC_VIDEO.draw_poly()` で頂点列を渡す。
- 現在のCPU描画＋`SetImageData()` は、互換用・フォールバック用として残す。

最も重要なのは、**スペクトラム値そのものを3D頂点として保存しないこと**である。解析データと描画用メッシュを分ければ、同じスペクトラムから2Dバー、円形表示、3Dバー、地形などを生成できる。

```text
音声入力
  ↓
FFT・波形・ピークなどの解析
  ↓
SpectrumFrame / WaveFrame（表示方法に依存しない共通データ）
  ↓
表示方式ごとのMeshBuilder
  ↓
RenderPacket（頂点、材質、描画状態）
  ↓
AviUtl2 draw_poly()
```

## 2. 現在の実装

現在の `Aul2AudioView` は、概ね次の経路で描画している。

```text
共有メモリ上のスペクトラム／波形
  ↓
Aul2AudioViewRenderEqualizer.pas など
  ↓
CPU上のPIXEL_RGBAバッファへ直接描画
  ↓
Aul2AudioViewRender.OutputImageData
  ↓
Video^.SetImageData(Buffer, Width, Height)
```

この方法は安定しており、通常の2D表示には適している。一方、AviUtl2へ渡る時点では完成済みのRGBA画像になっているため、AviUtl2からは「1枚の平面画像」にしか見えない。

そのため、次の表現を追加しようとすると別の描画系が必要になる。

- 奥行きのあるイコライザーバー
- カメラ回転で側面が見える表示
- 法線を使った光源表現
- 周波数と時間をX/Z軸に配置したスペクトラム地形
- 球面や円筒面へ貼り付けたスペクトラム

CPU描画を全面的に廃止する必要はない。最初は2つのバックエンドを並存させるのが安全である。

```text
共通解析データ
  ├─ CpuBitmapRenderer → SetImageData（従来表示）
  └─ AviUtl2MeshRenderer → draw_poly（新しい2D／3D表示）
```

## 3. AviUtl2 SDK v2.10で利用できる3D機能

SDKの `filter2.h` には、次の頂点形式が定義されている。

| SDK型 | 内容 |
|---|---|
| `VERTEX_COLOR` | XYZ座標＋RGBA頂点色 |
| `VERTEX_COLOR_NORM` | XYZ座標＋RGBA頂点色＋法線 |
| `VERTEX_TEXTURE` | XYZ座標＋UV＋アルファ |
| `VERTEX_TEXTURE_NORM` | XYZ座標＋UV＋アルファ＋法線 |

`draw_poly()` は、三角形または四角形の頂点列をAviUtl2のフレームバッファへ描画する。

```cpp
bool draw_poly(
    VERTEX_TYPE vertex_type,
    const void* vertex_list,
    int vertex_num,
    LPCWSTR resource
);
```

SDK付属の `MediaObject.cpp` では、`VERTEX_TEXTURE_NORM` の頂点をCPUで生成し、球体を `draw_poly()` で描画している。したがって、独自に生成したイコライザーの頂点を同じ方法で渡せる。

利用できる補助機能には、以下がある。

- `set_material_shine()`：カメラ制御の光源が有効な場合の光沢度
- `set_culling_state()`：裏面カリング
- `set_billboard_mode()`：カメラ方向を向く表示
- `set_blend_mode()`：合成モード
- `set_sampler_mode()`：テクスチャのサンプリング方法
- `draw_image()`：平面画像をXYZ座標、XYZ回転、XYZ拡大率付きで描画
- ピクセルシェーダー5.0／コンピュートシェーダー5.0の実行
- `ID3D11Texture2D` の取得とD3D11の直接操作

最初の実装ではD3D11を直接操作せず、AviUtl2が用意する `draw_poly()` を使用する方がよい。カメラやオブジェクト変換との整合をAviUtl2側に任せられるためである。

## 4. 推奨する共通データ構造

### 4.1 解析データ

解析データには、表示座標や三角形を含めない。

```pascal
type
  TSpectrumFrame = record
    FrameNumber: Integer;
    MinHz: Single;
    MaxHz: Single;
    Valid: Boolean;
    Bands: TArray<Single>;
  end;
```

既存の `TAudioMonitorSpectrumData` と `GetSpectrumDisplayValue()` は、この層に相当する。現在のスムージング処理も、基本的にはこの層または表示値生成層に残す。

### 4.2 描画頂点

内部の共通頂点は、将来必要になる属性を保持できる形にする。

```pascal
type
  TMeshVertex = packed record
    X, Y, Z: Single;
    NX, NY, NZ: Single;
    U, V: Single;
    R, G, B, A: Single;
  end;
```

ただし、毎回すべての属性をAviUtl2へ渡す必要はない。描画内容に応じて、SDKの頂点型へ変換する。

- 単色またはグラデーションのバー：`VERTEX_COLOR_NORM`
- 画像を貼る面：`VERTEX_TEXTURE_NORM`
- 光源不要の2D面：`VERTEX_COLOR`
- テクスチャ付き2D面：`VERTEX_TEXTURE`

### 4.3 RenderPacket

頂点だけでなく、材質や座標空間も一つの描画単位として管理する。

```pascal
type
  TRenderSpace = (
    rsScreenPlane, // Z=0を基本とする2D表示
    rsScene3D      // カメラ制御を利用する3D表示
  );

  TRenderPacket = record
    Space: TRenderSpace;
    VertexType: Integer;
    Vertices: TBytes;
    VertexCount: Integer;
    TextureResource: UnicodeString;
    MaterialShine: Single;
    Culling: Boolean;
  end;
```

実装時は `TBytes` より型付き動的配列の方が安全だが、概念としては「1回の `draw_poly()` 呼び出しに必要な情報」をまとめる。

## 5. 2Dを3Dの面として扱う方法

2Dイコライザーは、全頂点のZ座標を0にした面として生成できる。

```text
左下 (x0, y0, 0) ── 右下 (x1, y0, 0)
       │                    │
       │                    │
左上 (x0, y1, 0) ── 右上 (x1, y1, 0)
```

法線は、面の表側に統一する。

```pascal
NX := 0.0;
NY := 0.0;
NZ := -1.0; // 実機で表裏を確認し、必要なら+1.0へ統一する
```

この2Dバーへ奥行きを追加すると、同じスペクトラム値から直方体バーを生成できる。

```text
2D: 幅 × 高さ、Z=0の前面だけ
3D: 幅 × 高さ × 奥行き、前後左右上下の6面
```

つまり、解析データと色計算を共通化したまま、MeshBuilderだけを切り替えられる。

```pascal
case Settings.GeometryMode of
  gmFlatBars: BuildFlatBarMesh(Spectrum, Settings, Packet);
  gmBoxBars:  BuildBoxBarMesh(Spectrum, Settings, Packet);
  gmTerrain:  BuildSpectrumTerrain(SpectrumHistory, Settings, Packet);
end;
```

注意点として、「2D」という言葉には2つの意味がある。

1. 形状が平面である
2. カメラに影響されず画面へ固定される

Z=0の平面にするだけでは、カメラ制御が有効なシーンで傾いたり遠近が付いたりする可能性がある。画面固定表示と3Dシーン表示は、`TRenderSpace` や設定項目で明示的に分けるべきである。

## 6. イコライザー向けの具体的なメッシュ

### 6.1 平面バー

バー1本を四角形1枚、または三角形2枚で構成する。

SDKは四角形を受け取れるが、内部の共通形式は三角形を推奨する。将来、D3D11の頂点／インデックスバッファへ移行する場合にもそのまま使えるためである。

```text
三角形1: 左下、左上、右上
三角形2: 左下、右上、右下
```

### 6.2 立体バー

直方体は6面、三角形12枚で構成する。三角形リストへ展開するとバー1本あたり36頂点になる。

64バンドの場合は最大2304頂点程度なので、通常のイコライザーとしては大きな量ではない。ただし、毎フレームのメモリ確保は避け、配列を再利用する。

高さだけが変化する場合、次をキャッシュできる。

- バーのX位置
- バー幅
- 奥行き
- 三角形の接続関係
- UV座標
- 高さに影響されない底面頂点

フレームごとに更新するのは、主に上端Y座標、必要なら色と法線でよい。

### 6.3 スペクトラム地形

過去フレームのスペクトラム履歴をZ方向へ並べると、周波数×時間×振幅の地形を生成できる。

- X：周波数バンド
- Y：振幅
- Z：時間履歴

この場合、共有メモリに描画済み頂点を保存するのではなく、時系列のスペクトラム値をリングバッファとして保持し、View側で地形を生成する方がよい。

## 7. AviUtl2へ渡すDelphi定義

Delphi側には、SDKのメモリ配置と呼出規約を正確に移植する必要がある。

### 7.1 SDK頂点型

```pascal
type
  TVertexColor = packed record
    X, Y, Z: Single;
    R, G, B, A: Single;
  end;

  TVertexColorNorm = packed record
    X, Y, Z: Single;
    R, G, B, A: Single;
    VX, VY, VZ: Single;
  end;

  TVertexTexture = packed record
    X, Y, Z: Single;
    U, V, A: Single;
  end;

  TVertexTextureNorm = packed record
    X, Y, Z: Single;
    U, V, A: Single;
    VX, VY, VZ: Single;
  end;

const
  VERTEX_TRIANGLE_COLOR        = 1;
  VERTEX_TRIANGLE_COLOR_NORM   = 2;
  VERTEX_TRIANGLE_TEXTURE      = 3;
  VERTEX_TRIANGLE_TEXTURE_NORM = 4;
  VERTEX_QUAD_COLOR            = 5;
  VERTEX_QUAD_COLOR_NORM       = 6;
  VERTEX_QUAD_TEXTURE          = 7;
  VERTEX_QUAD_TEXTURE_NORM     = 8;
```

SDKの頂点色は0.0～1.0の乗算済みアルファである。現在の `TPIXEL_RGBA` の0～255整数とは形式が違うため、そのままコピーしてはいけない。

### 7.2 draw_poly関数ポインター

```pascal
type
  TDrawPoly = function(VertexType: Integer; VertexList: Pointer;
    VertexNum: Integer; Resource: PWideChar): Byte; cdecl;
```

- C++側の `VERTEX_TYPE` は4バイト整数として渡す。
- C++側の `bool` 戻り値は1バイトとして扱う。
- テクスチャを使わない頂点色描画では `Resource = nil` とする。
- 配列の先頭ポインターは `@Vertices[0]` で渡す。
- 頂点配列は `draw_poly()` の呼び出しが戻るまで有効でなければならない。
- 頂点数0のときに `@Vertices[0]` を評価してはいけない。

呼び出し例は次のようになる。

```pascal
if (Length(Vertices) > 0) and Assigned(Video^.DrawPoly) then
  if Video^.DrawPoly(
       VERTEX_TRIANGLE_COLOR_NORM,
       @Vertices[0],
       Length(Vertices),
       nil) = 0 then
    Exit;
```

### 7.3 現在の `TFILTER_PROC_VIDEO` に関する重要事項

現在の `Source\Lib\Aul2AudioFilterTypes.pas` の `TFILTER_PROC_VIDEO` は、次のフィールドまでしか定義していない。

- `Scene`
- `Object_`
- `GetImageData`
- `SetImageData`
- `GetImageTexture2D`
- `GetFramebufferTexture2D`

SDK v2.10では、この後に `Edit`、`Param`、各種関数ポインター、`DrawImage`、`DrawPoly` などが続く。

`DrawPoly` だけを現在のレコード直後へ追加してはいけない。SDKと同じ順序で、その手前にある全フィールドを定義しないと、異なるアドレスを関数として呼び出してクラッシュする。

最低でも `DrawPoly` までの並びを `filter2.h` と完全に一致させる必要がある。長期的には、SDK v2.10の `FILTER_PROC_VIDEO` 全体をDelphiへ移植し、元ヘッダーのフィールド名と順序をコメントで対応付けるのが安全である。

また、SDK更新時は構造体末尾へ関数が追加される可能性があるため、以下を確認する。

- フィールド順序
- ポインターサイズ（Win64）
- `cdecl` 呼出規約
- C++ `bool` とDelphi型のサイズ
- `enum class : int` のサイズ
- `packed record` が必要な頂点型と、自然アラインメントを維持すべきAPIレコードの区別

`TFILTER_PROC_VIDEO` 本体には安易に `packed record` を付けず、Win64 C++構造体と同じ自然アラインメントになることを確認する。

## 8. 推奨するソース構成

既存の描画ユニットを一度に書き換えず、次のように追加する。

```text
Source/
  Aul2AudioViewRender.pas             描画バックエンドの選択と振り分け
  Aul2AudioViewSpectrum.pas           スペクトラム取得・スムージング

  Mesh/
    Aul2AudioMeshTypes.pas            共通頂点、材質、RenderPacket
    Aul2AudioMeshBuilderBars.pas      平面／立体バー
    Aul2AudioMeshBuilderCircular.pas  円形・円筒形
    Aul2AudioMeshBuilderTerrain.pas   スペクトラム履歴地形

  RenderBackend/
    Aul2AudioRenderCpuBitmap.pas      現在のSetImageData経路
    Aul2AudioRenderAviUtl2Mesh.pas    draw_poly経路
```

表示方式ユニットがAviUtl2 APIを直接呼ばないようにする。表示方式ユニットは `RenderPacket` を作るだけにし、AviUtl2固有処理は `Aul2AudioRenderAviUtl2Mesh.pas` に集約する。

これにより、プラグイン制作者が管理する入口は次の1つにまとめられる。

```pascal
procedure RenderPacket(Video: PFILTER_PROC_VIDEO; const Packet: TRenderPacket);
```

## 9. マテリアルと複数回描画

1回の `draw_poly()` では、基本的に1種類の頂点形式と1つのテクスチャリソースを指定する。

そのため、次の場合は `RenderPacket` を複数に分ける。

- バーごとに別テクスチャを使う
- 不透明面と半透明面を分ける
- 光沢度を変える
- カリング設定を変える
- 頂点色メッシュとテクスチャメッシュを混在させる

半透明面は描画順の影響を受ける。完全な順序非依存透明処理は期待せず、必要ならカメラから遠い面から近い面へ並べる。最初の3Dバーは不透明で実装すると問題を切り分けやすい。

## 10. キャッシュとスレッド安全性

AviUtl2の描画コールバックは、常に単一オブジェクト・単一スレッドだけから呼ばれる前提にしない。

共有の可変配列を使い回す場合は、別オブジェクトや別レンダリング処理と競合する可能性を考慮する。安全な候補は次のとおり。

- コールバック内のローカル配列
- オブジェクトID／エフェクトID別のキャッシュ
- SDKの `InitializeCache` を利用したレンダリング共用キャッシュ
- ロックで保護したキャッシュ。ただし描画中の長時間ロックは避ける

毎フレーム避けるべき処理は次のとおり。

- 頂点配列の細かな再確保
- モデルファイルの再読み込み
- 同じトポロジーの再構築
- CPU画像生成後に、さらに同じ形状をメッシュとして生成する二重処理

## 11. 段階的な導入手順

### 第1段階：SDK型の安全な移植

1. SDK v2.10の `FILTER_PROC_VIDEO` をDelphiへ正確に移植する。
2. 頂点型と `VERTEX_TYPE` 定数を追加する。
3. `DrawPoly` までのオフセットがC++定義と一致することを確認する。
4. Delphi例外をAviUtl2コールバック外へ漏らさない既存方針を維持する。

### 第2段階：固定平面の描画

1. 音声とは無関係な固定四角形を `draw_poly()` で表示する。
2. 頂点の並び、表裏、座標方向、アルファを確認する。
3. カメラ制御の有無で挙動を確認する。

### 第3段階：既存Equalizer Barsの平面メッシュ化

1. `GetSpectrumDisplayValue()` の結果を再利用する。
2. `FillRect()` の代わりに、各バーの三角形を生成する。
3. 色計算は既存の `GetViewColor()` と同じ結果にする。
4. CPU版とメッシュ版を設定または開発用定数で切り替えて比較する。

### 第4段階：立体バー

1. `Depth` 設定を追加する。
2. 前面だけだったバーを6面の直方体へ変更する。
3. 面ごとに正しい法線を設定する。
4. カリングと光沢度を有効にする。
5. 不透明描画で安定した後、必要なら半透明へ対応する。

### 第5段階：共通化

1. 既存のCircular SpectrumやFilled SpectrumをMeshBuilderへ移す。
2. 解析値取得を描画ユニットから分離する。
3. CPU版はフォールバックまたは特殊なピクセル表現用として残す。

## 12. 最初に作るべき検証用表示

最初の実機検証は、64本の立体イコライザーではなく、以下の単純な順序がよい。

1. 頂点色付き三角形1枚
2. Z=0の四角形1枚
3. 高さが時間で変わる平面バー1本
4. スペクトラムに反応する平面バー8本
5. 奥行きを持つ直方体バー8本
6. 64本へ増加

確認項目は次のとおり。

- AviUtl2終了時に例外やアクセス違反がない
- プレビュー、停止、再生、シーク、書き出しで同じ結果になる
- 複数のAul2Audio Viewオブジェクトを置いてもデータが混ざらない
- カメラ制御の内外で意図した座標になる
- X/Y/Z回転と拡大率が正しく適用される
- 裏面カリング時に面が消える方向が正しい
- 透明度と描画順が破綻しない
- CPU版より過度に負荷が増えない

## 13. 採用方針のまとめ

このプロジェクトでは、次の方針が最も拡張しやすい。

1. 共有メモリには軽量な解析値を保持し、頂点や完成画像を共通データにはしない。
2. 2Dと3Dを同じMeshBuilder系インターフェースで扱う。
3. 2DはZ=0の平面メッシュとして生成する。
4. 画面固定2Dとカメラ空間3Dは明示的に区別する。
5. AviUtl2との境界は `RenderPacket → draw_poly()` の1か所へ集約する。
6. 現在の `SetImageData()` 経路は、互換性と特殊なピクセル描画のために残す。
7. 最初はSDK標準の `draw_poly()` を利用し、必要性が明確になるまでD3D11を直接操作しない。

この構成なら、現在の2Dイコライザーを失わずに、同じスペクトラム処理から立体バー、円筒、球面、地形などへ段階的に発展させられる。

## 参考にしたSDKファイル

- `C:\Users\vramw\Downloads\aviutl2_sdk_v210\filter2.h`
- `C:\Users\vramw\Downloads\aviutl2_sdk_v210\MediaObject.cpp`
- `C:\Users\vramw\Downloads\aviutl2_sdk_v210\aviutl2_plugin_sdk.txt`

