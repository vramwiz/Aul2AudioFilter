unit Aul2AudioFilterPluginRingMod;

// RingMod 系の GUI 項目と、機械的な振幅変調処理を担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddRingModItems;
function ProcessRingMod(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
procedure SetRingModGuiParams(UseRingMod: Boolean; FrequencyHz, Depth, Mix: Double);

implementation

var
  GRingModGroup    : TFILTER_ITEM_GROUP;
  GRingModUseCheck : TFILTER_ITEM_CHECK;
  GRingModFreqTrack: TFILTER_ITEM_TRACK;
  GRingModDepthTrack: TFILTER_ITEM_TRACK;
  GRingModMixTrack : TFILTER_ITEM_TRACK;

function ClampSingle(Value, MinValue, MaxValue: Single): Single;
begin
  Result := Value;
  if Result < MinValue then
    Result := MinValue
  else if Result > MaxValue then
    Result := MaxValue;
end;

procedure ApplyRingMod(var Buffer: TArray<Single>; SampleNum, SampleRate: Integer; BaseIndex: Int64;
  FrequencyHz, Depth, Mix: Single);
var
  I: Integer;
  DrySample: Single;
  Modulator: Single;
  WetSample: Single;
begin
  FrequencyHz := ClampSingle(FrequencyHz, 1.0, 2000.0);
  Depth := ClampSingle(Depth, 0.0, 1.0);
  Mix := ClampSingle(Mix, 0.0, 1.0);

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    Modulator := (1.0 - Depth) + (Depth * Sin(2.0 * Pi * FrequencyHz * ((BaseIndex + I) / SampleRate)));
    WetSample := DrySample * Modulator;
    Buffer[I] := (DrySample * (1.0 - Mix)) + (WetSample * Mix);
  end;
end;

procedure AddRingModItems;
begin
  AddGroup(GRingModGroup, 'RingMod', 1);
  AddCheck(GRingModUseCheck, 'Ring: Use', 0);
  AddTrack(GRingModFreqTrack, 'Ring: Frequency(Hz)', 45.0, 1.0, 2000.0, 1.0);
  AddTrack(GRingModDepthTrack, 'Ring: Depth', 0.7, 0.0, 1.0, 0.01);
  AddTrack(GRingModMixTrack, 'Ring: Mix', 0.7, 0.0, 1.0, 0.01);
end;

procedure SetRingModGuiParams(UseRingMod: Boolean; FrequencyHz, Depth, Mix: Double);
begin
  GRingModUseCheck.Value := Byte(UseRingMod);
  GRingModFreqTrack.Value := FrequencyHz;
  GRingModDepthTrack.Value := Depth;
  GRingModMixTrack.Value := Mix;
end;

function ProcessRingMod(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
begin
  Result := GRingModUseCheck.Value <> 0;
  if not Result then
    Exit;

  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyRingMod(Buffer, SampleNum, Audio^.Scene^.SampleRate, Audio^.Object_^.SampleIndex,
      GRingModFreqTrack.Value, GRingModDepthTrack.Value, GRingModMixTrack.Value);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;
end;

end.
