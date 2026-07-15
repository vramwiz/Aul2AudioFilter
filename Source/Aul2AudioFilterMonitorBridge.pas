unit Aul2AudioFilterMonitorBridge;

// 音声フィルター処理から Aul2AudioMonitor 用共有メモリへ軽量な解析値を書き出す。

interface

uses
  Aul2AudioFilterTypes;

procedure AudioMonitorInitialize;
procedure AudioMonitorSetStage(Stage: Integer; Audio: PFILTER_PROC_AUDIO);
procedure AudioMonitorCaptureInput(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer);
procedure AudioMonitorCaptureOutput(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer);
procedure AudioMonitorFinalize;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  Aul2AudioFilterAudioTrace,
  Aul2AudioMonitorShared,
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioMonitorVectorShared;

type
  TAudioMonitorInputSnapshot = record
    PeakL: Single;
    PeakR: Single;
    RmsL: Single;
    RmsR: Single;
    Wave: TAudioMonitorWaveData;
    WaveMin: TAudioMonitorWaveData;
    WaveMax: TAudioMonitorWaveData;
    VectorLeft : TAudioMonitorVectorData;
    VectorRight: TAudioMonitorVectorData;
    VectorValid: Boolean;
    Spectrum: TAudioMonitorSpectrumData;
  end;

var
  SharedMemory: TAul2AudioMonitorSharedMemory;
  SpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;
  VectorMemory: TAul2AudioMonitorVectorSharedMemory;
  LastInputSnapshots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAudioMonitorInputSnapshot;
  SpectrumCosTable: TArray<Single>;
  SpectrumSinTable: TArray<Single>;
  SpectrumTableSampleRate: Integer;
  SpectrumTableSize: Integer;

procedure PushMonitorHistory(Root: PAul2AudioMonitorLayeredState; Layer: Integer;
  const State: TAul2AudioMonitorState);
var
  Index: Integer;
begin
  if (Root = nil) or (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;

  Index := Root^.HistoryIndex[Layer] + 1;
  if (Index < 0) or (Index > AUDIO_MONITOR_HISTORY_LAST) then
    Index := 0;
  Root^.HistoryIndex[Layer] := Index;
  Root^.History[Layer, Index] := State;
end;

procedure PushSpectrumHistory(Root: PAul2AudioMonitorLayeredSpectrumState; Layer: Integer;
  const State: TAul2AudioMonitorSpectrumState);
var
  Index: Integer;
begin
  if (Root = nil) or (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;

  Index := Root^.HistoryIndex[Layer] + 1;
  if (Index < 0) or (Index > AUDIO_MONITOR_SPECTRUM_HISTORY_LAST) then
    Index := 0;
  Root^.HistoryIndex[Layer] := Index;
  Root^.History[Layer, Index] := State;
end;

procedure PushVectorHistory(Root: PAul2AudioMonitorLayeredVectorState; Layer: Integer;
  const State: TAul2AudioMonitorVectorState);
var
  Index: Integer;
begin
  if (Root = nil) or (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;

  Index := Root^.HistoryIndex[Layer] + 1;
  if (Index < 0) or (Index > AUDIO_MONITOR_VECTOR_HISTORY_LAST) then
    Index := 0;
  Root^.HistoryIndex[Layer] := Index;
  Root^.History[Layer, Index] := State;
end;

function GetSharedMemory: TAul2AudioMonitorSharedMemory;
begin
  if SharedMemory = nil then
    SharedMemory := TAul2AudioMonitorSharedMemory.Create;

  Result := SharedMemory;
end;

function GetSpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;
begin
  if SpectrumMemory = nil then
    SpectrumMemory := TAul2AudioMonitorSpectrumSharedMemory.Create;

  Result := SpectrumMemory;
end;

function GetVectorMemory: TAul2AudioMonitorVectorSharedMemory;
begin
  if VectorMemory = nil then
    VectorMemory := TAul2AudioMonitorVectorSharedMemory.Create;

  Result := VectorMemory;
end;

function VectorCaptureRequested: Boolean;
var
  NowTick: UInt64;
  Root: PAul2AudioMonitorLayeredVectorState;
begin
  Result := False;
  Root := GetVectorMemory.Root;
  if (Root = nil) or
     (Root^.Magic <> AUDIO_MONITOR_VECTOR_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_MONITOR_VECTOR_SHARED_VERSION) or
     (Root^.RequestTick = 0) then
    Exit;

  NowTick := GetTickCount64;
  Result := (NowTick >= Root^.RequestTick) and
    ((NowTick - Root^.RequestTick) <= AUDIO_MONITOR_VECTOR_REQUEST_MS);
end;

function AudioLayer(Audio: PFILTER_PROC_AUDIO): Integer;
begin
  if (Audio = nil) or (Audio^.Object_ = nil) then
    Exit(AUDIO_MONITOR_LAYER_AUTO);

  Result := Audio^.Object_^.Layer;
  if (Result < 0) or (Result > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Result := 0;
end;

function MonitorSignalLevel(State: PAul2AudioMonitorState): Single;
begin
  if State = nil then
    Exit(0.0);
  Result := Max(Max(Abs(State^.OutputPeakL), Abs(State^.OutputPeakR)),
    Max(Abs(State^.OutputRmsL), Abs(State^.OutputRmsR)));
end;

procedure SelectLastMonitorLayer(Root: PAul2AudioMonitorLayeredState;
  CandidateLayer: Integer);
var
  CurrentLayer: Integer;
  CandidateState: PAul2AudioMonitorState;
  CurrentState: PAul2AudioMonitorState;
  CandidateFrame: Integer;
  CurrentFrame: Integer;
begin
  if (Root = nil) or (CandidateLayer < 0) or
     (CandidateLayer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Exit;

  CandidateState := @Root^.Slots[CandidateLayer];
  CurrentLayer := Root^.LastLayer;
  if (CurrentLayer < 0) or (CurrentLayer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
  begin
    Root^.LastLayer := CandidateLayer;
    Exit;
  end;

  CurrentState := @Root^.Slots[CurrentLayer];
  CandidateFrame := CandidateState^.SourceFrameS + CandidateState^.SourceFrame;
  CurrentFrame := CurrentState^.SourceFrameS + CurrentState^.SourceFrame;
  if (CandidateFrame <> CurrentFrame) or
     (MonitorSignalLevel(CandidateState) >= MonitorSignalLevel(CurrentState)) then
    Root^.LastLayer := CandidateLayer;
end;

procedure ResetInputSnapshot(var Snapshot: TAudioMonitorInputSnapshot);
begin
  FillChar(Snapshot, SizeOf(Snapshot), 0);
end;

procedure InitializeMonitorSlot(var State: TAul2AudioMonitorState; Layer: Integer);
begin
  FillChar(State, SizeOf(State), 0);
  State.Magic := AUDIO_MONITOR_SHARED_MAGIC;
  State.Version := AUDIO_MONITOR_SHARED_VERSION;
  State.UpdateTick := 0;
  State.Stage := 1;
  State.SourceLayer := Layer;
end;

procedure InitializeSpectrumSlot(var State: TAul2AudioMonitorSpectrumState; Layer: Integer);
begin
  FillChar(State, SizeOf(State), 0);
  State.Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
  State.Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
  State.UpdateTick := 0;
  State.SourceLayer := Layer;
  State.BandCount := AUDIO_MONITOR_SPECTRUM_BAND_COUNT;
  State.MinHz := 20;
  State.MaxHz := 20000;
end;

procedure InitializeVectorSlot(var State: TAul2AudioMonitorVectorState; Layer: Integer);
begin
  FillChar(State, SizeOf(State), 0);
  State.Magic := AUDIO_MONITOR_VECTOR_SHARED_MAGIC;
  State.Version := AUDIO_MONITOR_VECTOR_SHARED_VERSION;
  State.UpdateTick := 0;
  State.SourceLayer := Layer;
  State.PointCount := AUDIO_MONITOR_VECTOR_POINT_COUNT;
end;

procedure AudioMonitorInitialize;
var
  SharedRoot: PAul2AudioMonitorLayeredState;
  SpectrumRoot: PAul2AudioMonitorLayeredSpectrumState;
  VectorRoot: PAul2AudioMonitorLayeredVectorState;
  Layer: Integer;
  Index: Integer;
begin
  try
    SharedRoot := GetSharedMemory.Root;
    if SharedRoot = nil then
      Exit;

    SharedRoot^.Magic := AUDIO_MONITOR_SHARED_MAGIC;
    SharedRoot^.Version := AUDIO_MONITOR_SHARED_VERSION;
    SharedRoot^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
    FillChar(LastInputSnapshots, SizeOf(LastInputSnapshots), 0);
    for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
    begin
      SharedRoot^.HistoryIndex[Layer] := 0;
      InitializeMonitorSlot(SharedRoot^.Slots[Layer], Layer);
      for Index := 0 to AUDIO_MONITOR_HISTORY_LAST do
        InitializeMonitorSlot(SharedRoot^.History[Layer, Index], Layer);
    end;
    Inc(SharedRoot^.Generation);

    SpectrumRoot := GetSpectrumMemory.Root;
    if SpectrumRoot <> nil then
    begin
      SpectrumRoot^.Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
      SpectrumRoot^.Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
      SpectrumRoot^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
      for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
      begin
        SpectrumRoot^.HistoryIndex[Layer] := 0;
        InitializeSpectrumSlot(SpectrumRoot^.Slots[Layer], Layer);
        for Index := 0 to AUDIO_MONITOR_SPECTRUM_HISTORY_LAST do
          InitializeSpectrumSlot(SpectrumRoot^.History[Layer, Index], Layer);
      end;
      Inc(SpectrumRoot^.Generation);
    end;

    VectorRoot := GetVectorMemory.Root;
    if VectorRoot <> nil then
    begin
      VectorRoot^.Magic := AUDIO_MONITOR_VECTOR_SHARED_MAGIC;
      VectorRoot^.Version := AUDIO_MONITOR_VECTOR_SHARED_VERSION;
      VectorRoot^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
      VectorRoot^.RequestTick := 0;
      for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
      begin
        VectorRoot^.HistoryIndex[Layer] := 0;
        InitializeVectorSlot(VectorRoot^.Slots[Layer], Layer);
        for Index := 0 to AUDIO_MONITOR_VECTOR_HISTORY_LAST do
          InitializeVectorSlot(VectorRoot^.History[Layer, Index], Layer);
      end;
      Inc(VectorRoot^.Generation);
    end;
  except
    // 初期化疎通は補助機能なので、プラグインロードへ例外を漏らさない。
  end;
end;

procedure AudioMonitorSetStage(Stage: Integer; Audio: PFILTER_PROC_AUDIO);
var
  State: PAul2AudioMonitorState;
  Layer: Integer;
begin
  try
    Layer := AudioLayer(Audio);
    if Layer = AUDIO_MONITOR_LAYER_AUTO then
      Exit;

    State := GetSharedMemory.GetStateForLayer(Layer);
    if State = nil then
      Exit;

    State^.Magic := AUDIO_MONITOR_SHARED_MAGIC;
    State^.Version := AUDIO_MONITOR_SHARED_VERSION;
    State^.UpdateTick := GetTickCount64;
    State^.Stage := Stage;

    if (Audio <> nil) and (Audio^.Scene <> nil) then
      State^.SampleRate := Audio^.Scene^.SampleRate;

    if (Audio <> nil) and (Audio^.Object_ <> nil) then
    begin
      State^.SampleNum := Audio^.Object_^.SampleNum;
      State^.ChannelNum := Audio^.Object_^.ChannelNum;
      State^.SourceFrame := Audio^.Object_^.Frame;
      State^.SourceFrameS := Audio^.Object_^.FrameS;
      State^.SourceFrameE := Audio^.Object_^.FrameE;
      State^.SourceLayer := Audio^.Object_^.Layer;
      State^.SourceIndex := Audio^.Object_^.Index;
      State^.SampleIndex := Audio^.Object_^.SampleIndex;
    end;

    Inc(State^.Generation);
    Inc(GetSharedMemory.Root^.Generation);
  except
    // Monitor diagnostics must never affect the audio callback.
  end;
end;

function ReadChannel(Audio: PFILTER_PROC_AUDIO; SampleNum, Channel: Integer;
  out Buffer: TArray<Single>): Boolean;
begin
  Result := False;
  SetLength(Buffer, 0);

  if (Audio = nil) or not Assigned(Audio^.GetSampleData) or (SampleNum <= 0) then
    Exit;

  SetLength(Buffer, SampleNum);
  Audio^.GetSampleData(@Buffer[0], Channel);
  Result := True;
end;

procedure CaptureWave(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer;
  var Wave, WaveMin, WaveMax: TAudioMonitorWaveData;
  var VectorLeft, VectorRight: TAudioMonitorVectorData; CaptureVectors: Boolean;
  out PeakL, PeakR, RmsL, RmsR: Single);
var
  LeftBuffer: TArray<Single>;
  RightBuffer: TArray<Single>;
  I: Integer;
  Point: Integer;
  StartIndex: Integer;
  EndIndex: Integer;
  SampleIndex: Integer;
  Value: Single;
  Mixed: Single;
  BestValue: Single;
  BestAbs: Single;
  MinValue: Single;
  MaxValue: Single;
  SumSqL: Double;
  SumSqR: Double;
begin
  PeakL := 0;
  PeakR := 0;
  RmsL := 0;
  RmsR := 0;
  FillChar(Wave, SizeOf(Wave), 0);
  FillChar(WaveMin, SizeOf(WaveMin), 0);
  FillChar(WaveMax, SizeOf(WaveMax), 0);
  FillChar(VectorLeft, SizeOf(VectorLeft), 0);
  FillChar(VectorRight, SizeOf(VectorRight), 0);
  SumSqL := 0;
  SumSqR := 0;

  if not ReadChannel(Audio, SampleNum, 0, LeftBuffer) then
    Exit;

  if ChannelNum > 1 then
    ReadChannel(Audio, SampleNum, 1, RightBuffer);

  for I := 0 to SampleNum - 1 do
  begin
    Value := Abs(LeftBuffer[I]);
    if Value > PeakL then
      PeakL := Value;
    SumSqL := SumSqL + (LeftBuffer[I] * LeftBuffer[I]);

    if Length(RightBuffer) > I then
    begin
      Value := Abs(RightBuffer[I]);
      if Value > PeakR then
        PeakR := Value;
      SumSqR := SumSqR + (RightBuffer[I] * RightBuffer[I]);
    end;
  end;

  if ChannelNum <= 1 then
  begin
    PeakR := PeakL;
    SumSqR := SumSqL;
  end;

  RmsL := Sqrt(SumSqL / Max(1, SampleNum));
  RmsR := Sqrt(SumSqR / Max(1, SampleNum));

  for Point := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
  begin
    StartIndex := Point * SampleNum div AUDIO_MONITOR_WAVE_POINT_COUNT;
    EndIndex := (Point + 1) * SampleNum div AUDIO_MONITOR_WAVE_POINT_COUNT;
    if EndIndex <= StartIndex then
      EndIndex := StartIndex + 1;
    if EndIndex > SampleNum then
      EndIndex := SampleNum;

    BestValue := 0;
    BestAbs := 0;
    MinValue := 0;
    MaxValue := 0;
    for SampleIndex := StartIndex to EndIndex - 1 do
    begin
      Mixed := LeftBuffer[SampleIndex];
      if Length(RightBuffer) > SampleIndex then
        Mixed := (Mixed + RightBuffer[SampleIndex]) * 0.5;

      if SampleIndex = StartIndex then
      begin
        MinValue := Mixed;
        MaxValue := Mixed;
      end
      else
      begin
        if Mixed < MinValue then
          MinValue := Mixed;
        if Mixed > MaxValue then
          MaxValue := Mixed;
      end;

      Value := Abs(Mixed);
      if Value > BestAbs then
      begin
        BestAbs := Value;
        BestValue := Mixed;
      end;
    end;

    Wave[Point] := BestValue;
    WaveMin[Point] := MinValue;
    WaveMax[Point] := MaxValue;
  end;

  if CaptureVectors then
    for Point := 0 to AUDIO_MONITOR_VECTOR_POINT_LAST do
    begin
      SampleIndex := Min(SampleNum - 1,
        ((Point * 2 + 1) * SampleNum) div (AUDIO_MONITOR_VECTOR_POINT_COUNT * 2));
      VectorLeft[Point] := LeftBuffer[SampleIndex];
      if Length(RightBuffer) > SampleIndex then
        VectorRight[Point] := RightBuffer[SampleIndex]
      else
        VectorRight[Point] := LeftBuffer[SampleIndex];
    end;
end;

procedure ApplyAudioOutputLevel(Audio: PFILTER_PROC_AUDIO;
  var PeakL, PeakR, RmsL, RmsR: Single);
var
  AudioObject: OBJECT_HANDLE;
  OutputParam: TOBJECT_AUDIO_PARAM;
  LevelL: Single;
  LevelR: Single;
begin
  if Audio = nil then
    Exit;

  LevelL := 1;
  LevelR := 1;
  OutputParam := Default(TOBJECT_AUDIO_PARAM);
  if Assigned(Audio^.GetAudioObject) and Assigned(Audio^.GetOutputAudioParam) and
     (Audio^.Object_ <> nil) then
  begin
    AudioObject := Audio^.GetAudioObject(Audio^.Object_^.Layer, 0);
    if (AudioObject <> nil) and
       (Audio^.GetOutputAudioParam(AudioObject, 0, @OutputParam, SizeOf(OutputParam)) <> 0) then
    begin
      LevelL := Abs(OutputParam.VolL);
      LevelR := Abs(OutputParam.VolR);
    end
    else if Audio^.Param <> nil then
    begin
      LevelL := Abs(Audio^.Param^.VolL);
      LevelR := Abs(Audio^.Param^.VolR);
    end;
  end
  else if Audio^.Param <> nil then
  begin
    LevelL := Abs(Audio^.Param^.VolL);
    LevelR := Abs(Audio^.Param^.VolR);
  end;

  PeakL := PeakL * LevelL;
  PeakR := PeakR * LevelR;
  RmsL := RmsL * LevelL;
  RmsR := RmsR * LevelR;
end;

procedure EnsureSpectrumTable(SampleRate, TableSize: Integer);
var
  Band: Integer;
  Sample: Integer;
  Offset: Integer;
  FreqMin: Double;
  FreqMax: Double;
  Freq: Double;
  Angle: Double;
begin
  if (SampleRate = SpectrumTableSampleRate) and (TableSize = SpectrumTableSize) and
     (Length(SpectrumCosTable) = AUDIO_MONITOR_SPECTRUM_BAND_COUNT * TableSize) then
    Exit;

  SpectrumTableSampleRate := SampleRate;
  SpectrumTableSize := TableSize;
  SetLength(SpectrumCosTable, AUDIO_MONITOR_SPECTRUM_BAND_COUNT * TableSize);
  SetLength(SpectrumSinTable, AUDIO_MONITOR_SPECTRUM_BAND_COUNT * TableSize);

  FreqMin := 20.0;
  FreqMax := Min(20000.0, SampleRate * 0.5);
  if FreqMax <= FreqMin then
    FreqMax := FreqMin + 1.0;

  for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
  begin
    Freq := FreqMin * Power(FreqMax / FreqMin,
      (Band + 0.5) / AUDIO_MONITOR_SPECTRUM_BAND_COUNT);

    for Sample := 0 to TableSize - 1 do
    begin
      Offset := Band * TableSize + Sample;
      Angle := 2.0 * Pi * Freq * Sample / SampleRate;
      SpectrumCosTable[Offset] := Cos(Angle);
      SpectrumSinTable[Offset] := Sin(Angle);
    end;
  end;
end;

procedure CaptureSpectrum(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer;
  var Spectrum: TAudioMonitorSpectrumData);
const
  SPECTRUM_SAMPLE_COUNT = 1024;
  SPECTRUM_DB_FLOOR = -80.0;
var
  LeftBuffer: TArray<Single>;
  RightBuffer: TArray<Single>;
  WorkSize: Integer;
  Band: Integer;
  Sample: Integer;
  Offset: Integer;
  Window: Double;
  Mixed: Double;
  Re: Double;
  Im: Double;
  Mag: Double;
  Db: Double;
begin
  FillChar(Spectrum, SizeOf(Spectrum), 0);

  if (Audio = nil) or (Audio^.Scene = nil) or (SampleNum <= 0) then
    Exit;

  WorkSize := Min(SPECTRUM_SAMPLE_COUNT, SampleNum);
  if WorkSize <= 0 then
    Exit;

  if not ReadChannel(Audio, SampleNum, 0, LeftBuffer) then
    Exit;

  if ChannelNum > 1 then
    ReadChannel(Audio, SampleNum, 1, RightBuffer);

  EnsureSpectrumTable(Audio^.Scene^.SampleRate, WorkSize);

  for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
  begin
    Re := 0;
    Im := 0;

    for Sample := 0 to WorkSize - 1 do
    begin
      Mixed := LeftBuffer[Sample];
      if Length(RightBuffer) > Sample then
        Mixed := (Mixed + RightBuffer[Sample]) * 0.5;

      if WorkSize > 1 then
        Window := 0.5 - (0.5 * Cos(2.0 * Pi * Sample / (WorkSize - 1)))
      else
        Window := 1.0;

      Offset := Band * WorkSize + Sample;
      Re := Re + (Mixed * Window * SpectrumCosTable[Offset]);
      Im := Im - (Mixed * Window * SpectrumSinTable[Offset]);
    end;

    Mag := Sqrt((Re * Re) + (Im * Im)) / Max(1.0, WorkSize * 0.5);
    Db := 20.0 * Log10(Max(0.000001, Mag));
    Spectrum[Band] := Max(0.0, Min(1.0, (Db - SPECTRUM_DB_FLOOR) / -SPECTRUM_DB_FLOOR));
  end;
end;

procedure AudioMonitorCaptureInput(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer);
var
  CaptureVectors: Boolean;
  State: PAul2AudioMonitorState;
  Layer: Integer;
begin
  Layer := AUDIO_MONITOR_LAYER_AUTO;
  try
    Layer := AudioLayer(Audio);
    if Layer = AUDIO_MONITOR_LAYER_AUTO then
      Exit;

    CaptureVectors := VectorCaptureRequested;

    State := GetSharedMemory.GetStateForLayer(Layer);
    if State <> nil then
    begin
      State^.Stage := 2;
      State^.UpdateTick := GetTickCount64;
      State^.SourceLayer := Layer;
      Inc(State^.Generation);
      Inc(GetSharedMemory.Root^.Generation);
    end;

    CaptureWave(Audio, SampleNum, ChannelNum, LastInputSnapshots[Layer].Wave,
      LastInputSnapshots[Layer].WaveMin, LastInputSnapshots[Layer].WaveMax,
      LastInputSnapshots[Layer].VectorLeft, LastInputSnapshots[Layer].VectorRight,
      CaptureVectors,
      LastInputSnapshots[Layer].PeakL, LastInputSnapshots[Layer].PeakR,
      LastInputSnapshots[Layer].RmsL, LastInputSnapshots[Layer].RmsR);
    LastInputSnapshots[Layer].VectorValid := CaptureVectors;
    CaptureSpectrum(Audio, SampleNum, ChannelNum, LastInputSnapshots[Layer].Spectrum);
  except
    if (Layer >= 0) and (Layer <= AUDIO_MONITOR_LAYER_SLOT_LAST) then
      ResetInputSnapshot(LastInputSnapshots[Layer]);
  end;
end;

procedure AudioMonitorCaptureOutput(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer);
var
  CaptureVectors: Boolean;
  Shared: TAul2AudioMonitorSharedMemory;
  State: PAul2AudioMonitorState;
  OutputPeakL: Single;
  OutputPeakR: Single;
  OutputRmsL: Single;
  OutputRmsR: Single;
  OutputWave: TAudioMonitorWaveData;
  OutputWaveMin: TAudioMonitorWaveData;
  OutputWaveMax: TAudioMonitorWaveData;
  OutputVectorLeft: TAudioMonitorVectorData;
  OutputVectorRight: TAudioMonitorVectorData;
  OutputSpectrum: TAudioMonitorSpectrumData;
  SpectrumState: PAul2AudioMonitorSpectrumState;
  SpectrumRoot: PAul2AudioMonitorLayeredSpectrumState;
  VectorState: PAul2AudioMonitorVectorState;
  VectorRoot: PAul2AudioMonitorLayeredVectorState;
  Layer: Integer;
  InputSnapshot: TAudioMonitorInputSnapshot;
begin
  try
    Layer := AudioLayer(Audio);
    if Layer = AUDIO_MONITOR_LAYER_AUTO then
      Exit;

    CaptureVectors := VectorCaptureRequested;

    CaptureWave(Audio, SampleNum, ChannelNum, OutputWave, OutputWaveMin, OutputWaveMax,
      OutputVectorLeft, OutputVectorRight, CaptureVectors,
      OutputPeakL, OutputPeakR, OutputRmsL, OutputRmsR);
    ApplyAudioOutputLevel(Audio, OutputPeakL, OutputPeakR, OutputRmsL, OutputRmsR);
    CaptureSpectrum(Audio, SampleNum, ChannelNum, OutputSpectrum);

    Shared := GetSharedMemory;
    State := Shared.GetStateForLayer(Layer);
    if State = nil then
      Exit;

    InputSnapshot := LastInputSnapshots[Layer];
    ApplyAudioOutputLevel(Audio, InputSnapshot.PeakL, InputSnapshot.PeakR,
      InputSnapshot.RmsL, InputSnapshot.RmsR);
    AudioTraceMonitorPeaks(Audio, InputSnapshot.PeakL, InputSnapshot.PeakR,
      OutputPeakL, OutputPeakR);
    State^.Magic := AUDIO_MONITOR_SHARED_MAGIC;
    State^.Version := AUDIO_MONITOR_SHARED_VERSION;
    State^.UpdateTick := GetTickCount64;
    State^.Stage := 3;
    State^.SampleRate := Audio^.Scene^.SampleRate;
    State^.SampleNum := SampleNum;
    State^.ChannelNum := ChannelNum;
    State^.SourceFrame := Audio^.Object_^.Frame;
    State^.SourceFrameS := Audio^.Object_^.FrameS;
    State^.SourceFrameE := Audio^.Object_^.FrameE;
    State^.SourceLayer := Layer;
    State^.SourceIndex := Audio^.Object_^.Index;
    State^.SampleIndex := Audio^.Object_^.SampleIndex;
    State^.InputPeakL := InputSnapshot.PeakL;
    State^.InputPeakR := InputSnapshot.PeakR;
    State^.OutputPeakL := OutputPeakL;
    State^.OutputPeakR := OutputPeakR;
    State^.InputRmsL := InputSnapshot.RmsL;
    State^.InputRmsR := InputSnapshot.RmsR;
    State^.OutputRmsL := OutputRmsL;
    State^.OutputRmsR := OutputRmsR;
    State^.InputWave := InputSnapshot.Wave;
    State^.OutputWave := OutputWave;
    State^.InputWaveMin := InputSnapshot.WaveMin;
    State^.InputWaveMax := InputSnapshot.WaveMax;
    State^.OutputWaveMin := OutputWaveMin;
    State^.OutputWaveMax := OutputWaveMax;

    Inc(State^.Generation);
    SelectLastMonitorLayer(Shared.Root, Layer);
    PushMonitorHistory(Shared.Root, Layer, State^);
    Inc(Shared.Root^.Generation);

    SpectrumState := GetSpectrumMemory.GetStateForLayer(Layer);
    if SpectrumState <> nil then
    begin
      SpectrumRoot := GetSpectrumMemory.Root;
      SpectrumState^.Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
      SpectrumState^.Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
      SpectrumState^.UpdateTick := GetTickCount64;
      SpectrumState^.SampleRate := Audio^.Scene^.SampleRate;
      SpectrumState^.SampleNum := SampleNum;
      SpectrumState^.ChannelNum := ChannelNum;
      SpectrumState^.SourceFrame := Audio^.Object_^.Frame;
      SpectrumState^.SourceFrameS := Audio^.Object_^.FrameS;
      SpectrumState^.SourceFrameE := Audio^.Object_^.FrameE;
      SpectrumState^.SourceLayer := Layer;
      SpectrumState^.SourceIndex := Audio^.Object_^.Index;
      SpectrumState^.SampleIndex := Audio^.Object_^.SampleIndex;
      SpectrumState^.BandCount := AUDIO_MONITOR_SPECTRUM_BAND_COUNT;
      SpectrumState^.MinHz := 20;
      SpectrumState^.MaxHz := Min(20000, Audio^.Scene^.SampleRate * 0.5);
      SpectrumState^.InputBands := InputSnapshot.Spectrum;
      SpectrumState^.OutputBands := OutputSpectrum;
      Inc(SpectrumState^.Generation);
      if SpectrumRoot <> nil then
      begin
        SpectrumRoot^.LastLayer := Shared.Root^.LastLayer;
        PushSpectrumHistory(SpectrumRoot, Layer, SpectrumState^);
        Inc(SpectrumRoot^.Generation);
      end;
    end;

    if CaptureVectors and InputSnapshot.VectorValid then
    begin
      VectorState := GetVectorMemory.GetStateForLayer(Layer);
      if VectorState <> nil then
      begin
        VectorRoot := GetVectorMemory.Root;
        VectorState^.Magic := AUDIO_MONITOR_VECTOR_SHARED_MAGIC;
        VectorState^.Version := AUDIO_MONITOR_VECTOR_SHARED_VERSION;
        VectorState^.UpdateTick := GetTickCount64;
        VectorState^.SampleRate := Audio^.Scene^.SampleRate;
        VectorState^.SampleNum := SampleNum;
        VectorState^.ChannelNum := ChannelNum;
        VectorState^.SourceFrame := Audio^.Object_^.Frame;
        VectorState^.SourceFrameS := Audio^.Object_^.FrameS;
        VectorState^.SourceFrameE := Audio^.Object_^.FrameE;
        VectorState^.SourceLayer := Layer;
        VectorState^.SourceIndex := Audio^.Object_^.Index;
        VectorState^.SampleIndex := Audio^.Object_^.SampleIndex;
        VectorState^.PointCount := AUDIO_MONITOR_VECTOR_POINT_COUNT;
        VectorState^.InputLeft := InputSnapshot.VectorLeft;
        VectorState^.InputRight := InputSnapshot.VectorRight;
        VectorState^.OutputLeft := OutputVectorLeft;
        VectorState^.OutputRight := OutputVectorRight;
        Inc(VectorState^.Generation);
        if VectorRoot <> nil then
        begin
          VectorRoot^.LastLayer := Shared.Root^.LastLayer;
          PushVectorHistory(VectorRoot, Layer, VectorState^);
          Inc(VectorRoot^.Generation);
        end;
      end;
    end;
  except
    // モニター連携は補助機能なので、音声処理へ例外を漏らさない。
  end;
end;

procedure AudioMonitorFinalize;
begin
  SetLength(SpectrumCosTable, 0);
  SetLength(SpectrumSinTable, 0);
  FreeAndNil(VectorMemory);
  FreeAndNil(SpectrumMemory);
  FreeAndNil(SharedMemory);
end;

end.
