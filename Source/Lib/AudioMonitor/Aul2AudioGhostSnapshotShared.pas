unit Aul2AudioGhostSnapshotShared;

// Ghost処理で追加された最新残響RMSをFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_GHOST_SNAPSHOT_SHARED_NAME = 'Local\Aul2AudioGhostSnapshotV1';
  AUDIO_GHOST_SNAPSHOT_SHARED_MAGIC = $4748534E; // GHSN
  AUDIO_GHOST_SNAPSHOT_SHARED_VERSION = 1;

type
  PAul2AudioGhostSnapshotState = ^TAul2AudioGhostSnapshotState;
  TAul2AudioGhostSnapshotState = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    UpdateTick: UInt64;
    RequestId: TGUID;
    SourceLayer: Integer;
    SourceFrame: Integer;
    SampleRate: Integer;
    SampleIndex: Int64;
    AddedRms: Single;
  end;

  PAul2AudioGhostSnapshotRoot = ^TAul2AudioGhostSnapshotRoot;
  TAul2AudioGhostSnapshotRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of
      TAul2AudioGhostSnapshotState;
  end;

  TAul2AudioGhostSnapshotSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioGhostSnapshotRoot;
    function GetState: PAul2AudioGhostSnapshotState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioGhostSnapshotState;
    property Root: PAul2AudioGhostSnapshotRoot read GetRoot;
    property State: PAul2AudioGhostSnapshotState read GetState;
  end;

implementation

constructor TAul2AudioGhostSnapshotSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_GHOST_SNAPSHOT_SHARED_NAME,
    SizeOf(TAul2AudioGhostSnapshotRoot));
  if Root = nil then
    Exit;
  if IsOwner or (Root^.Magic <> AUDIO_GHOST_SNAPSHOT_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_GHOST_SNAPSHOT_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_GHOST_SNAPSHOT_SHARED_MAGIC;
    Root^.Version := AUDIO_GHOST_SNAPSHOT_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_GHOST_SNAPSHOT_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_GHOST_SNAPSHOT_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
  end;
end;

function TAul2AudioGhostSnapshotSharedMemory.GetRoot:
  PAul2AudioGhostSnapshotRoot;
begin
  Result := PAul2AudioGhostSnapshotRoot(View);
end;

function TAul2AudioGhostSnapshotSharedMemory.GetState:
  PAul2AudioGhostSnapshotState;
begin
  if (Root = nil) or (Root^.Magic <> AUDIO_GHOST_SNAPSHOT_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_GHOST_SNAPSHOT_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioGhostSnapshotSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioGhostSnapshotState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
