unit Aul2AudioControllerRingModGraph;

// ControllerのRingMod画面へ、処理前後スペクトルと予測側波帯を表示する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  Aul2AudioRingModSpectrumShared;

type
  TAul2ControllerRingModGraph = class(TCustomControl)
  private
    FActive: Boolean;
    FFrequency: Double;
    FDepth: Double;
    FMix: Double;
    FValid: Boolean;
    FBandCount: Integer;
    FMinHz: Single;
    FMaxHz: Single;
    FInputBands: TAudioRingSpectrumData;
    FOutputBands: TAudioRingSpectrumData;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSpectrum;
    procedure SetRingMod(Frequency, Depth, Mix: Double; Active: Boolean);
    procedure SetSpectrum(const InputBands, OutputBands: TAudioRingSpectrumData;
      BandCount: Integer; MinHz, MaxHz: Single);
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
  GRAPH_BACKGROUND = TColor($0013100E);
  GRAPH_GRID = TColor($002B2723);
  GRAPH_AXIS = TColor($00645E58);
  GRAPH_TEXT = TColor($00F2F0EE);
  GRAPH_INPUT = TColor($007ABE5C);
  GRAPH_OUTPUT = TColor($0048B0E0);
  GRAPH_SIDEBAND_LOW = TColor($00705E93);
  GRAPH_SIDEBAND_HIGH = TColor($00806F55);

constructor TAul2ControllerRingModGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := GRAPH_BACKGROUND;
  FActive := True;
  ClearSpectrum;
end;

procedure TAul2ControllerRingModGraph.ClearSpectrum;
begin
  FValid := False;
  FBandCount := 0;
  FillChar(FInputBands, SizeOf(FInputBands), 0);
  FillChar(FOutputBands, SizeOf(FOutputBands), 0);
  Invalidate;
end;

procedure TAul2ControllerRingModGraph.SetRingMod(Frequency, Depth, Mix: Double;
  Active: Boolean);
begin
  FFrequency := EnsureRange(Frequency, 1.0, 2000.0);
  FDepth := EnsureRange(Depth, 0.0, 1.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerRingModGraph.SetSpectrum(const InputBands,
  OutputBands: TAudioRingSpectrumData; BandCount: Integer; MinHz, MaxHz: Single);
begin
  FInputBands := InputBands;
  FOutputBands := OutputBands;
  FBandCount := EnsureRange(BandCount, 1, AUDIO_RING_SPECTRUM_BAND_COUNT);
  FMinHz := Max(20.0, MinHz);
  FMaxHz := Max(FMinHz + 1, MaxHz);
  FValid := True;
  Invalidate;
end;

procedure TAul2ControllerRingModGraph.Paint;
const
  GRID_HZ: array[0..4] of Double = (100, 500, 1000, 5000, 10000);
var
  Band, GridIndex, PlotBottom, PlotHeight, PlotLeft, PlotRight, PlotTop,
    PlotWidth, TextHeight, X, Y: Integer;
  Frequency, LogMax, LogMin: Double;
  LabelText: string;
  InputPoints, OutputPoints, LowerPoints, UpperPoints: array of TPoint;

  function FrequencyToX(Value: Double): Integer;
  begin
    Value := EnsureRange(Value, FMinHz, FMaxHz);
    Result := PlotLeft + Round((Ln(Value) - LogMin) /
      (LogMax - LogMin) * PlotWidth);
  end;

  function BandFrequency(Index: Integer): Double;
  begin
    Result := FMinHz * Power(FMaxHz / FMinHz,
      (Index + 0.5) / Max(1, FBandCount));
  end;

  function BandToY(Value: Single): Integer;
  begin
    Result := PlotBottom - Round(EnsureRange(Value, 0.0, 1.0) * PlotHeight);
  end;

  function SampleInput(ValueHz: Double): Single;
  var
    Fraction, Position: Double;
    Index, NextIndex: Integer;
  begin
    if (ValueHz < FMinHz) or (ValueHz > FMaxHz) or (FBandCount < 1) then
      Exit(0);
    Position := Ln(ValueHz / FMinHz) / Ln(FMaxHz / FMinHz) * FBandCount - 0.5;
    Index := EnsureRange(Floor(Position), 0, FBandCount - 1);
    NextIndex := Min(FBandCount - 1, Index + 1);
    Fraction := EnsureRange(Position - Index, 0.0, 1.0);
    Result := FInputBands[Index] * (1.0 - Fraction) +
      FInputBands[NextIndex] * Fraction;
  end;

begin
  inherited;
  Canvas.Brush.Color := GRAPH_BACKGROUND;
  Canvas.FillRect(ClientRect);
  if (ClientWidth < 50) or (ClientHeight < 50) then Exit;
  Canvas.Font.Assign(Font);
  Canvas.Font.Height := -MulDiv(9, Max(96, CurrentPPI), 72);
  Canvas.Brush.Style := bsClear;
  TextHeight := Canvas.TextHeight('0');
  PlotLeft := MulDiv(35, Max(96, CurrentPPI), 96);
  PlotRight := ClientWidth - MulDiv(10, Max(96, CurrentPPI), 96);
  PlotTop := MulDiv(32, Max(96, CurrentPPI), 96);
  PlotBottom := ClientHeight - MulDiv(24, Max(96, CurrentPPI), 96);
  PlotWidth := Max(1, PlotRight - PlotLeft);
  PlotHeight := Max(1, PlotBottom - PlotTop);
  LogMin := Ln(FMinHz);
  LogMax := Ln(FMaxHz);

  LabelText := Format('Frequency %.0fHz  Depth %.2f  Mix %.2f',
    [FFrequency, FDepth, FMix]);
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(PlotLeft, MulDiv(6, Max(96, CurrentPPI), 96), LabelText);
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := GRAPH_GRID;
  for GridIndex := 0 to High(GRID_HZ) do
  begin
    X := FrequencyToX(GRID_HZ[GridIndex]);
    Canvas.MoveTo(X, PlotTop); Canvas.LineTo(X, PlotBottom);
  end;
  for GridIndex := 0 to 2 do
  begin
    Y := PlotTop + PlotHeight * GridIndex div 2;
    Canvas.MoveTo(PlotLeft, Y); Canvas.LineTo(PlotRight, Y);
  end;
  Canvas.Pen.Color := GRAPH_AXIS;
  Canvas.MoveTo(PlotLeft, PlotTop); Canvas.LineTo(PlotLeft, PlotBottom);
  Canvas.LineTo(PlotRight, PlotBottom);
  Canvas.Font.Color := RGB(155, 155, 155);
  Canvas.TextOut(PlotLeft - Canvas.TextWidth('100') - 4,
    PlotTop - TextHeight div 2, '100');
  Canvas.TextOut(PlotLeft - Canvas.TextWidth('0') - 4,
    PlotBottom - TextHeight div 2, '0');
  for GridIndex := 0 to High(GRID_HZ) do
  begin
    if GRID_HZ[GridIndex] >= 1000 then
      LabelText := FormatFloat('0.#k', GRID_HZ[GridIndex] / 1000)
    else LabelText := FormatFloat('0', GRID_HZ[GridIndex]);
    X := FrequencyToX(GRID_HZ[GridIndex]);
    Canvas.TextOut(EnsureRange(X - Canvas.TextWidth(LabelText) div 2,
      PlotLeft, PlotRight - Canvas.TextWidth(LabelText)), PlotBottom + 3, LabelText);
  end;

  if FValid and (FBandCount > 1) then
  begin
    SetLength(InputPoints, FBandCount); SetLength(OutputPoints, FBandCount);
    SetLength(LowerPoints, FBandCount); SetLength(UpperPoints, FBandCount);
    for Band := 0 to FBandCount - 1 do
    begin
      Frequency := BandFrequency(Band);
      X := FrequencyToX(Frequency);
      InputPoints[Band] := Point(X, BandToY(FInputBands[Band]));
      OutputPoints[Band] := Point(X, BandToY(FOutputBands[Band]));
      LowerPoints[Band] := Point(X, BandToY(SampleInput(Frequency + FFrequency)));
      if Frequency > FFrequency + FMinHz then
        UpperPoints[Band] := Point(X, BandToY(SampleInput(Frequency - FFrequency)))
      else
        UpperPoints[Band] := Point(X, PlotBottom);
    end;
    Canvas.Pen.Width := 1;
    Canvas.Pen.Color := GRAPH_SIDEBAND_LOW; Canvas.Polyline(LowerPoints);
    Canvas.Pen.Color := GRAPH_SIDEBAND_HIGH; Canvas.Polyline(UpperPoints);
    Canvas.Pen.Color := GRAPH_INPUT;
    if not FActive then Canvas.Pen.Color := RGB(55, 100, 70);
    Canvas.Polyline(InputPoints);
    Canvas.Pen.Width := 2; Canvas.Pen.Color := GRAPH_OUTPUT;
    if not FActive then Canvas.Pen.Color := RGB(105, 85, 45);
    Canvas.Polyline(OutputPoints);
  end;
  Canvas.Font.Color := GRAPH_INPUT;
  Canvas.TextOut(PlotRight - Canvas.TextWidth('Input') - 2, PlotTop + 2, 'Input');
  Canvas.Font.Color := GRAPH_OUTPUT;
  Canvas.TextOut(PlotRight - Canvas.TextWidth('Output') - 2,
    PlotTop + TextHeight + 2, 'Output');
  Canvas.Font.Color := GRAPH_SIDEBAND_HIGH;
  Canvas.TextOut(PlotLeft + 3, PlotTop + 2, 'Sidebands +/-F');
end;

end.
