unit Aul2AudioWobbleSnapshotShared;

// Wobble処理の現在遅延量とLFO位相をFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_WOBBLE_SNAPSHOT_SHARED_NAME = 'Local\Aul2AudioWobbleSnapshotV1';
  AUDIO_WOBBLE_SNAPSHOT_SHARED_MAGIC = $5742534E; // WBSN
  AUDIO_WOBBLE_SNAPSHOT_SHARED_VERSION = 1;

type
  PAul2AudioWobbleSnapshotState = ^TAul2AudioWobbleSnapshotState;
  TAul2AudioWobbleSnapshotState = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    UpdateTick: UInt64;
    RequestId: TGUID;
    SourceLayer: Integer;
    SourceFrame: Integer;
    SampleRate: Integer;
    SampleIndex: Int64;
    CurrentDelayMs: Single;
    LfoPhase: Single;
  end;

  PAul2AudioWobbleSnapshotRoot = ^TAul2AudioWobbleSnapshotRoot;
  TAul2AudioWobbleSnapshotRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of
      TAul2AudioWobbleSnapshotState;
  end;

  TAul2AudioWobbleSnapshotSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioWobbleSnapshotRoot;
    function GetState: PAul2AudioWobbleSnapshotState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioWobbleSnapshotState;
    property Root: PAul2AudioWobbleSnapshotRoot read GetRoot;
    property State: PAul2AudioWobbleSnapshotState read GetState;
  end;

implementation

constructor TAul2AudioWobbleSnapshotSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_WOBBLE_SNAPSHOT_SHARED_NAME,
    SizeOf(TAul2AudioWobbleSnapshotRoot));
  if Root = nil then
    Exit;
  if IsOwner or (Root^.Magic <> AUDIO_WOBBLE_SNAPSHOT_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_WOBBLE_SNAPSHOT_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_WOBBLE_SNAPSHOT_SHARED_MAGIC;
    Root^.Version := AUDIO_WOBBLE_SNAPSHOT_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_WOBBLE_SNAPSHOT_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_WOBBLE_SNAPSHOT_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
  end;
end;

function TAul2AudioWobbleSnapshotSharedMemory.GetRoot:
  PAul2AudioWobbleSnapshotRoot;
begin
  Result := PAul2AudioWobbleSnapshotRoot(View);
end;

function TAul2AudioWobbleSnapshotSharedMemory.GetState:
  PAul2AudioWobbleSnapshotState;
begin
  if (Root = nil) or (Root^.Magic <> AUDIO_WOBBLE_SNAPSHOT_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_WOBBLE_SNAPSHOT_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioWobbleSnapshotSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioWobbleSnapshotState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
