unit Aul2AudioViewRenderUtils;

// Small pixel drawing helpers shared by Aul2AudioView render units.

interface

uses
  Aul2AudioFilterTypes;

type
  TPixelArray = array[0..0] of TPIXEL_RGBA;
  PPixelArray = ^TPixelArray;

procedure ClearPixels(Buffer: PPIXEL_RGBA; Width, Height: Integer);
procedure FillRect(Buffer: PPIXEL_RGBA; Width, Height, X1, Y1, X2, Y2: Integer;
  R, G, B, A: Byte);
procedure GetSolidOrRainbowColor(ColorStyle: Integer; BaseR, BaseG, BaseB: Byte;
  Index, Count: Integer; out R, G, B: Byte);

implementation

uses
  System.Math,
  Aul2AudioViewParams;

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

procedure GetSolidOrRainbowColor(ColorStyle: Integer; BaseR, BaseG, BaseB: Byte;
  Index, Count: Integer; out R, G, B: Byte);
var
  Hue: Double;
  Segment: Integer;
  F: Double;
  Q: Byte;
  T: Byte;
begin
  if ColorStyle <> VIEW_COLOR_RAINBOW then
  begin
    R := BaseR;
    G := BaseG;
    B := BaseB;
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

end.
