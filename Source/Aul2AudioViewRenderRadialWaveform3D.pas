unit Aul2AudioViewRenderRadialWaveform3D;

// 時間波形を円周上の厚み付きリボンへ変換し、AviUtl2の3D空間へ描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 現在波形の立体リングを描き、draw_polyが成功した場合Trueを返す。
function DrawRadialWaveform3D(Video: PFILTER_PROC_VIDEO; const Settings: TAul2AudioViewSettings;
  CurrentFrame: Integer): Boolean;

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

const
  RADIAL_WAVEFORM_Z_SENSITIVITY = 6.0; // 薄い波形帯の奥行きをカメラ上で確認しやすくする専用倍率。

var
  LastEditWave       : TAudioMonitorWaveData;
  LastEditWaveValid  : Boolean;
  LastEditSourceLayer: Integer = -1;

function WavePeak(const Wave: TAudioMonitorWaveData): Single;
var
  Point: Integer;
begin
  Result := 0.0;
  for Point := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
    Result := Max(Result, Abs(Wave[Point]));
end;

procedure ResolveEditWave(var Wave: TAudioMonitorWaveData; var WaveValid: Boolean;
  SourceLayer: Integer);
var
  Peak: Single;
begin
  if SourceLayer <> LastEditSourceLayer then
  begin
    LastEditWaveValid := False;
    LastEditSourceLayer := SourceLayer;
  end;

  Peak := WavePeak(Wave);
  if WaveValid and (Peak > 0.0001) then
  begin
    LastEditWave := Wave;
    LastEditWaveValid := True;
  end;

  // 編集停止中だけ最後の有効波形へ戻し、再生中の本当の無音は保持しない。
  if (GetViewEditState = 0) and ((not WaveValid) or (Peak <= 0.0001)) and LastEditWaveValid then
  begin
    Wave := LastEditWave;
    WaveValid := True;
  end;
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

function DrawRadialWaveform3D(Video: PFILTER_PROC_VIDEO; const Settings: TAul2AudioViewSettings;
  CurrentFrame: Integer): Boolean;
var
  Wave: TAudioMonitorWaveData;
  WaveMin: TAudioMonitorWaveData;
  WaveMax: TAudioMonitorWaveData;
  WaveValid: Boolean;
  Vertices: TVertexColorArray;
  Count: Integer;
  Index: Integer;
  NextIndex: Integer;
  VertexIndex: Integer;
  MinSize: Integer;
  BaseRadius: Single;
  Amplitude: Single;
  HalfWidth: Single;
  HalfDepth: Single;
  Radius0: Single;
  Radius1: Single;
  Angle0: Single;
  Angle1: Single;
  XScale: Single;
  YScale: Single;
  ZScale: Single;
  I0F, O0F, I1F, O1F: TPoint3D;
  I0B, O0B, I1B, O1B: TPoint3D;
  R, G, B: Byte;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or not Assigned(Video^.DrawPoly) then
    Exit;

  UpdateViewWave(Settings.Smooth, Wave, WaveMin, WaveMax, WaveValid,
    CurrentFrame, Settings.SourceLayer);
  if (GetViewEditState = 0) and (not WaveValid) then
    UpdateViewWaveLatestForEdit(Settings.Smooth, Wave, WaveMin, WaveMax,
      WaveValid, CurrentFrame, Settings.SourceLayer);
  if (not WaveValid) or (WavePeak(Wave) <= 0.0001) then
  begin
    Result := True;
    if Assigned(Video^.SetDefaultAnchor) then
      Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
    Exit;
  end;

  Count := Max(8, Min(128, Settings.Density));
  MinSize := Min(Video^.Object_^.Width, Video^.Object_^.Height);
  BaseRadius := Max(16.0, MinSize * Max(0, Min(100, Settings.BaseRadius)) / 200.0);
  Amplitude := MinSize * 0.18;
  HalfWidth := Max(0.5, Min(32, Settings.Thickness) * 0.5);
  HalfDepth := HalfWidth;
  XScale := Max(10, Min(500, Settings.XScale)) / 100.0;
  YScale := Max(10, Min(500, Settings.YScale)) / 100.0;
  ZScale := Max(10, Min(500, Settings.ZScale)) / 100.0 * RADIAL_WAVEFORM_Z_SENSITIVITY;

  SetLength(Vertices, Count * 16);
  VertexIndex := 0;
  for Index := 0 to Count - 1 do
  begin
    NextIndex := (Index + 1) mod Count;
    Angle0 := -Pi / 2.0 + (2.0 * Pi * Index / Count);
    Angle1 := -Pi / 2.0 + (2.0 * Pi * (Index + 1) / Count);
    Radius0 := Max(HalfWidth + 1.0, BaseRadius + SampleWave(Wave, Index, Count) * Amplitude);
    Radius1 := Max(HalfWidth + 1.0, BaseRadius + SampleWave(Wave, NextIndex, Count) * Amplitude);

    SetRingPoint(I0F, Angle0, Radius0 - HalfWidth, -HalfDepth);
    SetRingPoint(O0F, Angle0, Radius0 + HalfWidth, -HalfDepth);
    SetRingPoint(I1F, Angle1, Radius1 - HalfWidth, -HalfDepth);
    SetRingPoint(O1F, Angle1, Radius1 + HalfWidth, -HalfDepth);
    SetRingPoint(I0B, Angle0, Radius0 - HalfWidth, HalfDepth);
    SetRingPoint(O0B, Angle0, Radius0 + HalfWidth, HalfDepth);
    SetRingPoint(I1B, Angle1, Radius1 - HalfWidth, HalfDepth);
    SetRingPoint(O1B, Angle1, Radius1 + HalfWidth, HalfDepth);

    GetViewColor(Settings, Index, Count, R, G, B);
    AddQuad(Vertices, VertexIndex, I0F, I1F, O1F, O0F, XScale, YScale, ZScale, R, G, B, 1.00);
    AddQuad(Vertices, VertexIndex, O0B, O1B, I1B, I0B, XScale, YScale, ZScale, R, G, B, 0.55);
    AddQuad(Vertices, VertexIndex, O0F, O1F, O1B, O0B, XScale, YScale, ZScale, R, G, B, 0.82);
    AddQuad(Vertices, VertexIndex, I0B, I1B, I1F, I0F, XScale, YScale, ZScale, R, G, B, 0.68);
  end;

  Result := Video^.DrawPoly(VERTEX_QUAD_COLOR, @Vertices[0], Length(Vertices), nil) <> 0;
  if Result and Assigned(Video^.SetDefaultAnchor) then
    Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
end;

end.
