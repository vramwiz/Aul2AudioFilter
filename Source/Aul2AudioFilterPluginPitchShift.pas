unit Aul2AudioFilterPluginPitchShift;

// PitchShift 系の GUI 項目、状態管理、二重可変ディレイによる簡易ピッチ処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddPitchShiftItems;
function ProcessPitchShift(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetPitchShiftGuiParams(UsePitchShift: Boolean; Semitone, WindowMs, Mix: Double);

implementation

type
  TPitchShiftChannelState = record
    Buffer  : TArray<Single>; // ピッチ変更用の履歴バッファ
    Position: Integer;        // 次に書き込む位置
    Phase   : Double;         // 二重ディレイの読み出し位相
  end;

var
  GPitchShiftGroup      : TFILTER_ITEM_GROUP;
  GPitchShiftUseCheck   : TFILTER_ITEM_CHECK;
  GPitchShiftSemiTrack  : TFILTER_ITEM_TRACK;
  GPitchShiftWindowTrack: TFILTER_ITEM_TRACK;
  GPitchShiftMixTrack   : TFILTER_ITEM_TRACK;
  GPitchShiftChannels   : array of TPitchShiftChannelState; // チャンネル別の可変ディレイ状態
  GPitchShiftSamples    : Integer;                          // 現在確保している履歴長
  GPitchShiftObjectID   : Int64;                            // 状態を構築した対象オブジェクト
  GPitchShiftEffectID   : Int64;                            // 状態を構築した対象エフェクト
  GPitchShiftNextIndex  : Int64;                            // 連続処理を判定する次サンプル位置

procedure ClearPitchShiftState;
begin
  SetLength(GPitchShiftChannels, 0);
  GPitchShiftSamples := 0;
  GPitchShiftObjectID := 0;
  GPitchShiftEffectID := 0;
  GPitchShiftNextIndex := 0;
end;

procedure ResetPitchShiftState(ChannelNum, BufferSamples: Integer);
var
  Channel: Integer;
begin
  SetLength(GPitchShiftChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    SetLength(GPitchShiftChannels[Channel].Buffer, BufferSamples);
    FillChar(GPitchShiftChannels[Channel].Buffer[0], BufferSamples * SizeOf(Single), 0);
    GPitchShiftChannels[Channel].Position := 0;
    GPitchShiftChannels[Channel].Phase := 0.0;
  end;

  GPitchShiftSamples := BufferSamples;
end;

procedure EnsurePitchShiftState(Audio: PFILTER_PROC_AUDIO; ChannelNum, BufferSamples: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  // 可変ディレイは履歴と位相を持つため、不連続な呼び出しでは状態を破棄する。
  if (Length(GPitchShiftChannels) <> ChannelNum) or
     (GPitchShiftSamples <> BufferSamples) or
     (GPitchShiftObjectID <> ObjectInfo^.ID) or
     (GPitchShiftEffectID <> ObjectInfo^.EffectID) or
     (GPitchShiftNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetPitchShiftState(ChannelNum, BufferSamples);
    GPitchShiftObjectID := ObjectInfo^.ID;
    GPitchShiftEffectID := ObjectInfo^.EffectID;
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

function ReadDelaySample(const State: TPitchShiftChannelState; DelaySamples: Double): Single;
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

procedure ApplyPitchShift(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  Semitone, WindowMs, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  PitchRatio: Double;
  WindowSamples: Double;
  PhaseStep: Double;
  PhaseA: Double;
  PhaseB: Double;
  DelayA: Double;
  DelayB: Double;
  GainA: Single;
  GainB: Single;
  State: ^TPitchShiftChannelState;
begin
  Semitone := ClampSingle(Semitone, -12.0, 12.0);
  WindowMs := ClampSingle(WindowMs, 20.0, 120.0);
  Mix := ClampSingle(Mix, 0.0, 1.0);
  PitchRatio := Power(2.0, Semitone / 12.0);
  WindowSamples := SampleRate * WindowMs / 1000.0;
  if WindowSamples < 4.0 then
    WindowSamples := 4.0;

  PhaseStep := Abs(PitchRatio - 1.0) / WindowSamples;
  State := @GPitchShiftChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    State^.Buffer[State^.Position] := DrySample;

    if Abs(Semitone) < 0.001 then
      WetSample := DrySample
    else
    begin
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

      GainA := 1.0 - CrossFadeGain(PhaseA);
      GainB := 1.0 - CrossFadeGain(PhaseB);
      WetSample := (ReadDelaySample(State^, DelayA) * GainA) + (ReadDelaySample(State^, DelayB) * GainB);
      State^.Phase := WrapPhase(State^.Phase + PhaseStep);
    end;

    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);

    Inc(State^.Position);
    if State^.Position >= GPitchShiftSamples then
      State^.Position := 0;
  end;
end;

procedure AddPitchShiftItems;
begin
  AddGroup(GPitchShiftGroup, 'PitchShift', 1);
  AddCheck(GPitchShiftUseCheck, 'PitchShift: Use', 0);
  AddTrack(GPitchShiftSemiTrack, 'PitchShift: Semitone', 0.0, -12.0, 12.0, 0.1);
  AddTrack(GPitchShiftWindowTrack, 'PitchShift: Window(ms)', 60.0, 20.0, 120.0, 1.0);
  AddTrack(GPitchShiftMixTrack, 'PitchShift: Mix', 1.0, 0.0, 1.0, 0.01);
end;

procedure SetPitchShiftGuiParams(UsePitchShift: Boolean; Semitone, WindowMs, Mix: Double);
begin
  GPitchShiftUseCheck.Value := Byte(UsePitchShift);
  GPitchShiftSemiTrack.Value := Semitone;
  GPitchShiftWindowTrack.Value := WindowMs;
  GPitchShiftMixTrack.Value := Mix;
  ClearPitchShiftState;
end;

function ProcessPitchShift(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  BufferSamples: Integer;
  Buffer: TArray<Single>;
  Semitone: Single;
  WindowMs: Single;
  Mix: Single;
begin
  Result := GPitchShiftUseCheck.Value <> 0;
  if not Result then
  begin
    ClearPitchShiftState;
    Exit;
  end;

  Semitone := GPitchShiftSemiTrack.Value;
  WindowMs := GPitchShiftWindowTrack.Value;
  Mix := GPitchShiftMixTrack.Value;
  BufferSamples := Ceil(Audio^.Scene^.SampleRate * WindowMs / 1000.0) + 4;
  if BufferSamples < 4 then
    BufferSamples := 4;

  EnsurePitchShiftState(Audio, ChannelNum, BufferSamples);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyPitchShift(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, Semitone, WindowMs, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GPitchShiftNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
