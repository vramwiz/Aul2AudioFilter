unit Aul2AudioMonitorShared;

// Aul2AudioFilter と Aul2AudioMonitor の共有メモリ疎通データを扱う。

interface

uses
  System.SysUtils,
  SharedMemoryBase;

const
  AUDIO_MONITOR_SHARED_NAME    = 'Local\Aul2AudioMonitorState';
  AUDIO_MONITOR_SHARED_MAGIC   = $414D4F4E; // AMON
  AUDIO_MONITOR_SHARED_VERSION = 6;
  AUDIO_MONITOR_LAYER_SLOT_COUNT = 64;
  AUDIO_MONITOR_LAYER_SLOT_LAST  = AUDIO_MONITOR_LAYER_SLOT_COUNT - 1;
  AUDIO_MONITOR_LAYER_AUTO       = -1;
  AUDIO_MONITOR_WAVE_POINT_COUNT = 256;
  AUDIO_MONITOR_WAVE_POINT_LAST  = AUDIO_MONITOR_WAVE_POINT_COUNT - 1;

type
  TAudioMonitorWaveData = array[0..AUDIO_MONITOR_WAVE_POINT_LAST] of Single;

  PAul2AudioMonitorState = ^TAul2AudioMonitorState;
  TAul2AudioMonitorState = record
    Magic       : Cardinal;
    Version     : Cardinal;
    Generation  : Int64;
    UpdateTick  : UInt64;
    Stage       : Integer;
    SampleRate  : Integer;
    SampleNum   : Integer;
    ChannelNum  : Integer;
    SourceFrame : Integer;
    SourceFrameS: Integer;
    SourceFrameE: Integer;
    SourceLayer : Integer;
    SourceIndex : Integer;
    SampleIndex : Int64;
    InputPeakL  : Single;
    InputPeakR  : Single;
    OutputPeakL : Single;
    OutputPeakR : Single;
    InputRmsL   : Single;
    InputRmsR   : Single;
    OutputRmsL  : Single;
    OutputRmsR  : Single;
    InputWave   : TAudioMonitorWaveData;
    OutputWave  : TAudioMonitorWaveData;
    InputWaveMin: TAudioMonitorWaveData;
    InputWaveMax: TAudioMonitorWaveData;
    OutputWaveMin: TAudioMonitorWaveData;
    OutputWaveMax: TAudioMonitorWaveData;
  end;

  PAul2AudioMonitorLayeredState = ^TAul2AudioMonitorLayeredState;
  TAul2AudioMonitorLayeredState = record
    Magic     : Cardinal;
    Version   : Cardinal;
    Generation: Int64;
    LastLayer : Integer;
    Slots     : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioMonitorState;
  end;

  TAul2AudioMonitorSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioMonitorLayeredState;
    function GetState: PAul2AudioMonitorState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioMonitorState;
    property Root: PAul2AudioMonitorLayeredState read GetRoot;
    property State: PAul2AudioMonitorState read GetState;
  end;

implementation

constructor TAul2AudioMonitorSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_MONITOR_SHARED_NAME, SizeOf(TAul2AudioMonitorLayeredState));

  if Root <> nil then
  begin
    Root^.Magic := AUDIO_MONITOR_SHARED_MAGIC;
    Root^.Version := AUDIO_MONITOR_SHARED_VERSION;
    if (Root^.LastLayer < 0) or (Root^.LastLayer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
      Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;

    for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
    begin
      Root^.Slots[Layer].Magic := AUDIO_MONITOR_SHARED_MAGIC;
      Root^.Slots[Layer].Version := AUDIO_MONITOR_SHARED_VERSION;
      Root^.Slots[Layer].SourceLayer := Layer;
    end;
  end;
end;

function TAul2AudioMonitorSharedMemory.GetRoot: PAul2AudioMonitorLayeredState;
begin
  Result := PAul2AudioMonitorLayeredState(View);
end;

function TAul2AudioMonitorSharedMemory.GetState: PAul2AudioMonitorState;
begin
  if (Root = nil) or
     (Root^.Magic <> AUDIO_MONITOR_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_MONITOR_SHARED_VERSION) then
    Exit(nil);

  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioMonitorSharedMemory.GetStateForLayer(Layer: Integer): PAul2AudioMonitorState;
begin
  if (Root = nil) or (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);

  Result := @Root^.Slots[Layer];
end;

end.
