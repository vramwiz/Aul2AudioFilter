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
  Aul2AudioFilterGui,
  Aul2AudioViewParams,
  Aul2AudioViewRender,
  Aul2AudioViewRenderEqualizer;

var
  GViewTypeSelect  : TFILTER_ITEM_SELECT;
  GViewTypeList    : array[0..5] of TFILTER_ITEM_SELECT_ITEM;
  GViewStyleSelect : TFILTER_ITEM_SELECT;
  GViewStyleList   : array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  GViewDensityTrack: TFILTER_ITEM_TRACK;
  GViewSpacingTrack: TFILTER_ITEM_TRACK;
  GViewColorItem   : TFILTER_ITEM_COLOR;
  GViewColorSelect : TFILTER_ITEM_SELECT;
  GViewColorList   : array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  GViewSmoothTrack : TFILTER_ITEM_TRACK;

procedure InitializeViewPlugin;
begin
  InitializeEqualizerBars;
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
    Settings.Smooth := Round(GViewSmoothTrack.Value);
    Settings.ColorStyle := GViewColorSelect.Value;
    Settings.ColorR := GViewColorItem.R;
    Settings.ColorG := GViewColorItem.G;
    Settings.ColorB := GViewColorItem.B;
    RenderView(Video, Settings);
  except
    Result := 0;
    Exit;
  end;

  Result := 1;
end;

function GetViewFilterTable: PFILTER_PLUGIN_TABLE;
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
    AddSelectList(GViewTypeList, 'Equalizer Bars', VIEW_TYPE_EQUALIZER_BARS);
    AddSelectList(GViewTypeList, 'Wave Line', VIEW_TYPE_WAVE_LINE);
    AddSelectList(GViewTypeList, 'Pixel Wave', VIEW_TYPE_PIXEL_WAVE);
    AddSelectList(GViewTypeList, 'Filled Spectrum', VIEW_TYPE_FILLED_SPECTRUM);
    AddSelectList(GViewTypeList, 'Pulse Wave', VIEW_TYPE_PULSE_WAVE);
    AddSelect(GViewTypeSelect, 'View: Type', VIEW_TYPE_EQUALIZER_BARS, @GViewTypeList[0]);

    ClearSelectList;
    AddSelectList(GViewStyleList, 'Solid', VIEW_STYLE_SOLID);
    AddSelectList(GViewStyleList, 'Blocks', VIEW_STYLE_BLOCKS);
    AddSelect(GViewStyleSelect, 'View: Style', VIEW_STYLE_BLOCKS, @GViewStyleList[0]);

    AddTrack(GViewDensityTrack, 'View: Density', 32, 4, 128, 1);
    AddTrack(GViewSpacingTrack, 'View: Spacing', 2, 0, 32, 1);
    AddColor(GViewColorItem, 'View: Color', 245, 245, 240);

    ClearSelectList;
    AddSelectList(GViewColorList, 'Solid', VIEW_COLOR_SOLID);
    AddSelectList(GViewColorList, 'Rainbow', VIEW_COLOR_RAINBOW);
    AddSelect(GViewColorSelect, 'View: Color Style', VIEW_COLOR_SOLID, @GViewColorList[0]);

    AddTrack(GViewSmoothTrack, 'View: Smooth', 50, 0, 100, 1);
  end;

  Result := @GTable;
end;

procedure FinalizeViewPlugin;
begin
  FinalizeEqualizerBars;
end;

end.
