unit RTTIPropertyList;

interface

uses
  System.SysUtils, System.Classes, System.TypInfo,
  System.Rtti, System.Generics.Collections;

type
  TRTTIPropertyType = (rtNormal, rtBoolean, rtClass, rtUnsupported);

  //======================================================================
  // プロパティ情報
  //======================================================================
  TRTTIPropertyItem = class(TPersistent)
  private
    FName: string;                // プロパティ名
    FTypeKind: TTypeKind;         // 型の種類
    FTypeBool: TRTTIPropertyType; // 型分類
  public
    property Name: string read FName;
    property TypeKind: TTypeKind read FTypeKind;
    property TypeBool: TRTTIPropertyType read FTypeBool;
  end;

  //======================================================================
  // RTTI プロパティリスト
  //======================================================================
  TRTTIPropertyList = class(TObjectList<TRTTIPropertyItem>)
  private
    FObject: TObject;                      // 解析対象オブジェクト
    FRttiCtx: TRttiContext;                // RTTIコンテキスト
    FProps: TArray<TRttiProperty>;         // プロパティ一覧

    // プロパティ型分類
    function DetectPropType(const Prop: TRttiProperty): TRTTIPropertyType;

    // インデックスのプロパティ名取得
    function GetInfos(Index: Integer): TRTTIPropertyItem;

    // 値取得
    function GetValue(PropName: string): string;

    // 値設定
    procedure SetValue(PropName: string; const Value: string);

    // インデックス検索
    function IndexOfPName(const PName: string): Integer;
  public
    destructor Destroy; override;

    // 新しい要素作成
    function AddNew: TRTTIPropertyItem;

    // オブジェクトを解析
    procedure LoadFromObject(AObject: TObject);

    // インデックスアクセス（ユーザー互換）
    property Infos[Index: Integer]: TRTTIPropertyItem read GetInfos; default;

    // 名前アクセス（ユーザー互換）
    property Values[PropName: string]: string read GetValue write SetValue;
  end;

implementation

// プロパティ型分類
function TRTTIPropertyList.DetectPropType(const Prop: TRttiProperty): TRTTIPropertyType;
var
  K: TTypeKind;
begin
  K := Prop.PropertyType.TypeKind;

  case K of
    tkEnumeration:
      begin
        if Prop.PropertyType.Handle = TypeInfo(Boolean) then
          Exit(rtBoolean)
        else
          Exit(rtNormal);
      end;

    tkInteger, tkInt64, tkFloat, tkString, tkUString,
    tkLString, tkWString, tkChar, tkWChar:
      Exit(rtNormal);

    tkClass:
      Exit(rtClass);
  end;

  Result := rtUnsupported;
end;

destructor TRTTIPropertyList.Destroy;
begin
  inherited;
end;

// 新しい要素作成
function TRTTIPropertyList.AddNew: TRTTIPropertyItem;
var
  Item: TRTTIPropertyItem;
begin
  Item := TRTTIPropertyItem.Create;
  Add(Item);
  Result := Item;
end;

// オブジェクトを解析
procedure TRTTIPropertyList.LoadFromObject(AObject: TObject);
var
  RType: TRttiType;
  Prop: TRttiProperty;
  Item: TRTTIPropertyItem;
begin
  FObject := AObject;
  Clear;

  if FObject = nil then
  begin
    SetLength(FProps, 0);
    Exit;
  end;

  RType := FRttiCtx.GetType(FObject.ClassType);
  FProps := RType.GetProperties;

  for Prop in FProps do
  begin
    // ① published プロパティのみを対象とする
    //if Prop.Visibility <> mvPublished then
    //  Continue;

    //if not Prop.IsWritable then Continue;
    //if not Prop.IsReadable then Continue;

    Item := AddNew;
    Item.FName := Prop.Name;
    Item.FTypeKind := Prop.PropertyType.TypeKind;
    Item.FTypeBool := DetectPropType(Prop);
  end;
end;


// インデックス検索
function TRTTIPropertyList.IndexOfPName(const PName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do
    if SameText(Items[i].Name, PName) then
      Exit(i);
end;

// プロパティ情報
function TRTTIPropertyList.GetInfos(Index: Integer): TRTTIPropertyItem;
begin
  Result := Items[Index];
end;

// 値取得
function TRTTIPropertyList.GetValue(PropName: string): string;
var
  idx: Integer;
  Prop: TRttiProperty;
  v: TValue;
begin
  Result := '';
  idx := IndexOfPName(PropName);
  if idx < 0 then Exit;

  Prop := FProps[idx];
  v := Prop.GetValue(FObject);

  case Items[idx].TypeBool of
    rtBoolean:
      Result := BoolToStr(v.AsBoolean, True);

    rtNormal:
      begin
        case Prop.PropertyType.TypeKind of
          tkInteger, tkInt64:
            Result := v.ToString;

          tkEnumeration:
            Result := IntToStr(v.AsOrdinal);

          tkFloat:
            Result := FloatToStr(v.AsExtended);

          tkString, tkUString, tkLString, tkWString:
            Result := v.AsString;

          tkChar, tkWChar:
            Result := v.ToString;
        end;
      end;

    rtClass:
      begin
        if v.AsObject = nil then
          Result := ''
        else
          Result := v.AsObject.ClassName;
      end;
  end;
end;

// 値設定
procedure TRTTIPropertyList.SetValue(PropName: string; const Value: string);
var
  idx: Integer;
  Prop: TRttiProperty;
  K: TTypeKind;
  f : Boolean;
  OrdValue: Int64;
begin
  idx := IndexOfPName(PropName);
  if idx < 0 then Exit;

  Prop := FProps[idx];
  K := Prop.PropertyType.TypeKind;

  case Items[idx].TypeBool of
    rtBoolean: begin
        f :=   Boolean(StrToIntDef(Value, 0) <> 0);
        Prop.SetValue(FObject, f);
        //Prop.SetValue(FObject, TValue.From(Boolean(StrToIntDef(Value, 0) <> 0)));
      end;

    rtNormal:
      begin
        case K of
          tkInteger, tkInt64:
            Prop.SetValue(FObject, TValue.From(StrToIntDef(Value, 0)));

          tkEnumeration:
            begin
              if not TryStrToInt64(Value, OrdValue) then
                OrdValue := GetEnumValue(Prop.PropertyType.Handle, Value);

              if OrdValue >= 0 then
                Prop.SetValue(FObject, TValue.FromOrdinal(Prop.PropertyType.Handle, OrdValue));
            end;

          tkFloat:
            Prop.SetValue(FObject, TValue.From(StrToFloatDef(Value, 0)));

          tkString, tkUString, tkLString, tkWString:
            Prop.SetValue(FObject, Value);

          tkChar, tkWChar:
            if Value <> '' then
              Prop.SetValue(FObject, Value[1]);
        end;
      end;

    rtClass:
      ; // クラス型は設定不可（安全のため何もしない）
  end;
end;

end.

