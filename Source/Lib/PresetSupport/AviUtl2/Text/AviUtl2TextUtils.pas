unit AviUtl2TextUtils;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls;

function AvrUtl2_StrToAviutl(const str: string): string;
function AvrUtl2_AviUtlToStr(const S: string): string;
function AviUtl2TextToStringListText(const S: string): string;

implementation

function NormalizeToLineBreak(const S: string): string;
var
  Tmp: string;
begin
  Tmp := S;

  // 文字列化された改行表現も実改行へ寄せる
  Tmp := StringReplace(Tmp, '#$D#$A', #10, [rfReplaceAll, rfIgnoreCase]);
  Tmp := StringReplace(Tmp, '#$A', #10, [rfReplaceAll, rfIgnoreCase]);

  // 改行コードを一度 LF に寄せてから環境依存改行へ戻す
  Tmp := StringReplace(Tmp, #13#10, #10, [rfReplaceAll]);
  Tmp := StringReplace(Tmp, #13, #10, [rfReplaceAll]);
  Tmp := StringReplace(Tmp, #10, sLineBreak, [rfReplaceAll]);

  Result := Tmp;
end;

function AvrUtl2_StrToAviutl(const str: string): string;
var
  Tmp: string;
begin
  Tmp := str;

  // バックスラッシュ → \\ （最優先）
  Tmp := StringReplace(Tmp, '\', '\\', [rfReplaceAll]);

  // ダブルクォーテーション → \"
  Tmp := StringReplace(Tmp, '"', '\"', [rfReplaceAll]);

  // CRLF（Windows改行）→ \n
  Tmp := StringReplace(Tmp, sLineBreak, '\n', [rfReplaceAll]);

  // 単独の CR → \n
  Tmp := StringReplace(Tmp, #13, '\n', [rfReplaceAll]);

  // 単独の LF → \n
  Tmp := StringReplace(Tmp, #10, '\n', [rfReplaceAll]);

  Result := Tmp;
end;

// AviUtl のエスケープ文字列を元の文字列へ戻す（逆変換）
function AvrUtl2_AviUtlToStr(const S: string): string;
var
  Tmp: string;
begin
  Tmp := S;

  // \n → 改行
  Tmp := StringReplace(Tmp, '\n', #10, [rfReplaceAll]);

  // \" → "
  Tmp := StringReplace(Tmp, '\"', '"', [rfReplaceAll]);

  // \\ → \
  Tmp := StringReplace(Tmp, '\\', '\', [rfReplaceAll]);

  Result := NormalizeToLineBreak(Tmp);
end;

function AviUtl2TextToStringListText(const S: string): string;
begin
  Result := NormalizeToLineBreak(AvrUtl2_AviUtlToStr(S));
end;


end.
