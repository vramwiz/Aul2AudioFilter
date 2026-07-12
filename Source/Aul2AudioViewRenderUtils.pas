unit Aul2AudioViewRenderUtils;

// Aul2Audio View の各描画タイプで共有する画素操作、配色、スペクトラム再標本化を担当する。

interface

uses
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

type
  // 動的な RGBA バッファを境界検査付きの配列ポインターとして扱うための型。
  TPixelArray = array[0..0] of TPIXEL_RGBA;
  PPixelArray = ^TPixelArray;

// RGBA バッファの全画素を透明に初期化する。
procedure ClearPixels(Buffer: PPIXEL_RGBA; Width, Height: Integer);
// 指定矩形を画像範囲内へ切り詰め、同じ RGBA 値で塗りつぶす。
procedure FillRect(Buffer: PPIXEL_RGBA; Width, Height, X1, Y1, X2, Y2: Integer;
  R, G, B, A: Byte);
// Settings の配色と要素位置から描画に使う RGB 値を返す。
procedure GetViewColor(const Settings: TAul2AudioViewSettings; Index, Count: Integer;
  out R, G, B: Byte);
// View Gain を描画値だけに適用し、結果を -1～1 に制限する。
function ApplyViewGain(Value: Single; const Settings: TAul2AudioViewSettings): Single;
// 指定した表示位置に対応する周波数バンドを補間し、高域強調と View Gain を適用して返す。
function GetSpectrumDisplayValue(const Bands: TAudioMonitorSpectrumData; Valid: Boolean;
  SourceMinHz, SourceMaxHz: Single; const Settings: TAul2AudioViewSettings;
  Index, Count: Integer): Single;

implementation

uses
  System.Math,
  Aul2ColorUtils,
  Aul2ColorPalette;

procedure ClearPixels(Buffer: PPIXEL_RGBA; Width, Height: Integer);
var
  BufferSize: NativeUInt;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  BufferSize := NativeUInt(Width) * NativeUInt(Height) * SizeOf(TPIXEL_RGBA);
  if BufferSize > NativeUInt(High(NativeInt)) then
    Exit;

  // 未描画領域を透明にする。各 View Type は描画前に必ずこの初期化を行う。
  FillChar(Buffer^, NativeInt(BufferSize), 0);
end;

procedure PutPixel(Buffer: PPixelArray; Width, Height, X, Y: Integer; R, G, B, A: Byte);
var
  P: ^TPIXEL_RGBA;
begin
  if (Buffer = nil) or (X < 0) or (Y < 0) or (X >= Width) or (Y >= Height) then
    Exit;

  P := Pointer(NativeUInt(Buffer) +
    NativeUInt(Y * Width + X) * SizeOf(TPIXEL_RGBA));
  P^.R := R;
  P^.G := G;
  P^.B := B;
  P^.A := A;
end;

procedure FillRect(Buffer: PPIXEL_RGBA; Width, Height, X1, Y1, X2, Y2: Integer;
  R, G, B, A: Byte);
var
  X, Y: Integer;
  Pixels: PPixelArray;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  Pixels := PPixelArray(Buffer);
  X1 := Max(0, X1);
  Y1 := Max(0, Y1);
  X2 := Min(Width - 1, X2);
  Y2 := Min(Height - 1, Y2);

  if (X1 > X2) or (Y1 > Y2) then
    Exit;

  for Y := Y1 to Y2 do
    for X := X1 to X2 do
      PutPixel(Pixels, Width, Height, X, Y, R, G, B, A);
end;

function ToColorBlendMode(Value: Integer): TAul2ColorBlendMode;
begin
  case Value of
    VIEW_COLOR_BLEND_RGB:
      Result := cbRGB;
    VIEW_COLOR_BLEND_HSV_SHORT:
      Result := cbHSVShort;
    VIEW_COLOR_BLEND_HSV_LONG:
      Result := cbHSVLong;
  else
    Result := cbAuto;
  end;
end;

function ToColorPalette(ColorVariation: Integer): TAul2ColorPalette;
var
  PaletteValue: Integer;
begin
  // 1～3 色のユーザー指定値を除いた GUI 番号をパレット列挙値へ詰め直す。
  PaletteValue := ColorVariation - 1;
  if (PaletteValue >= Ord(Low(TAul2ColorPalette))) and
     (PaletteValue <= Ord(High(TAul2ColorPalette))) then
    Result := TAul2ColorPalette(PaletteValue)
  else
    Result := cpRainbow;
end;

function GetCustomViewColor(const Settings: TAul2AudioViewSettings; T: Double): TAul2RGBColor;
var
  Color1: TAul2RGBColor;
  Color2: TAul2RGBColor;
  Color3: TAul2RGBColor;
  BlendMode: TAul2ColorBlendMode;
begin
  Color1 := Aul2RGB(Settings.Color1R, Settings.Color1G, Settings.Color1B);
  Color2 := Aul2RGB(Settings.Color2R, Settings.Color2G, Settings.Color2B);
  Color3 := Aul2RGB(Settings.Color3R, Settings.Color3G, Settings.Color3B);
  BlendMode := ToColorBlendMode(Settings.ColorBlend);
  if BlendMode = cbAuto then
    BlendMode := cbHSVShort;

  case Settings.ColorVariation of
    VIEW_COLOR_VARIATION_TWO_COLOR:
      Result := LerpColor(Color1, Color2, T, BlendMode);
    VIEW_COLOR_VARIATION_THREE_COLOR:
      begin
        if T <= 0.5 then
          Result := LerpColor(Color1, Color2, T * 2.0, BlendMode)
        else
          Result := LerpColor(Color2, Color3, (T - 0.5) * 2.0, BlendMode);
      end;
  else
    Result := Color1;
  end;
end;

procedure GetViewColor(const Settings: TAul2AudioViewSettings; Index, Count: Integer;
  out R, G, B: Byte);
var
  T: Double;
  Color: TAul2RGBColor;
begin
  if Settings.ColorVariation <= VIEW_COLOR_VARIATION_THREE_COLOR then
  begin
    T := Index / Max(1, Count - 1);
    Color := GetCustomViewColor(Settings, T);
    R := Color.R;
    G := Color.G;
    B := Color.B;
    Exit;
  end;

  T := Index / Max(1, Count - 1);
  Color := GetPaletteColor(
    ToColorPalette(Settings.ColorVariation),
    T,
    ToColorBlendMode(Settings.ColorBlend)
  );

  R := Color.R;
  G := Color.G;
  B := Color.B;
end;

function ApplyViewGain(Value: Single; const Settings: TAul2AudioViewSettings): Single;
begin
  // 音声や共有解析値は変更せず、描画に使う振幅だけを調整する。
  Result := Value * Max(10, Min(500, Settings.ViewGain)) / 100.0;
  Result := Max(-1.0, Min(1.0, Result));
end;

function ClampHzRange(const Settings: TAul2AudioViewSettings; SourceMinHz, SourceMaxHz: Single;
  out LowHz, HighHz: Double): Boolean;
begin
  SourceMinHz := Max(1.0, SourceMinHz);
  SourceMaxHz := Max(SourceMinHz + 1.0, SourceMaxHz);
  LowHz := Max(SourceMinHz, Min(SourceMaxHz - 1.0, Settings.SpectrumLowHz));
  HighHz := Max(LowHz + 1.0, Min(SourceMaxHz, Settings.SpectrumHighHz));
  Result := HighHz > LowHz;
end;

function DisplayIndexToHz(const Settings: TAul2AudioViewSettings; Index, Count: Integer;
  LowHz, HighHz: Double): Double;
var
  T: Double;
begin
  if Count <= 1 then
    T := 0.0
  else
    T := Index / (Count - 1);

  // Log は低域の表示密度を確保し、Linear は周波数を等間隔に配置する。
  if Settings.SpectrumScale = VIEW_SPECTRUM_SCALE_LINEAR then
    Result := LowHz + ((HighHz - LowHz) * T)
  else
    Result := LowHz * Power(HighHz / LowHz, T);
end;

function HzToSourceBand(FreqHz, SourceMinHz, SourceMaxHz: Double): Double;
begin
  SourceMinHz := Max(1.0, SourceMinHz);
  SourceMaxHz := Max(SourceMinHz + 1.0, SourceMaxHz);
  FreqHz := Max(SourceMinHz, Min(SourceMaxHz, FreqHz));
  Result := Ln(FreqHz / SourceMinHz) / Ln(SourceMaxHz / SourceMinHz);
  Result := Result * AUDIO_MONITOR_SPECTRUM_BAND_LAST;
end;

function SampleSpectrumBand(const Bands: TAudioMonitorSpectrumData; Position: Double): Single;
var
  Band0: Integer;
  Band1: Integer;
  Frac: Double;
begin
  Band0 := Max(0, Min(AUDIO_MONITOR_SPECTRUM_BAND_LAST, Floor(Position)));
  Band1 := Max(0, Min(AUDIO_MONITOR_SPECTRUM_BAND_LAST, Band0 + 1));
  Frac := Max(0.0, Min(1.0, Position - Band0));
  // 表示位置が元バンドの中間でも段差が出ないよう、隣接バンドを線形補間する。
  Result := Bands[Band0] + ((Bands[Band1] - Bands[Band0]) * Frac);
end;

function ApplySpectrumHighBoost(Value: Single; const Settings: TAul2AudioViewSettings;
  Index, Count: Integer): Single;
var
  T: Double;
  Boost: Double;
begin
  if Count <= 1 then
    T := 0.0
  else
    T := Index / (Count - 1);

  Boost := Max(0, Min(100, Settings.SpectrumHighBoost)) / 100.0;
  Result := Max(0.0, Min(1.0, Value * (1.0 + Boost * 2.0 * T)));
end;

function GetSpectrumDisplayValue(const Bands: TAudioMonitorSpectrumData; Valid: Boolean;
  SourceMinHz, SourceMaxHz: Single; const Settings: TAul2AudioViewSettings;
  Index, Count: Integer): Single;
var
  LowHz: Double;
  HighHz: Double;
  FreqHz: Double;
  Position: Double;
begin
  if (not Valid) or (Count <= 1) or
     not ClampHzRange(Settings, SourceMinHz, SourceMaxHz, LowHz, HighHz) then
    Exit(0.0);

  FreqHz := DisplayIndexToHz(Settings, Index, Count, LowHz, HighHz);
  Position := HzToSourceBand(FreqHz, SourceMinHz, SourceMaxHz);
  Result := Max(0.0, Min(1.0, SampleSpectrumBand(Bands, Position)));
  Result := ApplySpectrumHighBoost(Result, Settings, Index, Count);
  Result := ApplyViewGain(Result, Settings);
end;

end.
