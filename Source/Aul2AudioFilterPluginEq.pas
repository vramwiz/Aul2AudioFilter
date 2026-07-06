unit Aul2AudioFilterPluginEq;

// EQ 系の GUI 項目、状態管理、音声処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddEqItems;
function ProcessEq(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetEqBandPassGuiParams(UseEq: Boolean; LowCutHz, HighCutHz, Mix: Double);

implementation

const
  EQ_MODE_LOW_CUT = 0;
  EQ_MODE_HIGH_CUT = 1;
  EQ_MODE_BAND_PASS = 2;

type
  TEqChannelState = record
    LowCutLP : Single; // Low Cut 用 high-pass を作るための low-pass 状態
    HighCutLP: Single; // High Cut 用 low-pass 状態
  end;

var
  GEqGroup      : TFILTER_ITEM_GROUP;
  GEqUseCheck   : TFILTER_ITEM_CHECK;
  GEqModeSelect : TFILTER_ITEM_SELECT;
  GEqModeList   : array[0..3] of TFILTER_ITEM_SELECT_ITEM;
  GLowCutTrack  : TFILTER_ITEM_TRACK;
  GHighCutTrack : TFILTER_ITEM_TRACK;
  GEqMixTrack   : TFILTER_ITEM_TRACK;
  GEqChannels   : array of TEqChannelState; // チャンネル別の EQ 状態
  GEqSampleRate : Integer;                  // 状態を構築したサンプルレート
  GEqMode       : Integer;                  // 状態を構築した EQ Mode
  GEqObjectID   : Int64;                    // 状態を構築した対象オブジェクト
  GEqEffectID   : Int64;                    // 状態を構築した対象エフェクト
  GEqNextIndex  : Int64;                    // 連続処理を判定する次のサンプル位置

procedure ClearEqState;
begin
  SetLength(GEqChannels, 0);
  GEqSampleRate := 0;
  GEqMode := EQ_MODE_BAND_PASS;
  GEqObjectID := 0;
  GEqEffectID := 0;
  GEqNextIndex := 0;
end;

procedure ResetEqState(ChannelNum, SampleRate, Mode: Integer);
var
  Channel: Integer;
begin
  SetLength(GEqChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    GEqChannels[Channel].LowCutLP := 0.0;
    GEqChannels[Channel].HighCutLP := 0.0;
  end;

  GEqSampleRate := SampleRate;
  GEqMode := Mode;
end;

procedure EnsureEqState(Audio: PFILTER_PROC_AUDIO; ChannelNum, Mode: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  // IIR の状態が別素材へ混ざらないよう、処理対象や連続位置が変わったら作り直す。
  if (Length(GEqChannels) <> ChannelNum) or
     (GEqSampleRate <> Audio^.Scene^.SampleRate) or
     (GEqMode <> Mode) or
     (GEqObjectID <> ObjectInfo^.ID) or
     (GEqEffectID <> ObjectInfo^.EffectID) or
     (GEqNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetEqState(ChannelNum, Audio^.Scene^.SampleRate, Mode);
    GEqObjectID := ObjectInfo^.ID;
    GEqEffectID := ObjectInfo^.EffectID;
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

function LowPassCoeff(CutoffHz: Single; SampleRate: Integer): Single;
var
  Cutoff: Single;
  Nyquist: Single;
begin
  Nyquist := SampleRate * 0.5;
  Cutoff := ClampSingle(CutoffHz, 1.0, Nyquist * 0.99);
  Result := 1.0 - Exp(-2.0 * Pi * Cutoff / SampleRate);
end;

function ApplyLowPass(InputSample: Single; Coeff: Single; var State: Single): Single;
begin
  State := State + (Coeff * (InputSample - State));
  Result := State;
end;

function ApplyHighPass(InputSample: Single; Coeff: Single; var State: Single): Single;
begin
  State := State + (Coeff * (InputSample - State));
  Result := InputSample - State;
end;

procedure ApplyEq(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate, Mode: Integer;
  LowCutHz, HighCutHz, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  LowCutCoeff: Single;
  HighCutCoeff: Single;
  State: ^TEqChannelState;
begin
  Mix := ClampSingle(Mix, 0.0, 1.0);
  if (Mode = EQ_MODE_BAND_PASS) and (HighCutHz <= LowCutHz) then
    HighCutHz := LowCutHz + 1.0;

  LowCutCoeff := LowPassCoeff(LowCutHz, SampleRate);
  HighCutCoeff := LowPassCoeff(HighCutHz, SampleRate);
  State := @GEqChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];

    case Mode of
      EQ_MODE_LOW_CUT:
        WetSample := ApplyHighPass(DrySample, LowCutCoeff, State^.LowCutLP);
      EQ_MODE_HIGH_CUT:
        WetSample := ApplyLowPass(DrySample, HighCutCoeff, State^.HighCutLP);
    else
      WetSample := ApplyHighPass(DrySample, LowCutCoeff, State^.LowCutLP);
      WetSample := ApplyLowPass(WetSample, HighCutCoeff, State^.HighCutLP);
    end;

    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);
  end;
end;

procedure AddEqItems;
begin
  AddGroup(GEqGroup, 'EQ', 1);
  AddCheck(GEqUseCheck, 'EQ: Use', 0);
  GEqModeList[0].Name := 'Low Cut';
  GEqModeList[0].Value := EQ_MODE_LOW_CUT;
  GEqModeList[1].Name := 'High Cut';
  GEqModeList[1].Value := EQ_MODE_HIGH_CUT;
  GEqModeList[2].Name := 'Band Pass';
  GEqModeList[2].Value := EQ_MODE_BAND_PASS;
  GEqModeList[3].Name := nil;
  GEqModeList[3].Value := 0;
  AddSelect(GEqModeSelect, 'EQ: Mode', EQ_MODE_BAND_PASS, @GEqModeList[0]);
  AddTrack(GLowCutTrack, 'EQ: LowCut(Hz)', 300.0, 20.0, 5000.0, 1.0);
  AddTrack(GHighCutTrack, 'EQ: HighCut(Hz)', 3400.0, 500.0, 20000.0, 1.0);
  AddTrack(GEqMixTrack, 'EQ: Mix', 1.0, 0.0, 1.0, 0.01);
end;

procedure SetEqBandPassGuiParams(UseEq: Boolean; LowCutHz, HighCutHz, Mix: Double);
begin
  GEqUseCheck.Value := Byte(UseEq);
  GEqModeSelect.Value := EQ_MODE_BAND_PASS;
  GLowCutTrack.Value := LowCutHz;
  GHighCutTrack.Value := HighCutHz;
  GEqMixTrack.Value := Mix;
  ClearEqState;
end;

function ProcessEq(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  Mode: Integer;
  LowCutHz: Single;
  HighCutHz: Single;
  Mix: Single;
begin
  Result := GEqUseCheck.Value <> 0;
  if not Result then
  begin
    ClearEqState;
    Exit;
  end;

  Mode := GEqModeSelect.Value;
  LowCutHz := GLowCutTrack.Value;
  HighCutHz := GHighCutTrack.Value;
  Mix := GEqMixTrack.Value;

  EnsureEqState(Audio, ChannelNum, Mode);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyEq(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, Mode, LowCutHz, HighCutHz, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GEqNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
