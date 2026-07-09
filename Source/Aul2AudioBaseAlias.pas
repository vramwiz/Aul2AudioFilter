unit Aul2AudioBaseAlias;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils;

type
  TAul2AudioBaseAliasParams = record
    Caption: string;
    Width: Integer;
    Height: Integer;
    MaxSec: Integer;
    Rate: Integer;
    Scale: Integer;
    Layer: Integer;
    FrameStart: Integer;
    FrameLength: Integer;
  end;

function DefaultBaseAliasParams: TAul2AudioBaseAliasParams;
function BuildBaseVirtualFileName(const Params: TAul2AudioBaseAliasParams): string;
function BuildBaseAliasText(const Params: TAul2AudioBaseAliasParams): string;
function SaveBaseAliasFile(const Params: TAul2AudioBaseAliasParams): string;
function NormalizeBaseAliasParams(const Params: TAul2AudioBaseAliasParams): TAul2AudioBaseAliasParams;

implementation

uses
  System.Classes,
  System.IOUtils;

const
  BASE_ALIAS_TEMP_DIR = 'Aul2AudioFilter';
  BASE_ALIAS_FILE_NAME = 'Aul2AudioBase.object';
  VIEW_FILTER_NAME = 'Aul2Audio View';

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
