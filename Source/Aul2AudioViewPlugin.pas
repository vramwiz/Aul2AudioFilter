unit Aul2AudioViewPlugin;

// Aul2Audio View の GUI 項目登録、設定値の収集、映像処理コールバックを担当する。

interface

uses
  Aul2AudioFilterTypes;

// AviUtl2 へ登録する View フィルターテーブルを初回呼び出し時に構築して返す。
function GetViewFilterTable: PFILTER_PLUGIN_TABLE;
// View が共有する解析メモリと表示履歴を利用可能な状態にする。
procedure InitializeViewPlugin;
// View が保持する共有メモリと表示履歴を解放する。
procedure FinalizeViewPlugin;

implementation

uses
  System.SysUtils,
  Aul2AudioFilterGui,
  Aul2AudioViewParams,
  Aul2AudioViewRender,
  Aul2AudioViewRenderEqualizer,
  Aul2AudioViewVector,
  Aul2AudioViewWave,
  Aul2AudioControllerRequest;

var
  GViewTypeSelect  : TFILTER_ITEM_SELECT;
  GViewTypeList    : array[0..15] of TFILTER_ITEM_SELECT_ITEM;
  GViewStyleSelect : TFILTER_ITEM_SELECT;
  GViewStyleList   : array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  GViewDensityTrack: TFILTER_ITEM_TRACK;
  GViewSpacingTrack: TFILTER_ITEM_TRACK;
  GViewThicknessTrack: TFILTER_ITEM_TRACK;
  GViewBaseRadiusTrack: TFILTER_ITEM_TRACK;
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
  GViewXScaleTrack : TFILTER_ITEM_TRACK;
  GViewYScaleTrack : TFILTER_ITEM_TRACK;
  GViewZScaleTrack : TFILTER_ITEM_TRACK;
  GViewResetButton : TFILTER_ITEM_BUTTON;

function SetViewObjectItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  Item: PWideChar; const Value: UTF8String): Boolean;
begin
  Result := False;
  if (Edit = nil) or (Obj = nil) or not Assigned(Edit^.SetObjectItemValue) then
    Exit;

  Result := Edit^.SetObjectItemValue(Obj, 'Aul2Audio View', Item, PAnsiChar(Value)) <> 0;
end;

procedure ApplyViewDefaults(Edit: PEDIT_SECTION); cdecl;
var
  Obj: OBJECT_HANDLE;
begin
  // ボタンを押したフィルターだけを初期化し、ほかの Aul2Audio View の設定には触れない。
  if (Edit = nil) or not Assigned(Edit^.GetFocusObject) then
    Exit;

  Obj := Edit^.GetFocusObject;
  if Obj = nil then
    Exit;

  SetViewObjectItem(Edit, Obj, 'Source Layer', UTF8String('0'));
  SetViewObjectItem(Edit, Obj, 'Type', UTF8String('0'));
  SetViewObjectItem(Edit, Obj, 'Style', UTF8String('1'));
  SetViewObjectItem(Edit, Obj, 'Density', UTF8String('32'));
  SetViewObjectItem(Edit, Obj, 'Spacing', UTF8String('2'));
  SetViewObjectItem(Edit, Obj, 'Thickness', UTF8String('2'));
  SetViewObjectItem(Edit, Obj, 'Base Radius', UTF8String('24'));
  SetViewObjectItem(Edit, Obj, 'Smooth', UTF8String('50'));
  SetViewObjectItem(Edit, Obj, 'X Scale', UTF8String('100'));
  SetViewObjectItem(Edit, Obj, 'Y Scale', UTF8String('100'));
  SetViewObjectItem(Edit, Obj, 'Z Scale', UTF8String('100'));
  SetViewObjectItem(Edit, Obj, 'Spectrum Scale', UTF8String('0'));
  SetViewObjectItem(Edit, Obj, 'Low Hz', UTF8String('40'));
  SetViewObjectItem(Edit, Obj, 'High Hz', UTF8String('12000'));
  SetViewObjectItem(Edit, Obj, 'High Boost', UTF8String('0'));
end;

procedure InitializeViewPlugin;
begin
  // 状態を持つ描画系ユニットは DLL 終了時と対称になる順序で初期化する。
  InitializeEqualizerBars;
  InitializeViewWave;
  InitializeViewVector;
end;

function ViewProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  Settings: TAul2AudioViewSettings;
begin
  try
    AudioConsumerNotifyView;
    // GUI のグローバル項目をフレーム単位の値へ写し、描画側へ不変の設定として渡す。
    Settings.ViewType := GViewTypeSelect.Value;
    Settings.Style := GViewStyleSelect.Value;
    Settings.Density := Round(GViewDensityTrack.Value);
    Settings.Spacing := Round(GViewSpacingTrack.Value);
    Settings.Thickness := Round(GViewThicknessTrack.Value);
    Settings.BaseRadius := Round(GViewBaseRadiusTrack.Value);
    Settings.Smooth := Round(GViewSmoothTrack.Value);
    Settings.XScale := Round(GViewXScaleTrack.Value);
    Settings.YScale := Round(GViewYScaleTrack.Value);
    Settings.ZScale := Round(GViewZScaleTrack.Value);
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
    if not RenderView(Video, Settings) then
    begin
      // draw_poly はフレームバッファへ直接描くため、通常の画像出力を続けない。
      Result := 0;
      Exit;
    end;
  except
    // Delphi 例外を AviUtl2 のコールバック境界より外へ漏らさない。
    Result := 0;
    Exit;
  end;

  Result := 1;
end;

function GetViewFilterTable: PFILTER_PLUGIN_TABLE;
var
  Layer: Integer;
begin
  // GTable はプロセス中に一度だけ構築し、選択肢の文字列領域をグローバルで保持する。
  if GTable.Name = nil then
  begin
    SetupPluginTable(
      FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,       // モード指定
      'Aul2Audio View',                              // 名称
      'Effects',                                     // グループ
      'オーディオエフェクター',                      // 詳細
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
    AddButton(GViewResetButton, #$521D#$671F#$5024#$306B#$623B#$3059, ApplyViewDefaults);

    ClearSelectList;
    AddSelectList(GViewTypeList, 'Equalizer Bars', VIEW_TYPE_EQUALIZER_BARS);
    AddSelectList(GViewTypeList, 'Wave Line', VIEW_TYPE_WAVE_LINE);
    AddSelectList(GViewTypeList, 'Pixel Wave', VIEW_TYPE_PIXEL_WAVE);
    AddSelectList(GViewTypeList, 'Filled Spectrum', VIEW_TYPE_FILLED_SPECTRUM);
    AddSelectList(GViewTypeList, 'Pulse Wave', VIEW_TYPE_PULSE_WAVE);
    AddSelectList(GViewTypeList, 'Circular Spectrum', VIEW_TYPE_CIRCULAR_SPECTRUM);
    AddSelectList(GViewTypeList, 'Mirror Bars', VIEW_TYPE_MIRROR_BARS);
    AddSelectList(GViewTypeList, 'Vectorscope', VIEW_TYPE_VECTORSCOPE);
    AddSelectList(GViewTypeList, 'Comms Scope', VIEW_TYPE_COMMS_SCOPE);
    AddSelectList(GViewTypeList, 'Circular Bars (3D)', VIEW_TYPE_CIRCULAR_BARS_3D);
    AddSelectList(GViewTypeList, 'Radial Waveform (3D)', VIEW_TYPE_RADIAL_WAVEFORM_3D);
    AddSelectList(GViewTypeList, 'Spectrum Landscape (3D)', VIEW_TYPE_SPECTRUM_LANDSCAPE_3D);
    AddSelectList(GViewTypeList, 'Waveform Tunnel (3D)', VIEW_TYPE_WAVEFORM_TUNNEL_3D);
    AddSelectList(GViewTypeList, 'Spectrum Waterfall (3D)', VIEW_TYPE_SPECTRUM_WATERFALL_3D);
    AddSelectList(GViewTypeList, 'Vectorscope Trail (3D)', VIEW_TYPE_VECTORSCOPE_TRAIL_3D);
    AddSelect(GViewTypeSelect, 'Type', VIEW_TYPE_EQUALIZER_BARS, @GViewTypeList[0]);

    ClearSelectList;
    AddSelectList(GViewStyleList, 'Solid', VIEW_STYLE_SOLID);
    AddSelectList(GViewStyleList, 'Blocks', VIEW_STYLE_BLOCKS);
    AddSelect(GViewStyleSelect, 'Style', VIEW_STYLE_BLOCKS, @GViewStyleList[0]);

    AddTrack(GViewDensityTrack, 'Density', 32, 4, 128, 1);
    AddTrack(GViewSpacingTrack, 'Spacing', 2, 0, 32, 1);
    AddTrack(GViewThicknessTrack, 'Thickness', 2, 1, 32, 1);
    AddTrack(GViewBaseRadiusTrack, 'Base Radius', 24, 0, 100, 1);
    AddTrack(GViewSmoothTrack, 'Smooth', 50, 0, 100, 1);
    AddTrack(GViewXScaleTrack, 'X Scale', 100, 10, 500, 1);
    AddTrack(GViewYScaleTrack, 'Y Scale', 100, 10, 500, 1);
    AddTrack(GViewZScaleTrack, 'Z Scale', 100, 10, 500, 1);

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
  // 共有メモリや表示履歴を初期化時と逆順に解放する。
  FinalizeViewVector;
  FinalizeViewWave;
  FinalizeEqualizerBars;
end;

end.
