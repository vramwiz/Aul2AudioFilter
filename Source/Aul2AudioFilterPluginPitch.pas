unit Aul2AudioFilterPluginPitch;

// Pitch 系の GUI 項目を1つにまとめ、ピッチ変更、声色補正、段階ピッチを選択処理する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddPitchItems;
function ProcessPitch(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetPitchGuiParams(UsePitch: Boolean; Mode: Integer; Semitone, WindowMs,
  Formant, Amount, StepSemi, RateHz, Mix: Double);

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Aul2AudioMonitorShared,
  Aul2AudioPitchSpectrumShared;

const
  PITCH_MODE_NATURAL      = 0;
  PITCH_MODE_PITCH_ONLY   = 1;
  PITCH_MODE_FORMANT_ONLY = 2;
  PITCH_MODE_STEP         = 3;

type
  TPitchShiftChannelState = record
    Buffer  : TArray<Single>;
    Position: Integer;
    Phase   : Double;
  end;

  TFormantChannelState = record
    LowSample: Single;
  end;

  TPitchStepChannelState = record
    Buffer  : TArray<Single>;
    Position: Integer;
    Phase   : Double;
  end;

var
  GPitchGroup       : TFILTER_ITEM_GROUP;
  GPitchUseCheck    : TFILTER_ITEM_CHECK;
  GPitchModeSelect  : TFILTER_ITEM_SELECT;
  GPitchModeList    : array[0..4] of TFILTER_ITEM_SELECT_ITEM;
  GPitchSemiTrack   : TFILTER_ITEM_TRACK;
  GPitchWindowTrack : TFILTER_ITEM_TRACK;
  GPitchFormantTrack: TFILTER_ITEM_TRACK;
  GPitchAmountTrack : TFILTER_ITEM_TRACK;
  GPitchStepTrack   : TFILTER_ITEM_TRACK;
  GPitchRateTrack   : TFILTER_ITEM_TRACK;
  GPitchMixTrack    : TFILTER_ITEM_TRACK;

  GPitchShiftChannels  : array of TPitchShiftChannelState;
  GPitchShiftSamples   : Integer;
  GPitchShiftObjectID  : Int64;
  GPitchShiftEffectID  : Int64;
  GPitchShiftNextIndex : Int64;

  GFormantChannels     : array of TFormantChannelState;
  GFormantSampleRate   : Integer;
  GFormantObjectID     : Int64;
  GFormantEffectID     : Int64;
  GFormantNextIndex    : Int64;

  GPitchStepChannels   : array of TPitchStepChannelState;
  GPitchStepSamples    : Integer;
  GPitchStepObjectID   : Int64;
  GPitchStepEffectID   : Int64;
  GPitchStepNextIndex  : Int64;

  GPitchSpectrumMemory: TAul2AudioPitchSpectrumSharedMemory;
  GPitchSpectrumCosTable: TArray<Double>;
  GPitchSpectrumSinTable: TArray<Double>;
  GPitchSpectrumSampleRate: Integer;
  GPitchSpectrumTableSize: Integer;

function GetPitchSpectrumMemory: TAul2AudioPitchSpectrumSharedMemory;
begin
  if GPitchSpectrumMemory = nil then
    GPitchSpectrumMemory := TAul2AudioPitchSpectrumSharedMemory.Create;
  Result := GPitchSpectrumMemory;
end;

procedure EnsurePitchSpectrumTable(SampleRate, TableSize: Integer);
var
  Angle: Double;
  Band: Integer;
  Frequency: Double;
  FrequencyMax: Double;
  Offset: Integer;
  Sample: Integer;
begin
  if (SampleRate = GPitchSpectrumSampleRate) and
     (TableSize = GPitchSpectrumTableSize) and
     (Length(GPitchSpectrumCosTable) =
      AUDIO_PITCH_SPECTRUM_BAND_COUNT * TableSize) then
    Exit;
  GPitchSpectrumSampleRate := SampleRate;
  GPitchSpectrumTableSize := TableSize;
  SetLength(GPitchSpectrumCosTable,
    AUDIO_PITCH_SPECTRUM_BAND_COUNT * TableSize);
  SetLength(GPitchSpectrumSinTable,
    AUDIO_PITCH_SPECTRUM_BAND_COUNT * TableSize);
  FrequencyMax := Min(20000.0, SampleRate * 0.5);
  for Band := 0 to AUDIO_PITCH_SPECTRUM_BAND_LAST do
  begin
    Frequency := 20.0 * Power(FrequencyMax / 20.0,
      (Band + 0.5) / AUDIO_PITCH_SPECTRUM_BAND_COUNT);
    for Sample := 0 to TableSize - 1 do
    begin
      Offset := Band * TableSize + Sample;
      Angle := 2.0 * Pi * Frequency * Sample / SampleRate;
      GPitchSpectrumCosTable[Offset] := Cos(Angle);
      GPitchSpectrumSinTable[Offset] := Sin(Angle);
    end;
  end;
end;

procedure CapturePitchSpectrum(Audio: PFILTER_PROC_AUDIO; SampleNum,
  ChannelNum: Integer; var Spectrum: TAudioPitchSpectrumData);
const
  PITCH_SPECTRUM_SAMPLE_COUNT = 2048;
  PITCH_SPECTRUM_DB_FLOOR = -80.0;
var
  Band: Integer;
  Db: Double;
  Im: Double;
  LeftBuffer: TArray<Single>;
  Magnitude: Double;
  Mixed: Double;
  Offset: Integer;
  Re: Double;
  RightBuffer: TArray<Single>;
  Sample: Integer;
  WindowValue: Double;
  WorkSize: Integer;
begin
  FillChar(Spectrum, SizeOf(Spectrum), 0);
  if (Audio = nil) or (Audio^.Scene = nil) or (SampleNum <= 0) then
    Exit;
  WorkSize := Min(PITCH_SPECTRUM_SAMPLE_COUNT, SampleNum);
  if WorkSize <= 0 then
    Exit;
  SetLength(LeftBuffer, SampleNum);
  Audio^.GetSampleData(@LeftBuffer[0], 0);
  if ChannelNum > 1 then
  begin
    SetLength(RightBuffer, SampleNum);
    Audio^.GetSampleData(@RightBuffer[0], 1);
  end;
  EnsurePitchSpectrumTable(Audio^.Scene^.SampleRate, WorkSize);
  for Band := 0 to AUDIO_PITCH_SPECTRUM_BAND_LAST do
  begin
    Re := 0;
    Im := 0;
    for Sample := 0 to WorkSize - 1 do
    begin
      Mixed := LeftBuffer[Sample];
      if Length(RightBuffer) > Sample then
        Mixed := (Mixed + RightBuffer[Sample]) * 0.5;
      if WorkSize > 1 then
        WindowValue := 0.5 -
          (0.5 * Cos(2.0 * Pi * Sample / (WorkSize - 1)))
      else
        WindowValue := 1.0;
      Offset := Band * WorkSize + Sample;
      Re := Re + Mixed * WindowValue * GPitchSpectrumCosTable[Offset];
      Im := Im - Mixed * WindowValue * GPitchSpectrumSinTable[Offset];
    end;
    Magnitude := Sqrt(Sqr(Re) + Sqr(Im)) / Max(1.0, WorkSize * 0.5);
    Db := 20.0 * Log10(Max(0.000001, Magnitude));
    Spectrum[Band] := EnsureRange(
      (Db - PITCH_SPECTRUM_DB_FLOOR) / -PITCH_SPECTRUM_DB_FLOOR, 0.0, 1.0);
  end;
end;

procedure PublishPitchSpectrum(Audio: PFILTER_PROC_AUDIO;
  const InputBands, OutputBands: TAudioPitchSpectrumData);
var
  Layer: Integer;
  Memory: TAul2AudioPitchSpectrumSharedMemory;
  State: PAul2AudioPitchSpectrumState;
begin
  if (Audio = nil) or (Audio^.Scene = nil) or (Audio^.Object_ = nil) then
    Exit;
  Layer := Audio^.Object_^.Layer;
  if (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;
  Memory := GetPitchSpectrumMemory;
  State := Memory.GetStateForLayer(Layer);
  if State = nil then
    Exit;
  State^.Magic := AUDIO_PITCH_SPECTRUM_SHARED_MAGIC;
  State^.Version := AUDIO_PITCH_SPECTRUM_SHARED_VERSION;
  State^.UpdateTick := GetTickCount64;
  State^.SourceLayer := Layer;
  State^.SourceFrame := Audio^.Object_^.Frame;
  State^.SourceFrameS := Audio^.Object_^.FrameS;
  State^.SourceFrameE := Audio^.Object_^.FrameE;
  State^.SampleRate := Audio^.Scene^.SampleRate;
  State^.BandCount := AUDIO_PITCH_SPECTRUM_BAND_COUNT;
  State^.MinHz := 20;
  State^.MaxHz := Min(20000, Audio^.Scene^.SampleRate * 0.5);
  State^.InputBands := InputBands;
  State^.OutputBands := OutputBands;
  Inc(State^.Generation);
  Memory.Root^.LastLayer := Layer;
  Inc(Memory.Root^.Generation);
end;

procedure ClearPitchShiftState;
begin
  SetLength(GPitchShiftChannels, 0);
  GPitchShiftSamples := 0;
  GPitchShiftObjectID := 0;
  GPitchShiftEffectID := 0;
  GPitchShiftNextIndex := 0;
end;

procedure ClearFormantState;
begin
  SetLength(GFormantChannels, 0);
  GFormantSampleRate := 0;
  GFormantObjectID := 0;
  GFormantEffectID := 0;
  GFormantNextIndex := 0;
end;

procedure ClearPitchStepState;
begin
  SetLength(GPitchStepChannels, 0);
  GPitchStepSamples := 0;
  GPitchStepObjectID := 0;
  GPitchStepEffectID := 0;
  GPitchStepNextIndex := 0;
end;

procedure ClearPitchState;
begin
  ClearPitchShiftState;
  ClearFormantState;
  ClearPitchStepState;
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

function CrossFadeGain(Phase: Double): Single;
begin
  Result := 0.5 - (0.5 * Cos(2.0 * Pi * Phase));
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

function ReadPitchShiftDelaySample(const State: TPitchShiftChannelState; DelaySamples: Double): Single;
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
      WetSample := (ReadPitchShiftDelaySample(State^, DelayA) * GainA) +
        (ReadPitchShiftDelaySample(State^, DelayB) * GainB);
      State^.Phase := WrapPhase(State^.Phase + PhaseStep);
    end;

    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);

    Inc(State^.Position);
    if State^.Position >= GPitchShiftSamples then
      State^.Position := 0;
  end;
end;

procedure ResetFormantState(ChannelNum, SampleRate: Integer);
var
  Channel: Integer;
begin
  SetLength(GFormantChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
    GFormantChannels[Channel].LowSample := 0.0;

  GFormantSampleRate := SampleRate;
end;

procedure EnsureFormantState(Audio: PFILTER_PROC_AUDIO; ChannelNum: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  if (Length(GFormantChannels) <> ChannelNum) or
     (GFormantSampleRate <> Audio^.Scene^.SampleRate) or
     (GFormantObjectID <> ObjectInfo^.ID) or
     (GFormantEffectID <> ObjectInfo^.EffectID) or
     (GFormantNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetFormantState(ChannelNum, Audio^.Scene^.SampleRate);
    GFormantObjectID := ObjectInfo^.ID;
    GFormantEffectID := ObjectInfo^.EffectID;
  end;
end;

procedure ApplyFormant(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
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
  State: ^TFormantChannelState;
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

  State := @GFormantChannels[Channel];

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

function ReadPitchStepDelaySample(const State: TPitchStepChannelState; DelaySamples: Double): Single;
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

    WetSample := (ReadPitchStepDelaySample(State^, DelayA) * (1.0 - CrossFadeGain(PhaseA))) +
      (ReadPitchStepDelaySample(State^, DelayB) * (1.0 - CrossFadeGain(PhaseB)));
    State^.Phase := WrapPhase(State^.Phase + PhaseStep);
    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);

    Inc(State^.Position);
    if State^.Position >= GPitchStepSamples then
      State^.Position := 0;
  end;
end;

procedure AddPitchMode(Index: Integer; Name: PWideChar; Value: Integer);
begin
  GPitchModeList[Index].Name := Name;
  GPitchModeList[Index].Value := Value;
end;

procedure AddPitchItems;
begin
  AddPitchMode(0, 'Natural', PITCH_MODE_NATURAL);
  AddPitchMode(1, 'Pitch Only', PITCH_MODE_PITCH_ONLY);
  AddPitchMode(2, 'Formant Only', PITCH_MODE_FORMANT_ONLY);
  AddPitchMode(3, 'Step', PITCH_MODE_STEP);
  AddPitchMode(4, nil, 0);

  AddGroup(GPitchGroup, 'Pitch', 1);
  AddCheck(GPitchUseCheck, 'Pitch: Use', 0);
  AddSelect(GPitchModeSelect, 'Pitch: Mode', PITCH_MODE_NATURAL, @GPitchModeList[0]);
  AddTrack(GPitchSemiTrack, 'Pitch: Semitone', 0.0, -12.0, 12.0, 0.1);
  AddTrack(GPitchWindowTrack, 'Pitch: Window(ms)', 60.0, 20.0, 120.0, 1.0);
  AddTrack(GPitchFormantTrack, 'Pitch: Formant', 0.0, -12.0, 12.0, 0.1);
  AddTrack(GPitchAmountTrack, 'Pitch: Amount', 0.7, 0.0, 1.0, 0.01);
  AddTrack(GPitchStepTrack, 'Pitch: Step(semi)', 5.0, 0.0, 12.0, 0.1);
  AddTrack(GPitchRateTrack, 'Pitch: Rate(Hz)', 4.0, 0.25, 20.0, 0.25);
  AddTrack(GPitchMixTrack, 'Pitch: Mix', 1.0, 0.0, 1.0, 0.01);
end;

procedure SetPitchGuiParams(UsePitch: Boolean; Mode: Integer; Semitone, WindowMs,
  Formant, Amount, StepSemi, RateHz, Mix: Double);
begin
  GPitchUseCheck.Value := Byte(UsePitch);
  GPitchModeSelect.Value := Mode;
  GPitchSemiTrack.Value := Semitone;
  GPitchWindowTrack.Value := WindowMs;
  GPitchFormantTrack.Value := Formant;
  GPitchAmountTrack.Value := Amount;
  GPitchStepTrack.Value := StepSemi;
  GPitchRateTrack.Value := RateHz;
  GPitchMixTrack.Value := Mix;
  ClearPitchState;
end;

procedure ProcessPitchShiftPart(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer;
  Semitone, WindowMs, Mix: Single);
var
  Channel: Integer;
  BufferSamples: Integer;
  Buffer: TArray<Single>;
begin
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

procedure ProcessFormantPart(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer;
  Formant, Amount, Mix: Single);
var
  Channel: Integer;
  Buffer: TArray<Single>;
begin
  EnsureFormantState(Audio, ChannelNum);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyFormant(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, Formant, Amount, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GFormantNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

procedure ProcessPitchStepPart(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer;
  StepSemi, RateHz, Mix: Single);
var
  Channel: Integer;
  Buffer: TArray<Single>;
  BufferSamples: Integer;
begin
  BufferSamples := Ceil(Audio^.Scene^.SampleRate * 0.045) + 4;
  EnsurePitchStepState(Audio, ChannelNum, BufferSamples);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyPitchStep(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, Audio^.Object_^.SampleIndex,
      StepSemi, RateHz, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GPitchStepNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

function ProcessPitch(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  InputSpectrum: TAudioPitchSpectrumData;
  Mode: Integer;
  Mix: Single;
  OutputSpectrum: TAudioPitchSpectrumData;
begin
  Result := GPitchUseCheck.Value <> 0;
  if not Result then
  begin
    ClearPitchState;
    Exit;
  end;

  Mode := GPitchModeSelect.Value;
  Mix := GPitchMixTrack.Value;
  CapturePitchSpectrum(Audio, SampleNum, ChannelNum, InputSpectrum);

  case Mode of
    PITCH_MODE_NATURAL:
      begin
        ClearPitchStepState;
        ProcessPitchShiftPart(Audio, SampleNum, ChannelNum, GPitchSemiTrack.Value, GPitchWindowTrack.Value, Mix);
        ProcessFormantPart(Audio, SampleNum, ChannelNum, GPitchFormantTrack.Value, GPitchAmountTrack.Value, Mix);
      end;
    PITCH_MODE_PITCH_ONLY:
      begin
        ClearFormantState;
        ClearPitchStepState;
        ProcessPitchShiftPart(Audio, SampleNum, ChannelNum, GPitchSemiTrack.Value, GPitchWindowTrack.Value, Mix);
      end;
    PITCH_MODE_FORMANT_ONLY:
      begin
        ClearPitchShiftState;
        ClearPitchStepState;
        ProcessFormantPart(Audio, SampleNum, ChannelNum, GPitchFormantTrack.Value, GPitchAmountTrack.Value, Mix);
      end;
    PITCH_MODE_STEP:
      begin
        ClearPitchShiftState;
        ClearFormantState;
        ProcessPitchStepPart(Audio, SampleNum, ChannelNum, GPitchStepTrack.Value, GPitchRateTrack.Value, Mix);
      end;
  else
    ClearPitchState;
  end;
  CapturePitchSpectrum(Audio, SampleNum, ChannelNum, OutputSpectrum);
  PublishPitchSpectrum(Audio, InputSpectrum, OutputSpectrum);
end;

initialization
  GPitchSpectrumMemory := nil;

finalization
  FreeAndNil(GPitchSpectrumMemory);

end.
