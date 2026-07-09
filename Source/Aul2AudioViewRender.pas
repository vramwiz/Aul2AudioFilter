unit Aul2AudioViewRender;

// Builds the first visible frame for Aul2AudioView and sends it to AviUtl2.

interface

uses
  Aul2AudioFilterTypes;

procedure RenderView(Video: PFILTER_PROC_VIDEO; ViewType: Integer);

implementation

uses
  System.SysUtils,
  AviUtl2GpuTextureOut,
  Aul2AudioViewRenderEqualizer;

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

procedure DrawViewType(Buffer: PPIXEL_RGBA; Width, Height, ViewType: Integer);
begin
  case ViewType of
    0: DrawEqualizerBars(Buffer, Width, Height);
  else
    DrawEqualizerBars(Buffer, Width, Height);
  end;
end;

procedure RenderView(Video: PFILTER_PROC_VIDEO; ViewType: Integer);
var
  Width: Integer;
  Height: Integer;
  Buffer: PPIXEL_RGBA;
  BufferSize: NativeUInt;
begin
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  Width := Video^.Object_^.Width;
  Height := Video^.Object_^.Height;
  if (Width <= 0) or (Height <= 0) then
    Exit;

  BufferSize := NativeUInt(Width) * NativeUInt(Height) * SizeOf(TPIXEL_RGBA);
  GetMem(Buffer, BufferSize);
  try
    DrawViewType(Buffer, Width, Height, ViewType);
    OutputImageData(Video, Buffer, Width, Height);
  finally
    FreeMem(Buffer);
  end;
end;

end.
