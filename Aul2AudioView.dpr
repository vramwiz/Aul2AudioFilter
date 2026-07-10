library Aul2AudioView;

// Defines the export boundary for the AviUtl2 view filter DLL.

{$ALIGN 8}

uses
  Winapi.Windows,
  Aul2AudioFilterTypes in 'Source\Lib\Aul2AudioFilterTypes.pas',
  Aul2AudioFilterGui in 'Source\Lib\Aul2AudioFilterGui.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemory\SharedMemoryBase.pas',
  Aul2AudioMonitorSpectrumShared in 'Source\Lib\AudioMonitor\Aul2AudioMonitorSpectrumShared.pas',
  Aul2AudioViewFrameShared in 'Source\Lib\AudioMonitor\Aul2AudioViewFrameShared.pas',
  AviUtl2GpuTextureOut in 'Source\Lib\AviUtl2GpuTextureOut.pas',
  Aul2AudioViewParams in 'Source\Aul2AudioViewParams.pas',
  Aul2AudioViewRenderUtils in 'Source\Aul2AudioViewRenderUtils.pas',
  Aul2AudioViewSpectrum in 'Source\Aul2AudioViewSpectrum.pas',
  Aul2AudioViewRenderEqualizer in 'Source\Aul2AudioViewRenderEqualizer.pas',
  Aul2AudioViewRender in 'Source\Aul2AudioViewRender.pas',
  Aul2AudioViewPlugin in 'Source\Aul2AudioViewPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  InitializeViewPlugin;
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizeViewPlugin;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetViewFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
