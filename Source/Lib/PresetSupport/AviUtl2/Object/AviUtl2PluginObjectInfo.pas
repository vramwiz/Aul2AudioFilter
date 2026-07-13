unit AviUtl2PluginObjectInfo;

interface

uses
  Windows,   Messages,  SysUtils,  Classes,  MMSystem,  Vcl.Forms,
  AviUtl2PluginTypes;

// 指定したオブジェクトのフレーム、レイヤーを取得
function  AviUtl2GetObjectLayerFrame(obj : TObjectHandle ;var Layer, FrameStart,FrameEnd: Integer) : Boolean;


implementation

uses AviUtl2PluginCore;

var
  GObject     : TObjectHandle;
  GObjectFrame: TObjectLayerFrame;


procedure GetObjectLayerFrame(Edit: PEditSection); cdecl;
begin
  if (Edit = nil) or (Edit^.Info = nil) then Exit;

  GObjectFrame := Edit^.GetObjectLayerFrame(GObject);
end;


function  AviUtl2GetObjectLayerFrame(obj : TObjectHandle ;var Layer, FrameStart,FrameEnd: Integer) : Boolean;
begin
  Result := False;
  if not Assigned(EditHandle) then Exit;
  GObject := obj;
  FillChar(GObjectFrame, SizeOf(GObjectFrame), 0);
  EditHandle^.CallEditSection(@GetObjectLayerFrame);

  Layer := GObjectFrame.Layer;
  FrameStart := GObjectFrame.StartFrame;
  FrameEnd := GObjectFrame.EndFrame;

  Result := True;
end;


end.
