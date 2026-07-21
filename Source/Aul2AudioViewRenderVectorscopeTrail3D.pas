unit Aul2AudioViewRenderVectorscopeTrail3D;

// Vectorscopeの時刻別点列をZ方向へ複数層並べ、ステレオ軌跡を立体表示する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

function DrawVectorscopeTrail3D(Video: PFILTER_PROC_VIDEO;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer): Boolean;

implementation

uses
  System.Math,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewSpectrum,
  Aul2AudioViewVector,
  Aul2AudioViewVectorShared;

type
  TVertexColorArray = array of TVERTEX_COLOR;
  TPoint3D = record
    X, Y, Z: Single;
  end;

const
  VECTOR_TRAIL_XY_SENSITIVITY = 2.5; // 通常音量でも指定解像度を使いやすくするType専用感度。
  VECTOR_TRAIL_Z_SENSITIVITY = 8.0;  // 履歴層の奥行きを確認しやすくするZ Scale専用感度。

var
  LastEditHistory: TAudioViewVectorHistory;
  LastEditHistoryValid: Boolean;
  LastEditSourceLayer: Integer = -1;
  FlowHistory: TAudioViewVectorHistory;
  FlowLastFrame: Integer = -1;
  FlowSourceLayer: Integer = -1;

function FramePeak(const Frame: TAudioViewVectorFrame): Single;
var
  Point: Integer;
begin
  Result := 0.0;
  for Point := 0 to AUDIO_VIEW_VECTOR_POINT_LAST do
  begin
    Result := Max(Result, Abs(Frame.Left[Point]));
    Result := Max(Result, Abs(Frame.Right[Point]));
  end;
end;

function HistoryPeak(const History: TAudioViewVectorHistory): Single;
var
  Row: Integer;
begin
  Result := 0.0;
  for Row := 0 to Length(History) - 1 do
    Result := Max(Result, FramePeak(History[Row]));
end;

procedure CopyHistory(const Source: TAudioViewVectorHistory;
  out Dest: TAudioViewVectorHistory);
var
  Row: Integer;
begin
  SetLength(Dest, Length(Source));
  for Row := 0 to Length(Source) - 1 do
    Dest[Row] := Source[Row];
end;

procedure PushFlowFrame(const Frame: TAudioViewVectorFrame; MaxRows: Integer);
var
  NewHistory: TAudioViewVectorHistory;
  Row: Integer;
  NewCount: Integer;
begin
  NewCount := Min(MaxRows, Length(FlowHistory) + 1);
  SetLength(NewHistory, NewCount);
  if NewCount <= 0 then
    Exit;
  NewHistory[0] := Frame;
  for Row := 1 to NewCount - 1 do
    NewHistory[Row] := FlowHistory[Row - 1];
  FlowHistory := NewHistory;
end;

procedure ResolvePlaybackFlow(var History: TAudioViewVectorHistory;
  var Valid: Boolean; const CurrentFrameData: TAudioViewVectorFrame;
  CurrentValid: Boolean; CurrentFrame, SourceLayer, MaxRows: Integer);
var
  EmptyFrame: TAudioViewVectorFrame;
  NewFrame: TAudioViewVectorFrame;
  Step: Integer;
  AdvanceCount: Integer;
begin
  if SourceLayer <> FlowSourceLayer then
  begin
    SetLength(FlowHistory, 0);
    FlowLastFrame := -1;
    FlowSourceLayer := SourceLayer;
  end;

  // 編集停止中は共有履歴を直接使い、カーソル位置へ追従する。
  if GetViewEditState = 0 then
    Exit;

  FillChar(EmptyFrame, SizeOf(EmptyFrame), 0);
  if CurrentValid and (FramePeak(CurrentFrameData) > 0.0001) then
    NewFrame := CurrentFrameData
  else
    // 無音時は中心点を描かず、既存層を押し出すための空層を追加する。
    NewFrame := EmptyFrame;

  if (FlowLastFrame < 0) or (CurrentFrame < FlowLastFrame) or
     (CurrentFrame - FlowLastFrame > MaxRows) then
  begin
    if Valid then
      CopyHistory(History, FlowHistory)
    else
      SetLength(FlowHistory, 0);
    FlowLastFrame := CurrentFrame;
  end
  else if CurrentFrame > FlowLastFrame then
  begin
    AdvanceCount := Min(MaxRows, CurrentFrame - FlowLastFrame);
    for Step := 1 to AdvanceCount do
      PushFlowFrame(NewFrame, MaxRows);
    FlowLastFrame := CurrentFrame;
  end
  else if Length(FlowHistory) > 0 then
    FlowHistory[0] := NewFrame;

  if Length(FlowHistory) > 0 then
  begin
    CopyHistory(FlowHistory, History);
    Valid := True;
  end;
end;

procedure ResolveEditHistory(var History: TAudioViewVectorHistory;
  var Valid: Boolean; SourceLayer: Integer);
var
  Peak: Single;
begin
  if SourceLayer <> LastEditSourceLayer then
  begin
    SetLength(LastEditHistory, 0);
    LastEditHistoryValid := False;
    LastEditSourceLayer := SourceLayer;
  end;

  Peak := HistoryPeak(History);
  if Valid and (Peak > 0.0001) then
  begin
    CopyHistory(History, LastEditHistory);
    LastEditHistoryValid := True;
  end;
  if (GetViewEditState = 0) and ((not Valid) or (Peak <= 0.0001)) and
     LastEditHistoryValid then
  begin
    CopyHistory(LastEditHistory, History);
    Valid := True;
  end;
end;

procedure SmoothHistory(var History: TAudioViewVectorHistory; Smooth: Integer);
var
  Blend: Single;
  Row: Integer;
  Point: Integer;
begin
  if Length(History) < 2 then
    Exit;
  Blend := Max(0, Min(100, Smooth)) / 100.0 * 0.85;
  if Blend <= 0.0 then
    Exit;
  for Row := 1 to Length(History) - 1 do
    for Point := 0 to AUDIO_VIEW_VECTOR_POINT_LAST do
    begin
      History[Row].Left[Point] := EnsureRange(
        History[Row].Left[Point] +
        ((History[Row - 1].Left[Point] - History[Row].Left[Point]) * Blend),
        -1.0, 1.0);
      History[Row].Right[Point] := EnsureRange(
        History[Row].Right[Point] +
        ((History[Row - 1].Right[Point] - History[Row].Right[Point]) * Blend),
        -1.0, 1.0);
    end;
end;

procedure SetVertex(var Vertex: TVERTEX_COLOR; const Point: TPoint3D;
  ZScale: Single; R, G, B: Byte);
begin
  Vertex.X := Point.X;
  Vertex.Y := Point.Y;
  Vertex.Z := Point.Z * ZScale;
  Vertex.R := R / 255.0;
  Vertex.G := G / 255.0;
  Vertex.B := B / 255.0;
  Vertex.A := 1.0;
end;

procedure SetScopePoint(var Dest: TPoint3D; const Frame: TAudioViewVectorFrame;
  SourcePoint: Integer; Z, ScopeHalfWidth, ScopeHalfHeight,
  XScale, YScale: Single);
var
  ScopeX: Single;
  ScopeY: Single;
begin
  ScopeX := (Frame.Left[SourcePoint] - Frame.Right[SourcePoint]) * 0.5 * XScale;
  ScopeY := (Frame.Left[SourcePoint] + Frame.Right[SourcePoint]) * 0.5 * YScale;
  Dest.X := EnsureRange(ScopeX, -1.0, 1.0) * ScopeHalfWidth;
  Dest.Y := -EnsureRange(ScopeY, -1.0, 1.0) * ScopeHalfHeight;
  Dest.Z := Z;
end;

function DrawVectorscopeTrail3D(Video: PFILTER_PROC_VIDEO;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer): Boolean;
var
  History: TAudioViewVectorHistory;
  Valid: Boolean;
  CurrentLeft, CurrentRight: TAudioViewVectorData;
  CurrentValid: Boolean;
  CurrentFrameData: TAudioViewVectorFrame;
  Vertices: TVertexColorArray;
  PointCount: Integer;
  RequestedRows: Integer;
  RowCount: Integer;
  Row: Integer;
  Point: Integer;
  SourcePoint: Integer;
  NextSourcePoint: Integer;
  VertexIndex: Integer;
  ScopeHalfWidth: Single;
  ScopeHalfHeight: Single;
  XScale, YScale, ZScale: Single;
  DepthStep: Single;
  Z: Single;
  HalfThickness: Single;
  Dx, Dy, LineLength: Single;
  Nx, Ny: Single;
  P0, P1, P2, P3: TPoint3D;
  C0, C1: TPoint3D;
  R, G, B: Byte;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or not Assigned(Video^.DrawPoly) then
    Exit;

  PointCount := Max(4, Min(AUDIO_VIEW_VECTOR_POINT_COUNT, Settings.Density));
  RequestedRows := Max(4, Min(32, Settings.Density));
  GetViewVectorHistory(CurrentFrame, Settings.SourceLayer, RequestedRows,
    History, Valid);
  UpdateViewVector(CurrentLeft, CurrentRight, CurrentValid,
    CurrentFrame, Settings.SourceLayer);
  FillChar(CurrentFrameData, SizeOf(CurrentFrameData), 0);
  if CurrentValid then
  begin
    CurrentFrameData.Left := CurrentLeft;
    CurrentFrameData.Right := CurrentRight;
    if Length(History) = 0 then
      SetLength(History, 1);
    History[0] := CurrentFrameData;
    Valid := True;
  end;
  if (GetViewEditState = 0) and
     ((not CurrentValid) or (FramePeak(CurrentFrameData) <= 0.0001)) then
  begin
    Result := True;
    if Assigned(Video^.SetDefaultAnchor) then
      Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
    Exit;
  end;
  ResolvePlaybackFlow(History, Valid, CurrentFrameData, CurrentValid,
    CurrentFrame, Settings.SourceLayer, RequestedRows);
  ResolveEditHistory(History, Valid, Settings.SourceLayer);
  if not Valid or (Length(History) = 0) then
  begin
    Result := True;
    if Assigned(Video^.SetDefaultAnchor) then
      Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
    Exit;
  end;
  SmoothHistory(History, Settings.Smooth);

  RowCount := Max(2, Length(History));
  // 正方形へ制限せず、Xは指定Width、Yは指定Heightをそれぞれ描画範囲に使う。
  ScopeHalfWidth := Max(16.0, Video^.Object_^.Width * 0.45);
  ScopeHalfHeight := Max(16.0, Video^.Object_^.Height * 0.45);
  // 全体を専用感度で広げつつ、左右差は2D Vectorscopeと同じ相対10倍を維持する。
  XScale := Max(10, Min(500, Settings.XScale)) / 100.0 *
    10.0 * VECTOR_TRAIL_XY_SENSITIVITY;
  YScale := Max(10, Min(500, Settings.YScale)) / 100.0 *
    VECTOR_TRAIL_XY_SENSITIVITY;
  ZScale := Max(10, Min(500, Settings.ZScale)) / 100.0 *
    VECTOR_TRAIL_Z_SENSITIVITY;
  DepthStep := 1.0 + Max(0, Min(32, Settings.Spacing));
  HalfThickness := Max(0.5, Min(32, Settings.Thickness) * 0.5);
  VertexIndex := 0;

  if Settings.Style = VIEW_STYLE_BLOCKS then
  begin
    // 各時刻の代表点を独立した正方形として描き、層同士も接続しない。
    SetLength(Vertices, RowCount * PointCount * 4);
    for Row := 0 to RowCount - 1 do
    begin
      if FramePeak(History[Min(Row, Length(History) - 1)]) <= 0.0001 then
        Continue;
      Z := (Row - (RowCount - 1) * 0.5) * DepthStep;
      for Point := 0 to PointCount - 1 do
      begin
        SourcePoint := Point * AUDIO_VIEW_VECTOR_POINT_LAST div Max(1, PointCount - 1);
        SetScopePoint(C0, History[Min(Row, Length(History) - 1)], SourcePoint,
          Z, ScopeHalfWidth, ScopeHalfHeight, XScale, YScale);
        P0 := C0; P0.X := P0.X - HalfThickness; P0.Y := P0.Y - HalfThickness;
        P1 := C0; P1.X := P1.X - HalfThickness; P1.Y := P1.Y + HalfThickness;
        P2 := C0; P2.X := P2.X + HalfThickness; P2.Y := P2.Y + HalfThickness;
        P3 := C0; P3.X := P3.X + HalfThickness; P3.Y := P3.Y - HalfThickness;
        GetViewColor(Settings, Point, PointCount, R, G, B);
        SetVertex(Vertices[VertexIndex], P0, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 1], P1, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 2], P2, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 3], P3, ZScale, R, G, B);
        Inc(VertexIndex, 4);
      end;
    end;
  end
  else
  begin
    // 各時刻の点列だけを厚み付きリボンで結び、履歴層同士は接続しない。
    SetLength(Vertices, RowCount * (PointCount - 1) * 4);
    for Row := 0 to RowCount - 1 do
    begin
      if FramePeak(History[Min(Row, Length(History) - 1)]) <= 0.0001 then
        Continue;
      Z := (Row - (RowCount - 1) * 0.5) * DepthStep;
      for Point := 0 to PointCount - 2 do
      begin
        SourcePoint := Point * AUDIO_VIEW_VECTOR_POINT_LAST div Max(1, PointCount - 1);
        NextSourcePoint := (Point + 1) * AUDIO_VIEW_VECTOR_POINT_LAST div Max(1, PointCount - 1);
        SetScopePoint(C0, History[Min(Row, Length(History) - 1)], SourcePoint,
          Z, ScopeHalfWidth, ScopeHalfHeight, XScale, YScale);
        SetScopePoint(C1, History[Min(Row, Length(History) - 1)], NextSourcePoint,
          Z, ScopeHalfWidth, ScopeHalfHeight, XScale, YScale);
        Dx := C1.X - C0.X;
        Dy := C1.Y - C0.Y;
        LineLength := Sqrt(Dx * Dx + Dy * Dy);
        if LineLength > 0.0001 then
        begin
          Nx := -Dy / LineLength * HalfThickness;
          Ny := Dx / LineLength * HalfThickness;
        end
        else
        begin
          Nx := HalfThickness;
          Ny := 0.0;
        end;
        P0 := C0; P0.X := P0.X - Nx; P0.Y := P0.Y - Ny;
        P1 := C0; P1.X := P1.X + Nx; P1.Y := P1.Y + Ny;
        P2 := C1; P2.X := P2.X + Nx; P2.Y := P2.Y + Ny;
        P3 := C1; P3.X := P3.X - Nx; P3.Y := P3.Y - Ny;
        GetViewColor(Settings, Point, PointCount, R, G, B);
        SetVertex(Vertices[VertexIndex], P0, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 1], P1, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 2], P2, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 3], P3, ZScale, R, G, B);
        Inc(VertexIndex, 4);
      end;
    end;
  end;

  if Length(Vertices) = 0 then
    Exit;
  if VertexIndex <= 0 then
  begin
    // 全層が流れ切った空表示は描画失敗ではない。2D Vectorscopeへ戻さず透明を保つ。
    Result := True;
    if Assigned(Video^.SetDefaultAnchor) then
      Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
    Exit;
  end;
  Result := Video^.DrawPoly(VERTEX_QUAD_COLOR, @Vertices[0], VertexIndex, nil) <> 0;
  if Result and Assigned(Video^.SetDefaultAnchor) then
    Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
end;

end.
