unit Aul2AudioViewRenderFilledSpectrum;

// Draws the Filled Spectrum view type.

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

procedure DrawFilledSpectrum(Buffer: PPIXEL_RGBA; Width, Height: Integer;
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
  CurrentSourceMinHz: Single;
  CurrentSourceMaxHz: Single;

const
  VIEW_MARGIN_X = 0; // Keep as a named value so this can become a setting later.
  VIEW_MARGIN_Y = 0;

function BandValue(const Settings: TAul2AudioViewSettings; Index, Count: Integer): Single;
begin
  Result := GetSpectrumDisplayValue(CurrentBands, CurrentBandsValid,
    CurrentSourceMinHz, CurrentSourceMaxHz, Settings, Index, Count);
end;

procedure DrawSolidFilled(Buffer: PPIXEL_RGBA; Width, Height, AreaW, AreaH,
  MarginX, BaseY: Integer; const Settings: TAul2AudioViewSettings);
var
  X: Integer;
  FillH: Integer;
  TopY: Integer;
  R, G, B: Byte;
begin
  for X := 0 to AreaW - 1 do
  begin
    FillH := Round(AreaH * BandValue(Settings, X, AreaW));
    if FillH <= 0 then
      Continue;

    GetViewColor(Settings, X, AreaW, R, G, B);

    TopY := BaseY - FillH + 1;
    FillRect(Buffer, Width, Height, MarginX + X, TopY, MarginX + X, BaseY, R, G, B, 255);
    FillRect(Buffer, Width, Height, MarginX + X, TopY, MarginX + X, TopY + 1, 255, 255, 255, 255);
  end;
end;

procedure DrawBlockFilled(Buffer: PPIXEL_RGBA; Width, Height, AreaW, AreaH,
  MarginX, BaseY: Integer; const Settings: TAul2AudioViewSettings);
var
  Gap: Integer;
  BlockH: Integer;
  BlockCount: Integer;
  FillCount: Integer;
  X: Integer;
  Block: Integer;
  Y2: Integer;
  R, G, B: Byte;
begin
  Gap := Max(0, Min(32, Settings.Spacing));
  BlockH := Max(1, AreaH div Max(6, Min(64, Settings.Density)));
  BlockCount := Max(1, (AreaH + Gap) div Max(1, BlockH + Gap));

  for X := 0 to AreaW - 1 do
  begin
    FillCount := Round(BlockCount * BandValue(Settings, X, AreaW));
    if FillCount <= 0 then
      Continue;

    GetViewColor(Settings, X, AreaW, R, G, B);
    for Block := 0 to FillCount - 1 do
    begin
      Y2 := BaseY - Block * (BlockH + Gap);
      FillRect(Buffer, Width, Height, MarginX + X, Y2 - BlockH + 1, MarginX + X, Y2, R, G, B, 255);
    end;

    Y2 := BaseY - FillCount * (BlockH + Gap) + Gap;
    FillRect(Buffer, Width, Height, MarginX + X, Y2, MarginX + X, Y2 + 1, 255, 255, 255, 255);
  end;
end;

procedure DrawFilledSpectrum(Buffer: PPIXEL_RGBA; Width, Height: Integer;
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
  UpdateViewSpectrum(Settings.Smooth, CurrentBands, CurrentBandsValid,
    CurrentSourceMinHz, CurrentSourceMaxHz, CurrentFrame, Settings.SourceLayer);

  MarginX := VIEW_MARGIN_X;
  MarginY := VIEW_MARGIN_Y;
  AreaW := Width - (MarginX * 2);
  AreaH := Height - (MarginY * 2);
  if (AreaW <= 0) or (AreaH <= 0) then
    Exit;

  BaseY := Height - MarginY - 1;

  if Settings.Style = VIEW_STYLE_BLOCKS then
    DrawBlockFilled(Buffer, Width, Height, AreaW, AreaH, MarginX, BaseY, Settings)
  else
    DrawSolidFilled(Buffer, Width, Height, AreaW, AreaH, MarginX, BaseY, Settings);
end;

end.
