unit AviUtl2PluginObjectControl;

interface

uses
  Windows,   Messages,  SysUtils,  Classes,  MMSystem,  Vcl.Forms,
  AviUtl2PluginTypes;

function AviUtl2MoveObject(Obj: TObjectHandle;Layer,Frame : Integer) : Boolean;
procedure AviUtl2DeleteObject(Obj: TObjectHandle);

implementation

uses AviUtl2PluginCore;

var
  GObject     : TObjectHandle;
  GLayer      : Integer;
  GFrame      : Integer;
  GBool       : BOOL;

procedure MoveObject(Edit: PEditSection); cdecl;
begin
  if (Edit = nil) or (Edit^.Info = nil) then Exit;
  GBool := Edit^.MoveObject(GObject,GLayer,GFrame);
end;

function AviUtl2MoveObject(Obj: TObjectHandle;Layer,Frame : Integer) : Boolean;
begin
  Result := False;
  if not Assigned(EditHandle) then Exit;

  GObject := Obj;
  GLayer  := layer;
  GFrame  := frame;
  EditHandle^.CallEditSection(@MoveObject);
  Result := GBool;
end;

procedure DeleteObject(Edit: PEditSection); cdecl;
begin
  if (Edit = nil) or (Edit^.Info = nil) then Exit;
  Edit^.DeleteObject(GObject);
end;

procedure AviUtl2DeleteObject(Obj: TObjectHandle);
begin
  if not Assigned(EditHandle) then Exit;

  GObject := Obj;
  EditHandle^.CallEditSection(@DeleteObject);
end;

end.
