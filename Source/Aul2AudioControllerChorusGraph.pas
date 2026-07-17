unit Aul2AudioControllerChorusGraph;

// ChorusのL/R遅延変動カーブ、現在位相、ステレオ相関を描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics;

type
  TAul2ControllerChorusGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FBaseDelayMs: Double;
    FCorrelation: Double;
    FCorrelationValid: Boolean;
    FCurrentDelayL: Double;
    FCurrentDelayR: Double;
    FDataValid: Boolean;
    FDepthMs: Double;
    FLfoPhase: Double;
    FMix: Double;
    FRateHz: Double;
    FStereoMode: Integer;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSnapshot;
    procedure SetChorus(StereoMode: Integer; BaseDelayMs, DepthMs, RateHz,
      Mix: Double; Active: Boolean);
    procedure SetSnapshot(CurrentDelayL, CurrentDelayR, LfoPhase,
      Correlation: Single; CorrelationValid: Boolean);
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
  CURVE_POINT_COUNT = 101;
  GRAPH_BACKGROUND = TColor($0013100E);
  GRAPH_BORDER = TColor($00312C28);
  GRAPH_GRID = TColor($002B2723);
  GRAPH_TEXT = TColor($00F2F0EE);
  GRAPH_LEFT = TColor($00FFD248);
  GRAPH_RIGHT = TColor($00BE64FF);

function ScaleColor(Color: TColor; Numerator, Denominator: Integer): TColor;
begin
  Color := ColorToRGB(Color);
  Result := RGB(
    EnsureRange(GetRValue(Color) * Numerator div Denominator, 0, 255),
    EnsureRange(GetGValue(Color) * Numerator div Denominator, 0, 255),
    EnsureRange(GetBValue(Color) * Numerator div Denominator, 0, 255));
end;

constructor TAul2ControllerChorusGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := GRAPH_BACKGROUND;
  FAccentColor := TColor($0048B0E0);
  FActive := True;
  FStereoMode := 0;
  FBaseDelayMs := 15.0;
  FDepthMs := 5.0;
  FRateHz := 0.5;
  FMix := 0.5;
  ClearSnapshot;
end;

procedure TAul2ControllerChorusGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerChorusGraph.ClearSnapshot;
begin
  FDataValid := False;
  FCorrelationValid := False;
  FCurrentDelayL := 0;
  FCurrentDelayR := 0;
  FLfoPhase := 0;
  FCorrelation := 0;
  Invalidate;
end;

procedure TAul2ControllerChorusGraph.SetChorus(StereoMode: Integer;
  BaseDelayMs, DepthMs, RateHz, Mix: Double; Active: Boolean);
begin
  FStereoMode := EnsureRange(StereoMode, 0, 1);
  FBaseDelayMs := EnsureRange(BaseDelayMs, 1.0, 50.0);
  FDepthMs := EnsureRange(DepthMs, 0.0, 20.0);
  FRateHz := EnsureRange(RateHz, 0.01, 10.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerChorusGraph.SetSnapshot(CurrentDelayL,
  CurrentDelayR, LfoPhase, Correlation: Single; CorrelationValid: Boolean);
begin
  FCurrentDelayL := Max(0.0, CurrentDelayL);
  FCurrentDelayR := Max(0.0, CurrentDelayR);
  FLfoPhase := LfoPhase - Floor(LfoPhase);
  if FLfoPhase < 0 then
    FLfoPhase := FLfoPhase + 1.0;
  FCorrelation := EnsureRange(Correlation, -1.0, 1.0);
  FCorrelationValid := CorrelationValid;
  FDataValid := True;
  Invalidate;
end;

procedure TAul2ControllerChorusGraph.Paint;
var
  Accent: TColor;
  BaseY: Integer;
  CorrelationColor: TColor;
  CurveBottom: Integer;
  CurveLeft: Integer;
  CurveRight: Integer;
  CurveTop: Integer;
  DelayL: Double;
  DelayR: Double;
  DisplayMax: Double;
  DisplayMin: Double;
  FontPPI: Integer;
  GaugeLeft: Integer;
  GaugeMarker: Integer;
  GaugeRight: Integer;
  GaugeY: Integer;
  Index: Integer;
  LegendText: string;
  MarkerXL: Integer;
  MarkerXR: Integer;
  MarkerYL: Integer;
  MarkerYR: Integer;
  MaximumDelay: Double;
  MinimumDelay: Double;
  Padding: Double;
  Phase: Double;
  PointsL: array[0..CURVE_POINT_COUNT - 1] of TPoint;
  PointsR: array[0..CURVE_POINT_COUNT - 1] of TPoint;
  TextValue: string;
  WidthText: string;

  function DelayY(Value: Double): Integer;
  begin
    Value := EnsureRange(Value, DisplayMin, DisplayMax);
    Result := CurveBottom - Round((Value - DisplayMin) /
      (DisplayMax - DisplayMin) * (CurveBottom - CurveTop));
  end;

  procedure DrawMarker(X, Y: Integer; Color: TColor);
  begin
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Color;
    Canvas.Pen.Color := RGB(20, 20, 20);
    Canvas.Pen.Width := Max(1, MulDiv(2, FontPPI, 96));
    Canvas.Ellipse(X - MulDiv(4, FontPPI, 96), Y - MulDiv(4, FontPPI, 96),
      X + MulDiv(4, FontPPI, 96) + 1, Y + MulDiv(4, FontPPI, 96) + 1);
  end;

  procedure DrawPointLabel(X, Y: Integer; const LabelText: string;
    Color: TColor);
  var
    LabelHeight: Integer;
    LabelLeft: Integer;
    LabelTop: Integer;
    LabelWidth: Integer;
  begin
    LabelWidth := Canvas.TextWidth(LabelText);
    LabelHeight := Canvas.TextHeight(LabelText);
    LabelLeft := X + MulDiv(6, FontPPI, 96);
    if LabelLeft + LabelWidth + MulDiv(2, FontPPI, 96) > CurveRight then
      LabelLeft := X - LabelWidth - MulDiv(6, FontPPI, 96);
    LabelTop := EnsureRange(Y - LabelHeight div 2, CurveTop,
      CurveBottom - LabelHeight);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 112, 100);
    Canvas.FillRect(Rect(LabelLeft - MulDiv(1, FontPPI, 96), LabelTop,
      LabelLeft + LabelWidth + MulDiv(1, FontPPI, 96),
      LabelTop + LabelHeight));
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := Color;
    Canvas.TextOut(LabelLeft, LabelTop, LabelText);
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
  Accent := FAccentColor;
  if not FActive then
    Accent := ScaleColor(Accent, 45, 100);

  MinimumDelay := Max(0.0, FBaseDelayMs - FDepthMs);
  MaximumDelay := FBaseDelayMs + FDepthMs;
  Padding := Max(0.5, (MaximumDelay - MinimumDelay) * 0.10);
  DisplayMin := Max(0.0, MinimumDelay - Padding);
  DisplayMax := MaximumDelay + Padding;
  if DisplayMax <= DisplayMin then
    DisplayMax := DisplayMin + 1.0;

  Canvas.Pen.Color := GRAPH_BORDER;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(ClientRect);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96),
    'L/R delay modulation');
  if FCorrelationValid then
  begin
    if FCorrelation >= 0.85 then
      WidthText := 'Narrow'
    else if FCorrelation >= 0.40 then
      WidthText := 'Medium'
    else if FCorrelation >= 0.0 then
      WidthText := 'Wide'
    else
      WidthText := 'Phase risk';
    TextValue := WidthText + ' ' +
      FormatFloat('+0.00;-0.00;0.00', FCorrelation);
    if FCorrelation < -0.1 then
      CorrelationColor := RGB(255, 105, 105)
    else if FCorrelation < 0.5 then
      CorrelationColor := RGB(255, 214, 72)
    else
      CorrelationColor := RGB(92, 210, 135);
  end
  else
  begin
    TextValue := 'Stereo --';
    CorrelationColor := ScaleColor(GRAPH_TEXT, 60, 100);
  end;
  Canvas.Font.Color := CorrelationColor;
  Canvas.TextOut(ClientWidth - Canvas.TextWidth(TextValue) -
    MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96), TextValue);

  if FDataValid then
    TextValue := Format('Now L %s  R %s ms',
      [FormatFloat('0.0', FCurrentDelayL), FormatFloat('0.0', FCurrentDelayR)])
  else
    TextValue := 'Now L --  R -- ms';
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 68, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(20, FontPPI, 96), TextValue);

  GaugeLeft := ClientWidth - MulDiv(88, FontPPI, 96);
  GaugeRight := ClientWidth - MulDiv(9, FontPPI, 96);
  GaugeY := MulDiv(23, FontPPI, 96);
  Canvas.Pen.Color := GRAPH_GRID;
  Canvas.Pen.Width := 1;
  Canvas.MoveTo(GaugeLeft, GaugeY);
  Canvas.LineTo(GaugeRight, GaugeY);
  Canvas.MoveTo((GaugeLeft + GaugeRight) div 2, GaugeY - MulDiv(3, FontPPI, 96));
  Canvas.LineTo((GaugeLeft + GaugeRight) div 2, GaugeY + MulDiv(3, FontPPI, 96));
  if FCorrelationValid then
  begin
    GaugeMarker := GaugeLeft + Round((FCorrelation + 1.0) * 0.5 *
      (GaugeRight - GaugeLeft));
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := CorrelationColor;
    Canvas.Pen.Color := RGB(20, 20, 20);
    Canvas.Ellipse(GaugeMarker - MulDiv(3, FontPPI, 96),
      GaugeY - MulDiv(3, FontPPI, 96), GaugeMarker + MulDiv(3, FontPPI, 96) + 1,
      GaugeY + MulDiv(3, FontPPI, 96) + 1);
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 43, 100);
  Canvas.TextOut(GaugeLeft, GaugeY + MulDiv(2, FontPPI, 96), '-1');
  Canvas.TextOut((GaugeLeft + GaugeRight) div 2 - Canvas.TextWidth('0') div 2,
    GaugeY + MulDiv(2, FontPPI, 96), '0');
  Canvas.TextOut(GaugeRight - Canvas.TextWidth('+1'),
    GaugeY + MulDiv(2, FontPPI, 96), '+1');

  CurveLeft := MulDiv(38, FontPPI, 96);
  CurveRight := ClientWidth - MulDiv(9, FontPPI, 96);
  CurveTop := MulDiv(40, FontPPI, 96);
  CurveBottom := ClientHeight - MulDiv(16, FontPPI, 96);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 118, 100);
  Canvas.FillRect(Rect(CurveLeft, CurveTop, CurveRight, CurveBottom));
  BaseY := DelayY(FBaseDelayMs);
  Canvas.Pen.Color := GRAPH_GRID;
  Canvas.MoveTo(CurveLeft, BaseY);
  Canvas.LineTo(CurveRight, BaseY);

  for Index := 0 to CURVE_POINT_COUNT - 1 do
  begin
    Phase := Index / (CURVE_POINT_COUNT - 1);
    DelayL := Max(0.0, FBaseDelayMs + Sin(2.0 * Pi * Phase) * FDepthMs);
    if FStereoMode = 1 then
      DelayR := Max(0.0, FBaseDelayMs - Sin(2.0 * Pi * Phase) * FDepthMs)
    else
      DelayR := DelayL;
    PointsL[Index] := Point(CurveLeft + Round(Phase *
      (CurveRight - CurveLeft)), DelayY(DelayL));
    PointsR[Index] := Point(PointsL[Index].X, DelayY(DelayR));
  end;
  if FStereoMode = 1 then
  begin
    Canvas.Pen.Color := GRAPH_RIGHT;
    Canvas.Pen.Width := 2;
    Canvas.Polyline(PointsR);
    Canvas.Pen.Color := GRAPH_LEFT;
    Canvas.Polyline(PointsL);
  end
  else
  begin
    Canvas.Pen.Color := Accent;
    Canvas.Pen.Width := 2;
    Canvas.Polyline(PointsL);
  end;

  if FDataValid then
  begin
    MarkerXL := CurveLeft + Round(FLfoPhase * (CurveRight - CurveLeft));
    MarkerYL := DelayY(FCurrentDelayL);
    if FStereoMode = 1 then
    begin
      MarkerXR := MarkerXL;
      MarkerYR := DelayY(FCurrentDelayR);
      DrawMarker(MarkerXR, MarkerYR, GRAPH_RIGHT);
      DrawMarker(MarkerXL, MarkerYL, GRAPH_LEFT);
      if Abs(MarkerYL - MarkerYR) <= Canvas.TextHeight('L/R') then
        DrawPointLabel(MarkerXL, MarkerYL, 'L/R', GRAPH_TEXT)
      else
      begin
        DrawPointLabel(MarkerXL, MarkerYL, 'L', GRAPH_LEFT);
        DrawPointLabel(MarkerXR, MarkerYR, 'R', GRAPH_RIGHT);
      end;
    end
    else
      DrawMarker(MarkerXL, MarkerYL, GRAPH_LEFT);
  end;

  if FStereoMode = 1 then
    LegendText := 'Opposite phase (Wide)'
  else
    LegendText := 'Same phase (Normal)';
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 118, 100);
  Canvas.FillRect(Rect(CurveRight - Canvas.TextWidth(LegendText) -
    MulDiv(5, FontPPI, 96),
    CurveTop + MulDiv(1, FontPPI, 96), CurveRight,
    CurveTop + Canvas.TextHeight('L') + MulDiv(3, FontPPI, 96)));
  Canvas.Brush.Style := bsClear;
  if FStereoMode = 1 then
  begin
    Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 55, 100);
    Canvas.TextOut(CurveRight - Canvas.TextWidth(LegendText) -
      MulDiv(2, FontPPI, 96), CurveTop + MulDiv(1, FontPPI, 96), LegendText);
  end
  else
  begin
    Canvas.Font.Color := Accent;
    Canvas.TextOut(CurveRight - Canvas.TextWidth(LegendText) -
      MulDiv(2, FontPPI, 96), CurveTop + MulDiv(1, FontPPI, 96), LegendText);
  end;

  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 48, 100);
  Canvas.TextOut(MulDiv(3, FontPPI, 96), CurveTop -
    Canvas.TextHeight('0') div 2, FormatFloat('0.#', DisplayMax));
  Canvas.TextOut(MulDiv(3, FontPPI, 96), CurveBottom -
    Canvas.TextHeight('0') div 2, FormatFloat('0.#', DisplayMin));
  Canvas.TextOut(CurveLeft, CurveBottom + MulDiv(1, FontPPI, 96), '0');
  Canvas.TextOut(CurveRight - Canvas.TextWidth('1'),
    CurveBottom + MulDiv(1, FontPPI, 96), '1');
end;

end.
