unit AviUtl2InputTypes;

// AviUtl2 入力プラグインSDKの構造体とコールバックを Delphi のABI配置で定義する。

interface

uses
  Winapi.MMSystem,
  Winapi.Windows;

type
  LPCWSTR           = PWideChar; // SDK側の変更不可Wide文字列ポインター。
  INPUT_HANDLE      = Pointer;   // 入力ごとの不透明コンテキストハンドル。
  PBITMAPINFOHEADER = ^BITMAPINFOHEADER;

  // 音声入力が使うWAVEFORMATEXの固定ABI配置。
  PWAVEFORMATEX = ^WAVEFORMATEX;
  WAVEFORMATEX = packed record
    wFormatTag      : Word;     // 音声形式タグ。
    nChannels       : Word;     // チャンネル数。
    nSamplesPerSec  : Cardinal; // 1秒当たりのサンプル数。
    nAvgBytesPerSec : Cardinal; // 1秒当たりの平均バイト数。
    nBlockAlign     : Word;     // 1サンプルフレームのバイト数。
    wBitsPerSample  : Word;     // 1チャンネル当たりの量子化ビット数。
    cbSize          : Word;     // 後続する拡張情報のバイト数。
  end;

const
  INPUT_INFO_FLAG_VIDEO         = 1;  // 映像ストリームを持つ。
  INPUT_INFO_FLAG_AUDIO         = 2;  // 音声ストリームを持つ。
  INPUT_INFO_FLAG_TIME_TO_FRAME = 16; // 時刻からフレームへの変換に対応する。

type
  // 開いた入力のストリーム仕様と総サンプル数を AviUtl2 へ返す。
  PInputInfo = ^TInputInfo;
  TInputInfo = record
    flag             : Integer;           // INPUT_INFO_FLAG_* の組み合わせ。
    rate             : Integer;           // フレームレートの分子。
    scale            : Integer;           // フレームレートの分母。
    n                : Integer;           // 総フレーム数。
    format           : PBITMAPINFOHEADER; // 映像形式情報へのポインター。
    format_size      : Integer;           // 映像形式情報のバイト数。
    audio_n          : Integer;           // 総音声サンプル数。
    audio_format     : PWAVEFORMATEX;     // 音声形式情報へのポインター。
    audio_format_size: Integer;           // 音声形式情報のバイト数。
  end;

const
  INPUT_PLUGIN_FLAG_VIDEO      = 1;  // 映像入力に対応する。
  INPUT_PLUGIN_FLAG_AUDIO      = 2;  // 音声入力に対応する。
  INPUT_PLUGIN_FLAG_CONCURRENT = 16; // 複数入力の並行処理に対応する。
  INPUT_PLUGIN_FLAG_MULTI_TRACK = 32; // 複数トラック選択に対応する。
  INPUT_PLUGIN_TRACK_TYPE_VIDEO = 0;  // 映像トラック種別。
  INPUT_PLUGIN_TRACK_TYPE_AUDIO = 1;  // 音声トラック種別。

type
  // AviUtl2へ公開する入力プラグイン情報と各処理コールバック。
  PInputPluginTable = ^TInputPluginTable;
  TInputPluginTable = record
    flag              : Integer; // INPUT_PLUGIN_FLAG_* の組み合わせ。
    name              : LPCWSTR; // 入力プラグインの表示名。
    filefilter        : LPCWSTR; // 対応拡張子を示す二重nil終端フィルター。
    information       : LPCWSTR; // プラグイン情報表示用の説明。
    func_open         : function(FileName: LPCWSTR): INPUT_HANDLE; cdecl; // 入力を開く。
    func_close        : function(Ih: INPUT_HANDLE): BOOL; cdecl; // 入力を閉じる。
    func_info_get     : function(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL; cdecl; // 仕様を返す。
    func_read_video   : function(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer; cdecl; // 映像を読む。
    func_read_audio   : function(Ih: INPUT_HANDLE; Start, Length: Integer; Buf: Pointer): Integer; cdecl; // 音声。
    func_config       : function(Hwnd: HWND; Hinst: HINST): BOOL; cdecl; // 設定画面を開く。
    func_set_track    : function(Ih: INPUT_HANDLE; MediaType, Index: Integer): Integer; cdecl; // トラックを選ぶ。
    func_time_to_frame: function(Ih: INPUT_HANDLE; Time: Double): Integer; cdecl; // 時刻をフレームへ変換。
  end;

implementation

end.
