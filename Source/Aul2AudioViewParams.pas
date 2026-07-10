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

  VIEW_COLOR_SOLID   = 0;
  VIEW_COLOR_RAINBOW = 1;

type
  TAul2AudioViewSettings = record
    ViewType: Integer;
    Style: Integer;
    Density: Integer;
    Spacing: Integer;
    Thickness: Integer;
    Smooth: Integer;
    ColorStyle: Integer;
    ColorR: Byte;
    ColorG: Byte;
    ColorB: Byte;
  end;

implementation

end.
