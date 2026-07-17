unit Aul2AudioViewSpectrum;

// 共有メモリ履歴から描画フレームに対応するスペクトラムを選び、表示用に平滑化して返す。

interface

uses
  Aul2AudioMonitorSpectrumShared;

type
  TAudioViewSpectrumHistory = array of TAudioMonitorSpectrumData;

// スペクトラム共有メモリを開き、描画値を取得できる状態にする。
procedure InitializeViewSpectrum;
// スペクトラム共有メモリと ViewFrame 共有メモリを解放し、平滑化履歴を無効にする。
procedure FinalizeViewSpectrum;
// 指定フレームとレイヤーに最も近いスペクトラムを取得し、平滑化した表示値と周波数範囲を返す。
procedure UpdateViewSpectrum(Smooth: Integer; out Bands: TAudioMonitorSpectrumData;
  out Valid: Boolean; out SourceMinHz, SourceMaxHz: Single;
  CurrentFrame, SourceLayer: Integer);
// 編集時に同期履歴がない場合、指定レイヤーの最新スペクトラムを返す。
procedure UpdateViewSpectrumLatestForEdit(Smooth: Integer; out Bands: TAudioMonitorSpectrumData;
  out Valid: Boolean; out SourceMinHz, SourceMaxHz: Single; SourceLayer: Integer);
// Monitorが通知した編集状態を返す。0=Edit、1=Play、2=Encode。
function GetViewEditState: Integer;
// 現在フレーム以前の同一レイヤーのスペクトラムを新しい順で返す。
procedure GetViewSpectrumHistory(CurrentFrame, SourceLayer, MaxCount: Integer;
  out History: TAudioViewSpectrumHistory; out Valid: Boolean;
  out SourceMinHz, SourceMaxHz: Single);

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  Aul2AudioMonitorShared,
  Aul2AudioViewFrameShared;

var
  SpectrumMemory  : TAul2AudioMonitorSpectrumSharedMemory;
  ViewFrameMemory : TAul2AudioViewFrameSharedMemory;
  DisplayBands    : TAudioMonitorSpectrumData;
  DisplayBandsValid: Boolean;

procedure InitializeViewSpectrum;
begin
  try
    if SpectrumMemory = nil then
      SpectrumMemory := TAul2AudioMonitorSpectrumSharedMemory.Create;
  except
    FreeAndNil(SpectrumMemory);
    FreeAndNil(ViewFrameMemory);
    DisplayBandsValid := False;
  end;
end;

procedure FinalizeViewSpectrum;
begin
  FreeAndNil(SpectrumMemory);
  FreeAndNil(ViewFrameMemory);
  DisplayBandsValid := False;
end;

function GetViewEditState: Integer;
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

procedure SmoothBand(var DisplayValue: Single; NewValue: Single; Smooth: Integer);
var
  Alpha: Single;
  SmoothRate: Single;
begin
  NewValue := Max(0.0, Min(1.0, NewValue));
  SmoothRate := Max(0, Min(100, Smooth)) / 100.0;
  // 立ち上がりを速く、減衰を遅くして、音への反応と表示の安定性を両立する。
  if NewValue > DisplayValue then
    Alpha := 0.85 - (SmoothRate * 0.65)
  else
    Alpha := 0.45 - (SmoothRate * 0.35);

  DisplayValue := DisplayValue + ((NewValue - DisplayValue) * Alpha);
end;

function StateMatchesFrame(State: PAul2AudioMonitorSpectrumState; CurrentFrame: Integer): Boolean;
begin
  if CurrentFrame < 0 then
  begin
    Result := True;
    Exit;
  end;

  if (State^.SourceFrameS <= 0) and (State^.SourceFrameE <= 0) then
  begin
    Result := True;
    Exit;
  end;

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

function SpectrumStateUsable(State: PAul2AudioMonitorSpectrumState): Boolean;
begin
  Result := (State <> nil) and
            (State^.Magic = AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) and
            (State^.Version = AUDIO_MONITOR_SPECTRUM_SHARED_VERSION) and
            (State^.UpdateTick <> 0);
end;

function StateDisplayFrame(State: PAul2AudioMonitorSpectrumState): Integer;
begin
  Result := State^.SourceFrameS + State^.SourceFrame;
end;

function StateFrameDistance(State: PAul2AudioMonitorSpectrumState; CurrentFrame: Integer): Integer;
begin
  if CurrentFrame < 0 then
    Exit(0);

  Result := Abs(StateDisplayFrame(State) - CurrentFrame);
end;

function PreferSpectrumState(Candidate, Current: PAul2AudioMonitorSpectrumState;
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

function FindSpectrumHistoryForLayer(Layer, CurrentFrame: Integer): PAul2AudioMonitorSpectrumState;
var
  Index: Integer;
  State: PAul2AudioMonitorSpectrumState;
begin
  Result := nil;

  if (SpectrumMemory = nil) or (SpectrumMemory.Root = nil) or
     (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;

  for Index := 0 to AUDIO_MONITOR_SPECTRUM_HISTORY_LAST do
  begin
    State := SpectrumMemory.GetHistoryStateForLayer(Layer, Index);
    if SpectrumStateUsable(State) and StateMatchesFrame(State, CurrentFrame) and
       PreferSpectrumState(State, Result, CurrentFrame) then
      Result := State;
  end;
end;

function FindBestSpectrumHistory(CurrentFrame: Integer): PAul2AudioMonitorSpectrumState;
var
  Layer: Integer;
  State: PAul2AudioMonitorSpectrumState;
begin
  Result := nil;

  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    State := FindSpectrumHistoryForLayer(Layer, CurrentFrame);
    if (State <> nil) and PreferSpectrumState(State, Result, CurrentFrame) then
      Result := State;
  end;
end;

function SelectSpectrumState(CurrentFrame, InternalLayer: Integer): PAul2AudioMonitorSpectrumState;
begin
  // Auto は全レイヤーから最も近い履歴を選び、個別指定時は対象レイヤーだけを調べる。
  if InternalLayer = AUDIO_MONITOR_LAYER_AUTO then
  begin
    Result := FindBestSpectrumHistory(CurrentFrame);
    if Result = nil then
      Result := SpectrumMemory.State;
  end
  else
  begin
    Result := FindSpectrumHistoryForLayer(InternalLayer, CurrentFrame);
    if Result = nil then
      Result := SpectrumMemory.GetStateForLayer(InternalLayer);
  end;

  if not (SpectrumStateUsable(Result) and StateMatchesFrame(Result, CurrentFrame)) then
    Result := nil;
  // 近傍履歴がない場合は別時刻のスペクトラムを表示せず、呼び出し側へ無効として返す。
  if (Result <> nil) and (StateFrameDistance(Result, CurrentFrame) > 1) then
    Result := nil;
end;

procedure UpdateViewSpectrum(Smooth: Integer; out Bands: TAudioMonitorSpectrumData;
  out Valid: Boolean; out SourceMinHz, SourceMaxHz: Single;
  CurrentFrame, SourceLayer: Integer);
var
  State: PAul2AudioMonitorSpectrumState;
  Band: Integer;
  InternalLayer: Integer;
begin
  FillChar(Bands, SizeOf(Bands), 0);
  Valid := False;
  SourceMinHz := 20.0;
  SourceMaxHz := 20000.0;

  if SpectrumMemory = nil then
    InitializeViewSpectrum;

  if SpectrumMemory = nil then
    Exit;

  InternalLayer := ResolveSourceLayer(SourceLayer);
  State := SelectSpectrumState(CurrentFrame, InternalLayer);
  if State = nil then
    Exit;

  SourceMinHz := Max(1.0, State^.MinHz);
  SourceMaxHz := Max(SourceMinHz + 1.0, State^.MaxHz);

  if not DisplayBandsValid then
  begin
    DisplayBands := State^.OutputBands;
    DisplayBandsValid := True;
  end
  else
    for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
      SmoothBand(DisplayBands[Band], State^.OutputBands[Band], Smooth);

  Bands := DisplayBands;
  Valid := True;
end;

procedure GetViewSpectrumHistory(CurrentFrame, SourceLayer, MaxCount: Integer;
  out History: TAudioViewSpectrumHistory; out Valid: Boolean;
  out SourceMinHz, SourceMaxHz: Single);
type
  THistoryEntry = record
    Frame: Integer;
    UpdateTick: UInt64;
    Bands: TAudioMonitorSpectrumData;
    MinHz: Single;
    MaxHz: Single;
  end;
var
  Entries: array of THistoryEntry;
  State: PAul2AudioMonitorSpectrumState;
  Selected: PAul2AudioMonitorSpectrumState;
  InternalLayer: Integer;
  Index: Integer;
  EntryIndex: Integer;
  SortIndex: Integer;
  Count: Integer;
  Temp: THistoryEntry;
begin
  SetLength(History, 0);
  Valid := False;
  SourceMinHz := 20.0;
  SourceMaxHz := 20000.0;
  MaxCount := Max(1, Min(AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT, MaxCount));

  if SpectrumMemory = nil then
    InitializeViewSpectrum;
  if (SpectrumMemory = nil) or (SpectrumMemory.Root = nil) then
    Exit;

  InternalLayer := ResolveSourceLayer(SourceLayer);
  if InternalLayer = AUDIO_MONITOR_LAYER_AUTO then
  begin
    Selected := SelectSpectrumState(CurrentFrame, InternalLayer);
    if (Selected = nil) and (GetViewEditState = 0) then
      Selected := SpectrumMemory.State;
    if not SpectrumStateUsable(Selected) then
      Exit;
    InternalLayer := Selected^.SourceLayer;
  end;
  if (InternalLayer < 0) or (InternalLayer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;

  SetLength(Entries, AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT);
  Count := 0;
  for Index := 0 to AUDIO_MONITOR_SPECTRUM_HISTORY_LAST do
  begin
    State := SpectrumMemory.GetHistoryStateForLayer(InternalLayer, Index);
    if not SpectrumStateUsable(State) or not StateMatchesFrame(State, CurrentFrame) then
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
    Entries[EntryIndex].Bands := State^.OutputBands;
    Entries[EntryIndex].MinHz := State^.MinHz;
    Entries[EntryIndex].MaxHz := State^.MaxHz;
  end;

  // 編集停止中に同期履歴が取れない場合は、指定レイヤーの最新値を最低1列として使う。
  if (Count = 0) and (GetViewEditState = 0) then
  begin
    State := SpectrumMemory.GetStateForLayer(InternalLayer);
    if SpectrumStateUsable(State) then
    begin
      Entries[0].Frame := StateDisplayFrame(State);
      Entries[0].UpdateTick := State^.UpdateTick;
      Entries[0].Bands := State^.OutputBands;
      Entries[0].MinHz := State^.MinHz;
      Entries[0].MaxHz := State^.MaxHz;
      Count := 1;
    end;
  end;

  // 現在に近い履歴から奥へ並べられるよう、絶対フレームの降順へ整列する。
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
    History[Index] := Entries[Index].Bands;
  SourceMinHz := Max(1.0, Entries[0].MinHz);
  SourceMaxHz := Max(SourceMinHz + 1.0, Entries[0].MaxHz);
  Valid := True;
end;

procedure UpdateViewSpectrumLatestForEdit(Smooth: Integer; out Bands: TAudioMonitorSpectrumData;
  out Valid: Boolean; out SourceMinHz, SourceMaxHz: Single; SourceLayer: Integer);
var
  State: PAul2AudioMonitorSpectrumState;
  Band: Integer;
  InternalLayer: Integer;
begin
  FillChar(Bands, SizeOf(Bands), 0);
  Valid := False;
  SourceMinHz := 20.0;
  SourceMaxHz := 20000.0;

  if SpectrumMemory = nil then
    InitializeViewSpectrum;
  if SpectrumMemory = nil then
    Exit;

  InternalLayer := ResolveSourceLayer(SourceLayer);
  if InternalLayer = AUDIO_MONITOR_LAYER_AUTO then
    State := SpectrumMemory.State
  else
    State := SpectrumMemory.GetStateForLayer(InternalLayer);
  if not SpectrumStateUsable(State) then
    Exit;

  SourceMinHz := Max(1.0, State^.MinHz);
  SourceMaxHz := Max(SourceMinHz + 1.0, State^.MaxHz);
  if not DisplayBandsValid then
  begin
    DisplayBands := State^.OutputBands;
    DisplayBandsValid := True;
  end
  else
    for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
      SmoothBand(DisplayBands[Band], State^.OutputBands[Band], Smooth);

  Bands := DisplayBands;
  Valid := True;
end;

end.
