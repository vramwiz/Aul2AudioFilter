unit Aul2AudioViewRenderEqualizer;

// Draws the Equalizer Bars view type.

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

procedure InitializeEqualizerBars;
procedure FinalizeEqualizerBars;
procedure DrawEqualizerBars(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);

implementation

uses
  System.Math,
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewSpectrum;

var
  CurrentBands: TAudioMonitorSpectrumData;
  CurrentBandsValid: Boolean;

procedure InitializeEqualizerBars;
begin
  InitializeViewSpectrum;
end;

procedure FinalizeEqualizerBars;
begin
  FinalizeViewSpectrum;
  CurrentBandsValid := False;
end;

function BandValue(Index, Count: Integer): Single;
var
  Band: Integer;
begin
  if (not CurrentBandsValid) or (Count <= 1) then
    Exit(0.0);

  Band := Round(Index * AUDIO_MONITOR_SPECTRUM_BAND_LAST / (Count - 1));
  Band := Max(0, Min(AUDIO_MONITOR_SPECTRUM_BAND_LAST, Band));
  Result := CurrentBands[Band];
end;

procedure DrawSolidBars(Buffer: PPIXEL_RGBA; Width, Height, AreaW, AreaH, MarginX,
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
    GetSolidOrRainbowColor(Settings.ColorStyle, Settings.ColorR, Settings.ColorG,
      Settings.ColorB, I, Count, R, G, B);
    FillRect(Buffer, Width, Height, X, BaseY - BarH + 1, X + BarW - 1, BaseY, R, G, B, 255);
  end;
end;

procedure DrawBlockBars(Buffer: PPIXEL_RGBA; Width, Height, AreaW, AreaH, MarginX,
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
    GetSolidOrRainbowColor(Settings.ColorStyle, Settings.ColorR, Settings.ColorG,
      Settings.ColorB, I, Count, R, G, B);
    for Block := 0 to FillCount - 1 do
    begin
      Y2 := BaseY - Block * (BlockH + Gap);
      FillRect(Buffer, Width, Height, X, Y2 - BlockH + 1, X + BarW - 1, Y2, R, G, B, 255);
    end;
  end;
end;

procedure DrawEqualizerBars(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
var
  MarginX: Integer;
  MarginY: Integer;
  AreaW: Integer;
  AreaH: Integer;
  BaseY: Integer;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  UpdateViewSpectrum(Settings.Smooth, CurrentBands, CurrentBandsValid, CurrentFrame);

  MarginX := Max(8, Width div 28);
  MarginY := Max(6, Height div 16);
  AreaW := Width - (MarginX * 2);
  AreaH := Height - (MarginY * 2);
  if (AreaW <= 0) or (AreaH <= 0) then
    Exit;

  BaseY := Height - MarginY - 1;

  if Settings.Style = VIEW_STYLE_SOLID then
    DrawSolidBars(Buffer, Width, Height, AreaW, AreaH, MarginX, BaseY, Settings)
  else
    DrawBlockBars(Buffer, Width, Height, AreaW, AreaH, MarginX, BaseY, Settings);
end;

end.
