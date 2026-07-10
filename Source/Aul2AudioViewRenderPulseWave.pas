unit Aul2AudioViewRenderPulseWave;

// Draws the Pulse Wave view type.

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

procedure DrawPulseWave(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);

implementation

uses
  System.Math,
  Aul2AudioMonitorShared,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewWave;

var
  CurrentWave: TAudioMonitorWaveData;
  CurrentWaveMin: TAudioMonitorWaveData;
  CurrentWaveMax: TAudioMonitorWaveData;
  CurrentWaveValid: Boolean;

function InterpolateWaveAbs(const WaveA, WaveB: TAudioMonitorWaveData;
  Index, Count: Integer): Single;
var
  Position: Double;
  Point0: Integer;
  Point1: Integer;
  Frac: Double;
  ValueA: Single;
  ValueB: Single;
begin
  if Count <= 1 then
    Exit(0.0);

  Position := Index * AUDIO_MONITOR_WAVE_POINT_LAST / (Count - 1);
  Point0 := Max(0, Min(AUDIO_MONITOR_WAVE_POINT_LAST, Floor(Position)));
  Point1 := Max(0, Min(AUDIO_MONITOR_WAVE_POINT_LAST, Point0 + 1));
  Frac := Position - Point0;

  ValueA := WaveA[Point0] + ((WaveA[Point1] - WaveA[Point0]) * Frac);
  ValueB := WaveB[Point0] + ((WaveB[Point1] - WaveB[Point0]) * Frac);
  Result := Max(Abs(ValueA), Abs(ValueB));
  Result := Max(0.0, Min(1.0, Result));
end;

procedure DrawPulse(Buffer: PPIXEL_RGBA; Width, Height, CenterY, X, HalfH,
  Thickness: Integer; R, G, B, A: Byte);
var
  HalfW: Integer;
begin
  Thickness := Max(1, Thickness);
  HalfW := Thickness div 2;
  FillRect(Buffer, Width, Height, X - HalfW, CenterY - HalfH,
    X + Thickness - HalfW - 1, CenterY + HalfH, R, G, B, A);
end;

procedure DrawCenterGuide(Buffer: PPIXEL_RGBA; Width, Height, CenterY,
  Thickness: Integer; R, G, B: Byte);
begin
  FillRect(Buffer, Width, Height, 0, CenterY - Max(0, Thickness div 4),
    Width - 1, CenterY + Max(0, Thickness div 4), R div 4, G div 4, B div 4, 255);
end;

procedure DrawPulseWave(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
var
  CenterY: Integer;
  HalfHeight: Integer;
  PulseCount: Integer;
  I: Integer;
  X: Integer;
  PulseH: Integer;
  Thickness: Integer;
  Gap: Integer;
  R, G, B: Byte;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  UpdateViewWave(Settings.Smooth, CurrentWave, CurrentWaveMin, CurrentWaveMax,
    CurrentWaveValid, CurrentFrame, Settings.SourceLayer);

  CenterY := Height div 2;
  HalfHeight := Max(1, (Height - 1) div 2);
  Thickness := Max(1, Min(32, Settings.Thickness));
  Gap := Max(0, Settings.Spacing);

  GetViewColor(Settings, 0, Max(1, Width), R, G, B);
  DrawCenterGuide(Buffer, Width, Height, CenterY, Thickness, R, G, B);

  if not CurrentWaveValid then
    Exit;

  PulseCount := Max(4, Min(256, Settings.Density * 2));
  if Width < PulseCount then
    PulseCount := Width;

  for I := 0 to PulseCount - 1 do
  begin
    if (Gap > 0) and ((I mod (Gap + 1)) <> 0) then
      Continue;

    X := Round(I * Max(0, Width - 1) / Max(1, PulseCount - 1));
    if Settings.Style = VIEW_STYLE_BLOCKS then
      PulseH := Round(HalfHeight * ApplyViewGain(InterpolateWaveAbs(CurrentWaveMin, CurrentWaveMax, I, PulseCount), Settings))
    else
      PulseH := Round(HalfHeight * ApplyViewGain(InterpolateWaveAbs(CurrentWave, CurrentWave, I, PulseCount), Settings));

    if PulseH <= 0 then
      Continue;

    GetViewColor(Settings, I, PulseCount, R, G, B);
    DrawPulse(Buffer, Width, Height, CenterY, X, PulseH, Thickness, R, G, B, 255);
  end;
end;

end.
