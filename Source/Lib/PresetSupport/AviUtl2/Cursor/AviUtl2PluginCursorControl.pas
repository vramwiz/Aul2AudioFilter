unit AviUtl2PluginCursorControl;

interface

uses
  Windows,   Messages,  SysUtils,  Classes,  MMSystem,  Vcl.Forms,
  AviUtl2PluginTypes;

// カーソル位置を現在位置から指定した秒数移動させる  （相対値）
function  AviUtl2CursorMoveSec(const Sec : Double) : Double;
// カーソル位置を指定したフレームへ移動              （絶対位置）
procedure  AviUtl2CursorMoveFrame(const Frame : Integer);
// 指定したフレーム、レイヤー位置のオブジェクトを選択状態に
procedure  AviUtl2CursorMoveFrameFocus(const Layer,Frame : Integer);

// カーソル位置を秒で取得
function  AviUtl2CursorGetSec() : Double;
// カーソル位置をフレームで取得
function  AviUtl2CursorGetFrame() : Integer;
function  AviUtl2CursorGetLayer() : Integer;

implementation


uses AviUtl2PluginCore,AviUtl2PluginObjectFind;

var
  GSec        : Double;
  GFrame      : Integer;
  GLayer      : Integer;
  GObject     : TObjectHandle;
  //GSceneId    : Integer;

// フォーカスセット
procedure SetFocusObject(Edit: PEditSection); cdecl;
begin
  if Edit = nil then Exit;
  Edit^.SetFocusObject(GObject);
end;

procedure  AviUtl2CursorSetFocusObject(obj : TObjectHandle);
begin
  GObject := obj;
  if Assigned(EditHandle) then begin
    EditHandle^.CallEditSection(@SetFocusObject);
  end;

end;


// カーソル移動（カーソル位置からの相対座標）
procedure CursorMoveSec(Edit: PEditSection); cdecl;
var
  MoveFrames: Integer;
begin
  MoveFrames := Round(GSec * Edit^.Info^.Rate / Edit^.Info^.Scale);             // 秒 → フレーム
  Edit^.SetCursorLayerFrame(Edit^.Info^.Layer,Edit^.Info^.Frame + MoveFrames);  // カーソル移動
  GSec := (MoveFrames * Edit^.Info^.Scale) / Edit^.Info^.Rate;                  // フレーム → 秒（戻す）
end;

// カーソル移動（カーソル位置からの相対座標）
procedure CursorMoveFrame(Edit: PEditSection); cdecl;
var
  MoveFrames: Integer;
begin
  MoveFrames := GFrame;                                        // 秒 → フレーム
  Edit^.SetCursorLayerFrame(Edit^.Info^.Layer,MoveFrames);     // カーソル移動
end;

// カーソル位置取得
procedure CursorGetSec(Edit: PEditSection); cdecl;
var
  CurFrame: Integer;
begin
  if (Edit = nil) or (Edit^.Info = nil) then
  begin
    GSec := 0;
    Exit;
  end;
  CurFrame := Edit^.Info^.Frame;
  // frame → 秒
  GSec := (CurFrame * Edit^.Info^.Scale) / Edit^.Info^.Rate;
end;

// レイヤー位置取得
procedure CursorGetLayer(Edit: PEditSection); cdecl;
begin
  GLayer := 0;
  if (Edit = nil) or (Edit^.Info = nil) then Exit;
  GLayer := Edit^.Info^.Layer;
end;


// カーソル位置取得
procedure CursorGetFrame(Edit: PEditSection); cdecl;
begin
  GFrame := 0;
  if (Edit = nil) or (Edit^.Info = nil) then Exit;
  GFrame := Edit^.Info^.Frame;
end;

// レイヤー位置取得
function  AviUtl2CursorGetLayer() : Integer;
begin
  if Assigned(EditHandle) then EditHandle^.CallEditSection(@CursorGetLayer);
  Result := GLayer;
end;

// カーソル位置取得
function  AviUtl2CursorGetSec() : Double;
begin
  if Assigned(EditHandle) then EditHandle^.CallEditSection(@CursorGetSec);
  Result := GSec;
end;

// カーソル位置取得
function  AviUtl2CursorGetFrame() : Integer;
begin
  if Assigned(EditHandle) then EditHandle^.CallEditSection(@CursorGetFrame);
  Result := GFrame;
end;

// カーソル移動
function  AviUtl2CursorMoveSec(const Sec : Double) : Double;
begin
  GSec := Sec;
  if Assigned(EditHandle) then begin
    EditHandle^.CallEditSection(@CursorMoveSec);
    EditHandle^.CallEditSection(@CursorGetSec);
  end;
  Result := GSec;
end;


procedure  AviUtl2CursorMoveFrame(const Frame : Integer);
begin
  GFrame := Frame;
  if Assigned(EditHandle) then begin
    EditHandle^.CallEditSection(@CursorMoveFrame);
  end;

end;

procedure  AviUtl2CursorMoveFrameFocus(const Layer,Frame : Integer);
var
  obj : TObjectHandle;
begin
  GFrame := Frame;
  if not Assigned(EditHandle) then exit;
  EditHandle^.CallEditSection(@CursorMoveFrame);
  obj := AviUtl2FindObject(Layer,Frame);
  if obj =  nil then Exit;
  AviUtl2CursorSetFocusObject(obj);

end;


end.

