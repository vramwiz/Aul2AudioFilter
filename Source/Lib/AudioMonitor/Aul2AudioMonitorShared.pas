unit Aul2AudioMonitorShared;

// Aul2AudioFilter と Aul2AudioMonitor の共有メモリ疎通データを扱う。

interface

uses
  System.SysUtils,
  SharedMemoryBase;

const
  AUDIO_MONITOR_SHARED_NAME      = 'Local\Aul2AudioMonitorState'; // 波形状態の名前付きマップ。
  AUDIO_MONITOR_SHARED_MAGIC     = $414D4F4E;                      // 構造判定用の識別値 AMON。
  AUDIO_MONITOR_SHARED_VERSION   = 8;                              // レコード配置を変更したら更新する。
  AUDIO_MONITOR_LAYER_SLOT_COUNT = 64;                             // 保持する内部レイヤー数。
  AUDIO_MONITOR_LAYER_SLOT_LAST  = AUDIO_MONITOR_LAYER_SLOT_COUNT - 1; // 最後の有効レイヤー。
  AUDIO_MONITOR_LAYER_AUTO       = -1;                             // 全レイヤーから自動選択する指定値。
  AUDIO_MONITOR_HISTORY_COUNT    = 128;                            // レイヤーごとの履歴件数。
  AUDIO_MONITOR_HISTORY_LAST     = AUDIO_MONITOR_HISTORY_COUNT - 1; // 履歴の最後の添字。
  AUDIO_MONITOR_WAVE_POINT_COUNT = 256;                            // 表示用波形の点数。
  AUDIO_MONITOR_WAVE_POINT_LAST  = AUDIO_MONITOR_WAVE_POINT_COUNT - 1; // 波形の最後の添字。

type
  TAudioMonitorWaveData = array[0..AUDIO_MONITOR_WAVE_POINT_LAST] of Single;

  // 1レイヤー、1解析時点の波形、レベル、音声位置を保持する共有状態。
  PAul2AudioMonitorState = ^TAul2AudioMonitorState;
  TAul2AudioMonitorState = record
    Magic        : Cardinal;              // AUDIO_MONITOR_SHARED_MAGIC。
    Version      : Cardinal;              // AUDIO_MONITOR_SHARED_VERSION。
    Generation   : Int64;                 // 書き込み世代を識別する単調増加値。
    UpdateTick   : UInt64;                // 更新の鮮度を判定する GetTickCount64 値。
    Stage        : Integer;               // 入力取得中など解析処理の進行状態。
    SampleRate   : Integer;               // 元音声のサンプリング周波数。
    SampleNum    : Integer;               // 今回処理した1チャンネル当たりのサンプル数。
    ChannelNum   : Integer;               // 元音声のチャンネル数。
    SourceFrame  : Integer;               // 音声オブジェクト内の相対フレーム。
    SourceFrameS : Integer;               // 音声オブジェクトの開始フレーム。
    SourceFrameE : Integer;               // 音声オブジェクトの終了フレーム。
    SourceLayer  : Integer;               // 解析元の内部0-basedレイヤー。
    SourceIndex  : Integer;               // 音声処理コールバック内のブロック位置。
    SampleIndex  : Int64;                 // 音声オブジェクト内の先頭サンプル位置。
    InputPeakL   : Single;                // 処理前の左チャンネルピーク。
    InputPeakR   : Single;                // 処理前の右チャンネルピーク。
    OutputPeakL  : Single;                // 処理後の左チャンネルピーク。
    OutputPeakR  : Single;                // 処理後の右チャンネルピーク。
    InputRmsL    : Single;                // 処理前の左チャンネルRMS。
    InputRmsR    : Single;                // 処理前の右チャンネルRMS。
    OutputRmsL   : Single;                // 処理後の左チャンネルRMS。
    OutputRmsR   : Single;                // 処理後の右チャンネルRMS。
    InputWave    : TAudioMonitorWaveData; // 処理前の表示用代表波形。
    OutputWave   : TAudioMonitorWaveData; // 処理後の表示用代表波形。
    InputWaveMin : TAudioMonitorWaveData; // 処理前波形の区間最小値。
    InputWaveMax : TAudioMonitorWaveData; // 処理前波形の区間最大値。
    OutputWaveMin: TAudioMonitorWaveData; // 処理後波形の区間最小値。
    OutputWaveMax: TAudioMonitorWaveData; // 処理後波形の区間最大値。
  end;

  // 最新値とフレーム同期用履歴をレイヤーごとに保持する共有メモリのルート。
  PAul2AudioMonitorLayeredState = ^TAul2AudioMonitorLayeredState;
  TAul2AudioMonitorLayeredState = record
    Magic       : Cardinal; // AUDIO_MONITOR_SHARED_MAGIC。
    Version     : Cardinal; // AUDIO_MONITOR_SHARED_VERSION。
    Generation  : Int64;    // ルート全体の初期化世代。
    LastLayer   : Integer;  // 最後に更新された内部レイヤー。
    HistoryIndex: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of Integer; // 次に書く履歴位置。
    Slots       : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAul2AudioMonitorState; // 最新値。
    History     : array[0..AUDIO_MONITOR_LAYER_SLOT_LAST,
      0..AUDIO_MONITOR_HISTORY_LAST] of TAul2AudioMonitorState; // フレーム同期用リング。
  end;

  // 波形状態のルート、最新値、履歴を型安全に参照する共有メモリラッパー。
  TAul2AudioMonitorSharedMemory = class(TSharedMemoryBase)
  private
    function GetRoot: PAul2AudioMonitorLayeredState;
    function GetState: PAul2AudioMonitorState;
  public
    // 波形状態用マップを開き、初回作成または版不一致時にルートを初期化する。
    constructor Create; reintroduce;
    // 指定した内部0-basedレイヤーの最新状態を返し、範囲外なら nil を返す。
    function GetStateForLayer(Layer: Integer): PAul2AudioMonitorState;
    // 指定レイヤーとリング添字の履歴状態を返し、範囲外なら nil を返す。
    function GetHistoryStateForLayer(Layer, Index: Integer): PAul2AudioMonitorState;
    property Root: PAul2AudioMonitorLayeredState read GetRoot; // 共有メモリのルート。
    property State: PAul2AudioMonitorState read GetState;      // 最終更新レイヤーの最新状態。
  end;

implementation

constructor TAul2AudioMonitorSharedMemory.Create;
var
  Layer: Integer;
  Index: Integer;
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
      if (Root^.HistoryIndex[Layer] < 0) or
         (Root^.HistoryIndex[Layer] > AUDIO_MONITOR_HISTORY_LAST) then
        Root^.HistoryIndex[Layer] := 0;
      for Index := 0 to AUDIO_MONITOR_HISTORY_LAST do
      begin
        Root^.History[Layer, Index].Magic := AUDIO_MONITOR_SHARED_MAGIC;
        Root^.History[Layer, Index].Version := AUDIO_MONITOR_SHARED_VERSION;
        Root^.History[Layer, Index].SourceLayer := Layer;
      end;
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

function TAul2AudioMonitorSharedMemory.GetHistoryStateForLayer(
  Layer, Index: Integer): PAul2AudioMonitorState;
begin
  if (Root = nil) or
     (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) or
     (Index < 0) or (Index > AUDIO_MONITOR_HISTORY_LAST) then
    Exit(nil);

  Result := @Root^.History[Layer, Index];
end;

end.
