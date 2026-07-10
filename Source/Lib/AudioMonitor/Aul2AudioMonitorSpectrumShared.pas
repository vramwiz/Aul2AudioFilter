unit Aul2AudioMonitorSpectrumShared;

// Aul2AudioMonitor のスペクトラム表示専用共有メモリ構造体。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_MONITOR_SPECTRUM_SHARED_NAME    = 'Local\Aul2AudioMonitorSpectrum';
  AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC   = $41535043; // ASPC
  AUDIO_MONITOR_SPECTRUM_SHARED_VERSION = 4;
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

  PAul2AudioMonitorLayeredSpectrumState = ^TAul2AudioMonitorLayeredSpectrumState;
  TAul2AudioMonitorLayeredSpectrumState = record
    Magic     : Cardinal;
    Version   : Cardinal;
    Generation: Int64;
    LastLayer : Integer;
    Slots     : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioMonitorSpectrumState;
  end;

  TAul2AudioMonitorSpectrumSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioMonitorLayeredSpectrumState;
    function GetState: PAul2AudioMonitorSpectrumState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioMonitorSpectrumState;
    property Root: PAul2AudioMonitorLayeredSpectrumState read GetRoot;
    property State: PAul2AudioMonitorSpectrumState read GetState;
  end;

implementation

constructor TAul2AudioMonitorSpectrumSharedMemory.Create;
var
  Layer: Integer;
begin
  inherited Create(AUDIO_MONITOR_SPECTRUM_SHARED_NAME,
    SizeOf(TAul2AudioMonitorLayeredSpectrumState));

  if Root <> nil then
  begin
    Root^.Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
    Root^.Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
    if (Root^.LastLayer < 0) or (Root^.LastLayer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
      Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;

    for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
    begin
      Root^.Slots[Layer].Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
      Root^.Slots[Layer].Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
      Root^.Slots[Layer].SourceLayer := Layer;
    end;
  end;
end;

function TAul2AudioMonitorSpectrumSharedMemory.GetRoot: PAul2AudioMonitorLayeredSpectrumState;
begin
  Result := PAul2AudioMonitorLayeredSpectrumState(View);
end;

function TAul2AudioMonitorSpectrumSharedMemory.GetState: PAul2AudioMonitorSpectrumState;
begin
  if (Root = nil) or
     (Root^.Magic <> AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_MONITOR_SPECTRUM_SHARED_VERSION) then
    Exit(nil);

  Result := GetStateForLayer(Root^.LastLayer);
end;

function TAul2AudioMonitorSpectrumSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioMonitorSpectrumState;
begin
  if (Root = nil) or (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);

  Result := @Root^.Slots[Layer];
end;

end.
