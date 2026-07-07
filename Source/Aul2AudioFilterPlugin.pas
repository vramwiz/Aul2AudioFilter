unit Aul2AudioFilterPlugin;

// AviUtl2 に公開する音声フィルターの入口と、各エフェクトユニットの接続を担当する。

interface

uses
  System.SysUtils,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui,
  Aul2AudioFilterPluginPreset,
  Aul2AudioFilterPluginDelay,
  Aul2AudioFilterPluginEq,
  Aul2AudioFilterPluginCompressor,
  Aul2AudioFilterPluginVoiceDrive,
  Aul2AudioFilterPluginDistortion,
  Aul2AudioFilterPluginNoise,
  Aul2AudioFilterPluginBitCrusher,
  Aul2AudioFilterPluginTremble,
  Aul2AudioFilterPluginWobble,
  Aul2AudioFilterPluginPitch,
  Aul2AudioFilterPluginRingMod,
  Aul2AudioFilterPluginMuffle,
  Aul2AudioFilterPluginWhisper,
  Aul2AudioFilterPluginAutoGain,
  Aul2AudioFilterPluginNoiseGate,
  Aul2AudioFilterPluginGhost,
  Aul2AudioFilterPluginOutput,
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

  ProcessDelay(Audio, SampleNum, ChannelNum);
  ProcessEq(Audio, SampleNum, ChannelNum);
  ProcessCompressor(Audio, SampleNum, ChannelNum);
  ProcessVoiceDrive(Audio, SampleNum, ChannelNum);
  ProcessDistortion(Audio, SampleNum, ChannelNum);
  ProcessNoise(Audio, SampleNum, ChannelNum);
  ProcessBitCrusher(Audio, SampleNum, ChannelNum);
  ProcessTremble(Audio, SampleNum, ChannelNum);
  ProcessWobble(Audio, SampleNum, ChannelNum);
  ProcessPitch(Audio, SampleNum, ChannelNum);
  ProcessRingMod(Audio, SampleNum, ChannelNum);
  ProcessMuffle(Audio, SampleNum, ChannelNum);
  ProcessWhisper(Audio, SampleNum, ChannelNum);
  ProcessAutoGain(Audio, SampleNum, ChannelNum);
  ProcessNoiseGate(Audio, SampleNum, ChannelNum);
  ProcessGhost(Audio, SampleNum, ChannelNum);
  ProcessOutput(Audio, SampleNum, ChannelNum);
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

    AddPresetItems;
    AddDelayItems;
    AddEqItems;
    AddCompressorItems;
    AddVoiceDriveItems;
    AddDistortionItems;
    AddNoiseItems;
    AddBitCrusherItems;
    AddTrembleItems;
    AddWobbleItems;
    AddPitchItems;
    AddRingModItems;
    AddMuffleItems;
    AddWhisperItems;
    AddAutoGainItems;
    AddNoiseGateItems;
    AddGhostItems;
    AddOutputItems;
    AddLimiterItems;
    AddChorusItems;
    AddReverbItems;
  end;

  Result := @GTable;
end;

end.
