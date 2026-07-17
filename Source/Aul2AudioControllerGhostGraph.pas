unit Aul2AudioControllerGhostGraph;

// Ghostの追加残響RMSと遅延した残響影の減衰を描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics;

type
  TAul2ControllerGhostGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FAddedRms: Single;
    FDataValid: Boolean;
    FFeedback: Double;
    FMix: Double;
    FSizeMs: Double;
    FWet: Double;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSnapshot;
    procedure SetGhost(SizeMs, Feedback, Wet, Mix: Double; Active: Boolean);
    procedure SetSnapshot(AddedRms: Single);
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
  GRAPH_ADDED = TColor($00FFD248);
  GRAPH_MIN_DB = -60.0;
  MAX_GHOST_NODES = 8;

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
  Result := Max(GRAPH_MIN_DB, 20.0 * Log10(Value));
end;

constructor TAul2ControllerGhostGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := GRAPH_BACKGROUND;
  FAccentColor := TColor($0048B0E0);
  FActive := True;
  FSizeMs := 420.0;
  FFeedback := 0.45;
  FWet := 0.35;
  FMix := 1.0;
  ClearSnapshot;
end;

procedure TAul2ControllerGhostGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerGhostGraph.ClearSnapshot;
begin
  FDataValid := False;
  FAddedRms := 0;
  Invalidate;
end;

procedure TAul2ControllerGhostGraph.SetGhost(SizeMs, Feedback, Wet,
  Mix: Double; Active: Boolean);
begin
  FSizeMs := EnsureRange(SizeMs, 80.0, 1500.0);
  FFeedback := EnsureRange(Feedback, 0.0, 0.95);
  FWet := EnsureRange(Wet, 0.0, 1.0);
  FMix := EnsureRange(Mix, 0.0, 1.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerGhostGraph.SetSnapshot(AddedRms: Single);
begin
  FAddedRms := Max(0.0, AddedRms);
  FDataValid := True;
  Invalidate;
end;

procedure TAul2ControllerGhostGraph.Paint;
var
  Accent: TColor;
  AddedBar: TRect;
  AddedDb: Double;
  DelayMs: Double;
  DisplayMs: Double;
  EffectiveLoop: Double;
  FillX: Integer;
  FirstLevel: Double;
  FontPPI: Integer;
  GraphBottom: Integer;
  GraphLeft: Integer;
  GraphRight: Integer;
  GraphTop: Integer;
  Node: Integer;
  NodeCount: Integer;
  NodeDb: Double;
  NodeLevel: Double;
  NodeX: Integer;
  NodeY: Integer;
  Points: array[0..MAX_GHOST_NODES - 1] of TPoint;
  TextValue: string;

  function DbY(ValueDb: Double): Integer;
  begin
    ValueDb := EnsureRange(ValueDb, GRAPH_MIN_DB, 0.0);
    Result := GraphTop + Round((-ValueDb / -GRAPH_MIN_DB) *
      (GraphBottom - GraphTop));
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

  DelayMs := FSizeMs * 0.5;
  EffectiveLoop := FFeedback * FWet;
  FirstLevel := Max(0.000001, FWet * FMix);
  NodeCount := 1;
  NodeLevel := FirstLevel;
  while (NodeCount < MAX_GHOST_NODES) and
        (LinearToDb(NodeLevel) > GRAPH_MIN_DB) do
  begin
    Inc(NodeCount);
    NodeLevel := NodeLevel * EffectiveLoop;
  end;
  NodeCount := Max(3, NodeCount);
  DisplayMs := DelayMs * (NodeCount + 0.5);

  Canvas.Pen.Color := GRAPH_BORDER;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(ClientRect);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96),
    'Ghost shadow');
  TextValue := Format('First %s ms', [FormatFloat('0', DelayMs)]);
  Canvas.Font.Color := Accent;
  Canvas.TextOut(ClientWidth - Canvas.TextWidth(TextValue) -
    MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96), TextValue);

  AddedBar := Rect(MulDiv(38, FontPPI, 96), MulDiv(22, FontPPI, 96),
    ClientWidth - MulDiv(9, FontPPI, 96), MulDiv(32, FontPPI, 96));
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 130, 100);
  Canvas.FillRect(AddedBar);
  AddedDb := LinearToDb(FAddedRms);
  if FDataValid then
  begin
    FillX := AddedBar.Left + Round((AddedDb - GRAPH_MIN_DB) / -GRAPH_MIN_DB *
      (AddedBar.Right - AddedBar.Left));
    Canvas.Brush.Color := GRAPH_ADDED;
    Canvas.FillRect(Rect(AddedBar.Left, AddedBar.Top, FillX, AddedBar.Bottom));
    TextValue := FormatFloat('0.0 dB', AddedDb);
  end
  else
    TextValue := '-- dB';
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 72, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(20, FontPPI, 96), 'Added');
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(AddedBar.Right - Canvas.TextWidth(TextValue) -
    MulDiv(3, FontPPI, 96), MulDiv(20, FontPPI, 96), TextValue);

  TextValue := Format('Loop %s   Wet %s   Mix %s',
    [FormatFloat('0.00', EffectiveLoop), FormatFloat('0.00', FWet),
     FormatFloat('0.00', FMix)]);
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 68, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(38, FontPPI, 96), TextValue);

  GraphLeft := MulDiv(38, FontPPI, 96);
  GraphRight := ClientWidth - MulDiv(9, FontPPI, 96);
  GraphTop := MulDiv(55, FontPPI, 96);
  GraphBottom := ClientHeight - MulDiv(18, FontPPI, 96);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 118, 100);
  Canvas.FillRect(Rect(GraphLeft, GraphTop, GraphRight, GraphBottom));
  Canvas.Pen.Color := GRAPH_GRID;
  Canvas.MoveTo(GraphLeft, DbY(-30));
  Canvas.LineTo(GraphRight, DbY(-30));

  NodeLevel := FirstLevel;
  for Node := 0 to NodeCount - 1 do
  begin
    NodeDb := LinearToDb(NodeLevel);
    NodeX := GraphLeft + Round((DelayMs * (Node + 1)) / DisplayMs *
      (GraphRight - GraphLeft));
    NodeY := DbY(NodeDb);
    Points[Node] := Point(NodeX, NodeY);
    Canvas.Pen.Color := ScaleColor(Accent, 65, 100);
    Canvas.Pen.Width := 1;
    Canvas.MoveTo(NodeX, GraphBottom);
    Canvas.LineTo(NodeX, NodeY);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Accent;
    Canvas.Pen.Color := GRAPH_BACKGROUND;
    Canvas.Ellipse(NodeX - MulDiv(3, FontPPI, 96),
      NodeY - MulDiv(3, FontPPI, 96), NodeX + MulDiv(3, FontPPI, 96) + 1,
      NodeY + MulDiv(3, FontPPI, 96) + 1);
    NodeLevel := NodeLevel * EffectiveLoop;
  end;
  if NodeCount > 1 then
  begin
    Canvas.Pen.Color := Accent;
    Canvas.Pen.Width := 2;
    Canvas.Polyline(Slice(Points, NodeCount));
  end;

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 48, 100);
  Canvas.TextOut(MulDiv(4, FontPPI, 96), GraphTop -
    Canvas.TextHeight('0') div 2, '0');
  Canvas.TextOut(MulDiv(2, FontPPI, 96), GraphBottom -
    Canvas.TextHeight('0'), '-60');
  Canvas.TextOut(GraphLeft, GraphBottom + MulDiv(2, FontPPI, 96), '0s');
  TextValue := FormatFloat('0.00s', DisplayMs / 1000.0);
  Canvas.TextOut(GraphRight - Canvas.TextWidth(TextValue),
    GraphBottom + MulDiv(2, FontPPI, 96), TextValue);
end;

end.
