unit Aul2ColorUtils;

interface

type
  TAul2ColorBlendMode = (
    cbAuto,
    cbRGB,
    cbHSVShort,
    cbHSVLong
  );

  TAul2RGBColor = record
    R: Byte;
    G: Byte;
    B: Byte;
  end;

function Aul2RGB(R, G, B: Byte): TAul2RGBColor;
function ClampByte(Value: Integer): Byte;
function Clamp01(Value: Double): Double;

procedure RGBToHSV(R, G, B: Byte; out H, S, V: Double);
procedure HSVToRGB(H, S, V: Double; out R, G, B: Byte);

function LerpRGB(const C1, C2: TAul2RGBColor; T: Double): TAul2RGBColor;
function LerpHSVShort(const C1, C2: TAul2RGBColor; T: Double): TAul2RGBColor;
function LerpHSVLong(const C1, C2: TAul2RGBColor; T: Double): TAul2RGBColor;
function LerpColor(const C1, C2: TAul2RGBColor; T: Double;
  BlendMode: TAul2ColorBlendMode): TAul2RGBColor;

implementation

uses
  System.Math;

function Aul2RGB(R, G, B: Byte): TAul2RGBColor;
begin
  Result.R := R;
  Result.G := G;
  Result.B := B;
end;

function ClampByte(Value: Integer): Byte;
begin
  Result := Byte(Max(0, Min(255, Value)));
end;

function Clamp01(Value: Double): Double;
begin
  Result := Max(0.0, Min(1.0, Value));
end;

procedure RGBToHSV(R, G, B: Byte; out H, S, V: Double);
var
  Rd, Gd, Bd: Double;
  CMax, CMin, Delta: Double;
begin
  Rd := R / 255.0;
  Gd := G / 255.0;
  Bd := B / 255.0;

  CMax := Max(Rd, Max(Gd, Bd));
  CMin := Min(Rd, Min(Gd, Bd));
  Delta := CMax - CMin;

  if Delta = 0 then
    H := 0
  else if CMax = Rd then
    H := 60 * ((Gd - Bd) / Delta)
  else if CMax = Gd then
    H := 60 * (((Bd - Rd) / Delta) + 2)
  else
    H := 60 * (((Rd - Gd) / Delta) + 4);

  while H < 0 do
    H := H + 360;
  while H >= 360 do
    H := H - 360;

  if CMax = 0 then
    S := 0
  else
    S := Delta / CMax;

  V := CMax;
end;

procedure HSVToRGB(H, S, V: Double; out R, G, B: Byte);
var
  C, X, M: Double;
  Rp, Gp, Bp: Double;
  Hs: Double;
begin
  Hs := H;
  while Hs >= 360 do
    Hs := Hs - 360;
  while Hs < 0 do
    Hs := Hs + 360;

  S := Clamp01(S);
  V := Clamp01(V);

  C := V * S;
  X := C * (1 - Abs(Frac(Hs / 60) * 2 - 1));
  M := V - C;

  if Hs < 60 then
  begin
    Rp := C; Gp := X; Bp := 0;
  end
  else if Hs < 120 then
  begin
    Rp := X; Gp := C; Bp := 0;
  end
  else if Hs < 180 then
  begin
    Rp := 0; Gp := C; Bp := X;
  end
  else if Hs < 240 then
  begin
    Rp := 0; Gp := X; Bp := C;
  end
  else if Hs < 300 then
  begin
    Rp := X; Gp := 0; Bp := C;
  end
  else
  begin
    Rp := C; Gp := 0; Bp := X;
  end;

  R := ClampByte(Round((Rp + M) * 255));
  G := ClampByte(Round((Gp + M) * 255));
  B := ClampByte(Round((Bp + M) * 255));
end;

function LerpRGB(const C1, C2: TAul2RGBColor; T: Double): TAul2RGBColor;
begin
  T := Clamp01(T);
  Result.R := ClampByte(Round(C1.R + (C2.R - C1.R) * T));
  Result.G := ClampByte(Round(C1.G + (C2.G - C1.G) * T));
  Result.B := ClampByte(Round(C1.B + (C2.B - C1.B) * T));
end;

function LerpHSV(const C1, C2: TAul2RGBColor; T: Double; UseLongPath: Boolean): TAul2RGBColor;
var
  H1, S1, V1: Double;
  H2, S2, V2: Double;
  HueDelta: Double;
  H, S, V: Double;
begin
  T := Clamp01(T);

  RGBToHSV(C1.R, C1.G, C1.B, H1, S1, V1);
  RGBToHSV(C2.R, C2.G, C2.B, H2, S2, V2);

  HueDelta := H2 - H1;
  if HueDelta > 180 then
    HueDelta := HueDelta - 360
  else if HueDelta < -180 then
    HueDelta := HueDelta + 360;

  if UseLongPath then
  begin
    if HueDelta >= 0 then
      HueDelta := HueDelta - 360
    else
      HueDelta := HueDelta + 360;
  end;

  H := H1 + HueDelta * T;
  S := S1 + (S2 - S1) * T;
  V := V1 + (V2 - V1) * T;
  HSVToRGB(H, S, V, Result.R, Result.G, Result.B);
end;

function LerpHSVShort(const C1, C2: TAul2RGBColor; T: Double): TAul2RGBColor;
begin
  Result := LerpHSV(C1, C2, T, False);
end;

function LerpHSVLong(const C1, C2: TAul2RGBColor; T: Double): TAul2RGBColor;
begin
  Result := LerpHSV(C1, C2, T, True);
end;

function LerpColor(const C1, C2: TAul2RGBColor; T: Double;
  BlendMode: TAul2ColorBlendMode): TAul2RGBColor;
begin
  case BlendMode of
    cbHSVShort:
      Result := LerpHSVShort(C1, C2, T);
    cbHSVLong:
      Result := LerpHSVLong(C1, C2, T);
  else
    Result := LerpRGB(C1, C2, T);
  end;
end;

end.
