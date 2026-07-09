unit AviUtl2InputTypes;

interface

uses
  Winapi.MMSystem,
  Winapi.Windows;

type
  LPCWSTR = PWideChar;
  INPUT_HANDLE = Pointer;
  PBITMAPINFOHEADER = ^BITMAPINFOHEADER;

  PWAVEFORMATEX = ^WAVEFORMATEX;
  WAVEFORMATEX = packed record
    wFormatTag: Word;
    nChannels: Word;
    nSamplesPerSec: Cardinal;
    nAvgBytesPerSec: Cardinal;
    nBlockAlign: Word;
    wBitsPerSample: Word;
    cbSize: Word;
  end;

const
  INPUT_INFO_FLAG_VIDEO = 1;
  INPUT_INFO_FLAG_AUDIO = 2;
  INPUT_INFO_FLAG_TIME_TO_FRAME = 16;

type
  PInputInfo = ^TInputInfo;
  TInputInfo = record
    flag: Integer;
    rate: Integer;
    scale: Integer;
    n: Integer;
    format: PBITMAPINFOHEADER;
    format_size: Integer;
    audio_n: Integer;
    audio_format: PWAVEFORMATEX;
    audio_format_size: Integer;
  end;

const
  INPUT_PLUGIN_FLAG_VIDEO = 1;
  INPUT_PLUGIN_FLAG_AUDIO = 2;
  INPUT_PLUGIN_FLAG_CONCURRENT = 16;
  INPUT_PLUGIN_FLAG_MULTI_TRACK = 32;
  INPUT_PLUGIN_TRACK_TYPE_VIDEO = 0;
  INPUT_PLUGIN_TRACK_TYPE_AUDIO = 1;

type
  PInputPluginTable = ^TInputPluginTable;
  TInputPluginTable = record
    flag: Integer;
    name: LPCWSTR;
    filefilter: LPCWSTR;
    information: LPCWSTR;
    func_open: function(FileName: LPCWSTR): INPUT_HANDLE; cdecl;
    func_close: function(Ih: INPUT_HANDLE): BOOL; cdecl;
    func_info_get: function(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL; cdecl;
    func_read_video: function(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer; cdecl;
    func_read_audio: function(Ih: INPUT_HANDLE; Start, Length: Integer; Buf: Pointer): Integer; cdecl;
    func_config: function(Hwnd: HWND; Hinst: HINST): BOOL; cdecl;
    func_set_track: function(Ih: INPUT_HANDLE; MediaType, Index: Integer): Integer; cdecl;
    func_time_to_frame: function(Ih: INPUT_HANDLE; Time: Double): Integer; cdecl;
  end;

implementation

end.
