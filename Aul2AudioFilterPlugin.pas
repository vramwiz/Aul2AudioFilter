unit Aul2AudioFilterPlugin;

interface

uses
  System.SysUtils,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

function GetFilterTable: PFILTER_PLUGIN_TABLE;

implementation

var
  GAudioGroup: TFILTER_ITEM_GROUP;
  GVolumeTrack: TFILTER_ITEM_TRACK;

function FilterProcAudio(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;
var
  SampleNum: Integer;
  ChannelNum: Integer;
  Channel: Integer;
  I: Integer;
  Volume: Single;
  Buffer: TArray<Single>;
begin
  Result := 1;

  if (Audio = nil) or (Audio^.Object_ = nil) then
    Exit;

  SampleNum := Audio^.Object_^.SampleNum;
  ChannelNum := Audio^.Object_^.ChannelNum;
  if (SampleNum <= 0) or (ChannelNum <= 0) then
    Exit;

  Volume := GVolumeTrack.Value;
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);

    if Volume <> 1.0 then
      for I := 0 to SampleNum - 1 do
        Buffer[I] := Buffer[I] * Volume;

    Audio^.SetSampleData(@Buffer[0], Channel);
  end;
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

    AddGroup(GAudioGroup, 'Audio', 1);
    AddTrack(GVolumeTrack, 'Volume', 1.0, 0.0, 2.0, 0.01);
  end;

  Result := @GTable;
end;

end.
