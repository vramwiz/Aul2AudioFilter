unit Aul2AudioControllerPitchGraph;

// ControllerのPitch画面へ、処理直前・直後の高解像度スペクトルを表示する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  Aul2AudioPitchSpectrumShared;

type
  TAul2ControllerPitchGraph = class(TCustomControl)
  private
    FActive: Boolean;
    FMode: Integer;
    FSemitone: Double;
    FFormant: Double;
    FStepSemi: Double;
    FMix: Double;
    FValid: Boolean;
    FBandCount: Integer;
    FMinHz: Single;
    FMaxHz: Single;
    FInputBands: TAudioPitchSpectrumData;
    FOutputBands: TAudioPitchSpectrumData;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSpectrum;
    procedure SetPitch(Mode: Integer; Semitone, Formant, StepSemi, Mix: Double;
      Active: Boolean);
    procedure SetSpectrum(const InputBands, OutputBands: TAudioPitchSpectrumData;
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
  PITCH_GRAPH_BACKGROUND = TColor($0013100E);
  PITCH_GRAPH_BORDER = TColor($00312C28);
  PITCH_GRAPH_GRID = TColor($002B2723);
  PITCH_GRAPH_AXIS = TColor($00645E58);
  PITCH_GRAPH_TEXT = TColor($00F2F0EE);
  PITCH_GRAPH_INPUT = TColor($007ABE5C);
  PITCH_GRAPH_OUTPUT = TColor($0048B0E0);

constructor TAul2ControllerPitchGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := PITCH_GRAPH_BACKGROUND;
  FActive := True;
  ClearSpectrum;
end;

procedure TAul2ControllerPitchGraph.ClearSpectrum;
begin
  FValid := False;
  FBandCount := 0;
  FillChar(FInputBands, SizeOf(FInputBands), 0);
  FillChar(FOutputBands, SizeOf(FOutputBands), 0);
  Invalidate;
end;

procedure TAul2ControllerPitchGraph.SetPitch(Mode: Integer; Semitone, Formant,
  StepSemi, Mix: Double; Active: Boolean);
begin
  FMode := EnsureRange(Mode, 0, 3);
  FSemitone := EnsureRange(Semitone, -12.0, 12.0);
  FFormant := EnsureRange(Formant, -12.0, 12.0);
  FStepSemi := EnsureRange(StepSemi, 0.0, 12.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerPitchGraph.SetSpectrum(const InputBands,
  OutputBands: TAudioPitchSpectrumData; BandCount: Integer;
  MinHz, MaxHz: Single);
begin
  FInputBands := InputBands;
  FOutputBands := OutputBands;
  FBandCount := EnsureRange(BandCount, 1, AUDIO_PITCH_SPECTRUM_BAND_COUNT);
  FMinHz := Max(20.0, MinHz);
  FMaxHz := Max(FMinHz + 1, MaxHz);
  FValid := True;
  Invalidate;
end;

procedure TAul2ControllerPitchGraph.Paint;
const
  GRID_HZ: array[0..4] of Double = (100, 500, 1000, 5000, 10000);
  MODE_NAMES: array[0..3] of string = ('Natural', 'Pitch Only',
    'Formant Only', 'Step');
var
  Band: Integer;
  Frequency: Double;
  GridIndex: Integer;
  Header: string;
  InputPoints: array of TPoint;
  LogMax: Double;
  LogMin: Double;
  OutputPoints: array of TPoint;
  PlotBottom: Integer;
  PlotHeight: Integer;
  PlotLeft: Integer;
  PlotRight: Integer;
  PlotTop: Integer;
  PlotWidth: Integer;
  TextHeight: Integer;
  X: Integer;
  Y: Integer;

  function FrequencyToX(Value: Double): Integer;
  begin
    Value := EnsureRange(Value, FMinHz, FMaxHz);
    Result := PlotLeft + Round((Ln(Value) - LogMin) /
      (LogMax - LogMin) * PlotWidth);
  end;

  function BandToX(Index: Integer): Integer;
  begin
    Frequency := FMinHz * Power(FMaxHz / FMinHz,
      (Index + 0.5) / Max(1, FBandCount));
    Result := FrequencyToX(Frequency);
  end;

  function BandToY(Value: Single): Integer;
  begin
    Result := PlotBottom - Round(EnsureRange(Value, 0.0, 1.0) * PlotHeight);
  end;

begin
  inherited;
  Canvas.Brush.Color := PITCH_GRAPH_BACKGROUND;
  Canvas.FillRect(ClientRect);
  if (ClientWidth < 50) or (ClientHeight < 50) then
    Exit;
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
  LogMin := Ln(Max(20.0, FMinHz));
  LogMax := Ln(Max(FMinHz + 1, FMaxHz));

  case FMode of
    2: Header := Format('%s  Formant %s  Mix %.2f',
      [MODE_NAMES[FMode], FormatFloat('+0.0;-0.0;0.0', FFormant), FMix]);
    3: Header := Format('%s  ±%.1f semi  Mix %.2f',
      [MODE_NAMES[FMode], FStepSemi, FMix]);
  else
    Header := Format('%s  Pitch %s semi  Mix %.2f',
      [MODE_NAMES[FMode], FormatFloat('+0.0;-0.0;0.0', FSemitone), FMix]);
  end;
  Canvas.Font.Color := PITCH_GRAPH_TEXT;
  Canvas.TextOut(PlotLeft, MulDiv(6, Max(96, CurrentPPI), 96), Header);

  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := PITCH_GRAPH_GRID;
  for GridIndex := 0 to High(GRID_HZ) do
  begin
    X := FrequencyToX(GRID_HZ[GridIndex]);
    Canvas.MoveTo(X, PlotTop);
    Canvas.LineTo(X, PlotBottom);
  end;
  for GridIndex := 0 to 2 do
  begin
    Y := PlotTop + PlotHeight * GridIndex div 2;
    Canvas.MoveTo(PlotLeft, Y);
    Canvas.LineTo(PlotRight, Y);
  end;
  Canvas.Pen.Color := PITCH_GRAPH_AXIS;
  Canvas.MoveTo(PlotLeft, PlotTop);
  Canvas.LineTo(PlotLeft, PlotBottom);
  Canvas.LineTo(PlotRight, PlotBottom);
  Canvas.Font.Color := RGB(155, 155, 155);
  Canvas.TextOut(PlotLeft - Canvas.TextWidth('100') - 4,
    PlotTop - TextHeight div 2, '100');
  Canvas.TextOut(PlotLeft - Canvas.TextWidth('0') - 4,
    PlotBottom - TextHeight div 2, '0');
  for GridIndex := 0 to High(GRID_HZ) do
  begin
    if GRID_HZ[GridIndex] >= 1000 then
      Header := FormatFloat('0.#k', GRID_HZ[GridIndex] / 1000)
    else
      Header := FormatFloat('0', GRID_HZ[GridIndex]);
    X := FrequencyToX(GRID_HZ[GridIndex]);
    Canvas.TextOut(EnsureRange(X - Canvas.TextWidth(Header) div 2,
      PlotLeft, PlotRight - Canvas.TextWidth(Header)), PlotBottom + 3, Header);
  end;

  if FValid and (FBandCount > 1) then
  begin
    SetLength(InputPoints, FBandCount);
    SetLength(OutputPoints, FBandCount);
    for Band := 0 to FBandCount - 1 do
    begin
      InputPoints[Band] := Point(BandToX(Band), BandToY(FInputBands[Band]));
      OutputPoints[Band] := Point(BandToX(Band), BandToY(FOutputBands[Band]));
    end;
    Canvas.Pen.Width := 1;
    Canvas.Pen.Color := PITCH_GRAPH_INPUT;
    if not FActive then
      Canvas.Pen.Color := RGB(55, 100, 70);
    Canvas.Polyline(InputPoints);
    Canvas.Pen.Width := 2;
    Canvas.Pen.Color := PITCH_GRAPH_OUTPUT;
    if not FActive then
      Canvas.Pen.Color := RGB(105, 85, 45);
    Canvas.Polyline(OutputPoints);
  end;

  Canvas.Font.Color := PITCH_GRAPH_INPUT;
  Canvas.TextOut(PlotRight - Canvas.TextWidth('Input') - 2, PlotTop + 2, 'Input');
  Canvas.Font.Color := PITCH_GRAPH_OUTPUT;
  Canvas.TextOut(PlotRight - Canvas.TextWidth('Output') - 2,
    PlotTop + TextHeight + 2, 'Output');
end;

end.
