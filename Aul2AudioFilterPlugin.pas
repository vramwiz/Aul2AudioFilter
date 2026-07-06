unit Aul2AudioFilterPlugin;

// AviUtl2 に公開する音声フィルターの入口と、各エフェクトユニットの接続を担当する。

interface

uses
  System.SysUtils,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui,
  Aul2AudioFilterPluginSoundStyle,
  Aul2AudioFilterPluginDelay,
  Aul2AudioFilterPluginEq,
  Aul2AudioFilterPluginCompressor,
  Aul2AudioFilterPluginDistortion,
  Aul2AudioFilterPluginNoise,
  Aul2AudioFilterPluginBitCrusher,
  Aul2AudioFilterPluginLimiter,
  Aul2AudioFilterPluginChorus,
  Aul2AudioFilterPluginReverb;

function GetFilterTable: PFILTER_PLUGIN_TABLE;

implementation

function FilterProcAudio(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;
var
  SampleNum: Integer;
  ChannelNum: Integer;
begin
  Result := 1;

  // AviUtl2 から無効な処理対象が渡された場合は成功扱いで何もしない。
  if (Audio = nil) or (Audio^.Scene = nil) or (Audio^.Object_ = nil) then
    Exit;

  SampleNum := Audio^.Object_^.SampleNum;
  ChannelNum := Audio^.Object_^.ChannelNum;
  if (SampleNum <= 0) or (ChannelNum <= 0) then
    Exit;

  ProcessSoundStyle(Audio, SampleNum, ChannelNum);
  ProcessDelay(Audio, SampleNum, ChannelNum);
  ProcessEq(Audio, SampleNum, ChannelNum);
  ProcessCompressor(Audio, SampleNum, ChannelNum);
  ProcessDistortion(Audio, SampleNum, ChannelNum);
  ProcessNoise(Audio, SampleNum, ChannelNum);
  ProcessBitCrusher(Audio, SampleNum, ChannelNum);
  ProcessLimiter(Audio, SampleNum, ChannelNum);
  ProcessChorus(Audio, SampleNum, ChannelNum);
  ProcessReverb(Audio, SampleNum, ChannelNum);
end;

function GetFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if GTable.Name = nil then
  begin
    SetupPluginTable(
      FILTER_FLAG_AUDIO or FILTER_FLAG_FILTER,       // モード指定
      'サウンドエフェクター',                        // 名称
      '音声効果',                                    // グループ
      'Aul2AudioFilter for AviUtl ExEdit2',          // 詳細
      nil,
      FilterProcAudio
    );

    AddSoundStyleItems;
    AddDelayItems;
    AddEqItems;
    AddCompressorItems;
    AddDistortionItems;
    AddNoiseItems;
    AddBitCrusherItems;
    AddLimiterItems;
    AddChorusItems;
    AddReverbItems;
  end;

  Result := @GTable;
end;

end.
