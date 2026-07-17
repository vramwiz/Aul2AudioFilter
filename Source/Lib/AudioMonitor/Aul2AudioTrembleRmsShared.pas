unit Aul2AudioTrembleRmsShared;

// Tremble処理直前・直後のRMS時間履歴をFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_TREMBLE_RMS_SHARED_NAME = 'Local\Aul2AudioTrembleRmsV1';
  AUDIO_TREMBLE_RMS_SHARED_MAGIC = $54524D53; // TRMS
  AUDIO_TREMBLE_RMS_SHARED_VERSION = 1;
  AUDIO_TREMBLE_RMS_HISTORY_COUNT = 192;
  AUDIO_TREMBLE_RMS_HISTORY_LAST = AUDIO_TREMBLE_RMS_HISTORY_COUNT - 1;

type
  TAudioTrembleRmsData = array[0..AUDIO_TREMBLE_RMS_HISTORY_LAST] of Single;
  TAudioTrembleSampleIndexData = array[0..AUDIO_TREMBLE_RMS_HISTORY_LAST] of Int64;

  PAul2AudioTrembleRmsState = ^TAul2AudioTrembleRmsState;
  TAul2AudioTrembleRmsState = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    UpdateTick: UInt64;
    RequestId: TGUID;
    SourceLayer: Integer;
    SourceFrame: Integer;
    SampleRate: Integer;
    HistoryCount: Integer;
    WriteIndex: Integer;
    LastSampleIndex: Int64;
    SampleIndices: TAudioTrembleSampleIndexData;
    InputRms: TAudioTrembleRmsData;
    OutputRms: TAudioTrembleRmsData;
  end;

  PAul2AudioTrembleRmsRoot = ^TAul2AudioTrembleRmsRoot;
  TAul2AudioTrembleRmsRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioTrembleRmsState;
  end;

  TAul2AudioTrembleRmsSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioTrembleRmsRoot;
    function GetState: PAul2AudioTrembleRmsState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioTrembleRmsState;
    property Root: PAul2AudioTrembleRmsRoot read GetRoot;
    property State: PAul2AudioTrembleRmsState read GetState;
  end;

implementation

constructor TAul2AudioTrembleRmsSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_TREMBLE_RMS_SHARED_NAME,
    SizeOf(TAul2AudioTrembleRmsRoot));
  if Root = nil then
    Exit;

  if IsOwner or (Root^.Magic <> AUDIO_TREMBLE_RMS_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_TREMBLE_RMS_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_TREMBLE_RMS_SHARED_MAGIC;
    Root^.Version := AUDIO_TREMBLE_RMS_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_TREMBLE_RMS_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_TREMBLE_RMS_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
  end;
end;

function TAul2AudioTrembleRmsSharedMemory.GetRoot: PAul2AudioTrembleRmsRoot;
begin
  Result := PAul2AudioTrembleRmsRoot(View);
end;

function TAul2AudioTrembleRmsSharedMemory.GetState: PAul2AudioTrembleRmsState;
begin
  if (Root = nil) or (Root^.Magic <> AUDIO_TREMBLE_RMS_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_TREMBLE_RMS_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioTrembleRmsSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioTrembleRmsState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
