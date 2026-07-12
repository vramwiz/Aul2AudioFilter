unit Aul2AudioFilterAudioTrace;

// FilterProcAudio の呼び出し単位を調べるための一時診断ログ。

interface

uses
  Aul2AudioFilterTypes;

procedure AudioTraceInitialize;
procedure AudioTraceProcAudio(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer);
procedure AudioTraceMonitorPeaks(Audio: PFILTER_PROC_AUDIO;
  InputPeakL, InputPeakR, OutputPeakL, OutputPeakR: Single);
procedure AudioTraceFinalize;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.IOUtils;

const
  TRACE_ENABLE_FILE_NAME = 'Aul2AudioFilterAudioTrace.enable';
  TRACE_LOG_FILE_NAME = 'Aul2AudioFilterAudioTrace.log';
  TRACE_ENABLE_CHECK_INTERVAL_MS = 500;
  TRACE_MAX_LINES = 2048;

var
  TraceEnabled: Boolean;
  TraceHeaderWritten: Boolean;
  TraceLimitWritten: Boolean;
  TraceLineCount: Integer;
  NextEnableCheckTick: UInt64;

function TraceEnablePath: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, TRACE_ENABLE_FILE_NAME);
end;

function TraceLogPath: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, TRACE_LOG_FILE_NAME);
end;

procedure AppendTraceLine(const Line: string);
begin
  TFile.AppendAllText(TraceLogPath, Line + sLineBreak, TEncoding.UTF8);
end;

function RefreshTraceEnabled: Boolean;
var
  Tick: UInt64;
begin
  Tick := GetTickCount64;
  if Tick >= NextEnableCheckTick then
  begin
    TraceEnabled := TFile.Exists(TraceEnablePath);
    NextEnableCheckTick := Tick + TRACE_ENABLE_CHECK_INTERVAL_MS;
  end;

  Result := TraceEnabled;
end;

procedure EnsureTraceHeader;
begin
  if TraceHeaderWritten then
    Exit;

  AppendTraceLine('tick,count,id,effect_id,layer,index,num,frame,frame_s,frame_e,sample_index,sample_num,sample_total,channel_num,scene_rate,param_l,param_r,output_l,output_r');
  TraceHeaderWritten := True;
end;

procedure AudioTraceInitialize;
begin
  TraceEnabled := False;
  TraceHeaderWritten := False;
  TraceLimitWritten := False;
  TraceLineCount := 0;
  NextEnableCheckTick := 0;
end;

procedure AudioTraceProcAudio(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer);
var
  Obj: POBJECT_INFO;
  AudioObject: OBJECT_HANDLE;
  OutputParam: TOBJECT_AUDIO_PARAM;
  ParamL: Single;
  ParamR: Single;
  OutputL: Single;
  OutputR: Single;
  SceneRate: Integer;
begin
  try
    if not RefreshTraceEnabled then
      Exit;

    if TraceLineCount >= TRACE_MAX_LINES then
    begin
      if not TraceLimitWritten then
      begin
        AppendTraceLine(Format('trace limit reached: %d lines', [TRACE_MAX_LINES]));
        TraceLimitWritten := True;
      end;
      Exit;
    end;

    EnsureTraceHeader;

    Obj := nil;
    ParamL := -999;
    ParamR := -999;
    OutputL := -999;
    OutputR := -999;
    if (Audio <> nil) and (Audio^.Object_ <> nil) then
      Obj := Audio^.Object_;
    if (Audio <> nil) and (Audio^.Param <> nil) then
    begin
      ParamL := Audio^.Param^.VolL;
      ParamR := Audio^.Param^.VolR;
    end;
    if (Audio <> nil) and (Obj <> nil) and Assigned(Audio^.GetAudioObject) and
       Assigned(Audio^.GetOutputAudioParam) then
    begin
      AudioObject := Audio^.GetAudioObject(Obj^.Layer, 0);
      OutputParam := Default(TOBJECT_AUDIO_PARAM);
      if (AudioObject <> nil) and
         (Audio^.GetOutputAudioParam(AudioObject, 0, @OutputParam, SizeOf(OutputParam)) <> 0) then
      begin
        OutputL := OutputParam.VolL;
        OutputR := OutputParam.VolR;
      end;
    end;

    SceneRate := 0;
    if (Audio <> nil) and (Audio^.Scene <> nil) then
      SceneRate := Audio^.Scene^.SampleRate;

    if Obj = nil then
      AppendTraceLine(Format('%d,%d,nil,nil,nil,nil,nil,nil,nil,nil,nil,%d,nil,%d,%d',
        [GetTickCount64, TraceLineCount + 1, SampleNum, ChannelNum, SceneRate]))
    else
      AppendTraceLine(Format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f',
        [
          GetTickCount64,
          TraceLineCount + 1,
          Obj^.ID,
          Obj^.EffectID,
          Obj^.Layer,
          Obj^.Index,
          Obj^.Num,
          Obj^.Frame,
          Obj^.FrameS,
          Obj^.FrameE,
          Obj^.SampleIndex,
          SampleNum,
          Obj^.SampleTotal,
          ChannelNum,
          SceneRate,
          ParamL,
          ParamR,
          OutputL,
          OutputR
        ]));

    Inc(TraceLineCount);
  except
    // 診断ログは補助機能なので、音声処理へ例外を漏らさない。
  end;
end;

procedure AudioTraceFinalize;
begin
  TraceEnabled := False;
end;

procedure AudioTraceMonitorPeaks(Audio: PFILTER_PROC_AUDIO;
  InputPeakL, InputPeakR, OutputPeakL, OutputPeakR: Single);
var
  Obj: POBJECT_INFO;
begin
  try
    if not RefreshTraceEnabled or (Audio = nil) or (Audio^.Object_ = nil) then
      Exit;

    Obj := Audio^.Object_;
    AppendTraceLine(Format('peaks,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f',
      [Obj^.ID, Obj^.EffectID, Obj^.Layer, Obj^.Frame,
       InputPeakL, InputPeakR, OutputPeakL, OutputPeakR]));
  except
    // 診断ログは音声処理へ影響させない。
  end;
end;

end.
