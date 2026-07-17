unit Aul2AudioChorusSnapshotShared;

// Chorus処理の現在L/R遅延とステレオ相関をFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_CHORUS_SNAPSHOT_SHARED_NAME = 'Local\Aul2AudioChorusSnapshotV1';
  AUDIO_CHORUS_SNAPSHOT_SHARED_MAGIC = $4348534E; // CHSN
  AUDIO_CHORUS_SNAPSHOT_SHARED_VERSION = 1;

type
  PAul2AudioChorusSnapshotState = ^TAul2AudioChorusSnapshotState;
  TAul2AudioChorusSnapshotState = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    UpdateTick: UInt64;
    RequestId: TGUID;
    SourceLayer: Integer;
    SourceFrame: Integer;
    SampleRate: Integer;
    SampleIndex: Int64;
    CurrentDelayL: Single;
    CurrentDelayR: Single;
    LfoPhase: Single;
    Correlation: Single;
    CorrelationValid: LongBool;
  end;

  PAul2AudioChorusSnapshotRoot = ^TAul2AudioChorusSnapshotRoot;
  TAul2AudioChorusSnapshotRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of
      TAul2AudioChorusSnapshotState;
  end;

  TAul2AudioChorusSnapshotSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioChorusSnapshotRoot;
    function GetState: PAul2AudioChorusSnapshotState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioChorusSnapshotState;
    property Root: PAul2AudioChorusSnapshotRoot read GetRoot;
    property State: PAul2AudioChorusSnapshotState read GetState;
  end;

implementation

constructor TAul2AudioChorusSnapshotSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_CHORUS_SNAPSHOT_SHARED_NAME,
    SizeOf(TAul2AudioChorusSnapshotRoot));
  if Root = nil then
    Exit;
  if IsOwner or (Root^.Magic <> AUDIO_CHORUS_SNAPSHOT_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_CHORUS_SNAPSHOT_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_CHORUS_SNAPSHOT_SHARED_MAGIC;
    Root^.Version := AUDIO_CHORUS_SNAPSHOT_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_CHORUS_SNAPSHOT_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_CHORUS_SNAPSHOT_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
  end;
end;

function TAul2AudioChorusSnapshotSharedMemory.GetRoot:
  PAul2AudioChorusSnapshotRoot;
begin
  Result := PAul2AudioChorusSnapshotRoot(View);
end;

function TAul2AudioChorusSnapshotSharedMemory.GetState:
  PAul2AudioChorusSnapshotState;
begin
  if (Root = nil) or (Root^.Magic <> AUDIO_CHORUS_SNAPSHOT_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_CHORUS_SNAPSHOT_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioChorusSnapshotSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioChorusSnapshotState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
