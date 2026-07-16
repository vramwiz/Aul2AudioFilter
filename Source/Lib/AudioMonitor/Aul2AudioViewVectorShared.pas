unit Aul2AudioViewVectorShared;

// Aul2AudioFilter と Aul2Audio View で共有する Vectorscope 用 Output L/R 代表点を扱う。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_VIEW_VECTOR_SHARED_NAME    = 'Local\Aul2AudioViewVector';
  AUDIO_VIEW_VECTOR_SHARED_MAGIC   = $41565643; // AVVC
  AUDIO_VIEW_VECTOR_SHARED_VERSION = 2;
  AUDIO_VIEW_VECTOR_POINT_COUNT    = 64;
  AUDIO_VIEW_VECTOR_POINT_LAST     = AUDIO_VIEW_VECTOR_POINT_COUNT - 1;
  AUDIO_VIEW_VECTOR_HISTORY_COUNT  = 256;
  AUDIO_VIEW_VECTOR_HISTORY_LAST   = AUDIO_VIEW_VECTOR_HISTORY_COUNT - 1;

type
  TAudioViewVectorData = array[0..AUDIO_VIEW_VECTOR_POINT_LAST] of Single;
  PAudioViewVectorData = ^TAudioViewVectorData;

  // 1回の音声処理で得た処理後L/R代表点と、映像フレーム同期に必要な位置を保持する。
  PAul2AudioViewVectorState = ^TAul2AudioViewVectorState;
  TAul2AudioViewVectorState = record
    Magic       : Cardinal;
    Version     : Cardinal;
    Generation  : Int64;
    UpdateTick  : UInt64;
    SourceFrame : Integer;
    SourceFrameS: Integer;
    SourceFrameE: Integer;
    SourceLayer : Integer;
    SourceIndex : Integer;
    SampleIndex : Int64;
    PointCount  : Integer;
    OutputLeft  : TAudioViewVectorData;
    OutputRight : TAudioViewVectorData;
  end;

  // 最新値はレイヤー別、同期履歴は全レイヤー共通リングとして保持してメモリ量を抑える。
  PAul2AudioViewVectorRoot = ^TAul2AudioViewVectorRoot;
  TAul2AudioViewVectorRoot = record
    Magic         : Cardinal;
    Version       : Cardinal;
    Generation    : Int64;
    HistoryIndex  : Integer;
    Slots         : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioViewVectorState;
    History       : array[0..AUDIO_VIEW_VECTOR_HISTORY_LAST] of TAul2AudioViewVectorState;
  end;

  TAul2AudioViewVectorSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioViewVectorRoot;
  public
    // 小型共有マップを開き、初回作成または版不一致時だけ内容を初期化する。
    constructor Create; reintroduce;
    // 指定レイヤーの最新状態を返す。
    function GetStateForLayer(Layer: Integer): PAul2AudioViewVectorState;
    // 全レイヤー共通リングの指定位置を返す。
    function GetHistoryState(Index: Integer): PAul2AudioViewVectorState;
    property Root: PAul2AudioViewVectorRoot read GetRoot;
  end;

implementation

procedure InitializeState(var State: TAul2AudioViewVectorState; Layer: Integer);
begin
  FillChar(State, SizeOf(State), 0);
  State.Magic := AUDIO_VIEW_VECTOR_SHARED_MAGIC;
  State.Version := AUDIO_VIEW_VECTOR_SHARED_VERSION;
  State.SourceLayer := Layer;
  State.PointCount := AUDIO_VIEW_VECTOR_POINT_COUNT;
end;

constructor TAul2AudioViewVectorSharedMemory.Create;
var
  Index: Integer;
begin
  inherited Create(AUDIO_VIEW_VECTOR_SHARED_NAME, SizeOf(TAul2AudioViewVectorRoot));
  if Root = nil then
    Exit;

  if (Root^.Magic = AUDIO_VIEW_VECTOR_SHARED_MAGIC) and
     (Root^.Version = AUDIO_VIEW_VECTOR_SHARED_VERSION) then
    Exit;

  FillChar(Root^, SizeOf(TAul2AudioViewVectorRoot), 0);
  Root^.Magic := AUDIO_VIEW_VECTOR_SHARED_MAGIC;
  Root^.Version := AUDIO_VIEW_VECTOR_SHARED_VERSION;
  Root^.HistoryIndex := 0;
  for Index := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
    InitializeState(Root^.Slots[Index], Index);
  for Index := 0 to AUDIO_VIEW_VECTOR_HISTORY_LAST do
    InitializeState(Root^.History[Index], AUDIO_MONITOR_LAYER_AUTO);
end;

function TAul2AudioViewVectorSharedMemory.GetRoot: PAul2AudioViewVectorRoot;
begin
  Result := PAul2AudioViewVectorRoot(View);
end;

function TAul2AudioViewVectorSharedMemory.GetStateForLayer(
  Layer: Integer): PAul2AudioViewVectorState;
begin
  if (Root = nil) or (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit(nil);
  Result := @Root^.Slots[Layer];
end;

function TAul2AudioViewVectorSharedMemory.GetHistoryState(
  Index: Integer): PAul2AudioViewVectorState;
begin
  if (Root = nil) or (Index < 0) or (Index > AUDIO_VIEW_VECTOR_HISTORY_LAST) then
    Exit(nil);
  Result := @Root^.History[Index];
end;

end.
