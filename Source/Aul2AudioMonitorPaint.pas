unit Aul2AudioMonitorPaint;

// Aul2AudioMonitor の表示描画を担当する。

interface

uses
  Winapi.Windows,
  Vcl.Graphics,
  Aul2AudioMonitorShared,
  Aul2AudioMonitorSpectrumShared;

procedure DrawAudioMonitorCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorState);
procedure DrawAudioMonitorPlaceholder(Canvas: TCanvas; const ClientRect: TRect;
  const Text: string);
procedure DrawAudioSpectrumCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorSpectrumState);

implementation

uses
  System.Math,
  System.SysUtils,
  System.Types;

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
  State: PAul2AudioMonitorState);
var
  PlotRect: TRect;
  CenterY: Integer;
  CaptionText: string;
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
    if (State = nil) or (State^.Magic <> AUDIO_MONITOR_SHARED_MAGIC) or
       (State^.Version <> AUDIO_MONITOR_SHARED_VERSION) or (State^.Stage <> 3) then
    begin
      Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
        'Aul2AudioMonitor - waiting audio data');
      Exit;
    end;

    CaptionText := Format('Aul2AudioMonitor  %d Hz  %d ch',
      [State^.SampleRate, State^.ChannelNum]);
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8, CaptionText);

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

    DrawWaveEnvelope(Canvas, PlotRect, State^.InputWaveMin, State^.InputWaveMax,
      RGB(92, 190, 122));
    DrawWaveEnvelope(Canvas, PlotRect, State^.OutputWaveMin, State^.OutputWaveMax,
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

procedure DrawAudioSpectrumCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorSpectrumState);
var
  PlotRect: TRect;
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

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Font.Color := RGB(220, 220, 220);
  Canvas.Brush.Style := bsClear;

  try
    if (State = nil) or (State^.Magic <> AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) or
       (State^.Version <> AUDIO_MONITOR_SPECTRUM_SHARED_VERSION) then
    begin
      Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
        'Spectrum - waiting audio data');
      Exit;
    end;

    CaptionText := Format('Spectrum  %d Hz  %d bands',
      [State^.SampleRate, State^.BandCount]);
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
    DrawSpectrumBars(Canvas, PlotRect, State^.InputBands, RGB(92, 190, 122),
      -BarWidth, BarWidth);
    DrawSpectrumBars(Canvas, PlotRect, State^.OutputBands, RGB(224, 176, 72),
      1, BarWidth);

    DrawLegend(Canvas, ClientRect.Left + 12, ClientRect.Top + 26);
  except
    Canvas.Font.Color := RGB(220, 220, 220);
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
      'Spectrum - draw error');
  end;

  Canvas.Brush.Style := bsSolid;
end;

end.
