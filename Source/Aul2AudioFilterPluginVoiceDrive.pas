unit Aul2AudioFilterPluginVoiceDrive;

// VoiceDrive 系の GUI 項目、状態管理、声向けサチュレーション処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddVoiceDriveItems;
function ProcessVoiceDrive(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetVoiceDriveGuiParams(UseVoiceDrive: Boolean; DriveDb, Body, LevelDb, Mix: Double);

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Aul2AudioMonitorShared,
  Aul2AudioVoiceDriveXYShared,
  Aul2AudioControllerRequest;

type
  TVoiceDriveChannelState = record
    LowSample: Single; // 声の太さを作るための低域側状態
  end;

var
  GVoiceDriveGroup      : TFILTER_ITEM_GROUP;
  GVoiceDriveUseCheck   : TFILTER_ITEM_CHECK;
  GVoiceDriveDriveTrack : TFILTER_ITEM_TRACK;
  GVoiceDriveBodyTrack  : TFILTER_ITEM_TRACK;
  GVoiceDriveLevelTrack : TFILTER_ITEM_TRACK;
  GVoiceDriveMixTrack   : TFILTER_ITEM_TRACK;
  GVoiceDriveChannels   : array of TVoiceDriveChannelState; // チャンネル別の低域状態
  GVoiceDriveSampleRate : Integer;                          // 状態を構築したサンプルレート
  GVoiceDriveObjectID   : Int64;                            // 状態を構築した対象オブジェクト
  GVoiceDriveEffectID   : Int64;                            // 状態を構築した対象エフェクト
  GVoiceDriveNextIndex  : Int64;                            // 連続処理を判定する次のサンプル位置
  GVoiceDriveXYMemory   : TAul2AudioVoiceDriveXYSharedMemory;

function GetVoiceDriveXYMemory: TAul2AudioVoiceDriveXYSharedMemory;
begin
  if GVoiceDriveXYMemory = nil then
    GVoiceDriveXYMemory := TAul2AudioVoiceDriveXYSharedMemory.Create;
  Result := GVoiceDriveXYMemory;
end;

procedure CaptureVoiceDriveSamples(Audio: PFILTER_PROC_AUDIO; SampleNum,
  ChannelNum: Integer; var Samples: TAudioVoiceDriveXYData;
  out CapturedCount: Integer);
var
  CaptureChannels: Integer;
  Channel: Integer;
  Frame: Integer;
  FrameCount: Integer;
  LeftBuffer: TArray<Single>;
  PointIndex: Integer;
  RightBuffer: TArray<Single>;
  SourceIndex: Integer;
begin
  FillChar(Samples, SizeOf(Samples), 0);
  CapturedCount := 0;
  if (Audio = nil) or (SampleNum <= 0) or (ChannelNum <= 0) then
    Exit;
  CaptureChannels := Min(ChannelNum, 2);
  FrameCount := Min(SampleNum,
    AUDIO_VOICE_DRIVE_XY_SAMPLE_COUNT div CaptureChannels);
  if FrameCount <= 0 then
    Exit;
  SetLength(LeftBuffer, SampleNum);
  Audio^.GetSampleData(@LeftBuffer[0], 0);
  if CaptureChannels > 1 then
  begin
    SetLength(RightBuffer, SampleNum);
    Audio^.GetSampleData(@RightBuffer[0], 1);
  end;
  for Frame := 0 to FrameCount - 1 do
  begin
    if FrameCount > 1 then
      SourceIndex := Round(Frame * (SampleNum - 1) / (FrameCount - 1))
    else
      SourceIndex := 0;
    for Channel := 0 to CaptureChannels - 1 do
    begin
      PointIndex := Frame * CaptureChannels + Channel;
      if Channel = 0 then
        Samples[PointIndex] := LeftBuffer[SourceIndex]
      else
        Samples[PointIndex] := RightBuffer[SourceIndex];
    end;
  end;
  CapturedCount := FrameCount * CaptureChannels;
end;

procedure PublishVoiceDriveSamples(Audio: PFILTER_PROC_AUDIO;
  SampleCount: Integer; const InputSamples,
  OutputSamples: TAudioVoiceDriveXYData);
var
  Layer: Integer;
  Memory: TAul2AudioVoiceDriveXYSharedMemory;
  State: PAul2AudioVoiceDriveXYState;
begin
  if (Audio = nil) or (Audio^.Scene = nil) or (Audio^.Object_ = nil) then
    Exit;
  Layer := Audio^.Object_^.Layer;
  if (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;
  Memory := GetVoiceDriveXYMemory;
  State := Memory.GetStateForLayer(Layer);
  if State = nil then
    Exit;
  State^.Magic := AUDIO_VOICE_DRIVE_XY_SHARED_MAGIC;
  State^.Version := AUDIO_VOICE_DRIVE_XY_SHARED_VERSION;
  State^.UpdateTick := GetTickCount64;
  State^.RequestId := ControllerCurrentRequestId;
  State^.SourceLayer := Layer;
  State^.SourceFrame := Audio^.Object_^.Frame;
  State^.SourceFrameS := Audio^.Object_^.FrameS;
  State^.SourceFrameE := Audio^.Object_^.FrameE;
  State^.SampleRate := Audio^.Scene^.SampleRate;
  State^.SampleCount := SampleCount;
  State^.InputSamples := InputSamples;
  State^.OutputSamples := OutputSamples;
  Inc(State^.Generation);
  Memory.Root^.LastLayer := Layer;
  Inc(Memory.Root^.Generation);
end;

procedure ClearVoiceDriveState;
begin
  SetLength(GVoiceDriveChannels, 0);
  GVoiceDriveSampleRate := 0;
  GVoiceDriveObjectID := 0;
  GVoiceDriveEffectID := 0;
  GVoiceDriveNextIndex := 0;
end;

procedure ResetVoiceDriveState(ChannelNum, SampleRate: Integer);
var
  Channel: Integer;
begin
  SetLength(GVoiceDriveChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
    GVoiceDriveChannels[Channel].LowSample := 0.0;

  GVoiceDriveSampleRate := SampleRate;
end;

procedure EnsureVoiceDriveState(Audio: PFILTER_PROC_AUDIO; ChannelNum: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  // 低域状態が別素材へ混ざらないよう、処理対象や連続位置が変わったら作り直す。
  if (Length(GVoiceDriveChannels) <> ChannelNum) or
     (GVoiceDriveSampleRate <> Audio^.Scene^.SampleRate) or
     (GVoiceDriveObjectID <> ObjectInfo^.ID) or
     (GVoiceDriveEffectID <> ObjectInfo^.EffectID) or
     (GVoiceDriveNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetVoiceDriveState(ChannelNum, Audio^.Scene^.SampleRate);
    GVoiceDriveObjectID := ObjectInfo^.ID;
    GVoiceDriveEffectID := ObjectInfo^.EffectID;
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

procedure ApplyVoiceDrive(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  DriveDb, Body, LevelDb, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  Drive: Single;
  Level: Single;
  BodyMix: Single;
  LowCoeff: Single;
  DrivenInput: Single;
  Normalizer: Single;
  State: ^TVoiceDriveChannelState;
begin
  BodyMix := ClampSingle(Body, 0.0, 1.0);
  Mix := ClampSingle(Mix, 0.0, 1.0);
  Drive := DbToLinear(DriveDb);
  Level := DbToLinear(LevelDb);
  LowCoeff := 1.0 - Exp(-2.0 * Pi * 700.0 / SampleRate);
  Normalizer := Tanh(Drive);
  if Normalizer <= 0.0 then
    Normalizer := 1.0;

  State := @GVoiceDriveChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    State^.LowSample := State^.LowSample + ((DrySample - State^.LowSample) * LowCoeff);
    DrivenInput := (DrySample * (1.0 - (BodyMix * 0.35))) + (State^.LowSample * BodyMix * 0.35);
    WetSample := (Tanh(DrivenInput * Drive) / Normalizer) * Level;
    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);
  end;
end;

procedure AddVoiceDriveItems;
begin
  AddGroup(GVoiceDriveGroup, 'VoiceDrive', 1);
  AddCheck(GVoiceDriveUseCheck, 'Drive: Use', 0);
  AddTrack(GVoiceDriveDriveTrack, 'Drive: Drive(dB)', 9.0, 0.0, 30.0, 0.1);
  AddTrack(GVoiceDriveBodyTrack, 'Drive: Body', 0.45, 0.0, 1.0, 0.01);
  AddTrack(GVoiceDriveLevelTrack, 'Drive: Level(dB)', -6.0, -24.0, 6.0, 0.1);
  AddTrack(GVoiceDriveMixTrack, 'Drive: Mix', 0.6, 0.0, 1.0, 0.01);
end;

procedure SetVoiceDriveGuiParams(UseVoiceDrive: Boolean; DriveDb, Body, LevelDb, Mix: Double);
begin
  GVoiceDriveUseCheck.Value := Byte(UseVoiceDrive);
  GVoiceDriveDriveTrack.Value := DriveDb;
  GVoiceDriveBodyTrack.Value := Body;
  GVoiceDriveLevelTrack.Value := LevelDb;
  GVoiceDriveMixTrack.Value := Mix;
  ClearVoiceDriveState;
end;

function ProcessVoiceDrive(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  DriveDb: Single;
  InputSamples: TAudioVoiceDriveXYData;
  Body: Single;
  LevelDb: Single;
  Mix: Single;
  OutputCount: Integer;
  OutputSamples: TAudioVoiceDriveXYData;
  SampleCount: Integer;
  CaptureRequested: Boolean;
begin
  Result := GVoiceDriveUseCheck.Value <> 0;
  if not Result then
  begin
    ClearVoiceDriveState;
    Exit;
  end;

  DriveDb := GVoiceDriveDriveTrack.Value;
  Body := GVoiceDriveBodyTrack.Value;
  LevelDb := GVoiceDriveLevelTrack.Value;
  Mix := GVoiceDriveMixTrack.Value;
  CaptureRequested := ControllerGraphRequested(AUDIO_CONTROLLER_GRAPH_VOICE_DRIVE);

  EnsureVoiceDriveState(Audio, ChannelNum);
  if CaptureRequested then
    CaptureVoiceDriveSamples(Audio, SampleNum, ChannelNum, InputSamples,
      SampleCount);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyVoiceDrive(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, DriveDb, Body, LevelDb, Mix);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  if CaptureRequested then
  begin
    CaptureVoiceDriveSamples(Audio, SampleNum, ChannelNum, OutputSamples,
      OutputCount);
    PublishVoiceDriveSamples(Audio, Min(SampleCount, OutputCount), InputSamples,
      OutputSamples);
  end;

  GVoiceDriveNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

initialization
  GVoiceDriveXYMemory := nil;

finalization
  FreeAndNil(GVoiceDriveXYMemory);

end.
