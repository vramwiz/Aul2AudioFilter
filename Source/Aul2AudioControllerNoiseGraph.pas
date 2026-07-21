unit Aul2AudioControllerNoiseGraph;

// ControllerのNoise画面へ、処理直前・直後と差分の短い波形を描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  Aul2AudioNoiseWaveShared;

type
  TAul2ControllerNoiseGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FMode: Integer;
    FLevelDb: Double;
    FMix: Double;
    FWaveValid: Boolean;
    FSampleCount: Integer;
    FInputWave: TAudioNoiseWaveData;
    FOutputWave: TAudioNoiseWaveData;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearWave;
    procedure SetNoise(Mode: Integer; LevelDb, Mix: Double; Active: Boolean);
    procedure SetWave(const InputWave, OutputWave: TAudioNoiseWaveData;
      SampleCount: Integer);
    property AccentColor: TColor read FAccentColor write SetAccentColor;
  published
    property Font;
    property ParentFont;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  System.Types;

const
  NOISE_GRAPH_BACKGROUND = TColor($0013100E);
  NOISE_GRAPH_BORDER = TColor($00312C28);
  NOISE_GRAPH_GRID = TColor($002B2723);
  NOISE_GRAPH_AXIS = TColor($00645E58);
  NOISE_GRAPH_TEXT = TColor($00F2F0EE);
  NOISE_GRAPH_INPUT = TColor($007ABE5C);
  NOISE_GRAPH_OUTPUT = TColor($0048B0E0);

function ScaleColor(Color: TColor; Numerator, Denominator: Integer): TColor;
var
  Blue, Green, Red: Integer;
begin
  Color := ColorToRGB(Color);
  Red := EnsureRange(GetRValue(Color) * Numerator div Denominator, 0, 255);
  Green := EnsureRange(GetGValue(Color) * Numerator div Denominator, 0, 255);
  Blue := EnsureRange(GetBValue(Color) * Numerator div Denominator, 0, 255);
  Result := RGB(Red, Green, Blue);
end;

constructor TAul2ControllerNoiseGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := NOISE_GRAPH_BACKGROUND;
  FAccentColor := RGB(242, 242, 242);
  FActive := True;
  FMode := 0;
  FLevelDb := -36;
  FMix := 1;
  ClearWave;
end;

procedure TAul2ControllerNoiseGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerNoiseGraph.ClearWave;
begin
  FWaveValid := False;
  FSampleCount := 0;
  FillChar(FInputWave, SizeOf(FInputWave), 0);
  FillChar(FOutputWave, SizeOf(FOutputWave), 0);
  Invalidate;
end;

procedure TAul2ControllerNoiseGraph.SetNoise(Mode: Integer; LevelDb,
  Mix: Double; Active: Boolean);
begin
  FMode := EnsureRange(Mode, 0, 1);
  FLevelDb := EnsureRange(LevelDb, -80.0, -6.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerNoiseGraph.SetWave(const InputWave,
  OutputWave: TAudioNoiseWaveData; SampleCount: Integer);
begin
  FInputWave := InputWave;
  FOutputWave := OutputWave;
  FSampleCount := EnsureRange(SampleCount, 1, AUDIO_NOISE_WAVE_SAMPLE_COUNT);
  FWaveValid := True;
  Invalidate;
end;

procedure TAul2ControllerNoiseGraph.Paint;
var
  Difference: Double;
  DifferencePeak: Double;
  DifferencePoints: array of TPoint;
  HeaderText: string;
  I: Integer;
  InputOutputPeak: Double;
  InputPoints: array of TPoint;
  OutputPoints: array of TPoint;
  PlotBottom: Integer;
  PlotLeft: Integer;
  PlotRight: Integer;
  PlotTop: Integer;
  PlotWidth: Integer;
  SavedDC: Integer;
  SectionGap: Integer;
  SectionHeight: Integer;
  TopCenter: Integer;
  BottomCenter: Integer;
  WaveHalfHeight: Integer;

  function SampleToX(Index: Integer): Integer;
  begin
    if FSampleCount <= 1 then
      Exit(PlotLeft);
    Result := PlotLeft + Round(Index / (FSampleCount - 1) * PlotWidth);
  end;

  function WaveToY(Value, Peak: Double; CenterY: Integer): Integer;
  begin
    Result := CenterY - Round(EnsureRange(Value / Max(Peak, 0.000001),
      -1.0, 1.0) * WaveHalfHeight);
  end;

  function ScaleText(Peak: Double): string;
  begin
    if Peak >= 0.01 then
      Result := Format('+/-%.3f', [Peak])
    else
      Result := Format('+/-%.1e', [Peak]);
  end;

  procedure DrawBackedText(X, Y: Integer; const Text: string; TextColor: TColor);
  const
    HORIZONTAL_PADDING = 2;
    VERTICAL_PADDING = 1;
  var
    TextRect: TRect;
  begin
    TextRect := Rect(X - HORIZONTAL_PADDING, Y - VERTICAL_PADDING,
      X + Canvas.TextWidth(Text) + HORIZONTAL_PADDING,
      Y + Canvas.TextHeight(Text) + VERTICAL_PADDING);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := clBlack;
    Canvas.FillRect(TextRect);
    Canvas.Font.Color := TextColor;
    Canvas.TextOut(X, Y, Text);
    Canvas.Brush.Style := bsClear;
  end;

begin
  inherited;
  Canvas.Brush.Color := NOISE_GRAPH_BACKGROUND;
  Canvas.FillRect(ClientRect);
  if (ClientWidth <= 40) or (ClientHeight <= 50) then
    Exit;

  Canvas.Font.Assign(Font);
  Canvas.Font.Height := -MulDiv(9, Max(96, CurrentPPI), 72);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := NOISE_GRAPH_TEXT;
  if FMode = 1 then
    HeaderText := 'Crackle'
  else
    HeaderText := 'White';
  HeaderText := Format('%s  Level %.1fdB  Mix %.2f',
    [HeaderText, FLevelDb, FMix]);
  Canvas.TextOut(MulDiv(8, Max(96, CurrentPPI), 96),
    MulDiv(4, Max(96, CurrentPPI), 96), HeaderText);

  PlotLeft := MulDiv(8, Max(96, CurrentPPI), 96);
  PlotRight := ClientWidth - PlotLeft;
  PlotTop := MulDiv(26, Max(96, CurrentPPI), 96);
  PlotBottom := ClientHeight - MulDiv(6, Max(96, CurrentPPI), 96);
  PlotWidth := Max(1, PlotRight - PlotLeft);
  SectionGap := MulDiv(8, Max(96, CurrentPPI), 96);
  SectionHeight := Max(8, (PlotBottom - PlotTop - SectionGap) div 2);
  TopCenter := PlotTop + SectionHeight div 2;
  BottomCenter := PlotTop + SectionHeight + SectionGap + SectionHeight div 2;
  // 自動スケールした波形が枠の全高を埋めると、ラベルや隣の段へ
  // 重なって見えるため、上下に十分な余白を残す。
  WaveHalfHeight := Max(2, (SectionHeight div 2 - 2) * 13 div 20);

  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := NOISE_GRAPH_BORDER;
  Canvas.Rectangle(PlotLeft, PlotTop, PlotRight, PlotTop + SectionHeight);
  Canvas.Rectangle(PlotLeft, PlotTop + SectionHeight + SectionGap,
    PlotRight, PlotBottom);
  Canvas.Pen.Color := NOISE_GRAPH_AXIS;
  Canvas.MoveTo(PlotLeft, TopCenter);
  Canvas.LineTo(PlotRight, TopCenter);
  Canvas.MoveTo(PlotLeft, BottomCenter);
  Canvas.LineTo(PlotRight, BottomCenter);
  Canvas.Pen.Color := NOISE_GRAPH_GRID;
  for I := 1 to 3 do
  begin
    Canvas.MoveTo(PlotLeft + PlotWidth * I div 4, PlotTop);
    Canvas.LineTo(PlotLeft + PlotWidth * I div 4, PlotTop + SectionHeight);
    Canvas.MoveTo(PlotLeft + PlotWidth * I div 4,
      PlotTop + SectionHeight + SectionGap);
    Canvas.LineTo(PlotLeft + PlotWidth * I div 4, PlotBottom);
  end;

  if not FWaveValid or (FSampleCount <= 1) then
  begin
    Canvas.Font.Color := ScaleColor(NOISE_GRAPH_TEXT, 55, 100);
    Canvas.TextOut(PlotLeft + 5, TopCenter - Canvas.TextHeight('0') div 2,
      'No Noise waveform');
    Exit;
  end;

  InputOutputPeak := 0.000001;
  DifferencePeak := 0.000001;
  for I := 0 to FSampleCount - 1 do
  begin
    InputOutputPeak := Max(InputOutputPeak,
      Max(Abs(FInputWave[I]), Abs(FOutputWave[I])));
    DifferencePeak := Max(DifferencePeak,
      Abs(FOutputWave[I] - FInputWave[I]));
  end;
  InputOutputPeak := InputOutputPeak * 1.08;
  DifferencePeak := DifferencePeak * 1.08;

  SetLength(InputPoints, FSampleCount);
  SetLength(OutputPoints, FSampleCount);
  SetLength(DifferencePoints, FSampleCount);
  for I := 0 to FSampleCount - 1 do
  begin
    Difference := FOutputWave[I] - FInputWave[I];
    InputPoints[I] := Point(SampleToX(I),
      WaveToY(FInputWave[I], InputOutputPeak, TopCenter));
    OutputPoints[I] := Point(SampleToX(I),
      WaveToY(FOutputWave[I], InputOutputPeak, TopCenter));
    DifferencePoints[I] := Point(SampleToX(I),
      WaveToY(Difference, DifferencePeak, BottomCenter));
  end;

  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := ScaleColor(NOISE_GRAPH_INPUT, 78, 100);
  SavedDC := SaveDC(Canvas.Handle);
  try
    IntersectClipRect(Canvas.Handle, PlotLeft + 1, PlotTop + 1,
      PlotRight, PlotTop + SectionHeight);
    Canvas.Polyline(InputPoints);
    Canvas.Pen.Color := ScaleColor(NOISE_GRAPH_OUTPUT, 88, 100);
    Canvas.Polyline(OutputPoints);
  finally
    RestoreDC(Canvas.Handle, SavedDC);
  end;
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := FAccentColor;
  if not FActive then
    Canvas.Pen.Color := ScaleColor(FAccentColor, 45, 100);
  SavedDC := SaveDC(Canvas.Handle);
  try
    IntersectClipRect(Canvas.Handle, PlotLeft + 1,
      PlotTop + SectionHeight + SectionGap + 1, PlotRight, PlotBottom);
    Canvas.Polyline(DifferencePoints);
  finally
    RestoreDC(Canvas.Handle, SavedDC);
  end;

  DrawBackedText(PlotLeft + 4, PlotTop, 'Input', NOISE_GRAPH_INPUT);
  DrawBackedText(PlotLeft + 4, PlotTop + Canvas.TextHeight('0'),
    'Output', NOISE_GRAPH_OUTPUT);
  DrawBackedText(PlotRight - Canvas.TextWidth(ScaleText(InputOutputPeak)) - 4,
    PlotTop, ScaleText(InputOutputPeak),
    ScaleColor(NOISE_GRAPH_TEXT, 72, 100));
  DrawBackedText(PlotLeft + 4, PlotTop + SectionHeight + SectionGap,
    'Difference (Output - Input)', FAccentColor);
  DrawBackedText(PlotRight - Canvas.TextWidth(ScaleText(DifferencePeak)) - 4,
    PlotTop + SectionHeight + SectionGap, ScaleText(DifferencePeak),
    ScaleColor(NOISE_GRAPH_TEXT, 72, 100));
end;

end.
