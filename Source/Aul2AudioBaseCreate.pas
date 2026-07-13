unit Aul2AudioBaseCreate;

// MonitorのBaseページからAviUtl2編集領域へエイリアスObjectを安全に作成する。

interface

uses
  Aul2AudioBaseAlias,
  AviUtl2PluginTypes;

// 指定レイヤーの現在フレームへBaseエイリアスObjectを作り、作成ハンドルを返す。
function CreateBaseAliasObject(Layer: Integer; const Params: TAul2AudioBaseAliasParams): TObjectHandle;
// AviUtl2編集領域の現在フレームを返し、取得できない場合は0を返す。
function GetCurrentEditFrame: Integer;
// 編集領域の最大レイヤー数を返し、取得できない場合はDefaultValueを返す。
function GetEditLayerMax(DefaultValue: Integer = 100): Integer;

implementation

uses
  AviUtl2PluginCore;

type
  // CallEditSectionParamを介して編集スレッドへ渡す入出力コンテキスト。
  PBaseCreateContext = ^TBaseCreateContext;
  TBaseCreateContext = record
    Params      : TAul2AudioBaseAliasParams; // 作成するBase素材の設定。
    AliasUtf8   : UTF8String;                // SDKへ渡すUTF-8エイリアス本文。
    ObjectHandle: TObjectHandle;             // SDKが返した作成済みObject。
    Frame       : Integer;                   // 編集領域の現在フレーム。
    LayerMax    : Integer;                   // 編集領域の最大レイヤー数。
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

  // Object操作はAviUtl2が保証する編集セクション内だけで実行する。
  if EditHandle^.CallEditSectionParam(@Context, @CreateObjectParam) then
    Result := Context.ObjectHandle;
end;

end.
