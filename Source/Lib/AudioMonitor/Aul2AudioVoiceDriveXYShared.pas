unit Aul2AudioVoiceDriveXYShared;

// VoiceDrive処理直前・直後の対応サンプルをFilterとControllerで共有する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_VOICE_DRIVE_XY_SHARED_NAME = 'Local\Aul2AudioVoiceDriveXYV2';
  AUDIO_VOICE_DRIVE_XY_SHARED_MAGIC = $56445859; // VDXY
  AUDIO_VOICE_DRIVE_XY_SHARED_VERSION = 2;
  AUDIO_VOICE_DRIVE_XY_SAMPLE_COUNT = 256;
  AUDIO_VOICE_DRIVE_XY_SAMPLE_LAST = AUDIO_VOICE_DRIVE_XY_SAMPLE_COUNT - 1;

type
  TAudioVoiceDriveXYData = array[0..AUDIO_VOICE_DRIVE_XY_SAMPLE_LAST] of Single;

  PAul2AudioVoiceDriveXYState = ^TAul2AudioVoiceDriveXYState;
  TAul2AudioVoiceDriveXYState = record
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
    InputSamples: TAudioVoiceDriveXYData;
    OutputSamples: TAudioVoiceDriveXYData;
  end;

  PAul2AudioVoiceDriveXYRoot = ^TAul2AudioVoiceDriveXYRoot;
  TAul2AudioVoiceDriveXYRoot = record
    Magic: Cardinal;
    Version: Cardinal;
    Generation: Int64;
    LastLayer: Integer;
    Slots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioVoiceDriveXYState;
  end;

  TAul2AudioVoiceDriveXYSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioVoiceDriveXYRoot;
    function GetState: PAul2AudioVoiceDriveXYState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioVoiceDriveXYState;
    property Root: PAul2AudioVoiceDriveXYRoot read GetRoot;
    property State: PAul2AudioVoiceDriveXYState read GetState;
  end;

implementation

constructor TAul2AudioVoiceDriveXYSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_VOICE_DRIVE_XY_SHARED_NAME,
    SizeOf(TAul2AudioVoiceDriveXYRoot));
  if Root = nil then
    Exit;
  if IsOwner or (Root^.Magic <> AUDIO_VOICE_DRIVE_XY_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_VOICE_DRIVE_XY_SHARED_VERSION) then
  begin
    FillChar(Root^, SizeOf(Root^), 0);
    Root^.Magic := AUDIO_VOICE_DRIVE_XY_SHARED_MAGIC;
    Root^.Version := AUDIO_VOICE_DRIVE_XY_SHARED_VERSION;
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
  end;
  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_VOICE_DRIVE_XY_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_VOICE_DRIVE_XY_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
  end;
end;

function TAul2AudioVoiceDriveXYSharedMemory.GetRoot: PAul2AudioVoiceDriveXYRoot;
begin
  Result := PAul2AudioVoiceDriveXYRoot(View);
end;

function TAul2AudioVoiceDriveXYSharedMemory.GetState: PAul2AudioVoiceDriveXYState;
begin
  if (Root = nil) or (Root^.Magic <> AUDIO_VOICE_DRIVE_XY_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_VOICE_DRIVE_XY_SHARED_VERSION) then
    Exit(nil);
  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioVoiceDriveXYSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioVoiceDriveXYState;
begin
  if (Root = nil) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

end.
