unit Aul2AudioFilterPluginCompressor;

// Compressor 系の GUI 項目、状態管理、音声処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddCompressorItems;
function ProcessCompressor(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetCompressorGuiParams(UseCompressor: Boolean; ThresholdDb, Ratio, AttackMs, ReleaseMs,
  MakeupDb, Mix: Double);

implementation

type
  TCompressorChannelState = record
    Envelope: Single; // 入力レベルを平滑化した検出値
  end;

  TCompressorContext = record
    ObjectID  : Int64;
    EffectID  : Int64;
    Channels  : array of TCompressorChannelState;
    SampleRate: Integer;
    NextIndex : Int64;
  end;
  PCompressorContext = ^TCompressorContext;

var
  GCompressorGroup       : TFILTER_ITEM_GROUP;
  GCompressorUseCheck    : TFILTER_ITEM_CHECK;
  GThresholdTrack        : TFILTER_ITEM_TRACK;
  GRatioTrack            : TFILTER_ITEM_TRACK;
  GAttackTrack           : TFILTER_ITEM_TRACK;
  GReleaseTrack          : TFILTER_ITEM_TRACK;
  GMakeupTrack           : TFILTER_ITEM_TRACK;
  GCompressorMixTrack    : TFILTER_ITEM_TRACK;
  GCompressorContexts    : array of TCompressorContext;
  GCompressorContextIndex: Integer;

procedure ClearCompressorState;
begin
  SetLength(GCompressorContexts, 0);
  GCompressorContextIndex := -1;
end;

function CurrentCompressorContext: PCompressorContext;
begin
  Result := nil;
  if (GCompressorContextIndex >= 0) and (GCompressorContextIndex < Length(GCompressorContexts)) then
    Result := @GCompressorContexts[GCompressorContextIndex];
end;

function FindCompressorContext(ObjectID, EffectID: Int64): Integer;
var
  I: Integer;
begin
  for I := 0 to High(GCompressorContexts) do
    if (GCompressorContexts[I].ObjectID = ObjectID) and
       (GCompressorContexts[I].EffectID = EffectID) then
      Exit(I);

  Result := Length(GCompressorContexts);
  SetLength(GCompressorContexts, Result + 1);
  GCompressorContexts[Result].ObjectID := ObjectID;
  GCompressorContexts[Result].EffectID := EffectID;
end;

procedure ResetCompressorState(var Context: TCompressorContext; ChannelNum, SampleRate: Integer);
var
  Channel: Integer;
begin
  SetLength(Context.Channels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
    Context.Channels[Channel].Envelope := 0.0;

  Context.SampleRate := SampleRate;
end;

procedure EnsureCompressorState(Audio: PFILTER_PROC_AUDIO; ChannelNum: Integer);
var
  ObjectInfo: POBJECT_INFO;
  Context: PCompressorContext;
begin
  ObjectInfo := Audio^.Object_;
  GCompressorContextIndex := FindCompressorContext(ObjectInfo^.ID, ObjectInfo^.EffectID);
  Context := CurrentCompressorContext;
  if Context = nil then
    Exit;

  // レベル検出の状態が別素材へ混ざらないよう、処理対象や連続位置が変わったら作り直す。
  if (Length(Context^.Channels) <> ChannelNum) or
     (Context^.SampleRate <> Audio^.Scene^.SampleRate) or
     (Context^.NextIndex <> ObjectInfo^.SampleIndex) then
    ResetCompressorState(Context^, ChannelNum, Audio^.Scene^.SampleRate);
end;

function ClampSingle(Value, MinValue, MaxValue: Single): Single;
begin
  Result := Value;
  if Result < MinValue then
    Result := MinValue
  else if Result > MaxValue then
    Result := MaxValue;
end;

function DbToLinear(ValueDb: Single): Single;
begin
  Result := Power(10.0, ValueDb / 20.0);
end;

function LinearToDb(Value: Single): Single;
begin
  if Value <= 0.000001 then
    Result := -120.0
  else
    Result := 20.0 * Log10(Value);
end;

function TimeCoeff(TimeMs: Single; SampleRate: Integer): Single;
begin
  TimeMs := ClampSingle(TimeMs, 0.1, 1000.0);
  Result := Exp(-1.0 / (SampleRate * TimeMs / 1000.0));
end;

procedure ApplyCompressor(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  ThresholdDb, Ratio, AttackMs, ReleaseMs, MakeupDb, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  Level: Single;
  LevelDb: Single;
  GainDb: Single;
  Gain: Single;
  AttackCoeff: Single;
  ReleaseCoeff: Single;
  MakeupGain: Single;
  State: ^TCompressorChannelState;
  Context: PCompressorContext;
begin
  Context := CurrentCompressorContext;
  if Context = nil then
    Exit;

  Ratio := ClampSingle(Ratio, 1.0, 20.0);
  Mix := ClampSingle(Mix, 0.0, 1.0);
  AttackCoeff := TimeCoeff(AttackMs, SampleRate);
  ReleaseCoeff := TimeCoeff(ReleaseMs, SampleRate);
  MakeupGain := DbToLinear(MakeupDb);
  State := @Context^.Channels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    Level := Abs(DrySample);

    if Level > State^.Envelope then
      State^.Envelope := (AttackCoeff * State^.Envelope) + ((1.0 - AttackCoeff) * Level)
    else
      State^.Envelope := (ReleaseCoeff * State^.Envelope) + ((1.0 - ReleaseCoeff) * Level);

    LevelDb := LinearToDb(State^.Envelope);
    if LevelDb > ThresholdDb then
      GainDb := ThresholdDb + ((LevelDb - ThresholdDb) / Ratio) - LevelDb
    else
      GainDb := 0.0;

    Gain := DbToLinear(GainDb) * MakeupGain;
    WetSample := DrySample * Gain;
    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);
  end;
end;

procedure AddCompressorItems;
begin
  AddGroup(GCompressorGroup, 'Compressor', 1);
  AddCheck(GCompressorUseCheck, 'Comp: Use', 0);
  AddTrack(GThresholdTrack, 'Comp: Threshold(dB)', -18.0, -60.0, 0.0, 0.1);
  AddTrack(GRatioTrack, 'Comp: Ratio', 4.0, 1.0, 20.0, 0.1);
  AddTrack(GAttackTrack, 'Comp: Attack(ms)', 10.0, 0.1, 200.0, 0.1);
  AddTrack(GReleaseTrack, 'Comp: Release(ms)', 120.0, 5.0, 1000.0, 1.0);
  AddTrack(GMakeupTrack, 'Comp: Makeup(dB)', 0.0, -24.0, 24.0, 0.1);
  AddTrack(GCompressorMixTrack, 'Comp: Mix', 1.0, 0.0, 1.0, 0.01);
end;

procedure SetCompressorGuiParams(UseCompressor: Boolean; ThresholdDb, Ratio, AttackMs, ReleaseMs,
  MakeupDb, Mix: Double);
begin
  GCompressorUseCheck.Value := Byte(UseCompressor);
  GThresholdTrack.Value := ThresholdDb;
  GRatioTrack.Value := Ratio;
  GAttackTrack.Value := AttackMs;
  GReleaseTrack.Value := ReleaseMs;
  GMakeupTrack.Value := MakeupDb;
  GCompressorMixTrack.Value := Mix;
  ClearCompressorState;
end;

function ProcessCompressor(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  ThresholdDb: Single;
  Ratio: Single;
  AttackMs: Single;
  ReleaseMs: Single;
  MakeupDb: Single;
  Mix: Single;
  Context: PCompressorContext;
begin
  Result := GCompressorUseCheck.Value <> 0;
  if not Result then
  begin
    ClearCompressorState;
    Exit;
  end;

  ThresholdDb := GThresholdTrack.Value;
  Ratio := GRatioTrack.Value;
  AttackMs := GAttackTrack.Value;
  ReleaseMs := GReleaseTrack.Value;
  MakeupDb := GMakeupTrack.Value;
  Mix := GCompressorMixTrack.Value;

  EnsureCompressorState(Audio, ChannelNum);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyCompressor(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate,
      ThresholdDb, Ratio, AttackMs, ReleaseMs, MakeupDb, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  Context := CurrentCompressorContext;
  if Context <> nil then
    Context^.NextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
