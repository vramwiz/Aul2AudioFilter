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
  TBiQuadCoeff = record
    B0: Single;
    B1: Single;
    B2: Single;
    A1: Single;
    A2: Single;
  end;

  TBiQuadState = record
    X1: Single;
    X2: Single;
    Y1: Single;
    Y2: Single;
  end;

  TEqChannelState = record
    LowCutHP : TBiQuadState; // Low Cut 用 2 次 high-pass 状態
    HighCutLP: TBiQuadState; // High Cut 用 2 次 low-pass 状態
  end;

  TEqContext = record
    ObjectID  : Int64;
    EffectID  : Int64;
    Channels  : array of TEqChannelState;
    SampleRate: Integer;
    Mode      : Integer;
    NextIndex : Int64;
  end;
  PEqContext = ^TEqContext;

var
  GEqGroup      : TFILTER_ITEM_GROUP;
  GEqUseCheck   : TFILTER_ITEM_CHECK;
  GEqModeSelect : TFILTER_ITEM_SELECT;
  GEqModeList   : array[0..3] of TFILTER_ITEM_SELECT_ITEM;
  GLowCutTrack  : TFILTER_ITEM_TRACK;
  GHighCutTrack : TFILTER_ITEM_TRACK;
  GEqMixTrack   : TFILTER_ITEM_TRACK;
  GEqContexts   : array of TEqContext;
  GEqContextIndex: Integer;

procedure ClearEqState;
begin
  SetLength(GEqContexts, 0);
  GEqContextIndex := -1;
end;

function CurrentEqContext: PEqContext;
begin
  Result := nil;
  if (GEqContextIndex >= 0) and (GEqContextIndex < Length(GEqContexts)) then
    Result := @GEqContexts[GEqContextIndex];
end;

function FindEqContext(ObjectID, EffectID: Int64): Integer;
var
  I: Integer;
begin
  for I := 0 to High(GEqContexts) do
    if (GEqContexts[I].ObjectID = ObjectID) and (GEqContexts[I].EffectID = EffectID) then
      Exit(I);

  Result := Length(GEqContexts);
  SetLength(GEqContexts, Result + 1);
  GEqContexts[Result].ObjectID := ObjectID;
  GEqContexts[Result].EffectID := EffectID;
  GEqContexts[Result].Mode := EQ_MODE_BAND_PASS;
end;

procedure ResetEqState(var Context: TEqContext; ChannelNum, SampleRate, Mode: Integer);
var
  Channel: Integer;
begin
  SetLength(Context.Channels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    FillChar(Context.Channels[Channel].LowCutHP, SizeOf(TBiQuadState), 0);
    FillChar(Context.Channels[Channel].HighCutLP, SizeOf(TBiQuadState), 0);
  end;

  Context.SampleRate := SampleRate;
  Context.Mode := Mode;
end;

procedure EnsureEqState(Audio: PFILTER_PROC_AUDIO; ChannelNum, Mode: Integer);
var
  ObjectInfo: POBJECT_INFO;
  Context: PEqContext;
begin
  ObjectInfo := Audio^.Object_;
  GEqContextIndex := FindEqContext(ObjectInfo^.ID, ObjectInfo^.EffectID);
  Context := CurrentEqContext;
  if Context = nil then
    Exit;

  // IIR の状態が別素材へ混ざらないよう、処理対象や連続位置が変わったら作り直す。
  if (Length(Context^.Channels) <> ChannelNum) or
     (Context^.SampleRate <> Audio^.Scene^.SampleRate) or
     (Context^.Mode <> Mode) or
     (Context^.NextIndex <> ObjectInfo^.SampleIndex) then
    ResetEqState(Context^, ChannelNum, Audio^.Scene^.SampleRate, Mode);
end;

function ClampSingle(Value, MinValue, MaxValue: Single): Single;
begin
  Result := Value;
  if Result < MinValue then
    Result := MinValue
  else if Result > MaxValue then
    Result := MaxValue;
end;

function ClampCutoff(CutoffHz: Single; SampleRate: Integer): Single;
var
  Nyquist: Single;
begin
  Nyquist := SampleRate * 0.5;
  Result := ClampSingle(CutoffHz, 20.0, Nyquist * 0.95);
end;

function MakeLowPassCoeff(CutoffHz: Single; SampleRate: Integer): TBiQuadCoeff;
var
  W0: Double;
  C: Double;
  S: Double;
  Alpha: Double;
  A0: Double;
begin
  CutoffHz := ClampCutoff(CutoffHz, SampleRate);
  W0 := 2.0 * Pi * CutoffHz / SampleRate;
  C := Cos(W0);
  S := Sin(W0);
  Alpha := S / Sqrt(2.0);
  A0 := 1.0 + Alpha;

  Result.B0 := ((1.0 - C) * 0.5) / A0;
  Result.B1 := (1.0 - C) / A0;
  Result.B2 := Result.B0;
  Result.A1 := (-2.0 * C) / A0;
  Result.A2 := (1.0 - Alpha) / A0;
end;

function MakeHighPassCoeff(CutoffHz: Single; SampleRate: Integer): TBiQuadCoeff;
var
  W0: Double;
  C: Double;
  S: Double;
  Alpha: Double;
  A0: Double;
begin
  CutoffHz := ClampCutoff(CutoffHz, SampleRate);
  W0 := 2.0 * Pi * CutoffHz / SampleRate;
  C := Cos(W0);
  S := Sin(W0);
  Alpha := S / Sqrt(2.0);
  A0 := 1.0 + Alpha;

  Result.B0 := ((1.0 + C) * 0.5) / A0;
  Result.B1 := -(1.0 + C) / A0;
  Result.B2 := Result.B0;
  Result.A1 := (-2.0 * C) / A0;
  Result.A2 := (1.0 - Alpha) / A0;
end;

function ApplyBiQuad(InputSample: Single; const Coeff: TBiQuadCoeff;
  var State: TBiQuadState): Single;
begin
  Result := (Coeff.B0 * InputSample) +
            (Coeff.B1 * State.X1) +
            (Coeff.B2 * State.X2) -
            (Coeff.A1 * State.Y1) -
            (Coeff.A2 * State.Y2);

  if IsNan(Result) or IsInfinite(Result) then
  begin
    FillChar(State, SizeOf(TBiQuadState), 0);
    Result := 0.0;
  end;

  State.X2 := State.X1;
  State.X1 := InputSample;
  State.Y2 := State.Y1;
  State.Y1 := Result;
end;

procedure ApplyEq(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate, Mode: Integer;
  LowCutHz, HighCutHz, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  LowCutCoeff: TBiQuadCoeff;
  HighCutCoeff: TBiQuadCoeff;
  State: ^TEqChannelState;
  Context: PEqContext;
begin
  Context := CurrentEqContext;
  if Context = nil then
    Exit;

  Mix := ClampSingle(Mix, 0.0, 1.0);
  if (Mode = EQ_MODE_BAND_PASS) and (HighCutHz <= LowCutHz) then
    HighCutHz := LowCutHz + 1.0;

  LowCutCoeff := MakeHighPassCoeff(LowCutHz, SampleRate);
  HighCutCoeff := MakeLowPassCoeff(HighCutHz, SampleRate);
  State := @Context^.Channels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];

    case Mode of
      EQ_MODE_LOW_CUT:
        WetSample := ApplyBiQuad(DrySample, LowCutCoeff, State^.LowCutHP);
      EQ_MODE_HIGH_CUT:
        WetSample := ApplyBiQuad(DrySample, HighCutCoeff, State^.HighCutLP);
    else
      WetSample := ApplyBiQuad(DrySample, LowCutCoeff, State^.LowCutHP);
      WetSample := ApplyBiQuad(WetSample, HighCutCoeff, State^.HighCutLP);
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
  Context: PEqContext;
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

  Context := CurrentEqContext;
  if Context <> nil then
    Context^.NextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
