unit Aul2AudioViewRender;

// 表示タイプ別の描画を振り分け、生成した RGBA 画像を AviUtl2 へ出力する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// Settings の描画経路を実行し、通常の画像出力を継続する場合 True を返す。
function RenderView(Video: PFILTER_PROC_VIDEO; const Settings: TAul2AudioViewSettings): Boolean;

implementation

uses
  System.SysUtils,
  AviUtl2GpuTextureOut,
  Aul2AudioViewRenderCircularSpectrum,
  Aul2AudioViewRenderCircular3D,
  Aul2AudioViewRenderEqualizer,
  Aul2AudioViewRenderFilledSpectrum,
  Aul2AudioViewRenderMirrorBars,
  Aul2AudioViewRenderPixelWave,
  Aul2AudioViewRenderPulseWave,
  Aul2AudioViewRenderRadialWaveform3D,
  Aul2AudioViewRenderSpectrumLandscape3D,
  Aul2AudioViewRenderWaveformTunnel3D,
  Aul2AudioViewRenderVectorscope,
  Aul2AudioViewRenderWaveLine;

const
  GPU_TEXTURE_OUT_STAGE1 = False; // GPU 出力は検証用。通常は安定している SetImageData を使う。

procedure OutputImageData(Video: PFILTER_PROC_VIDEO; Buffer: Pointer; Width, Height: Integer);
begin
  if (Video = nil) or (Buffer = nil) then
    Exit;

  if GPU_TEXTURE_OUT_STAGE1 then
    if TryOutputBufferAsTexture(Video, Buffer, Width, Height) then
      Exit;

  if Assigned(Video^.SetImageData) then
    Video^.SetImageData(PPIXEL_RGBA(Buffer), Width, Height);
end;

function GetCurrentFrame(Video: PFILTER_PROC_VIDEO): Integer;
var
  ObjectInfo: POBJECT_INFO;
begin
  Result := -1;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  ObjectInfo := Video^.Object_;
  // 共有メモリ履歴との同期に使うため、オブジェクト内ではなく編集全体のフレームへ正規化する。
  Result := ObjectInfo^.FrameS + ObjectInfo^.Frame;
end;

procedure DrawViewType(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
begin
  // 未知の値は Equalizer Bars へ戻し、破損した設定でも透明な未初期化バッファを出力しない。
  case Settings.ViewType of
    VIEW_TYPE_EQUALIZER_BARS: DrawEqualizerBars(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_WAVE_LINE: DrawWaveLine(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_PIXEL_WAVE: DrawPixelWave(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_FILLED_SPECTRUM: DrawFilledSpectrum(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_PULSE_WAVE: DrawPulseWave(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_CIRCULAR_SPECTRUM: DrawCircularSpectrum(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_MIRROR_BARS: DrawMirrorBars(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_VECTORSCOPE: DrawVectorscope(Buffer, Width, Height, Settings, CurrentFrame);
  else
    DrawEqualizerBars(Buffer, Width, Height, Settings, CurrentFrame);
  end;
end;

function RenderView(Video: PFILTER_PROC_VIDEO; const Settings: TAul2AudioViewSettings): Boolean;
var
  Width: Integer;
  Height: Integer;
  CurrentFrame: Integer;
  Buffer: PPIXEL_RGBA;
  BufferSize: NativeUInt;
begin
  Result := True;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  Width := Video^.Object_^.Width;
  Height := Video^.Object_^.Height;
  if (Width <= 0) or (Height <= 0) then
    Exit;

  CurrentFrame := GetCurrentFrame(Video);

  if Settings.ViewType = VIEW_TYPE_CIRCULAR_BARS_3D then
  begin
    // 3D経路が利用できればフレームバッファへ直接描き、通常の画像出力を中断する。
    if DrawCircularBars3D(Video, Settings, CurrentFrame) then
    begin
      Result := False;
      Exit;
    end;
    // 未対応環境や描画失敗時は、同系統の既存CPU表示へ安全に戻す。
    BufferSize := NativeUInt(Width) * NativeUInt(Height) * SizeOf(TPIXEL_RGBA);
    GetMem(Buffer, BufferSize);
    try
      DrawCircularSpectrum(Buffer, Width, Height, Settings, CurrentFrame);
      OutputImageData(Video, Buffer, Width, Height);
    finally
      FreeMem(Buffer);
    end;
    Exit;
  end;

  if Settings.ViewType = VIEW_TYPE_RADIAL_WAVEFORM_3D then
  begin
    if DrawRadialWaveform3D(Video, Settings, CurrentFrame) then
    begin
      Result := False;
      Exit;
    end;
    // 3D描画が利用できない場合も、同じ時間波形を使う既存表示へ戻す。
    BufferSize := NativeUInt(Width) * NativeUInt(Height) * SizeOf(TPIXEL_RGBA);
    GetMem(Buffer, BufferSize);
    try
      DrawWaveLine(Buffer, Width, Height, Settings, CurrentFrame);
      OutputImageData(Video, Buffer, Width, Height);
    finally
      FreeMem(Buffer);
    end;
    Exit;
  end;

  if Settings.ViewType = VIEW_TYPE_SPECTRUM_LANDSCAPE_3D then
  begin
    if DrawSpectrumLandscape3D(Video, Settings, CurrentFrame) then
    begin
      Result := False;
      Exit;
    end;
    // 3D描画が利用できない場合も、同じスペクトラムを使う既存表示へ戻す。
    BufferSize := NativeUInt(Width) * NativeUInt(Height) * SizeOf(TPIXEL_RGBA);
    GetMem(Buffer, BufferSize);
    try
      DrawFilledSpectrum(Buffer, Width, Height, Settings, CurrentFrame);
      OutputImageData(Video, Buffer, Width, Height);
    finally
      FreeMem(Buffer);
    end;
    Exit;
  end;

  if Settings.ViewType = VIEW_TYPE_WAVEFORM_TUNNEL_3D then
  begin
    if DrawWaveformTunnel3D(Video, Settings, CurrentFrame) then
    begin
      Result := False;
      Exit;
    end;
    // 3D描画が利用できない場合も、同じ時間波形を使う既存表示へ戻す。
    BufferSize := NativeUInt(Width) * NativeUInt(Height) * SizeOf(TPIXEL_RGBA);
    GetMem(Buffer, BufferSize);
    try
      DrawWaveLine(Buffer, Width, Height, Settings, CurrentFrame);
      OutputImageData(Video, Buffer, Width, Height);
    finally
      FreeMem(Buffer);
    end;
    Exit;
  end;

  BufferSize := NativeUInt(Width) * NativeUInt(Height) * SizeOf(TPIXEL_RGBA);
  GetMem(Buffer, BufferSize);
  try
    // 描画ユニットが全画素を初期化してから、同じ寿命内に AviUtl2 へコピーする。
    DrawViewType(Buffer, Width, Height, Settings, CurrentFrame);
    OutputImageData(Video, Buffer, Width, Height);
  finally
    FreeMem(Buffer);
  end;
end;

end.
