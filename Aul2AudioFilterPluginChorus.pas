unit Aul2AudioFilterPluginChorus;

// Chorus 系の GUI 項目、状態、音声処理を担当する。

interface

uses
  System.SysUtils,
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddChorusItems;
function ProcessChorus(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;

implementation

const
  CHORUS_STEREO_NORMAL = 0;
  CHORUS_STEREO_WIDE = 1;

type
  TChorusChannelState = record
    Buffer  : TArray<Single>; // コーラス用の短い履歴バッファ
    Position: Integer;        // 次に書き込む位置
  end;

var
  GChorusGroup     : TFILTER_ITEM_GROUP;
  GChorusUseCheck  : TFILTER_ITEM_CHECK;
  GChorusStereoMode: TFILTER_ITEM_SELECT;
  GChorusModeList  : array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  GChorusDelayTrack: TFILTER_ITEM_TRACK;
  GChorusDepthTrack: TFILTER_ITEM_TRACK;
  GChorusRateTrack : TFILTER_ITEM_TRACK;
  GChorusMixTrack  : TFILTER_ITEM_TRACK;
  GChorusChannels  : array of TChorusChannelState;
  GChorusSamples   : Integer;
  GChorusObjectID  : Int64;
  GChorusEffectID  : Int64;
  GChorusNextIndex : Int64;

procedure ClearChorusState;
begin
  SetLength(GChorusChannels, 0);
  GChorusSamples := 0;
  GChorusObjectID := 0;
  GChorusEffectID := 0;
  GChorusNextIndex := 0;
end;

procedure ResetChorusState(ChannelNum, BufferSamples: Integer);
var
  Channel: Integer;
begin
  SetLength(GChorusChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    SetLength(GChorusChannels[Channel].Buffer, BufferSamples);
    FillChar(GChorusChannels[Channel].Buffer[0], BufferSamples * SizeOf(Single), 0);
    GChorusChannels[Channel].Position := 0;
  end;

  GChorusSamples := BufferSamples;
end;

procedure EnsureChorusState(Audio: PFILTER_PROC_AUDIO; ChannelNum, BufferSamples: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  if (Length(GChorusChannels) <> ChannelNum) or
     (GChorusSamples <> BufferSamples) or
     (GChorusObjectID <> ObjectInfo^.ID) or
     (GChorusEffectID <> ObjectInfo^.EffectID) or
     (GChorusNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetChorusState(ChannelNum, BufferSamples);
    GChorusObjectID := ObjectInfo^.ID;
    GChorusEffectID := ObjectInfo^.EffectID;
  end;
end;

function ReadChorusDelaySample(const State: TChorusChannelState; DelaySamples: Double): Single;
var
  ReadPos: Double;
  Index0: Integer;
  Index1: Integer;
  Frac: Double;
  BufferLen: Integer;
begin
  BufferLen := Length(State.Buffer);
  if BufferLen <= 0 then
    Exit(0.0);

  ReadPos := State.Position - DelaySamples;
  while ReadPos < 0 do
    ReadPos := ReadPos + BufferLen;
  while ReadPos >= BufferLen do
    ReadPos := ReadPos - BufferLen;

  Index0 := Floor(ReadPos);
  Index1 := Index0 + 1;
  if Index1 >= BufferLen then
    Index1 := 0;
  Frac := ReadPos - Index0;

  Result := State.Buffer[Index0] * (1.0 - Frac) + State.Buffer[Index1] * Frac;
end;

procedure ApplyChorus(var Buffer: TArray<Single>; Channel, SampleNum: Integer;
  SampleRate, SampleIndex: Int64; BaseDelayMs, DepthMs, RateHz, Mix: Single;
  StereoMode: Integer);
var
  I: Integer;
  InputSample: Single;
  DelayMs: Double;
  DelaySamples: Double;
  Phase: Double;
  DelayedSample: Single;
  State: ^TChorusChannelState;
begin
  State := @GChorusChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    InputSample := Buffer[I];
    Phase := 2.0 * Pi * RateHz * ((SampleIndex + I) / SampleRate);
    if (StereoMode = CHORUS_STEREO_WIDE) and (Channel = 1) then
      Phase := Phase + Pi;

    DelayMs := BaseDelayMs + (Sin(Phase) * DepthMs);
    if DelayMs < 0.0 then
      DelayMs := 0.0;

    DelaySamples := SampleRate * DelayMs / 1000.0;
    DelayedSample := ReadChorusDelaySample(State^, DelaySamples);
    State^.Buffer[State^.Position] := InputSample;

    Buffer[I] := (InputSample * (1.0 - Mix)) + (DelayedSample * Mix);

    Inc(State^.Position);
    if State^.Position >= GChorusSamples then
      State^.Position := 0;
  end;
end;

procedure AddChorusItems;
begin
  AddGroup(GChorusGroup, 'Chorus', 1);
  AddCheck(GChorusUseCheck, 'Chorus: Use', 0);
  GChorusModeList[0].Name := 'Normal';
  GChorusModeList[0].Value := CHORUS_STEREO_NORMAL;
  GChorusModeList[1].Name := 'Wide';
  GChorusModeList[1].Value := CHORUS_STEREO_WIDE;
  GChorusModeList[2].Name := nil;
  GChorusModeList[2].Value := 0;
  AddSelect(GChorusStereoMode, 'Chorus: Stereo Mode', CHORUS_STEREO_NORMAL, @GChorusModeList[0]);
  AddTrack(GChorusDelayTrack, 'Chorus: Delay(ms)', 15.0, 1.0, 50.0, 0.1);
  AddTrack(GChorusDepthTrack, 'Chorus: Depth(ms)', 5.0, 0.0, 20.0, 0.1);
  AddTrack(GChorusRateTrack, 'Chorus: Rate(Hz)', 0.5, 0.01, 10.0, 0.01);
  AddTrack(GChorusMixTrack, 'Chorus: Mix', 0.5, 0.0, 1.0, 0.01);
end;

function ProcessChorus(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  BufferSamples: Integer;
  Buffer: TArray<Single>;
  BaseDelayMs: Single;
  DepthMs: Single;
  RateHz: Single;
  Mix: Single;
  StereoMode: Integer;
begin
  Result := GChorusUseCheck.Value <> 0;
  if not Result then
  begin
    ClearChorusState;
    Exit;
  end;

  BaseDelayMs := GChorusDelayTrack.Value;
  DepthMs := GChorusDepthTrack.Value;
  RateHz := GChorusRateTrack.Value;
  Mix := GChorusMixTrack.Value;
  StereoMode := GChorusStereoMode.Value;

  BufferSamples := Ceil(Audio^.Scene^.SampleRate * (BaseDelayMs + DepthMs) / 1000.0) + 4;
  if BufferSamples < 4 then
    BufferSamples := 4;

  EnsureChorusState(Audio, ChannelNum, BufferSamples);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyChorus(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate,
      Audio^.Object_^.SampleIndex, BaseDelayMs, DepthMs, RateHz, Mix, StereoMode);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GChorusNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
