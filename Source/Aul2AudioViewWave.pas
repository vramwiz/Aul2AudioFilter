unit Aul2AudioViewWave;

// Reads and smooths waveform values for Aul2AudioView render units.

interface

uses
  Aul2AudioMonitorShared;

procedure InitializeViewWave;
procedure FinalizeViewWave;
procedure UpdateViewWave(Smooth: Integer; out Wave, WaveMin, WaveMax: TAudioMonitorWaveData;
  out Valid: Boolean; CurrentFrame, SourceLayer: Integer);

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  Aul2AudioViewFrameShared;

var
  WaveMemory: TAul2AudioMonitorSharedMemory;
  ViewFrameMemory: TAul2AudioViewFrameSharedMemory;
  DisplayWave: TAudioMonitorWaveData;
  DisplayWaveMin: TAudioMonitorWaveData;
  DisplayWaveMax: TAudioMonitorWaveData;
  DisplayWaveValid: Boolean;

procedure InitializeViewWave;
begin
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

procedure UpdateViewFrame(CurrentFrame: Integer);
var
  State: PAul2AudioViewFrameState;
begin
  try
    if ViewFrameMemory = nil then
      ViewFrameMemory := TAul2AudioViewFrameSharedMemory.Create;

    State := ViewFrameMemory.State;
    if State = nil then
      Exit;

    State^.Magic := AUDIO_VIEW_FRAME_SHARED_MAGIC;
    State^.Version := AUDIO_VIEW_FRAME_SHARED_VERSION;
    State^.UpdateTick := GetTickCount64;
    State^.Frame := CurrentFrame;
  except
    FreeAndNil(ViewFrameMemory);
  end;
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
  Alpha := 0.82 - (SmoothRate * 0.64);
  DisplayValue := DisplayValue + ((NewValue - DisplayValue) * Alpha);
end;

procedure UpdateViewWave(Smooth: Integer; out Wave, WaveMin, WaveMax: TAudioMonitorWaveData;
  out Valid: Boolean; CurrentFrame, SourceLayer: Integer);
var
  State: PAul2AudioMonitorState;
  Point: Integer;
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
  UpdateViewFrame(CurrentFrame);

  State := SelectWaveState(CurrentFrame, InternalLayer);
  if State = nil then
    Exit;

  if not DisplayWaveValid then
  begin
    DisplayWave := State^.OutputWave;
    DisplayWaveMin := State^.OutputWaveMin;
    DisplayWaveMax := State^.OutputWaveMax;
    DisplayWaveValid := True;
  end
  else
    for Point := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
    begin
      SmoothPoint(DisplayWave[Point], State^.OutputWave[Point], Smooth);
      SmoothPoint(DisplayWaveMin[Point], State^.OutputWaveMin[Point], Smooth);
      SmoothPoint(DisplayWaveMax[Point], State^.OutputWaveMax[Point], Smooth);
    end;

  Wave := DisplayWave;
  WaveMin := DisplayWaveMin;
  WaveMax := DisplayWaveMax;
  Valid := True;
end;

end.
