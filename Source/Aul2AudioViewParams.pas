unit Aul2AudioViewParams;

// Shared parameter definitions for Aul2AudioView render units.

interface

const
  VIEW_TYPE_EQUALIZER_BARS  = 0;
  VIEW_TYPE_WAVE_LINE       = 1;
  VIEW_TYPE_PIXEL_WAVE      = 2;
  VIEW_TYPE_FILLED_SPECTRUM = 3;
  VIEW_TYPE_PULSE_WAVE      = 4;

  VIEW_STYLE_SOLID  = 0;
  VIEW_STYLE_BLOCKS = 1;

  VIEW_COLOR_VARIATION_ONE_COLOR  = 0;
  VIEW_COLOR_VARIATION_TWO_COLOR  = 1;
  VIEW_COLOR_VARIATION_THREE_COLOR = 2;
  VIEW_COLOR_VARIATION_RAINBOW    = 3;
  VIEW_COLOR_VARIATION_WARM       = 4;
  VIEW_COLOR_VARIATION_COOL       = 5;
  VIEW_COLOR_VARIATION_PASTEL     = 6;
  VIEW_COLOR_VARIATION_NEON       = 7;
  VIEW_COLOR_VARIATION_MONO       = 8;
  VIEW_COLOR_VARIATION_SEPIA      = 9;
  VIEW_COLOR_VARIATION_GOLD       = 10;
  VIEW_COLOR_VARIATION_SILVER     = 11;
  VIEW_COLOR_VARIATION_FIRE       = 12;
  VIEW_COLOR_VARIATION_ICE        = 13;
  VIEW_COLOR_VARIATION_WATER      = 14;
  VIEW_COLOR_VARIATION_AURORA     = 15;
  VIEW_COLOR_VARIATION_STARLIGHT  = 16;
  VIEW_COLOR_VARIATION_SUNSET     = 17;
  VIEW_COLOR_VARIATION_OCEAN      = 18;
  VIEW_COLOR_VARIATION_FOREST     = 19;
  VIEW_COLOR_VARIATION_CYBER      = 20;
  VIEW_COLOR_VARIATION_RETRO_GAME = 21;

  VIEW_COLOR_BLEND_AUTO      = 0;
  VIEW_COLOR_BLEND_RGB       = 1;
  VIEW_COLOR_BLEND_HSV_SHORT = 2;
  VIEW_COLOR_BLEND_HSV_LONG  = 3;

  VIEW_SPECTRUM_SCALE_LOG    = 0;
  VIEW_SPECTRUM_SCALE_LINEAR = 1;

type
  TAul2AudioViewSettings = record
    ViewType: Integer;
    Style: Integer;
    Density: Integer;
    Spacing: Integer;
    Thickness: Integer;
    Smooth: Integer;
    SpectrumScale: Integer;
    SpectrumLowHz: Integer;
    SpectrumHighHz: Integer;
    SpectrumHighBoost: Integer;
    ColorVariation: Integer;
    ColorBlend: Integer;
    Color1R: Byte;
    Color1G: Byte;
    Color1B: Byte;
    Color2R: Byte;
    Color2G: Byte;
    Color2B: Byte;
    Color3R: Byte;
    Color3G: Byte;
    Color3B: Byte;
  end;

implementation

end.
