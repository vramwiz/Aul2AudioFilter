unit Aul2AudioViewRenderWaveLine;

// 時間波形を中央線基準の連続線と min/max 包絡線へ変換し、Wave Line を描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 現在フレームの波形を中央線基準の線として透明 RGBA バッファへ描画する。
procedure DrawWaveLine(Buffer: PPIXEL_RGBA; Width, Height: Integer;
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

function WaveValue(X, Width: Integer): Single;
var
  Position: Double;
  Point0: Integer;
  Point1: Integer;
  Frac: Double;
begin
  if (not CurrentWaveValid) or (Width <= 1) then
    Exit(0.0);

  Position := X * AUDIO_MONITOR_WAVE_POINT_LAST / (Width - 1);
  Point0 := Max(0, Min(AUDIO_MONITOR_WAVE_POINT_LAST, Floor(Position)));
  Point1 := Max(0, Min(AUDIO_MONITOR_WAVE_POINT_LAST, Point0 + 1));
  Frac := Position - Point0;

  // 共有波形の点数と出力幅が異なっても段差が出ないよう、隣接点を線形補間する。
  Result := CurrentWave[Point0] + ((CurrentWave[Point1] - CurrentWave[Point0]) * Frac);
  Result := Max(-1.0, Min(1.0, Result));
end;

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

procedure DrawLine(Buffer: PPIXEL_RGBA; Width, Height, X1, Y1, X2, Y2: Integer;
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

    E2 := 2 * Err;
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

procedure DrawWaveEnvelope(Buffer: PPIXEL_RGBA; Width, Height, CenterY, HalfHeight: Integer;
  const Settings: TAul2AudioViewSettings);
var
  X: Integer;
  Position: Double;
  Point0: Integer;
  Point1: Integer;
  Frac: Double;
  MinValue: Single;
  MaxValue: Single;
  YMin: Integer;
  YMax: Integer;
  R, G, B: Byte;
  Thickness: Integer;
begin
  // Style=Blocks のときだけ min/max 包絡線を薄く重ね、瞬間的なピーク幅を残す。
  if Settings.Style <> VIEW_STYLE_BLOCKS then
    Exit;

  Thickness := Max(1, Min(32, Settings.Thickness));
  for X := 0 to Width - 1 do
  begin
    Position := X * AUDIO_MONITOR_WAVE_POINT_LAST / Max(1, Width - 1);
    Point0 := Max(0, Min(AUDIO_MONITOR_WAVE_POINT_LAST, Floor(Position)));
    Point1 := Max(0, Min(AUDIO_MONITOR_WAVE_POINT_LAST, Point0 + 1));
    Frac := Position - Point0;
    MinValue := CurrentWaveMin[Point0] + ((CurrentWaveMin[Point1] - CurrentWaveMin[Point0]) * Frac);
    MaxValue := CurrentWaveMax[Point0] + ((CurrentWaveMax[Point1] - CurrentWaveMax[Point0]) * Frac);
    YMin := CenterY - Round(ApplyYScale(MinValue, Settings) * HalfHeight);
    YMax := CenterY - Round(ApplyYScale(MaxValue, Settings) * HalfHeight);

    GetViewColor(Settings, X, Width, R, G, B);
    DrawLine(Buffer, Width, Height, X, YMin, X, YMax, Max(1, Thickness div 2), R, G, B, 120);
  end;
end;

procedure DrawWaveLine(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
var
  CenterY: Integer;
  HalfHeight: Integer;
  X: Integer;
  PrevX: Integer;
  PrevY: Integer;
  Y: Integer;
  R, G, B: Byte;
  Thickness: Integer;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  UpdateViewWave(Settings.Smooth, CurrentWave, CurrentWaveMin, CurrentWaveMax,
    CurrentWaveValid, CurrentFrame, Settings.SourceLayer);

  CenterY := Height div 2;
  HalfHeight := Max(1, (Height - 1) div 2);
  Thickness := Max(1, Min(32, Settings.Thickness));

  GetViewColor(Settings, 0, Max(1, Width), R, G, B);
  // 無音時にも振幅ゼロの位置が分かるよう、暗い基準線を常時描画する。
  DrawLine(Buffer, Width, Height, 0, CenterY, Width - 1, CenterY,
    Max(1, Thickness div 2), R div 3, G div 3, B div 3, 255);

  if not CurrentWaveValid then
    Exit;

  DrawWaveEnvelope(Buffer, Width, Height, CenterY, HalfHeight, Settings);

  PrevX := 0;
  PrevY := CenterY - Round(ApplyYScale(WaveValue(0, Width), Settings) * HalfHeight);
  for X := 1 to Width - 1 do
  begin
    Y := CenterY - Round(ApplyYScale(WaveValue(X, Width), Settings) * HalfHeight);
    GetViewColor(Settings, X, Width, R, G, B);
    DrawLine(Buffer, Width, Height, PrevX, PrevY, X, Y, Thickness, R, G, B, 255);
    if Settings.Style = VIEW_STYLE_BLOCKS then
    begin
      DrawPoint(Buffer, Width, Height, X, Y - Thickness, Max(1, Thickness div 2), R, G, B, 255);
      DrawPoint(Buffer, Width, Height, X, Y + Thickness, Max(1, Thickness div 2), R, G, B, 255);
    end;
    PrevX := X;
    PrevY := Y;
  end;
end;

end.
