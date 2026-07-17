unit Aul2AudioViewRenderVectorscope;

// 処理後OutputのL/R代表点を45度回転し、透明背景の最小Vectorscopeとして描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 現在フレームのOutput L/R代表点を透明RGBAバッファへ点描画する。
procedure DrawVectorscope(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
// 中央パンの声でも動くよう、Mid音声の時間差をXY位相軌跡として描画する。
procedure DrawCommsScope(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);

implementation

uses
  System.Math,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewVector,
  Aul2AudioViewVectorShared;

var
  CurrentLeft : TAudioViewVectorData;
  CurrentRight: TAudioViewVectorData;
  CurrentValid: Boolean;

procedure DrawPoint(Buffer: PPIXEL_RGBA; Width, Height, X, Y, Size: Integer;
  R, G, B, A: Byte);
var
  Radius: Integer;
begin
  Size := Max(1, Size);
  Radius := Size div 2;
  FillRect(Buffer, Width, Height, X - Radius, Y - Radius,
    X + Size - Radius - 1, Y + Size - Radius - 1, R, G, B, A);
end;

procedure DrawLine(Buffer: PPIXEL_RGBA; Width, Height, X1, Y1, X2, Y2,
  Thickness: Integer; R, G, B, A: Byte);
var
  Dx: Integer;
  Dy: Integer;
  Sx: Integer;
  Sy: Integer;
  Err: Integer;
  E2: Integer;
begin
  Dx := Abs(X2 - X1);
  Dy := -Abs(Y2 - Y1);
  if X1 < X2 then
    Sx := 1
  else
    Sx := -1;
  if Y1 < Y2 then
    Sy := 1
  else
    Sy := -1;
  Err := Dx + Dy;
  while True do
  begin
    DrawPoint(Buffer, Width, Height, X1, Y1, Thickness, R, G, B, A);
    if (X1 = X2) and (Y1 = Y2) then
      Break;
    E2 := Err * 2;
    if E2 >= Dy then
    begin
      Inc(Err, Dy);
      Inc(X1, Sx);
    end;
    if E2 <= Dx then
    begin
      Inc(Err, Dx);
      Inc(Y1, Sy);
    end;
  end;
end;

procedure DrawVectorscope(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
var
  CenterX: Integer;
  CenterY: Integer;
  ScopeHalfWidth: Integer;
  ScopeHalfHeight: Integer;
  PointCount: Integer;
  Point: Integer;
  SourcePoint: Integer;
  ScopeX: Double;
  ScopeY: Double;
  XScale: Double;
  YScale: Double;
  X: Integer;
  Y: Integer;
  PointSize: Integer;
  PrevX: Integer;
  PrevY: Integer;
  R, G, B: Byte;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  CenterX := Width div 2;
  CenterY := Height div 2;
  PointSize := Max(1, Min(32, Settings.Thickness));
  // XとYを独立した描画範囲にし、横長ViewでもX Scaleが画像幅全体へ反映されるようにする。
  ScopeHalfWidth := Max(1, (Width - PointSize) div 2);
  ScopeHalfHeight := Max(1, (Height - PointSize) div 2);
  PointCount := Max(4, Min(AUDIO_VIEW_VECTOR_POINT_COUNT, Settings.Density));

  UpdateViewVector(CurrentLeft, CurrentRight, CurrentValid,
    CurrentFrame, Settings.SourceLayer);
  if not CurrentValid then
    Exit;

  // Side成分は通常かなり小さいため、このTypeだけX Scaleの表示感度を10倍にする。
  XScale := Max(10, Min(500, Settings.XScale)) / 100.0 * 10.0;
  YScale := Max(10, Min(500, Settings.YScale)) / 100.0;
  PrevX := CenterX;
  PrevY := CenterY;
  for Point := 0 to PointCount - 1 do
  begin
    SourcePoint := Point * AUDIO_VIEW_VECTOR_POINT_LAST div Max(1, PointCount - 1);
    ScopeX := (CurrentLeft[SourcePoint] - CurrentRight[SourcePoint]) * 0.5 * XScale;
    ScopeY := (CurrentLeft[SourcePoint] + CurrentRight[SourcePoint]) * 0.5 * YScale;
    ScopeX := EnsureRange(ScopeX, -1.0, 1.0);
    ScopeY := EnsureRange(ScopeY, -1.0, 1.0);
    X := CenterX + Round(ScopeX * ScopeHalfWidth);
    Y := CenterY - Round(ScopeY * ScopeHalfHeight);
    GetViewColor(Settings, Point, PointCount, R, G, B);
    if Point > 0 then
      DrawLine(Buffer, Width, Height, PrevX, PrevY, X, Y,
        PointSize, R, G, B, 255);
    DrawPoint(Buffer, Width, Height, X, Y, PointSize, R, G, B, 255);
    PrevX := X;
    PrevY := Y;
  end;
end;

procedure DrawCommsScope(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
const
  PHASE_OFFSET = 8;
  COMMS_SCOPE_SENSITIVITY = 2.0;
var
  Alpha: Double;
  CenterX: Integer;
  CenterY: Integer;
  CurrentMono: Double;
  DelayedMono: Double;
  DelayedPoint: Integer;
  Mono: TAudioViewVectorData;
  Point: Integer;
  PointCount: Integer;
  PointSize: Integer;
  PrevX: Integer;
  PrevY: Integer;
  R, G, B: Byte;
  ScopeHalfSize: Integer;
  ScopeX: Double;
  ScopeY: Double;
  SmoothRatio: Double;
  SourcePoint: Integer;
  X: Integer;
  XScale: Double;
  Y: Integer;
  YScale: Double;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  CenterX := Width div 2;
  CenterY := Height div 2;
  PointSize := Max(1, Min(32, Settings.Thickness));
  // Comms Scopeは長方形画像でも短辺基準の中央正方形を描画範囲とする。
  ScopeHalfSize := Max(1, (Min(Width, Height) - PointSize) div 2);
  PointCount := Max(4, Min(AUDIO_VIEW_VECTOR_POINT_COUNT - PHASE_OFFSET,
    Settings.Density));

  UpdateViewVector(CurrentLeft, CurrentRight, CurrentValid,
    CurrentFrame, Settings.SourceLayer);
  if not CurrentValid then
    Exit;

  for Point := 0 to AUDIO_VIEW_VECTOR_POINT_LAST do
    Mono[Point] := (CurrentLeft[Point] + CurrentRight[Point]) * 0.5;

  // Smoothを時間方向のローパス量として使い、声の輪郭を残しながら細かな揺れを抑える。
  SmoothRatio := EnsureRange(Settings.Smooth, 0, 100) / 100.0;
  Alpha := 1.0 - SmoothRatio * 0.75;
  for Point := 1 to AUDIO_VIEW_VECTOR_POINT_LAST do
    Mono[Point] := Mono[Point - 1] + (Mono[Point] - Mono[Point - 1]) * Alpha;

  XScale := Max(10, Min(500, Settings.XScale)) / 100.0 * COMMS_SCOPE_SENSITIVITY;
  YScale := Max(10, Min(500, Settings.YScale)) / 100.0 * COMMS_SCOPE_SENSITIVITY;
  PrevX := CenterX;
  PrevY := CenterY;
  for Point := 0 to PointCount - 1 do
  begin
    SourcePoint := PHASE_OFFSET +
      Point * (AUDIO_VIEW_VECTOR_POINT_LAST - PHASE_OFFSET) div Max(1, PointCount - 1);
    DelayedPoint := SourcePoint - PHASE_OFFSET;
    CurrentMono := Mono[SourcePoint];
    DelayedMono := Mono[DelayedPoint];
    ScopeX := (CurrentMono - DelayedMono) * 0.5 * XScale;
    ScopeY := (CurrentMono + DelayedMono) * 0.5 * YScale;
    ScopeX := EnsureRange(ScopeX, -1.0, 1.0);
    ScopeY := EnsureRange(ScopeY, -1.0, 1.0);
    X := CenterX + Round(ScopeX * ScopeHalfSize);
    Y := CenterY - Round(ScopeY * ScopeHalfSize);
    GetViewColor(Settings, Point, PointCount, R, G, B);
    if Point > 0 then
      DrawLine(Buffer, Width, Height, PrevX, PrevY, X, Y,
        PointSize, R, G, B, 255);
    DrawPoint(Buffer, Width, Height, X, Y, PointSize, R, G, B, 255);
    PrevX := X;
    PrevY := Y;
  end;
end;

end.
