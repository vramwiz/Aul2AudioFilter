library Aul2AudioMonitor;

// AviUtl2 が読み込む汎用プラグインの最小 export 境界を定義する。

{$ALIGN 8}

uses
  Winapi.Windows,
  System.SysUtils,
  AviUtl2PluginTypes in 'Source\Lib\AviUtl2Plugin\AviUtl2PluginTypes.pas',
  AviUtl2PluginCore in 'Source\Lib\AviUtl2Plugin\AviUtl2PluginCore.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemory\SharedMemoryBase.pas',
  ToolBarPanelManager in 'Source\Lib\ToolBarPanelManager\ToolBarPanelManager.pas',
  DragAgent in 'Source\Lib\DragAgent\DragAgent.pas',
  Aul2AudioMonitorShared in 'Source\Lib\AudioMonitor\Aul2AudioMonitorShared.pas',
  Aul2AudioMonitorSpectrumShared in 'Source\Lib\AudioMonitor\Aul2AudioMonitorSpectrumShared.pas',
  Aul2AudioBaseAlias in 'Source\Aul2AudioBaseAlias.pas',
  Aul2AudioBaseCreate in 'Source\Aul2AudioBaseCreate.pas',
  Aul2AudioBasePanel in 'Source\Aul2AudioBasePanel.pas',
  Aul2AudioMonitorPaint in 'Source\Aul2AudioMonitorPaint.pas',
  Aul2AudioMonitorView in 'Source\Aul2AudioMonitorView.pas',
  Aul2AudioMonitorPlugin in 'Source\Aul2AudioMonitorPlugin.pas';

function InitializePlugin(Version: DWORD): BOOL; cdecl;
begin
  Result := True;
end;

procedure UninitializePlugin; cdecl;
begin
  UninitializeMonitorPlugin;
  EditHandle := nil;
  ProjectFile := nil;
  GAviUtl2Plugin := False;
end;

procedure RegisterPlugin(Host: PHostAppTable); cdecl;
begin
  try
    GAviUtl2Plugin := True;

    if Host = nil then
      Exit;

    Host^.SetPluginInformation('Aul2AudioMonitor audio waveform monitor');
    EditHandle := Host^.CreateEditHandle;
    RegisterMonitorPlugin(Host);
  except
    on E: Exception do
    begin
      EditHandle := nil;
      ProjectFile := nil;
      GAviUtl2Plugin := False;
    end;
  end;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  RegisterPlugin name 'RegisterPlugin';

begin
end.
