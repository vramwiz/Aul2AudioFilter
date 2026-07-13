unit Aul2AudioBaseAlias;

{$WARN IMPLICIT_STRING_CAST OFF}

// Base素材の仮想ファイル名と、動画ファイル・映像再生・Viewを含むエイリアスを生成する。

interface

uses
  System.SysUtils;

type
  // Base素材と配置先を再現するためにエイリアスへ埋め込む設定。
  TAul2AudioBaseAliasParams = record
    Caption    : string;  // 仮想ファイル名の先頭へ使う素材名。
    Width      : Integer; // Base映像の幅。
    Height     : Integer; // Base映像の高さ。
    MaxSec     : Integer; // Base映像の最大秒数。
    Rate       : Integer; // フレームレートの分子。
    Scale      : Integer; // フレームレートの分母。
    Layer      : Integer; // 配置先の内部0-basedレイヤー。
    FrameStart : Integer; // 配置先の開始フレーム。
    FrameLength: Integer; // 配置する総フレーム数。
  end;

// 一般的な1920x1080、30秒、30fpsの初期設定を返す。
function DefaultBaseAliasParams: TAul2AudioBaseAliasParams;
// 入力プラグインが解析できる Width_Height_MaxSec_Rate_Scale 形式の仮想名を返す。
function BuildBaseVirtualFileName(const Params: TAul2AudioBaseAliasParams): string;
// AviUtl2の.object形式でBase素材とViewフィルターを構成する文字列を返す。
function BuildBaseAliasText(const Params: TAul2AudioBaseAliasParams): string;
// D&D用エイリアスを一時フォルダーへUTF-8で保存し、絶対パスを返す。
function SaveBaseAliasFile(const Params: TAul2AudioBaseAliasParams): string;
// 不正または不足した設定値を安全な既定値へ補正して返す。
function NormalizeBaseAliasParams(const Params: TAul2AudioBaseAliasParams): TAul2AudioBaseAliasParams;

implementation

uses
  System.Classes,
  System.IOUtils;

const
  BASE_ALIAS_TEMP_DIR  = 'Aul2AudioFilter';      // D&D用ファイルを置く一時サブフォルダー。
  BASE_ALIAS_FILE_NAME = 'Aul2AudioBase.object'; // D&Dで渡す固定エイリアス名。
  VIEW_FILTER_NAME     = 'Aul2Audio View';       // エイリアスへ追加する表示フィルター名。

function DefaultBaseAliasParams: TAul2AudioBaseAliasParams;
begin
  Result.Caption := 'Aul2AudioBase';
  Result.Width := 1920;
  Result.Height := 1080;
  Result.MaxSec := 30;
  Result.Rate := 30;
  Result.Scale := 1;
  Result.Layer := 0;
  Result.FrameStart := 0;
  Result.FrameLength := 900;
end;

function NormalizeBaseAliasParams(const Params: TAul2AudioBaseAliasParams): TAul2AudioBaseAliasParams;
begin
  Result := Params;

  if Result.Caption = '' then
    Result.Caption := 'Aul2AudioBase';
  if Result.Width <= 0 then
    Result.Width := 1920;
  if Result.Height <= 0 then
    Result.Height := 1080;
  if Result.MaxSec <= 0 then
    Result.MaxSec := 30;
  if Result.Rate <= 0 then
    Result.Rate := 30;
  if Result.Scale <= 0 then
    Result.Scale := 1;
  if Result.Layer < 0 then
    Result.Layer := 0;
  if Result.FrameStart < 0 then
    Result.FrameStart := 0;
  if Result.FrameLength <= 0 then
    Result.FrameLength := Result.MaxSec * Result.Rate div Result.Scale;
  if Result.FrameLength <= 0 then
    Result.FrameLength := 1;
end;

function BuildBaseVirtualFileName(const Params: TAul2AudioBaseAliasParams): string;
var
  P: TAul2AudioBaseAliasParams;
  BaseName: string;
begin
  P := NormalizeBaseAliasParams(Params);
  BaseName := ChangeFileExt(ExtractFileName(P.Caption), '');
  if BaseName = '' then
    BaseName := 'Aul2AudioBase';

  Result :=
    BaseName + ':' +
    IntToStr(P.Width) + '_' +
    IntToStr(P.Height) + '_' +
    IntToStr(P.MaxSec) + '_' +
    IntToStr(P.Rate) + '_' +
    IntToStr(P.Scale) + '.aul2base';
end;

procedure AddKeyValue(Strings: TStrings; const Key, Value: string); overload;
begin
  Strings.Add(Key + '=' + Value);
end;

procedure AddKeyValue(Strings: TStrings; const Key: string; Value: Integer); overload;
begin
  Strings.Add(Key + '=' + IntToStr(Value));
end;

procedure AddKeyFloat(Strings: TStrings; const Key: string; Value: Double; Digits: Integer);
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := TFormatSettings.Create('en-US');
  Strings.Add(Key + '=' + FormatFloat('0.' + StringOfChar('0', Digits), Value, FormatSettings));
end;

function BuildBaseAliasText(const Params: TAul2AudioBaseAliasParams): string;
var
  P: TAul2AudioBaseAliasParams;
  Strings: TStringList;
begin
  // フィルター順は動画ファイル、映像再生、Aul2Audio Viewから変更しない。
  P := NormalizeBaseAliasParams(Params);
  Strings := TStringList.Create;
  try
    Strings.Add('[0]');
    Strings.Add(Format('layer=%d', [P.Layer]));
    Strings.Add(Format('frame=%d,%d', [P.FrameStart, P.FrameStart + P.FrameLength - 1]));

    Strings.Add('[0.0]');
    AddKeyValue(Strings, 'effect.name', '動画ファイル');
    AddKeyValue(Strings, '再生位置', '0.000,33333.300,再生範囲,0');
    AddKeyFloat(Strings, '再生速度', 100.00, 2);
    AddKeyValue(Strings, 'ファイル', BuildBaseVirtualFileName(P));
    AddKeyValue(Strings, 'トラック', 0);
    AddKeyValue(Strings, 'ループ再生', 0);
    AddKeyValue(Strings, '音声付き', 0);
    AddKeyValue(Strings, 'YUV', '');

    Strings.Add('[0.1]');
    AddKeyValue(Strings, 'effect.name', '映像再生');
    AddKeyFloat(Strings, 'X', 0, 2);
    AddKeyFloat(Strings, 'Y', 0, 2);
    AddKeyFloat(Strings, 'Z', 0, 2);
    AddKeyFloat(Strings, '中心X', 0, 2);
    AddKeyFloat(Strings, '中心Y', 0, 2);
    AddKeyFloat(Strings, '中心Z', 0, 2);
    AddKeyFloat(Strings, 'X軸回転', 0, 2);
    AddKeyFloat(Strings, 'Y軸回転', 0, 2);
    AddKeyFloat(Strings, 'Z軸回転', 0, 2);
    AddKeyFloat(Strings, '拡大率', 100, 3);
    AddKeyFloat(Strings, '縦横比', 0, 3);
    AddKeyFloat(Strings, '透明度', 0, 2);

    Strings.Add('[0.2]');
    AddKeyValue(Strings, 'effect.name', VIEW_FILTER_NAME);

    Result := Strings.Text;
  finally
    Strings.Free;
  end;
end;

function SaveBaseAliasFile(const Params: TAul2AudioBaseAliasParams): string;
var
  Dir: string;
  Strings: TStringList;
  Enc: TEncoding;
begin
  Dir := TPath.Combine(TPath.GetTempPath, BASE_ALIAS_TEMP_DIR);
  ForceDirectories(Dir);
  Result := TPath.Combine(Dir, BASE_ALIAS_FILE_NAME);

  Strings := TStringList.Create;
  Enc := TUTF8Encoding.Create(False);
  try
    Strings.Text := BuildBaseAliasText(Params);
    Strings.SaveToFile(Result, Enc);
  finally
    Enc.Free;
    Strings.Free;
  end;
end;

end.
