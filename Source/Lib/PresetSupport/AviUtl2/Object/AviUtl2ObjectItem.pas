unit AviUtl2ObjectItem;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  AviUtl2PluginTypes,RTTIPersistentIni;

type
  {====================================================================}
  { 単一オブジェクト情報クラス }
  {====================================================================}
  TAviUtl2ObjectItem = class(TRTTIPersistentIni)
  private
    FEdit: PEditSection;
    FObj: TObjectHandle;
    FLayer: Integer;              // Layer (レイヤー番号)
    FStartFrame: Integer;         // StartFrame (開始フレーム)
    FEndFrame: Integer;           // EndFrame (終了フレーム)
    FEffectId: Int64;             // EffectId (内部識別子 / Beta19a追加)
    FAlias: string;               // Alias (オブジェクトのエイリアス名)
  public
    constructor Create;
    function EqualsTo(const B: TAviUtl2ObjectItem): Boolean;
    function GetHash: UInt64;
    function ToString: string; override;

    // AviUtl2 のオブジェクト情報をセット
    procedure SetObject(const Edit: PEditSection; Obj: TObjectHandle);

    // 保持中のオブジェクトを取得（必要なら再キャプチャ）
    function GetObject(const Edit: PEditSection = nil): TObjectHandle;

    procedure LoadFromSection(const Edit: PEditSection; Obj: TObjectHandle);
  published
    property Layer: Integer read FLayer write FLayer;
    property StartFrame: Integer read FStartFrame write FStartFrame;
    property EndFrame: Integer read FEndFrame write FEndFrame;
    property EffectId: Int64 read FEffectId write FEffectId;
    property Alias: string read FAlias write FAlias;
  end;


implementation

constructor TAviUtl2ObjectItem.Create;
begin
  inherited Create;
  FEdit := nil;
  FObj := nil;
  FLayer := 0;
  FStartFrame := 0;
  FEndFrame := 0;
  FEffectId := 0;
  FAlias := '';
end;

function TAviUtl2ObjectItem.EqualsTo(const B: TAviUtl2ObjectItem): Boolean;
begin
  Result :=
    (FLayer      = B.FLayer)      and
    (FStartFrame = B.FStartFrame) and
    (FEndFrame   = B.FEndFrame)   and
    (FEffectId   = B.FEffectId)   and
    (FAlias      = B.FAlias);
end;

function TAviUtl2ObjectItem.ToString: string;
begin
  Result := Format('Layer=%d, Frame=%d-%d, EffectId=%d, Alias=%s, Hash=%x',
    [FLayer, FStartFrame, FEndFrame, FEffectId, FAlias, GetHash]);
end;

procedure TAviUtl2ObjectItem.LoadFromSection(const Edit: PEditSection; Obj: TObjectHandle);
var
  Frame: TObjectLayerFrame;
  AliasPtr: LPCSTR;
begin
  if (Edit = nil) or (Obj = nil) then Exit;

  // フレーム情報取得
  Frame := Edit^.GetObjectLayerFrame(Obj);
  FLayer      := Frame.Layer;
  FStartFrame := Frame.StartFrame;
  FEndFrame   := Frame.EndFrame;

  // エイリアス取得
  AliasPtr := Edit^.GetObjectAlias(Obj);
  if AliasPtr <> nil then
    FAlias := string(AnsiString(AliasPtr))
  else
    FAlias := '';
end;


{===== 64-bit FNV-1a string hash ====================================}
function HashString64(const S: string): UInt64;
const
  FNV_OFFSET_BASIS: UInt64 = $CBF29CE484222325;
  FNV_PRIME:        UInt64 = $00000100000001B3;
var
  i: Integer;
  c: UInt64;
begin
  Result := FNV_OFFSET_BASIS;
  for i := 1 to Length(S) do
  begin
    c := Ord(S[i]);        // WideChar -> Ord (UTF-16コードユニット)
    Result := Result xor c;
    Result := Result * FNV_PRIME;
  end;
end;


function TAviUtl2ObjectItem.GetHash: UInt64;
begin
  Result :=
    UInt64(FLayer)      * UInt64(1315423911) xor
    UInt64(FStartFrame) * UInt64(2654435761) xor
    UInt64(FEndFrame)   * UInt64(11400714819323198485) xor
    UInt64(FEffectId)   * UInt64(1099511628211) xor
    HashString64(FAlias);
end;

function TAviUtl2ObjectItem.GetObject(const Edit: PEditSection): TObjectHandle;
var
  Frame: TObjectLayerFrame;
  AliasPtr: LPCSTR;
begin
  // オブジェクトハンドルをそのまま返す
  Result := FObj;

  // Edit指定があれば再キャプチャして同期（任意機能）
  if (Edit <> nil) and (FObj <> nil) then
  begin
    Frame := Edit^.GetObjectLayerFrame(FObj);
    FLayer      := Frame.Layer;
    FStartFrame := Frame.StartFrame;
    FEndFrame   := Frame.EndFrame;

    AliasPtr := Edit^.GetObjectAlias(FObj);
    if AliasPtr <> nil then
      FAlias := string(AnsiString(AliasPtr))
    else
      FAlias := '';
  end;
end;

procedure TAviUtl2ObjectItem.SetObject(const Edit: PEditSection;Obj: TObjectHandle);
var
  Frame: TObjectLayerFrame;
  AliasPtr: LPCSTR;
begin
  if (Edit = nil) or (Obj = nil) then Exit;

  FEdit := Edit;
  FObj := Obj;

  // AviUtl2 SDK から情報を取得
  Frame := Edit^.GetObjectLayerFrame(Obj);
  FLayer      := Frame.Layer;
  FStartFrame := Frame.StartFrame;
  FEndFrame   := Frame.EndFrame;

  AliasPtr := Edit^.GetObjectAlias(Obj);
  if AliasPtr <> nil then
    FAlias := string(AnsiString(AliasPtr))
  else
    FAlias := '';
end;

end.
