unit Aul2AudioFilterPluginReverb;

// Reverb effect GUI items, state buffers, and audio processing.
interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddReverbItems;
function ProcessReverb(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;

implementation

const
  REVERB_COMB_COUNT = 4;
  REVERB_DELAY_MS_L: array[0..REVERB_COMB_COUNT - 1] of Double = (29.7, 37.1, 41.1, 43.7);
  REVERB_DELAY_MS_R: array[0..REVERB_COMB_COUNT - 1] of Double = (31.1, 35.3, 39.7, 45.1);

type
  TReverbCombState = record
    Buffer  : TArray<Single>; // Feedback delay line for one comb filter.
    Position: Integer;        // Current ring-buffer write position.
    Filter  : Single;         // One-pole low-pass memory for damping.
  end;

  TReverbChannelState = record
    Combs: array[0..REVERB_COMB_COUNT - 1] of TReverbCombState;
  end;

var
  GReverbGroup    : TFILTER_ITEM_GROUP;
  GReverbUseCheck : TFILTER_ITEM_CHECK;
  GRoomSizeTrack  : TFILTER_ITEM_TRACK;
  GDampingTrack   : TFILTER_ITEM_TRACK;
  GReverbDryTrack : TFILTER_ITEM_TRACK;
  GReverbWetTrack : TFILTER_ITEM_TRACK;
  GReverbChannels : array of TReverbChannelState;
  GReverbSampleRate: Integer;
  GReverbObjectID : Int64;
  GReverbEffectID : Int64;
  GReverbNextIndex: Int64;

procedure ClearReverbState;
begin
  SetLength(GReverbChannels, 0);
  GReverbSampleRate := 0;
  GReverbObjectID := 0;
  GReverbEffectID := 0;
  GReverbNextIndex := 0;
end;

function GetReverbDelaySamples(SampleRate, Channel, CombIndex: Integer): Integer;
var
  DelayMs: Double;
begin
  if Odd(Channel) then
    DelayMs := REVERB_DELAY_MS_R[CombIndex]
  else
    DelayMs := REVERB_DELAY_MS_L[CombIndex];

  Result := Round(SampleRate * DelayMs / 1000.0);
  if Result < 1 then
    Result := 1;
end;

procedure ResetReverbState(ChannelNum, SampleRate: Integer);
var
  Channel: Integer;
  Comb: Integer;
  DelaySamples: Integer;
begin
  SetLength(GReverbChannels, ChannelNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    for Comb := 0 to REVERB_COMB_COUNT - 1 do
    begin
      DelaySamples := GetReverbDelaySamples(SampleRate, Channel, Comb);
      SetLength(GReverbChannels[Channel].Combs[Comb].Buffer, DelaySamples);
      FillChar(GReverbChannels[Channel].Combs[Comb].Buffer[0], DelaySamples * SizeOf(Single), 0);
      GReverbChannels[Channel].Combs[Comb].Position := 0;
      GReverbChannels[Channel].Combs[Comb].Filter := 0.0;
    end;
  end;

  GReverbSampleRate := SampleRate;
end;

procedure EnsureReverbState(Audio: PFILTER_PROC_AUDIO; ChannelNum: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  if (Length(GReverbChannels) <> ChannelNum) or
     (GReverbSampleRate <> Audio^.Scene^.SampleRate) or
     (GReverbObjectID <> ObjectInfo^.ID) or
     (GReverbEffectID <> ObjectInfo^.EffectID) or
     (GReverbNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetReverbState(ChannelNum, Audio^.Scene^.SampleRate);
    GReverbObjectID := ObjectInfo^.ID;
    GReverbEffectID := ObjectInfo^.EffectID;
  end;
end;

function ClampUnit(Value: Single): Single;
begin
  Result := Value;
  if Result < 0.0 then
    Result := 0.0
  else if Result > 1.0 then
    Result := 1.0;
end;

procedure ApplyReverb(var Buffer: TArray<Single>; Channel, SampleNum: Integer;
  RoomSize, Damping, Dry, Wet: Single);
var
  I: Integer;
  Comb: Integer;
  InputSample: Single;
  DelayedSample: Single;
  FilteredSample: Single;
  ReverbSample: Single;
  Feedback: Single;
  CombState: ^TReverbCombState;
begin
  RoomSize := ClampUnit(RoomSize);
  Damping := ClampUnit(Damping);
  Feedback := 0.20 + (RoomSize * 0.65);

  for I := 0 to SampleNum - 1 do
  begin
    InputSample := Buffer[I];
    ReverbSample := 0.0;

    for Comb := 0 to REVERB_COMB_COUNT - 1 do
    begin
      CombState := @GReverbChannels[Channel].Combs[Comb];
      DelayedSample := CombState^.Buffer[CombState^.Position];
      FilteredSample := (DelayedSample * (1.0 - Damping)) + (CombState^.Filter * Damping);
      CombState^.Filter := FilteredSample;
      CombState^.Buffer[CombState^.Position] := InputSample + (FilteredSample * Feedback);
      ReverbSample := ReverbSample + FilteredSample;

      Inc(CombState^.Position);
      if CombState^.Position >= Length(CombState^.Buffer) then
        CombState^.Position := 0;
    end;

    Buffer[I] := (InputSample * Dry) + ((ReverbSample / REVERB_COMB_COUNT) * Wet);
  end;
end;

procedure AddReverbItems;
begin
  AddGroup(GReverbGroup, 'Reverb', 1);
  AddCheck(GReverbUseCheck, 'Reverb: Use', 0);
  AddTrack(GRoomSizeTrack, 'Reverb: RoomSize', 0.5, 0.0, 1.0, 0.01);
  AddTrack(GDampingTrack, 'Reverb: Damping', 0.4, 0.0, 1.0, 0.01);
  AddTrack(GReverbDryTrack, 'Reverb: Dry', 1.0, 0.0, 2.0, 0.01);
  AddTrack(GReverbWetTrack, 'Reverb: Wet', 0.3, 0.0, 2.0, 0.01);
end;

function ProcessReverb(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  RoomSize: Single;
  Damping: Single;
  Dry: Single;
  Wet: Single;
begin
  Result := GReverbUseCheck.Value <> 0;
  if not Result then
  begin
    ClearReverbState;
    Exit;
  end;

  RoomSize := GRoomSizeTrack.Value;
  Damping := GDampingTrack.Value;
  Dry := GReverbDryTrack.Value;
  Wet := GReverbWetTrack.Value;

  EnsureReverbState(Audio, ChannelNum);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyReverb(Buffer, Channel, SampleNum, RoomSize, Damping, Dry, Wet);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GReverbNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
