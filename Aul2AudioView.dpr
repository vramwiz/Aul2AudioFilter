library Aul2AudioView;

// Aul2AudioView の DLL エントリポイントを公開し、プラグイン本体の初期化と終了処理へ中継する。

{$ALIGN 8}

uses
  Winapi.Windows,
  Aul2AudioFilterTypes in 'Source\Lib\Aul2AudioFilterTypes.pas',
  Aul2AudioFilterGui in 'Source\Lib\Aul2AudioFilterGui.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemory\SharedMemoryBase.pas',
  Aul2AudioMonitorShared in 'Source\Lib\AudioMonitor\Aul2AudioMonitorShared.pas',
  Aul2AudioMonitorSpectrumShared in 'Source\Lib\AudioMonitor\Aul2AudioMonitorSpectrumShared.pas',
  Aul2AudioViewFrameShared in 'Source\Lib\AudioMonitor\Aul2AudioViewFrameShared.pas',
  Aul2AudioViewVectorShared in 'Source\Lib\AudioMonitor\Aul2AudioViewVectorShared.pas',
  AviUtl2GpuTextureOut in 'Source\Lib\AviUtl2GpuTextureOut.pas',
  Aul2ColorUtils in 'Source\Lib\Color\Aul2ColorUtils.pas',
  Aul2ColorPalette in 'Source\Lib\Color\Aul2ColorPalette.pas',
  Aul2AudioViewParams in 'Source\Aul2AudioViewParams.pas',
  Aul2AudioViewRenderUtils in 'Source\Aul2AudioViewRenderUtils.pas',
  Aul2AudioViewSpectrum in 'Source\Aul2AudioViewSpectrum.pas',
  Aul2AudioViewRenderEqualizer in 'Source\Aul2AudioViewRenderEqualizer.pas',
  Aul2AudioViewRenderFilledSpectrum in 'Source\Aul2AudioViewRenderFilledSpectrum.pas',
  Aul2AudioViewRenderCircularSpectrum in 'Source\Aul2AudioViewRenderCircularSpectrum.pas',
  Aul2AudioViewRenderCircular3D in 'Source\Aul2AudioViewRenderCircular3D.pas',
  Aul2AudioViewRenderMirrorBars in 'Source\Aul2AudioViewRenderMirrorBars.pas',
  Aul2AudioViewWave in 'Source\Aul2AudioViewWave.pas',
  Aul2AudioViewRenderWaveLine in 'Source\Aul2AudioViewRenderWaveLine.pas',
  Aul2AudioViewRenderPixelWave in 'Source\Aul2AudioViewRenderPixelWave.pas',
  Aul2AudioViewRenderPulseWave in 'Source\Aul2AudioViewRenderPulseWave.pas',
  Aul2AudioViewRenderRadialWaveform3D in 'Source\Aul2AudioViewRenderRadialWaveform3D.pas',
  Aul2AudioViewRenderSpectrumLandscape3D in 'Source\Aul2AudioViewRenderSpectrumLandscape3D.pas',
  Aul2AudioViewRenderSpectrumWaterfall3D in 'Source\Aul2AudioViewRenderSpectrumWaterfall3D.pas',
  Aul2AudioViewRenderWaveformTunnel3D in 'Source\Aul2AudioViewRenderWaveformTunnel3D.pas',
  Aul2AudioViewVector in 'Source\Aul2AudioViewVector.pas',
  Aul2AudioViewRenderVectorscope in 'Source\Aul2AudioViewRenderVectorscope.pas',
  Aul2AudioViewRenderVectorscopeTrail3D in 'Source\Aul2AudioViewRenderVectorscopeTrail3D.pas',
  Aul2AudioViewRender in 'Source\Aul2AudioViewRender.pas',
  Aul2AudioViewPlugin in 'Source\Aul2AudioViewPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  // Version は AviUtl2 側との将来の互換性確認用に受け取る。現行版では初期化処理だけを行う。
  InitializeViewPlugin;
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizeViewPlugin;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  // 登録テーブルの構築責務は Plugin ユニットへ集約し、DLL 境界ではポインターだけを返す。
  Result := GetViewFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
