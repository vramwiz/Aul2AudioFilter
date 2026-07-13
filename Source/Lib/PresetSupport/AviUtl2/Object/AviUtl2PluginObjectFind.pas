unit AviUtl2PluginObjectFind;

interface


uses
  Windows,   Messages,  SysUtils,  Classes,  MMSystem,  Vcl.Forms,
  AviUtl2PluginTypes;

// 指定したフレーム、レイヤー位置のオブジェクトを取得  nil=未取得
function  AviUtl2FindObject(Layer, Frame: Integer) : TObjectHandle;
// カーソル位置オブジェクトを取得  nil=未取得
function  AviUtl2FindObjectCursor() : TObjectHandle;
// フォーカスのあるオブジェクトを取得   nil=未取得
function  AviUtl2FindObjectFocus() : TObjectHandle;
// 選択されているオブジェクト数を取得  0=未選択
function  AviUtl2FindObjectSelectedNum() : Integer;
// 指定インデックスの選択オブジェクトを取得  nil=未取得
function  AviUtl2FindObjectSelected(Index: Integer) : TObjectHandle;
// 指定レイヤーで FromFrame以降の次オブジェクト開始位置を取得  True=取得成功
function AviUtl2FindObjectNext(Layer, FromFrame: Integer; out StFrame, EdFrame: Integer): Boolean;

implementation

uses AviUtl2PluginCore,AviUtl2PluginCursorControl,AviUtl2PluginObjectInfo;

var
  GObject     : TObjectHandle;
  GLayer      : Integer;
  GFrame      : Integer;
  GObjectIndex : Integer;
  GObjectNum   : Integer;

// オブジェクト検索
procedure FindObject(Edit: PEditSection); cdecl;
begin
  GObject := nil;
  if (Edit = nil) or (Edit^.Info = nil) then Exit;

  GObject := Edit^.FindObject(GLayer,GFrame);
end;

function  AviUtl2FindObject(Layer, Frame: Integer) : TObjectHandle;
begin
  Result := nil;
  if not Assigned(EditHandle) then Exit;
  GLayer := Layer;
  GFrame := Frame;
  EditHandle^.CallEditSection(@FindObject);
  //if GObject = nil then Exit;
  Result := GObject;
end;

function  AviUtl2FindObjectCursor() : TObjectHandle;
var
  layer,frame : Integer;
begin
  layer := AviUtl2CursorGetLayer();
  frame := AviUtl2CursorGetFrame();
  Result := AviUtl2FindObject(layer,frame);
end;

// オブジェクト検索
procedure GetFocusObject(Edit: PEditSection); cdecl;
begin
  GObject := nil;
  if (Edit = nil) or (Edit^.Info = nil) then Exit;

  GObject := Edit^.GetFocusObject();
end;


function  AviUtl2FindObjectFocus() : TObjectHandle;
begin
  Result := nil;
  if not Assigned(EditHandle) then Exit;
  EditHandle^.CallEditSection(@GetFocusObject);
  Result := GObject;
end;

// 選択オブジェクト数取得
procedure GetSelectedObjectNum(Edit: PEditSection); cdecl;
begin
  GObjectNum := 0;
  if (Edit = nil) or (Edit^.Info = nil) then Exit;

  GObjectNum := Edit^.GetSelectedObjectNum();
end;

function  AviUtl2FindObjectSelectedNum() : Integer;
begin
  Result := 0;
  if not Assigned(EditHandle) then Exit;

  EditHandle^.CallEditSection(@GetSelectedObjectNum);
  Result := GObjectNum;
end;

// 選択オブジェクト取得
procedure GetSelectedObject(Edit: PEditSection); cdecl;
begin
  GObject := nil;
  if (Edit = nil) or (Edit^.Info = nil) then Exit;

  GObject := Edit^.GetSelectedObject(GObjectIndex);
end;

function  AviUtl2FindObjectSelected(Index: Integer) : TObjectHandle;
begin
  Result := nil;
  if not Assigned(EditHandle) then Exit;

  GObjectIndex := Index;
  EditHandle^.CallEditSection(@GetSelectedObject);

  Result := GObject;
end;

function AviUtl2FindObjectNext(Layer, FromFrame: Integer; out StFrame, EdFrame: Integer): Boolean;
var
  Obj: TObjectHandle;
begin
  Result := False;
  StFrame := 0;
  EdFrame := 0;

  Obj := AviUtl2FindObject(Layer, FromFrame);
  if Obj = nil then begin
    Exit;
  end;

  if not AviUtl2GetObjectLayerFrame(Obj, Layer, StFrame, EdFrame) then begin
    Exit;
  end;

  Result := True;
end;

end.
