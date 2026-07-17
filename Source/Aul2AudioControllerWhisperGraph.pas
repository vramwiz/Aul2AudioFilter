unit Aul2AudioControllerWhisperGraph;

// 参考スペクトルへ、Whisper設定から求めた息成分の予測特性を重ねる。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  Aul2AudioMonitorSpectrumShared;

type
  TAul2ControllerWhisperGraph = class(TCustomControl)
  private
    FActive, FValid: Boolean;
    FLevelDb, FTone, FMix: Double;
    FBandCount: Integer;
    FMinHz, FMaxHz: Single;
    FReferenceBands: TAudioMonitorSpectrumData;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSpectrum;
    procedure SetWhisper(LevelDb, Tone, Mix: Double; Active: Boolean);
    procedure SetSpectrum(const ReferenceBands: TAudioMonitorSpectrumData;
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
  GRAPH_REFERENCE = TColor($007ABE5C);
  GRAPH_BREATH_ON = TColor($009A7048);
  GRAPH_BREATH_OFF = TColor($0049362A);

constructor TAul2ControllerWhisperGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := GRAPH_BACKGROUND;
  FActive := True;
  FMinHz := 20;
  FMaxHz := 20000;
  ClearSpectrum;
end;

procedure TAul2ControllerWhisperGraph.ClearSpectrum;
begin
  FValid := False;
  FBandCount := 0;
  FillChar(FReferenceBands, SizeOf(FReferenceBands), 0);
  Invalidate;
end;

procedure TAul2ControllerWhisperGraph.SetWhisper(LevelDb, Tone, Mix: Double;
  Active: Boolean);
begin
  FLevelDb := EnsureRange(LevelDb, -48.0, 0.0);
  FTone := EnsureRange(Tone, 0.0, 1.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerWhisperGraph.SetSpectrum(
  const ReferenceBands: TAudioMonitorSpectrumData; BandCount: Integer;
  MinHz, MaxHz: Single);
begin
  FReferenceBands := ReferenceBands;
  FBandCount := EnsureRange(BandCount, 1, AUDIO_MONITOR_SPECTRUM_BAND_COUNT);
  FMinHz := Max(20.0, MinHz);
  FMaxHz := Max(FMinHz + 1, MaxHz);
  FValid := True;
  Invalidate;
end;

procedure TAul2ControllerWhisperGraph.Paint;
const
  GRID_HZ: array[0..4] of Double = (100, 500, 1000, 5000, 10000);
var
  Band, GridIndex, PlotBottom, PlotHeight, PlotLeft, PlotRight, PlotTop,
    PlotWidth, TextHeight, X, Y: Integer;
  BreathStrength, CutoffHz, Frequency, HighPassShape, LevelPosition,
    LogMax, LogMin: Double;
  LabelText: string;
  BreathColor: TColor;
  BreathPoints, ReferencePoints: array of TPoint;

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

  function BandToY(Value: Double): Integer;
  begin
    Result := PlotBottom - Round(EnsureRange(Value, 0.0, 1.0) * PlotHeight);
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

  LabelText := Format('Level %.1fdB  Tone %.2f  Mix %.2f',
    [FLevelDb, FTone, FMix]);
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(PlotLeft, 6, LabelText);
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := GRAPH_GRID;
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
  Canvas.Pen.Color := GRAPH_AXIS;
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
      LabelText := FormatFloat('0.#k', GRID_HZ[GridIndex] / 1000)
    else
      LabelText := FormatFloat('0', GRID_HZ[GridIndex]);
    X := FrequencyToX(GRID_HZ[GridIndex]);
    Canvas.TextOut(EnsureRange(X - Canvas.TextWidth(LabelText) div 2,
      PlotLeft, PlotRight - Canvas.TextWidth(LabelText)),
      PlotBottom + 3, LabelText);
  end;

  if FValid and (FBandCount > 1) then
  begin
    SetLength(ReferencePoints, FBandCount);
    SetLength(BreathPoints, FBandCount + 2);
    BreathPoints[0] := Point(FrequencyToX(BandFrequency(0)), PlotBottom);
    CutoffHz := 900.0 + FTone * 4200.0;
    LevelPosition := EnsureRange((FLevelDb + 48.0) / 48.0, 0.0, 1.0);
    // 実振幅の厳密値ではなく、小型Controllerで設定差を読める表示強度にする。
    BreathStrength := FMix * (0.12 + 0.78 * LevelPosition);
    for Band := 0 to FBandCount - 1 do
    begin
      Frequency := BandFrequency(Band);
      X := FrequencyToX(Frequency);
      ReferencePoints[Band] := Point(X, BandToY(FReferenceBands[Band]));
      HighPassShape := Frequency / Sqrt(Sqr(Frequency) + Sqr(CutoffHz));
      BreathPoints[Band + 1] := Point(X,
        BandToY(BreathStrength * HighPassShape));
    end;
    BreathPoints[High(BreathPoints)] := Point(
      FrequencyToX(BandFrequency(FBandCount - 1)), PlotBottom);
    Canvas.Brush.Style := bsSolid;
    if FActive then BreathColor := GRAPH_BREATH_ON
    else BreathColor := GRAPH_BREATH_OFF;
    Canvas.Brush.Color := BreathColor;
    Canvas.Pen.Color := BreathColor;
    Canvas.Polygon(BreathPoints);
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Width := 1;
    Canvas.Pen.Color := GRAPH_REFERENCE;
    Canvas.Polyline(ReferencePoints);
  end;

  if FActive then Canvas.Font.Color := GRAPH_BREATH_ON
  else Canvas.Font.Color := GRAPH_BREATH_OFF;
  Canvas.TextOut(PlotLeft + 3, PlotTop + 2, 'Breath');
  Canvas.Font.Color := GRAPH_REFERENCE;
  Canvas.TextOut(PlotRight - Canvas.TextWidth('Reference') - 2,
    PlotTop + 2, 'Reference');
end;

end.
