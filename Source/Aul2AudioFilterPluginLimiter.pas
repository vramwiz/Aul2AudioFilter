unit Aul2AudioFilterPluginLimiter;

// Limiter 系の GUI 項目、状態管理、音声処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddLimiterItems;
function ProcessLimiter(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetLimiterGuiParams(UseLimiter: Boolean; CeilingDb, ReleaseMs, Mix: Double);

implementation

type
  TLimiterChannelState = record
    Gain: Single; // 現在適用しているピーク抑制ゲイン
  end;

var
  GLimiterGroup      : TFILTER_ITEM_GROUP;
  GLimiterUseCheck   : TFILTER_ITEM_CHECK;
  GCeilingTrack      : TFILTER_ITEM_TRACK;
  GReleaseTrack      : TFILTER_ITEM_TRACK;
  GLimiterMixTrack   : TFILTER_ITEM_TRACK;
  GLimiterChannels   : array of TLimiterChannelState; // チャンネル別のゲイン状態
  GLimiterSampleRate : Integer;                       // 状態を構築したサンプルレート
  GLimiterObjectID   : Int64;                         // 状態を構築した対象オブジェクト
  GLimiterEffectID   : Int64;                         // 状態を構築した対象エフェクト
  GLimiterNextIndex  : Int64;                         // 連続処理を判定する次のサンプル位置

procedure ClearLimiterState;
begin
  SetLength(GLimiterChannels, 0);
  GLimiterSampleRate := 0;
  GLimiterObjectID := 0;
  GLimiterEffectID := 0;
  GLimiterNextIndex := 0;
end;

procedure ResetLimiterState(ChannelNum, SampleRate: Integer);
var
  Channel: Integer;
begin
  SetLength(GLimiterChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
    GLimiterChannels[Channel].Gain := 1.0;

  GLimiterSampleRate := SampleRate;
end;

procedure EnsureLimiterState(Audio: PFILTER_PROC_AUDIO; ChannelNum: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  // ゲイン状態が別素材へ混ざらないよう、処理対象や連続位置が変わったら作り直す。
  if (Length(GLimiterChannels) <> ChannelNum) or
     (GLimiterSampleRate <> Audio^.Scene^.SampleRate) or
     (GLimiterObjectID <> ObjectInfo^.ID) or
     (GLimiterEffectID <> ObjectInfo^.EffectID) or
     (GLimiterNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetLimiterState(ChannelNum, Audio^.Scene^.SampleRate);
    GLimiterObjectID := ObjectInfo^.ID;
    GLimiterEffectID := ObjectInfo^.EffectID;
  end;
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

function ReleaseCoeff(ReleaseMs: Single; SampleRate: Integer): Single;
begin
  ReleaseMs := ClampSingle(ReleaseMs, 1.0, 1000.0);
  Result := Exp(-1.0 / (SampleRate * ReleaseMs / 1000.0));
end;

procedure ApplyLimiter(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  CeilingDb, ReleaseMs, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  Level: Single;
  TargetGain: Single;
  Ceiling: Single;
  Release: Single;
  State: ^TLimiterChannelState;
begin
  Mix := ClampSingle(Mix, 0.0, 1.0);
  Ceiling := DbToLinear(CeilingDb);
  Release := ReleaseCoeff(ReleaseMs, SampleRate);
  State := @GLimiterChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    Level := Abs(DrySample);

    if Level > Ceiling then
      TargetGain := Ceiling / Level
    else
      TargetGain := 1.0;

    if TargetGain < State^.Gain then
      State^.Gain := TargetGain
    else
      State^.Gain := 1.0 - ((1.0 - State^.Gain) * Release);

    WetSample := DrySample * State^.Gain;
    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);
  end;
end;

procedure AddLimiterItems;
begin
  AddGroup(GLimiterGroup, 'Limiter', 1);
  AddCheck(GLimiterUseCheck, 'Lim: Use', 0);
  AddTrack(GCeilingTrack, 'Lim: Ceiling(dB)', -1.0, -24.0, 0.0, 0.1);
  AddTrack(GReleaseTrack, 'Lim: Release(ms)', 50.0, 1.0, 1000.0, 1.0);
  AddTrack(GLimiterMixTrack, 'Lim: Mix', 1.0, 0.0, 1.0, 0.01);
end;

procedure SetLimiterGuiParams(UseLimiter: Boolean; CeilingDb, ReleaseMs, Mix: Double);
begin
  GLimiterUseCheck.Value := Byte(UseLimiter);
  GCeilingTrack.Value := CeilingDb;
  GReleaseTrack.Value := ReleaseMs;
  GLimiterMixTrack.Value := Mix;
  ClearLimiterState;
end;

function ProcessLimiter(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  CeilingDb: Single;
  ReleaseMs: Single;
  Mix: Single;
begin
  Result := GLimiterUseCheck.Value <> 0;
  if not Result then
  begin
    ClearLimiterState;
    Exit;
  end;

  CeilingDb := GCeilingTrack.Value;
  ReleaseMs := GReleaseTrack.Value;
  Mix := GLimiterMixTrack.Value;

  EnsureLimiterState(Audio, ChannelNum);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyLimiter(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, CeilingDb, ReleaseMs, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GLimiterNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
