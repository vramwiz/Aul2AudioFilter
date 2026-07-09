unit Aul2AudioMonitorShared;

// Aul2AudioFilter と Aul2AudioMonitor の共有メモリ疎通データを扱う。

interface

uses
  System.SysUtils,
  SharedMemoryBase;

const
  AUDIO_MONITOR_SHARED_NAME    = 'Local\Aul2AudioMonitorState';
  AUDIO_MONITOR_SHARED_MAGIC   = $414D4F4E; // AMON
  AUDIO_MONITOR_SHARED_VERSION = 5;
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

  TAul2AudioMonitorSharedMemory = class(TSharedMemoryBase)
  private
    function GetState: PAul2AudioMonitorState;
  public
    constructor Create; reintroduce;
    property State: PAul2AudioMonitorState read GetState;
  end;

implementation

constructor TAul2AudioMonitorSharedMemory.Create;
begin
  inherited Create(AUDIO_MONITOR_SHARED_NAME, SizeOf(TAul2AudioMonitorState));

  if State <> nil then
  begin
    State^.Magic := AUDIO_MONITOR_SHARED_MAGIC;
    State^.Version := AUDIO_MONITOR_SHARED_VERSION;
  end;
end;

function TAul2AudioMonitorSharedMemory.GetState: PAul2AudioMonitorState;
begin
  Result := PAul2AudioMonitorState(View);
end;

end.
