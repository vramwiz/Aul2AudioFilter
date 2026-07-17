unit Aul2AudioControllerTrembleGraph;

// Tremble処理前後の最新RMSと1周期分の音量変調カーブを描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics;

type
  TAul2ControllerTrembleGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FDataValid: Boolean;
    FDepth: Double;
    FInputRms: Single;
    FLfoPhase: Double;
    FMix: Double;
    FOutputRms: Single;
    FRateHz: Double;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearLevels;
    procedure SetTremble(RateHz, Depth, Mix: Double; Active: Boolean);
    procedure SetLevels(InputRms, OutputRms, LfoPhase: Single);
  published
    property AccentColor: TColor read FAccentColor write SetAccentColor;
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
  GRAPH_BORDER = TColor($00312C28);
  GRAPH_GRID = TColor($002B2723);
  GRAPH_TEXT = TColor($00F2F0EE);
  GRAPH_INPUT = TColor($007ABE5C);
  GRAPH_MIN_DB = -60.0;

function ScaleColor(Color: TColor; Numerator, Denominator: Integer): TColor;
begin
  Color := ColorToRGB(Color);
  Result := RGB(
    EnsureRange(GetRValue(Color) * Numerator div Denominator, 0, 255),
    EnsureRange(GetGValue(Color) * Numerator div Denominator, 0, 255),
    EnsureRange(GetBValue(Color) * Numerator div Denominator, 0, 255));
end;

function LinearToDb(Value: Double; FloorDb: Double): Double;
begin
  if Value <= 0.000001 then
    Exit(FloorDb);
  Result := Max(FloorDb, 20.0 * Log10(Value));
end;

function LevelToDb(Value: Single): Double;
begin
  Result := EnsureRange(LinearToDb(Value, GRAPH_MIN_DB), GRAPH_MIN_DB, 0.0);
end;

constructor TAul2ControllerTrembleGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := GRAPH_BACKGROUND;
  FAccentColor := TColor($0048B0E0);
  FActive := True;
  FRateHz := 8.0;
  FDepth := 0.35;
  FMix := 1.0;
  ClearLevels;
end;

procedure TAul2ControllerTrembleGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerTrembleGraph.ClearLevels;
begin
  FDataValid := False;
  FInputRms := 0;
  FOutputRms := 0;
  FLfoPhase := 0;
  Invalidate;
end;

procedure TAul2ControllerTrembleGraph.SetTremble(RateHz, Depth, Mix: Double;
  Active: Boolean);
begin
  FRateHz := EnsureRange(RateHz, 0.1, 30.0);
  FDepth := EnsureRange(Depth, 0.0, 1.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerTrembleGraph.SetLevels(InputRms, OutputRms,
  LfoPhase: Single);
begin
  FInputRms := Max(0.0, InputRms);
  FOutputRms := Max(0.0, OutputRms);
  FLfoPhase := LfoPhase - Floor(LfoPhase);
  if FLfoPhase < 0 then
    FLfoPhase := FLfoPhase + 1.0;
  FDataValid := True;
  Invalidate;
end;

procedure TAul2ControllerTrembleGraph.Paint;
const
  CURVE_POINT_COUNT = 101;
var
  Accent: TColor;
  BarLeft: Integer;
  BarRight: Integer;
  BarWidth: Integer;
  CurveBottom: Integer;
  CurveDb: Double;
  CurveFloorDb: Double;
  CurveLeft: Integer;
  CurveRight: Integer;
  CurveTop: Integer;
  Db: Integer;
  DeltaDb: Double;
  DetailText: string;
  FontPPI: Integer;
  Gain: Double;
  GainMinimumDb: Double;
  GridX: Integer;
  Index: Integer;
  InputDb: Double;
  Lfo: Double;
  MarkerX: Integer;
  MarkerY: Integer;
  OutputDb: Double;
  Phase: Double;
  Points: array[0..CURVE_POINT_COUNT - 1] of TPoint;
  RateText: string;
  ValueX: Integer;

  function CurveY(ValueDb: Double): Integer;
  begin
    ValueDb := EnsureRange(ValueDb, CurveFloorDb, 0.0);
    Result := CurveTop + Round((-ValueDb / -CurveFloorDb) *
      (CurveBottom - CurveTop));
  end;

  procedure DrawMeter(Top: Integer; const LabelText: string; ValueDb: Double;
    MeterColor: TColor);
  var
    FillRight: Integer;
    MeterRect: TRect;
    ValueText: string;
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 72, 100);
    Canvas.TextOut(MulDiv(8, FontPPI, 96), Top - MulDiv(2, FontPPI, 96),
      LabelText);
    MeterRect := Rect(BarLeft, Top, BarRight, Top + MulDiv(10, FontPPI, 96));
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 130, 100);
    Canvas.FillRect(MeterRect);
    if FDataValid then
    begin
      FillRight := BarLeft + Round((ValueDb - GRAPH_MIN_DB) / -GRAPH_MIN_DB *
        BarWidth);
      Canvas.Brush.Color := MeterColor;
      Canvas.FillRect(Rect(BarLeft, MeterRect.Top, FillRight, MeterRect.Bottom));
      ValueText := FormatFloat('0.0 dB', ValueDb);
    end
    else
      ValueText := '-- dB';
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := GRAPH_TEXT;
    ValueX := BarRight - Canvas.TextWidth(ValueText) - MulDiv(3, FontPPI, 96);
    Canvas.TextOut(ValueX, Top - MulDiv(2, FontPPI, 96), ValueText);
  end;

begin
  inherited;
  Canvas.Brush.Color := GRAPH_BACKGROUND;
  Canvas.FillRect(ClientRect);
  if (ClientWidth <= 40) or (ClientHeight <= 40) then
    Exit;

  FontPPI := Max(96, CurrentPPI);
  Canvas.Font.Assign(Font);
  Canvas.Font.Height := -MulDiv(8, FontPPI, 72);
  Canvas.Brush.Style := bsClear;
  Accent := FAccentColor;
  if not FActive then
    Accent := ScaleColor(Accent, 45, 100);

  Canvas.Pen.Color := GRAPH_BORDER;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(ClientRect);
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96),
    'RMS snapshot');
  RateText := FormatFloat('0.0 Hz', FRateHz);
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 60, 100);
  Canvas.TextOut(ClientWidth - Canvas.TextWidth(RateText) -
    MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96), RateText);

  BarLeft := MulDiv(38, FontPPI, 96);
  BarRight := ClientWidth - MulDiv(9, FontPPI, 96);
  BarWidth := Max(1, BarRight - BarLeft);
  InputDb := LevelToDb(FInputRms);
  OutputDb := LevelToDb(FOutputRms);
  DrawMeter(MulDiv(24, FontPPI, 96), 'In', InputDb, GRAPH_INPUT);
  DrawMeter(MulDiv(40, FontPPI, 96), 'Out', OutputDb, Accent);

  Canvas.Pen.Color := GRAPH_GRID;
  for Db in [-60, -30, 0] do
  begin
    GridX := BarLeft + Round((Db - GRAPH_MIN_DB) / -GRAPH_MIN_DB * BarWidth);
    Canvas.MoveTo(GridX, MulDiv(22, FontPPI, 96));
    Canvas.LineTo(GridX, MulDiv(51, FontPPI, 96));
    Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 45, 100);
    Canvas.TextOut(GridX - Canvas.TextWidth(IntToStr(Db)) div 2,
      MulDiv(51, FontPPI, 96), IntToStr(Db));
  end;

  GainMinimumDb := LinearToDb(1.0 - FDepth * FMix, -120.0);
  if FDataValid then
    DeltaDb := OutputDb - InputDb
  else
    DeltaDb := 0;
  if FDataValid then
    DetailText := Format('Delta %s dB   range %s..0 dB',
      [FormatFloat('0.0', DeltaDb), FormatFloat('0.0', GainMinimumDb)])
  else
    DetailText := Format('range %s..0 dB', [FormatFloat('0.0', GainMinimumDb)]);
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 68, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(65, FontPPI, 96), DetailText);

  CurveLeft := MulDiv(38, FontPPI, 96);
  CurveRight := ClientWidth - MulDiv(9, FontPPI, 96);
  CurveTop := MulDiv(82, FontPPI, 96);
  CurveBottom := ClientHeight - MulDiv(8, FontPPI, 96);
  CurveFloorDb := Min(-6.0, Max(-36.0, GainMinimumDb));
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 118, 100);
  Canvas.FillRect(Rect(CurveLeft, CurveTop, CurveRight, CurveBottom));
  Canvas.Pen.Color := GRAPH_GRID;
  Canvas.MoveTo(CurveLeft, CurveY(CurveFloorDb * 0.5));
  Canvas.LineTo(CurveRight, CurveY(CurveFloorDb * 0.5));
  Canvas.Pen.Color := ScaleColor(GRAPH_INPUT, 70, 100);
  Canvas.MoveTo(CurveLeft, CurveTop);
  Canvas.LineTo(CurveRight, CurveTop);

  for Index := 0 to CURVE_POINT_COUNT - 1 do
  begin
    Phase := Index / (CURVE_POINT_COUNT - 1);
    Lfo := 0.5 + 0.5 * Sin(2.0 * Pi * Phase);
    Gain := Max(0.000001, 1.0 - FDepth * FMix * Lfo);
    CurveDb := LinearToDb(Gain, -120.0);
    Points[Index] := Point(
      CurveLeft + Round(Phase * (CurveRight - CurveLeft)), CurveY(CurveDb));
  end;
  Canvas.Pen.Color := Accent;
  Canvas.Pen.Width := 2;
  Canvas.Polyline(Points);

  if FDataValid then
  begin
    Lfo := 0.5 + 0.5 * Sin(2.0 * Pi * FLfoPhase);
    Gain := Max(0.000001, 1.0 - FDepth * FMix * Lfo);
    MarkerX := CurveLeft + Round(FLfoPhase * (CurveRight - CurveLeft));
    MarkerY := CurveY(LinearToDb(Gain, -120.0));
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := RGB(255, 214, 72);
    Canvas.Pen.Color := RGB(20, 20, 20);
    Canvas.Pen.Width := Max(1, MulDiv(2, FontPPI, 96));
    Canvas.Ellipse(MarkerX - MulDiv(5, FontPPI, 96),
      MarkerY - MulDiv(5, FontPPI, 96), MarkerX + MulDiv(5, FontPPI, 96) + 1,
      MarkerY + MulDiv(5, FontPPI, 96) + 1);
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 48, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), CurveTop - MulDiv(2, FontPPI, 96), '0');
  Canvas.TextOut(MulDiv(4, FontPPI, 96),
    CurveBottom - Canvas.TextHeight('0'), FormatFloat('0', CurveFloorDb));
end;

end.
