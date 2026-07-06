unit Aul2AudioFilterPlugin;

// AviUtl2 に公開する音声フィルター本体と、サウンドエフェクターの GUI 項目を定義する。

interface

uses
  System.SysUtils,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

function GetFilterTable: PFILTER_PLUGIN_TABLE;

implementation

const
  DELAY_STEREO_NORMAL = 0;
  DELAY_STEREO_PING_PONG = 1;

type
  TDelayChannelState = record
    Buffer  : TArray<Single>; // 過去サンプルを保持するリングバッファ
    Position: Integer;        // 次に読み書きするリングバッファ位置
  end;

var
  GAudioGroup     : TFILTER_ITEM_GROUP;
  GVolumeTrack    : TFILTER_ITEM_TRACK;
  GDelayGroup     : TFILTER_ITEM_GROUP;
  GDelayUseCheck  : TFILTER_ITEM_CHECK;
  GDelayStereoMode : TFILTER_ITEM_SELECT;
  GDelayModeList   : array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  GDelayMsTrack   : TFILTER_ITEM_TRACK;
  GDryTrack       : TFILTER_ITEM_TRACK;
  GWetTrack       : TFILTER_ITEM_TRACK;
  GFeedbackTrack  : TFILTER_ITEM_TRACK;
  GDelayChannels  : array of TDelayChannelState;
  GDelaySamples   : Integer;
  GDelayMode      : Integer;
  GLastObjectID   : Int64;
  GLastEffectID   : Int64;
  GNextSampleIndex: Int64;

procedure ClearDelayState;
begin
  SetLength(GDelayChannels, 0);
  GDelaySamples := 0;
  GDelayMode := DELAY_STEREO_NORMAL;
  GLastObjectID := 0;
  GLastEffectID := 0;
  GNextSampleIndex := 0;
end;

procedure ResetDelayState(ChannelNum, DelaySamples: Integer);
var
  Channel: Integer;
begin
  SetLength(GDelayChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    SetLength(GDelayChannels[Channel].Buffer, DelaySamples);
    FillChar(GDelayChannels[Channel].Buffer[0], DelaySamples * SizeOf(Single), 0);
    GDelayChannels[Channel].Position := 0;
  end;

  GDelaySamples := DelaySamples;
end;

procedure EnsureDelayState(Audio: PFILTER_PROC_AUDIO; ChannelNum, DelaySamples, StereoMode: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  if (Length(GDelayChannels) <> ChannelNum) or
     (GDelaySamples <> DelaySamples) or
     (GDelayMode <> StereoMode) or
     (GLastObjectID <> ObjectInfo^.ID) or
     (GLastEffectID <> ObjectInfo^.EffectID) or
     (GNextSampleIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetDelayState(ChannelNum, DelaySamples);
    GDelayMode := StereoMode;
    GLastObjectID := ObjectInfo^.ID;
    GLastEffectID := ObjectInfo^.EffectID;
  end;
end;

procedure ApplyVolume(var Buffer: TArray<Single>; SampleNum: Integer; Volume: Single);
var
  I: Integer;
begin
  if Volume = 1.0 then
    Exit;

  for I := 0 to SampleNum - 1 do
    Buffer[I] := Buffer[I] * Volume;
end;

procedure ApplyDelay(var Buffer: TArray<Single>; Channel, SampleNum: Integer;
  Volume, Dry, Wet, Feedback: Single);
var
  I: Integer;
  InputSample: Single;
  DelayedSample: Single;
  State: ^TDelayChannelState;
begin
  State := @GDelayChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    InputSample := Buffer[I] * Volume;
    DelayedSample := State^.Buffer[State^.Position];
    State^.Buffer[State^.Position] := InputSample + (DelayedSample * Feedback);

    Buffer[I] := (InputSample * Dry) + (DelayedSample * Wet);

    Inc(State^.Position);
    if State^.Position >= GDelaySamples then
      State^.Position := 0;
  end;
end;

procedure ApplyPingPongDelay(var LeftBuffer, RightBuffer: TArray<Single>; SampleNum: Integer;
  Volume, Dry, Wet, Feedback: Single);
var
  I: Integer;
  InputL: Single;
  InputR: Single;
  DelayedL: Single;
  DelayedR: Single;
  LeftState: ^TDelayChannelState;
  RightState: ^TDelayChannelState;
begin
  LeftState := @GDelayChannels[0];
  RightState := @GDelayChannels[1];

  for I := 0 to SampleNum - 1 do
  begin
    InputL := LeftBuffer[I] * Volume;
    InputR := RightBuffer[I] * Volume;
    DelayedL := LeftState^.Buffer[LeftState^.Position];
    DelayedR := RightState^.Buffer[RightState^.Position];

    LeftState^.Buffer[LeftState^.Position] := InputR + (DelayedR * Feedback);
    RightState^.Buffer[RightState^.Position] := InputL + (DelayedL * Feedback);

    LeftBuffer[I] := (InputL * Dry) + (DelayedL * Wet);
    RightBuffer[I] := (InputR * Dry) + (DelayedR * Wet);

    Inc(LeftState^.Position);
    if LeftState^.Position >= GDelaySamples then
      LeftState^.Position := 0;

    Inc(RightState^.Position);
    if RightState^.Position >= GDelaySamples then
      RightState^.Position := 0;
  end;
end;

procedure ProcessNormalDelay(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer;
  Volume, Dry, Wet, Feedback: Single);
var
  Channel: Integer;
  Buffer: TArray<Single>;
begin
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyDelay(Buffer, Channel, SampleNum, Volume, Dry, Wet, Feedback);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;
end;

procedure ProcessPingPongDelay(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer;
  Volume, Dry, Wet, Feedback: Single);
var
  Channel: Integer;
  LeftBuffer: TArray<Single>;
  RightBuffer: TArray<Single>;
  Buffer: TArray<Single>;
begin
  if ChannelNum < 2 then
  begin
    ProcessNormalDelay(Audio, SampleNum, ChannelNum, Volume, Dry, Wet, Feedback);
    Exit;
  end;

  SetLength(LeftBuffer, SampleNum);
  SetLength(RightBuffer, SampleNum);
  Audio^.GetSampleData(@LeftBuffer[0], 0);
  Audio^.GetSampleData(@RightBuffer[0], 1);
  ApplyPingPongDelay(LeftBuffer, RightBuffer, SampleNum, Volume, Dry, Wet, Feedback);
  Audio^.SetSampleData(@LeftBuffer[0], 0);
  Audio^.SetSampleData(@RightBuffer[0], 1);

  SetLength(Buffer, SampleNum);
  for Channel := 2 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyDelay(Buffer, Channel, SampleNum, Volume, Dry, Wet, Feedback);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;
end;

function FilterProcAudio(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;
var
  SampleNum: Integer;
  ChannelNum: Integer;
  Channel: Integer;
  DelaySamples: Integer;
  Volume: Single;
  Dry: Single;
  Wet: Single;
  Feedback: Single;
  UseDelay: Boolean;
  StereoMode: Integer;
  Buffer: TArray<Single>;
begin
  Result := 1;

  if (Audio = nil) or (Audio^.Scene = nil) or (Audio^.Object_ = nil) then
    Exit;

  SampleNum := Audio^.Object_^.SampleNum;
  ChannelNum := Audio^.Object_^.ChannelNum;
  if (SampleNum <= 0) or (ChannelNum <= 0) then
    Exit;

  Volume := GVolumeTrack.Value;
  Dry := GDryTrack.Value;
  Wet := GWetTrack.Value;
  Feedback := GFeedbackTrack.Value;
  UseDelay := GDelayUseCheck.Value <> 0;
  StereoMode := GDelayStereoMode.Value;

  if UseDelay then
  begin
    DelaySamples := Round(Audio^.Scene^.SampleRate * GDelayMsTrack.Value / 1000.0);
    if DelaySamples < 1 then
      DelaySamples := 1;

    EnsureDelayState(Audio, ChannelNum, DelaySamples, StereoMode);
  end;

  if UseDelay and (StereoMode = DELAY_STEREO_PING_PONG) then
    ProcessPingPongDelay(Audio, SampleNum, ChannelNum, Volume, Dry, Wet, Feedback)
  else if UseDelay then
    ProcessNormalDelay(Audio, SampleNum, ChannelNum, Volume, Dry, Wet, Feedback)
  else
  begin
    ClearDelayState;
    SetLength(Buffer, SampleNum);
    for Channel := 0 to ChannelNum - 1 do
    begin
      Audio^.GetSampleData(@Buffer[0], Channel);
      ApplyVolume(Buffer, SampleNum, Volume);
      Audio^.SetSampleData(@Buffer[0], Channel);
    end;
  end;

  if UseDelay then
    GNextSampleIndex := Audio^.Object_^.SampleIndex + SampleNum
  else
    GNextSampleIndex := 0;
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

    AddGroup(GDelayGroup, 'Delay', 1);
    AddCheck(GDelayUseCheck, 'Delay: Use', 0);
    GDelayModeList[0].Name := 'Normal';
    GDelayModeList[0].Value := DELAY_STEREO_NORMAL;
    GDelayModeList[1].Name := 'Ping-Pong';
    GDelayModeList[1].Value := DELAY_STEREO_PING_PONG;
    GDelayModeList[2].Name := nil;
    GDelayModeList[2].Value := 0;
    AddSelect(GDelayStereoMode, 'Delay: Stereo Mode', DELAY_STEREO_NORMAL, @GDelayModeList[0]);
    AddTrack(GDelayMsTrack, 'Delay: Time(ms)', 250.0, 1.0, 1000.0, 1.0);
    AddTrack(GDryTrack, 'Delay: Dry', 1.0, 0.0, 2.0, 0.01);
    AddTrack(GWetTrack, 'Delay: Wet', 0.0, 0.0, 2.0, 0.01);
    AddTrack(GFeedbackTrack, 'Delay: Feedback', 0.0, 0.0, 0.95, 0.01);
  end;

  Result := @GTable;
end;

end.
