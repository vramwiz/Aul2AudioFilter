unit Aul2AudioControllerReverbGraph;

// Reverbの最新Wet RMSと設定上の減衰カーブを描画する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics;

type
  TAul2ControllerReverbGraph = class(TCustomControl)
  private
    FAccentColor: TColor;
    FActive: Boolean;
    FDamping: Double;
    FDataValid: Boolean;
    FDry: Double;
    FReverbType: Integer;
    FRoomSize: Double;
    FWet: Double;
    FWetRms: Single;
    procedure SetAccentColor(const Value: TColor);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ClearSnapshot;
    procedure SetReverb(ReverbType: Integer; RoomSize, Damping, Dry,
      Wet: Double; Active: Boolean);
    procedure SetSnapshot(WetRms: Single);
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
  GRAPH_WET = TColor($007ABE5C);
  GRAPH_HF = TColor($00FFD248);
  GRAPH_MIN_DB = -60.0;

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

function ReverbFeedback(ReverbType: Integer; RoomSize: Double): Double;
begin
  case EnsureRange(ReverbType, 0, 2) of
    1: Result := 0.24 + RoomSize * 0.68;
    2: Result := 0.18 + RoomSize * 0.62;
  else
    Result := 0.16 + RoomSize * 0.55;
  end;
  Result := Min(0.92, Result);
end;

function EffectiveDamping(ReverbType: Integer; Damping: Double): Double;
begin
  case EnsureRange(ReverbType, 0, 2) of
    0: Result := Damping * 1.10;
    2: Result := Damping * 0.45;
  else
    Result := Damping;
  end;
  Result := EnsureRange(Result, 0.0, 1.0);
end;

function AverageDelayMs(ReverbType: Integer): Double;
begin
  case EnsureRange(ReverbType, 0, 2) of
    1: Result := 37.85;
    2: Result := 23.20;
  else
    Result := 26.51;
  end;
end;

function ReverbTypeName(ReverbType: Integer): string;
begin
  case EnsureRange(ReverbType, 0, 2) of
    1: Result := 'Hall';
    2: Result := 'Plate';
  else
    Result := 'Room';
  end;
end;

constructor TAul2ControllerReverbGraph.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  ParentBackground := False;
  Color := GRAPH_BACKGROUND;
  FAccentColor := TColor($0048B0E0);
  FActive := True;
  FReverbType := 0;
  FRoomSize := 0.5;
  FDamping := 0.4;
  FDry := 1.0;
  FWet := 0.3;
  ClearSnapshot;
end;

procedure TAul2ControllerReverbGraph.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2ControllerReverbGraph.ClearSnapshot;
begin
  FDataValid := False;
  FWetRms := 0;
  Invalidate;
end;

procedure TAul2ControllerReverbGraph.SetReverb(ReverbType: Integer; RoomSize,
  Damping, Dry, Wet: Double; Active: Boolean);
begin
  FReverbType := EnsureRange(ReverbType, 0, 2);
  FRoomSize := EnsureRange(RoomSize, 0.0, 1.0);
  FDamping := EnsureRange(Damping, 0.0, 1.0);
  FDry := EnsureRange(Dry, 0.0, 2.0);
  FWet := EnsureRange(Wet, 0.0, 2.0);
  FActive := Active;
  Invalidate;
end;

procedure TAul2ControllerReverbGraph.SetSnapshot(WetRms: Single);
begin
  FWetRms := Max(0.0, WetRms);
  FDataValid := True;
  Invalidate;
end;

procedure TAul2ControllerReverbGraph.Paint;
var
  Accent: TColor;
  CurveBottom: Integer;
  CurveDb: Double;
  CurveLeft: Integer;
  CurveRight: Integer;
  CurveTop: Integer;
  Damping: Double;
  DisplaySeconds: Double;
  Feedback: Double;
  FontPPI: Integer;
  HfFeedback: Double;
  HfPoints: array[0..CURVE_POINT_COUNT - 1] of TPoint;
  Index: Integer;
  Points: array[0..CURVE_POINT_COUNT - 1] of TPoint;
  Rt60: Double;
  Seconds: Double;
  TextValue: string;
  WetBar: TRect;
  WetDb: Double;
  WetFillX: Integer;

  function CurveY(ValueDb: Double): Integer;
  begin
    ValueDb := EnsureRange(ValueDb, GRAPH_MIN_DB, 0.0);
    Result := CurveTop + Round((-ValueDb / -GRAPH_MIN_DB) *
      (CurveBottom - CurveTop));
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

  Feedback := ReverbFeedback(FReverbType, FRoomSize);
  Damping := EffectiveDamping(FReverbType, FDamping);
  Rt60 := (AverageDelayMs(FReverbType) / 1000.0) *
    (-60.0 / (20.0 * Log10(Feedback)));
  DisplaySeconds := EnsureRange(Rt60 * 1.15, 0.25, 3.0);
  HfFeedback := Max(0.000001, Feedback *
    ((1.0 - Damping) / Max(0.000001, 1.0 + Damping)));

  Canvas.Pen.Color := GRAPH_BORDER;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(ClientRect);
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96),
    'Wet reverb / decay');
  TextValue := ReverbTypeName(FReverbType) + '  RT60 ' +
    FormatFloat('0.00 s', Rt60);
  Canvas.Font.Color := Accent;
  Canvas.TextOut(ClientWidth - Canvas.TextWidth(TextValue) -
    MulDiv(8, FontPPI, 96), MulDiv(4, FontPPI, 96), TextValue);

  WetBar := Rect(MulDiv(38, FontPPI, 96), MulDiv(21, FontPPI, 96),
    ClientWidth - MulDiv(9, FontPPI, 96), MulDiv(31, FontPPI, 96));
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 130, 100);
  Canvas.FillRect(WetBar);
  WetDb := LinearToDb(FWetRms);
  if FDataValid then
  begin
    WetFillX := WetBar.Left + Round((WetDb - GRAPH_MIN_DB) / -GRAPH_MIN_DB *
      (WetBar.Right - WetBar.Left));
    Canvas.Brush.Color := GRAPH_WET;
    Canvas.FillRect(Rect(WetBar.Left, WetBar.Top, WetFillX, WetBar.Bottom));
    TextValue := FormatFloat('0.0 dB', WetDb);
  end
  else
    TextValue := '-- dB';
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 72, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(19, FontPPI, 96), 'Wet');
  Canvas.Font.Color := GRAPH_TEXT;
  Canvas.TextOut(WetBar.Right - Canvas.TextWidth(TextValue) -
    MulDiv(3, FontPPI, 96), MulDiv(19, FontPPI, 96), TextValue);

  TextValue := Format('FB %s   Damp %s   Dry %s   Wet %s',
    [FormatFloat('0.00', Feedback), FormatFloat('0.00', Damping),
     FormatFloat('0.00', FDry), FormatFloat('0.00', FWet)]);
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 66, 100);
  Canvas.TextOut(MulDiv(8, FontPPI, 96), MulDiv(36, FontPPI, 96), TextValue);

  CurveLeft := MulDiv(38, FontPPI, 96);
  CurveRight := ClientWidth - MulDiv(9, FontPPI, 96);
  CurveTop := MulDiv(51, FontPPI, 96);
  CurveBottom := ClientHeight - MulDiv(15, FontPPI, 96);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 118, 100);
  Canvas.FillRect(Rect(CurveLeft, CurveTop, CurveRight, CurveBottom));
  Canvas.Pen.Color := GRAPH_GRID;
  Canvas.MoveTo(CurveLeft, CurveY(-30));
  Canvas.LineTo(CurveRight, CurveY(-30));

  for Index := 0 to CURVE_POINT_COUNT - 1 do
  begin
    Seconds := DisplaySeconds * Index / (CURVE_POINT_COUNT - 1);
    CurveDb := 20.0 * Log10(Feedback) * Seconds /
      (AverageDelayMs(FReverbType) / 1000.0);
    Points[Index] := Point(CurveLeft + Round(Index /
      (CURVE_POINT_COUNT - 1) * (CurveRight - CurveLeft)), CurveY(CurveDb));
    CurveDb := 20.0 * Log10(HfFeedback) * Seconds /
      (AverageDelayMs(FReverbType) / 1000.0);
    HfPoints[Index] := Point(Points[Index].X, CurveY(CurveDb));
  end;
  Canvas.Pen.Color := GRAPH_HF;
  Canvas.Pen.Width := 1;
  Canvas.Polyline(HfPoints);
  Canvas.Pen.Color := Accent;
  Canvas.Pen.Width := 2;
  Canvas.Polyline(Points);

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := ScaleColor(GRAPH_BACKGROUND, 118, 100);
  Canvas.FillRect(Rect(CurveRight - MulDiv(50, FontPPI, 96),
    CurveTop + MulDiv(1, FontPPI, 96), CurveRight,
    CurveTop + Canvas.TextHeight('HF') + MulDiv(3, FontPPI, 96)));
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := Accent;
  Canvas.TextOut(CurveRight - MulDiv(47, FontPPI, 96),
    CurveTop + MulDiv(1, FontPPI, 96), 'Tail');
  Canvas.Font.Color := GRAPH_HF;
  Canvas.TextOut(CurveRight - MulDiv(22, FontPPI, 96),
    CurveTop + MulDiv(1, FontPPI, 96), 'HF');

  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := ScaleColor(GRAPH_TEXT, 48, 100);
  Canvas.TextOut(MulDiv(4, FontPPI, 96), CurveTop -
    Canvas.TextHeight('0') div 2, '0');
  Canvas.TextOut(MulDiv(2, FontPPI, 96), CurveBottom -
    Canvas.TextHeight('0'), '-60');
  Canvas.TextOut(CurveLeft, CurveBottom + MulDiv(1, FontPPI, 96), '0s');
  TextValue := FormatFloat('0.00s', DisplaySeconds);
  Canvas.TextOut(CurveRight - Canvas.TextWidth(TextValue),
    CurveBottom + MulDiv(1, FontPPI, 96), TextValue);
end;

end.
