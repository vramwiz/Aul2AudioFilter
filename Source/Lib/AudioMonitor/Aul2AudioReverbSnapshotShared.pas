unit Aul2AudioReverbSnapshotShared;

// Reverb処理の最新Wet RMSをFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_REVERB_SNAPSHOT_SHARED_NAME = 'Local\Aul2AudioReverbSnapshotV1';
  AUDIO_REVERB_SNAPSHOT_SHARED_MAGIC = $5256534E; // RVSN
  AUDIO_REVERB_SNAPSHOT_SHARED_VERSION = 1;

type
  PAul2AudioReverbSnapshotState = ^TAul2AudioReverbSnapshotState;
  TAul2AudioReverbSnapshotState = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    UpdateTick: UInt64;
    RequestId: TGUID;
    SourceLayer: Integer;
    SourceFrame: Integer;
    SampleRate: Integer;
    SampleIndex: Int64;
    WetRms: Single;
  end;

  PAul2AudioReverbSnapshotRoot = ^TAul2AudioReverbSnapshotRoot;
  TAul2AudioReverbSnapshotRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of
      TAul2AudioReverbSnapshotState;
  end;

  TAul2AudioReverbSnapshotSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioReverbSnapshotRoot;
    function GetState: PAul2AudioReverbSnapshotState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioReverbSnapshotState;
    property Root: PAul2AudioReverbSnapshotRoot read GetRoot;
    property State: PAul2AudioReverbSnapshotState read GetState;
  end;

implementation

constructor TAul2AudioReverbSnapshotSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_REVERB_SNAPSHOT_SHARED_NAME,
    SizeOf(TAul2AudioReverbSnapshotRoot));
  if Root = nil then
    Exit;
  if IsOwner or (Root^.Magic <> AUDIO_REVERB_SNAPSHOT_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_REVERB_SNAPSHOT_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_REVERB_SNAPSHOT_SHARED_MAGIC;
    Root^.Version := AUDIO_REVERB_SNAPSHOT_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_REVERB_SNAPSHOT_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_REVERB_SNAPSHOT_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
  end;
end;

function TAul2AudioReverbSnapshotSharedMemory.GetRoot:
  PAul2AudioReverbSnapshotRoot;
begin
  Result := PAul2AudioReverbSnapshotRoot(View);
end;

function TAul2AudioReverbSnapshotSharedMemory.GetState:
  PAul2AudioReverbSnapshotState;
begin
  if (Root = nil) or (Root^.Magic <> AUDIO_REVERB_SNAPSHOT_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_REVERB_SNAPSHOT_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioReverbSnapshotSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioReverbSnapshotState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
