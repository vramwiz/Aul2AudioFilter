unit Aul2AudioViewWave;

// 共有メモリ履歴から描画フレームに対応する時間波形を選び、表示用に平滑化して返す。

interface

uses
  Aul2AudioMonitorShared;

type
  TAudioViewWaveHistory = array of TAudioMonitorWaveData;

// 波形共有メモリを開き、描画値を取得できる状態にする。
procedure InitializeViewWave;
// 波形共有メモリと ViewFrame 共有メモリを解放し、平滑化履歴を無効にする。
procedure FinalizeViewWave;
// 指定フレームとレイヤーに最も近い波形を取得し、平滑化した中心値と min/max 包絡線を返す。
procedure UpdateViewWave(Smooth: Integer; out Wave, WaveMin, WaveMax: TAudioMonitorWaveData;
  out Valid: Boolean; CurrentFrame, SourceLayer: Integer);
// 編集時に同期履歴がない場合、指定レイヤーの最新波形を返す。
procedure UpdateViewWaveLatestForEdit(Smooth: Integer; out Wave, WaveMin, WaveMax: TAudioMonitorWaveData;
  out Valid: Boolean; CurrentFrame, SourceLayer: Integer);
// 現在フレーム以前の同一レイヤーの時間波形を新しい順で返す。
procedure GetViewWaveHistory(CurrentFrame, SourceLayer, MaxCount: Integer;
  out History: TAudioViewWaveHistory; out Valid: Boolean);

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  Aul2AudioViewFrameShared;

var
  WaveMemory       : TAul2AudioMonitorSharedMemory;
  ViewFrameMemory  : TAul2AudioViewFrameSharedMemory;
  DisplayWave      : TAudioMonitorWaveData;
  DisplayWaveMin   : TAudioMonitorWaveData;
  DisplayWaveMax   : TAudioMonitorWaveData;
  DisplayWaveValid: Boolean;

function GetWaveEditState: Integer;
var
  State: PAul2AudioViewFrameState;
begin
  Result := 0;
  try
    if ViewFrameMemory = nil then
      ViewFrameMemory := TAul2AudioViewFrameSharedMemory.Create;
    State := ViewFrameMemory.State;
    if State <> nil then
      Result := State^.EditState;
  except
    FreeAndNil(ViewFrameMemory);
    Result := 0;
  end;
end;

procedure InitializeViewWave;
begin
  // Monitor が同じ描画時刻を選べるよう、実際に View が処理した編集全体のフレームを通知する。
  try
    if WaveMemory = nil then
      WaveMemory := TAul2AudioMonitorSharedMemory.Create;
  except
    FreeAndNil(WaveMemory);
    FreeAndNil(ViewFrameMemory);
    DisplayWaveValid := False;
  end;
end;

procedure FinalizeViewWave;
begin
  FreeAndNil(WaveMemory);
  FreeAndNil(ViewFrameMemory);
  DisplayWaveValid := False;
end;

function StateMatchesFrame(State: PAul2AudioMonitorState; CurrentFrame: Integer): Boolean;
begin
  if CurrentFrame < 0 then
    Exit(True);

  if (State^.SourceFrameS <= 0) and (State^.SourceFrameE <= 0) then
    Exit(True);

  Result := (CurrentFrame >= State^.SourceFrameS) and (CurrentFrame <= State^.SourceFrameE);
end;

function ResolveSourceLayer(SourceLayer: Integer): Integer;
begin
  // GUI は 1-based、共有メモリのレイヤースロットは 0-based で保持する。
  if SourceLayer <= 0 then
    Exit(AUDIO_MONITOR_LAYER_AUTO);

  Result := SourceLayer - 1;
  if (Result < 0) or (Result > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Result := AUDIO_MONITOR_LAYER_AUTO;
end;

function WaveStateUsable(State: PAul2AudioMonitorState): Boolean;
begin
  Result := (State <> nil) and
            (State^.Magic = AUDIO_MONITOR_SHARED_MAGIC) and
            (State^.Version = AUDIO_MONITOR_SHARED_VERSION) and
            (State^.UpdateTick <> 0);
end;

function StateDisplayFrame(State: PAul2AudioMonitorState): Integer;
begin
  Result := State^.SourceFrameS + State^.SourceFrame;
end;

function StateFrameDistance(State: PAul2AudioMonitorState; CurrentFrame: Integer): Integer;
begin
  if CurrentFrame < 0 then
    Exit(0);

  Result := Abs(StateDisplayFrame(State) - CurrentFrame);
end;

function PreferWaveState(Candidate, Current: PAul2AudioMonitorState;
  CurrentFrame: Integer): Boolean;
var
  CandidateDistance: Integer;
  CurrentDistance: Integer;
begin
  if Current = nil then
    Exit(True);

  CandidateDistance := StateFrameDistance(Candidate, CurrentFrame);
  CurrentDistance := StateFrameDistance(Current, CurrentFrame);
  // 音声先読みによる未来側の値を避けるため、更新時刻よりフレーム距離を優先する。
  if CandidateDistance <> CurrentDistance then
    Exit(CandidateDistance < CurrentDistance);

  Result := Candidate^.UpdateTick > Current^.UpdateTick;
end;

function FindWaveHistoryForLayer(Layer, CurrentFrame: Integer): PAul2AudioMonitorState;
var
  Index: Integer;
  State: PAul2AudioMonitorState;
begin
  Result := nil;

  if (WaveMemory = nil) or (WaveMemory.Root = nil) or
     (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;

  for Index := 0 to AUDIO_MONITOR_HISTORY_LAST do
  begin
    State := WaveMemory.GetHistoryStateForLayer(Layer, Index);
    if WaveStateUsable(State) and StateMatchesFrame(State, CurrentFrame) and
       PreferWaveState(State, Result, CurrentFrame) then
      Result := State;
  end;
end;

function FindBestWaveHistory(CurrentFrame: Integer): PAul2AudioMonitorState;
var
  Layer: Integer;
  State: PAul2AudioMonitorState;
begin
  Result := nil;

  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    State := FindWaveHistoryForLayer(Layer, CurrentFrame);
    if (State <> nil) and PreferWaveState(State, Result, CurrentFrame) then
      Result := State;
  end;
end;

function SelectWaveState(CurrentFrame, InternalLayer: Integer): PAul2AudioMonitorState;
begin
  // Auto は全レイヤーから最も近い履歴を選び、個別指定時は対象レイヤーだけを調べる。
  if InternalLayer = AUDIO_MONITOR_LAYER_AUTO then
  begin
    Result := FindBestWaveHistory(CurrentFrame);
    if Result = nil then
      Result := WaveMemory.State;
  end
  else
  begin
    Result := FindWaveHistoryForLayer(InternalLayer, CurrentFrame);
    if Result = nil then
      Result := WaveMemory.GetStateForLayer(InternalLayer);
  end;

  if not (WaveStateUsable(Result) and StateMatchesFrame(Result, CurrentFrame)) then
    Result := nil;
  // 近傍履歴がない場合は別時刻の波形を表示せず、呼び出し側へ無効として返す。
  if (Result <> nil) and (StateFrameDistance(Result, CurrentFrame) > 1) then
    Result := nil;
end;

procedure SmoothPoint(var DisplayValue: Single; NewValue: Single; Smooth: Integer);
var
  Alpha: Single;
  SmoothRate: Single;
begin
  NewValue := Max(-1.0, Min(1.0, NewValue));
  SmoothRate := Max(0, Min(100, Smooth)) / 100.0;
  // Smooth を上げるほど過去値の比率を増やし、フレーム間の細かな揺れを抑える。
  Alpha := 0.82 - (SmoothRate * 0.64);
  DisplayValue := DisplayValue + ((NewValue - DisplayValue) * Alpha);
end;

procedure UpdateDisplayWaveFromState(State: PAul2AudioMonitorState; Smooth: Integer);
var
  Point: Integer;
begin
  if not DisplayWaveValid then
  begin
    DisplayWave := State^.OutputWave;
    DisplayWaveMin := State^.OutputWaveMin;
    DisplayWaveMax := State^.OutputWaveMax;
    DisplayWaveValid := True;
    Exit;
  end;

  for Point := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
  begin
    SmoothPoint(DisplayWave[Point], State^.OutputWave[Point], Smooth);
    SmoothPoint(DisplayWaveMin[Point], State^.OutputWaveMin[Point], Smooth);
    SmoothPoint(DisplayWaveMax[Point], State^.OutputWaveMax[Point], Smooth);
  end;
end;

procedure UpdateViewWave(Smooth: Integer; out Wave, WaveMin, WaveMax: TAudioMonitorWaveData;
  out Valid: Boolean; CurrentFrame, SourceLayer: Integer);
var
  State: PAul2AudioMonitorState;
  InternalLayer: Integer;
begin
  FillChar(Wave, SizeOf(Wave), 0);
  FillChar(WaveMin, SizeOf(WaveMin), 0);
  FillChar(WaveMax, SizeOf(WaveMax), 0);
  Valid := False;

  if WaveMemory = nil then
    InitializeViewWave;

  if WaveMemory = nil then
    Exit;

  InternalLayer := ResolveSourceLayer(SourceLayer);
  State := SelectWaveState(CurrentFrame, InternalLayer);
  if State = nil then
    Exit;

  UpdateDisplayWaveFromState(State, Smooth);

  Wave := DisplayWave;
  WaveMin := DisplayWaveMin;
  WaveMax := DisplayWaveMax;
  Valid := True;
end;

procedure UpdateViewWaveLatestForEdit(Smooth: Integer; out Wave, WaveMin, WaveMax: TAudioMonitorWaveData;
  out Valid: Boolean; CurrentFrame, SourceLayer: Integer);
var
  State: PAul2AudioMonitorState;
  InternalLayer: Integer;
begin
  FillChar(Wave, SizeOf(Wave), 0);
  FillChar(WaveMin, SizeOf(WaveMin), 0);
  FillChar(WaveMax, SizeOf(WaveMax), 0);
  Valid := False;

  if WaveMemory = nil then
    InitializeViewWave;
  if WaveMemory = nil then
    Exit;

  InternalLayer := ResolveSourceLayer(SourceLayer);
  if InternalLayer = AUDIO_MONITOR_LAYER_AUTO then
    State := WaveMemory.State
  else
    State := WaveMemory.GetStateForLayer(InternalLayer);
  if not WaveStateUsable(State) or not StateMatchesFrame(State, CurrentFrame) then
    Exit;

  UpdateDisplayWaveFromState(State, Smooth);
  Wave := DisplayWave;
  WaveMin := DisplayWaveMin;
  WaveMax := DisplayWaveMax;
  Valid := True;
end;

procedure GetViewWaveHistory(CurrentFrame, SourceLayer, MaxCount: Integer;
  out History: TAudioViewWaveHistory; out Valid: Boolean);
type
  THistoryEntry = record
    Frame: Integer;
    UpdateTick: UInt64;
    Wave: TAudioMonitorWaveData;
  end;
var
  Entries: array of THistoryEntry;
  State: PAul2AudioMonitorState;
  Selected: PAul2AudioMonitorState;
  InternalLayer: Integer;
  Index: Integer;
  EntryIndex: Integer;
  SortIndex: Integer;
  Count: Integer;
  Temp: THistoryEntry;
begin
  SetLength(History, 0);
  Valid := False;
  MaxCount := Max(1, Min(AUDIO_MONITOR_HISTORY_COUNT, MaxCount));

  if WaveMemory = nil then
    InitializeViewWave;
  if (WaveMemory = nil) or (WaveMemory.Root = nil) then
    Exit;

  InternalLayer := ResolveSourceLayer(SourceLayer);
  if InternalLayer = AUDIO_MONITOR_LAYER_AUTO then
  begin
    Selected := SelectWaveState(CurrentFrame, InternalLayer);
    if (Selected = nil) and (GetWaveEditState = 0) then
      Selected := WaveMemory.State;
    if not WaveStateUsable(Selected) then
      Exit;
    InternalLayer := Selected^.SourceLayer;
  end;
  if (InternalLayer < 0) or (InternalLayer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;

  SetLength(Entries, AUDIO_MONITOR_HISTORY_COUNT);
  Count := 0;
  for Index := 0 to AUDIO_MONITOR_HISTORY_LAST do
  begin
    State := WaveMemory.GetHistoryStateForLayer(InternalLayer, Index);
    if not WaveStateUsable(State) or not StateMatchesFrame(State, CurrentFrame) then
      Continue;
    if (CurrentFrame >= 0) and (StateDisplayFrame(State) > CurrentFrame) then
      Continue;

    EntryIndex := -1;
    for SortIndex := 0 to Count - 1 do
      if Entries[SortIndex].Frame = StateDisplayFrame(State) then
      begin
        EntryIndex := SortIndex;
        Break;
      end;
    if (EntryIndex >= 0) and (Entries[EntryIndex].UpdateTick >= State^.UpdateTick) then
      Continue;
    if EntryIndex < 0 then
    begin
      EntryIndex := Count;
      Inc(Count);
    end;
    Entries[EntryIndex].Frame := StateDisplayFrame(State);
    Entries[EntryIndex].UpdateTick := State^.UpdateTick;
    Entries[EntryIndex].Wave := State^.OutputWave;
  end;

  // 編集停止中に同期履歴が取れない場合は、指定レイヤーの最新値を最低1列として使う。
  if (Count = 0) and (GetWaveEditState = 0) then
  begin
    State := WaveMemory.GetStateForLayer(InternalLayer);
    if WaveStateUsable(State) and StateMatchesFrame(State, CurrentFrame) then
    begin
      Entries[0].Frame := StateDisplayFrame(State);
      Entries[0].UpdateTick := State^.UpdateTick;
      Entries[0].Wave := State^.OutputWave;
      Count := 1;
    end;
  end;

  // 現在に近い断面を手前へ置けるよう、絶対フレームの降順へ整列する。
  for Index := 0 to Count - 2 do
    for SortIndex := Index + 1 to Count - 1 do
      if Entries[SortIndex].Frame > Entries[Index].Frame then
      begin
        Temp := Entries[Index];
        Entries[Index] := Entries[SortIndex];
        Entries[SortIndex] := Temp;
      end;

  Count := Min(Count, MaxCount);
  if Count <= 0 then
    Exit;
  SetLength(History, Count);
  for Index := 0 to Count - 1 do
    History[Index] := Entries[Index].Wave;
  Valid := True;
end;

end.
