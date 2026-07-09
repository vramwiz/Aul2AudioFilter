unit Aul2AudioBaseCreate;

interface

uses
  Aul2AudioBaseAlias,
  AviUtl2PluginTypes;

function CreateBaseAliasObject(Layer: Integer; const Params: TAul2AudioBaseAliasParams): TObjectHandle;
function GetCurrentEditFrame: Integer;
function GetEditLayerMax(DefaultValue: Integer = 100): Integer;

implementation

uses
  AviUtl2PluginCore;

type
  PBaseCreateContext = ^TBaseCreateContext;
  TBaseCreateContext = record
    Params: TAul2AudioBaseAliasParams;
    AliasUtf8: UTF8String;
    ObjectHandle: TObjectHandle;
    Frame: Integer;
    LayerMax: Integer;
  end;

procedure QueryEditInfo(Param: Pointer; Edit: PEditSection); cdecl;
var
  Context: PBaseCreateContext;
begin
  Context := PBaseCreateContext(Param);
  if (Context = nil) or (Edit = nil) or (Edit^.Info = nil) then
    Exit;

  Context^.Frame := Edit^.Info^.Frame;
  Context^.LayerMax := Edit^.Info^.LayerMax;
end;

procedure CreateObjectParam(Param: Pointer; Edit: PEditSection); cdecl;
var
  Context: PBaseCreateContext;
begin
  Context := PBaseCreateContext(Param);
  if (Context = nil) or (Edit = nil) or (Edit^.Info = nil) then
    Exit;

  Context^.ObjectHandle := Edit^.CreateObjectFromAlias(
    PAnsiChar(Context^.AliasUtf8),
    Context^.Params.Layer,
    Context^.Params.FrameStart,
    Context^.Params.FrameLength
  );
end;

function GetCurrentEditFrame: Integer;
var
  Context: TBaseCreateContext;
begin
  Result := 0;
  if not Assigned(EditHandle) then
    Exit;

  Context.Frame := 0;
  Context.LayerMax := 0;
  Context.ObjectHandle := nil;
  Context.AliasUtf8 := '';
  if EditHandle^.CallEditSectionParam(@Context, @QueryEditInfo) then
    Result := Context.Frame;
end;

function GetEditLayerMax(DefaultValue: Integer): Integer;
var
  Context: TBaseCreateContext;
begin
  Result := DefaultValue;
  if not Assigned(EditHandle) then
    Exit;

  Context.Frame := 0;
  Context.LayerMax := DefaultValue;
  Context.ObjectHandle := nil;
  Context.AliasUtf8 := '';
  if EditHandle^.CallEditSectionParam(@Context, @QueryEditInfo) and (Context.LayerMax > 0) then
    Result := Context.LayerMax;
end;

function CreateBaseAliasObject(Layer: Integer; const Params: TAul2AudioBaseAliasParams): TObjectHandle;
var
  Context: TBaseCreateContext;
begin
  Result := nil;
  if not Assigned(EditHandle) then
    Exit;

  Context.Params := NormalizeBaseAliasParams(Params);
  Context.Params.Layer := Layer;
  Context.Params.FrameStart := GetCurrentEditFrame;
  Context.AliasUtf8 := UTF8String(BuildBaseAliasText(Context.Params));
  Context.ObjectHandle := nil;
  Context.Frame := 0;
  Context.LayerMax := 0;

  if EditHandle^.CallEditSectionParam(@Context, @CreateObjectParam) then
    Result := Context.ObjectHandle;
end;

end.
