unit Aul2AudioViewParams;

// Aul2Audio View の GUI と各描画ユニットが共有する設定値、選択値、設定レコードを定義する。

interface

const
  // GUIのType選択値と描画分岐で共用し、選択リストに表示する順番で連番にする。
  VIEW_TYPE_EQUALIZER_BARS    = 0;
  VIEW_TYPE_WAVE_LINE         = 1;
  VIEW_TYPE_PIXEL_WAVE        = 2;
  VIEW_TYPE_FILLED_SPECTRUM   = 3;
  VIEW_TYPE_PULSE_WAVE        = 4;
  VIEW_TYPE_CIRCULAR_SPECTRUM = 5;
  VIEW_TYPE_MIRROR_BARS       = 6;
  VIEW_TYPE_VECTORSCOPE       = 7;
  VIEW_TYPE_COMMS_SCOPE       = 8;
  VIEW_TYPE_CIRCULAR_BARS_3D  = 9;
  VIEW_TYPE_RADIAL_WAVEFORM_3D = 10;
  VIEW_TYPE_SPECTRUM_LANDSCAPE_3D = 11;
  VIEW_TYPE_WAVEFORM_TUNNEL_3D = 12;
  VIEW_TYPE_SPECTRUM_WATERFALL_3D = 13;
  VIEW_TYPE_VECTORSCOPE_TRAIL_3D = 14;

  // 描画タイプが対応する場合だけ Blocks を使い、それ以外は Solid と同じ連続描画にする。
  VIEW_STYLE_SOLID  = 0;
  VIEW_STYLE_BLOCKS = 1;

  // 保存済みプロジェクトとの互換性があるため、色バリエーションは末尾へ追加する。
  VIEW_COLOR_VARIATION_ONE_COLOR  = 0;
  VIEW_COLOR_VARIATION_TWO_COLOR  = 1;
  VIEW_COLOR_VARIATION_THREE_COLOR = 2;
  VIEW_COLOR_VARIATION_RAINBOW    = 3;
  VIEW_COLOR_VARIATION_WARM       = 4;
  VIEW_COLOR_VARIATION_COOL       = 5;
  VIEW_COLOR_VARIATION_PASTEL     = 6;
  VIEW_COLOR_VARIATION_NEON       = 7;
  VIEW_COLOR_VARIATION_MONO       = 8;
  VIEW_COLOR_VARIATION_SEPIA      = 9;
  VIEW_COLOR_VARIATION_GOLD       = 10;
  VIEW_COLOR_VARIATION_SILVER     = 11;
  VIEW_COLOR_VARIATION_FIRE       = 12;
  VIEW_COLOR_VARIATION_ICE        = 13;
  VIEW_COLOR_VARIATION_WATER      = 14;
  VIEW_COLOR_VARIATION_AURORA     = 15;
  VIEW_COLOR_VARIATION_STARLIGHT  = 16;
  VIEW_COLOR_VARIATION_SUNSET     = 17;
  VIEW_COLOR_VARIATION_OCEAN      = 18;
  VIEW_COLOR_VARIATION_FOREST     = 19;
  VIEW_COLOR_VARIATION_CYBER      = 20;
  VIEW_COLOR_VARIATION_RETRO_GAME = 21;

  VIEW_COLOR_BLEND_AUTO      = 0;
  VIEW_COLOR_BLEND_RGB       = 1;
  VIEW_COLOR_BLEND_HSV_SHORT = 2;
  VIEW_COLOR_BLEND_HSV_LONG  = 3;

  VIEW_SPECTRUM_SCALE_LOG    = 0;
  VIEW_SPECTRUM_SCALE_LINEAR = 1;

type
  // 1 回の映像コールバックで使う GUI 設定のスナップショット。
  TAul2AudioViewSettings = record
    ViewType         : Integer; // 描画タイプを選ぶ VIEW_TYPE_* の値。
    Style            : Integer; // 連続描画またはブロック描画を選ぶ VIEW_STYLE_* の値。
    Density          : Integer; // バー、点、パルスなどを横方向へ配置する基準数。
    Spacing          : Integer; // 隣接する描画要素の間隔をピクセル単位で指定する。
    Thickness        : Integer; // 線幅、点サイズ、バー幅など描画要素の太さ。
    BaseRadius       : Integer; // 円形表示が描画を開始する半径の割合。
    Smooth           : Integer; // 解析値の時間方向の平滑化率。
    XScale           : Integer; // 描画座標のX成分へ適用する倍率。100 が等倍。
    YScale           : Integer; // 描画振幅またはY成分へ適用する倍率。100 が等倍。
    ZScale           : Integer; // 3D描画座標のZ成分へ適用する倍率。100 が等倍。
    SourceLayer      : Integer; // 解析元レイヤー。0 は Auto、1..64 は表示レイヤー番号。
    SpectrumScale    : Integer; // 周波数軸を選ぶ VIEW_SPECTRUM_SCALE_* の値。
    SpectrumLowHz    : Integer; // スペクトラム表示に含める下限周波数。
    SpectrumHighHz   : Integer; // スペクトラム表示に含める上限周波数。
    SpectrumHighBoost: Integer; // 高域側の表示値へ加える強調率。
    ColorVariation   : Integer; // 配色を選ぶ VIEW_COLOR_VARIATION_* の値。
    ColorBlend       : Integer; // 色補間方式を選ぶ VIEW_COLOR_BLEND_* の値。
    Color1R          : Byte;    // Color 1 の赤成分。
    Color1G          : Byte;    // Color 1 の緑成分。
    Color1B          : Byte;    // Color 1 の青成分。
    Color2R          : Byte;    // Color 2 の赤成分。
    Color2G          : Byte;    // Color 2 の緑成分。
    Color2B          : Byte;    // Color 2 の青成分。
    Color3R          : Byte;    // Color 3 の赤成分。
    Color3G          : Byte;    // Color 3 の緑成分。
    Color3B          : Byte;    // Color 3 の青成分。
  end;

implementation

end.
