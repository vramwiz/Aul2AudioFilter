unit Aul2AudioFilterPluginPitchStep;

// PitchStep 系の GUI 項目、状態管理、階段状ピッチ変化を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddPitchStepItems;
function ProcessPitchStep(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetPitchStepGuiParams(UsePitchStep: Boolean; StepSemi, RateHz, Mix: Double);

implementation

type
  TPitchStepChannelState = record
    Buffer  : TArray<Single>; // ピッチ段差用の履歴バッファ
    Position: Integer;        // 次に書き込む位置
    Phase   : Double;         // 二重ディレイの読み出し位相
  end;

var
  GPitchStepGroup     : TFILTER_ITEM_GROUP;
  GPitchStepUseCheck  : TFILTER_ITEM_CHECK;
  GPitchStepSemiTrack : TFILTER_ITEM_TRACK;
  GPitchStepRateTrack : TFILTER_ITEM_TRACK;
  GPitchStepMixTrack  : TFILTER_ITEM_TRACK;
  GPitchStepChannels  : array of TPitchStepChannelState; // チャンネル別の可変ディレイ状態
  GPitchStepSamples   : Integer;                         // 現在確保している履歴長
  GPitchStepObjectID  : Int64;                           // 状態を構築した対象オブジェクト
  GPitchStepEffectID  : Int64;                           // 状態を構築した対象エフェクト
  GPitchStepNextIndex : Int64;                           // 連続処理を判定する次サンプル位置

procedure ClearPitchStepState;
begin
  SetLength(GPitchStepChannels, 0);
  GPitchStepSamples := 0;
  GPitchStepObjectID := 0;
  GPitchStepEffectID := 0;
  GPitchStepNextIndex := 0;
end;

procedure ResetPitchStepState(ChannelNum, BufferSamples: Integer);
var
  Channel: Integer;
begin
  SetLength(GPitchStepChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    SetLength(GPitchStepChannels[Channel].Buffer, BufferSamples);
    FillChar(GPitchStepChannels[Channel].Buffer[0], BufferSamples * SizeOf(Single), 0);
    GPitchStepChannels[Channel].Position := 0;
    GPitchStepChannels[Channel].Phase := 0.0;
  end;

  GPitchStepSamples := BufferSamples;
end;

procedure EnsurePitchStepState(Audio: PFILTER_PROC_AUDIO; ChannelNum, BufferSamples: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  if (Length(GPitchStepChannels) <> ChannelNum) or
     (GPitchStepSamples <> BufferSamples) or
     (GPitchStepObjectID <> ObjectInfo^.ID) or
     (GPitchStepEffectID <> ObjectInfo^.EffectID) or
     (GPitchStepNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetPitchStepState(ChannelNum, BufferSamples);
    GPitchStepObjectID := ObjectInfo^.ID;
    GPitchStepEffectID := ObjectInfo^.EffectID;
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

function WrapPhase(Value: Double): Double;
begin
  Result := Value - Floor(Value);
end;

function ReadDelaySample(const State: TPitchStepChannelState; DelaySamples: Double): Single;
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

function CrossFadeGain(Phase: Double): Single;
begin
  Result := 0.5 - (0.5 * Cos(2.0 * Pi * Phase));
end;

function CurrentStepSemitone(BaseIndex: Int64; SampleRate: Integer; StepSemi, RateHz: Single): Single;
var
  StepIndex: Integer;
begin
  RateHz := ClampSingle(RateHz, 0.25, 20.0);
  StepIndex := Floor((BaseIndex / SampleRate) * RateHz);
  if (StepIndex and 1) = 0 then
    Result := StepSemi
  else
    Result := -StepSemi;
end;

procedure ApplyPitchStep(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  BaseIndex: Int64; StepSemi, RateHz, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  Semitone: Single;
  PitchRatio: Double;
  WindowSamples: Double;
  PhaseStep: Double;
  PhaseA: Double;
  PhaseB: Double;
  DelayA: Double;
  DelayB: Double;
  State: ^TPitchStepChannelState;
begin
  StepSemi := ClampSingle(StepSemi, 0.0, 12.0);
  Mix := ClampSingle(Mix, 0.0, 1.0);
  WindowSamples := SampleRate * 0.045;
  State := @GPitchStepChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    State^.Buffer[State^.Position] := DrySample;
    Semitone := CurrentStepSemitone(BaseIndex + I, SampleRate, StepSemi, RateHz);
    PitchRatio := Power(2.0, Semitone / 12.0);
    PhaseStep := Abs(PitchRatio - 1.0) / WindowSamples;

    PhaseA := State^.Phase;
    PhaseB := WrapPhase(State^.Phase + 0.5);
    if PitchRatio >= 1.0 then
    begin
      DelayA := WindowSamples * (1.0 - PhaseA);
      DelayB := WindowSamples * (1.0 - PhaseB);
    end
    else
    begin
      DelayA := WindowSamples * PhaseA;
      DelayB := WindowSamples * PhaseB;
    end;

    WetSample := (ReadDelaySample(State^, DelayA) * (1.0 - CrossFadeGain(PhaseA))) +
      (ReadDelaySample(State^, DelayB) * (1.0 - CrossFadeGain(PhaseB)));
    State^.Phase := WrapPhase(State^.Phase + PhaseStep);
    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);

    Inc(State^.Position);
    if State^.Position >= GPitchStepSamples then
      State^.Position := 0;
  end;
end;

procedure AddPitchStepItems;
begin
  AddGroup(GPitchStepGroup, 'PitchStep', 1);
  AddCheck(GPitchStepUseCheck, 'PitchStep: Use', 0);
  AddTrack(GPitchStepSemiTrack, 'PitchStep: Step(semitone)', 5.0, 0.0, 12.0, 0.1);
  AddTrack(GPitchStepRateTrack, 'PitchStep: Rate(Hz)', 4.0, 0.25, 20.0, 0.25);
  AddTrack(GPitchStepMixTrack, 'PitchStep: Mix', 0.8, 0.0, 1.0, 0.01);
end;

procedure SetPitchStepGuiParams(UsePitchStep: Boolean; StepSemi, RateHz, Mix: Double);
begin
  GPitchStepUseCheck.Value := Byte(UsePitchStep);
  GPitchStepSemiTrack.Value := StepSemi;
  GPitchStepRateTrack.Value := RateHz;
  GPitchStepMixTrack.Value := Mix;
  ClearPitchStepState;
end;

function ProcessPitchStep(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  BufferSamples: Integer;
begin
  Result := GPitchStepUseCheck.Value <> 0;
  if not Result then
  begin
    ClearPitchStepState;
    Exit;
  end;

  BufferSamples := Ceil(Audio^.Scene^.SampleRate * 0.045) + 4;
  EnsurePitchStepState(Audio, ChannelNum, BufferSamples);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyPitchStep(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, Audio^.Object_^.SampleIndex,
      GPitchStepSemiTrack.Value, GPitchStepRateTrack.Value, GPitchStepMixTrack.Value);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GPitchStepNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
