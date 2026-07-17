unit Aul2AudioRingModSpectrumShared;

// RingMod処理直前・直後の高解像度スペクトルをFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_RING_SPECTRUM_SHARED_NAME = 'Local\Aul2AudioRingModSpectrum';
  AUDIO_RING_SPECTRUM_SHARED_MAGIC = $52535043; // RSPC
  AUDIO_RING_SPECTRUM_SHARED_VERSION = 1;
  AUDIO_RING_SPECTRUM_BAND_COUNT = 128;
  AUDIO_RING_SPECTRUM_BAND_LAST = AUDIO_RING_SPECTRUM_BAND_COUNT - 1;

type
  TAudioRingSpectrumData = array[0..AUDIO_RING_SPECTRUM_BAND_LAST] of Single;

  PAul2AudioRingSpectrumState = ^TAul2AudioRingSpectrumState;
  TAul2AudioRingSpectrumState = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    UpdateTick: UInt64;
    SourceLayer: Integer;
    SourceFrame: Integer;
    SourceFrameS: Integer;
    SourceFrameE: Integer;
    SampleRate: Integer;
    BandCount: Integer;
    MinHz: Single;
    MaxHz: Single;
    InputBands: TAudioRingSpectrumData;
    OutputBands: TAudioRingSpectrumData;
  end;

  PAul2AudioRingSpectrumRoot = ^TAul2AudioRingSpectrumRoot;
  TAul2AudioRingSpectrumRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioRingSpectrumState;
  end;

  TAul2AudioRingSpectrumSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioRingSpectrumRoot;
    function GetState: PAul2AudioRingSpectrumState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioRingSpectrumState;
    property Root: PAul2AudioRingSpectrumRoot read GetRoot;
    property State: PAul2AudioRingSpectrumState read GetState;
  end;

implementation

uses
  System.SysUtils;

constructor TAul2AudioRingSpectrumSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_RING_SPECTRUM_SHARED_NAME,
    SizeOf(TAul2AudioRingSpectrumRoot));
  if Root = nil then
    Exit;
  if IsOwner or (Root^.Magic <> AUDIO_RING_SPECTRUM_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_RING_SPECTRUM_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_RING_SPECTRUM_SHARED_MAGIC;
    Root^.Version := AUDIO_RING_SPECTRUM_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_RING_SPECTRUM_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_RING_SPECTRUM_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
    Root^.Slots[Layer].BandCount := AUDIO_RING_SPECTRUM_BAND_COUNT;
  end;
end;

function TAul2AudioRingSpectrumSharedMemory.GetRoot: PAul2AudioRingSpectrumRoot;
begin
  Result := PAul2AudioRingSpectrumRoot(View);
end;

function TAul2AudioRingSpectrumSharedMemory.GetState: PAul2AudioRingSpectrumState;
begin
  if (Root = nil) or (Root^.Magic <> AUDIO_RING_SPECTRUM_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_RING_SPECTRUM_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioRingSpectrumSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioRingSpectrumState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
