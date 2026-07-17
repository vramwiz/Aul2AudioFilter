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

uses
  Winapi.Windows,
  System.SysUtils,
  Aul2AudioMonitorShared,
  Aul2AudioRingModSpectrumShared,
  Aul2AudioControllerRequest;

var
  GRingModGroup    : TFILTER_ITEM_GROUP;
  GRingModUseCheck : TFILTER_ITEM_CHECK;
  GRingModFreqTrack: TFILTER_ITEM_TRACK;
  GRingModDepthTrack: TFILTER_ITEM_TRACK;
  GRingModMixTrack : TFILTER_ITEM_TRACK;
  GRingSpectrumMemory: TAul2AudioRingSpectrumSharedMemory;
  GRingSpectrumCosTable: TArray<Double>;
  GRingSpectrumSinTable: TArray<Double>;
  GRingSpectrumSampleRate: Integer;
  GRingSpectrumTableSize: Integer;

function GetRingSpectrumMemory: TAul2AudioRingSpectrumSharedMemory;
begin
  if GRingSpectrumMemory = nil then
    GRingSpectrumMemory := TAul2AudioRingSpectrumSharedMemory.Create;
  Result := GRingSpectrumMemory;
end;

procedure EnsureRingSpectrumTable(SampleRate, TableSize: Integer);
var
  Angle, Frequency, FrequencyMax: Double;
  Band, Offset, Sample: Integer;
begin
  if (SampleRate = GRingSpectrumSampleRate) and
     (TableSize = GRingSpectrumTableSize) and
     (Length(GRingSpectrumCosTable) = AUDIO_RING_SPECTRUM_BAND_COUNT * TableSize) then
    Exit;
  GRingSpectrumSampleRate := SampleRate;
  GRingSpectrumTableSize := TableSize;
  SetLength(GRingSpectrumCosTable, AUDIO_RING_SPECTRUM_BAND_COUNT * TableSize);
  SetLength(GRingSpectrumSinTable, AUDIO_RING_SPECTRUM_BAND_COUNT * TableSize);
  FrequencyMax := Min(20000.0, SampleRate * 0.5);
  for Band := 0 to AUDIO_RING_SPECTRUM_BAND_LAST do
  begin
    Frequency := 20.0 * Power(FrequencyMax / 20.0,
      (Band + 0.5) / AUDIO_RING_SPECTRUM_BAND_COUNT);
    for Sample := 0 to TableSize - 1 do
    begin
      Offset := Band * TableSize + Sample;
      Angle := 2.0 * Pi * Frequency * Sample / SampleRate;
      GRingSpectrumCosTable[Offset] := Cos(Angle);
      GRingSpectrumSinTable[Offset] := Sin(Angle);
    end;
  end;
end;

procedure CaptureRingSpectrum(Audio: PFILTER_PROC_AUDIO; SampleNum,
  ChannelNum: Integer; var Spectrum: TAudioRingSpectrumData);
const
  SAMPLE_COUNT = 2048;
  DB_FLOOR = -80.0;
var
  Band, Offset, Sample, WorkSize: Integer;
  Db, ImValue, Magnitude, Mixed, ReValue, WindowValue: Double;
  LeftBuffer, RightBuffer: TArray<Single>;
begin
  FillChar(Spectrum, SizeOf(Spectrum), 0);
  if (Audio = nil) or (Audio^.Scene = nil) or (SampleNum <= 0) then
    Exit;
  WorkSize := Min(SAMPLE_COUNT, SampleNum);
  SetLength(LeftBuffer, SampleNum);
  Audio^.GetSampleData(@LeftBuffer[0], 0);
  if ChannelNum > 1 then
  begin
    SetLength(RightBuffer, SampleNum);
    Audio^.GetSampleData(@RightBuffer[0], 1);
  end;
  EnsureRingSpectrumTable(Audio^.Scene^.SampleRate, WorkSize);
  for Band := 0 to AUDIO_RING_SPECTRUM_BAND_LAST do
  begin
    ReValue := 0;
    ImValue := 0;
    for Sample := 0 to WorkSize - 1 do
    begin
      Mixed := LeftBuffer[Sample];
      if Length(RightBuffer) > Sample then
        Mixed := (Mixed + RightBuffer[Sample]) * 0.5;
      if WorkSize > 1 then
        WindowValue := 0.5 - 0.5 * Cos(2.0 * Pi * Sample / (WorkSize - 1))
      else
        WindowValue := 1.0;
      Offset := Band * WorkSize + Sample;
      ReValue := ReValue + Mixed * WindowValue * GRingSpectrumCosTable[Offset];
      ImValue := ImValue - Mixed * WindowValue * GRingSpectrumSinTable[Offset];
    end;
    Magnitude := Sqrt(Sqr(ReValue) + Sqr(ImValue)) / Max(1.0, WorkSize * 0.5);
    Db := 20.0 * Log10(Max(0.000001, Magnitude));
    Spectrum[Band] := EnsureRange((Db - DB_FLOOR) / -DB_FLOOR, 0.0, 1.0);
  end;
end;

procedure PublishRingSpectrum(Audio: PFILTER_PROC_AUDIO;
  const InputBands, OutputBands: TAudioRingSpectrumData);
var
  Layer: Integer;
  Memory: TAul2AudioRingSpectrumSharedMemory;
  State: PAul2AudioRingSpectrumState;
begin
  if (Audio = nil) or (Audio^.Scene = nil) or (Audio^.Object_ = nil) then
    Exit;
  Layer := Audio^.Object_^.Layer;
  if (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;
  Memory := GetRingSpectrumMemory;
  State := Memory.GetStateForLayer(Layer);
  if State = nil then
    Exit;
  State^.Magic := AUDIO_RING_SPECTRUM_SHARED_MAGIC;
  State^.Version := AUDIO_RING_SPECTRUM_SHARED_VERSION;
  State^.UpdateTick := GetTickCount64;
  State^.RequestId := ControllerCurrentRequestId;
  State^.SourceLayer := Layer;
  State^.SourceFrame := Audio^.Object_^.Frame;
  State^.SourceFrameS := Audio^.Object_^.FrameS;
  State^.SourceFrameE := Audio^.Object_^.FrameE;
  State^.SampleRate := Audio^.Scene^.SampleRate;
  State^.BandCount := AUDIO_RING_SPECTRUM_BAND_COUNT;
  State^.MinHz := 20;
  State^.MaxHz := Min(20000, Audio^.Scene^.SampleRate * 0.5);
  State^.InputBands := InputBands;
  State^.OutputBands := OutputBands;
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
  InputSpectrum: TAudioRingSpectrumData;
  OutputSpectrum: TAudioRingSpectrumData;
  CaptureRequested: Boolean;
begin
  Result := GRingModUseCheck.Value <> 0;
  if not Result then
    Exit;

  CaptureRequested := ControllerGraphRequested(AUDIO_CONTROLLER_GRAPH_RING_MOD);
  if CaptureRequested then
    CaptureRingSpectrum(Audio, SampleNum, ChannelNum, InputSpectrum);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplyRingMod(Buffer, SampleNum, Audio^.Scene^.SampleRate, Audio^.Object_^.SampleIndex,
      GRingModFreqTrack.Value, GRingModDepthTrack.Value, GRingModMixTrack.Value);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;
  if CaptureRequested then
  begin
    CaptureRingSpectrum(Audio, SampleNum, ChannelNum, OutputSpectrum);
    PublishRingSpectrum(Audio, InputSpectrum, OutputSpectrum);
  end;
end;

initialization
  GRingSpectrumMemory := nil;

finalization
  FreeAndNil(GRingSpectrumMemory);

end.
