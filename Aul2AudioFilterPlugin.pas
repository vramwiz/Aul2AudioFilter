unit Aul2AudioFilterPlugin;

// AviUtl2 に公開する音声フィルターの入口と、各エフェクトユニットの接続を担当する。

interface

uses
  System.SysUtils,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui,
  Aul2AudioFilterPluginDelay,
  Aul2AudioFilterPluginChorus,
  Aul2AudioFilterPluginReverb;

function GetFilterTable: PFILTER_PLUGIN_TABLE;

implementation

var
  GAudioGroup : TFILTER_ITEM_GROUP; // Basic グループの GUI 項目
  GVolumeTrack: TFILTER_ITEM_TRACK; // 全エフェクト前段で使う基本音量

procedure ApplyVolume(var Buffer: TArray<Single>; SampleNum: Integer; Volume: Single);
var
  I: Integer;
begin
  if Volume = 1.0 then
    Exit;

  for I := 0 to SampleNum - 1 do
    Buffer[I] := Buffer[I] * Volume;
end;

procedure ProcessVolume(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer; Volume: Single);
var
  Channel: Integer;
  Buffer: TArray<Single>;
begin
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyVolume(Buffer, SampleNum, Volume);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;
end;

function FilterProcAudio(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;
var
  SampleNum: Integer;
  ChannelNum: Integer;
  Volume: Single;
begin
  Result := 1;

  // AviUtl2 から無効な処理対象が渡された場合は成功扱いで何もしない。
  if (Audio = nil) or (Audio^.Scene = nil) or (Audio^.Object_ = nil) then
    Exit;

  SampleNum := Audio^.Object_^.SampleNum;
  ChannelNum := Audio^.Object_^.ChannelNum;
  if (SampleNum <= 0) or (ChannelNum <= 0) then
    Exit;

  Volume := GVolumeTrack.Value;
  // Delay は Volume を内部で適用するため、有効時は通常 Volume 処理を省く。
  if not ProcessDelay(Audio, SampleNum, ChannelNum, Volume) then
    ProcessVolume(Audio, SampleNum, ChannelNum, Volume);

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

    AddGroup(GAudioGroup, 'Basic', 1);
    AddTrack(GVolumeTrack, 'Volume', 1.0, 0.0, 2.0, 0.01);
    AddDelayItems;
    AddChorusItems;
    AddReverbItems;
  end;

  Result := @GTable;
end;

end.
