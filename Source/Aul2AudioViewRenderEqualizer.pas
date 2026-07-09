unit Aul2AudioViewRenderEqualizer;

// Draws the Equalizer Bars view type from the monitor spectrum shared memory.

interface

uses
  Aul2AudioFilterTypes;

procedure InitializeEqualizerBars;
procedure FinalizeEqualizerBars;
procedure DrawEqualizerBars(Buffer: PPIXEL_RGBA; Width, Height: Integer);

implementation

uses
  System.Math,
  System.SysUtils,
  Aul2AudioMonitorSpectrumShared;

type
  TPixelArray = array[0..0] of TPIXEL_RGBA;
  PPixelArray = ^TPixelArray;

var
  SpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;
  DisplayBands: TAudioMonitorSpectrumData;
  DisplayBandsValid: Boolean;

procedure InitializeEqualizerBars;
begin
  try
    if SpectrumMemory = nil then
      SpectrumMemory := TAul2AudioMonitorSpectrumSharedMemory.Create;
  except
    FreeAndNil(SpectrumMemory);
    DisplayBandsValid := False;
  end;
end;

procedure FinalizeEqualizerBars;
begin
  FreeAndNil(SpectrumMemory);
  DisplayBandsValid := False;
end;

procedure PutPixel(Buffer: PPixelArray; Width, Height, X, Y: Integer; R, G, B, A: Byte);
var
  P: ^TPIXEL_RGBA;
begin
  if (Buffer = nil) or (X < 0) or (Y < 0) or (X >= Width) or (Y >= Height) then
    Exit;

  P := @Buffer^[Y * Width + X];
  P^.R := R;
  P^.G := G;
  P^.B := B;
  P^.A := A;
end;

procedure ClearBuffer(Buffer: PPixelArray; Width, Height: Integer);
var
  I: Integer;
  PixelCount: Integer;
begin
  if Buffer = nil then
    Exit;

  PixelCount := Width * Height;
  for I := 0 to PixelCount - 1 do
  begin
    Buffer^[I].R := 0;
    Buffer^[I].G := 0;
    Buffer^[I].B := 0;
    Buffer^[I].A := 0;
  end;
end;

procedure SmoothBand(var DisplayValue: Single; NewValue: Single);
const
  SPECTRUM_ATTACK = 0.55;
  SPECTRUM_RELEASE = 0.16;
var
  Alpha: Single;
begin
  NewValue := Max(0.0, Min(1.0, NewValue));
  if NewValue > DisplayValue then
    Alpha := SPECTRUM_ATTACK
  else
    Alpha := SPECTRUM_RELEASE;

  DisplayValue := DisplayValue + ((NewValue - DisplayValue) * Alpha);
end;

procedure UpdateDisplayBands;
var
  State: PAul2AudioMonitorSpectrumState;
  Band: Integer;
begin
  if SpectrumMemory = nil then
    InitializeEqualizerBars;

  if SpectrumMemory = nil then
    Exit;

  State := SpectrumMemory.State;
  if (State = nil) or
     (State^.Magic <> AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) or
     (State^.Version <> AUDIO_MONITOR_SPECTRUM_SHARED_VERSION) then
    Exit;

  if not DisplayBandsValid then
  begin
    DisplayBands := State^.OutputBands;
    DisplayBandsValid := True;
    Exit;
  end;

  for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
    SmoothBand(DisplayBands[Band], State^.OutputBands[Band]);
end;

procedure FillRect(Buffer: PPixelArray; Width, Height, X1, Y1, X2, Y2: Integer; R, G, B, A: Byte);
var
  X, Y: Integer;
begin
  X1 := Max(0, X1);
  Y1 := Max(0, Y1);
  X2 := Min(Width - 1, X2);
  Y2 := Min(Height - 1, Y2);

  if (X1 > X2) or (Y1 > Y2) then
    Exit;

  for Y := Y1 to Y2 do
    for X := X1 to X2 do
      PutPixel(Buffer, Width, Height, X, Y, R, G, B, A);
end;

procedure DrawEqualizerBars(Buffer: PPIXEL_RGBA; Width, Height: Integer);
var
  Pixels: PPixelArray;
  Band: Integer;
  MarginX: Integer;
  MarginY: Integer;
  AreaW: Integer;
  AreaH: Integer;
  Gap: Integer;
  BarW: Integer;
  BarH: Integer;
  X: Integer;
  BaseY: Integer;
  Value: Single;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  Pixels := PPixelArray(Buffer);
  ClearBuffer(Pixels, Width, Height);
  UpdateDisplayBands;

  MarginX := Max(8, Width div 28);
  MarginY := Max(6, Height div 16);
  AreaW := Width - (MarginX * 2);
  AreaH := Height - (MarginY * 2);
  if (AreaW <= 0) or (AreaH <= 0) then
    Exit;

  Gap := Max(1, AreaW div 160);
  BarW := Max(1, (AreaW - (Gap * AUDIO_MONITOR_SPECTRUM_BAND_LAST)) div AUDIO_MONITOR_SPECTRUM_BAND_COUNT);
  BaseY := Height - MarginY - 1;

  for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
  begin
    if DisplayBandsValid then
      Value := DisplayBands[Band]
    else
      Value := 0.0;

    BarH := Round(AreaH * Max(0.0, Min(1.0, Value)));
    if BarH <= 0 then
      Continue;

    X := MarginX + Band * (BarW + Gap);
    FillRect(Pixels, Width, Height, X, BaseY - BarH + 1, X + BarW - 1, BaseY, 245, 245, 240, 255);
  end;
end;

end.
