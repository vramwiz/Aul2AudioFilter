unit AliasManagerStringList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, RTTIPersistentIni;


type
  //===========================================================
  // エリアス管理文字列リスト
  //===========================================================
  TAliasStringList = class(TPersistent)
  private
    FStrings: TStringList;        // エリアス内容を蓄積する内部文字列バッファ
    FIndexObject: Integer;        // 現在のオブジェクト用セクション番号
    FIndexFilter: Integer;        // 現在のフィルター用サブセクション番号
    FObjectName : string;         // [Object] をする場合は Objectを代入
  public
    // 生成（内部バッファ初期化）
    constructor Create;
    // 破棄（内部バッファ解放）
    destructor Destroy; override;

    // 全データ初期化（インデックスもリセット）
    procedure Clear;
    // [n] セクション追加（オブジェクトセクション）
    procedure AddSectionObject;
    // [n,m] セクション追加（フィルターセクション）
    procedure AddSectionFilter;
    // key=value（文字列版）
    procedure AddKeyValue(const Key, Value: string); overload;
    // key=value（整数版）
    procedure AddKeyValue(const Key: string; Value: Integer); overload;
    // key=少数値（指定桁数でフォーマット）
    procedure AddKeyFloat(const Key: string; Value: Double; Digits: Integer);
    // key=value（色版）
    procedure AddKeyColor(const Key : string; Value: TColor);

    procedure AddObject(AObject : TRTTIPersistentIni);

    // layer=0 レイヤー番号
    procedure AddLayer(const Layer: Integer);
    // frame=開始,終了
    procedure AddFrame(AObject : TRTTIPersistentIni);

    procedure AddGroup(const Group : Integer);
    // UTF8（BOMなし）で保存
    procedure SaveToFile(const FileName: string);
    // エリアス単体を文字列で取得 セクションを Objectにする
    function SaveToText() : string;

    property ObjectName : string read FObjectName write FObjectName;
  end;

implementation

uses AliasManager,AliasManagerObjectList;


{ TAliasStringList }

constructor TAliasStringList.Create;
begin
  inherited;
  FStrings := TStringList.Create;
  Clear;
end;

destructor TAliasStringList.Destroy;
begin
  FStrings.Free;
  inherited;
end;

procedure TAliasStringList.SaveToFile(const FileName: string);
var
  Enc: TEncoding;
begin
  Enc := TUTF8Encoding.Create(False);  // ← False = BOM なし
  try
    FStrings.SaveToFile(FileName, Enc);
  finally
    Enc.Free;
  end;
end;

function TAliasStringList.SaveToText: string;
begin
  Result := FStrings.Text;
end;

procedure TAliasStringList.Clear;
begin
  FStrings.Clear;
  FIndexObject := -1;
  FIndexFilter := 0;
end;

//---------------------------------------------
// [n] セクション
//---------------------------------------------
procedure TAliasStringList.AddSectionObject;
begin
  Inc(FIndexObject);
  FIndexFilter := 0;

  if FObjectName<>'' then begin
    FStrings.Add('[' + FObjectName + ']');
  end
  else begin
    FStrings.Add(Format('[%d]', [FIndexObject]));
  end;
end;

//---------------------------------------------
// [n,m] セクション
//---------------------------------------------
procedure TAliasStringList.AddSectionFilter;
begin
  if FObjectName<>'' then begin
    FStrings.Add(Format('[%s.%d]', [FObjectName, FIndexFilter]));
  end
  else begin
    FStrings.Add(Format('[%d.%d]', [FIndexObject, FIndexFilter]));
  end;
  Inc(FIndexFilter);
end;

//---------------------------------------------
// key=value
//---------------------------------------------
// string
procedure TAliasStringList.AddKeyValue(const Key, Value: string);
begin
  FStrings.Add(Key + '=' + Value);
end;

// integer
procedure TAliasStringList.AddKeyValue(const Key: string; Value: Integer);
begin
  FStrings.Add(Key + '=' + IntToStr(Value));
end;

procedure TAliasStringList.AddKeyColor(const Key : string; Value: TColor);
var
  RGBColor: COLORREF;
begin
  // AviUtl2 が読む rrggbb の小文字 hex に変換する
  RGBColor := ColorToRGB(Value);
  FStrings.Add(Key + '=' + LowerCase(Format('%.2x%.2x%.2x', [
    GetRValue(RGBColor),
    GetGValue(RGBColor),
    GetBValue(RGBColor)
  ])));
end;

procedure TAliasStringList.AddKeyFloat(const Key: string; Value: Double; Digits: Integer);
var
  fmt: string;
begin
  // 例：Digits=3 → '0.000'
  fmt := '0.' + StringOfChar('0', Digits);
  FStrings.Add(Key + '=' + FormatFloat(fmt, Value));
end;


procedure TAliasStringList.AddLayer(const Layer: Integer);
begin
  if ObjectName <> '' then Exit;
  FStrings.Add(Format('layer=%d', [Layer]));
end;

procedure TAliasStringList.AddGroup(const Group: Integer);
begin
  if Group = 0  then Exit;
  FStrings.Add(Format('group=%d', [Group]));
end;


procedure TAliasStringList.AddObject(AObject : TRTTIPersistentIni);
var
  Obj : TAliasManagerObjectItem;
begin
  obj := TAliasManagerObjectItem(AObject);

  AddSectionObject();
  AddLayer(obj.Layer);
  AddFrame(obj);
  AddGroup(obj.Group);
end;

//---------------------------------------------
// frame=開始,終了
//---------------------------------------------
procedure TAliasStringList.AddFrame(AObject : TRTTIPersistentIni);
var
  Obj : TAliasManagerObjectItem;
  i : Integer;
  s : string;
begin
  obj := TAliasManagerObjectItem(AObject);
  if ObjectName <> '' then Exit;
  s := 'frame=';
  s := s + IntToStr(Obj.FrameStart);
  for i := 0 to obj.Positions.Count-1 do begin
    s := s + ',';
    s := s + IntToStr(obj.Positions[i].Frame);
  end;
  s := s + ',';
  s := s + IntToStr(Obj.FrameEnd);

  FStrings.Add(s);
end;



end.
