unit Aul2AudioMonitorSpectrumShared;

// Aul2AudioMonitor のスペクトラム表示専用共有メモリ構造体。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_MONITOR_SPECTRUM_SHARED_NAME    = 'Local\Aul2AudioMonitorSpectrum';
  AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC   = $41535043; // ASPC
  AUDIO_MONITOR_SPECTRUM_SHARED_VERSION = 6;
  AUDIO_MONITOR_SPECTRUM_BAND_COUNT     = 64;
  AUDIO_MONITOR_SPECTRUM_BAND_LAST      = AUDIO_MONITOR_SPECTRUM_BAND_COUNT - 1;
  AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT  = 128;
  AUDIO_MONITOR_SPECTRUM_HISTORY_LAST   = AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT - 1;

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
    HistoryIndex: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of Integer;
    Slots     : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioMonitorSpectrumState;
    History   : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST, 0..AUDIO_MONITOR_SPECTRUM_HISTORY_LAST] of TAul2AudioMonitorSpectrumState;
  end;

  TAul2AudioMonitorSpectrumSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioMonitorLayeredSpectrumState;
    function GetState: PAul2AudioMonitorSpectrumState;
  public
    constructor Create; reintroduce;
    function GetStateForLayer(Layer: Integer): PAul2AudioMonitorSpectrumState;
    function GetHistoryStateForLayer(Layer, Index: Integer): PAul2AudioMonitorSpectrumState;
    property Root: PAul2AudioMonitorLayeredSpectrumState read GetRoot;
    property State: PAul2AudioMonitorSpectrumState read GetState;
  end;

implementation

constructor TAul2AudioMonitorSpectrumSharedMemory.Create;
var
  Layer: Integer;
  Index: Integer;
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
      if (Root^.HistoryIndex[Layer] < 0) or
         (Root^.HistoryIndex[Layer] > AUDIO_MONITOR_SPECTRUM_HISTORY_LAST) then
        Root^.HistoryIndex[Layer] := 0;
      for Index := 0 to AUDIO_MONITOR_SPECTRUM_HISTORY_LAST do
      begin
        Root^.History[Layer, Index].Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
        Root^.History[Layer, Index].Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
        Root^.History[Layer, Index].SourceLayer := Layer;
        Root^.History[Layer, Index].BandCount := AUDIO_MONITOR_SPECTRUM_BAND_COUNT;
        Root^.History[Layer, Index].MinHz := 20;
        Root^.History[Layer, Index].MaxHz := 20000;
      end;
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

function TAul2AudioMonitorSpectrumSharedMemory.GetHistoryStateForLayer(
  Layer, Index: Integer): PAul2AudioMonitorSpectrumState;
begin
  if (Root = nil) or
     (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) or
     (Index < 0) or (Index > AUDIO_MONITOR_SPECTRUM_HISTORY_LAST) then
    Exit(nil);

  Result := @Root^.History[Layer, Index];
end;

end.
