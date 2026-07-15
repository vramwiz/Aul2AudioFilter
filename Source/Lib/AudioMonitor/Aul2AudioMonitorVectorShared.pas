unit Aul2AudioMonitorVectorShared;

// Aul2AudioFilter と Monitor で共有するVectorscope専用L/R代表点を定義する。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_MONITOR_VECTOR_SHARED_NAME    = 'Local\Aul2AudioMonitorVector';
  AUDIO_MONITOR_VECTOR_SHARED_MAGIC   = $41564543; // AVEC
  AUDIO_MONITOR_VECTOR_SHARED_VERSION = 1;
  AUDIO_MONITOR_VECTOR_POINT_COUNT    = 64;
  AUDIO_MONITOR_VECTOR_POINT_LAST     = AUDIO_MONITOR_VECTOR_POINT_COUNT - 1;
  AUDIO_MONITOR_VECTOR_HISTORY_COUNT  = 128;
  AUDIO_MONITOR_VECTOR_HISTORY_LAST   = AUDIO_MONITOR_VECTOR_HISTORY_COUNT - 1;
  AUDIO_MONITOR_VECTOR_REQUEST_MS     = 250; // 表示要求が途切れてから取得を停止するまでの猶予。

type
  TAudioMonitorVectorData = array[0..AUDIO_MONITOR_VECTOR_POINT_LAST] of Single;

  // 1レイヤー、1解析時点の処理前/処理後L/R代表点と音声位置を保持する。
  PAul2AudioMonitorVectorState = ^TAul2AudioMonitorVectorState;
  TAul2AudioMonitorVectorState = record
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
    PointCount  : Integer;
    InputLeft   : TAudioMonitorVectorData;
    InputRight  : TAudioMonitorVectorData;
    OutputLeft  : TAudioMonitorVectorData;
    OutputRight : TAudioMonitorVectorData;
  end;

  PAul2AudioMonitorLayeredVectorState = ^TAul2AudioMonitorLayeredVectorState;
  TAul2AudioMonitorLayeredVectorState = record
    Magic       : Cardinal;
    Version     : Cardinal;
    Generation  : Int64;
    LastLayer   : Integer;
    RequestTick : UInt64; // MonitorのVectorscopeページが表示中であることをFilterへ通知する。
    HistoryIndex: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of Integer;
    Slots       : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioMonitorVectorState;
    History     : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST,
      0..AUDIO_MONITOR_VECTOR_HISTORY_LAST] of TAul2AudioMonitorVectorState;
  end;

  TAul2AudioMonitorVectorSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioMonitorLayeredVectorState;
    function GetState: PAul2AudioMonitorVectorState;
  public
    // Vectorscope用マップを開き、各レイヤーと履歴の識別情報を初期化する。
    constructor Create; reintroduce;
    // 表示要求時刻を更新し、Filter側のL/R代表点取得を有効にする。
    procedure RequestCapture;
    // 指定レイヤーの最新状態を返す。
    function GetStateForLayer(Layer: Integer): PAul2AudioMonitorVectorState;
    // 指定レイヤーとリング添字の履歴状態を返す。
    function GetHistoryStateForLayer(Layer, Index: Integer): PAul2AudioMonitorVectorState;
    property Root: PAul2AudioMonitorLayeredVectorState read GetRoot;
    property State: PAul2AudioMonitorVectorState read GetState;
  end;

implementation

uses
  Winapi.Windows;

constructor TAul2AudioMonitorVectorSharedMemory.Create;
var
  Index: Integer;
  Layer: Integer;
begin
  inherited Create(AUDIO_MONITOR_VECTOR_SHARED_NAME,
    SizeOf(TAul2AudioMonitorLayeredVectorState));

  if Root = nil then
    Exit;

  Root^.Magic := AUDIO_MONITOR_VECTOR_SHARED_MAGIC;
  Root^.Version := AUDIO_MONITOR_VECTOR_SHARED_VERSION;
  if (Root^.LastLayer < 0) or (Root^.LastLayer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Root^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;

  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    Root^.Slots[Layer].Magic := AUDIO_MONITOR_VECTOR_SHARED_MAGIC;
    Root^.Slots[Layer].Version := AUDIO_MONITOR_VECTOR_SHARED_VERSION;
    Root^.Slots[Layer].SourceLayer := Layer;
    Root^.Slots[Layer].PointCount := AUDIO_MONITOR_VECTOR_POINT_COUNT;
    if (Root^.HistoryIndex[Layer] < 0) or
       (Root^.HistoryIndex[Layer] > AUDIO_MONITOR_VECTOR_HISTORY_LAST) then
      Root^.HistoryIndex[Layer] := 0;
    for Index := 0 to AUDIO_MONITOR_VECTOR_HISTORY_LAST do
    begin
      Root^.History[Layer, Index].Magic := AUDIO_MONITOR_VECTOR_SHARED_MAGIC;
      Root^.History[Layer, Index].Version := AUDIO_MONITOR_VECTOR_SHARED_VERSION;
      Root^.History[Layer, Index].SourceLayer := Layer;
      Root^.History[Layer, Index].PointCount := AUDIO_MONITOR_VECTOR_POINT_COUNT;
    end;
  end;
end;

function TAul2AudioMonitorVectorSharedMemory.GetRoot: PAul2AudioMonitorLayeredVectorState;
begin
  Result := PAul2AudioMonitorLayeredVectorState(View);
end;

function TAul2AudioMonitorVectorSharedMemory.GetState: PAul2AudioMonitorVectorState;
begin
  if (Root = nil) or
     (Root^.Magic <> AUDIO_MONITOR_VECTOR_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_MONITOR_VECTOR_SHARED_VERSION) then
    Exit(nil);

  Result := GetStateForLayer(Root^.LastLayer);
end;

procedure TAul2AudioMonitorVectorSharedMemory.RequestCapture;
begin
  if (Root = nil) or
     (Root^.Magic <> AUDIO_MONITOR_VECTOR_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_MONITOR_VECTOR_SHARED_VERSION) then
    Exit;

  Root^.RequestTick := GetTickCount64;
end;

function TAul2AudioMonitorVectorSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioMonitorVectorState;
begin
  if (Root = nil) or (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);

  Result := @Root^.Slots[Layer];
end;

function TAul2AudioMonitorVectorSharedMemory.GetHistoryStateForLayer(
  Layer, Index: Integer): PAul2AudioMonitorVectorState;
begin
  if (Root = nil) or
     (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) or
     (Index < 0) or (Index > AUDIO_MONITOR_VECTOR_HISTORY_LAST) then
    Exit(nil);

  Result := @Root^.History[Layer, Index];
end;

end.
