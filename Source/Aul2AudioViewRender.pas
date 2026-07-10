unit Aul2AudioViewRender;

// Builds the first visible frame for Aul2AudioView and sends it to AviUtl2.

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

procedure RenderView(Video: PFILTER_PROC_VIDEO; const Settings: TAul2AudioViewSettings);

implementation

uses
  System.SysUtils,
  AviUtl2GpuTextureOut,
  Aul2AudioViewRenderCircularSpectrum,
  Aul2AudioViewRenderEqualizer,
  Aul2AudioViewRenderFilledSpectrum,
  Aul2AudioViewRenderMirrorBars,
  Aul2AudioViewRenderPixelWave,
  Aul2AudioViewRenderPulseWave,
  Aul2AudioViewRenderWaveLine;

const
  GPU_TEXTURE_OUT_STAGE1 = False;

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
  Result := ObjectInfo^.FrameS + ObjectInfo^.Frame;
end;

procedure DrawViewType(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
begin
  case Settings.ViewType of
    VIEW_TYPE_EQUALIZER_BARS: DrawEqualizerBars(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_WAVE_LINE: DrawWaveLine(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_PIXEL_WAVE: DrawPixelWave(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_FILLED_SPECTRUM: DrawFilledSpectrum(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_PULSE_WAVE: DrawPulseWave(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_CIRCULAR_SPECTRUM: DrawCircularSpectrum(Buffer, Width, Height, Settings, CurrentFrame);
    VIEW_TYPE_MIRROR_BARS: DrawMirrorBars(Buffer, Width, Height, Settings, CurrentFrame);
  else
    DrawEqualizerBars(Buffer, Width, Height, Settings, CurrentFrame);
  end;
end;

procedure RenderView(Video: PFILTER_PROC_VIDEO; const Settings: TAul2AudioViewSettings);
var
  Width: Integer;
  Height: Integer;
  CurrentFrame: Integer;
  Buffer: PPIXEL_RGBA;
  BufferSize: NativeUInt;
begin
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  Width := Video^.Object_^.Width;
  Height := Video^.Object_^.Height;
  if (Width <= 0) or (Height <= 0) then
    Exit;

  CurrentFrame := GetCurrentFrame(Video);

  BufferSize := NativeUInt(Width) * NativeUInt(Height) * SizeOf(TPIXEL_RGBA);
  GetMem(Buffer, BufferSize);
  try
    DrawViewType(Buffer, Width, Height, Settings, CurrentFrame);
    OutputImageData(Video, Buffer, Width, Height);
  finally
    FreeMem(Buffer);
  end;
end;

end.
