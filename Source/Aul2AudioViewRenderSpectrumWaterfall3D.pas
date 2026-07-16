unit Aul2AudioViewRenderSpectrumWaterfall3D;

// スペクトラム履歴を接続しない細い帯としてZ方向へ並べ、滝状に描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

function DrawSpectrumWaterfall3D(Video: PFILTER_PROC_VIDEO;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer): Boolean;

implementation

uses
  System.Math,
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewSpectrum;

type
  TVertexColorArray = array of TVERTEX_COLOR;

var
  LastEditHistory: TAudioViewSpectrumHistory;
  LastEditHistoryValid: Boolean;
  LastEditSourceMinHz: Single;
  LastEditSourceMaxHz: Single;
  LastEditSourceLayer: Integer = -1;
  FlowHistory: TAudioViewSpectrumHistory;
  FlowLastFrame: Integer = -1;
  FlowSourceLayer: Integer = -1;

function HistoryPeak(const History: TAudioViewSpectrumHistory): Single;
var
  Row: Integer;
  Band: Integer;
begin
  Result := 0.0;
  for Row := 0 to Length(History) - 1 do
    for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
      Result := Max(Result, History[Row][Band]);
end;

procedure CopyHistory(const Source: TAudioViewSpectrumHistory;
  out Dest: TAudioViewSpectrumHistory);
var
  Row: Integer;
begin
  SetLength(Dest, Length(Source));
  for Row := 0 to Length(Source) - 1 do
    Dest[Row] := Source[Row];
end;

procedure PushFlowRow(const Bands: TAudioMonitorSpectrumData; MaxRows: Integer);
var
  NewHistory: TAudioViewSpectrumHistory;
  Row: Integer;
  NewCount: Integer;
begin
  NewCount := Min(MaxRows, Length(FlowHistory) + 1);
  SetLength(NewHistory, NewCount);
  if NewCount <= 0 then
    Exit;
  NewHistory[0] := Bands;
  for Row := 1 to NewCount - 1 do
    NewHistory[Row] := FlowHistory[Row - 1];
  FlowHistory := NewHistory;
end;

procedure ResolvePlaybackFlow(var History: TAudioViewSpectrumHistory;
  var Valid: Boolean; CurrentFrame, SourceLayer, MaxRows: Integer);
var
  CurrentBands: TAudioMonitorSpectrumData;
  Step: Integer;
  AdvanceCount: Integer;
begin
  if SourceLayer <> FlowSourceLayer then
  begin
    SetLength(FlowHistory, 0);
    FlowLastFrame := -1;
    FlowSourceLayer := SourceLayer;
  end;

  // 編集停止中は共有履歴をそのまま使い、カーソル位置の変更へ追従する。
  if GetViewEditState = 0 then
    Exit;

  FillChar(CurrentBands, SizeOf(CurrentBands), 0);
  if Valid and (Length(History) > 0) then
    CurrentBands := History[0];

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
      PushFlowRow(CurrentBands, MaxRows);
    FlowLastFrame := CurrentFrame;
  end
  else if Length(FlowHistory) > 0 then
    FlowHistory[0] := CurrentBands;

  if Length(FlowHistory) > 0 then
  begin
    CopyHistory(FlowHistory, History);
    Valid := True;
  end;
end;

procedure ResolveEditHistory(var History: TAudioViewSpectrumHistory;
  var Valid: Boolean; var SourceMinHz, SourceMaxHz: Single; SourceLayer: Integer);
var
  Peak: Single;
begin
  if SourceLayer <> LastEditSourceLayer then
  begin
    LastEditHistoryValid := False;
    SetLength(LastEditHistory, 0);
    LastEditSourceLayer := SourceLayer;
  end;

  Peak := HistoryPeak(History);
  if Valid and (Peak > 0.0001) then
  begin
    CopyHistory(History, LastEditHistory);
    LastEditHistoryValid := True;
    LastEditSourceMinHz := SourceMinHz;
    LastEditSourceMaxHz := SourceMaxHz;
  end;

  if (GetViewEditState = 0) and ((not Valid) or (Peak <= 0.0001)) and
     LastEditHistoryValid then
  begin
    CopyHistory(LastEditHistory, History);
    Valid := True;
    SourceMinHz := LastEditSourceMinHz;
    SourceMaxHz := LastEditSourceMaxHz;
  end;
end;

procedure SmoothSpectrumHistory(var History: TAudioViewSpectrumHistory;
  Smooth: Integer);
var
  Blend: Single;
  Row: Integer;
  Band: Integer;
begin
  if Length(History) < 2 then
    Exit;

  // 先頭列の時間平滑化に加え、履歴方向の隣接帯も滑らかにつなぐ。
  Blend := Max(0, Min(100, Smooth)) / 100.0 * 0.85;
  if Blend <= 0.0 then
    Exit;
  for Row := 1 to Length(History) - 1 do
    for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
      History[Row][Band] := Max(0.0, Min(1.0,
        History[Row][Band] +
        ((History[Row - 1][Band] - History[Row][Band]) * Blend)));
end;

procedure SetVertex(var Vertex: TVERTEX_COLOR; X, Y, Z, XScale, ZScale: Single;
  R, G, B: Byte);
begin
  Vertex.X := X * XScale;
  Vertex.Y := Y;
  Vertex.Z := Z * ZScale;
  Vertex.R := R / 255.0;
  Vertex.G := G / 255.0;
  Vertex.B := B / 255.0;
  Vertex.A := 1.0;
end;

function DrawSpectrumWaterfall3D(Video: PFILTER_PROC_VIDEO;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer): Boolean;
var
  History: TAudioViewSpectrumHistory;
  Valid: Boolean;
  SourceMinHz, SourceMaxHz: Single;
  CurrentBands: TAudioMonitorSpectrumData;
  CurrentValid: Boolean;
  CurrentMinHz, CurrentMaxHz: Single;
  Vertices: TVertexColorArray;
  BandCount: Integer;
  RequestedRows: Integer;
  RowCount: Integer;
  Row: Integer;
  Band: Integer;
  VertexIndex: Integer;
  MinSize: Integer;
  Width: Single;
  Height: Single;
  StripDepth: Single;
  DepthStep: Single;
  ZCenter, Z0, Z1: Single;
  X0, X1, XCenter: Single;
  CellWidth: Single;
  TileHalfWidth: Single;
  Y0, Y1: Single;
  XScale, ZScale: Single;
  Value: Single;
  R, G, B: Byte;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or not Assigned(Video^.DrawPoly) then
    Exit;

  BandCount := Max(8, Min(AUDIO_MONITOR_SPECTRUM_BAND_COUNT, Settings.Density));
  RequestedRows := Max(8, Min(32, Settings.Density));
  GetViewSpectrumHistory(CurrentFrame, Settings.SourceLayer, RequestedRows,
    History, Valid, SourceMinHz, SourceMaxHz);
  UpdateViewSpectrum(Settings.Smooth, CurrentBands, CurrentValid,
    CurrentMinHz, CurrentMaxHz, CurrentFrame, Settings.SourceLayer);
  if (not CurrentValid) and (GetViewEditState = 0) then
    UpdateViewSpectrumLatestForEdit(Settings.Smooth, CurrentBands, CurrentValid,
      CurrentMinHz, CurrentMaxHz, Settings.SourceLayer);
  if CurrentValid then
  begin
    if Length(History) = 0 then
      SetLength(History, 1);
    History[0] := CurrentBands;
    Valid := True;
    SourceMinHz := CurrentMinHz;
    SourceMaxHz := CurrentMaxHz;
  end;
  ResolvePlaybackFlow(History, Valid, CurrentFrame, Settings.SourceLayer, RequestedRows);
  ResolveEditHistory(History, Valid, SourceMinHz, SourceMaxHz, Settings.SourceLayer);
  if not Valid or (Length(History) = 0) then
    Exit;
  SmoothSpectrumHistory(History, Settings.Smooth);

  RowCount := Max(2, Length(History));
  MinSize := Min(Video^.Object_^.Width, Video^.Object_^.Height);
  Width := Video^.Object_^.Width * 0.82;
  Height := MinSize * 0.42;
  StripDepth := Max(1.0, Min(32, Settings.Thickness));
  DepthStep := StripDepth + Max(0, Min(32, Settings.Spacing));
  XScale := Max(10, Min(500, Settings.XScale)) / 100.0;
  ZScale := Max(10, Min(500, Settings.ZScale)) / 100.0;
  VertexIndex := 0;

  if Settings.Style = VIEW_STYLE_BLOCKS then
  begin
    // 周波数方向も分割し、履歴ごとに独立したタイル列として描く。
    SetLength(Vertices, RowCount * BandCount * 4);
    CellWidth := Width / BandCount;
    TileHalfWidth := Max(0.5,
      (CellWidth - Min(Max(0.0, CellWidth - 1.0),
        Max(0, Min(32, Settings.Spacing)))) * 0.5);
    for Row := 0 to RowCount - 1 do
    begin
      ZCenter := (Row - (RowCount - 1) * 0.5) * DepthStep;
      Z0 := ZCenter - StripDepth * 0.5;
      Z1 := ZCenter + StripDepth * 0.5;
      for Band := 0 to BandCount - 1 do
      begin
        XCenter := ((Band + 0.5) / BandCount - 0.5) * Width;
        Value := GetSpectrumDisplayValue(History[Min(Row, Length(History) - 1)], True,
          SourceMinHz, SourceMaxHz, Settings, Band, BandCount);
        Y0 := -Height * Value;
        GetViewColor(Settings, Band, BandCount, R, G, B);
        SetVertex(Vertices[VertexIndex], XCenter - TileHalfWidth, Y0, Z0, XScale, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 1], XCenter - TileHalfWidth, Y0, Z1, XScale, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 2], XCenter + TileHalfWidth, Y0, Z1, XScale, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 3], XCenter + TileHalfWidth, Y0, Z0, XScale, ZScale, R, G, B);
        Inc(VertexIndex, 4);
      end;
    end;
  end
  else
  begin
    // 履歴同士は接続せず、各時刻のスペクトラムだけを連続した細いリボンにする。
    SetLength(Vertices, RowCount * (BandCount - 1) * 4);
    for Row := 0 to RowCount - 1 do
    begin
      ZCenter := (Row - (RowCount - 1) * 0.5) * DepthStep;
      Z0 := ZCenter - StripDepth * 0.5;
      Z1 := ZCenter + StripDepth * 0.5;
      for Band := 0 to BandCount - 2 do
      begin
        X0 := ((Band / (BandCount - 1)) - 0.5) * Width;
        X1 := (((Band + 1) / (BandCount - 1)) - 0.5) * Width;
        Value := GetSpectrumDisplayValue(History[Min(Row, Length(History) - 1)], True,
          SourceMinHz, SourceMaxHz, Settings, Band, BandCount);
        Y0 := -Height * Value;
        Value := GetSpectrumDisplayValue(History[Min(Row, Length(History) - 1)], True,
          SourceMinHz, SourceMaxHz, Settings, Band + 1, BandCount);
        Y1 := -Height * Value;
        GetViewColor(Settings, Band, BandCount, R, G, B);
        SetVertex(Vertices[VertexIndex], X0, Y0, Z0, XScale, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 1], X0, Y0, Z1, XScale, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 2], X1, Y1, Z1, XScale, ZScale, R, G, B);
        SetVertex(Vertices[VertexIndex + 3], X1, Y1, Z0, XScale, ZScale, R, G, B);
        Inc(VertexIndex, 4);
      end;
    end;
  end;

  if Length(Vertices) = 0 then
    Exit;
  Result := Video^.DrawPoly(VERTEX_QUAD_COLOR, @Vertices[0], Length(Vertices), nil) <> 0;
  if Result and Assigned(Video^.SetDefaultAnchor) then
    Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
end;

end.
