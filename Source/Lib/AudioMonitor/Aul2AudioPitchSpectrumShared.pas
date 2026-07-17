unit Aul2AudioPitchSpectrumShared;

// Pitch処理直前・直後の高解像度スペクトルをFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_PITCH_SPECTRUM_SHARED_NAME = 'Local\Aul2AudioPitchSpectrumV2';
  AUDIO_PITCH_SPECTRUM_SHARED_MAGIC = $50535043; // PSPC
  AUDIO_PITCH_SPECTRUM_SHARED_VERSION = 2;
  AUDIO_PITCH_SPECTRUM_BAND_COUNT = 128;
  AUDIO_PITCH_SPECTRUM_BAND_LAST = AUDIO_PITCH_SPECTRUM_BAND_COUNT - 1;

type
  TAudioPitchSpectrumData = array[0..AUDIO_PITCH_SPECTRUM_BAND_LAST] of Single;

  PAul2AudioPitchSpectrumState = ^TAul2AudioPitchSpectrumState;
  TAul2AudioPitchSpectrumState = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    UpdateTick: UInt64;
    RequestId: TGUID;
    SourceLayer: Integer;
    SourceFrame: Integer;
    SourceFrameS: Integer;
    SourceFrameE: Integer;
    SampleRate: Integer;
    BandCount: Integer;
    MinHz: Single;
    MaxHz: Single;
    InputBands: TAudioPitchSpectrumData;
    OutputBands: TAudioPitchSpectrumData;
  end;

  PAul2AudioPitchSpectrumRoot = ^TAul2AudioPitchSpectrumRoot;
  TAul2AudioPitchSpectrumRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioPitchSpectrumState;
  end;

  TAul2AudioPitchSpectrumSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioPitchSpectrumRoot;
    function GetState: PAul2AudioPitchSpectrumState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioPitchSpectrumState;
    property Root: PAul2AudioPitchSpectrumRoot read GetRoot;
    property State: PAul2AudioPitchSpectrumState read GetState;
  end;

implementation

uses
  System.SysUtils;

constructor TAul2AudioPitchSpectrumSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_PITCH_SPECTRUM_SHARED_NAME,
    SizeOf(TAul2AudioPitchSpectrumRoot));
  if Root = nil then
    Exit;

  if IsOwner or (Root^.Magic <> AUDIO_PITCH_SPECTRUM_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_PITCH_SPECTRUM_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_PITCH_SPECTRUM_SHARED_MAGIC;
    Root^.Version := AUDIO_PITCH_SPECTRUM_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_PITCH_SPECTRUM_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_PITCH_SPECTRUM_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
    Root^.Slots[Layer].BandCount := AUDIO_PITCH_SPECTRUM_BAND_COUNT;
  end;
end;

function TAul2AudioPitchSpectrumSharedMemory.GetRoot: PAul2AudioPitchSpectrumRoot;
begin
  Result := PAul2AudioPitchSpectrumRoot(View);
end;

function TAul2AudioPitchSpectrumSharedMemory.GetState: PAul2AudioPitchSpectrumState;
begin
  if (Root = nil) or
     (Root^.Magic <> AUDIO_PITCH_SPECTRUM_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_PITCH_SPECTRUM_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioPitchSpectrumSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioPitchSpectrumState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
