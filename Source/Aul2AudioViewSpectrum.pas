unit Aul2AudioViewSpectrum;

// Reads and smooths spectrum values for Aul2AudioView render units.

interface

uses
  Aul2AudioMonitorSpectrumShared;

procedure InitializeViewSpectrum;
procedure FinalizeViewSpectrum;
procedure UpdateViewSpectrum(Smooth: Integer; out Bands: TAudioMonitorSpectrumData;
  out Valid: Boolean; out SourceMinHz, SourceMaxHz: Single; CurrentFrame: Integer);

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  Aul2AudioViewFrameShared;

var
  SpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;
  ViewFrameMemory: TAul2AudioViewFrameSharedMemory;
  DisplayBands: TAudioMonitorSpectrumData;
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

procedure SmoothBand(var DisplayValue: Single; NewValue: Single; Smooth: Integer);
var
  Alpha: Single;
  SmoothRate: Single;
begin
  NewValue := Max(0.0, Min(1.0, NewValue));
  SmoothRate := Max(0, Min(100, Smooth)) / 100.0;
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

procedure UpdateViewSpectrum(Smooth: Integer; out Bands: TAudioMonitorSpectrumData;
  out Valid: Boolean; out SourceMinHz, SourceMaxHz: Single; CurrentFrame: Integer);
var
  State: PAul2AudioMonitorSpectrumState;
  Band: Integer;
begin
  FillChar(Bands, SizeOf(Bands), 0);
  Valid := False;
  SourceMinHz := 20.0;
  SourceMaxHz := 20000.0;

  if SpectrumMemory = nil then
    InitializeViewSpectrum;

  if SpectrumMemory = nil then
    Exit;

  State := SpectrumMemory.State;
  if (State = nil) or
     (State^.Magic <> AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) or
     (State^.Version <> AUDIO_MONITOR_SPECTRUM_SHARED_VERSION) then
    Exit;

  UpdateViewFrame(CurrentFrame);

  if not StateMatchesFrame(State, CurrentFrame) then
  begin
    DisplayBandsValid := False;
    Exit;
  end;

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
