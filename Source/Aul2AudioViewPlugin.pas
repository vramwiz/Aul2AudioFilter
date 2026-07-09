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
  Aul2AudioViewRender,
  Aul2AudioViewRenderEqualizer;

const
  VIEW_TYPE_EQUALIZER_BARS = 0;
  VIEW_TYPE_WAVE_LINE = 1;
  VIEW_TYPE_PIXEL_WAVE = 2;
  VIEW_TYPE_FILLED_SPECTRUM = 3;
  VIEW_TYPE_PULSE_WAVE = 4;

var
  GViewTypeSelect: TFILTER_ITEM_SELECT;
  GViewTypeList  : array[0..5] of TFILTER_ITEM_SELECT_ITEM;

procedure InitializeViewPlugin;
begin
  InitializeEqualizerBars;
end;

function ViewProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  try
    RenderView(Video, GViewTypeSelect.Value);
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
  end;

  Result := @GTable;
end;

procedure FinalizeViewPlugin;
begin
  FinalizeEqualizerBars;
end;

end.
