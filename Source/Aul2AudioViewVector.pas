unit Aul2AudioViewVector;

// Vectorscope用共有履歴から現在フレームに対応するOutput L/R代表点を選択する。

interface

uses
  Aul2AudioViewVectorShared;

// Vectorscope用共有メモリを開く。
procedure InitializeViewVector;
// Vectorscope用共有メモリを解放する。
procedure FinalizeViewVector;
// 現在フレームとレイヤーに最も近いOutput L/R代表点を返す。
procedure UpdateViewVector(out Left, Right: TAudioViewVectorData;
  out Valid: Boolean; CurrentFrame, SourceLayer: Integer);

implementation

uses
  System.Math,
  System.SysUtils,
  Aul2AudioMonitorShared;

var
  VectorMemory: TAul2AudioViewVectorSharedMemory;

procedure InitializeViewVector;
begin
  try
    VectorMemory := TAul2AudioViewVectorSharedMemory.Create;
  except
    FreeAndNil(VectorMemory);
  end;
end;

procedure FinalizeViewVector;
begin
  FreeAndNil(VectorMemory);
end;

function ResolveSourceLayer(SourceLayer: Integer): Integer;
begin
  if SourceLayer <= 0 then
    Exit(AUDIO_MONITOR_LAYER_AUTO);
  Result := SourceLayer - 1;
  if (Result < 0) or (Result > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Result := AUDIO_MONITOR_LAYER_AUTO;
end;

function StateUsable(State: PAul2AudioViewVectorState): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_VIEW_VECTOR_SHARED_MAGIC) and
    (State^.Version = AUDIO_VIEW_VECTOR_SHARED_VERSION) and
    (State^.UpdateTick <> 0) and
    (State^.PointCount > 0);
end;

function StateDisplayFrame(State: PAul2AudioViewVectorState): Integer;
begin
  Result := State^.SourceFrameS + State^.SourceFrame;
end;

function StateMatchesFrame(State: PAul2AudioViewVectorState; CurrentFrame: Integer): Boolean;
begin
  if CurrentFrame < 0 then
    Exit(True);
  if (State^.SourceFrameS <= 0) and (State^.SourceFrameE <= 0) then
    Exit(True);
  Result := (CurrentFrame >= State^.SourceFrameS) and
    (CurrentFrame <= State^.SourceFrameE);
end;

function PreferState(Candidate, Current: PAul2AudioViewVectorState;
  CurrentFrame: Integer): Boolean;
var
  CandidateDistance: Integer;
  CurrentDistance: Integer;
begin
  if Current = nil then
    Exit(True);

  CandidateDistance := Abs(StateDisplayFrame(Candidate) - CurrentFrame);
  CurrentDistance := Abs(StateDisplayFrame(Current) - CurrentFrame);
  if CandidateDistance <> CurrentDistance then
    Exit(CandidateDistance < CurrentDistance);
  Result := Candidate^.UpdateTick > Current^.UpdateTick;
end;

function SelectVectorState(CurrentFrame, InternalLayer: Integer): PAul2AudioViewVectorState;
var
  Index: Integer;
  State: PAul2AudioViewVectorState;
begin
  Result := nil;
  if VectorMemory = nil then
    Exit;

  for Index := 0 to AUDIO_VIEW_VECTOR_HISTORY_LAST do
  begin
    State := VectorMemory.GetHistoryState(Index);
    if not StateUsable(State) or not StateMatchesFrame(State, CurrentFrame) then
      Continue;
    if (InternalLayer <> AUDIO_MONITOR_LAYER_AUTO) and
       (State^.SourceLayer <> InternalLayer) then
      Continue;
    if PreferState(State, Result, CurrentFrame) then
      Result := State;
  end;

  if Result = nil then
  begin
    if InternalLayer = AUDIO_MONITOR_LAYER_AUTO then
    begin
      for Index := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
      begin
        State := VectorMemory.GetStateForLayer(Index);
        if StateUsable(State) and StateMatchesFrame(State, CurrentFrame) and
           PreferState(State, Result, CurrentFrame) then
          Result := State;
      end;
    end
    else
      Result := VectorMemory.GetStateForLayer(InternalLayer);
  end;

  if not StateUsable(Result) or not StateMatchesFrame(Result, CurrentFrame) then
    Exit(nil);
  if (CurrentFrame >= 0) and
     (Abs(StateDisplayFrame(Result) - CurrentFrame) > 1) then
    Result := nil;
end;

procedure UpdateViewVector(out Left, Right: TAudioViewVectorData;
  out Valid: Boolean; CurrentFrame, SourceLayer: Integer);
var
  State: PAul2AudioViewVectorState;
begin
  FillChar(Left, SizeOf(Left), 0);
  FillChar(Right, SizeOf(Right), 0);
  Valid := False;
  if VectorMemory = nil then
    Exit;

  State := SelectVectorState(CurrentFrame, ResolveSourceLayer(SourceLayer));
  if State = nil then
    Exit;

  Left := State^.OutputLeft;
  Right := State^.OutputRight;
  Valid := True;
end;

end.
