library Aul2AudioView;

// Defines the export boundary for the AviUtl2 view filter DLL.

{$ALIGN 8}

uses
  Winapi.Windows,
  Aul2AudioFilterTypes in 'Source\Lib\Aul2AudioFilterTypes.pas',
  Aul2AudioFilterGui in 'Source\Lib\Aul2AudioFilterGui.pas',
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
