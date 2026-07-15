unit Aul2AudioControllerVolumeControl;

// Controllerで連続値を表示する音響機器風ノブの描画と値表示を担当する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls;

type
  TAul2VolumeControl = class(TCustomControl)
  private
    FAccentColor: TColor;
    FDisplayName: string;
    FMaximum: Double;
    FMinimum: Double;
    FUnitText: string;
    FValue: Double;
    FValueEdit: TEdit;
    FValueText: string;
    procedure LayoutValueEdit;
    procedure SetAccentColor(const Value: TColor);
    procedure SetDisplayName(const Value: string);
    procedure SetMaximum(const Value: Double);
    procedure SetMinimum(const Value: Double);
    procedure SetUnitText(const Value: string);
    procedure SetValue(const Value: Double);
    procedure SetValueText(const Value: string);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    // 表示名、値域、単位を一度に設定する。現段階では表示だけを行う。
    procedure Configure(const DisplayName: string; Minimum, Maximum: Double; const UnitText: string = '');
    property ValueText: string read FValueText write SetValueText;
  published
    property AccentColor: TColor read FAccentColor write SetAccentColor default $00D88A38;
    property Align;
    property Anchors;
    property DisplayName: string read FDisplayName write SetDisplayName;
    property Enabled;
    property Font;
    property Maximum: Double read FMaximum write SetMaximum;
    property Minimum: Double read FMinimum write SetMinimum;
    property ParentFont;
    property ShowHint;
    property UnitText: string read FUnitText write SetUnitText;
    property Value: Double read FValue write SetValue;
    property Visible;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  System.Types;

function ScaleColor(Color: TColor; Numerator, Denominator: Integer): TColor;
var
  Blue : Integer;
  Green: Integer;
  Red  : Integer;
begin
  Color := ColorToRGB(Color);
  Red := EnsureRange(GetRValue(Color) * Numerator div Denominator, 0, 255);
  Green := EnsureRange(GetGValue(Color) * Numerator div Denominator, 0, 255);
  Blue := EnsureRange(GetBValue(Color) * Numerator div Denominator, 0, 255);
  Result := RGB(Red, Green, Blue);
end;

procedure DrawKnobArc(Canvas: TCanvas; const Center: TPoint; Radius, StartDegree,
  EndDegree: Integer; Color: TColor; Width: Integer);
const
  ARC_SEGMENTS = 18;
var
  Angle       : Double;
  PointIndex  : Integer;
  Points      : array[0..ARC_SEGMENTS] of TPoint;
begin
  for PointIndex := 0 to ARC_SEGMENTS do
  begin
    Angle := DegToRad(StartDegree + (EndDegree - StartDegree) * PointIndex / ARC_SEGMENTS);
    Points[PointIndex] := Point(
      Center.X + Round(Cos(Angle) * Radius),
      Center.Y + Round(Sin(Angle) * Radius));
  end;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := Color;
  Canvas.Pen.Width := Width;
  Canvas.Polyline(Points);
end;

procedure DrawKnobLimitMark(Canvas: TCanvas; const Center: TPoint; Radius,
  Degree: Integer);
var
  Angle    : Double;
  InnerPoint: TPoint;
  OuterPoint: TPoint;
begin
  Angle := DegToRad(Degree);
  InnerPoint := Point(
    Center.X + Round(Cos(Angle) * (Radius + 2)),
    Center.Y + Round(Sin(Angle) * (Radius + 2)));
  OuterPoint := Point(
    Center.X + Round(Cos(Angle) * (Radius + 7)),
    Center.Y + Round(Sin(Angle) * (Radius + 7)));
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 2;
  Canvas.Pen.Color := RGB(118, 122, 127);
  Canvas.MoveTo(InnerPoint.X, InnerPoint.Y);
  Canvas.LineTo(OuterPoint.X, OuterPoint.Y);
end;

constructor TAul2VolumeControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // Parent接続や寸法変更でResize/Paintが発火する前に、子Editを完全に構築する。
  FValueEdit := TEdit.Create(Self);
  FValueEdit.ReadOnly := True;
  FValueEdit.TabStop := False;
  FValueEdit.Text := '0';
  FValueEdit.Alignment := taCenter;
  FValueEdit.BorderStyle := bsSingle;
  FValueEdit.Color := RGB(19, 21, 24);
  FValueEdit.Font.Color := RGB(248, 248, 248);
  FValueEdit.ParentFont := True;

  Width := 72;
  Height := 126;
  Color := RGB(31, 34, 38);
  ParentBackground := False;
  DoubleBuffered := True;
  TabStop := False;
  FAccentColor := RGB(56, 138, 216);
  FDisplayName := 'Value';
  FMinimum := 0;
  FMaximum := 1;
  FValue := 0;
  FValueText := '0';
  FValueEdit.Parent := Self;
  LayoutValueEdit;
end;

procedure TAul2VolumeControl.LayoutValueEdit;
var
  EditRight: Integer;
  EditTop  : Integer;
  FontPPI  : Integer;
  UnitWidth: Integer;
begin
  if not Assigned(FValueEdit) then
    Exit;

  // Handle生成前のResize/Configureからも呼ばれるため、Canvasには触れない。
  FontPPI := Font.PixelsPerInch;
  if FontPPI <= 0 then
    FontPPI := 96;
  if FUnitText <> '' then
    UnitWidth := Max(MulDiv(18, FontPPI, 96),
      MulDiv(Length(FUnitText) * 7 + 5, FontPPI, 96))
  else
    UnitWidth := 0;
  // ClientWidth/ClientHeightはHandleを要求するため、Parent接続前は保存済み寸法を使う。
  EditRight := Width - 6 - UnitWidth;
  EditTop := Min(Height - 27, 89);
  FValueEdit.SetBounds(6, EditTop, Max(24, EditRight - 6), 23);
end;

procedure TAul2VolumeControl.Configure(const DisplayName: string; Minimum, Maximum: Double;
  const UnitText: string);
begin
  FDisplayName := DisplayName;
  FMinimum := Minimum;
  FMaximum := Maximum;
  FUnitText := UnitText;
  FValue := EnsureRange(FValue, FMinimum, FMaximum);
  Invalidate;
end;

procedure TAul2VolumeControl.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TAul2VolumeControl.SetDisplayName(const Value: string);
begin
  if FDisplayName = Value then
    Exit;
  FDisplayName := Value;
  Invalidate;
end;

procedure TAul2VolumeControl.SetMaximum(const Value: Double);
begin
  if SameValue(FMaximum, Value) then
    Exit;
  FMaximum := Max(Value, FMinimum);
  SetValue(FValue);
  Invalidate;
end;

procedure TAul2VolumeControl.SetMinimum(const Value: Double);
begin
  if SameValue(FMinimum, Value) then
    Exit;
  FMinimum := Min(Value, FMaximum);
  SetValue(FValue);
  Invalidate;
end;

procedure TAul2VolumeControl.SetUnitText(const Value: string);
begin
  if FUnitText = Value then
    Exit;
  FUnitText := Value;
  LayoutValueEdit;
  Invalidate;
end;

procedure TAul2VolumeControl.SetValue(const Value: Double);
var
  NewValue: Double;
begin
  NewValue := EnsureRange(Value, FMinimum, FMaximum);
  if SameValue(FValue, NewValue) then
    Exit;
  FValue := NewValue;
  Invalidate;
end;

procedure TAul2VolumeControl.SetValueText(const Value: string);
var
  FormatSettings: TFormatSettings;
  NumberValue   : Double;
begin
  if FValueText = Value then
    Exit;

  FValueText := Value;
  if Assigned(FValueEdit) then
    FValueEdit.Text := Value;
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';
  if TryStrToFloat(Trim(Value), NumberValue, FormatSettings) then
    FValue := EnsureRange(NumberValue, FMinimum, FMaximum);
  Invalidate;
end;

procedure TAul2VolumeControl.Resize;
begin
  inherited;
  LayoutValueEdit;
end;

procedure TAul2VolumeControl.Paint;
var
  Angle       : Double;
  CardRect    : TRect;
  Center      : TPoint;
  KnobRadius  : Integer;
  LineEnd     : TPoint;
  LineStart   : TPoint;
  Ratio       : Double;
  TextRect    : TRect;
  UnitLeft    : Integer;
begin
  inherited;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  CardRect := Rect(1, 1, ClientWidth - 1, ClientHeight - 1);
  Canvas.Pen.Color := RGB(58, 62, 68);
  Canvas.Brush.Color := RGB(34, 37, 41);
  Canvas.RoundRect(CardRect.Left, CardRect.Top, CardRect.Right, CardRect.Bottom, 9, 9);

  Canvas.Font.Assign(Font);
  Canvas.Font.Color := RGB(232, 232, 232);
  Canvas.Font.Style := [fsBold];
  Canvas.Brush.Style := bsClear;
  TextRect := Rect(3, 7, ClientWidth - 3, 25);
  DrawText(Canvas.Handle, PChar(FDisplayName), -1, TextRect,
    DT_CENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_VCENTER);

  KnobRadius := Min(ClientWidth div 2 - 7, 27);
  KnobRadius := Max(KnobRadius, 18);
  Center := Point(ClientWidth div 2, 57);

  DrawKnobLimitMark(Canvas, Center, KnobRadius, 135);
  DrawKnobLimitMark(Canvas, Center, KnobRadius, 405);

  Canvas.Pen.Style := psClear;
  Canvas.Brush.Color := RGB(10, 11, 12);
  Canvas.Ellipse(Center.X - KnobRadius + 2, Center.Y - KnobRadius + 4,
    Center.X + KnobRadius + 2, Center.Y + KnobRadius + 4);
  Canvas.Brush.Color := RGB(82, 86, 91);
  Canvas.Ellipse(Center.X - KnobRadius, Center.Y - KnobRadius,
    Center.X + KnobRadius, Center.Y + KnobRadius);
  Canvas.Brush.Color := RGB(13, 14, 16);
  Canvas.Ellipse(Center.X - KnobRadius + 2, Center.Y - KnobRadius + 2,
    Center.X + KnobRadius - 2, Center.Y + KnobRadius - 2);
  Canvas.Brush.Color := RGB(27, 29, 33);
  Canvas.Ellipse(Center.X - KnobRadius + 4, Center.Y - KnobRadius + 4,
    Center.X + KnobRadius - 4, Center.Y + KnobRadius - 4);
  Canvas.Brush.Color := RGB(36, 39, 43);
  Canvas.Ellipse(Center.X - KnobRadius + 7, Center.Y - KnobRadius + 6,
    Center.X + KnobRadius - 7, Center.Y + KnobRadius - 8);
  Canvas.Brush.Color := RGB(43, 46, 50);
  Canvas.Ellipse(Center.X - KnobRadius + 11, Center.Y - KnobRadius + 10,
    Center.X + KnobRadius - 10, Center.Y + KnobRadius - 12);

  DrawKnobArc(Canvas, Center, KnobRadius - 3, 190, 300, RGB(112, 116, 121), 2);
  DrawKnobArc(Canvas, Center, KnobRadius - 3, 10, 120, RGB(8, 9, 10), 2);
  DrawKnobArc(Canvas, Point(Center.X - 1, Center.Y - 1), KnobRadius - 7,
    205, 290, RGB(64, 68, 73), 1);

  if FMaximum > FMinimum then
    Ratio := EnsureRange((FValue - FMinimum) / (FMaximum - FMinimum), 0.0, 1.0)
  else
    Ratio := 0;
  Angle := DegToRad(135 + Ratio * 270);

  LineStart := Point(
    Center.X + Round(Cos(Angle) * (KnobRadius * 0.27)),
    Center.Y + Round(Sin(Angle) * (KnobRadius * 0.27)));
  LineEnd := Point(
    Center.X + Round(Cos(Angle) * (KnobRadius * 0.72)),
    Center.Y + Round(Sin(Angle) * (KnobRadius * 0.72)));
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := Max(3, KnobRadius div 6);
  Canvas.Pen.Color := RGB(7, 8, 9);
  Canvas.MoveTo(LineStart.X + 1, LineStart.Y + 1);
  Canvas.LineTo(LineEnd.X + 1, LineEnd.Y + 1);
  Canvas.Pen.Color := ScaleColor(FAccentColor, 5, 4);
  Canvas.MoveTo(LineStart.X, LineStart.Y);
  Canvas.LineTo(LineEnd.X, LineEnd.Y);
  Canvas.Pen.Style := psClear;
  Canvas.Brush.Color := ScaleColor(FAccentColor, 5, 4);
  Canvas.Ellipse(LineEnd.X - 2, LineEnd.Y - 2, LineEnd.X + 3, LineEnd.Y + 3);

  if (FUnitText <> '') and Assigned(FValueEdit) then
  begin
    UnitLeft := FValueEdit.Left + FValueEdit.Width + 3;
    TextRect := Rect(UnitLeft, FValueEdit.Top, ClientWidth - 4,
      FValueEdit.Top + FValueEdit.Height);
    Canvas.Font.Style := [];
    Canvas.Font.Color := RGB(188, 192, 197);
    Canvas.Brush.Style := bsClear;
    DrawText(Canvas.Handle, PChar(FUnitText), -1, TextRect,
      DT_LEFT or DT_SINGLELINE or DT_END_ELLIPSIS or DT_VCENTER);
  end;
end;

end.
