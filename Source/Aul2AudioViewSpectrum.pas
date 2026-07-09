unit Aul2AudioViewSpectrum;

// Reads and smooths spectrum values for Aul2AudioView render units.

interface

uses
  Aul2AudioMonitorSpectrumShared;

procedure InitializeViewSpectrum;
procedure FinalizeViewSpectrum;
procedure UpdateViewSpectrum(Smooth: Integer; out Bands: TAudioMonitorSpectrumData;
  out Valid: Boolean; CurrentFrame: Integer);

implementation

uses
  System.Math,
  System.SysUtils;

var
  SpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;
  DisplayBands: TAudioMonitorSpectrumData;
  DisplayBandsValid: Boolean;

procedure InitializeViewSpectrum;
begin
  try
    if SpectrumMemory = nil then
      SpectrumMemory := TAul2AudioMonitorSpectrumSharedMemory.Create;
  except
    FreeAndNil(SpectrumMemory);
    DisplayBandsValid := False;
  end;
end;

procedure FinalizeViewSpectrum;
begin
  FreeAndNil(SpectrumMemory);
  DisplayBandsValid := False;
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
  out Valid: Boolean; CurrentFrame: Integer);
var
  State: PAul2AudioMonitorSpectrumState;
  Band: Integer;
begin
  FillChar(Bands, SizeOf(Bands), 0);
  Valid := False;

  if SpectrumMemory = nil then
    InitializeViewSpectrum;

  if SpectrumMemory = nil then
    Exit;

  State := SpectrumMemory.State;
  if (State = nil) or
     (State^.Magic <> AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) or
     (State^.Version <> AUDIO_MONITOR_SPECTRUM_SHARED_VERSION) then
    Exit;

  if not StateMatchesFrame(State, CurrentFrame) then
  begin
    DisplayBandsValid := False;
    Exit;
  end;

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
