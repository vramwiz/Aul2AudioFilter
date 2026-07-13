unit AviUtl2PluginObjectAlias;

interface

uses
  Windows,   Messages,  SysUtils,  Classes,  MMSystem,  Vcl.Forms,
  AviUtl2PluginTypes;

// 指定したオブジェクトのエリアス情報を取得
function AviUtl2GetObjectAlias(Obj: TObjectHandle): string;


implementation

uses AviUtl2PluginCore;

var
  GObject     : TObjectHandle;
  GValue      : LPCSTR;


procedure GetObjectAlias(Edit: PEditSection); cdecl;
begin
  if (Edit = nil) or (Edit^.Info = nil) then Exit;
  GValue := Edit^.GetObjectAlias(GObject);
end;

function AviUtl2GetObjectAlias(Obj: TObjectHandle): string;
begin
  Result := '';

  if not Assigned(EditHandle) then Exit;

  GObject := Obj;
  GValue  := nil;

  EditHandle^.CallEditSection(@GetObjectAlias);

  if GValue = nil then Exit;

  Result := UTF8ToString(AnsiString(GValue));
end;


end.
