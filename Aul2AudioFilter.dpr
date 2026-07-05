library Aul2AudioFilter;

{$ALIGN 8}

uses
  Winapi.Windows,
  Aul2AudioFilterTypes in 'Lib\Aul2AudioFilterTypes.pas',
  Aul2AudioFilterGui in 'Lib\Aul2AudioFilterGui.pas',
  Aul2AudioFilterPlugin in 'Aul2AudioFilterPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
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
