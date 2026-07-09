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

var
  SharedMemory: TAul2AudioMonitorSharedMemory;
  SpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;
  LastInputPeakL: Single;
  LastInputPeakR: Single;
  LastInputRmsL: Single;
  LastInputRmsR: Single;
  LastInputWave: TAudioMonitorWaveData;
  LastInputWaveMin: TAudioMonitorWaveData;
  LastInputWaveMax: TAudioMonitorWaveData;
  LastInputSpectrum: TAudioMonitorSpectrumData;
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

procedure AudioMonitorInitialize;
var
  State: PAul2AudioMonitorState;
  SpectrumState: PAul2AudioMonitorSpectrumState;
begin
  try
    State := GetSharedMemory.State;
    if State = nil then
      Exit;

    State^.Magic := AUDIO_MONITOR_SHARED_MAGIC;
    State^.Version := AUDIO_MONITOR_SHARED_VERSION;
    State^.UpdateTick := GetTickCount64;
    State^.Stage := 1;
    State^.SampleRate := 0;
    State^.SampleNum := 0;
    State^.ChannelNum := 0;
    State^.SourceFrame := 0;
    State^.SourceFrameS := 0;
    State^.SourceFrameE := 0;
    State^.SourceLayer := 0;
    State^.SourceIndex := 0;
    State^.SampleIndex := 0;
    State^.InputPeakL := 0;
    State^.InputPeakR := 0;
    State^.OutputPeakL := 0;
    State^.OutputPeakR := 0;
    State^.InputRmsL := 0;
    State^.InputRmsR := 0;
    State^.OutputRmsL := 0;
    State^.OutputRmsR := 0;
    FillChar(State^.InputWave, SizeOf(State^.InputWave), 0);
    FillChar(State^.OutputWave, SizeOf(State^.OutputWave), 0);
    FillChar(State^.InputWaveMin, SizeOf(State^.InputWaveMin), 0);
    FillChar(State^.InputWaveMax, SizeOf(State^.InputWaveMax), 0);
    FillChar(State^.OutputWaveMin, SizeOf(State^.OutputWaveMin), 0);
    FillChar(State^.OutputWaveMax, SizeOf(State^.OutputWaveMax), 0);
    Inc(State^.Generation);

    SpectrumState := GetSpectrumMemory.State;
    if SpectrumState <> nil then
    begin
      SpectrumState^.Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
      SpectrumState^.Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
      SpectrumState^.UpdateTick := GetTickCount64;
      SpectrumState^.SampleRate := 0;
      SpectrumState^.SampleNum := 0;
      SpectrumState^.ChannelNum := 0;
      SpectrumState^.SourceFrame := 0;
      SpectrumState^.SourceFrameS := 0;
      SpectrumState^.SourceFrameE := 0;
      SpectrumState^.SourceLayer := 0;
      SpectrumState^.SourceIndex := 0;
      SpectrumState^.SampleIndex := 0;
      SpectrumState^.BandCount := AUDIO_MONITOR_SPECTRUM_BAND_COUNT;
      SpectrumState^.MinHz := 20;
      SpectrumState^.MaxHz := 20000;
      FillChar(SpectrumState^.InputBands, SizeOf(SpectrumState^.InputBands), 0);
      FillChar(SpectrumState^.OutputBands, SizeOf(SpectrumState^.OutputBands), 0);
      Inc(SpectrumState^.Generation);
    end;
  except
    // 初期化疎通は補助機能なので、プラグインロードへ例外を漏らさない。
  end;
end;

procedure AudioMonitorSetStage(Stage: Integer; Audio: PFILTER_PROC_AUDIO);
var
  State: PAul2AudioMonitorState;
begin
  try
    State := GetSharedMemory.State;
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
begin
  try
    State := GetSharedMemory.State;
    if State <> nil then
      State^.Stage := 2;

    CaptureWave(Audio, SampleNum, ChannelNum, LastInputWave, LastInputWaveMin,
      LastInputWaveMax, LastInputPeakL, LastInputPeakR, LastInputRmsL, LastInputRmsR);
    CaptureSpectrum(Audio, SampleNum, ChannelNum, LastInputSpectrum);
  except
    LastInputPeakL := 0;
    LastInputPeakR := 0;
    LastInputRmsL := 0;
    LastInputRmsR := 0;
    FillChar(LastInputWave, SizeOf(LastInputWave), 0);
    FillChar(LastInputWaveMin, SizeOf(LastInputWaveMin), 0);
    FillChar(LastInputWaveMax, SizeOf(LastInputWaveMax), 0);
    FillChar(LastInputSpectrum, SizeOf(LastInputSpectrum), 0);
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
begin
  try
    CaptureWave(Audio, SampleNum, ChannelNum, OutputWave, OutputWaveMin, OutputWaveMax,
      OutputPeakL, OutputPeakR, OutputRmsL, OutputRmsR);
    CaptureSpectrum(Audio, SampleNum, ChannelNum, OutputSpectrum);

    Shared := GetSharedMemory;
    State := Shared.State;
    if State = nil then
      Exit;

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
    State^.SourceLayer := Audio^.Object_^.Layer;
    State^.SourceIndex := Audio^.Object_^.Index;
    State^.SampleIndex := Audio^.Object_^.SampleIndex;
    State^.InputPeakL := LastInputPeakL;
    State^.InputPeakR := LastInputPeakR;
    State^.OutputPeakL := OutputPeakL;
    State^.OutputPeakR := OutputPeakR;
    State^.InputRmsL := LastInputRmsL;
    State^.InputRmsR := LastInputRmsR;
    State^.OutputRmsL := OutputRmsL;
    State^.OutputRmsR := OutputRmsR;
    State^.InputWave := LastInputWave;
    State^.OutputWave := OutputWave;
    State^.InputWaveMin := LastInputWaveMin;
    State^.InputWaveMax := LastInputWaveMax;
    State^.OutputWaveMin := OutputWaveMin;
    State^.OutputWaveMax := OutputWaveMax;

    Inc(State^.Generation);

    SpectrumState := GetSpectrumMemory.State;
    if SpectrumState <> nil then
    begin
      SpectrumState^.Magic := AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC;
      SpectrumState^.Version := AUDIO_MONITOR_SPECTRUM_SHARED_VERSION;
      SpectrumState^.UpdateTick := GetTickCount64;
      SpectrumState^.SampleRate := Audio^.Scene^.SampleRate;
      SpectrumState^.SampleNum := SampleNum;
      SpectrumState^.ChannelNum := ChannelNum;
      SpectrumState^.SourceFrame := Audio^.Object_^.Frame;
      SpectrumState^.SourceFrameS := Audio^.Object_^.FrameS;
      SpectrumState^.SourceFrameE := Audio^.Object_^.FrameE;
      SpectrumState^.SourceLayer := Audio^.Object_^.Layer;
      SpectrumState^.SourceIndex := Audio^.Object_^.Index;
      SpectrumState^.SampleIndex := Audio^.Object_^.SampleIndex;
      SpectrumState^.BandCount := AUDIO_MONITOR_SPECTRUM_BAND_COUNT;
      SpectrumState^.MinHz := 20;
      SpectrumState^.MaxHz := Min(20000, Audio^.Scene^.SampleRate * 0.5);
      SpectrumState^.InputBands := LastInputSpectrum;
      SpectrumState^.OutputBands := OutputSpectrum;
      Inc(SpectrumState^.Generation);
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
