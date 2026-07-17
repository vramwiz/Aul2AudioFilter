unit Aul2AudioControllerMuffleGraph;

// ControllerのMuffle画面へ、設定特性と処理前後スペクトルを重ねて表示する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  Aul2AudioMonitorSpectrumShared;

type
  TAul2ControllerMuffleGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FAmount: Double;
    FCutoffHz: Double;
    FMix: Double;
    FSpectrumValid: Boolean;
    FBandCount: Integer;
    FMinHz: Single;
    FMaxHz: Single;
    FInputBands: TAudioMonitorSpectrumData;
    FOutputBands: TAudioMonitorSpectrumData;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSpectrum;
    procedure SetMuffle(CutoffHz, Amount, Mix: Double; Active: Boolean);
    procedure SetSpectrum(const InputBands, OutputBands: TAudioMonitorSpectrumData;
      BandCount: Integer; MinHz, MaxHz: Single);
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
  MUFFLE_GRAPH_BACKGROUND = TColor($0013100E); // RGB(14, 16, 19)
  MUFFLE_GRAPH_BORDER     = TColor($00312C28); // RGB(40, 44, 49)
  MUFFLE_GRAPH_GRID       = TColor($002B2723); // RGB(35, 39, 43)
  MUFFLE_GRAPH_AXIS       = TColor($00645E58); // RGB(88, 94, 100)
  MUFFLE_GRAPH_TEXT       = TColor($00F2F0EE); // RGB(238, 240, 242)
  MUFFLE_GRAPH_INPUT      = TColor($007ABE5C); // RGB(92, 190, 122)
  MUFFLE_GRAPH_OUTPUT     = TColor($0048B0E0); // RGB(224, 176, 72)
  MUFFLE_VIEW_MIN_HZ      = 20.0;
  MUFFLE_VIEW_MAX_HZ      = 20000.0;
  MUFFLE_SAMPLE_RATE      = 44100.0;

function ScaleColor(Color: TColor; Numerator, Denominator: Integer): TColor;
var
  Blue: Integer;
  Green: Integer;
  Red: Integer;
begin
  Color := ColorToRGB(Color);
  Red := EnsureRange(GetRValue(Color) * Numerator div Denominator, 0, 255);
  Green := EnsureRange(GetGValue(Color) * Numerator div Denominator, 0, 255);
  Blue := EnsureRange(GetBValue(Color) * Numerator div Denominator, 0, 255);
  Result := RGB(Red, Green, Blue);
end;

constructor TAul2ControllerMuffleGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := MUFFLE_GRAPH_BACKGROUND;
  FAccentColor := RGB(242, 242, 242);
  FActive := True;
  FCutoffHz := 1200;
  FAmount := 0.8;
  FMix := 1;
  ClearSpectrum;
end;

procedure TAul2ControllerMuffleGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerMuffleGraph.ClearSpectrum;
begin
  FSpectrumValid := False;
  FBandCount := 0;
  FMinHz := MUFFLE_VIEW_MIN_HZ;
  FMaxHz := MUFFLE_VIEW_MAX_HZ;
  FillChar(FInputBands, SizeOf(FInputBands), 0);
  FillChar(FOutputBands, SizeOf(FOutputBands), 0);
  Invalidate;
end;

procedure TAul2ControllerMuffleGraph.SetMuffle(CutoffHz, Amount, Mix: Double;
  Active: Boolean);
begin
  FCutoffHz := EnsureRange(CutoffHz, 80.0, 8000.0);
  FAmount := EnsureRange(Amount, 0.0, 1.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerMuffleGraph.SetSpectrum(const InputBands,
  OutputBands: TAudioMonitorSpectrumData; BandCount: Integer;
  MinHz, MaxHz: Single);
begin
  FInputBands := InputBands;
  FOutputBands := OutputBands;
  FBandCount := EnsureRange(BandCount, 1, AUDIO_MONITOR_SPECTRUM_BAND_COUNT);
  FMinHz := Max(MUFFLE_VIEW_MIN_HZ, MinHz);
  FMaxHz := Max(FMinHz + 1, MaxHz);
  FSpectrumValid := True;
  Invalidate;
end;

procedure TAul2ControllerMuffleGraph.Paint;
const
  FREQUENCY_GRID: array[0..3] of Double = (100, 1000, 5000, 10000);
var
  AccentColor: TColor;
  Alpha: Double;
  Band: Integer;
  CurvePoints: array of TPoint;
  DenImag: Double;
  DenReal: Double;
  DryWeight: Double;
  Frequency: Double;
  GridIndex: Integer;
  GridX: Integer;
  HeaderText: string;
  InputPoints: array of TPoint;
  LogMax: Double;
  LogMin: Double;
  Magnitude: Double;
  OutputPoints: array of TPoint;
  Phase: Double;
  PlotBottom: Integer;
  PlotHeight: Integer;
  PlotLeft: Integer;
  PlotRight: Integer;
  PlotTop: Integer;
  PlotWidth: Integer;
  PointIndex: Integer;
  PoleImag: Double;
  PoleReal: Double;
  TextHeight: Integer;
  WetImag: Double;
  WetReal: Double;

  function FrequencyToX(Value: Double): Integer;
  begin
    Value := EnsureRange(Value, MUFFLE_VIEW_MIN_HZ, MUFFLE_VIEW_MAX_HZ);
    Result := PlotLeft + Round((Ln(Value) - LogMin) /
      (LogMax - LogMin) * PlotWidth);
  end;

  function SpectrumBandToX(Index: Integer): Integer;
  var
    BandFrequency: Double;
  begin
    if FBandCount <= 1 then
      Exit(PlotLeft);
    BandFrequency := Exp(Ln(Max(MUFFLE_VIEW_MIN_HZ, FMinHz)) +
      Index / (FBandCount - 1) *
      (Ln(Min(MUFFLE_VIEW_MAX_HZ, FMaxHz)) -
       Ln(Max(MUFFLE_VIEW_MIN_HZ, FMinHz))));
    Result := FrequencyToX(BandFrequency);
  end;

  function SpectrumToY(Value: Single): Integer;
  begin
    Result := PlotBottom - Round(EnsureRange(Value, 0.0, 1.0) * PlotHeight);
  end;

begin
  inherited;
  Canvas.Brush.Color := MUFFLE_GRAPH_BACKGROUND;
  Canvas.FillRect(ClientRect);
  if (ClientWidth <= 40) or (ClientHeight <= 40) then
    Exit;

  Canvas.Font.Assign(Font);
  Canvas.Font.Height := -MulDiv(9, Max(96, CurrentPPI), 72);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := MUFFLE_GRAPH_TEXT;
  TextHeight := Canvas.TextHeight('0');
  PlotLeft := MulDiv(35, Max(96, CurrentPPI), 96);
  PlotRight := ClientWidth - MulDiv(10, Max(96, CurrentPPI), 96);
  PlotTop := MulDiv(32, Max(96, CurrentPPI), 96);
  PlotBottom := ClientHeight - MulDiv(24, Max(96, CurrentPPI), 96);
  PlotWidth := Max(1, PlotRight - PlotLeft);
  PlotHeight := Max(1, PlotBottom - PlotTop);
  LogMin := Ln(MUFFLE_VIEW_MIN_HZ);
  LogMax := Ln(MUFFLE_VIEW_MAX_HZ);

  AccentColor := FAccentColor;
  if not FActive then
    AccentColor := ScaleColor(AccentColor, 45, 100);
  HeaderText := Format('Cutoff %.0fHz  Amount %.2f  Mix %.2f',
    [FCutoffHz, FAmount, FMix]);
  Canvas.TextOut(PlotLeft, MulDiv(6, Max(96, CurrentPPI), 96), HeaderText);

  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := MUFFLE_GRAPH_GRID;
  for GridIndex := 0 to High(FREQUENCY_GRID) do
  begin
    GridX := FrequencyToX(FREQUENCY_GRID[GridIndex]);
    Canvas.MoveTo(GridX, PlotTop);
    Canvas.LineTo(GridX, PlotBottom);
  end;
  for GridIndex := 0 to 2 do
  begin
    Canvas.MoveTo(PlotLeft, PlotTop + PlotHeight * GridIndex div 2);
    Canvas.LineTo(PlotRight, PlotTop + PlotHeight * GridIndex div 2);
  end;
  Canvas.Pen.Color := MUFFLE_GRAPH_AXIS;
  Canvas.MoveTo(PlotLeft, PlotTop);
  Canvas.LineTo(PlotLeft, PlotBottom);
  Canvas.LineTo(PlotRight, PlotBottom);

  Canvas.Font.Color := ScaleColor(MUFFLE_GRAPH_TEXT, 65, 100);
  Canvas.TextOut(PlotLeft - Canvas.TextWidth('100') - 4,
    PlotTop - TextHeight div 2, '100');
  Canvas.TextOut(PlotLeft - Canvas.TextWidth('0') - 4,
    PlotBottom - TextHeight div 2, '0');
  for GridIndex := 0 to High(FREQUENCY_GRID) do
  begin
    if FREQUENCY_GRID[GridIndex] >= 1000 then
      HeaderText := FormatFloat('0.#k', FREQUENCY_GRID[GridIndex] / 1000)
    else
      HeaderText := FormatFloat('0', FREQUENCY_GRID[GridIndex]);
    GridX := FrequencyToX(FREQUENCY_GRID[GridIndex]);
    Canvas.TextOut(EnsureRange(GridX - Canvas.TextWidth(HeaderText) div 2,
      PlotLeft, PlotRight - Canvas.TextWidth(HeaderText)), PlotBottom + 3,
      HeaderText);
  end;

  if FSpectrumValid and (FBandCount > 1) then
  begin
    SetLength(InputPoints, FBandCount);
    SetLength(OutputPoints, FBandCount);
    for Band := 0 to FBandCount - 1 do
    begin
      InputPoints[Band] := Point(SpectrumBandToX(Band),
        SpectrumToY(FInputBands[Band]));
      OutputPoints[Band] := Point(SpectrumBandToX(Band),
        SpectrumToY(FOutputBands[Band]));
    end;
    Canvas.Pen.Width := 1;
    Canvas.Pen.Color := ScaleColor(MUFFLE_GRAPH_INPUT, 70, 100);
    Canvas.Polyline(InputPoints);
    Canvas.Pen.Color := ScaleColor(MUFFLE_GRAPH_OUTPUT, 78, 100);
    Canvas.Polyline(OutputPoints);
  end;

  SetLength(CurvePoints, PlotWidth + 1);
  Alpha := 1.0 - Exp(-2.0 * Pi * FCutoffHz / MUFFLE_SAMPLE_RATE);
  DryWeight := 1.0 - (FMix * FAmount);
  for PointIndex := 0 to PlotWidth do
  begin
    Frequency := Exp(LogMin + PointIndex / PlotWidth * (LogMax - LogMin));
    Phase := 2.0 * Pi * Frequency / MUFFLE_SAMPLE_RATE;
    DenReal := 1.0 - ((1.0 - Alpha) * Cos(Phase));
    DenImag := (1.0 - Alpha) * Sin(Phase);
    Magnitude := Sqr(DenReal) + Sqr(DenImag);
    if Magnitude <= 0.0000001 then
    begin
      PoleReal := 1;
      PoleImag := 0;
    end
    else
    begin
      PoleReal := Alpha * DenReal / Magnitude;
      PoleImag := -Alpha * DenImag / Magnitude;
    end;
    WetReal := (PoleReal * PoleReal) - (PoleImag * PoleImag);
    WetImag := 2.0 * PoleReal * PoleImag;
    WetReal := DryWeight + (FMix * FAmount * WetReal);
    WetImag := FMix * FAmount * WetImag;
    Magnitude := EnsureRange(Sqrt(Sqr(WetReal) + Sqr(WetImag)), 0.0, 1.0);
    CurvePoints[PointIndex] := Point(PlotLeft + PointIndex,
      PlotBottom - Round(Magnitude * PlotHeight));
  end;
  Canvas.Pen.Color := AccentColor;
  Canvas.Pen.Width := Max(2, MulDiv(3, Max(96, CurrentPPI), 96));
  Canvas.Polyline(CurvePoints);

  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := AccentColor;
  GridX := FrequencyToX(FCutoffHz);
  Canvas.MoveTo(GridX, PlotTop);
  Canvas.LineTo(GridX, PlotBottom);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := MUFFLE_GRAPH_INPUT;
  Canvas.TextOut(PlotRight - Canvas.TextWidth('Input / Output') - 2,
    PlotTop + 2, 'Input');
  Canvas.Font.Color := MUFFLE_GRAPH_OUTPUT;
  Canvas.TextOut(PlotRight - Canvas.TextWidth('Output') - 2,
    PlotTop + TextHeight + 2, 'Output');
end;

end.
