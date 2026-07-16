unit Aul2AudioViewRenderCircular3D;

// スペクトラム値を円周上の縦面へ変換し、AviUtl2の3D描画経路を検証する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 円周上へスペクトラム連動の縦面を描き、draw_polyが成功した場合Trueを返す。
function DrawCircularBars3D(Video: PFILTER_PROC_VIDEO; const Settings: TAul2AudioViewSettings;
  CurrentFrame: Integer): Boolean;

implementation

uses
  System.Math,
  System.SysUtils,
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioViewDiagnostics,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewSpectrum;

type
  TVertexColorArray = array of TVERTEX_COLOR;
  TPoint3D = record
    X, Y, Z: Single;
  end;

var
  LastEditBands      : TAudioMonitorSpectrumData;
  LastEditBandsValid : Boolean;
  LastEditSourceMinHz: Single;
  LastEditSourceMaxHz: Single;
  LastEditSourceLayer: Integer = -1;

function PeakBandValue(const Bands: TAudioMonitorSpectrumData): Single;
var
  Band: Integer;
begin
  Result := 0.0;
  for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
    Result := Max(Result, Bands[Band]);
end;

procedure ResolveEditBands(var Bands: TAudioMonitorSpectrumData; var BandsValid: Boolean;
  var SourceMinHz, SourceMaxHz: Single; SourceLayer: Integer; out CacheUsed: Boolean);
var
  Peak: Single;
begin
  CacheUsed := False;
  if SourceLayer <> LastEditSourceLayer then
  begin
    LastEditBandsValid := False;
    LastEditSourceLayer := SourceLayer;
  end;

  Peak := PeakBandValue(Bands);
  if BandsValid and (Peak > 0.0001) then
  begin
    LastEditBands := Bands;
    LastEditBandsValid := True;
    LastEditSourceMinHz := SourceMinHz;
    LastEditSourceMaxHz := SourceMaxHz;
  end;

  // 再生中の本当の無音は保持せず、編集停止中だけ最後の有効表示へ戻す。
  if (GetViewEditState = 0) and ((not BandsValid) or (Peak <= 0.0001)) and LastEditBandsValid then
  begin
    Bands := LastEditBands;
    BandsValid := True;
    SourceMinHz := LastEditSourceMinHz;
    SourceMaxHz := LastEditSourceMaxHz;
    CacheUsed := True;
  end;
end;

function Shade(Color: Byte; Factor: Single): Byte;
begin
  Result := Round(Max(0.0, Min(255.0, Color * Factor)));
end;

procedure SetVertex(var Vertex: TVERTEX_COLOR; const Point: TPoint3D;
  XScale, ZScale: Single; R, G, B: Byte);
begin
  Vertex.X := Point.X * XScale;
  Vertex.Y := Point.Y;
  Vertex.Z := Point.Z * ZScale;
  Vertex.R := R / 255.0;
  Vertex.G := G / 255.0;
  Vertex.B := B / 255.0;
  Vertex.A := 1.0;
end;

procedure AddQuad(var Vertices: TVertexColorArray; var VertexIndex: Integer;
  const P0, P1, P2, P3: TPoint3D; XScale, ZScale: Single;
  R, G, B: Byte; ShadeFactor: Single);
var
  FaceR, FaceG, FaceB: Byte;
begin
  FaceR := Shade(R, ShadeFactor);
  FaceG := Shade(G, ShadeFactor);
  FaceB := Shade(B, ShadeFactor);
  SetVertex(Vertices[VertexIndex], P0, XScale, ZScale, FaceR, FaceG, FaceB);
  SetVertex(Vertices[VertexIndex + 1], P1, XScale, ZScale, FaceR, FaceG, FaceB);
  SetVertex(Vertices[VertexIndex + 2], P2, XScale, ZScale, FaceR, FaceG, FaceB);
  SetVertex(Vertices[VertexIndex + 3], P3, XScale, ZScale, FaceR, FaceG, FaceB);
  Inc(VertexIndex, 4);
end;

procedure AddBox(var Vertices: TVertexColorArray; var VertexIndex: Integer;
  Angle, Radius, HalfWidth, HalfDepth, BottomY, TopY, XScale, ZScale: Single;
  R, G, B: Byte);
var
  RadialX, RadialZ: Single;
  TangentX, TangentZ: Single;
  InnerRadius, OuterRadius: Single;
  ILB, IRB, OLB, ORB: TPoint3D;
  ILT, IRT, OLT, ORT: TPoint3D;
begin
  RadialX := Cos(Angle);
  RadialZ := Sin(Angle);
  TangentX := -RadialZ;
  TangentZ := RadialX;
  InnerRadius := Max(0.0, Radius - HalfDepth);
  OuterRadius := Radius + HalfDepth;

  ILB.X := RadialX * InnerRadius - TangentX * HalfWidth;
  ILB.Y := BottomY;
  ILB.Z := RadialZ * InnerRadius - TangentZ * HalfWidth;
  IRB.X := RadialX * InnerRadius + TangentX * HalfWidth;
  IRB.Y := BottomY;
  IRB.Z := RadialZ * InnerRadius + TangentZ * HalfWidth;
  OLB.X := RadialX * OuterRadius - TangentX * HalfWidth;
  OLB.Y := BottomY;
  OLB.Z := RadialZ * OuterRadius - TangentZ * HalfWidth;
  ORB.X := RadialX * OuterRadius + TangentX * HalfWidth;
  ORB.Y := BottomY;
  ORB.Z := RadialZ * OuterRadius + TangentZ * HalfWidth;

  ILT := ILB;
  ILT.Y := TopY;
  IRT := IRB;
  IRT.Y := TopY;
  OLT := OLB;
  OLT.Y := TopY;
  ORT := ORB;
  ORT.Y := TopY;

  // 面ごとに明度を変え、光源設定がない場合でも直方体の向きを判別できるようにする。
  AddQuad(Vertices, VertexIndex, OLB, OLT, ORT, ORB, XScale, ZScale, R, G, B, 1.00);
  AddQuad(Vertices, VertexIndex, IRB, IRT, ILT, ILB, XScale, ZScale, R, G, B, 0.55);
  AddQuad(Vertices, VertexIndex, ILB, ILT, OLT, OLB, XScale, ZScale, R, G, B, 0.72);
  AddQuad(Vertices, VertexIndex, ORB, ORT, IRT, IRB, XScale, ZScale, R, G, B, 0.84);
  AddQuad(Vertices, VertexIndex, ILT, IRT, ORT, OLT, XScale, ZScale, R, G, B, 1.15);
  AddQuad(Vertices, VertexIndex, ILB, OLB, ORB, IRB, XScale, ZScale, R, G, B, 0.42);
end;

function DrawCircularBars3D(Video: PFILTER_PROC_VIDEO; const Settings: TAul2AudioViewSettings;
  CurrentFrame: Integer): Boolean;
var
  Bands: TAudioMonitorSpectrumData;
  BandsValid: Boolean;
  SourceMinHz: Single;
  SourceMaxHz: Single;
  Vertices: TVertexColorArray;
  Count: Integer;
  Band: Integer;
  Block: Integer;
  VertexIndex: Integer;
  Radius: Single;
  ArcPitch: Single;
  BarWidth: Single;
  HalfWidth: Single;
  HalfDepth: Single;
  Angle: Single;
  BaseY: Single;
  TopY: Single;
  MaxHeight: Single;
  BlockHeight: Single;
  BlockGap: Single;
  BlockCount: Integer;
  FillCount: Integer;
  XScale: Single;
  ZScale: Single;
  Value: Single;
  InputPeak: Single;
  OutputPeak: Single;
  InputValid: Boolean;
  CacheUsed: Boolean;
  DrawSucceeded: Boolean;
  R, G, B: Byte;
begin
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) or not Assigned(Video^.DrawPoly) then
    Exit;

  UpdateViewSpectrum(Settings.Smooth, Bands, BandsValid, SourceMinHz, SourceMaxHz,
    CurrentFrame, Settings.SourceLayer);
  if (not BandsValid) and (GetViewEditState = 0) then
    UpdateViewSpectrumLatestForEdit(Settings.Smooth, Bands, BandsValid,
      SourceMinHz, SourceMaxHz, Settings.SourceLayer);
  InputValid := BandsValid;
  InputPeak := PeakBandValue(Bands);
  ResolveEditBands(Bands, BandsValid, SourceMinHz, SourceMaxHz, Settings.SourceLayer,
    CacheUsed);
  OutputPeak := PeakBandValue(Bands);

  Count := Max(8, Min(128, Settings.Density));
  Radius := Max(16.0, Min(Video^.Object_^.Width, Video^.Object_^.Height) *
    Max(10, Min(90, Settings.BaseRadius)) / 200.0);
  MaxHeight := Max(16.0, Video^.Object_^.Height * 0.42 *
    Max(10, Min(500, Settings.YScale)) / 100.0);
  XScale := Max(10, Min(500, Settings.XScale)) / 100.0;
  ZScale := Max(10, Min(500, Settings.ZScale)) / 100.0;
  ArcPitch := 2.0 * Pi * Radius / Count;
  BarWidth := Max(1.0, ArcPitch - Max(0, Min(32, Settings.Spacing)));
  HalfWidth := BarWidth * 0.5;
  HalfDepth := Max(0.5, Min(32, Settings.Thickness) * 0.5);

  BlockGap := Max(0, Min(32, Settings.Spacing));
  BlockHeight := Max(2.0, BarWidth * 0.62);
  BlockCount := Max(1, Min(32, Floor((MaxHeight + BlockGap) /
    Max(1.0, BlockHeight + BlockGap))));
  if Settings.Style = VIEW_STYLE_BLOCKS then
    SetLength(Vertices, Count * BlockCount * 24)
  else
    SetLength(Vertices, Count * 24);

  VertexIndex := 0;
  for Band := 0 to Count - 1 do
  begin
    Value := Max(0.02, Min(1.0, GetSpectrumDisplayValue(Bands, BandsValid,
      SourceMinHz, SourceMaxHz, Settings, Band, Count)));
    Angle := -Pi / 2.0 + (2.0 * Pi * Band / Count);
    GetViewColor(Settings, Band, Count, R, G, B);

    if Settings.Style = VIEW_STYLE_BLOCKS then
    begin
      FillCount := Round(BlockCount * Value);
      for Block := 0 to FillCount - 1 do
      begin
        BaseY := -Block * (BlockHeight + BlockGap);
        TopY := BaseY - BlockHeight;
        AddBox(Vertices, VertexIndex, Angle, Radius, HalfWidth, HalfDepth,
          BaseY, TopY, XScale, ZScale, R, G, B);
      end;
    end
    else
    begin
      BaseY := 0.0;
      TopY := BaseY - MaxHeight * Value;
      AddBox(Vertices, VertexIndex, Angle, Radius, HalfWidth, HalfDepth,
        BaseY, TopY, XScale, ZScale, R, G, B);
    end;
  end;

  SetLength(Vertices, VertexIndex);
  if Length(Vertices) = 0 then
  begin
    WriteView3DLog(Format(
      'frame=%d objectFrame=%d range=%d..%d edit=%d inputValid=%d inputPeak=%.6f '+
      'cacheValid=%d cacheUsed=%d outputValid=%d outputPeak=%.6f vertices=0 %s',
      [CurrentFrame, Video^.Object_^.Frame, Video^.Object_^.FrameS, Video^.Object_^.FrameE,
       GetViewEditState, Ord(InputValid), InputPeak, Ord(LastEditBandsValid), Ord(CacheUsed),
       Ord(BandsValid), OutputPeak, LastViewSpectrumDiagnostic]));
    Exit;
  end;

  DrawSucceeded := Video^.DrawPoly(VERTEX_QUAD_COLOR, @Vertices[0], Length(Vertices), nil) <> 0;
  Result := DrawSucceeded;
  WriteView3DLog(Format(
    'frame=%d objectFrame=%d range=%d..%d edit=%d inputValid=%d inputPeak=%.6f '+
    'cacheValid=%d cacheUsed=%d outputValid=%d outputPeak=%.6f style=%d blocks=%d '+
    'vertices=%d draw=%d %s',
    [CurrentFrame, Video^.Object_^.Frame, Video^.Object_^.FrameS, Video^.Object_^.FrameE,
     GetViewEditState, Ord(InputValid), InputPeak, Ord(LastEditBandsValid), Ord(CacheUsed),
     Ord(BandsValid), OutputPeak, Settings.Style, BlockCount, Length(Vertices),
     Ord(DrawSucceeded), LastViewSpectrumDiagnostic]));
  if Result and Assigned(Video^.SetDefaultAnchor) then
    Video^.SetDefaultAnchor(Video^.Object_^.Width, Video^.Object_^.Height);
end;

end.
