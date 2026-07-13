unit Aul2AudioBaseInputPlugin;

// .aul2base のファイル名から映像仕様を復元し、透明な空フレームを返す入力処理を担当する。

interface

uses
  Winapi.Windows,
  AviUtl2InputTypes;

// 仮想ファイル名を解析して入力コンテキストを作り、失敗時は nil を返す。
function BaseInputOpen(FileName: LPCWSTR): INPUT_HANDLE;
// BaseInputOpen が確保した入力コンテキストを解放する。
function BaseInputClose(Ih: INPUT_HANDLE): BOOL;
// 解像度、フレームレート、総フレーム数、32bit映像形式を AviUtl2 へ返す。
function BaseInputGetInfo(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL;
// 指定フレーム用の32bit映像バッファを透明な黒で初期化し、書き込みバイト数を返す。
function BaseInputReadVideo(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer;
// 入力プラグインの簡易情報ダイアログを表示する。
function BaseInputConfig(Hwnd: HWND; Hinst: HINST): BOOL;

implementation

uses
  System.Math,
  System.SysUtils;

type
  // 1つの .aul2base 素材を開いている間だけ保持する映像仕様。
  PBaseInputContext = ^TBaseInputContext;
  TBaseInputContext = record
    Width : Integer;          // 出力映像の幅。
    Height: Integer;          // 出力映像の高さ。
    MaxSec: Double;           // 素材の最大秒数。
    Rate  : Integer;          // フレームレートの分子。
    Scale : Integer;          // フレームレートの分母。
    Info  : BITMAPINFOHEADER; // AviUtl2へ返す32bit BI_RGB形式情報。
  end;

procedure ParseBaseFileName(
  const FileName: string;
  out Width, Height: Integer;
  out MaxSec: Double;
  out Rate, Scale: Integer
);
var
  Base: string;
  Parts: TArray<string>;
  Fps: Double;
  P: Integer;
begin
  // 不完全なファイル名でも開けるよう、各値は一般的な映像仕様を既定値にする。
  Width := 1920;
  Height := 1080;
  MaxSec := 30.0;
  Fps := 30.0;
  Scale := 1;

  Base := ChangeFileExt(ExtractFileName(FileName), '');
  if Base = '' then
  begin
    Rate := Round(Fps * Scale);
    Exit;
  end;

  P := Pos(':', Base);
  if P > 0 then
    Base := Copy(Base, P + 1, MaxInt);

  // 仮想名は Width_Height_MaxSec_Fps_Scale の順で値を保持する。
  Parts := Base.Split(['_']);
  if Length(Parts) >= 2 then
  begin
    Width := StrToIntDef(Parts[0], Width);
    Height := StrToIntDef(Parts[1], Height);
  end;

  if Length(Parts) >= 3 then
    MaxSec := StrToFloatDef(Parts[2], MaxSec);

  if Length(Parts) >= 4 then
    Fps := StrToFloatDef(Parts[3], Fps);

  if Length(Parts) >= 5 then
    Scale := StrToIntDef(Parts[4], Scale);

  if Width <= 0 then
    Width := 1920;
  if Height <= 0 then
    Height := 1080;
  if MaxSec < 0 then
    MaxSec := 0;
  if Scale <= 0 then
    Scale := 1;

  Rate := Round(Fps * Scale);
  if Rate <= 0 then
    Rate := 30;
end;

function BaseInputOpen(FileName: LPCWSTR): INPUT_HANDLE;
var
  Ctx: PBaseInputContext;
begin
  New(Ctx);
  FillChar(Ctx^, SizeOf(Ctx^), 0);
  try
    ParseBaseFileName(string(FileName), Ctx^.Width, Ctx^.Height, Ctx^.MaxSec, Ctx^.Rate, Ctx^.Scale);

    Ctx^.Info.biSize := SizeOf(BITMAPINFOHEADER);
    Ctx^.Info.biWidth := Ctx^.Width;
    Ctx^.Info.biHeight := Ctx^.Height;
    Ctx^.Info.biPlanes := 1;
    // View フィルターが上に描画する土台なので、変換不要な32bit BI_RGBを返す。
    Ctx^.Info.biBitCount := 32;
    Ctx^.Info.biCompression := BI_RGB;
    Ctx^.Info.biSizeImage := Ctx^.Width * Ctx^.Height * 4;

    Result := Ctx;
  except
    Dispose(Ctx);
    Result := nil;
  end;
end;

function BaseInputClose(Ih: INPUT_HANDLE): BOOL;
begin
  Result := False;
  if Ih = nil then
    Exit;

  Dispose(PBaseInputContext(Ih));
  Result := True;
end;

function BaseInputGetInfo(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL;
var
  Ctx: PBaseInputContext;
begin
  Result := False;
  if (Ih = nil) or (Info = nil) then
    Exit;

  Ctx := PBaseInputContext(Ih);
  FillChar(Info^, SizeOf(TInputInfo), 0);
  Info^.flag := INPUT_INFO_FLAG_VIDEO;
  Info^.rate := Ctx^.Rate;
  Info^.scale := Ctx^.Scale;
  if (Info^.rate > 0) and (Info^.scale > 0) then
    Info^.n := Ceil(Ctx^.MaxSec * Info^.rate / Info^.scale)
  else
    Info^.n := 0;
  Info^.format := @Ctx^.Info;
  Info^.format_size := SizeOf(BITMAPINFOHEADER);

  Result := True;
end;

function BaseInputReadVideo(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer;
var
  Ctx: PBaseInputContext;
begin
  Result := 0;
  if (Ih = nil) or (Buf = nil) then
    Exit;

  Ctx := PBaseInputContext(Ih);
  // Frame に依存する内容は持たず、全フレームを同じ透明な土台として返す。
  FillChar(Buf^, Ctx^.Info.biSizeImage, 0);
  Result := Ctx^.Info.biSizeImage;
end;

function BaseInputConfig(Hwnd: HWND; Hinst: HINST): BOOL;
begin
  MessageBox(Hwnd, 'Aul2AudioBaseInput', 'Aul2AudioFilter', MB_OK);
  Result := True;
end;

end.
