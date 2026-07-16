unit Aul2AudioViewRenderWaveformTunnel3D;

// 時間波形の表示用履歴を円形断面へ変換し、Z方向へ連ねたトンネルとして描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

function DrawWaveformTunnel3D(Video: PFILTER_PROC_VIDEO;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer): Boolean;

implementation

uses
  System.Math,
  Aul2AudioMonitorShared,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewSpectrum,
  Aul2AudioViewWave;

type
  TVertexColorArray = array of TVERTEX_COLOR;
  TPoint3D = record
    X, Y, Z: Single;
  end;

var
  FlowHistory       : TAudioViewWaveHistory;
  FlowLastFrame     : Integer = -1;
  FlowSourceLayer   : Integer = -1;
  LastEditHistory   : TAudioViewWaveHistory;
  LastEditValid     : Boolean;
  LastEditSourceLayer: Integer = -1;

function WavePeak(const Wave: TAudioMonitorWaveData): Single;
var
  Point: Integer;
begin
  Result := 0.0;
  for Point := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
    Result := Max(Result, Abs(Wave[Point]));
end;

function HistoryPeak(const History: TAudioViewWaveHistory): Single;
var
  Row: Integer;
begin
  Result := 0.0;
  for Row := 0 to Length(History) - 1 do
    Result := Max(Result, WavePeak(History[Row]));
end;

procedure CopyHistory(const Source: TAudioViewWaveHistory;
  out Dest: TAudioViewWaveHistory);
var
  Row: Integer;
begin
  SetLength(Dest, Length(Source));
  for Row := 0 to Length(Source) - 1 do
    Dest[Row] := Source[Row];
end;

procedure PushFlowWave(const Wave: TAudioMonitorWaveData; MaxRows: Integer);
var
  NewHistory: TAudioViewWaveHistory;
  Row: Integer;
  NewCount: Integer;
begin
  NewCount := Min(MaxRows, Length(FlowHistory) + 1);
  SetLength(NewHistory, NewCount);
  if NewCount <= 0 then
    Exit;

  NewHistory[0] := Wave;
  for Row := 1 to NewCount - 1 do
    NewHistory[Row] := FlowHistory[Row - 1];
  FlowHistory := NewHistory;
end;

procedure ResolvePlaybackFlow(var History: TAudioViewWaveHistory; var Valid: Boolean;
  CurrentFrame, SourceLayer, MaxRows: Integer);
var
  CurrentWave: TAudioMonitorWaveData;
  Step: Integer;
  AdvanceCount: Integer;
begin
  if SourceLayer <> FlowSourceLayer then
  begin
    SetLength(FlowHistory, 0);
    FlowLastFrame := -1;
    FlowSourceLayer := SourceLayer;
  end;

  // 編集停止中は共有履歴から組み直したHistoryをそのまま描き、カーソル移動へ追従する。
  if GetViewEditState = 0 then
    Exit;

  FillChar(CurrentWave, SizeOf(CurrentWave), 0);
  if Valid and (Length(History) > 0) then
    CurrentWave := History[0];

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
    // 無音もゼロ断面として追加し、有音断面を一列ずつ奥へ送る。
    for Step := 1 to AdvanceCount do
      PushFlowWave(CurrentWave, MaxRows);
    FlowLastFrame := CurrentFrame;
  end
  else if Length(FlowHistory) > 0 then
    FlowHistory[0] := CurrentWave;

  if Length(FlowHistory) > 0 then
  begin
    CopyHistory(FlowHistory, History);
    Valid := True;
  end;
end;

procedure ResolveEditHistory(var History: TAudioViewWaveHistory; SourceLayer: Integer);
var
  Peak: Single;
begin
  if SourceLayer <> LastEditSourceLayer then
  begin
    SetLength(LastEditHistory, 0);
    LastEditValid := False;
    LastEditSourceLayer := SourceLayer;
  end;

  Peak := HistoryPeak(History);
  if (Length(History) > 0) and (Peak > 0.0001) then
  begin
    CopyHistory(History, LastEditHistory);
    LastEditValid := True;
  end;

  // 編集停止中だけ最後の有効トンネルへ戻し、Play／Encode中の無音は保持しない。
  if (GetViewEditState = 0) and ((Length(History) = 0) or (Peak <= 0.0001)) and
     LastEditValid then
    CopyHistory(LastEditHistory, History);
end;

procedure SmoothWaveHistory(var History: TAudioViewWaveHistory; Smooth: Integer);
var
  Blend: Single;
  Row: Integer;
  Point: Integer;
begin
  if Length(History) < 2 then
    Exit;

  // Smoothを履歴方向にも適用し、先頭断面だけでなくトンネル全体の急な段差を抑える。
  Blend := Max(0, Min(100, Smooth)) / 100.0 * 0.85;
  if Blend <= 0.0 then
    Exit;
  for Row := 1 to Length(History) - 1 do
    for Point := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
      History[Row][Point] := Max(-1.0, Min(1.0,
        History[Row][Point] +
        ((History[Row - 1][Point] - History[Row][Point]) * Blend)));
end;

function SampleWave(const Wave: TAudioMonitorWaveData; Index, Count: Integer): Single;
var
  Position: Double;
  Point0: Integer;
  Point1: Integer;
  Frac: Double;
begin
  Position := Index * AUDIO_MONITOR_WAVE_POINT_COUNT / Count;
  Point0 := Floor(Position) mod AUDIO_MONITOR_WAVE_POINT_COUNT;
  Point1 := (Point0 + 1) mod AUDIO_MONITOR_WAVE_POINT_COUNT;
  Frac := Position - Floor(Position);
  Result := Wave[Point0] + ((Wave[Point1] - Wave[Point0]) * Frac);
  Result := Max(-1.0, Min(1.0, Result));
end;

function Shade(Color: Byte; Factor: Single): Byte;
begin
  Result := Round(Max(0.0, Min(255.0, Color * Factor)));
end;

procedure SetVertex(var Vertex: TVERTEX_COLOR; const Point: TPoint3D;
  XScale, YScale, ZScale: Single; R, G, B: Byte);
begin
  Vertex.X := Point.X * XScale;
  Vertex.Y := Point.Y * YScale;
  Vertex.Z := Point.Z * ZScale;
  Vertex.R := R / 255.0;
  Vertex.G := G / 255.0;
  Vertex.B := B / 255.0;
  Vertex.A := 1.0;
end;

procedure AddQuad(var Vertices: TVertexColorArray; var VertexIndex: Integer;
  const P0, P1, P2, P3: TPoint3D; XScale, YScale, ZScale: Single;
  R, G, B: Byte; ShadeFactor: Single);
var
  FaceR, FaceG, FaceB: Byte;
begin
  FaceR := Shade(R, ShadeFactor);
  FaceG := Shade(G, ShadeFactor);
  FaceB := Shade(B, ShadeFactor);
  SetVertex(Vertices[VertexIndex], P0, XScale, YScale, ZScale, FaceR, FaceG, FaceB);
  SetVertex(Vertices[VertexIndex + 1], P1, XScale, YScale, ZScale, FaceR, FaceG, FaceB);
  SetVertex(Vertices[VertexIndex + 2], P2, XScale, YScale, ZScale, FaceR, FaceG, FaceB);
  SetVertex(Vertices[VertexIndex + 3], P3, XScale, YScale, ZScale, FaceR, FaceG, FaceB);
  Inc(VertexIndex, 4);
end;

procedure SetRingPoint(var Point: TPoint3D; Angle, Radius, Z: Single);
begin
  Point.X := Cos(Angle) * Radius;
  Point.Y := Sin(Angle) * Radius;
  Point.Z := Z;
end;

function DrawWaveformTunnel3D(Video: PFILTER_PROC_VIDEO;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer): Boolean;
var
  Wave, WaveMin, WaveMax: TAudioMonitorWaveData;
  WaveValid: Boolean;
  History: TAudioViewWaveHistory;
  HistoryValid: Boolean;
  Vertices: TVertexColorArray;
  Count: Integer;
  RequestedRows: Integer;
  RowCount: Integer;
  Row: Integer;
  NextRow: Integer;
  Index: Integer;
  NextIndex: Integer;
  VertexIndex: Integer;
  MinSize: Integer;
  BaseRadius: Single;
  Amplitude: Single;
  HalfWidth: Single;
  RingDepth: Single;
  DepthStep: Single;
  ZCenter: Single;
  Z0, Z1: Single;
  Radius00, Radius01, Radius10, Radius11: Single;
  Angle0, Angle1: Single;
  XScale, YScale, ZScale: Single;
  P0, P1, P2, P3: TPoint3D;
  R, G, B: Byte;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or not Assigned(Video^.DrawPoly) then
    Exit;

  UpdateViewWave(Settings.Smooth, Wave, WaveMin, WaveMax, WaveValid,
    CurrentFrame, Settings.SourceLayer);
  if (GetViewEditState = 0) and ((not WaveValid) or (WavePeak(Wave) <= 0.0001)) then
    UpdateViewWaveLatestForEdit(Settings.Smooth, Wave, WaveMin, WaveMax,
      WaveValid, Settings.SourceLayer);

  Count := Max(8, Min(128, Settings.Density));
  RequestedRows := Max(8, Min(32, Settings.Density));
  GetViewWaveHistory(CurrentFrame, Settings.SourceLayer, RequestedRows,
    History, HistoryValid);
  // 先頭断面には既存時間波形Typeと同じ平滑化済みの現在値を使う。
  if WaveValid then
  begin
    if Length(History) = 0 then
      SetLength(History, 1);
    History[0] := Wave;
    HistoryValid := True;
  end;
  ResolvePlaybackFlow(History, HistoryValid, CurrentFrame, Settings.SourceLayer,
    RequestedRows);
  ResolveEditHistory(History, Settings.SourceLayer);
  if Length(History) = 0 then
    Exit;
  SmoothWaveHistory(History, Settings.Smooth);

  RowCount := Max(2, Length(History));
  MinSize := Min(Video^.Object_^.Width, Video^.Object_^.Height);
  BaseRadius := Max(16.0, MinSize * Max(0, Min(100, Settings.BaseRadius)) / 200.0);
  Amplitude := MinSize * 0.18;
  HalfWidth := Max(0.5, Min(32, Settings.Thickness) * 0.5);
  RingDepth := Max(1.0, Min(32, Settings.Thickness));
  if Settings.Style = VIEW_STYLE_BLOCKS then
    // Blocksはリング自体の奥行きとリング間の空白を足した間隔にする。
    DepthStep := RingDepth + Max(0, Min(32, Settings.Spacing))
  else
    // SolidではThicknessを壁厚だけに使い、履歴間隔はSpacingから独立して決める。
    DepthStep := 1.0 + Max(0, Min(32, Settings.Spacing));
  XScale := Max(10, Min(500, Settings.XScale)) / 100.0;
  YScale := Max(10, Min(500, Settings.YScale)) / 100.0;
  ZScale := Max(10, Min(500, Settings.ZScale)) / 100.0;

  VertexIndex := 0;
  if Settings.Style = VIEW_STYLE_BLOCKS then
  begin
    // 独立リングは前後・内外の4面を持ち、Thicknessを断面の太さへ使う。
    SetLength(Vertices, RowCount * Count * 16);
    for Row := 0 to RowCount - 1 do
    begin
      ZCenter := (Row - (RowCount - 1) * 0.5) * DepthStep;
      Z0 := ZCenter - RingDepth * 0.5;
      Z1 := ZCenter + RingDepth * 0.5;
      for Index := 0 to Count - 1 do
      begin
        NextIndex := (Index + 1) mod Count;
        Angle0 := -Pi / 2.0 + (2.0 * Pi * Index / Count);
        Angle1 := -Pi / 2.0 + (2.0 * Pi * (Index + 1) / Count);
        Radius00 := Max(HalfWidth + 1.0, BaseRadius +
          SampleWave(History[Min(Row, Length(History) - 1)], Index, Count) * Amplitude);
        Radius01 := Max(HalfWidth + 1.0, BaseRadius +
          SampleWave(History[Min(Row, Length(History) - 1)], NextIndex, Count) * Amplitude);

        GetViewColor(Settings, Index, Count, R, G, B);
        SetRingPoint(P0, Angle0, Radius00 - HalfWidth, Z0);
        SetRingPoint(P1, Angle1, Radius01 - HalfWidth, Z0);
        SetRingPoint(P2, Angle1, Radius01 + HalfWidth, Z0);
        SetRingPoint(P3, Angle0, Radius00 + HalfWidth, Z0);
        AddQuad(Vertices, VertexIndex, P0, P1, P2, P3, XScale, YScale, ZScale, R, G, B, 1.00);
        SetRingPoint(P0, Angle0, Radius00 + HalfWidth, Z1);
        SetRingPoint(P1, Angle1, Radius01 + HalfWidth, Z1);
        SetRingPoint(P2, Angle1, Radius01 - HalfWidth, Z1);
        SetRingPoint(P3, Angle0, Radius00 - HalfWidth, Z1);
        AddQuad(Vertices, VertexIndex, P0, P1, P2, P3, XScale, YScale, ZScale, R, G, B, 0.55);
        SetRingPoint(P0, Angle0, Radius00 + HalfWidth, Z0);
        SetRingPoint(P1, Angle1, Radius01 + HalfWidth, Z0);
        SetRingPoint(P2, Angle1, Radius01 + HalfWidth, Z1);
        SetRingPoint(P3, Angle0, Radius00 + HalfWidth, Z1);
        AddQuad(Vertices, VertexIndex, P0, P1, P2, P3, XScale, YScale, ZScale, R, G, B, 0.82);
        SetRingPoint(P0, Angle0, Radius00 - HalfWidth, Z1);
        SetRingPoint(P1, Angle1, Radius01 - HalfWidth, Z1);
        SetRingPoint(P2, Angle1, Radius01 - HalfWidth, Z0);
        SetRingPoint(P3, Angle0, Radius00 - HalfWidth, Z0);
        AddQuad(Vertices, VertexIndex, P0, P1, P2, P3, XScale, YScale, ZScale, R, G, B, 0.68);
      end;
    end;
  end
  else
  begin
    // 連続トンネルは履歴間を内外2枚の面で接続し、両端も閉じて壁厚を見せる。
    SetLength(Vertices, ((RowCount - 1) * Count * 8) + (Count * 8));
    for Row := 0 to RowCount - 2 do
    begin
      NextRow := Min(Row + 1, Length(History) - 1);
      Z0 := (Row - (RowCount - 1) * 0.5) * DepthStep;
      Z1 := ((Row + 1) - (RowCount - 1) * 0.5) * DepthStep;
      for Index := 0 to Count - 1 do
      begin
        NextIndex := (Index + 1) mod Count;
        Angle0 := -Pi / 2.0 + (2.0 * Pi * Index / Count);
        Angle1 := -Pi / 2.0 + (2.0 * Pi * (Index + 1) / Count);
        Radius00 := Max(HalfWidth + 1.0, BaseRadius +
          SampleWave(History[Min(Row, Length(History) - 1)], Index, Count) * Amplitude);
        Radius01 := Max(HalfWidth + 1.0, BaseRadius +
          SampleWave(History[Min(Row, Length(History) - 1)], NextIndex, Count) * Amplitude);
        Radius10 := Max(HalfWidth + 1.0, BaseRadius +
          SampleWave(History[NextRow], Index, Count) * Amplitude);
        Radius11 := Max(HalfWidth + 1.0, BaseRadius +
          SampleWave(History[NextRow], NextIndex, Count) * Amplitude);

        GetViewColor(Settings, Index, Count, R, G, B);
        SetRingPoint(P0, Angle0, Radius00 + HalfWidth, Z0);
        SetRingPoint(P1, Angle0, Radius10 + HalfWidth, Z1);
        SetRingPoint(P2, Angle1, Radius11 + HalfWidth, Z1);
        SetRingPoint(P3, Angle1, Radius01 + HalfWidth, Z0);
        AddQuad(Vertices, VertexIndex, P0, P1, P2, P3, XScale, YScale, ZScale, R, G, B, 1.00);
        SetRingPoint(P0, Angle1, Radius01 - HalfWidth, Z0);
        SetRingPoint(P1, Angle1, Radius11 - HalfWidth, Z1);
        SetRingPoint(P2, Angle0, Radius10 - HalfWidth, Z1);
        SetRingPoint(P3, Angle0, Radius00 - HalfWidth, Z0);
        AddQuad(Vertices, VertexIndex, P0, P1, P2, P3, XScale, YScale, ZScale, R, G, B, 0.62);
      end;
    end;

    // 手前側と奥側を環状の面で閉じ、Thickness変更を端面でも確認できるようにする。
    Z0 := -(RowCount - 1) * 0.5 * DepthStep;
    Z1 := (RowCount - 1) * 0.5 * DepthStep;
    for Index := 0 to Count - 1 do
    begin
      NextIndex := (Index + 1) mod Count;
      Angle0 := -Pi / 2.0 + (2.0 * Pi * Index / Count);
      Angle1 := -Pi / 2.0 + (2.0 * Pi * (Index + 1) / Count);
      Radius00 := Max(HalfWidth + 1.0, BaseRadius +
        SampleWave(History[0], Index, Count) * Amplitude);
      Radius01 := Max(HalfWidth + 1.0, BaseRadius +
        SampleWave(History[0], NextIndex, Count) * Amplitude);
      Radius10 := Max(HalfWidth + 1.0, BaseRadius +
        SampleWave(History[Length(History) - 1], Index, Count) * Amplitude);
      Radius11 := Max(HalfWidth + 1.0, BaseRadius +
        SampleWave(History[Length(History) - 1], NextIndex, Count) * Amplitude);

      GetViewColor(Settings, Index, Count, R, G, B);
      SetRingPoint(P0, Angle0, Radius00 - HalfWidth, Z0);
      SetRingPoint(P1, Angle1, Radius01 - HalfWidth, Z0);
      SetRingPoint(P2, Angle1, Radius01 + HalfWidth, Z0);
      SetRingPoint(P3, Angle0, Radius00 + HalfWidth, Z0);
      AddQuad(Vertices, VertexIndex, P0, P1, P2, P3,
        XScale, YScale, ZScale, R, G, B, 0.88);

      SetRingPoint(P0, Angle0, Radius10 + HalfWidth, Z1);
      SetRingPoint(P1, Angle1, Radius11 + HalfWidth, Z1);
      SetRingPoint(P2, Angle1, Radius11 - HalfWidth, Z1);
      SetRingPoint(P3, Angle0, Radius10 - HalfWidth, Z1);
      AddQuad(Vertices, VertexIndex, P0, P1, P2, P3,
        XScale, YScale, ZScale, R, G, B, 0.52);
    end;
  end;

  if Length(Vertices) = 0 then
    Exit;
  Result := Video^.DrawPoly(VERTEX_QUAD_COLOR, @Vertices[0], Length(Vertices), nil) <> 0;
  if Result and Assigned(Video^.SetDefaultAnchor) then
    Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
end;

end.
