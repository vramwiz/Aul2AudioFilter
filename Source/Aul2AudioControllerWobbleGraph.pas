unit Aul2AudioControllerWobbleGraph;

// Wobbleの1周期遅延変動カーブと現在位相を描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics;

type
  TAul2ControllerWobbleGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FBaseDelayMs: Double;
    FCurrentDelayMs: Double;
    FDataValid: Boolean;
    FDepthMs: Double;
    FLfoPhase: Double;
    FMix: Double;
    FRateHz: Double;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSnapshot;
    procedure SetWobble(BaseDelayMs, DepthMs, RateHz, Mix: Double;
      Active: Boolean);
    procedure SetSnapshot(CurrentDelayMs, LfoPhase: Single);
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
  CURVE_POINT_COUNT = 121;
  GRAPH_BACKGROUND = TColor($0013100E);
  GRAPH_BORDER = TColor($00312C28);
  GRAPH_GRID = TColor($002B2723);
  GRAPH_TEXT = TColor($00F2F0EE);
  GRAPH_BASE = TColor($007ABE5C);

function ScaleColor(Color: TColor; Numerator, Denominator: Integer): TColor;
begin
  Color := ColorToRGB(Color);
  Result := RGB(
    EnsureRange(GetRValue(Color) * Numerator div Denominator, 0, 255),
    EnsureRange(GetGValue(Color) * Numerator div Denominator, 0, 255),
    EnsureRange(GetBValue(Color) * Numerator div Denominator, 0, 255));
end;

constructor TAul2ControllerWobbleGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := GRAPH_BACKGROUND;
  FAccentColor := TColor($0048B0E0);
  FActive := True;
  FBaseDelayMs := 24.0;
  FDepthMs := 12.0;
  FRateHz := 1.2;
  FMix := 0.65;
  ClearSnapshot;
end;

procedure TAul2ControllerWobbleGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerWobbleGraph.ClearSnapshot;
begin
  FDataValid := False;
  FCurrentDelayMs := 0;
  FLfoPhase := 0;
  Invalidate;
end;

procedure TAul2ControllerWobbleGraph.SetWobble(BaseDelayMs, DepthMs, RateHz,
  Mix: Double; Active: Boolean);
begin
  FBaseDelayMs := EnsureRange(BaseDelayMs, 1.0, 120.0);
  FDepthMs := EnsureRange(DepthMs, 0.0, 80.0);
  FRateHz := EnsureRange(RateHz, 0.05, 8.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerWobbleGraph.SetSnapshot(CurrentDelayMs,
  LfoPhase: Single);
begin
  FCurrentDelayMs := Max(0.0, CurrentDelayMs);
  FLfoPhase := LfoPhase - Floor(LfoPhase);
  if FLfoPhase < 0 then
    FLfoPhase := FLfoPhase + 1.0;
  FDataValid := True;
  Invalidate;
end;

procedure TAul2ControllerWobbleGraph.Paint;
var
  Accent: TColor;
  Angle: Double;
  ArrowSize: Integer;
  BaseY: Integer;
  CurveBottom: Integer;
  CurveLeft: Integer;
  CurveRight: Integer;
  CurveTop: Integer;
  DelayMs: Double;
  DelayDerivative: Double;
  DisplayMax: Double;
  DisplayMin: Double;
  DirectionText: string;
  EndX: Integer;
  EndY: Integer;
  FontPPI: Integer;
  Index: Integer;
  MarkerX: Integer;
  MarkerY: Integer;
  MaximumDelay: Double;
  MinimumDelay: Double;
  Padding: Double;
  Phase: Double;
  PitchRatio: Double;
  PitchSemitones: Double;
  PixelSlope: Double;
  Points: array[0..CURVE_POINT_COUNT - 1] of TPoint;
  TextValue: string;
  StartX: Integer;
  StartY: Integer;
  TangentHalfWidth: Integer;

  function DelayY(Value: Double): Integer;
  begin
    Value := EnsureRange(Value, DisplayMin, DisplayMax);
    Result := CurveBottom - Round((Value - DisplayMin) /
      (DisplayMax - DisplayMin) * (CurveBottom - CurveTop));
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
  Padding := Max(1.0, (MaximumDelay - MinimumDelay) * 0.12);
  DisplayMin := Max(0.0, MinimumDelay - Padding);
  DisplayMax := MaximumDelay + Padding;
  if DisplayMax <= DisplayMin then
    DisplayMax := DisplayMin + 2.0;

  Canvas.Pen.Color := GRAPH_BORDER;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(ClientRect);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96),
    'Delay modulation');
  if FDataValid then
    TextValue := Format('Now %s ms', [FormatFloat('0.0', FCurrentDelayMs)])
  else
    TextValue := 'Now -- ms';
  Canvas.Font.Color := Accent;
  Canvas.TextOut(ClientWidth - Canvas.TextWidth(TextValue) -
    MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96), TextValue);

  TextValue := Format('Range %s..%s ms   %s Hz   Mix %s',
    [FormatFloat('0.0', MinimumDelay), FormatFloat('0.0', MaximumDelay),
     FormatFloat('0.00', FRateHz), FormatFloat('0.00', FMix)]);
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 70, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(20, FontPPI, 96), TextValue);

  if FDataValid then
  begin
    DelayDerivative := 2.0 * Pi * FRateHz * (FDepthMs / 1000.0) *
      Cos(2.0 * Pi * FLfoPhase);
    PitchRatio := 1.0 - DelayDerivative;
    if DelayDerivative > 0.0005 then
      DirectionText := 'Delay rising -> Pitch down'
    else if DelayDerivative < -0.0005 then
      DirectionText := 'Delay falling -> Pitch up'
    else
      DirectionText := 'Delay turning -> Pitch steady';
    if PitchRatio > 0.001 then
    begin
      PitchSemitones := 12.0 * Log2(PitchRatio);
      TextValue := Format('%s   Wet %s st', [DirectionText,
        FormatFloat('+0.0;-0.0;0.0', PitchSemitones)]);
    end
    else
      TextValue := DirectionText + '   Wet read reverse';
  end
  else
    TextValue := 'Delay direction --   Wet pitch --';
  Canvas.Font.Color := RGB(72, 210, 255);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(35, FontPPI, 96), TextValue);

  CurveLeft := MulDiv(42, FontPPI, 96);
  CurveRight := ClientWidth - MulDiv(9, FontPPI, 96);
  CurveTop := MulDiv(57, FontPPI, 96);
  CurveBottom := ClientHeight - MulDiv(18, FontPPI, 96);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 118, 100);
  Canvas.FillRect(Rect(CurveLeft, CurveTop, CurveRight, CurveBottom));

  BaseY := DelayY(FBaseDelayMs);
  Canvas.Pen.Color := ScaleColor(GRAPH_BASE, 72, 100);
  Canvas.Pen.Width := 1;
  Canvas.MoveTo(CurveLeft, BaseY);
  Canvas.LineTo(CurveRight, BaseY);
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 48, 100);
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(MulDiv(4, FontPPI, 96), CurveTop -
    Canvas.TextHeight('0') div 2, FormatFloat('0.#', DisplayMax));
  Canvas.TextOut(MulDiv(4, FontPPI, 96), CurveBottom -
    Canvas.TextHeight('0') div 2, FormatFloat('0.#', DisplayMin));

  for Index := 0 to CURVE_POINT_COUNT - 1 do
  begin
    Phase := Index / (CURVE_POINT_COUNT - 1);
    DelayMs := Max(0.0, FBaseDelayMs + Sin(2.0 * Pi * Phase) * FDepthMs);
    Points[Index] := Point(
      CurveLeft + Round(Phase * (CurveRight - CurveLeft)), DelayY(DelayMs));
  end;
  Canvas.Pen.Color := Accent;
  Canvas.Pen.Width := 2;
  Canvas.Polyline(Points);

  if FDataValid then
  begin
    MarkerX := CurveLeft + Round(FLfoPhase * (CurveRight - CurveLeft));
    MarkerY := DelayY(FCurrentDelayMs);
    DelayDerivative := 2.0 * Pi * FDepthMs *
      Cos(2.0 * Pi * FLfoPhase);
    PixelSlope := -DelayDerivative * (CurveBottom - CurveTop) /
      (DisplayMax - DisplayMin) / (CurveRight - CurveLeft);
    TangentHalfWidth := MulDiv(18, FontPPI, 96);
    StartX := Max(CurveLeft, MarkerX - TangentHalfWidth);
    EndX := Min(CurveRight, MarkerX + TangentHalfWidth);
    StartY := EnsureRange(MarkerY + Round((StartX - MarkerX) * PixelSlope),
      CurveTop, CurveBottom);
    EndY := EnsureRange(MarkerY + Round((EndX - MarkerX) * PixelSlope),
      CurveTop, CurveBottom);
    Canvas.Pen.Color := RGB(72, 210, 255);
    Canvas.Pen.Width := Max(1, MulDiv(2, FontPPI, 96));
    Canvas.MoveTo(StartX, StartY);
    Canvas.LineTo(EndX, EndY);
    if (EndX <> StartX) or (EndY <> StartY) then
    begin
      ArrowSize := MulDiv(5, FontPPI, 96);
      Angle := ArcTan2(EndY - StartY, EndX - StartX);
      Canvas.MoveTo(EndX, EndY);
      Canvas.LineTo(EndX - Round(ArrowSize * Cos(Angle - 0.55)),
        EndY - Round(ArrowSize * Sin(Angle - 0.55)));
      Canvas.MoveTo(EndX, EndY);
      Canvas.LineTo(EndX - Round(ArrowSize * Cos(Angle + 0.55)),
        EndY - Round(ArrowSize * Sin(Angle + 0.55)));
    end;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := RGB(72, 210, 255);
    Canvas.Pen.Color := RGB(20, 20, 20);
    Canvas.Pen.Width := Max(1, MulDiv(2, FontPPI, 96));
    Canvas.Ellipse(MarkerX - MulDiv(5, FontPPI, 96),
      MarkerY - MulDiv(5, FontPPI, 96), MarkerX + MulDiv(5, FontPPI, 96) + 1,
      MarkerY + MulDiv(5, FontPPI, 96) + 1);
  end;

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 50, 100);
  Canvas.TextOut(CurveLeft, CurveBottom + MulDiv(2, FontPPI, 96), '0');
  Canvas.TextOut(CurveLeft + (CurveRight - CurveLeft) div 2 -
    Canvas.TextWidth('1/2') div 2, CurveBottom + MulDiv(2, FontPPI, 96), '1/2');
  Canvas.TextOut(CurveRight - Canvas.TextWidth('1'),
    CurveBottom + MulDiv(2, FontPPI, 96), '1');
end;

end.
