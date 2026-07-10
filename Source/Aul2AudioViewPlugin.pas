unit Aul2AudioViewPlugin;

// Provides the entry point for the view filter placed on Aul2AudioBaseInput.

interface

uses
  Aul2AudioFilterTypes;

function GetViewFilterTable: PFILTER_PLUGIN_TABLE;
procedure InitializeViewPlugin;
procedure FinalizeViewPlugin;

implementation

uses
  System.SysUtils,
  Aul2AudioFilterGui,
  Aul2AudioViewParams,
  Aul2AudioViewRender,
  Aul2AudioViewRenderEqualizer,
  Aul2AudioViewWave;

var
  GViewTypeSelect  : TFILTER_ITEM_SELECT;
  GViewTypeList    : array[0..5] of TFILTER_ITEM_SELECT_ITEM;
  GViewStyleSelect : TFILTER_ITEM_SELECT;
  GViewStyleList   : array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  GViewDensityTrack: TFILTER_ITEM_TRACK;
  GViewSpacingTrack: TFILTER_ITEM_TRACK;
  GViewThicknessTrack: TFILTER_ITEM_TRACK;
  GViewSourceLayerSelect: TFILTER_ITEM_SELECT;
  GViewSourceLayerList: array[0..65] of TFILTER_ITEM_SELECT_ITEM;
  GViewSourceLayerNames: array[0..64] of string;
  GViewSpectrumScaleSelect: TFILTER_ITEM_SELECT;
  GViewSpectrumScaleList: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  GViewSpectrumLowHzTrack: TFILTER_ITEM_TRACK;
  GViewSpectrumHighHzTrack: TFILTER_ITEM_TRACK;
  GViewSpectrumHighBoostTrack: TFILTER_ITEM_TRACK;
  GViewColor1Item  : TFILTER_ITEM_COLOR;
  GViewColor2Item  : TFILTER_ITEM_COLOR;
  GViewColor3Item  : TFILTER_ITEM_COLOR;
  GViewColorVariationSelect: TFILTER_ITEM_SELECT;
  GViewColorVariationList  : array[0..22] of TFILTER_ITEM_SELECT_ITEM;
  GViewColorBlendSelect: TFILTER_ITEM_SELECT;
  GViewColorBlendList  : array[0..4] of TFILTER_ITEM_SELECT_ITEM;
  GViewSmoothTrack : TFILTER_ITEM_TRACK;

procedure InitializeViewPlugin;
begin
  InitializeEqualizerBars;
  InitializeViewWave;
end;

function ViewProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  Settings: TAul2AudioViewSettings;
begin
  try
    Settings.ViewType := GViewTypeSelect.Value;
    Settings.Style := GViewStyleSelect.Value;
    Settings.Density := Round(GViewDensityTrack.Value);
    Settings.Spacing := Round(GViewSpacingTrack.Value);
    Settings.Thickness := Round(GViewThicknessTrack.Value);
    Settings.Smooth := Round(GViewSmoothTrack.Value);
    Settings.SourceLayer := GViewSourceLayerSelect.Value;
    Settings.SpectrumScale := GViewSpectrumScaleSelect.Value;
    Settings.SpectrumLowHz := Round(GViewSpectrumLowHzTrack.Value);
    Settings.SpectrumHighHz := Round(GViewSpectrumHighHzTrack.Value);
    Settings.SpectrumHighBoost := Round(GViewSpectrumHighBoostTrack.Value);
    Settings.ColorVariation := GViewColorVariationSelect.Value;
    Settings.ColorBlend := GViewColorBlendSelect.Value;
    Settings.Color1R := GViewColor1Item.R;
    Settings.Color1G := GViewColor1Item.G;
    Settings.Color1B := GViewColor1Item.B;
    Settings.Color2R := GViewColor2Item.R;
    Settings.Color2G := GViewColor2Item.G;
    Settings.Color2B := GViewColor2Item.B;
    Settings.Color3R := GViewColor3Item.R;
    Settings.Color3G := GViewColor3Item.G;
    Settings.Color3B := GViewColor3Item.B;
    RenderView(Video, Settings);
  except
    Result := 0;
    Exit;
  end;

  Result := 1;
end;

function GetViewFilterTable: PFILTER_PLUGIN_TABLE;
var
  Layer: Integer;
begin
  if GTable.Name = nil then
  begin
    SetupPluginTable(
      FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,       // モード指定
      'Aul2Audio View',                              // 名称
      'Video Effects',                               // グループ
      'Aul2AudioView for AviUtl ExEdit2',            // 詳細
      ViewProcVideo,
      nil
    );

    ClearSelectList;
    AddSelectList(GViewSourceLayerList, 'Auto', 0);
    for Layer := 1 to 64 do
    begin
      GViewSourceLayerNames[Layer] := 'Layer ' + IntToStr(Layer);
      AddSelectList(GViewSourceLayerList, PWideChar(GViewSourceLayerNames[Layer]), Layer);
    end;
    AddSelect(GViewSourceLayerSelect, 'Source Layer', 0, @GViewSourceLayerList[0]);

    ClearSelectList;
    AddSelectList(GViewTypeList, 'Equalizer Bars', VIEW_TYPE_EQUALIZER_BARS);
    AddSelectList(GViewTypeList, 'Wave Line', VIEW_TYPE_WAVE_LINE);
    AddSelectList(GViewTypeList, 'Pixel Wave', VIEW_TYPE_PIXEL_WAVE);
    AddSelectList(GViewTypeList, 'Filled Spectrum', VIEW_TYPE_FILLED_SPECTRUM);
    AddSelectList(GViewTypeList, 'Pulse Wave', VIEW_TYPE_PULSE_WAVE);
    AddSelect(GViewTypeSelect, 'Type', VIEW_TYPE_EQUALIZER_BARS, @GViewTypeList[0]);

    ClearSelectList;
    AddSelectList(GViewStyleList, 'Solid', VIEW_STYLE_SOLID);
    AddSelectList(GViewStyleList, 'Blocks', VIEW_STYLE_BLOCKS);
    AddSelect(GViewStyleSelect, 'Style', VIEW_STYLE_BLOCKS, @GViewStyleList[0]);

    AddTrack(GViewDensityTrack, 'Density', 32, 4, 128, 1);
    AddTrack(GViewSpacingTrack, 'Spacing', 2, 0, 32, 1);
    AddTrack(GViewThicknessTrack, 'Thickness', 2, 1, 32, 1);
    AddTrack(GViewSmoothTrack, 'Smooth', 50, 0, 100, 1);

    ClearSelectList;
    AddSelectList(GViewSpectrumScaleList, 'Log', VIEW_SPECTRUM_SCALE_LOG);
    AddSelectList(GViewSpectrumScaleList, 'Linear', VIEW_SPECTRUM_SCALE_LINEAR);
    AddSelect(GViewSpectrumScaleSelect, 'Spectrum Scale',
      VIEW_SPECTRUM_SCALE_LOG, @GViewSpectrumScaleList[0]);
    AddTrack(GViewSpectrumLowHzTrack, 'Low Hz', 40, 20, 20000, 1);
    AddTrack(GViewSpectrumHighHzTrack, 'High Hz', 12000, 20, 20000, 1);
    AddTrack(GViewSpectrumHighBoostTrack, 'High Boost', 0, 0, 100, 1);

    AddColor(GViewColor1Item, 'Color 1', 245, 245, 240);
    AddColor(GViewColor2Item, 'Color 2', 60, 180, 220);
    AddColor(GViewColor3Item, 'Color 3', 250, 245, 180);

    ClearSelectList;
    AddSelectList(GViewColorVariationList, '1 Color', VIEW_COLOR_VARIATION_ONE_COLOR);
    AddSelectList(GViewColorVariationList, '2 Color', VIEW_COLOR_VARIATION_TWO_COLOR);
    AddSelectList(GViewColorVariationList, '3 Color', VIEW_COLOR_VARIATION_THREE_COLOR);
    AddSelectList(GViewColorVariationList, 'Rainbow', VIEW_COLOR_VARIATION_RAINBOW);
    AddSelectList(GViewColorVariationList, 'Warm', VIEW_COLOR_VARIATION_WARM);
    AddSelectList(GViewColorVariationList, 'Cool', VIEW_COLOR_VARIATION_COOL);
    AddSelectList(GViewColorVariationList, 'Pastel', VIEW_COLOR_VARIATION_PASTEL);
    AddSelectList(GViewColorVariationList, 'Neon', VIEW_COLOR_VARIATION_NEON);
    AddSelectList(GViewColorVariationList, 'Mono', VIEW_COLOR_VARIATION_MONO);
    AddSelectList(GViewColorVariationList, 'Sepia', VIEW_COLOR_VARIATION_SEPIA);
    AddSelectList(GViewColorVariationList, 'Gold', VIEW_COLOR_VARIATION_GOLD);
    AddSelectList(GViewColorVariationList, 'Silver', VIEW_COLOR_VARIATION_SILVER);
    AddSelectList(GViewColorVariationList, 'Fire', VIEW_COLOR_VARIATION_FIRE);
    AddSelectList(GViewColorVariationList, 'Ice', VIEW_COLOR_VARIATION_ICE);
    AddSelectList(GViewColorVariationList, 'Water', VIEW_COLOR_VARIATION_WATER);
    AddSelectList(GViewColorVariationList, 'Aurora', VIEW_COLOR_VARIATION_AURORA);
    AddSelectList(GViewColorVariationList, 'Starlight', VIEW_COLOR_VARIATION_STARLIGHT);
    AddSelectList(GViewColorVariationList, 'Sunset', VIEW_COLOR_VARIATION_SUNSET);
    AddSelectList(GViewColorVariationList, 'Ocean', VIEW_COLOR_VARIATION_OCEAN);
    AddSelectList(GViewColorVariationList, 'Forest', VIEW_COLOR_VARIATION_FOREST);
    AddSelectList(GViewColorVariationList, 'Cyber', VIEW_COLOR_VARIATION_CYBER);
    AddSelectList(GViewColorVariationList, 'Retro Game', VIEW_COLOR_VARIATION_RETRO_GAME);
    AddSelect(GViewColorVariationSelect, 'Color Variation',
      VIEW_COLOR_VARIATION_ONE_COLOR, @GViewColorVariationList[0]);

    ClearSelectList;
    AddSelectList(GViewColorBlendList, 'Auto', VIEW_COLOR_BLEND_AUTO);
    AddSelectList(GViewColorBlendList, 'RGB', VIEW_COLOR_BLEND_RGB);
    AddSelectList(GViewColorBlendList, 'HSV Short', VIEW_COLOR_BLEND_HSV_SHORT);
    AddSelectList(GViewColorBlendList, 'HSV Long', VIEW_COLOR_BLEND_HSV_LONG);
    AddSelect(GViewColorBlendSelect, 'Color Blend', VIEW_COLOR_BLEND_AUTO, @GViewColorBlendList[0]);

  end;

  Result := @GTable;
end;

procedure FinalizeViewPlugin;
begin
  FinalizeViewWave;
  FinalizeEqualizerBars;
end;

end.
