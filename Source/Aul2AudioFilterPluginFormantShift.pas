unit Aul2AudioFilterPluginFormantShift;

// FormantShift 系の GUI 項目、状態管理、声色重心を動かす簡易処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddFormantShiftItems;
function ProcessFormantShift(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetFormantShiftGuiParams(UseFormantShift: Boolean; Shift, Amount, Mix: Double);

implementation

type
  TFormantShiftChannelState = record
    LowSample: Single; // 声色補正用の低域状態
  end;

var
  GFormantShiftGroup     : TFILTER_ITEM_GROUP;
  GFormantShiftUseCheck  : TFILTER_ITEM_CHECK;
  GFormantShiftTrack     : TFILTER_ITEM_TRACK;
  GFormantAmountTrack    : TFILTER_ITEM_TRACK;
  GFormantMixTrack       : TFILTER_ITEM_TRACK;
  GFormantShiftChannels  : array of TFormantShiftChannelState; // チャンネル別の低域状態
  GFormantShiftSampleRate: Integer;                            // 状態を構築したサンプルレート
  GFormantShiftObjectID  : Int64;                              // 状態を構築した対象オブジェクト
  GFormantShiftEffectID  : Int64;                              // 状態を構築した対象エフェクト
  GFormantShiftNextIndex : Int64;                              // 連続処理を判定する次のサンプル位置

procedure ClearFormantShiftState;
begin
  SetLength(GFormantShiftChannels, 0);
  GFormantShiftSampleRate := 0;
  GFormantShiftObjectID := 0;
  GFormantShiftEffectID := 0;
  GFormantShiftNextIndex := 0;
end;

procedure ResetFormantShiftState(ChannelNum, SampleRate: Integer);
var
  Channel: Integer;
begin
  SetLength(GFormantShiftChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
    GFormantShiftChannels[Channel].LowSample := 0.0;

  GFormantShiftSampleRate := SampleRate;
end;

procedure EnsureFormantShiftState(Audio: PFILTER_PROC_AUDIO; ChannelNum: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  // フィルター状態が別素材へ混ざらないよう、処理対象や連続位置が変わったら作り直す。
  if (Length(GFormantShiftChannels) <> ChannelNum) or
     (GFormantShiftSampleRate <> Audio^.Scene^.SampleRate) or
     (GFormantShiftObjectID <> ObjectInfo^.ID) or
     (GFormantShiftEffectID <> ObjectInfo^.EffectID) or
     (GFormantShiftNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetFormantShiftState(ChannelNum, Audio^.Scene^.SampleRate);
    GFormantShiftObjectID := ObjectInfo^.ID;
    GFormantShiftEffectID := ObjectInfo^.EffectID;
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

procedure ApplyFormantShift(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  Shift, Amount, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  LowPart: Single;
  HighPart: Single;
  LowGain: Single;
  HighGain: Single;
  Strength: Single;
  LowCoeff: Single;
  State: ^TFormantShiftChannelState;
begin
  Shift := ClampSingle(Shift, -12.0, 12.0);
  Amount := ClampSingle(Amount, 0.0, 1.0);
  Mix := ClampSingle(Mix, 0.0, 1.0);
  Strength := Abs(Shift) / 12.0 * Amount;
  LowCoeff := 1.0 - Exp(-2.0 * Pi * 950.0 / SampleRate);

  if Shift >= 0.0 then
  begin
    LowGain := 1.0 - (0.45 * Strength);
    HighGain := 1.0 + (0.75 * Strength);
  end
  else
  begin
    LowGain := 1.0 + (0.75 * Strength);
    HighGain := 1.0 - (0.45 * Strength);
  end;

  State := @GFormantShiftChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    State^.LowSample := State^.LowSample + ((DrySample - State^.LowSample) * LowCoeff);
    LowPart := State^.LowSample;
    HighPart := DrySample - LowPart;
    WetSample := (LowPart * LowGain) + (HighPart * HighGain);
    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);
  end;
end;

procedure AddFormantShiftItems;
begin
  AddGroup(GFormantShiftGroup, 'FormantShift', 1);
  AddCheck(GFormantShiftUseCheck, 'FormantShift: Use', 0);
  AddTrack(GFormantShiftTrack, 'FormantShift: Shift', 0.0, -12.0, 12.0, 0.1);
  AddTrack(GFormantAmountTrack, 'FormantShift: Amount', 0.7, 0.0, 1.0, 0.01);
  AddTrack(GFormantMixTrack, 'FormantShift: Mix', 1.0, 0.0, 1.0, 0.01);
end;

procedure SetFormantShiftGuiParams(UseFormantShift: Boolean; Shift, Amount, Mix: Double);
begin
  GFormantShiftUseCheck.Value := Byte(UseFormantShift);
  GFormantShiftTrack.Value := Shift;
  GFormantAmountTrack.Value := Amount;
  GFormantMixTrack.Value := Mix;
  ClearFormantShiftState;
end;

function ProcessFormantShift(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  Shift: Single;
  Amount: Single;
  Mix: Single;
begin
  Result := GFormantShiftUseCheck.Value <> 0;
  if not Result then
  begin
    ClearFormantShiftState;
    Exit;
  end;

  Shift := GFormantShiftTrack.Value;
  Amount := GFormantAmountTrack.Value;
  Mix := GFormantMixTrack.Value;

  EnsureFormantShiftState(Audio, ChannelNum);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyFormantShift(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, Shift, Amount, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GFormantShiftNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
