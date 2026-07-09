unit AviUtl2GpuTextureOut;

// Optional D3D11 texture output path for AviUtl2 video filters.

interface

uses
  Winapi.Windows,
  Aul2AudioFilterTypes;

function TryOutputBufferAsTexture(Video: PFILTER_PROC_VIDEO; Buffer: Pointer; Width, Height: Integer): Boolean;
function LastGpuTextureOutStatus: string;

implementation

uses
  System.SysUtils;

type
  TDxgiSampleDesc = record
    Count: LongWord;
    Quality: LongWord;
  end;

  TD3D11Texture2DDesc = record
    Width: LongWord;
    Height: LongWord;
    MipLevels: LongWord;
    ArraySize: LongWord;
    Format: LongWord;
    SampleDesc: TDxgiSampleDesc;
    Usage: LongWord;
    BindFlags: LongWord;
    CPUAccessFlags: LongWord;
    MiscFlags: LongWord;
  end;

  TD3D11SubresourceData = record
    pSysMem: Pointer;
    SysMemPitch: LongWord;
    SysMemSlicePitch: LongWord;
  end;

  TGetDevice = procedure(Self: Pointer; out Device: Pointer); stdcall;
  TGetTexture2DDesc = procedure(Self: Pointer; out Desc: TD3D11Texture2DDesc); stdcall;
  TCreateTexture2D = function(Self: Pointer; const Desc: TD3D11Texture2DDesc;
    InitialData: Pointer; out Texture: Pointer): HResult; stdcall;
  TGetImmediateContext = procedure(Self: Pointer; out Context: Pointer); stdcall;
  TCopyResource = procedure(Self: Pointer; DstResource, SrcResource: Pointer); stdcall;
  TRelease = function(Self: Pointer): LongWord; stdcall;
  TNativeUIntArray = array[0..1023] of NativeUInt;
  PNativeUIntArray = ^TNativeUIntArray;

const
  DXGI_FORMAT_R8G8B8A8_TYPELESS = 27;
  DXGI_FORMAT_R8G8B8A8_UNORM = 28;
  DXGI_FORMAT_R8G8B8A8_UNORM_SRGB = 29;
  DXGI_FORMAT_B8G8R8A8_UNORM = 87;
  DXGI_FORMAT_B8G8R8A8_TYPELESS = 90;
  DXGI_FORMAT_B8G8R8A8_UNORM_SRGB = 91;

  D3D11_USAGE_DEFAULT = 0;

var
  GLastStatus: string = '';

function LastGpuTextureOutStatus: string;
begin
  Result := GLastStatus;
end;

procedure SetStatus(const S: string);
begin
  GLastStatus := S;
  OutputDebugString(PChar('AviUtl2GpuTextureOut: ' + S));
end;

function VTableMethod(Instance: Pointer; Index: NativeUInt): Pointer;
begin
  Result := Pointer(PNativeUIntArray(PPointer(Instance)^)^[Index]);
end;

procedure ReleaseCom(var Instance: Pointer);
var
  Release: TRelease;
begin
  if Instance = nil then Exit;

  Release := TRelease(VTableMethod(Instance, 2));
  Release(Instance);
  Instance := nil;
end;

function IsRgbaFormat(const Format: LongWord): Boolean;
begin
  Result := Format in [
    DXGI_FORMAT_R8G8B8A8_TYPELESS,
    DXGI_FORMAT_R8G8B8A8_UNORM,
    DXGI_FORMAT_R8G8B8A8_UNORM_SRGB
  ];
end;

function IsBgraFormat(const Format: LongWord): Boolean;
begin
  Result := Format in [
    DXGI_FORMAT_B8G8R8A8_UNORM,
    DXGI_FORMAT_B8G8R8A8_TYPELESS,
    DXGI_FORMAT_B8G8R8A8_UNORM_SRGB
  ];
end;

procedure ConvertRgbaToBgra(const Src, Dst: Pointer; const PixelCount: NativeUInt);
var
  I: NativeUInt;
  S, D: PByte;
begin
  S := Src;
  D := Dst;
  for I := 0 to PixelCount - 1 do
  begin
    D[0] := S[2];
    D[1] := S[1];
    D[2] := S[0];
    D[3] := S[3];
    Inc(S, 4);
    Inc(D, 4);
  end;
end;

function TryOutputBufferAsTexture(Video: PFILTER_PROC_VIDEO; Buffer: Pointer; Width, Height: Integer): Boolean;
var
  Framebuffer: Pointer;
  Device: Pointer;
  Context: Pointer;
  SrcTexture: Pointer;
  Desc: TD3D11Texture2DDesc;
  InitData: TD3D11SubresourceData;
  UploadBuffer: Pointer;
  UploadSize: NativeUInt;
  HR: HResult;
  GetDevice: TGetDevice;
  GetDesc: TGetTexture2DDesc;
  CreateTexture2D: TCreateTexture2D;
  GetImmediateContext: TGetImmediateContext;
  CopyResource: TCopyResource;
begin
  Result := False;
  Device := nil;
  Context := nil;
  SrcTexture := nil;
  UploadBuffer := nil;

  if (Video = nil) or (Buffer = nil) or (Width <= 0) or (Height <= 0) then
  begin
    SetStatus('invalid argument');
    Exit;
  end;

  if not Assigned(Video^.GetFramebufferTexture2D) then
  begin
    SetStatus('GetFramebufferTexture2D is not assigned');
    Exit;
  end;

  Framebuffer := Video^.GetFramebufferTexture2D;
  if Framebuffer = nil then
  begin
    SetStatus('framebuffer texture is nil');
    Exit;
  end;

  try
    try
      GetDesc := TGetTexture2DDesc(VTableMethod(Framebuffer, 10));
      GetDesc(Framebuffer, Desc);

      if (Desc.Width <> LongWord(Width)) or (Desc.Height <> LongWord(Height)) then
      begin
        SetStatus(Format('framebuffer size mismatch: %dx%d <> %dx%d', [Desc.Width, Desc.Height, Width, Height]));
        Exit;
      end;

      if Desc.SampleDesc.Count <> 1 then
      begin
        SetStatus(Format('multisample framebuffer is not supported: %d', [Desc.SampleDesc.Count]));
        Exit;
      end;

      if not (IsRgbaFormat(Desc.Format) or IsBgraFormat(Desc.Format)) then
      begin
        SetStatus(Format('unsupported framebuffer format: %d', [Desc.Format]));
        Exit;
      end;

      GetDevice := TGetDevice(VTableMethod(Framebuffer, 3));
      GetDevice(Framebuffer, Device);
      if Device = nil then
      begin
        SetStatus('failed to get D3D11 device');
        Exit;
      end;

      GetImmediateContext := TGetImmediateContext(VTableMethod(Device, 40));
      GetImmediateContext(Device, Context);
      if Context = nil then
      begin
        SetStatus('failed to get D3D11 immediate context');
        Exit;
      end;

      UploadSize := NativeUInt(Width) * NativeUInt(Height) * 4;
      if IsBgraFormat(Desc.Format) then
      begin
        GetMem(UploadBuffer, UploadSize);
        ConvertRgbaToBgra(Buffer, UploadBuffer, NativeUInt(Width) * NativeUInt(Height));
      end
      else
        UploadBuffer := Buffer;

      Desc.MipLevels := 1;
      Desc.ArraySize := 1;
      Desc.Usage := D3D11_USAGE_DEFAULT;
      Desc.BindFlags := 0;
      Desc.CPUAccessFlags := 0;
      Desc.MiscFlags := 0;

      InitData.pSysMem := UploadBuffer;
      InitData.SysMemPitch := LongWord(Width * 4);
      InitData.SysMemSlicePitch := LongWord(UploadSize);

      CreateTexture2D := TCreateTexture2D(VTableMethod(Device, 5));
      HR := CreateTexture2D(Device, Desc, @InitData, SrcTexture);
      if Failed(HR) or (SrcTexture = nil) then
      begin
        SetStatus(Format('CreateTexture2D failed: 0x%.8x', [LongWord(HR)]));
        Exit;
      end;

      CopyResource := TCopyResource(VTableMethod(Context, 47));
      CopyResource(Context, Framebuffer, SrcTexture);

      SetStatus('gpu texture output succeeded');
      Result := True;
    except
      on E: Exception do
      begin
        SetStatus(E.ClassName + ': ' + E.Message);
        Result := False;
      end;
    end;
  finally
    if (UploadBuffer <> nil) and (UploadBuffer <> Buffer) then
      FreeMem(UploadBuffer);

    ReleaseCom(SrcTexture);
    ReleaseCom(Context);
    ReleaseCom(Device);
  end;
end;

end.
