unit Aul2AudioNoiseWaveShared;

// Noise処理直前・直後の短い波形をFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_NOISE_WAVE_SHARED_NAME = 'Local\Aul2AudioNoiseWaveV2';
  AUDIO_NOISE_WAVE_SHARED_MAGIC = $4E575643; // NWVC
  AUDIO_NOISE_WAVE_SHARED_VERSION = 2;
  AUDIO_NOISE_WAVE_SAMPLE_COUNT = 256;
  AUDIO_NOISE_WAVE_SAMPLE_LAST = AUDIO_NOISE_WAVE_SAMPLE_COUNT - 1;

type
  TAudioNoiseWaveData = array[0..AUDIO_NOISE_WAVE_SAMPLE_LAST] of Single;

  PAul2AudioNoiseWaveState = ^TAul2AudioNoiseWaveState;
  TAul2AudioNoiseWaveState = record
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
    SampleCount: Integer;
    InputWave: TAudioNoiseWaveData;
    OutputWave: TAudioNoiseWaveData;
  end;

  PAul2AudioNoiseWaveRoot = ^TAul2AudioNoiseWaveRoot;
  TAul2AudioNoiseWaveRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioNoiseWaveState;
  end;

  TAul2AudioNoiseWaveSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioNoiseWaveRoot;
    function GetState: PAul2AudioNoiseWaveState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioNoiseWaveState;
    property Root: PAul2AudioNoiseWaveRoot read GetRoot;
    property State: PAul2AudioNoiseWaveState read GetState;
  end;

implementation

constructor TAul2AudioNoiseWaveSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_NOISE_WAVE_SHARED_NAME,
    SizeOf(TAul2AudioNoiseWaveRoot));
  if Root = nil then
    Exit;

  if IsOwner or (Root^.Magic <> AUDIO_NOISE_WAVE_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_NOISE_WAVE_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_NOISE_WAVE_SHARED_MAGIC;
    Root^.Version := AUDIO_NOISE_WAVE_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_NOISE_WAVE_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_NOISE_WAVE_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
  end;
end;

function TAul2AudioNoiseWaveSharedMemory.GetRoot: PAul2AudioNoiseWaveRoot;
begin
  Result := PAul2AudioNoiseWaveRoot(View);
end;

function TAul2AudioNoiseWaveSharedMemory.GetState: PAul2AudioNoiseWaveState;
begin
  if (Root = nil) or (Root^.Magic <> AUDIO_NOISE_WAVE_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_NOISE_WAVE_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioNoiseWaveSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioNoiseWaveState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
