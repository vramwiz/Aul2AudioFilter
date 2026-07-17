unit Aul2AudioFilterPluginTremble;

// Tremble 系の GUI 項目と、細かい音量揺れの音声処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddTrembleItems;
function ProcessTremble(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetTrembleGuiParams(UseTremble: Boolean; RateHz, Depth, Mix: Double);

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Aul2AudioMonitorShared,
  Aul2AudioTrembleRmsShared,
  Aul2AudioControllerRequest;

var
  GTrembleGroup     : TFILTER_ITEM_GROUP;
  GTrembleUseCheck  : TFILTER_ITEM_CHECK;
  GTrembleRateTrack : TFILTER_ITEM_TRACK;
  GTrembleDepthTrack: TFILTER_ITEM_TRACK;
  GTrembleMixTrack  : TFILTER_ITEM_TRACK;
  GTrembleRmsMemory : TAul2AudioTrembleRmsSharedMemory;

function GetTrembleRmsMemory: TAul2AudioTrembleRmsSharedMemory;
begin
  if GTrembleRmsMemory = nil then
    GTrembleRmsMemory := TAul2AudioTrembleRmsSharedMemory.Create;
  Result := GTrembleRmsMemory;
end;

procedure PublishTrembleRms(Audio: PFILTER_PROC_AUDIO; InputRms,
  OutputRms, LfoPhase: Single);
var
  Layer: Integer;
  Memory: TAul2AudioTrembleRmsSharedMemory;
  State: PAul2AudioTrembleRmsState;
begin
  if (Audio = nil) or (Audio^.Scene = nil) or (Audio^.Object_ = nil) then
    Exit;
  Layer := Audio^.Object_^.Layer;
  if (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;
  Memory := GetTrembleRmsMemory;
  State := Memory.GetStateForLayer(Layer);
  if State = nil then
    Exit;
  State^.Magic := AUDIO_TREMBLE_RMS_SHARED_MAGIC;
  State^.Version := AUDIO_TREMBLE_RMS_SHARED_VERSION;
  State^.RequestId := ControllerCurrentRequestId;
  State^.SourceLayer := Layer;
  State^.SourceFrame := Audio^.Object_^.Frame;
  State^.SampleRate := Audio^.Scene^.SampleRate;
  State^.SampleIndex := Audio^.Object_^.SampleIndex;
  State^.InputRms := InputRms;
  State^.OutputRms := OutputRms;
  State^.LfoPhase := LfoPhase;
  State^.UpdateTick := GetTickCount64;
  Inc(State^.Generation);
  Memory.Root^.LastLayer := Layer;
  Inc(Memory.Root^.Generation);
end;

function ClampSingle(Value, MinValue, MaxValue: Single): Single;
begin
  Result := Value;
  if Result < MinValue then
    Result := MinValue
  else if Result > MaxValue then
    Result := MaxValue;
end;

procedure ApplyTremble(var Buffer: TArray<Single>; SampleNum, SampleRate: Integer; BaseIndex: Int64;
  RateHz, Depth, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  Lfo: Single;
  Gain: Single;
  Phase: Double;
begin
  RateHz := ClampSingle(RateHz, 0.1, 30.0);
  Depth := ClampSingle(Depth, 0.0, 1.0);
  Mix := ClampSingle(Mix, 0.0, 1.0);

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    Phase := 2.0 * Pi * RateHz * ((BaseIndex + I) / SampleRate);
    Lfo := 0.5 + (0.5 * Sin(Phase));
    Gain := 1.0 - (Depth * Lfo);
    WetSample := DrySample * Gain;
    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);
  end;
end;

procedure AddTrembleItems;
begin
  AddGroup(GTrembleGroup, 'Tremble', 1);
  AddCheck(GTrembleUseCheck, 'Trem: Use', 0);
  AddTrack(GTrembleRateTrack, 'Trem: Rate(Hz)', 8.0, 0.1, 30.0, 0.1);
  AddTrack(GTrembleDepthTrack, 'Trem: Depth', 0.35, 0.0, 1.0, 0.01);
  AddTrack(GTrembleMixTrack, 'Trem: Mix', 1.0, 0.0, 1.0, 0.01);
end;

procedure SetTrembleGuiParams(UseTremble: Boolean; RateHz, Depth, Mix: Double);
begin
  GTrembleUseCheck.Value := Byte(UseTremble);
  GTrembleRateTrack.Value := RateHz;
  GTrembleDepthTrack.Value := Depth;
  GTrembleMixTrack.Value := Mix;
end;

function ProcessTremble(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  RateHz: Single;
  Depth: Single;
  Mix: Single;
  BaseIndex: Int64;
  CaptureRequested: Boolean;
  InputSum: Double;
  OutputSum: Double;
  Sample: Integer;
  Denominator: Double;
  PhaseCycles: Double;
begin
  Result := GTrembleUseCheck.Value <> 0;
  if not Result then
    Exit;

  RateHz := GTrembleRateTrack.Value;
  Depth := GTrembleDepthTrack.Value;
  Mix := GTrembleMixTrack.Value;
  BaseIndex := Audio^.Object_^.SampleIndex;
  CaptureRequested := ControllerGraphRequested(AUDIO_CONTROLLER_GRAPH_TREMBLE);
  InputSum := 0;
  OutputSum := 0;
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    if CaptureRequested then
      for Sample := 0 to SampleNum - 1 do
        InputSum := InputSum + Double(Buffer[Sample]) * Buffer[Sample];
    ApplyTremble(Buffer, SampleNum, Audio^.Scene^.SampleRate, BaseIndex, RateHz, Depth, Mix);
    if CaptureRequested then
      for Sample := 0 to SampleNum - 1 do
        OutputSum := OutputSum + Double(Buffer[Sample]) * Buffer[Sample];
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;
  if CaptureRequested and (SampleNum > 0) and (ChannelNum > 0) then
  begin
    Denominator := Double(SampleNum) * ChannelNum;
    PhaseCycles := RateHz * (BaseIndex + SampleNum div 2) /
      Audio^.Scene^.SampleRate;
    PhaseCycles := PhaseCycles - Floor(PhaseCycles);
    PublishTrembleRms(Audio, Sqrt(InputSum / Denominator),
      Sqrt(OutputSum / Denominator), PhaseCycles);
  end;
end;

initialization
  GTrembleRmsMemory := nil;

finalization
  FreeAndNil(GTrembleRmsMemory);

end.
