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
  Aul2AudioMonitorShared,
  Aul2AudioMonitorSpectrumShared;

type
  TAudioMonitorInputSnapshot = record
    PeakL: Single;
    PeakR: Single;
    RmsL: Single;
    RmsR: Single;
    Wave: TAudioMonitorWaveData;
    WaveMin: TAudioMonitorWaveData;
    WaveMax: TAudioMonitorWaveData;
    Spectrum: TAudioMonitorSpectrumData;
  end;

var
  SharedMemory: TAul2AudioMonitorSharedMemory;
  SpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;
  LastInputSnapshots: array[0..AUDIO_MONITOR_LAYER_SLOT_LAST] of TAudioMonitorInputSnapshot;
  SpectrumCosTable: TArray<Single>;
  SpectrumSinTable: TArray<Single>;
  SpectrumTableSampleRate: Integer;
  SpectrumTableSize: Integer;

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

function AudioLayer(Audio: PFILTER_PROC_AUDIO): Integer;
begin
  if (Audio = nil) or (Audio^.Object_ = nil) then
    Exit(AUDIO_MONITOR_LAYER_AUTO);

  Result := Audio^.Object_^.Layer;
  if (Result < 0) or (Result > AUDIO_MONITOR_LAYER_SLOT_LAST) then
    Result := 0;
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

procedure AudioMonitorInitialize;
var
  SharedRoot: PAul2AudioMonitorLayeredState;
  SpectrumRoot: PAul2AudioMonitorLayeredSpectrumState;
  Layer: Integer;
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
      InitializeMonitorSlot(SharedRoot^.Slots[Layer], Layer);
    Inc(SharedRoot^.Generation);

    SpectrumRoot := GetSpectrumMemory.Root;
    if SpectrumRoot <> nil then
    begin
      SpectrumRoot^.Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
      SpectrumRoot^.Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
      SpectrumRoot^.LastLayer := AUDIO_MONITOR_LAYER_AUTO;
      for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
        InitializeSpectrumSlot(SpectrumRoot^.Slots[Layer], Layer);
      Inc(SpectrumRoot^.Generation);
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
    GetSharedMemory.Root^.LastLayer := Layer;
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
  var Wave, WaveMin, WaveMax: TAudioMonitorWaveData; out PeakL, PeakR, RmsL, RmsR: Single);
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
  State: PAul2AudioMonitorState;
  Layer: Integer;
begin
  Layer := AUDIO_MONITOR_LAYER_AUTO;
  try
    Layer := AudioLayer(Audio);
    if Layer = AUDIO_MONITOR_LAYER_AUTO then
      Exit;

    State := GetSharedMemory.GetStateForLayer(Layer);
    if State <> nil then
    begin
      State^.Stage := 2;
      State^.UpdateTick := GetTickCount64;
      State^.SourceLayer := Layer;
      Inc(State^.Generation);
      GetSharedMemory.Root^.LastLayer := Layer;
      Inc(GetSharedMemory.Root^.Generation);
    end;

    CaptureWave(Audio, SampleNum, ChannelNum, LastInputSnapshots[Layer].Wave,
      LastInputSnapshots[Layer].WaveMin, LastInputSnapshots[Layer].WaveMax,
      LastInputSnapshots[Layer].PeakL, LastInputSnapshots[Layer].PeakR,
      LastInputSnapshots[Layer].RmsL, LastInputSnapshots[Layer].RmsR);
    CaptureSpectrum(Audio, SampleNum, ChannelNum, LastInputSnapshots[Layer].Spectrum);
  except
    if (Layer >= 0) and (Layer <= AUDIO_MONITOR_LAYER_SLOT_LAST) then
      ResetInputSnapshot(LastInputSnapshots[Layer]);
  end;
end;

procedure AudioMonitorCaptureOutput(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer);
var
  Shared: TAul2AudioMonitorSharedMemory;
  State: PAul2AudioMonitorState;
  OutputPeakL: Single;
  OutputPeakR: Single;
  OutputRmsL: Single;
  OutputRmsR: Single;
  OutputWave: TAudioMonitorWaveData;
  OutputWaveMin: TAudioMonitorWaveData;
  OutputWaveMax: TAudioMonitorWaveData;
  OutputSpectrum: TAudioMonitorSpectrumData;
  SpectrumState: PAul2AudioMonitorSpectrumState;
  SpectrumRoot: PAul2AudioMonitorLayeredSpectrumState;
  Layer: Integer;
  InputSnapshot: TAudioMonitorInputSnapshot;
begin
  try
    Layer := AudioLayer(Audio);
    if Layer = AUDIO_MONITOR_LAYER_AUTO then
      Exit;

    CaptureWave(Audio, SampleNum, ChannelNum, OutputWave, OutputWaveMin, OutputWaveMax,
      OutputPeakL, OutputPeakR, OutputRmsL, OutputRmsR);
    CaptureSpectrum(Audio, SampleNum, ChannelNum, OutputSpectrum);

    Shared := GetSharedMemory;
    State := Shared.GetStateForLayer(Layer);
    if State = nil then
      Exit;

    InputSnapshot := LastInputSnapshots[Layer];
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
    Shared.Root^.LastLayer := Layer;
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
        SpectrumRoot^.LastLayer := Layer;
        Inc(SpectrumRoot^.Generation);
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
  FreeAndNil(SpectrumMemory);
  FreeAndNil(SharedMemory);
end;

end.
