library Aul2AudioFilter;

// AviUtl2 が読み込む DLL の export 境界を定義する。

{$ALIGN 8}

uses
  Winapi.Windows,
  Aul2AudioFilterTypes in 'Source\Lib\Aul2AudioFilterTypes.pas',
  Aul2AudioFilterGui in 'Source\Lib\Aul2AudioFilterGui.pas',
  Aul2AudioFilterPluginPreset in 'Source\Aul2AudioFilterPluginPreset.pas',
  Aul2AudioFilterPluginDelay in 'Source\Aul2AudioFilterPluginDelay.pas',
  Aul2AudioFilterPluginEq in 'Source\Aul2AudioFilterPluginEq.pas',
  Aul2AudioFilterPluginCompressor in 'Source\Aul2AudioFilterPluginCompressor.pas',
  Aul2AudioFilterPluginVoiceDrive in 'Source\Aul2AudioFilterPluginVoiceDrive.pas',
  Aul2AudioFilterPluginDistortion in 'Source\Aul2AudioFilterPluginDistortion.pas',
  Aul2AudioFilterPluginNoise in 'Source\Aul2AudioFilterPluginNoise.pas',
  Aul2AudioFilterPluginBitCrusher in 'Source\Aul2AudioFilterPluginBitCrusher.pas',
  Aul2AudioFilterPluginTremble in 'Source\Aul2AudioFilterPluginTremble.pas',
  Aul2AudioFilterPluginWobble in 'Source\Aul2AudioFilterPluginWobble.pas',
  Aul2AudioFilterPluginPitch in 'Source\Aul2AudioFilterPluginPitch.pas',
  Aul2AudioFilterPluginRingMod in 'Source\Aul2AudioFilterPluginRingMod.pas',
  Aul2AudioFilterPluginMuffle in 'Source\Aul2AudioFilterPluginMuffle.pas',
  Aul2AudioFilterPluginWhisper in 'Source\Aul2AudioFilterPluginWhisper.pas',
  Aul2AudioFilterPluginAutoGain in 'Source\Aul2AudioFilterPluginAutoGain.pas',
  Aul2AudioFilterPluginNoiseGate in 'Source\Aul2AudioFilterPluginNoiseGate.pas',
  Aul2AudioFilterPluginGhost in 'Source\Aul2AudioFilterPluginGhost.pas',
  Aul2AudioFilterPluginOutput in 'Source\Aul2AudioFilterPluginOutput.pas',
  Aul2AudioFilterPluginLimiter in 'Source\Aul2AudioFilterPluginLimiter.pas',
  Aul2AudioFilterPluginChorus in 'Source\Aul2AudioFilterPluginChorus.pas',
  Aul2AudioFilterPluginReverb in 'Source\Aul2AudioFilterPluginReverb.pas',
  Aul2AudioFilterContextManager in 'Source\Aul2AudioFilterContextManager.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemory\SharedMemoryBase.pas',
  Aul2AudioMonitorShared in 'Source\Lib\AudioMonitor\Aul2AudioMonitorShared.pas',
  Aul2AudioMonitorSpectrumShared in 'Source\Lib\AudioMonitor\Aul2AudioMonitorSpectrumShared.pas',
  Aul2AudioViewVectorShared in 'Source\Lib\AudioMonitor\Aul2AudioViewVectorShared.pas',
  Aul2AudioFilterMonitorBridge in 'Source\Aul2AudioFilterMonitorBridge.pas',
  Aul2AudioFilterPlugin in 'Source\Aul2AudioFilterPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  InitializeFilterPlugin;
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizeFilterPlugin;
  // エフェクト状態は各ユニット側で Use OFF や不連続検出時に破棄する。
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
