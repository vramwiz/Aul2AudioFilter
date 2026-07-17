unit Aul2AudioFilterPluginNoise;

// Noise 系の GUI 項目、状態管理、音声処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddNoiseItems;
function ProcessNoise(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetNoiseGuiParams(UseNoise: Boolean; Crackle: Boolean; LevelDb, Mix: Double);

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Aul2AudioMonitorShared,
  Aul2AudioNoiseWaveShared;

const
  NOISE_MODE_WHITE = 0;
  NOISE_MODE_CRACKLE = 1;

type
  TNoiseChannelState = record
    Seed: Cardinal; // チャンネル別の疑似乱数状態
  end;

var
  GNoiseGroup     : TFILTER_ITEM_GROUP;
  GNoiseUseCheck  : TFILTER_ITEM_CHECK;
  GNoiseModeSelect: TFILTER_ITEM_SELECT;
  GNoiseModeList  : array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  GNoiseLevelTrack: TFILTER_ITEM_TRACK;
  GNoiseMixTrack  : TFILTER_ITEM_TRACK;
  GNoiseChannels  : array of TNoiseChannelState; // チャンネル別のノイズ生成状態
  GNoiseObjectID  : Int64;                       // 状態を構築した対象オブジェクト
  GNoiseEffectID  : Int64;                       // 状態を構築した対象エフェクト
  GNoiseWaveMemory: TAul2AudioNoiseWaveSharedMemory;

function GetNoiseWaveMemory: TAul2AudioNoiseWaveSharedMemory;
begin
  if GNoiseWaveMemory = nil then
    GNoiseWaveMemory := TAul2AudioNoiseWaveSharedMemory.Create;
  Result := GNoiseWaveMemory;
end;

procedure CaptureNoiseWave(Audio: PFILTER_PROC_AUDIO; SampleNum,
  ChannelNum: Integer; var Wave: TAudioNoiseWaveData; out WaveSampleCount: Integer);
var
  LeftBuffer: TArray<Single>;
  Mixed: Single;
  RightBuffer: TArray<Single>;
  Sample: Integer;
  SourceIndex: Integer;
begin
  FillChar(Wave, SizeOf(Wave), 0);
  WaveSampleCount := 0;
  if (Audio = nil) or (SampleNum <= 0) or (ChannelNum <= 0) then
    Exit;
  WaveSampleCount := Min(AUDIO_NOISE_WAVE_SAMPLE_COUNT, SampleNum);
  SetLength(LeftBuffer, SampleNum);
  Audio^.GetSampleData(@LeftBuffer[0], 0);
  if ChannelNum > 1 then
  begin
    SetLength(RightBuffer, SampleNum);
    Audio^.GetSampleData(@RightBuffer[0], 1);
  end;
  for Sample := 0 to WaveSampleCount - 1 do
  begin
    if WaveSampleCount > 1 then
      SourceIndex := Round(Sample * (SampleNum - 1) /
        (WaveSampleCount - 1))
    else
      SourceIndex := 0;
    Mixed := LeftBuffer[SourceIndex];
    if Length(RightBuffer) > SourceIndex then
      Mixed := (Mixed + RightBuffer[SourceIndex]) * 0.5;
    Wave[Sample] := Mixed;
  end;
end;

procedure PublishNoiseWave(Audio: PFILTER_PROC_AUDIO; SampleCount: Integer;
  const InputWave, OutputWave: TAudioNoiseWaveData);
var
  Layer: Integer;
  Memory: TAul2AudioNoiseWaveSharedMemory;
  State: PAul2AudioNoiseWaveState;
begin
  if (Audio = nil) or (Audio^.Scene = nil) or (Audio^.Object_ = nil) then
    Exit;
  Layer := Audio^.Object_^.Layer;
  if (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;
  Memory := GetNoiseWaveMemory;
  State := Memory.GetStateForLayer(Layer);
  if State = nil then
    Exit;
  State^.Magic := AUDIO_NOISE_WAVE_SHARED_MAGIC;
  State^.Version := AUDIO_NOISE_WAVE_SHARED_VERSION;
  State^.UpdateTick := GetTickCount64;
  State^.SourceLayer := Layer;
  State^.SourceFrame := Audio^.Object_^.Frame;
  State^.SourceFrameS := Audio^.Object_^.FrameS;
  State^.SourceFrameE := Audio^.Object_^.FrameE;
  State^.SampleRate := Audio^.Scene^.SampleRate;
  State^.SampleCount := SampleCount;
  State^.InputWave := InputWave;
  State^.OutputWave := OutputWave;
  Inc(State^.Generation);
  Memory.Root^.LastLayer := Layer;
  Inc(Memory.Root^.Generation);
end;

procedure ClearNoiseState;
begin
  SetLength(GNoiseChannels, 0);
  GNoiseObjectID := 0;
  GNoiseEffectID := 0;
end;

procedure ResetNoiseState(ChannelNum: Integer);
var
  Channel: Integer;
begin
  SetLength(GNoiseChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
    GNoiseChannels[Channel].Seed := Cardinal($12345678 + (Channel * $00100193));
end;

procedure EnsureNoiseState(Audio: PFILTER_PROC_AUDIO; ChannelNum: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  // 同じ素材では連続したノイズにし、別素材へ切り替わったら乱数状態を作り直す。
  if (Length(GNoiseChannels) <> ChannelNum) or
     (GNoiseObjectID <> ObjectInfo^.ID) or
     (GNoiseEffectID <> ObjectInfo^.EffectID) then
  begin
    ResetNoiseState(ChannelNum);
    GNoiseObjectID := ObjectInfo^.ID;
    GNoiseEffectID := ObjectInfo^.EffectID;
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

function NextRandom(var Seed: Cardinal): Single;
begin
  Seed := (Seed * 1664525) + 1013904223;
  Result := ((Seed shr 8) * (1.0 / 16777215.0)) * 2.0 - 1.0;
end;

function MakeNoiseSample(var Seed: Cardinal; Mode: Integer): Single;
var
  Chance: Single;
begin
  case Mode of
    NOISE_MODE_CRACKLE:
      begin
        Chance := Abs(NextRandom(Seed));
        if Chance > 0.985 then
          Result := NextRandom(Seed)
        else
          Result := NextRandom(Seed) * 0.15;
      end;
  else
    Result := NextRandom(Seed);
  end;
end;

procedure ApplyNoise(var Buffer: TArray<Single>; Channel, SampleNum, Mode: Integer;
  LevelDb, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  NoiseSample: Single;
  Level: Single;
  State: ^TNoiseChannelState;
begin
  Mix := ClampSingle(Mix, 0.0, 1.0);
  Level := DbToLinear(LevelDb);
  State := @GNoiseChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    NoiseSample := MakeNoiseSample(State^.Seed, Mode) * Level;
    Buffer[I] := DrySample + (NoiseSample * Mix);
  end;
end;

procedure AddNoiseItems;
begin
  AddGroup(GNoiseGroup, 'Noise', 1);
  AddCheck(GNoiseUseCheck, 'Noise: Use', 0);
  GNoiseModeList[0].Name := 'White';
  GNoiseModeList[0].Value := NOISE_MODE_WHITE;
  GNoiseModeList[1].Name := 'Crackle';
  GNoiseModeList[1].Value := NOISE_MODE_CRACKLE;
  GNoiseModeList[2].Name := nil;
  GNoiseModeList[2].Value := 0;
  AddSelect(GNoiseModeSelect, 'Noise: Mode', NOISE_MODE_WHITE, @GNoiseModeList[0]);
  AddTrack(GNoiseLevelTrack, 'Noise: Level(dB)', -36.0, -80.0, -6.0, 0.1);
  AddTrack(GNoiseMixTrack, 'Noise: Mix', 1.0, 0.0, 1.0, 0.01);
end;

procedure SetNoiseGuiParams(UseNoise: Boolean; Crackle: Boolean; LevelDb, Mix: Double);
begin
  GNoiseUseCheck.Value := Byte(UseNoise);
  if Crackle then
    GNoiseModeSelect.Value := NOISE_MODE_CRACKLE
  else
    GNoiseModeSelect.Value := NOISE_MODE_WHITE;
  GNoiseLevelTrack.Value := LevelDb;
  GNoiseMixTrack.Value := Mix;
  ClearNoiseState;
end;

function ProcessNoise(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  InputWave: TAudioNoiseWaveData;
  OutputWave: TAudioNoiseWaveData;
  WaveSampleCount: Integer;
  OutputSampleCount: Integer;
  Mode: Integer;
  LevelDb: Single;
  Mix: Single;
begin
  Result := GNoiseUseCheck.Value <> 0;
  if not Result then
  begin
    ClearNoiseState;
    Exit;
  end;

  Mode := GNoiseModeSelect.Value;
  LevelDb := GNoiseLevelTrack.Value;
  Mix := GNoiseMixTrack.Value;

  EnsureNoiseState(Audio, ChannelNum);
  CaptureNoiseWave(Audio, SampleNum, ChannelNum, InputWave, WaveSampleCount);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyNoise(Buffer, Channel, SampleNum, Mode, LevelDb, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;
  CaptureNoiseWave(Audio, SampleNum, ChannelNum, OutputWave, OutputSampleCount);
  WaveSampleCount := Min(WaveSampleCount, OutputSampleCount);
  PublishNoiseWave(Audio, WaveSampleCount, InputWave, OutputWave);
end;

initialization
  GNoiseWaveMemory := nil;

finalization
  FreeAndNil(GNoiseWaveMemory);

end.
