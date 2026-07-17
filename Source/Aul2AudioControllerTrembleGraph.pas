unit Aul2AudioControllerTrembleGraph;

// Tremble処理前後のRMS時間履歴を描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  Aul2AudioTrembleRmsShared;

type
  TAul2ControllerTrembleGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FHistoryCount: Integer;
    FSampleRate: Integer;
    FSampleIndices: TAudioTrembleSampleIndexData;
    FInputRms: TAudioTrembleRmsData;
    FOutputRms: TAudioTrembleRmsData;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearHistory;
    procedure SetHistory(const SampleIndices: TAudioTrembleSampleIndexData;
      const InputRms, OutputRms: TAudioTrembleRmsData; HistoryCount,
      SampleRate: Integer; Active: Boolean);
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

function RmsToDb(Value: Single): Double;
begin
  if Value <= 0.000001 then
    Exit(GRAPH_MIN_DB);
  Result := EnsureRange(20.0 * Log10(Value), GRAPH_MIN_DB, 0.0);
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
  ClearHistory;
end;

procedure TAul2ControllerTrembleGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerTrembleGraph.ClearHistory;
begin
  FHistoryCount := 0;
  FSampleRate := 0;
  FillChar(FSampleIndices, SizeOf(FSampleIndices), 0);
  FillChar(FInputRms, SizeOf(FInputRms), 0);
  FillChar(FOutputRms, SizeOf(FOutputRms), 0);
  Invalidate;
end;

procedure TAul2ControllerTrembleGraph.SetHistory(
  const SampleIndices: TAudioTrembleSampleIndexData;
  const InputRms, OutputRms: TAudioTrembleRmsData; HistoryCount,
  SampleRate: Integer; Active: Boolean);
begin
  FSampleIndices := SampleIndices;
  FInputRms := InputRms;
  FOutputRms := OutputRms;
  FHistoryCount := EnsureRange(HistoryCount, 0, AUDIO_TREMBLE_RMS_HISTORY_COUNT);
  FSampleRate := Max(0, SampleRate);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerTrembleGraph.Paint;
var
  Accent: TColor;
  Bottom: Integer;
  Db: Integer;
  DurationText: string;
  FontPPI: Integer;
  Left: Integer;
  Points: array of TPoint;
  Right: Integer;
  TextHeight: Integer;
  Top: Integer;
  X: Integer;
  Y: Integer;

  procedure DrawLine(const Values: TAudioTrembleRmsData; LineColor: TColor);
  var
    LineIndex: Integer;
  begin
    if FHistoryCount <= 0 then
      Exit;
    SetLength(Points, FHistoryCount);
    for LineIndex := 0 to FHistoryCount - 1 do
    begin
      if (FHistoryCount > 1) and
         (FSampleIndices[FHistoryCount - 1] > FSampleIndices[0]) then
        X := Left + Round((FSampleIndices[LineIndex] - FSampleIndices[0]) *
          (Right - Left) /
          (FSampleIndices[FHistoryCount - 1] - FSampleIndices[0]))
      else if FHistoryCount > 1 then
        X := Left + Round(LineIndex * (Right - Left) / (FHistoryCount - 1))
      else
        X := Right;
      Y := Bottom - Round((RmsToDb(Values[LineIndex]) - GRAPH_MIN_DB) /
        -GRAPH_MIN_DB * (Bottom - Top));
      Points[LineIndex] := Point(X, Y);
    end;
    Canvas.Pen.Color := LineColor;
    Canvas.Pen.Width := 2;
    if FHistoryCount = 1 then
    begin
      Canvas.MoveTo(Left, Points[0].Y);
      Canvas.LineTo(Right, Points[0].Y);
    end
    else
      Canvas.Polyline(Points);
  end;

begin
  inherited;
  Canvas.Brush.Color := GRAPH_BACKGROUND;
  Canvas.FillRect(ClientRect);
  if (ClientWidth <= 30) or (ClientHeight <= 30) then
    Exit;

  FontPPI := Max(96, CurrentPPI);
  Canvas.Font.Assign(Font);
  Canvas.Font.Height := -MulDiv(9, FontPPI, 72);
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.Brush.Style := bsClear;
  TextHeight := Canvas.TextHeight('0');
  Accent := FAccentColor;
  if not FActive then
    Accent := ScaleColor(Accent, 45, 100);

  Canvas.Pen.Color := GRAPH_BORDER;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(ClientRect);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(5, FontPPI, 96),
    'Input / Output RMS');

  Left := MulDiv(34, FontPPI, 96);
  Right := ClientWidth - MulDiv(9, FontPPI, 96);
  Top := MulDiv(29, FontPPI, 96);
  Bottom := ClientHeight - MulDiv(25, FontPPI, 96);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 120, 100);
  Canvas.FillRect(Rect(Left, Top, Right, Bottom));
  Canvas.Brush.Style := bsClear;

  Canvas.Pen.Color := GRAPH_GRID;
  Canvas.Pen.Width := 1;
  for Db in [-60, -40, -20, 0] do
  begin
    Y := Bottom - Round((Db - GRAPH_MIN_DB) / -GRAPH_MIN_DB *
      (Bottom - Top));
    Canvas.MoveTo(Left, Y);
    Canvas.LineTo(Right, Y);
    Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 55, 100);
    Canvas.TextOut(Left - Canvas.TextWidth(IntToStr(Db)) - 4,
      Y - TextHeight div 2, IntToStr(Db));
  end;

  if FHistoryCount > 0 then
  begin
    DrawLine(FInputRms, GRAPH_INPUT);
    DrawLine(FOutputRms, Accent);
    Canvas.Font.Color := GRAPH_INPUT;
    Canvas.TextOut(Left, Bottom + 3, 'Input');
    Canvas.Font.Color := Accent;
    Canvas.TextOut(Left + Canvas.TextWidth('Input') + 10, Bottom + 3, 'Output');
    if (FSampleRate > 0) and (FHistoryCount > 1) then
      DurationText := FormatFloat('0.0s',
        (FSampleIndices[FHistoryCount - 1] - FSampleIndices[0]) / FSampleRate)
    else
      DurationText := 'recent';
    Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 55, 100);
    Canvas.TextOut(Right - Canvas.TextWidth(DurationText), Bottom + 3,
      DurationText);
  end
  else
  begin
    Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 55, 100);
    Canvas.TextOut(Left + (Right - Left - Canvas.TextWidth('no audio data')) div 2,
      Top + (Bottom - Top - TextHeight) div 2, 'no audio data');
  end;
end;

end.
