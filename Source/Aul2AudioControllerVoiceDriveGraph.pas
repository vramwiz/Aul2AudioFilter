unit Aul2AudioControllerVoiceDriveGraph;

// VoiceDriveの設定伝達範囲と実音声Input/Output XY点列を描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  Aul2AudioVoiceDriveXYShared;

type
  TAul2ControllerVoiceDriveGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FBody: Double;
    FDriveDb: Double;
    FLevelDb: Double;
    FMix: Double;
    FSampleCount: Integer;
    FSamplesValid: Boolean;
    FInputSamples: TAudioVoiceDriveXYData;
    FOutputSamples: TAudioVoiceDriveXYData;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSamples;
    procedure SetVoiceDrive(DriveDb, Body, LevelDb, Mix: Double;
      Active: Boolean);
    procedure SetSamples(const InputSamples,
      OutputSamples: TAudioVoiceDriveXYData; SampleCount: Integer);
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
  System.Types,
  System.UITypes;

const
  DRIVE_GRAPH_BACKGROUND = TColor($0013100E);
  DRIVE_GRAPH_BORDER = TColor($00312C28);
  DRIVE_GRAPH_GRID = TColor($002B2723);
  DRIVE_GRAPH_AXIS = TColor($00645E58);
  DRIVE_GRAPH_TEXT = TColor($00F2F0EE);
  DRIVE_GRAPH_POINTS = TColor($00D8D8D8);

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

constructor TAul2ControllerVoiceDriveGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := DRIVE_GRAPH_BACKGROUND;
  FAccentColor := RGB(242, 242, 242);
  FActive := True;
  FDriveDb := 9;
  FBody := 0.45;
  FLevelDb := -6;
  FMix := 0.6;
  ClearSamples;
end;

procedure TAul2ControllerVoiceDriveGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerVoiceDriveGraph.ClearSamples;
begin
  FSamplesValid := False;
  FSampleCount := 0;
  FillChar(FInputSamples, SizeOf(FInputSamples), 0);
  FillChar(FOutputSamples, SizeOf(FOutputSamples), 0);
  Invalidate;
end;

procedure TAul2ControllerVoiceDriveGraph.SetVoiceDrive(DriveDb, Body,
  LevelDb, Mix: Double; Active: Boolean);
begin
  FDriveDb := EnsureRange(DriveDb, 0.0, 30.0);
  FBody := EnsureRange(Body, 0.0, 1.0);
  FLevelDb := EnsureRange(LevelDb, -24.0, 6.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerVoiceDriveGraph.SetSamples(const InputSamples,
  OutputSamples: TAudioVoiceDriveXYData; SampleCount: Integer);
begin
  FInputSamples := InputSamples;
  FOutputSamples := OutputSamples;
  FSampleCount := EnsureRange(SampleCount, 1,
    AUDIO_VOICE_DRIVE_XY_SAMPLE_COUNT);
  FSamplesValid := True;
  Invalidate;
end;

procedure TAul2ControllerVoiceDriveGraph.Paint;
var
  AccentColor: TColor;
  BandPoints: array of TPoint;
  CurvePoints: array of TPoint;
  DriveGain: Double;
  GraphBottom, GraphLeft, GraphRight, GraphTop: Integer;
  GridIndex, I: Integer;
  HeaderText: string;
  InputValue: Double;
  LevelGain: Double;
  Normalizer: Double;
  OutputRange: Double;
  PlotHeight, PlotWidth: Integer;
  PointSize: Integer;
  TextHeight: Integer;
  X, Y: Integer;

  function Transfer(Value, LowRatio: Double): Double;
  var
    DrivenInput: Double;
    Wet: Double;
  begin
    DrivenInput := Value * (1.0 - FBody * 0.35) +
      Value * LowRatio * FBody * 0.35;
    Wet := Tanh(DrivenInput * DriveGain) / Normalizer * LevelGain;
    Result := Value * (1.0 - FMix) + Wet * FMix;
  end;

  function InputToX(Value: Double): Integer;
  begin
    Result := GraphLeft + Round((EnsureRange(Value, -1.0, 1.0) + 1.0) *
      0.5 * PlotWidth);
  end;

  function OutputToY(Value: Double): Integer;
  begin
    Result := GraphBottom - Round((EnsureRange(Value, -OutputRange,
      OutputRange) + OutputRange) / (OutputRange * 2.0) * PlotHeight);
  end;

  procedure DrawBackedText(TextX, TextY: Integer; const Text: string;
    TextColor: TColor);
  var
    R: TRect;
  begin
    R := Rect(TextX - 2, TextY - 1, TextX + Canvas.TextWidth(Text) + 2,
      TextY + Canvas.TextHeight(Text) + 1);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := clBlack;
    Canvas.FillRect(R);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := TextColor;
    Canvas.TextOut(TextX, TextY, Text);
  end;

begin
  Canvas.Brush.Color := DRIVE_GRAPH_BACKGROUND;
  Canvas.FillRect(ClientRect);
  if (ClientWidth < 80) or (ClientHeight < 70) then
    Exit;

  Canvas.Font.Assign(Font);
  Canvas.Font.Height := -MulDiv(9, Max(96, CurrentPPI), 72);
  Canvas.Font.Quality := fqClearTypeNatural;
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := DRIVE_GRAPH_TEXT;
  TextHeight := Canvas.TextHeight('0');
  GraphLeft := MulDiv(35, Max(96, CurrentPPI), 96);
  GraphRight := ClientWidth - MulDiv(10, Max(96, CurrentPPI), 96);
  GraphTop := MulDiv(32, Max(96, CurrentPPI), 96);
  GraphBottom := ClientHeight - MulDiv(24, Max(96, CurrentPPI), 96);
  PlotWidth := Max(1, GraphRight - GraphLeft);
  PlotHeight := Max(1, GraphBottom - GraphTop);
  DriveGain := Power(10.0, FDriveDb / 20.0);
  LevelGain := Power(10.0, FLevelDb / 20.0);
  Normalizer := Max(0.000001, Tanh(DriveGain));

  OutputRange := Max(1.0, Max(Abs(Transfer(-1.0, 0.0)),
    Abs(Transfer(1.0, 1.0))) * 1.08);
  if FSamplesValid then
    for I := 0 to FSampleCount - 1 do
      OutputRange := Max(OutputRange, Abs(FOutputSamples[I]) * 1.08);
  if OutputRange > 4 then OutputRange := 8
  else if OutputRange > 2 then OutputRange := 4
  else if OutputRange > 1 then OutputRange := 2
  else OutputRange := 1;

  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := DRIVE_GRAPH_BORDER;
  Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  HeaderText := Format('Drive %.1fdB  Body %.2f', [FDriveDb, FBody]);
  Canvas.TextOut(GraphLeft, MulDiv(7, Max(96, CurrentPPI), 96), HeaderText);
  HeaderText := Format('Level %.1fdB  Mix %.2f', [FLevelDb, FMix]);
  Canvas.TextOut(GraphRight - Canvas.TextWidth(HeaderText),
    MulDiv(7, Max(96, CurrentPPI), 96), HeaderText);

  Canvas.Pen.Color := DRIVE_GRAPH_GRID;
  for GridIndex := 0 to 4 do
  begin
    X := GraphLeft + PlotWidth * GridIndex div 4;
    Canvas.MoveTo(X, GraphTop); Canvas.LineTo(X, GraphBottom);
    Y := GraphTop + PlotHeight * GridIndex div 4;
    Canvas.MoveTo(GraphLeft, Y); Canvas.LineTo(GraphRight, Y);
  end;
  Canvas.Pen.Color := DRIVE_GRAPH_AXIS;
  Canvas.MoveTo(InputToX(0), GraphTop);
  Canvas.LineTo(InputToX(0), GraphBottom);
  Canvas.MoveTo(GraphLeft, OutputToY(0));
  Canvas.LineTo(GraphRight, OutputToY(0));

  Canvas.Pen.Style := psDash;
  Canvas.MoveTo(InputToX(-1), OutputToY(-1));
  Canvas.LineTo(InputToX(1), OutputToY(1));
  Canvas.Pen.Style := psSolid;

  AccentColor := FAccentColor;
  if not FActive then
    AccentColor := ScaleColor(AccentColor, 45, 100);
  SetLength(BandPoints, (PlotWidth + 1) * 2);
  SetLength(CurvePoints, PlotWidth + 1);
  for I := 0 to PlotWidth do
  begin
    InputValue := -1.0 + 2.0 * I / PlotWidth;
    BandPoints[I] := Point(GraphLeft + I, OutputToY(Transfer(InputValue, 0.0)));
    BandPoints[Length(BandPoints) - 1 - I] := Point(GraphLeft + I,
      OutputToY(Transfer(InputValue, 1.0)));
    CurvePoints[I] := Point(GraphLeft + I,
      OutputToY(Transfer(InputValue, 0.5)));
  end;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(AccentColor, 24, 100);
  Canvas.Pen.Color := Canvas.Brush.Color;
  Canvas.Polygon(BandPoints);

  if FSamplesValid then
  begin
    PointSize := Max(1, MulDiv(2, Max(96, CurrentPPI), 96));
    Canvas.Brush.Color := ScaleColor(DRIVE_GRAPH_POINTS, 70, 100);
    Canvas.Pen.Color := Canvas.Brush.Color;
    for I := 0 to FSampleCount - 1 do
    begin
      X := InputToX(FInputSamples[I]);
      Y := OutputToY(FOutputSamples[I]);
      Canvas.Rectangle(X - PointSize div 2, Y - PointSize div 2,
        X + PointSize div 2 + 1, Y + PointSize div 2 + 1);
    end;
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := AccentColor;
  Canvas.Pen.Width := Max(2, MulDiv(3, Max(96, CurrentPPI), 96));
  Canvas.Polyline(CurvePoints);

  Canvas.Font.Color := DRIVE_GRAPH_TEXT;
  HeaderText := FormatFloat('0.#', OutputRange);
  Canvas.TextOut(GraphLeft - Canvas.TextWidth(HeaderText) - 4,
    GraphTop - TextHeight div 2, HeaderText);
  HeaderText := FormatFloat('-0.#', OutputRange);
  Canvas.TextOut(GraphLeft - Canvas.TextWidth(HeaderText) - 4,
    GraphBottom - TextHeight div 2, HeaderText);
  for GridIndex := 0 to 4 do
  begin
    HeaderText := FormatFloat('0.#', -1.0 + GridIndex * 0.5);
    X := InputToX(-1.0 + GridIndex * 0.5);
    Canvas.TextOut(EnsureRange(X - Canvas.TextWidth(HeaderText) div 2, 1,
      ClientWidth - Canvas.TextWidth(HeaderText) - 1), GraphBottom + 4,
      HeaderText);
  end;
  DrawBackedText(GraphLeft + 4, GraphTop + 3, 'Body range',
    ScaleColor(AccentColor, 82, 100));
  if FSamplesValid then
    DrawBackedText(GraphRight - Canvas.TextWidth('Audio XY') - 4,
      GraphTop + 3, 'Audio XY', DRIVE_GRAPH_POINTS)
  else
    DrawBackedText(GraphRight - Canvas.TextWidth('No audio XY') - 4,
      GraphTop + 3, 'No audio XY', ScaleColor(DRIVE_GRAPH_TEXT, 60, 100));
end;

end.
