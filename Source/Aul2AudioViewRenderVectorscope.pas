unit Aul2AudioViewRenderVectorscope;

// 処理後OutputのL/R代表点を45度回転し、透明背景の最小Vectorscopeとして描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 現在フレームのOutput L/R代表点を透明RGBAバッファへ点描画する。
procedure DrawVectorscope(Buffer: PPIXEL_RGBA; Width, Height: Integer;
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
  ScopeHalfSize: Integer;
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
  AxisSize: Integer;
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
  // 短辺から線幅分を除いた中央正方形を、X/Y共通の描画座標範囲にする。
  ScopeHalfSize := Max(1, (Min(Width, Height) - PointSize) div 2);
  AxisSize := Max(2, PointSize div 2);
  PointCount := Max(4, Min(AUDIO_VIEW_VECTOR_POINT_COUNT, Settings.Density));

  GetViewColor(Settings, 0, PointCount, R, G, B);
  FillRect(Buffer, Width, Height, CenterX - AxisSize div 2, CenterY - ScopeHalfSize,
    CenterX + AxisSize div 2, CenterY + ScopeHalfSize, R div 2, G div 2, B div 2, 255);
  FillRect(Buffer, Width, Height, CenterX - ScopeHalfSize, CenterY - AxisSize div 2,
    CenterX + ScopeHalfSize, CenterY + AxisSize div 2, R div 2, G div 2, B div 2, 255);

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
