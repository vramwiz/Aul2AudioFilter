library Aul2AudioFilter;

// AviUtl2 が読み込む DLL の export 境界を定義する。

{$ALIGN 8}

uses
  Winapi.Windows,
  Aul2AudioFilterTypes in 'Lib\Aul2AudioFilterTypes.pas',
  Aul2AudioFilterGui in 'Lib\Aul2AudioFilterGui.pas',
  Aul2AudioFilterPluginDelay in 'Aul2AudioFilterPluginDelay.pas',
  Aul2AudioFilterPluginChorus in 'Aul2AudioFilterPluginChorus.pas',
  Aul2AudioFilterPluginReverb in 'Aul2AudioFilterPluginReverb.pas',
  Aul2AudioFilterPlugin in 'Aul2AudioFilterPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  // 現時点では初期化時に確保する共有リソースはない。
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
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
