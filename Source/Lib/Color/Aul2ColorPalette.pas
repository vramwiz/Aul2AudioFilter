unit Aul2ColorPalette;

interface

uses
  Aul2ColorUtils;

type
  TAul2ColorPalette = (
    cpTwoColor,
    cpThreeColor,
    cpRainbow,
    cpWarm,
    cpCool,
    cpPastel,
    cpNeon,
    cpMono,
    cpSepia,
    cpGold,
    cpSilver,
    cpFire,
    cpIce,
    cpWater,
    cpAurora,
    cpStarlight,
    cpSunset,
    cpOcean,
    cpForest,
    cpCyber,
    cpRetroGame
  );

function GetPaletteDefaultBlendMode(Palette: TAul2ColorPalette): TAul2ColorBlendMode;
function GetPaletteColor(Palette: TAul2ColorPalette; T: Double;
  BlendMode: TAul2ColorBlendMode): TAul2RGBColor;
function GetPaletteName(Palette: TAul2ColorPalette): string;

implementation

type
  TAul2PaletteStop = record
    Pos: Double;
    Color: TAul2RGBColor;
  end;

  TAul2PaletteStops = array of TAul2PaletteStop;

function Stop(Pos: Double; R, G, B: Byte): TAul2PaletteStop;
begin
  Result.Pos := Pos;
  Result.Color := Aul2RGB(R, G, B);
end;

function MakeStops(const Values: array of TAul2PaletteStop): TAul2PaletteStops;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := Values[I];
end;

function StopsForPalette(Palette: TAul2ColorPalette): TAul2PaletteStops;
begin
  case Palette of
    cpThreeColor:
      Result := MakeStops([Stop(0.0, 24, 30, 78), Stop(0.5, 60, 180, 220), Stop(1.0, 250, 245, 180)]);
    cpRainbow:
      Result := MakeStops([Stop(0.0, 255, 0, 0), Stop(0.16, 255, 128, 0), Stop(0.33, 255, 255, 0),
        Stop(0.50, 0, 220, 80), Stop(0.66, 0, 150, 255), Stop(0.82, 60, 60, 220),
        Stop(1.0, 180, 0, 255)]);
    cpWarm:
      Result := MakeStops([Stop(0.0, 180, 24, 32), Stop(0.5, 255, 112, 24), Stop(1.0, 255, 220, 64)]);
    cpCool:
      Result := MakeStops([Stop(0.0, 30, 220, 255), Stop(0.5, 40, 96, 240), Stop(1.0, 150, 70, 220)]);
    cpPastel:
      Result := MakeStops([Stop(0.0, 255, 170, 210), Stop(0.33, 160, 220, 255),
        Stop(0.66, 255, 240, 150), Stop(1.0, 205, 185, 255)]);
    cpNeon:
      Result := MakeStops([Stop(0.0, 0, 255, 255), Stop(0.33, 255, 0, 220),
        Stop(0.66, 120, 255, 0), Stop(1.0, 255, 240, 0)]);
    cpMono:
      Result := MakeStops([Stop(0.0, 0, 0, 0), Stop(1.0, 255, 255, 255)]);
    cpSepia:
      Result := MakeStops([Stop(0.0, 58, 34, 18), Stop(0.5, 156, 105, 58), Stop(1.0, 245, 225, 178)]);
    cpGold:
      Result := MakeStops([Stop(0.0, 64, 36, 8), Stop(0.45, 220, 154, 34), Stop(0.7, 255, 230, 110),
        Stop(1.0, 255, 248, 190)]);
    cpSilver:
      Result := MakeStops([Stop(0.0, 44, 48, 54), Stop(0.45, 170, 180, 190), Stop(0.7, 245, 248, 250),
        Stop(1.0, 118, 126, 136)]);
    cpFire:
      Result := MakeStops([Stop(0.0, 20, 0, 0), Stop(0.25, 160, 0, 0), Stop(0.55, 255, 76, 0),
        Stop(0.82, 255, 220, 40), Stop(1.0, 255, 255, 245)]);
    cpIce:
      Result := MakeStops([Stop(0.0, 0, 22, 96), Stop(0.45, 0, 190, 255), Stop(1.0, 245, 255, 255)]);
    cpWater:
      Result := MakeStops([Stop(0.0, 0, 40, 130), Stop(0.4, 0, 135, 150), Stop(0.75, 80, 220, 255),
        Stop(1.0, 245, 255, 255)]);
    cpAurora:
      Result := MakeStops([Stop(0.0, 40, 240, 100), Stop(0.25, 60, 230, 220), Stop(0.5, 60, 120, 255),
        Stop(0.75, 160, 70, 255), Stop(1.0, 255, 120, 210)]);
    cpStarlight:
      Result := MakeStops([Stop(0.0, 5, 10, 38), Stop(0.45, 40, 25, 95), Stop(0.72, 180, 220, 255),
        Stop(1.0, 255, 255, 255)]);
    cpSunset:
      Result := MakeStops([Stop(0.0, 45, 15, 90), Stop(0.35, 190, 30, 80), Stop(0.68, 255, 112, 30),
        Stop(1.0, 255, 220, 70)]);
    cpOcean:
      Result := MakeStops([Stop(0.0, 0, 20, 80), Stop(0.45, 0, 90, 210), Stop(1.0, 90, 230, 255)]);
    cpForest:
      Result := MakeStops([Stop(0.0, 12, 70, 36), Stop(0.35, 28, 150, 70), Stop(0.7, 160, 220, 80),
        Stop(1.0, 110, 78, 38)]);
    cpCyber:
      Result := MakeStops([Stop(0.0, 0, 8, 30), Stop(0.45, 0, 255, 255), Stop(0.7, 255, 0, 220),
        Stop(1.0, 18, 20, 60)]);
    cpRetroGame:
      Result := MakeStops([Stop(0.0, 0, 0, 0), Stop(0.25, 255, 40, 40), Stop(0.5, 40, 100, 255),
        Stop(0.75, 40, 220, 70), Stop(1.0, 255, 230, 40)]);
  else
    Result := MakeStops([Stop(0.0, 0, 80, 255), Stop(1.0, 180, 0, 255)]);
  end;
end;

function GetPaletteDefaultBlendMode(Palette: TAul2ColorPalette): TAul2ColorBlendMode;
begin
  case Palette of
    cpRainbow, cpPastel, cpNeon, cpCyber, cpRetroGame:
      Result := cbRGB;
    cpWarm, cpCool, cpOcean, cpAurora, cpTwoColor, cpThreeColor:
      Result := cbHSVShort;
  else
    Result := cbRGB;
  end;
end;

function GetPaletteColor(Palette: TAul2ColorPalette; T: Double;
  BlendMode: TAul2ColorBlendMode): TAul2RGBColor;
var
  Stops: TAul2PaletteStops;
  I: Integer;
  LocalT: Double;
  EffectiveBlend: TAul2ColorBlendMode;
begin
  T := Clamp01(T);
  Stops := StopsForPalette(Palette);
  if Length(Stops) = 0 then
    Exit(Aul2RGB(255, 255, 255));

  if T <= Stops[0].Pos then
    Exit(Stops[0].Color);

  for I := 1 to High(Stops) do
  begin
    if T <= Stops[I].Pos then
    begin
      if Stops[I].Pos <= Stops[I - 1].Pos then
        LocalT := 0
      else
        LocalT := (T - Stops[I - 1].Pos) / (Stops[I].Pos - Stops[I - 1].Pos);

      EffectiveBlend := BlendMode;
      if EffectiveBlend = cbAuto then
        EffectiveBlend := GetPaletteDefaultBlendMode(Palette);

      Exit(LerpColor(Stops[I - 1].Color, Stops[I].Color, LocalT, EffectiveBlend));
    end;
  end;

  Result := Stops[High(Stops)].Color;
end;

function GetPaletteName(Palette: TAul2ColorPalette): string;
begin
  case Palette of
    cpTwoColor: Result := '2 Color';
    cpThreeColor: Result := '3 Color';
    cpRainbow: Result := 'Rainbow';
    cpWarm: Result := 'Warm';
    cpCool: Result := 'Cool';
    cpPastel: Result := 'Pastel';
    cpNeon: Result := 'Neon';
    cpMono: Result := 'Mono';
    cpSepia: Result := 'Sepia';
    cpGold: Result := 'Gold';
    cpSilver: Result := 'Silver';
    cpFire: Result := 'Fire';
    cpIce: Result := 'Ice';
    cpWater: Result := 'Water';
    cpAurora: Result := 'Aurora';
    cpStarlight: Result := 'Starlight';
    cpSunset: Result := 'Sunset';
    cpOcean: Result := 'Ocean';
    cpForest: Result := 'Forest';
    cpCyber: Result := 'Cyber';
    cpRetroGame: Result := 'Retro Game';
  else
    Result := '';
  end;
end;

end.
