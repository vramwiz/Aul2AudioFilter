library Aul2AudioBaseInput;

uses
  Winapi.Windows,
  Aul2AudioBaseInputPlugin in 'Source\Aul2AudioBaseInputPlugin.pas',
  AviUtl2InputTypes in 'Source\Lib\AviUtl2Input\AviUtl2InputTypes.pas';

function func_open(FileName: LPCWSTR): INPUT_HANDLE; cdecl;
begin
  Result := BaseInputOpen(FileName);
end;

function func_close(Ih: INPUT_HANDLE): BOOL; cdecl;
begin
  Result := BaseInputClose(Ih);
end;

function func_info_get(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL; cdecl;
begin
  Result := BaseInputGetInfo(Ih, Info);
end;

function func_read_video(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer; cdecl;
begin
  Result := BaseInputReadVideo(Ih, Frame, Buf);
end;

function func_read_audio(Ih: INPUT_HANDLE; Start, Length: Integer; Buf: Pointer): Integer; cdecl;
begin
  Result := 0;
end;

function func_config(Hwnd: HWND; Hinst: HINST): BOOL; cdecl;
begin
  Result := BaseInputConfig(Hwnd, Hinst);
end;

var
  Plugin: TInputPluginTable = (
    flag: INPUT_PLUGIN_FLAG_VIDEO;
    name: 'Aul2AudioBaseInput';
    filefilter: 'Aul2Audio base (*.aul2base)'#0'*.aul2base'#0;
    information: 'Aul2AudioFilter base input plugin';
    func_open: func_open;
    func_close: func_close;
    func_info_get: func_info_get;
    func_read_video: func_read_video;
    func_read_audio: func_read_audio;
    func_config: func_config;
    func_set_track: nil;
    func_time_to_frame: nil
  );

function GetInputPluginTable: PInputPluginTable; cdecl;
begin
  Result := @Plugin;
end;

exports
  GetInputPluginTable name 'GetInputPluginTable';

begin
end.
