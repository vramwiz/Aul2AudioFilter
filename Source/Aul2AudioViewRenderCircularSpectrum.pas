unit Aul2AudioViewRenderCircularSpectrum;

// スペクトラム値を中心から外側へ伸びる放射状バーへ変換し、Circular Spectrum を描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 現在フレームのスペクトラムを円周上へ配置し、透明 RGBA バッファへ描画する。
procedure DrawCircularSpectrum(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);

implementation

uses
  System.Math,
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewSpectrum;

var
  CurrentBands      : TAudioMonitorSpectrumData;
  CurrentBandsValid : Boolean;
  CurrentSourceMinHz: Single;
  CurrentSourceMaxHz: Single;

type
  // 動的な RGBA バッファを座標から直接参照するための配列ポインター型。
  TPixelArray = array[0..0] of TPIXEL_RGBA;
  PPixelArray = ^TPixelArray;

const
  START_ANGLE = -Pi / 2.0; // 最低周波数のバーを円の上端から開始する角度。

procedure PutPixel(Buffer: PPixelArray; Width, Height, X, Y: Integer; R, G, B, A: Byte);
var
  P: ^TPIXEL_RGBA;
begin
  if (Buffer = nil) or (X < 0) or (Y < 0) or (X >= Width) or (Y >= Height) then
    Exit;

  // array[0..0]への可変添字はDebugの範囲検査対象になるため、実アドレスを直接計算する。
  P := Pointer(NativeUInt(Buffer) +
    NativeUInt(Y * Width + X) * SizeOf(TPIXEL_RGBA));
  P^.R := R;
  P^.G := G;
  P^.B := B;
  P^.A := A;
end;

procedure DrawDot(Buffer: PPixelArray; Width, Height: Integer; X, Y: Double;
  Radius: Integer; R, G, B, A: Byte);
var
  IX: Integer;
  IY: Integer;
  DX: Integer;
  DY: Integer;
  Radius2: Integer;
begin
  Radius := Max(0, Radius);
  Radius2 := Radius * Radius;
  for IY := Floor(Y) - Radius to Ceil(Y) + Radius do
    for IX := Floor(X) - Radius to Ceil(X) + Radius do
    begin
      DX := IX - Round(X);
      DY := IY - Round(Y);
      if (DX * DX + DY * DY) <= Radius2 then
        PutPixel(Buffer, Width, Height, IX, IY, R, G, B, A);
    end;
end;

procedure DrawThickLine(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  X1, Y1, X2, Y2: Double; Thickness: Integer; R, G, B, A: Byte);
var
  Pixels: PPixelArray;
  Steps: Integer;
  Step: Integer;
  T: Double;
  X: Double;
  Y: Double;
  Radius: Integer;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  Pixels := PPixelArray(Buffer);
  // 長辺の画素数で補間し、角度に依存する線の途切れを防ぐ。
  Steps := Ceil(Max(Abs(X2 - X1), Abs(Y2 - Y1)));
  Radius := Max(0, Thickness div 2);
  if Steps <= 0 then
  begin
    DrawDot(Pixels, Width, Height, X1, Y1, Radius, R, G, B, A);
    Exit;
  end;

  for Step := 0 to Steps do
  begin
    T := Step / Steps;
    X := X1 + (X2 - X1) * T;
    Y := Y1 + (Y2 - Y1) * T;
    DrawDot(Pixels, Width, Height, X, Y, Radius, R, G, B, A);
  end;
end;

function BandValue(const Settings: TAul2AudioViewSettings; Index, Count: Integer): Single;
begin
  Result := GetSpectrumDisplayValueUnscaled(CurrentBands, CurrentBandsValid,
    CurrentSourceMinHz, CurrentSourceMaxHz, Settings, Index, Count);
end;

procedure DrawRadialSegment(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  CX, CY, Angle, InnerRadius, OuterRadius, XScale, YScale: Double;
  Thickness: Integer; R, G, B: Byte);
var
  SinA: Double;
  CosA: Double;
begin
  if OuterRadius <= InnerRadius then
    Exit;

  SinA := Sin(Angle);
  CosA := Cos(Angle);
  DrawThickLine(Buffer, Width, Height,
    CX + CosA * InnerRadius * XScale,
    CY + SinA * InnerRadius * YScale,
    CX + CosA * OuterRadius * XScale,
    CY + SinA * OuterRadius * YScale,
    Thickness, R, G, B, 255);
end;

procedure DrawSolidCircular(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; Count: Integer; CX, CY, InnerRadius,
  OuterRadius, XScale, YScale: Double);
var
  I: Integer;
  Angle: Double;
  Value: Single;
  BarOuter: Double;
  R, G, B: Byte;
begin
  for I := 0 to Count - 1 do
  begin
    Value := Max(0.0, Min(1.0, BandValue(Settings, I, Count)));
    if Value <= 0.0 then
      Continue;

    Angle := START_ANGLE + (2.0 * Pi * I / Count);
    BarOuter := InnerRadius + (OuterRadius - InnerRadius) * Value;
    GetViewColor(Settings, I, Count, R, G, B);
    DrawRadialSegment(Buffer, Width, Height, CX, CY, Angle, InnerRadius, BarOuter,
      XScale, YScale, Max(1, Min(32, Settings.Thickness)), R, G, B);
  end;
end;

procedure DrawBlockCircular(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; Count: Integer; CX, CY, InnerRadius,
  OuterRadius, XScale, YScale: Double);
var
  I: Integer;
  Block: Integer;
  BlockCount: Integer;
  FillCount: Integer;
  Gap: Double;
  BlockLen: Double;
  Radius1: Double;
  Radius2: Double;
  Angle: Double;
  Value: Single;
  R, G, B: Byte;
begin
  Gap := Max(0, Min(32, Settings.Spacing));
  BlockLen := Max(2.0, Max(1, Min(32, Settings.Thickness)) * 1.8);
  BlockCount := Max(1, Floor((OuterRadius - InnerRadius + Gap) / (BlockLen + Gap)));

  for I := 0 to Count - 1 do
  begin
    Value := Max(0.0, Min(1.0, BandValue(Settings, I, Count)));
    FillCount := Round(BlockCount * Value);
    if FillCount <= 0 then
      Continue;

    Angle := START_ANGLE + (2.0 * Pi * I / Count);
    GetViewColor(Settings, I, Count, R, G, B);
    for Block := 0 to FillCount - 1 do
    begin
      Radius1 := InnerRadius + Block * (BlockLen + Gap);
      Radius2 := Min(OuterRadius, Radius1 + BlockLen);
      DrawRadialSegment(Buffer, Width, Height, CX, CY, Angle, Radius1, Radius2,
        XScale, YScale, Max(1, Min(32, Settings.Thickness)), R, G, B);
    end;
  end;
end;

procedure DrawCircularSpectrum(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
var
  Count: Integer;
  CX: Double;
  CY: Double;
  MaxRadius: Double;
  InnerRadius: Double;
  OuterRadius: Double;
  RadiusRatio: Double;
  XScale: Double;
  YScale: Double;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  UpdateViewSpectrum(Settings.Smooth, CurrentBands, CurrentBandsValid,
    CurrentSourceMinHz, CurrentSourceMaxHz, CurrentFrame, Settings.SourceLayer);

  Count := Max(8, Min(128, Settings.Density));
  CX := (Width - 1) / 2.0;
  CY := (Height - 1) / 2.0;
  MaxRadius := Max(1.0, Min(Width, Height) / 2.0 - Max(1, Settings.Thickness));
  // 外周へ描画可能な長さを残すため、開始半径は最大半径の 92% までに制限する。
  RadiusRatio := Max(0.0, Min(0.92, Settings.BaseRadius / 100.0));
  InnerRadius := Max(0.0, MaxRadius * RadiusRatio);
  OuterRadius := MaxRadius;
  XScale := Max(10, Min(500, Settings.XScale)) / 100.0;
  YScale := Max(10, Min(500, Settings.YScale)) / 100.0;
  if OuterRadius <= InnerRadius then
    Exit;

  if Settings.Style = VIEW_STYLE_BLOCKS then
    DrawBlockCircular(Buffer, Width, Height, Settings, Count, CX, CY, InnerRadius,
      OuterRadius, XScale, YScale)
  else
    DrawSolidCircular(Buffer, Width, Height, Settings, Count, CX, CY, InnerRadius,
      OuterRadius, XScale, YScale);
end;

end.
