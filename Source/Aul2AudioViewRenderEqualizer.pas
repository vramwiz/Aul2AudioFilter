unit Aul2AudioViewRenderEqualizer;

// Draws the Equalizer Bars view type from the monitor spectrum shared memory.

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

procedure InitializeEqualizerBars;
procedure FinalizeEqualizerBars;
procedure DrawEqualizerBars(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings);

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

procedure UpdateDisplayBands(Smooth: Integer);
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
    SmoothBand(DisplayBands[Band], State^.OutputBands[Band], Smooth);
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

procedure GetBarColor(const Settings: TAul2AudioViewSettings; Index, Count: Integer;
  out R, G, B: Byte);
var
  Hue: Double;
  Segment: Integer;
  F: Double;
  Q: Byte;
  T: Byte;
begin
  if Settings.ColorStyle <> VIEW_COLOR_RAINBOW then
  begin
    R := Settings.ColorR;
    G := Settings.ColorG;
    B := Settings.ColorB;
    Exit;
  end;

  Hue := 6.0 * Index / Max(1, Count);
  Segment := Trunc(Hue);
  F := Hue - Segment;
  Q := Round(255 * (1.0 - F));
  T := Round(255 * F);

  case Segment mod 6 of
    0: begin R := 255; G := T;   B := 0;   end;
    1: begin R := Q;   G := 255; B := 0;   end;
    2: begin R := 0;   G := 255; B := T;   end;
    3: begin R := 0;   G := Q;   B := 255; end;
    4: begin R := T;   G := 0;   B := 255; end;
  else
       begin R := 255; G := 0;   B := Q;   end;
  end;
end;

function BandValue(Index, Count: Integer): Single;
var
  Band: Integer;
begin
  if (not DisplayBandsValid) or (Count <= 1) then
    Exit(0.0);

  Band := Round(Index * AUDIO_MONITOR_SPECTRUM_BAND_LAST / (Count - 1));
  Band := Max(0, Min(AUDIO_MONITOR_SPECTRUM_BAND_LAST, Band));
  Result := DisplayBands[Band];
end;

procedure DrawSolidBars(Pixels: PPixelArray; Width, Height, AreaW, AreaH, MarginX,
  BaseY: Integer; const Settings: TAul2AudioViewSettings);
var
  Gap: Integer;
  BarW: Integer;
  BarH: Integer;
  Count: Integer;
  I: Integer;
  X: Integer;
  Value: Single;
  R, G, B: Byte;
begin
  Count := Max(4, Min(128, Settings.Density));
  Gap := 0;
  BarW := Max(1, AreaW div Count);

  for I := 0 to Count - 1 do
  begin
    Value := Max(0.0, Min(1.0, BandValue(I, Count)));
    BarH := Round(AreaH * Value);
    if BarH <= 0 then
      Continue;

    X := MarginX + I * (BarW + Gap);
    GetBarColor(Settings, I, Count, R, G, B);
    FillRect(Pixels, Width, Height, X, BaseY - BarH + 1, X + BarW - 1, BaseY, R, G, B, 255);
  end;
end;

procedure DrawBlockBars(Pixels: PPixelArray; Width, Height, AreaW, AreaH, MarginX,
  BaseY: Integer; const Settings: TAul2AudioViewSettings);
var
  Gap: Integer;
  BarW: Integer;
  Count: Integer;
  I: Integer;
  X: Integer;
  Value: Single;
  BlockH: Integer;
  BlockCount: Integer;
  FillCount: Integer;
  Block: Integer;
  Y2: Integer;
  R, G, B: Byte;
begin
  Count := Max(4, Min(128, Settings.Density));
  Gap := Max(0, Min(32, Settings.Spacing));
  BarW := Max(1, (AreaW - (Gap * (Count - 1))) div Count);
  BlockH := Max(1, Round(BarW * 0.62));
  BlockCount := Max(1, (AreaH + Gap) div Max(1, BlockH + Gap));

  for I := 0 to Count - 1 do
  begin
    Value := Max(0.0, Min(1.0, BandValue(I, Count)));
    FillCount := Round(BlockCount * Value);
    if FillCount <= 0 then
      Continue;

    X := MarginX + I * (BarW + Gap);
    GetBarColor(Settings, I, Count, R, G, B);
    for Block := 0 to FillCount - 1 do
    begin
      Y2 := BaseY - Block * (BlockH + Gap);
      FillRect(Pixels, Width, Height, X, Y2 - BlockH + 1, X + BarW - 1, Y2, R, G, B, 255);
    end;
  end;
end;

procedure DrawEqualizerBars(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings);
var
  Pixels: PPixelArray;
  MarginX: Integer;
  MarginY: Integer;
  AreaW: Integer;
  AreaH: Integer;
  BaseY: Integer;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  Pixels := PPixelArray(Buffer);
  ClearBuffer(Pixels, Width, Height);
  UpdateDisplayBands(Settings.Smooth);

  MarginX := Max(8, Width div 28);
  MarginY := Max(6, Height div 16);
  AreaW := Width - (MarginX * 2);
  AreaH := Height - (MarginY * 2);
  if (AreaW <= 0) or (AreaH <= 0) then
    Exit;

  BaseY := Height - MarginY - 1;

  if Settings.Style = VIEW_STYLE_SOLID then
    DrawSolidBars(Pixels, Width, Height, AreaW, AreaH, MarginX, BaseY, Settings)
  else
    DrawBlockBars(Pixels, Width, Height, AreaW, AreaH, MarginX, BaseY, Settings);
end;

end.
