unit Aul2AudioMonitorPaint;

// Aul2AudioMonitor の表示描画を担当する。

interface

uses
  Winapi.Windows,
  Vcl.Graphics,
  Aul2AudioMonitorShared,
  Aul2AudioMonitorSpectrumShared;

procedure DrawAudioMonitorCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorState; AllowDataUpdate: Boolean);
procedure DrawAudioMonitorPlaceholder(Canvas: TCanvas; const ClientRect: TRect;
  const Text: string);
procedure DrawAudioSpectrumCanvas(Canvas: TCanvas; const ClientRect: TRect;
  SpectrumState: PAul2AudioMonitorSpectrumState; MonitorState: PAul2AudioMonitorState;
  AllowDataUpdate: Boolean);
procedure ClearAudioMonitorDisplay;

implementation

uses
  System.Math,
  System.SysUtils,
  System.Types;

var
  DisplayPeakInputL : Single;
  DisplayPeakInputR : Single;
  DisplayPeakOutputL: Single;
  DisplayPeakOutputR: Single;
  DisplayInputBalance : Single;
  DisplayOutputBalance: Single;
  DisplayPeakValid  : Boolean;
  DisplayInputWaveMin : TAudioMonitorWaveData;
  DisplayInputWaveMax : TAudioMonitorWaveData;
  DisplayOutputWaveMin: TAudioMonitorWaveData;
  DisplayOutputWaveMax: TAudioMonitorWaveData;
  DisplayWaveValid    : Boolean;
  DisplayInputBands : TAudioMonitorSpectrumData;
  DisplayOutputBands: TAudioMonitorSpectrumData;
  DisplaySpectrumValid: Boolean;

procedure ClearAudioMonitorDisplay;
begin
  DisplayPeakInputL := 0;
  DisplayPeakInputR := 0;
  DisplayPeakOutputL := 0;
  DisplayPeakOutputR := 0;
  DisplayInputBalance := 0;
  DisplayOutputBalance := 0;
  DisplayPeakValid := False;
  FillChar(DisplayInputWaveMin, SizeOf(DisplayInputWaveMin), 0);
  FillChar(DisplayInputWaveMax, SizeOf(DisplayInputWaveMax), 0);
  FillChar(DisplayOutputWaveMin, SizeOf(DisplayOutputWaveMin), 0);
  FillChar(DisplayOutputWaveMax, SizeOf(DisplayOutputWaveMax), 0);
  DisplayWaveValid := False;
  FillChar(DisplayInputBands, SizeOf(DisplayInputBands), 0);
  FillChar(DisplayOutputBands, SizeOf(DisplayOutputBands), 0);
  DisplaySpectrumValid := False;
end;

function TickIsFresh(UpdateTick: UInt64): Boolean;
const
  MONITOR_STALE_MS = 2500;
var
  NowTick: UInt64;
begin
  if UpdateTick = 0 then
    Exit(False);

  NowTick := GetTickCount64;
  Result := (NowTick >= UpdateTick) and ((NowTick - UpdateTick) <= MONITOR_STALE_MS);
end;

function MonitorStateValid(State: PAul2AudioMonitorState): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_MONITOR_SHARED_MAGIC) and
    (State^.Version = AUDIO_MONITOR_SHARED_VERSION);
end;

function SpectrumStateValid(State: PAul2AudioMonitorSpectrumState): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) and
    (State^.Version = AUDIO_MONITOR_SPECTRUM_SHARED_VERSION);
end;

function MonitorStateFresh(State: PAul2AudioMonitorState): Boolean;
begin
  Result := MonitorStateValid(State) and TickIsFresh(State^.UpdateTick);
end;

function SpectrumStateFresh(State: PAul2AudioMonitorSpectrumState): Boolean;
begin
  Result := SpectrumStateValid(State) and TickIsFresh(State^.UpdateTick);
end;

function CalcStereoBalance(RmsL, RmsR: Single): Single;
var
  Total: Single;
begin
  Total := Max(0.000001, RmsL + RmsR);
  Result := Max(-1.0, Min(1.0, (RmsR - RmsL) / Total));
end;

procedure UpdateDisplayPeaks(State: PAul2AudioMonitorState; AllowDataUpdate: Boolean);
const
  PEAK_DECAY = 0.84;
begin
  if AllowDataUpdate and MonitorStateFresh(State) then
  begin
    DisplayPeakInputL := Max(State^.InputPeakL, DisplayPeakInputL * PEAK_DECAY);
    DisplayPeakInputR := Max(State^.InputPeakR, DisplayPeakInputR * PEAK_DECAY);
    DisplayPeakOutputL := Max(State^.OutputPeakL, DisplayPeakOutputL * PEAK_DECAY);
    DisplayPeakOutputR := Max(State^.OutputPeakR, DisplayPeakOutputR * PEAK_DECAY);
    DisplayInputBalance := CalcStereoBalance(State^.InputRmsL, State^.InputRmsR);
    DisplayOutputBalance := CalcStereoBalance(State^.OutputRmsL, State^.OutputRmsR);
    DisplayPeakValid := True;
    Exit;
  end;

  if DisplayPeakValid then
  begin
    DisplayPeakInputL := DisplayPeakInputL * PEAK_DECAY;
    DisplayPeakInputR := DisplayPeakInputR * PEAK_DECAY;
    DisplayPeakOutputL := DisplayPeakOutputL * PEAK_DECAY;
    DisplayPeakOutputR := DisplayPeakOutputR * PEAK_DECAY;
  end;
end;

procedure SmoothWavePoint(var DisplayMin, DisplayMax: Single; NewMin, NewMax: Single);
const
  WAVE_SMOOTH = 0.30;
begin
  DisplayMin := DisplayMin + ((NewMin - DisplayMin) * WAVE_SMOOTH);
  DisplayMax := DisplayMax + ((NewMax - DisplayMax) * WAVE_SMOOTH);
end;

procedure UpdateDisplayWave(State: PAul2AudioMonitorState; AllowDataUpdate: Boolean);
var
  Point: Integer;
begin
  if (not AllowDataUpdate) or (not MonitorStateFresh(State)) then
    Exit;

  if not DisplayWaveValid then
  begin
    DisplayInputWaveMin := State^.InputWaveMin;
    DisplayInputWaveMax := State^.InputWaveMax;
    DisplayOutputWaveMin := State^.OutputWaveMin;
    DisplayOutputWaveMax := State^.OutputWaveMax;
    DisplayWaveValid := True;
    Exit;
  end;

  for Point := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
  begin
    SmoothWavePoint(DisplayInputWaveMin[Point], DisplayInputWaveMax[Point],
      State^.InputWaveMin[Point], State^.InputWaveMax[Point]);
    SmoothWavePoint(DisplayOutputWaveMin[Point], DisplayOutputWaveMax[Point],
      State^.OutputWaveMin[Point], State^.OutputWaveMax[Point]);
  end;
end;

procedure SmoothSpectrumBand(var DisplayValue: Single; NewValue: Single);
const
  SPECTRUM_ATTACK = 0.55;
  SPECTRUM_RELEASE = 0.16;
var
  Alpha: Single;
begin
  NewValue := Max(0.0, Min(1.0, NewValue));
  if NewValue > DisplayValue then
    Alpha := SPECTRUM_ATTACK
  else
    Alpha := SPECTRUM_RELEASE;

  DisplayValue := DisplayValue + ((NewValue - DisplayValue) * Alpha);
end;

procedure UpdateDisplaySpectrum(SpectrumState: PAul2AudioMonitorSpectrumState; AllowDataUpdate: Boolean);
var
  Band: Integer;
begin
  if (not AllowDataUpdate) or (not SpectrumStateFresh(SpectrumState)) then
    Exit;

  if not DisplaySpectrumValid then
  begin
    DisplayInputBands := SpectrumState^.InputBands;
    DisplayOutputBands := SpectrumState^.OutputBands;
    DisplaySpectrumValid := True;
    Exit;
  end;

  for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
  begin
    SmoothSpectrumBand(DisplayInputBands[Band], SpectrumState^.InputBands[Band]);
    SmoothSpectrumBand(DisplayOutputBands[Band], SpectrumState^.OutputBands[Band]);
  end;
end;

function MonitorSourceText(Layer, Index, FrameS, FrameE: Integer): string;
begin
  Result := Format('Layer %d  Index %d  Frame %d-%d',
    [Layer + 1, Index, FrameS, FrameE]);
end;

procedure DrawWaveEnvelope(Canvas: TCanvas; const PlotRect: TRect;
  const WaveMin, WaveMax: TAudioMonitorWaveData; Color: TColor);
var
  Point: Integer;
  X: Integer;
  YMin: Integer;
  YMax: Integer;
  CenterY: Integer;
  HalfHeight: Integer;
  MinValue: Single;
  MaxValue: Single;
begin
  if (PlotRect.Right <= PlotRect.Left) or (PlotRect.Bottom <= PlotRect.Top) then
    Exit;

  CenterY := (PlotRect.Top + PlotRect.Bottom) div 2;
  HalfHeight := Max(1, (PlotRect.Bottom - PlotRect.Top) div 2 - 4);

  Canvas.Pen.Color := Color;
  Canvas.Pen.Width := 2;

  for Point := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
  begin
    MinValue := Max(-1.0, Min(1.0, WaveMin[Point]));
    MaxValue := Max(-1.0, Min(1.0, WaveMax[Point]));
    X := PlotRect.Left + MulDiv(Point, Max(1, PlotRect.Right - PlotRect.Left - 1),
      AUDIO_MONITOR_WAVE_POINT_LAST);
    YMin := CenterY - Round(MinValue * HalfHeight);
    YMax := CenterY - Round(MaxValue * HalfHeight);

    Canvas.MoveTo(X, YMin);
    Canvas.LineTo(X, YMax);
  end;
end;

procedure DrawAudioMonitorCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorState; AllowDataUpdate: Boolean);
var
  PlotRect: TRect;
  CenterY: Integer;
  CaptionText: string;
  StateValid: Boolean;
begin
  Canvas.Brush.Color := RGB(36, 36, 36);
  Canvas.FillRect(ClientRect);

  PlotRect := ClientRect;
  InflateRect(PlotRect, -12, -12);
  PlotRect.Top := PlotRect.Top + 42;

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Color := RGB(220, 220, 220);
  Canvas.Brush.Style := bsClear;

  try
    StateValid := MonitorStateValid(State);
    if (not StateValid) and (not DisplayWaveValid) then
    begin
      DisplayWaveValid := False;
      Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
        'Wave - waiting audio data');
      Exit;
    end;

    if StateValid then
      CaptionText := Format('Wave  %d Hz  %d ch  %s',
        [State^.SampleRate, State^.ChannelNum,
         MonitorSourceText(State^.SourceLayer, State^.SourceIndex,
           State^.SourceFrameS, State^.SourceFrameE)])
    else
      CaptionText := 'Wave';
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8, CaptionText);

    UpdateDisplayWave(State, AllowDataUpdate);

    CenterY := (PlotRect.Top + PlotRect.Bottom) div 2;
    Canvas.Pen.Color := RGB(84, 84, 84);
    Canvas.Pen.Width := 1;
    Canvas.MoveTo(PlotRect.Left, CenterY);
    Canvas.LineTo(PlotRect.Right, CenterY);

    Canvas.Pen.Color := RGB(56, 56, 56);
    Canvas.MoveTo(PlotRect.Left, PlotRect.Top);
    Canvas.LineTo(PlotRect.Right, PlotRect.Top);
    Canvas.LineTo(PlotRect.Right, PlotRect.Bottom);
    Canvas.LineTo(PlotRect.Left, PlotRect.Bottom);
    Canvas.LineTo(PlotRect.Left, PlotRect.Top);

    DrawWaveEnvelope(Canvas, PlotRect, DisplayInputWaveMin, DisplayInputWaveMax,
      RGB(92, 190, 122));
    DrawWaveEnvelope(Canvas, PlotRect, DisplayOutputWaveMin, DisplayOutputWaveMax,
      RGB(224, 176, 72));

    Canvas.Font.Color := RGB(92, 190, 122);
    Canvas.TextOut(ClientRect.Right - 150, ClientRect.Top + 8, 'Input');
    Canvas.Font.Color := RGB(224, 176, 72);
    Canvas.TextOut(ClientRect.Right - 88, ClientRect.Top + 8, 'Output');
  except
    Canvas.Font.Color := RGB(220, 220, 220);
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
      'Aul2AudioMonitor - draw error');
  end;

  Canvas.Brush.Style := bsSolid;
end;

procedure DrawAudioMonitorPlaceholder(Canvas: TCanvas; const ClientRect: TRect;
  const Text: string);
begin
  Canvas.Brush.Color := RGB(36, 36, 36);
  Canvas.FillRect(ClientRect);
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Color := RGB(220, 220, 220);
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8, Text);
  Canvas.Brush.Style := bsSolid;
end;

procedure DrawSpectrumBars(Canvas: TCanvas; const PlotRect: TRect;
  const Bands: TAudioMonitorSpectrumData; Color: TColor; BarOffset, BarWidth: Integer);
var
  Band: Integer;
  X: Integer;
  Y: Integer;
  H: Integer;
  R: TRect;
  Value: Single;
begin
  if (PlotRect.Right <= PlotRect.Left) or (PlotRect.Bottom <= PlotRect.Top) then
    Exit;

  Canvas.Brush.Color := Color;
  Canvas.Pen.Color := Color;

  for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
  begin
    Value := Max(0.0, Min(1.0, Bands[Band]));
    X := PlotRect.Left + MulDiv(Band, Max(1, PlotRect.Right - PlotRect.Left - 1),
      AUDIO_MONITOR_SPECTRUM_BAND_COUNT);
    H := Round(Value * (PlotRect.Bottom - PlotRect.Top));
    Y := PlotRect.Bottom - H;

    R := Rect(X + BarOffset, Y, X + BarOffset + BarWidth, PlotRect.Bottom);
    Canvas.FillRect(R);
  end;
end;

procedure DrawLegend(Canvas: TCanvas; X, Y: Integer);
var
  R: TRect;
begin
  Canvas.Font.Color := RGB(220, 220, 220);

  R := Rect(X, Y + 3, X + 20, Y + 12);
  Canvas.Brush.Color := RGB(92, 190, 122);
  Canvas.FillRect(R);
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(X + 26, Y, 'Input');

  R := Rect(X + 86, Y + 3, X + 106, Y + 12);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := RGB(224, 176, 72);
  Canvas.FillRect(R);
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(X + 112, Y, 'Output');
end;

procedure DrawVerticalPeakBar(Canvas: TCanvas; const TrackRect: TRect; Peak: Single;
  Color: TColor);
var
  FillRect: TRect;
  ClipY: Integer;
begin
  Peak := Min(1.25, Max(0.0, Peak));

  Canvas.Pen.Color := RGB(68, 68, 68);
  Canvas.Brush.Color := RGB(44, 44, 44);
  Canvas.Rectangle(TrackRect);

  FillRect := TrackRect;
  InflateRect(FillRect, -1, -1);
  FillRect.Top := FillRect.Bottom - Round((FillRect.Bottom - FillRect.Top) *
    Min(1.0, Peak));
  Canvas.Brush.Color := Color;
  Canvas.Pen.Color := Color;
  Canvas.FillRect(FillRect);

  ClipY := TrackRect.Bottom - MulDiv(100, TrackRect.Bottom - TrackRect.Top, 125);
  Canvas.Pen.Color := RGB(210, 92, 76);
  Canvas.MoveTo(TrackRect.Left, ClipY);
  Canvas.LineTo(TrackRect.Right, ClipY);
end;

procedure DrawStereoBalance(Canvas: TCanvas; const BalanceRect: TRect;
  InputBalance, OutputBalance: Single);
var
  CenterX: Integer;
  InputX: Integer;
  OutputX: Integer;
  TrackTop: Integer;
  TrackBottom: Integer;
begin
  if (BalanceRect.Right <= BalanceRect.Left) or (BalanceRect.Bottom <= BalanceRect.Top) then
    Exit;

  if (BalanceRect.Bottom - BalanceRect.Top) < 34 then
    Exit;

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := RGB(220, 220, 220);
  Canvas.TextOut(BalanceRect.Left, BalanceRect.Top, 'Stereo');

  TrackTop := BalanceRect.Top + 22;
  TrackBottom := BalanceRect.Bottom - 8;
  CenterX := (BalanceRect.Left + BalanceRect.Right) div 2;

  Canvas.Pen.Color := RGB(68, 68, 68);
  Canvas.MoveTo(BalanceRect.Left + 4, TrackTop);
  Canvas.LineTo(BalanceRect.Right - 4, TrackTop);
  Canvas.MoveTo(CenterX, TrackTop - 5);
  Canvas.LineTo(CenterX, TrackBottom + 2);

  InputX := CenterX + Round(InputBalance * ((BalanceRect.Right - BalanceRect.Left - 12) * 0.5));
  OutputX := CenterX + Round(OutputBalance * ((BalanceRect.Right - BalanceRect.Left - 12) * 0.5));

  Canvas.Pen.Color := RGB(92, 190, 122);
  Canvas.Brush.Color := RGB(92, 190, 122);
  Canvas.Ellipse(InputX - 3, TrackTop - 4, InputX + 4, TrackTop + 3);

  Canvas.Pen.Color := RGB(224, 176, 72);
  Canvas.Brush.Color := RGB(224, 176, 72);
  Canvas.Ellipse(OutputX - 3, TrackTop + 5, OutputX + 4, TrackTop + 12);

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := RGB(150, 150, 150);
  Canvas.TextOut(BalanceRect.Left + 2, BalanceRect.Bottom - 10, 'L');
  Canvas.TextOut(BalanceRect.Right - 10, BalanceRect.Bottom - 10, 'R');
  Canvas.Brush.Style := bsSolid;
end;

procedure DrawPeakMeters(Canvas: TCanvas; const MeterRect: TRect;
  State: PAul2AudioMonitorState; AllowDataUpdate: Boolean);
var
  BarRect: TRect;
  BalanceRect: TRect;
  BarTop: Integer;
  BarBottom: Integer;
  BarWidth: Integer;
  Gap: Integer;
  X: Integer;
begin
  if (MeterRect.Right <= MeterRect.Left) or (MeterRect.Bottom <= MeterRect.Top) then
    Exit;

  UpdateDisplayPeaks(State, AllowDataUpdate);

  Canvas.Pen.Color := RGB(56, 56, 56);
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(MeterRect);

  Canvas.Font.Color := RGB(220, 220, 220);
  Canvas.TextOut(MeterRect.Left + 2, MeterRect.Top, 'Peak');

  if not DisplayPeakValid then
  begin
    Canvas.Font.Color := RGB(150, 150, 150);
    Canvas.TextOut(MeterRect.Left + 2, MeterRect.Top + 18, 'wait');
    Exit;
  end;

  BarTop := MeterRect.Top + 38;
  BarBottom := MeterRect.Bottom - 64;
  if BarBottom < BarTop + 24 then
    BarBottom := BarTop + 24;
  BarWidth := Max(6, (MeterRect.Right - MeterRect.Left - 18) div 4);
  Gap := Max(2, (MeterRect.Right - MeterRect.Left - (BarWidth * 4)) div 5);
  X := MeterRect.Left + Gap;

  Canvas.Font.Color := RGB(92, 190, 122);
  Canvas.TextOut(MeterRect.Left + 2, MeterRect.Top + 18, 'In');
  Canvas.Font.Color := RGB(224, 176, 72);
  Canvas.TextOut(MeterRect.Left + 32, MeterRect.Top + 18, 'Out');

  BarRect := Rect(X, BarTop, X + BarWidth, BarBottom);
  DrawVerticalPeakBar(Canvas, BarRect, DisplayPeakInputL, RGB(92, 190, 122));
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := RGB(150, 150, 150);
  Canvas.TextOut(BarRect.Left + 1, BarBottom + 2, 'L');
  Inc(X, BarWidth + Gap);

  BarRect := Rect(X, BarTop, X + BarWidth, BarBottom);
  DrawVerticalPeakBar(Canvas, BarRect, DisplayPeakInputR, RGB(92, 190, 122));
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := RGB(150, 150, 150);
  Canvas.TextOut(BarRect.Left + 1, BarBottom + 2, 'R');
  Inc(X, BarWidth + Gap);

  BarRect := Rect(X, BarTop, X + BarWidth, BarBottom);
  DrawVerticalPeakBar(Canvas, BarRect, DisplayPeakOutputL, RGB(224, 176, 72));
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := RGB(150, 150, 150);
  Canvas.TextOut(BarRect.Left + 1, BarBottom + 2, 'L');
  Inc(X, BarWidth + Gap);

  BarRect := Rect(X, BarTop, X + BarWidth, BarBottom);
  DrawVerticalPeakBar(Canvas, BarRect, DisplayPeakOutputR, RGB(224, 176, 72));
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := RGB(150, 150, 150);
  Canvas.TextOut(BarRect.Left + 1, BarBottom + 2, 'R');

  BalanceRect := Rect(MeterRect.Left + 2, BarBottom + 22, MeterRect.Right - 2,
    MeterRect.Bottom - 2);
  DrawStereoBalance(Canvas, BalanceRect, DisplayInputBalance, DisplayOutputBalance);
  Canvas.Brush.Style := bsSolid;
end;

procedure DrawAudioSpectrumCanvas(Canvas: TCanvas; const ClientRect: TRect;
  SpectrumState: PAul2AudioMonitorSpectrumState; MonitorState: PAul2AudioMonitorState;
  AllowDataUpdate: Boolean);
var
  PlotRect: TRect;
  MeterRect: TRect;
  CaptionText: string;
  Grid: Integer;
  Y: Integer;
  BarWidth: Integer;
begin
  Canvas.Brush.Color := RGB(36, 36, 36);
  Canvas.FillRect(ClientRect);

  PlotRect := ClientRect;
  InflateRect(PlotRect, -12, -12);
  PlotRect.Top := PlotRect.Top + 22;
  MeterRect := PlotRect;
  MeterRect.Left := Max(PlotRect.Left + 60, PlotRect.Right - 72);
  PlotRect.Right := MeterRect.Left - 12;

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Color := RGB(220, 220, 220);
  Canvas.Brush.Style := bsClear;

  try
    if (not SpectrumStateValid(SpectrumState)) and (not DisplaySpectrumValid) then
    begin
      DisplaySpectrumValid := False;
      Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
        'Spectrum - waiting audio data');
      DrawPeakMeters(Canvas, MeterRect, MonitorState, AllowDataUpdate);
      Exit;
    end;

    UpdateDisplaySpectrum(SpectrumState, AllowDataUpdate);

    if SpectrumStateValid(SpectrumState) then
      CaptionText := Format('Spectrum  %d Hz  %d bands  %s',
        [SpectrumState^.SampleRate, SpectrumState^.BandCount,
         MonitorSourceText(SpectrumState^.SourceLayer, SpectrumState^.SourceIndex,
           SpectrumState^.SourceFrameS, SpectrumState^.SourceFrameE)])
    else
      CaptionText := 'Spectrum';
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8, CaptionText);

    Canvas.Pen.Color := RGB(56, 56, 56);
    Canvas.MoveTo(PlotRect.Left, PlotRect.Top);
    Canvas.LineTo(PlotRect.Right, PlotRect.Top);
    Canvas.LineTo(PlotRect.Right, PlotRect.Bottom);
    Canvas.LineTo(PlotRect.Left, PlotRect.Bottom);
    Canvas.LineTo(PlotRect.Left, PlotRect.Top);

    Canvas.Pen.Color := RGB(48, 48, 48);
    for Grid := 1 to 3 do
    begin
      Y := PlotRect.Top + MulDiv(Grid, PlotRect.Bottom - PlotRect.Top, 4);
      Canvas.MoveTo(PlotRect.Left, Y);
      Canvas.LineTo(PlotRect.Right, Y);
    end;

    BarWidth := Max(1, (PlotRect.Right - PlotRect.Left) div
      (AUDIO_MONITOR_SPECTRUM_BAND_COUNT * 3));
    DrawSpectrumBars(Canvas, PlotRect, DisplayInputBands, RGB(92, 190, 122),
      -BarWidth, BarWidth);
    DrawSpectrumBars(Canvas, PlotRect, DisplayOutputBands, RGB(224, 176, 72),
      1, BarWidth);

    DrawLegend(Canvas, ClientRect.Left + 12, ClientRect.Top + 26);
    DrawPeakMeters(Canvas, MeterRect, MonitorState, AllowDataUpdate);
  except
    Canvas.Font.Color := RGB(220, 220, 220);
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
      'Spectrum - draw error');
  end;

  Canvas.Brush.Style := bsSolid;
end;

end.
