unit Aul2AudioControllerAutoGainGraph;

// AutoGainのTarget、最新RMS、現在補正ゲインを描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics;

type
  TAul2ControllerAutoGainGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FCorrectionGain: Single;
    FDataValid: Boolean;
    FInputRms: Single;
    FMaxGainDb: Double;
    FMix: Double;
    FOutputRms: Single;
    FSpeedMs: Double;
    FTargetDb: Double;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSnapshot;
    procedure SetAutoGain(TargetDb, SpeedMs, MaxGainDb, Mix: Double;
      Active: Boolean);
    procedure SetSnapshot(InputRms, OutputRms, CorrectionGain: Single);
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
  GRAPH_TARGET = TColor($0048D6FF);
  GRAPH_MIN_DB = -60.0;
  GAIN_MIN_DB = -24.0;
  GAIN_MAX_DB = 24.0;

function ScaleColor(Color: TColor; Numerator, Denominator: Integer): TColor;
begin
  Color := ColorToRGB(Color);
  Result := RGB(
    EnsureRange(GetRValue(Color) * Numerator div Denominator, 0, 255),
    EnsureRange(GetGValue(Color) * Numerator div Denominator, 0, 255),
    EnsureRange(GetBValue(Color) * Numerator div Denominator, 0, 255));
end;

function LinearToDb(Value: Double): Double;
begin
  if Value <= 0.000001 then
    Exit(GRAPH_MIN_DB);
  Result := 20.0 * Log10(Value);
end;

constructor TAul2ControllerAutoGainGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := GRAPH_BACKGROUND;
  FAccentColor := TColor($0048B0E0);
  FActive := True;
  FTargetDb := -12.0;
  FSpeedMs := 400.0;
  FMaxGainDb := 12.0;
  FMix := 1.0;
  ClearSnapshot;
end;

procedure TAul2ControllerAutoGainGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerAutoGainGraph.ClearSnapshot;
begin
  FDataValid := False;
  FInputRms := 0;
  FOutputRms := 0;
  FCorrectionGain := 1.0;
  Invalidate;
end;

procedure TAul2ControllerAutoGainGraph.SetAutoGain(TargetDb, SpeedMs,
  MaxGainDb, Mix: Double; Active: Boolean);
begin
  FTargetDb := EnsureRange(TargetDb, -36.0, -3.0);
  FSpeedMs := EnsureRange(SpeedMs, 20.0, 2000.0);
  FMaxGainDb := EnsureRange(MaxGainDb, 0.0, 24.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerAutoGainGraph.SetSnapshot(InputRms, OutputRms,
  CorrectionGain: Single);
begin
  FInputRms := Max(0.0, InputRms);
  FOutputRms := Max(0.0, OutputRms);
  FCorrectionGain := Max(0.0, CorrectionGain);
  FDataValid := True;
  Invalidate;
end;

procedure TAul2ControllerAutoGainGraph.Paint;
var
  Accent: TColor;
  BarLeft: Integer;
  BarRight: Integer;
  BarWidth: Integer;
  CorrectionDb: Double;
  DetailText: string;
  FillRight: Integer;
  FontPPI: Integer;
  GainBar: TRect;
  GainCenter: Integer;
  GainDb: Integer;
  GainLeft: Integer;
  GainRight: Integer;
  InputDb: Double;
  OutputDb: Double;
  TargetX: Integer;

  function LevelX(ValueDb: Double): Integer;
  begin
    ValueDb := EnsureRange(ValueDb, GRAPH_MIN_DB, 0.0);
    Result := BarLeft + Round((ValueDb - GRAPH_MIN_DB) / -GRAPH_MIN_DB *
      BarWidth);
  end;

  function GainX(ValueDb: Double): Integer;
  begin
    ValueDb := EnsureRange(ValueDb, GAIN_MIN_DB, GAIN_MAX_DB);
    Result := GainLeft + Round((ValueDb - GAIN_MIN_DB) /
      (GAIN_MAX_DB - GAIN_MIN_DB) * (GainRight - GainLeft));
  end;

  procedure DrawLevel(Top: Integer; const LabelText: string; ValueDb: Double;
    MeterColor: TColor);
  var
    MeterRect: TRect;
    ValueText: string;
    ValueX: Integer;
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
      Canvas.Brush.Color := MeterColor;
      Canvas.FillRect(Rect(BarLeft, MeterRect.Top, LevelX(ValueDb),
        MeterRect.Bottom));
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
  Accent := FAccentColor;
  if not FActive then
    Accent := ScaleColor(Accent, 45, 100);

  Canvas.Pen.Color := GRAPH_BORDER;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(ClientRect);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96),
    'AutoGain snapshot');
  DetailText := Format('Target %s dB', [FormatFloat('0.0', FTargetDb)]);
  Canvas.Font.Color := GRAPH_TARGET;
  Canvas.TextOut(ClientWidth - Canvas.TextWidth(DetailText) -
    MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96), DetailText);

  BarLeft := MulDiv(38, FontPPI, 96);
  BarRight := ClientWidth - MulDiv(9, FontPPI, 96);
  BarWidth := Max(1, BarRight - BarLeft);
  InputDb := EnsureRange(LinearToDb(FInputRms), GRAPH_MIN_DB, 0.0);
  OutputDb := EnsureRange(LinearToDb(FOutputRms), GRAPH_MIN_DB, 0.0);
  DrawLevel(MulDiv(24, FontPPI, 96), 'In', InputDb, GRAPH_INPUT);
  DrawLevel(MulDiv(40, FontPPI, 96), 'Out', OutputDb, Accent);

  TargetX := LevelX(FTargetDb);
  Canvas.Pen.Color := GRAPH_TARGET;
  Canvas.Pen.Width := 2;
  Canvas.MoveTo(TargetX, MulDiv(21, FontPPI, 96));
  Canvas.LineTo(TargetX, MulDiv(53, FontPPI, 96));
  Canvas.Pen.Width := 1;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 50, 100);
  for GainDb in [-60, -30, 0] do
    Canvas.TextOut(LevelX(GainDb) - Canvas.TextWidth(IntToStr(GainDb)) div 2,
      MulDiv(52, FontPPI, 96), IntToStr(GainDb));

  if FDataValid then
    CorrectionDb := LinearToDb(FCorrectionGain)
  else
    CorrectionDb := 0;
  if FDataValid then
    DetailText := Format('Correction %s dB   Output delta %s dB',
      [FormatFloat('+0.0;-0.0;0.0', CorrectionDb),
       FormatFloat('+0.0;-0.0;0.0', OutputDb - InputDb)])
  else
    DetailText := 'Correction -- dB';
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 72, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(67, FontPPI, 96), DetailText);

  GainLeft := MulDiv(38, FontPPI, 96);
  GainRight := ClientWidth - MulDiv(9, FontPPI, 96);
  GainCenter := GainX(0.0);
  GainBar := Rect(GainLeft, MulDiv(91, FontPPI, 96), GainRight,
    MulDiv(105, FontPPI, 96));
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 130, 100);
  Canvas.FillRect(GainBar);
  if FDataValid then
  begin
    FillRight := GainX(CorrectionDb);
    Canvas.Brush.Color := Accent;
    Canvas.FillRect(Rect(Min(GainCenter, FillRight), GainBar.Top,
      Max(GainCenter, FillRight), GainBar.Bottom));
  end;
  Canvas.Pen.Color := GRAPH_TARGET;
  Canvas.MoveTo(GainCenter, GainBar.Top - MulDiv(3, FontPPI, 96));
  Canvas.LineTo(GainCenter, GainBar.Bottom + MulDiv(3, FontPPI, 96));
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 50, 100);
  for GainDb in [-24, 0, 24] do
    Canvas.TextOut(GainX(GainDb) - Canvas.TextWidth(IntToStr(GainDb)) div 2,
      GainBar.Bottom + MulDiv(2, FontPPI, 96), IntToStr(GainDb));

  DetailText := Format('Speed %s ms   Max +%s dB   Mix %s',
    [FormatFloat('0', FSpeedMs), FormatFloat('0.0', FMaxGainDb),
     FormatFloat('0.00', FMix)]);
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 62, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), ClientHeight -
    Canvas.TextHeight(DetailText) - MulDiv(4, FontPPI, 96), DetailText);
end;

end.
