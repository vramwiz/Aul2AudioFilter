unit Aul2AudioViewRenderPixelWave;

// 時間波形を離散的な点へ変換し、Pixel Wave を描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 現在フレームの波形を点の並びとして透明 RGBA バッファへ描画する。
procedure DrawPixelWave(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);

implementation

uses
  System.Math,
  Aul2AudioMonitorShared,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewWave;

var
  CurrentWave     : TAudioMonitorWaveData;
  CurrentWaveMin  : TAudioMonitorWaveData;
  CurrentWaveMax  : TAudioMonitorWaveData;
  CurrentWaveValid: Boolean;

function InterpolateWave(const Wave: TAudioMonitorWaveData; Index, Count: Integer): Single;
var
  Position: Double;
  Point0: Integer;
  Point1: Integer;
  Frac: Double;
begin
  if Count <= 1 then
    Exit(0.0);

  Position := Index * AUDIO_MONITOR_WAVE_POINT_LAST / (Count - 1);
  Point0 := Max(0, Min(AUDIO_MONITOR_WAVE_POINT_LAST, Floor(Position)));
  Point1 := Max(0, Min(AUDIO_MONITOR_WAVE_POINT_LAST, Point0 + 1));
  Frac := Position - Point0;

  // 点数と共有波形の解像度が異なっても段差が出ないよう、隣接点を線形補間する。
  Result := Wave[Point0] + ((Wave[Point1] - Wave[Point0]) * Frac);
  Result := Max(-1.0, Min(1.0, Result));
end;

procedure DrawPixel(Buffer: PPIXEL_RGBA; Width, Height, X, Y, Size: Integer;
  R, G, B, A: Byte);
var
  Radius: Integer;
begin
  Size := Max(1, Size);
  Radius := Size div 2;
  FillRect(Buffer, Width, Height, X - Radius, Y - Radius,
    X + Size - Radius - 1, Y + Size - Radius - 1, R, G, B, A);
end;

procedure DrawCenterGuide(Buffer: PPIXEL_RGBA; Width, Height, CenterY, Size: Integer;
  R, G, B: Byte);
var
  Step: Integer;
  X: Integer;
begin
  Step := Max(4, Size * 3);
  X := 0;
  while X < Width do
  begin
    DrawPixel(Buffer, Width, Height, X, CenterY, Max(1, Size div 2), R div 3, G div 3, B div 3, 190);
    Inc(X, Step);
  end;
end;

procedure DrawPixelWave(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
var
  CenterY: Integer;
  HalfHeight: Integer;
  PointCount: Integer;
  I: Integer;
  X: Integer;
  Y: Integer;
  YMin: Integer;
  YMax: Integer;
  StepY: Integer;
  PixelSize: Integer;
  R, G, B: Byte;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  UpdateViewWave(Settings.Smooth, CurrentWave, CurrentWaveMin, CurrentWaveMax,
    CurrentWaveValid, CurrentFrame, Settings.SourceLayer);

  CenterY := Height div 2;
  HalfHeight := Max(1, (Height - 1) div 2);
  PixelSize := Max(1, Min(32, Settings.Thickness));

  GetViewColor(Settings, 0, Max(1, Width), R, G, B);
  DrawCenterGuide(Buffer, Width, Height, CenterY, PixelSize, R, G, B);

  if not CurrentWaveValid then
    Exit;

  // Density は他タイプと尺度を合わせつつ、点表示では4倍して輪郭を読み取れる密度を確保する。
  PointCount := Max(8, Min(512, Settings.Density * 4));
  if Width < PointCount then
    PointCount := Width;

  for I := 0 to PointCount - 1 do
  begin
    X := Round(I * Max(0, Width - 1) / Max(1, PointCount - 1));
    GetViewColor(Settings, I, PointCount, R, G, B);

    if Settings.Style = VIEW_STYLE_BLOCKS then
    begin
      // Blocks は min/max 包絡線の範囲を点で埋め、短時間ピークの幅を可視化する。
      YMin := CenterY - Round(
        ApplyViewGain(InterpolateWave(CurrentWaveMin, I, PointCount), Settings) * HalfHeight);
      YMax := CenterY - Round(
        ApplyViewGain(InterpolateWave(CurrentWaveMax, I, PointCount), Settings) * HalfHeight);
      if YMin > YMax then
      begin
        Y := YMin;
        YMin := YMax;
        YMax := Y;
      end;

      StepY := Max(2, PixelSize + Max(0, Settings.Spacing));
      Y := YMin;
      while Y <= YMax do
      begin
        DrawPixel(Buffer, Width, Height, X, Y, PixelSize, R, G, B, 255);
        Inc(Y, StepY);
      end;
    end
    else
    begin
      Y := CenterY - Round(ApplyViewGain(InterpolateWave(CurrentWave, I, PointCount), Settings) * HalfHeight);
      DrawPixel(Buffer, Width, Height, X, Y, PixelSize, R, G, B, 255);
    end;
  end;
end;

end.
