unit AviUtl2PluginObjectValue;

interface

uses
  Windows,   Messages,  SysUtils,  Classes,  MMSystem,  Vcl.Forms,Vcl.Graphics,
  AviUtl2PluginTypes;


function AviUtl2GetObjectItemValue(Obj: TObjectHandle;
                                   const Effect,                    //
                                         Item: WideString;          // 変数名
                                   out Value: string                // 値
                                   ): Boolean;                      // True : 成功

// 文字列型の値をAviUtl2のオブジェクトへ書き込む
function AviUtl2SetObjectItemValue(Obj: TObjectHandle;
                                   const Effect,
                                         Item: WideString;
                                   const Value: string              // 値
                                   ): Boolean;                      // True:成功

// 数値型の値をAviUtl2のオブジェクトへ書き込む
function AviUtl2SetObjectItemInt(Obj: TObjectHandle;
                                   const Effect,
                                         Item: WideString;
                                   const Value: Integer             // 値
                                   ): Boolean;                      // True:成功

function AviUtl2SetObjectItemColor(Obj: TObjectHandle;
                                   const Effect,
                                         Item: WideString;
                                   const Value: TColor             // 値
                                   ): Boolean;                      // True:成功

function AviUtl2GetObjectItemInt(Obj: TObjectHandle;
                                   const Effect,                    //
                                         Item: WideString;          // 変数名
                                   out Value: Integer                // 値
                                   ): Boolean;                      // True : 成功
function AviUtl2GetObjectItemColor(Obj: TObjectHandle;
                                   const Effect,                    //
                                         Item: WideString;          // 変数名
                                   out Value: TColor                // 値
                                   ): Boolean;                      // True : 成功

function AviUtl2GetObjectItemFloat(Obj: TObjectHandle;
                                   const Effect,                    //
                                         Item: WideString;          // 変数名
                                   out Value: Double                // 値
                                   ): Boolean;                      // True : 成功

// 浮動小数点型の値をAviUtl2のオブジェクトへ書き込む
function AviUtl2SetObjectItemFloat(Obj: TObjectHandle;
                                   const Effect,
                                         Item: WideString;
                                   const Value: Double             // 値
                                   ): Boolean;                      // True:成功

implementation

uses AviUtl2PluginCore;

var
  GObject     : TObjectHandle;
  GEffect     : LPCWSTR;
  GItem       : LPCWSTR;
  GValue      : LPCSTR;
  GResult     : Boolean;

function TextToAviUtl2Color(const S: string; DefaultColor: TColor): TColor;
var
  Hex: string;
  R, G, B: Integer;
begin
  // AviUtl2 の rrggbb 文字列を Delphi の TColor に戻す
  Result := DefaultColor;
  Hex := Trim(S);
  if Hex = '' then
    Exit;

  if Hex[1] = '$' then
    Delete(Hex, 1, 1);
  if SameText(Copy(Hex, 1, 2), '0X') then
    Delete(Hex, 1, 2);

  if Length(Hex) <> 6 then
    Exit;

  R := StrToIntDef('$' + Copy(Hex, 1, 2), -1);
  G := StrToIntDef('$' + Copy(Hex, 3, 2), -1);
  B := StrToIntDef('$' + Copy(Hex, 5, 2), -1);
  if (R < 0) or (G < 0) or (B < 0) then
    Exit;

  Result := RGB(R, G, B);
end;

function ColorToAviUtl2Text(const Value: TColor): string;
var
  RGBColor: COLORREF;
begin
  // Delphi の TColor を AviUtl2 の rrggbb 小文字 hex に変換する
  RGBColor := ColorToRGB(Value);
  Result := LowerCase(Format('%.2x%.2x%.2x', [
    GetRValue(RGBColor),
    GetGValue(RGBColor),
    GetBValue(RGBColor)
  ]));
end;


procedure GetObjectItemValue(Edit: PEditSection); cdecl;
begin
  if (Edit = nil) or (Edit^.Info = nil) then Exit;
  GValue := Edit^.GetObjectItemValue(GObject,GEffect,GItem);
end;

function AviUtl2GetObjectItemValue(Obj: TObjectHandle;
  const Effect, Item: WideString;out Value: string): Boolean;
begin
  Result := False;
  Value  := '';

  if not Assigned(EditHandle) then Exit;

  GObject := Obj;
  GEffect := PWideChar(Effect);
  GItem   := PWideChar(Item);
  GValue  := nil;

  EditHandle^.CallEditSection(@GetObjectItemValue);

  if GValue = nil then Exit;

  Value := UTF8ToString(AnsiString(GValue));
  Result := True;
end;

function AviUtl2GetObjectItemInt(Obj: TObjectHandle;
  const Effect, Item: WideString;out Value: Integer): Boolean;
var
  s : string;
begin
  Result := AviUtl2GetObjectItemValue(Obj,Effect,Item,s);
  Value  := StrToIntDef(s,0);
end;

function AviUtl2GetObjectItemFloat(Obj: TObjectHandle;
  const Effect, Item: WideString;out Value: Double): Boolean;
var
  s : string;
begin
  Result := AviUtl2GetObjectItemValue(Obj,Effect,Item,s);
  Value  := StrToFloatDef(s,0);
end;

function AviUtl2GetObjectItemColor(Obj: TObjectHandle;
  const Effect, Item: WideString;out Value: TColor): Boolean;
var
  s : string;
begin
  Result := AviUtl2GetObjectItemValue(Obj,Effect,Item,s);
  Value  := TextToAviUtl2Color(s, 0);
end;


procedure SetObjectItemValue(Edit: PEditSection); cdecl;
var
  f : BOOL;
begin
  GResult := False;
  if (Edit = nil) or (Edit^.Info = nil) then Exit;
  f := Edit^.SetObjectItemValue(GObject,GEffect,GItem,GValue);
  if f <> True then Exit;
  GResult := True;
end;

function AviUtl2SetObjectItemValue(Obj: TObjectHandle;const Effect, Item: WideString;const Value: string): Boolean;
var
  Utf8Value: UTF8String;
begin
  Result := False;
  if not Assigned(EditHandle) then Exit;
  GObject := Obj;
  GEffect := PWideChar(Effect);
  GItem   := PWideChar(Item);

  // UTF-8 に変換して保持
  Utf8Value := UTF8String(Value);
  GValue    := PAnsiChar(Utf8Value);
  EditHandle^.CallEditSection(@SetObjectItemValue);
  if not GResult then Exit;
  Result := True;
end;

function AviUtl2SetObjectItemInt(Obj: TObjectHandle;const Effect,Item: WideString;const Value: Integer): Boolean;
var
  Utf8Value: UTF8String;
begin
  Result := False;
  if not Assigned(EditHandle) then Exit;
  GObject := Obj;
  GEffect := PWideChar(Effect);
  GItem   := PWideChar(Item);
  Utf8Value := UTF8String(IntToStr(Value));
  GValue    := PAnsiChar(Utf8Value);

  EditHandle^.CallEditSection(@SetObjectItemValue);
  if not GResult then Exit;
  Result := True;
end;

function AviUtl2SetObjectItemColor(Obj: TObjectHandle;const Effect,Item: WideString;const Value: TColor): Boolean;
var
  Utf8Value: UTF8String;
begin
  Result := False;
  if not Assigned(EditHandle) then Exit;
  GObject := Obj;
  GEffect := PWideChar(Effect);
  GItem   := PWideChar(Item);
  Utf8Value := UTF8String(ColorToAviUtl2Text(Value));
  GValue    := PAnsiChar(Utf8Value);

  EditHandle^.CallEditSection(@SetObjectItemValue);
  if not GResult then Exit;
  Result := True;
end;

function AviUtl2SetObjectItemFloat(Obj: TObjectHandle;const Effect,Item: WideString;const Value: Double): Boolean;
var
  Utf8Value: UTF8String;
begin
  Result := False;
  if not Assigned(EditHandle) then Exit;
  GObject := Obj;
  GEffect := PWideChar(Effect);
  GItem   := PWideChar(Item);
  Utf8Value := UTF8String(FloatToStr(Value));
  GValue    := PAnsiChar(Utf8Value);

  EditHandle^.CallEditSection(@SetObjectItemValue);
  if not GResult then Exit;
  Result := True;
end;

end.
