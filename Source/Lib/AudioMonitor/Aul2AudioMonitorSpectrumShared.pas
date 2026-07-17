unit Aul2AudioMonitorSpectrumShared;

// Aul2AudioMonitor のスペクトラム表示専用共有メモリ構造体。

interface

uses
  Aul2AudioMonitorShared,
  SharedMemoryBase;

const
  AUDIO_MONITOR_SPECTRUM_SHARED_NAME    = 'Local\Aul2AudioMonitorSpectrumV7';
  AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC   = $41535043; // ASPC
  AUDIO_MONITOR_SPECTRUM_SHARED_VERSION = 7;
  AUDIO_MONITOR_SPECTRUM_BAND_COUNT     = 64;
  AUDIO_MONITOR_SPECTRUM_BAND_LAST      = AUDIO_MONITOR_SPECTRUM_BAND_COUNT - 1;
  AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT  = 128;
  AUDIO_MONITOR_SPECTRUM_HISTORY_LAST   = AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT - 1;

type
  TAudioMonitorSpectrumData = array[0..AUDIO_MONITOR_SPECTRUM_BAND_LAST] of Single;

  // 1レイヤー、1解析時点の周波数バンドと音声位置を保持する共有状態。
  PAul2AudioMonitorSpectrumState = ^TAul2AudioMonitorSpectrumState;
  TAul2AudioMonitorSpectrumState = record
    Magic       : Cardinal;                  // AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC。
    Version     : Cardinal;                  // AUDIO_MONITOR_SPECTRUM_SHARED_VERSION。
    Generation  : Int64;                     // 書き込み世代を識別する単調増加値。
    UpdateTick  : UInt64;                    // 更新の鮮度を判定する GetTickCount64 値。
    RequestId   : TGUID;                     // Controller要求との対応を識別するGUID。
    SampleRate  : Integer;                   // 元音声のサンプリング周波数。
    SampleNum   : Integer;                   // 今回解析した1チャンネル当たりのサンプル数。
    ChannelNum  : Integer;                   // 元音声のチャンネル数。
    SourceFrame : Integer;                   // 音声オブジェクト内の相対フレーム。
    SourceFrameS: Integer;                   // 音声オブジェクトの開始フレーム。
    SourceFrameE: Integer;                   // 音声オブジェクトの終了フレーム。
    SourceLayer : Integer;                   // 解析元の内部0-basedレイヤー。
    SourceIndex : Integer;                   // 音声処理コールバック内のブロック位置。
    SampleIndex : Int64;                     // 音声オブジェクト内の先頭サンプル位置。
    BandCount   : Integer;                   // InputBands / OutputBands の有効バンド数。
    MinHz       : Single;                    // 最初のバンドが表す周波数。
    MaxHz       : Single;                    // 最後のバンドが表す周波数。
    InputBands  : TAudioMonitorSpectrumData; // 処理前の正規化スペクトラム。
    OutputBands : TAudioMonitorSpectrumData; // 処理後の正規化スペクトラム。
  end;

  // 最新スペクトラムとフレーム同期用履歴をレイヤーごとに保持するルート。
  PAul2AudioMonitorLayeredSpectrumState = ^TAul2AudioMonitorLayeredSpectrumState;
  TAul2AudioMonitorLayeredSpectrumState = record
    Magic       : Cardinal; // AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC。
    Version     : Cardinal; // AUDIO_MONITOR_SPECTRUM_SHARED_VERSION。
    Generation  : Int64;    // ルート全体の初期化世代。
    LastLayer   : Integer;  // 最後に更新された内部レイヤー。
    HistoryIndex: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of Integer; // 次に書く履歴位置。
    Slots       : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioMonitorSpectrumState; // 最新値。
    History     : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST,
      0..AUDIO_MONITOR_SPECTRUM_HISTORY_LAST] of TAul2AudioMonitorSpectrumState; // 同期用リング。
  end;

  TAul2AudioMonitorSpectrumSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioMonitorLayeredSpectrumState;
    function GetState: PAul2AudioMonitorSpectrumState;
  public
    // スペクトラム用マップを開き、初回作成または版不一致時にルートを初期化する。
    constructor Create; reintroduce;
    // 指定した内部0-basedレイヤーの最新状態を返し、範囲外なら nil を返す。
    function GetStateForLayer(Layer: Integer): PAul2AudioMonitorSpectrumState;
    // 指定レイヤーとリング添字の履歴状態を返し、範囲外なら nil を返す。
    function GetHistoryStateForLayer(Layer, Index: Integer): PAul2AudioMonitorSpectrumState;
    property Root: PAul2AudioMonitorLayeredSpectrumState read GetRoot; // 共有メモリのルート。
    property State: PAul2AudioMonitorSpectrumState read GetState;      // 最終更新レイヤーの最新値。
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
