unit Aul2AudioMonitorVectorscope;

// Monitorの処理前/処理後Vectorscopeを同一倍率で描画する。

interface

uses
  System.Types,
  Vcl.Graphics,
  Aul2AudioMonitorVectorShared;

// 処理前と処理後のL/R代表点を左右または上下へ並べて描画する。
procedure DrawAudioVectorscopeCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorVectorState);

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils;

function VectorStateValid(State: PAul2AudioMonitorVectorState): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_MONITOR_VECTOR_SHARED_MAGIC) and
    (State^.Version = AUDIO_MONITOR_VECTOR_SHARED_VERSION) and
    (State^.UpdateTick <> 0);
end;

function VectorHorizontal(LeftValue, RightValue: Single): Single;
begin
  Result := (RightValue - LeftValue) * 0.5;
end;

function VectorVertical(LeftValue, RightValue: Single): Single;
begin
  Result := (LeftValue + RightValue) * 0.5;
end;

function VectorPairMaximum(LeftValue, RightValue: Single): Single;
begin
  Result := Max(Abs(VectorHorizontal(LeftValue, RightValue)),
    Abs(VectorVertical(LeftValue, RightValue)));
end;

function CalculateViewGain(State: PAul2AudioMonitorVectorState): Single;
var
  Index: Integer;
  Maximum: Single;
begin
  Maximum := 0;
  for Index := 0 to AUDIO_MONITOR_VECTOR_POINT_LAST do
  begin
    Maximum := Max(Maximum,
      VectorPairMaximum(State^.InputLeft[Index], State^.InputRight[Index]));
    Maximum := Max(Maximum,
      VectorPairMaximum(State^.OutputLeft[Index], State^.OutputRight[Index]));
  end;

  if Maximum <= 0.0001 then
    Exit(1.0);
  Result := EnsureRange(0.86 / Maximum, 1.0, 4.0);
end;

procedure DrawDiamond(Canvas: TCanvas; const ScopeRect: TRect);
var
  Center: TPoint;
  HalfSize: Integer;
  InnerSize: Integer;
begin
  Center := Point((ScopeRect.Left + ScopeRect.Right) div 2,
    (ScopeRect.Top + ScopeRect.Bottom) div 2);
  HalfSize := Min(ScopeRect.Right - ScopeRect.Left,
    ScopeRect.Bottom - ScopeRect.Top) div 2 - 4;
  if HalfSize < 8 then
    Exit;

  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := RGB(68, 68, 68);
  Canvas.MoveTo(Center.X, Center.Y - HalfSize);
  Canvas.LineTo(Center.X + HalfSize, Center.Y);
  Canvas.LineTo(Center.X, Center.Y + HalfSize);
  Canvas.LineTo(Center.X - HalfSize, Center.Y);
  Canvas.LineTo(Center.X, Center.Y - HalfSize);

  InnerSize := HalfSize div 2;
  Canvas.Pen.Color := RGB(50, 50, 50);
  Canvas.MoveTo(Center.X, Center.Y - InnerSize);
  Canvas.LineTo(Center.X + InnerSize, Center.Y);
  Canvas.LineTo(Center.X, Center.Y + InnerSize);
  Canvas.LineTo(Center.X - InnerSize, Center.Y);
  Canvas.LineTo(Center.X, Center.Y - InnerSize);
  Canvas.MoveTo(Center.X, Center.Y - HalfSize);
  Canvas.LineTo(Center.X, Center.Y + HalfSize);
  Canvas.MoveTo(Center.X - HalfSize, Center.Y);
  Canvas.LineTo(Center.X + HalfSize, Center.Y);

  Canvas.Font.Color := RGB(130, 130, 130);
  Canvas.TextOut(Center.X - HalfSize + 3, Center.Y - 15, 'L');
  Canvas.TextOut(Center.X + HalfSize - 12, Center.Y - 15, 'R');
end;

procedure DrawVectorTrace(Canvas: TCanvas; const ScopeRect: TRect;
  const LeftData, RightData: TAudioMonitorVectorData; Gain: Single; Color: TColor);
var
  Center: TPoint;
  HalfSize: Integer;
  Index: Integer;
  PointX: Integer;
  PointY: Integer;
  ValueX: Single;
  ValueY: Single;
begin
  Center := Point((ScopeRect.Left + ScopeRect.Right) div 2,
    (ScopeRect.Top + ScopeRect.Bottom) div 2);
  HalfSize := Min(ScopeRect.Right - ScopeRect.Left,
    ScopeRect.Bottom - ScopeRect.Top) div 2 - 6;
  if HalfSize < 8 then
    Exit;

  Canvas.Pen.Color := Color;
  Canvas.Pen.Width := 1;
  for Index := 0 to AUDIO_MONITOR_VECTOR_POINT_LAST do
  begin
    ValueX := EnsureRange(VectorHorizontal(LeftData[Index], RightData[Index]) * Gain,
      -1.0, 1.0);
    ValueY := EnsureRange(VectorVertical(LeftData[Index], RightData[Index]) * Gain,
      -1.0, 1.0);
    PointX := Center.X + Round(ValueX * HalfSize);
    PointY := Center.Y - Round(ValueY * HalfSize);
    if Index = 0 then
      Canvas.MoveTo(PointX, PointY)
    else
      Canvas.LineTo(PointX, PointY);
  end;
end;

procedure DrawScopePanel(Canvas: TCanvas; const PanelRect: TRect; const Caption: string;
  CaptionColor: TColor; const LeftData, RightData: TAudioMonitorVectorData; Gain: Single);
var
  ScopeRect: TRect;
  ScopeSize: Integer;
begin
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := CaptionColor;
  Canvas.TextOut(PanelRect.Left, PanelRect.Top, Caption);

  ScopeSize := Min(PanelRect.Right - PanelRect.Left,
    PanelRect.Bottom - PanelRect.Top - 18);
  ScopeRect.Left := (PanelRect.Left + PanelRect.Right - ScopeSize) div 2;
  ScopeRect.Top := PanelRect.Top + 18;
  ScopeRect.Right := ScopeRect.Left + ScopeSize;
  ScopeRect.Bottom := ScopeRect.Top + ScopeSize;
  DrawDiamond(Canvas, ScopeRect);
  DrawVectorTrace(Canvas, ScopeRect, LeftData, RightData, Gain, CaptionColor);
end;

procedure DrawAudioVectorscopeCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorVectorState);
var
  CaptionText: string;
  ContentRect: TRect;
  InputRect: TRect;
  OutputRect: TRect;
  Split: Integer;
  ViewGain: Single;
begin
  Canvas.Brush.Color := RGB(36, 36, 36);
  Canvas.FillRect(ClientRect);
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Brush.Style := bsClear;

  try
    if not VectorStateValid(State) then
    begin
      Canvas.Font.Color := RGB(220, 220, 220);
      Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
        'Vectorscope - waiting audio data');
      Exit;
    end;

    CaptionText := Format('Vectorscope  %d Hz  %d ch  Layer %d',
      [State^.SampleRate, State^.ChannelNum, State^.SourceLayer + 1]);
    Canvas.Font.Color := RGB(220, 220, 220);
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8, CaptionText);

    ContentRect := ClientRect;
    InflateRect(ContentRect, -12, -12);
    Inc(ContentRect.Top, 24);
    if (ContentRect.Right - ContentRect.Left < 80) or
       (ContentRect.Bottom - ContentRect.Top < 80) then
      Exit;

    if (ContentRect.Right - ContentRect.Left) >=
       (ContentRect.Bottom - ContentRect.Top) then
    begin
      Split := (ContentRect.Left + ContentRect.Right) div 2;
      InputRect := Rect(ContentRect.Left, ContentRect.Top, Split - 4, ContentRect.Bottom);
      OutputRect := Rect(Split + 4, ContentRect.Top, ContentRect.Right, ContentRect.Bottom);
    end
    else
    begin
      Split := (ContentRect.Top + ContentRect.Bottom) div 2;
      InputRect := Rect(ContentRect.Left, ContentRect.Top, ContentRect.Right, Split - 4);
      OutputRect := Rect(ContentRect.Left, Split + 4, ContentRect.Right, ContentRect.Bottom);
    end;

    ViewGain := CalculateViewGain(State);
    DrawScopePanel(Canvas, InputRect, 'Input', RGB(92, 190, 122),
      State^.InputLeft, State^.InputRight, ViewGain);
    DrawScopePanel(Canvas, OutputRect, 'Output', RGB(224, 176, 72),
      State^.OutputLeft, State^.OutputRight, ViewGain);
  except
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := RGB(220, 220, 220);
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
      'Vectorscope - draw error');
  end;

  Canvas.Brush.Style := bsSolid;
end;

end.
