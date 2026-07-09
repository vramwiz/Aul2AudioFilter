unit Aul2AudioMonitorSpectrumShared;

// Aul2AudioMonitor のスペクトラム表示専用共有メモリ構造体。

interface

uses
  SharedMemoryBase;

const
  AUDIO_MONITOR_SPECTRUM_SHARED_NAME    = 'Local\Aul2AudioMonitorSpectrum';
  AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC   = $41535043; // ASPC
  AUDIO_MONITOR_SPECTRUM_SHARED_VERSION = 3;
  AUDIO_MONITOR_SPECTRUM_BAND_COUNT     = 64;
  AUDIO_MONITOR_SPECTRUM_BAND_LAST      = AUDIO_MONITOR_SPECTRUM_BAND_COUNT - 1;

type
  TAudioMonitorSpectrumData = array[0..AUDIO_MONITOR_SPECTRUM_BAND_LAST] of Single;

  PAul2AudioMonitorSpectrumState = ^TAul2AudioMonitorSpectrumState;
  TAul2AudioMonitorSpectrumState = record
    Magic       : Cardinal;
    Version     : Cardinal;
    Generation  : Int64;
    UpdateTick  : UInt64;
    SampleRate  : Integer;
    SampleNum   : Integer;
    ChannelNum  : Integer;
    SourceFrame : Integer;
    SourceFrameS: Integer;
    SourceFrameE: Integer;
    SourceLayer : Integer;
    SourceIndex : Integer;
    SampleIndex : Int64;
    BandCount   : Integer;
    MinHz       : Single;
    MaxHz       : Single;
    InputBands  : TAudioMonitorSpectrumData;
    OutputBands : TAudioMonitorSpectrumData;
  end;

  TAul2AudioMonitorSpectrumSharedMemory = class(TSharedMemoryBase)
  private
    function GetState: PAul2AudioMonitorSpectrumState;
  public
    constructor Create; reintroduce;
    property State: PAul2AudioMonitorSpectrumState read GetState;
  end;

implementation

constructor TAul2AudioMonitorSpectrumSharedMemory.Create;
begin
  inherited Create(AUDIO_MONITOR_SPECTRUM_SHARED_NAME,
    SizeOf(TAul2AudioMonitorSpectrumState));

  if State <> nil then
  begin
    State^.Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
    State^.Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
  end;
end;

function TAul2AudioMonitorSpectrumSharedMemory.GetState: PAul2AudioMonitorSpectrumState;
begin
  Result := PAul2AudioMonitorSpectrumState(View);
end;

end.
