unit Aul2AudioViewRenderUtils;

// Small pixel drawing helpers shared by Aul2AudioView render units.

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

type
  TPixelArray = array[0..0] of TPIXEL_RGBA;
  PPixelArray = ^TPixelArray;

procedure ClearPixels(Buffer: PPIXEL_RGBA; Width, Height: Integer);
procedure FillRect(Buffer: PPIXEL_RGBA; Width, Height, X1, Y1, X2, Y2: Integer;
  R, G, B, A: Byte);
procedure GetViewColor(const Settings: TAul2AudioViewSettings; Index, Count: Integer;
  out R, G, B: Byte);

implementation

uses
  System.Math,
  Aul2ColorUtils,
  Aul2ColorPalette;

procedure ClearPixels(Buffer: PPIXEL_RGBA; Width, Height: Integer);
var
  I: Integer;
  PixelCount: Integer;
  Pixels: PPixelArray;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  Pixels := PPixelArray(Buffer);
  PixelCount := Width * Height;
  for I := 0 to PixelCount - 1 do
  begin
    Pixels^[I].R := 0;
    Pixels^[I].G := 0;
    Pixels^[I].B := 0;
    Pixels^[I].A := 0;
  end;
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

procedure FillRect(Buffer: PPIXEL_RGBA; Width, Height, X1, Y1, X2, Y2: Integer;
  R, G, B, A: Byte);
var
  X, Y: Integer;
  Pixels: PPixelArray;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  Pixels := PPixelArray(Buffer);
  X1 := Max(0, X1);
  Y1 := Max(0, Y1);
  X2 := Min(Width - 1, X2);
  Y2 := Min(Height - 1, Y2);

  if (X1 > X2) or (Y1 > Y2) then
    Exit;

  for Y := Y1 to Y2 do
    for X := X1 to X2 do
      PutPixel(Pixels, Width, Height, X, Y, R, G, B, A);
end;

function ToColorBlendMode(Value: Integer): TAul2ColorBlendMode;
begin
  case Value of
    VIEW_COLOR_BLEND_RGB:
      Result := cbRGB;
    VIEW_COLOR_BLEND_HSV_SHORT:
      Result := cbHSVShort;
    VIEW_COLOR_BLEND_HSV_LONG:
      Result := cbHSVLong;
  else
    Result := cbAuto;
  end;
end;

function ToColorPalette(ColorVariation: Integer): TAul2ColorPalette;
var
  PaletteValue: Integer;
begin
  PaletteValue := ColorVariation - 1;
  if (PaletteValue >= Ord(Low(TAul2ColorPalette))) and
     (PaletteValue <= Ord(High(TAul2ColorPalette))) then
    Result := TAul2ColorPalette(PaletteValue)
  else
    Result := cpRainbow;
end;

procedure GetViewColor(const Settings: TAul2AudioViewSettings; Index, Count: Integer;
  out R, G, B: Byte);
var
  T: Double;
  Color: TAul2RGBColor;
begin
  if Settings.ColorVariation = VIEW_COLOR_VARIATION_ONE_COLOR then
  begin
    R := Settings.ColorR;
    G := Settings.ColorG;
    B := Settings.ColorB;
    Exit;
  end;

  T := Index / Max(1, Count - 1);
  Color := GetPaletteColor(
    ToColorPalette(Settings.ColorVariation),
    T,
    ToColorBlendMode(Settings.ColorBlend)
  );

  R := Color.R;
  G := Color.G;
  B := Color.B;
end;

end.
