library Aul2AudioController;

// AviUtl2 が読み込む Controller 拡張プラグインの最小 export 境界を定義する。

{$ALIGN 8}

uses
  Winapi.Windows,
  System.SysUtils,
  AviUtl2PluginTypes in 'Source\Lib\AviUtl2Plugin\AviUtl2PluginTypes.pas',
  AviUtl2PluginCore in 'Source\Lib\AviUtl2Plugin\AviUtl2PluginCore.pas',
  DragAgent in 'Source\Lib\DragAgent\DragAgent.pas',
  ListBoxEdit in 'Source\Lib\ListBoxEdit\ListBoxEdit.pas',
  ShortcutAction in 'Source\Lib\ShortcutAction\ShortcutAction.pas',
  Aul2AudioBaseAlias in 'Source\Aul2AudioBaseAlias.pas',
  Aul2AudioBaseCreate in 'Source\Aul2AudioBaseCreate.pas',
  Aul2AudioBasePanel in 'Source\Aul2AudioBasePanel.pas',
  Aul2AudioPresetModel in 'Source\Aul2AudioPresetModel.pas',
  Aul2AudioPresetPanel in 'Source\Aul2AudioPresetPanel.pas',
  SectionFileManager in 'Source\Lib\PresetSupport\Serialization\Section\SectionFileManager.pas',
  Aul2AudioControllerEffectDefinition in 'Source\Aul2AudioControllerEffectDefinition.pas',
  Aul2AudioControllerSync in 'Source\Aul2AudioControllerSync.pas',
  Aul2AudioControllerLampSwitch in 'Source\Aul2AudioControllerLampSwitch.pas',
  Aul2AudioControllerVolumeControl in 'Source\Aul2AudioControllerVolumeControl.pas',
  Aul2AudioControllerDelayGraph in 'Source\Aul2AudioControllerDelayGraph.pas',
  Aul2AudioControllerEqGraph in 'Source\Aul2AudioControllerEqGraph.pas',
  Aul2AudioControllerCompressorGraph in 'Source\Aul2AudioControllerCompressorGraph.pas',
  Aul2AudioControllerDistortionGraph in 'Source\Aul2AudioControllerDistortionGraph.pas',
  Aul2AudioControllerBitCrusherGraph in 'Source\Aul2AudioControllerBitCrusherGraph.pas',
  Aul2AudioControllerNoiseGateGraph in 'Source\Aul2AudioControllerNoiseGateGraph.pas',
  Aul2AudioControllerView in 'Source\Aul2AudioControllerView.pas',
  Aul2AudioControllerPlugin in 'Source\Aul2AudioControllerPlugin.pas';

function InitializePlugin(Version: DWORD): BOOL; cdecl;
begin
  // 実際のUI登録は Host を受け取れる RegisterPlugin で行う。
  Result := True;
end;

procedure UninitializePlugin; cdecl;
begin
  // AviUtl2 のSDKポインターより先に、Controllerのウィンドウを破棄する。
  UninitializeControllerPlugin;
  EditHandle := nil;
  ProjectFile := nil;
  GAviUtl2Plugin := False;
end;

procedure RegisterPlugin(Host: PHostAppTable); cdecl;
begin
  try
    // SDK境界から例外を漏らさず、登録途中の失敗時はグローバル参照を無効化する。
    GAviUtl2Plugin := True;

    if Host = nil then
      Exit;

    Host^.SetPluginInformation('Aul2AudioController effect parameter controller');
    EditHandle := Host^.CreateEditHandle;
    RegisterControllerPlugin(Host);
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
