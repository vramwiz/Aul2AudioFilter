unit AviUtl2PluginObjectCreate;

interface

uses
  Windows,   Messages,  SysUtils,  Classes,  MMSystem,  Vcl.Forms,
  AviUtl2PluginTypes,AliasManager,AliasManagerObjectList;

//function  AviUtl2Create(Item : TAliasManagerObjectItem;const Alias : string) : Integer;
function  AviUtl2Creates(FrameStart,FrameLength,Layer : Integer;const Alias : string) : TObjectHandle;

implementation

uses AviUtl2PluginCore;

var
  GAliasText  : UTF8String;
  GLayer      : Integer;
  GFrameStart : Integer;
  GFrameLength: Integer;
  GMsNext     : Integer;
  GObject     : TObjectHandle;


{-------------------------------------------------------------}
{ オブジェクト生成                                           }
{-------------------------------------------------------------}
procedure CreateObject(Edit: PEditSection); cdecl;
var
  FrameStart,FrameEnd,Layer: Integer;
begin
  GObject := nil;
  if (Edit = nil) or (Edit^.Info = nil) then Exit;

  FrameStart := GFrameStart;  // カーソル位置
  FrameEnd := GFrameLength ;
  Layer := GLayer;
  GObject := Edit^.CreateObjectFromAlias(PAnsiChar(GAliasText), Layer, FrameStart,FrameEnd);

end;

function  AviUtl2Create(Item : TAliasManagerObjectItem;const Alias : string) : Integer;
begin
  GMsNext := 0;
  GLayer       := Item.Layer;
  GFrameStart  := Item.FrameStart;
  GFrameLength := Item.FrameLength;
  GAliasText   := UTF8String(Alias);           // 2025/12/12 修正
  if Assigned(EditHandle) then
    EditHandle^.CallEditSection(@CreateObject);
  Result := GMsNext;
end;

function  AviUtl2Creates(FrameStart,FrameLength,Layer : Integer;const Alias : string) : TObjectHandle;
begin
  GLayer       := Layer;
  GFrameStart  := FrameStart;
  GFrameLength := FrameLength;
  GAliasText   := UTF8String(Alias);           // 2025/12/12 修正
  if Assigned(EditHandle) then
    EditHandle^.CallEditSection(@CreateObject);
  Result := GObject
end;





end.
