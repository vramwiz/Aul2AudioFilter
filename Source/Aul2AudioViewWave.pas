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
  if InternalLayer = AUDIO_MONITOR_LAYER_AUTO then
    State := WaveMemory.State
  else
    State := WaveMemory.GetStateForLayer(InternalLayer);

  if not WaveStateUsable(State) then
    State := WaveMemory.State;

  if not WaveStateUsable(State) then
    Exit;

  UpdateViewFrame(CurrentFrame);

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
