unit Aul2AudioPresetModel;

// ユーザープリセットをRTTI対応の型付きAlias項目へ分解し、INI保存とAlias再構築を担当する。

interface

uses
  System.Classes,
  System.Generics.Collections;

type
  // published文字列プロパティをRTTIでINIセクションへ保存・復元する基底クラス。
  TAul2AudioRttiPersistent = class(TPersistent)
  public
    // published文字列プロパティを指定INIセクションへ保存する。
    procedure SaveProperties(Ini: TObject; const Section: string);
    // 指定INIセクションからpublished文字列プロパティを復元する。
    procedure LoadProperties(Ini: TObject; const Section: string);
    // published文字列プロパティをName=Value形式で文字列リストへ追加する。
    procedure SavePropertiesToStrings(Strings: TStrings);
    // Name=Value形式の文字列リストからpublished文字列プロパティを復元する。
    procedure LoadPropertiesFromStrings(Strings: TStrings);
  end;

  // エイリアス内の1セクション行または1つのKey=Value行を保持する。
  TAul2AudioPresetAliasItem = class(TAul2AudioRttiPersistent)
  private
    FSection: string;
    FKey    : string;
    FValue  : string;
  published
    property Section: string read FSection write FSection;
    property Key    : string read FKey write FKey;
    property Value  : string read FValue write FValue;
  end;

  TAul2AudioPresetAliasItemList = class(TObjectList<TAul2AudioPresetAliasItem>)
  public
    // 新しいAlias項目を生成して末尾へ追加する。
    function AddNew: TAul2AudioPresetAliasItem;
  end;

  // 表示情報と型付きAlias項目リストをまとめる1件のユーザープリセット。
  TAul2AudioUserPreset = class(TAul2AudioRttiPersistent)
  private
    FAliasItems: TAul2AudioPresetAliasItemList;
    FEffect    : string;
    FName      : string;
    FPreview   : string;
  public
    // Alias項目リストを生成する。
    constructor Create;
    // Alias項目リストを解放する。
    destructor Destroy; override;
    // AviUtl2のAlias全文をSection / Key / Valueへ分解して保持する。
    procedure AssignAliasText(const AliasText: string);
    // 型付きAlias項目を元の.object形式へ再構築する。
    function BuildAliasText: string;
    property AliasItems: TAul2AudioPresetAliasItemList read FAliasItems;
  published
    property Name   : string read FName write FName;
    property Effect : string read FEffect write FEffect;
    property Preview: string read FPreview write FPreview;
  end;

  TAul2AudioUserPresetList = class(TObjectList<TAul2AudioUserPreset>)
  private
    FFilename: string;
  public
    // 所有権を指定してプリセット一覧を生成する。
    constructor Create(AOwnsObjects: Boolean);
    // 新しいプリセットを生成して末尾へ追加する。
    function AddNew: TAul2AudioUserPreset;
    // FilenameのINIからPresetとAlias項目を復元する。
    procedure LoadFromFile;
    // PresetとAlias項目をFilenameのINIへ保存する。
    procedure SaveToFile;
    property Filename: string read FFilename write FFilename;
  end;

implementation

uses
  System.IniFiles,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  SectionFileManager;

procedure TAul2AudioRttiPersistent.SaveProperties(Ini: TObject; const Section: string);
var
  Context : TRttiContext;
  Prop    : TRttiProperty;
  RttiType: TRttiType;
begin
  if not (Ini is TCustomIniFile) then
    Exit;

  RttiType := Context.GetType(ClassType);
  for Prop in RttiType.GetProperties do
    if (Prop.Visibility = mvPublished) and Prop.IsReadable and
       (Prop.PropertyType.TypeKind in [tkString, tkLString, tkWString, tkUString]) then
      TCustomIniFile(Ini).WriteString(Section, Prop.Name, Prop.GetValue(Self).AsString);
end;

procedure TAul2AudioRttiPersistent.LoadProperties(Ini: TObject; const Section: string);
var
  Context : TRttiContext;
  Prop    : TRttiProperty;
  RttiType: TRttiType;
begin
  if not (Ini is TCustomIniFile) then
    Exit;

  RttiType := Context.GetType(ClassType);
  for Prop in RttiType.GetProperties do
    if (Prop.Visibility = mvPublished) and Prop.IsWritable and
       (Prop.PropertyType.TypeKind in [tkString, tkLString, tkWString, tkUString]) then
      Prop.SetValue(Self, TCustomIniFile(Ini).ReadString(Section, Prop.Name, ''));
end;

procedure TAul2AudioRttiPersistent.SavePropertiesToStrings(Strings: TStrings);
var
  Context : TRttiContext;
  Prop    : TRttiProperty;
  RttiType: TRttiType;
begin
  if Strings = nil then
    Exit;

  RttiType := Context.GetType(ClassType);
  for Prop in RttiType.GetProperties do
    if (Prop.Visibility = mvPublished) and Prop.IsReadable and
       (Prop.PropertyType.TypeKind in [tkString, tkLString, tkWString, tkUString]) then
      Strings.Values[Prop.Name] := Prop.GetValue(Self).AsString;
end;

procedure TAul2AudioRttiPersistent.LoadPropertiesFromStrings(Strings: TStrings);
var
  Context : TRttiContext;
  Prop    : TRttiProperty;
  RttiType: TRttiType;
begin
  if Strings = nil then
    Exit;

  RttiType := Context.GetType(ClassType);
  for Prop in RttiType.GetProperties do
    if (Prop.Visibility = mvPublished) and Prop.IsWritable and
       (Prop.PropertyType.TypeKind in [tkString, tkLString, tkWString, tkUString]) then
      Prop.SetValue(Self, Strings.Values[Prop.Name]);
end;

function TAul2AudioPresetAliasItemList.AddNew: TAul2AudioPresetAliasItem;
begin
  Result := TAul2AudioPresetAliasItem.Create;
  Add(Result);
end;

constructor TAul2AudioUserPreset.Create;
begin
  inherited Create;
  FAliasItems := TAul2AudioPresetAliasItemList.Create(True);
end;

constructor TAul2AudioUserPresetList.Create(AOwnsObjects: Boolean);
begin
  inherited Create(AOwnsObjects);
end;

function TAul2AudioUserPresetList.AddNew: TAul2AudioUserPreset;
begin
  Result := TAul2AudioUserPreset.Create;
  Add(Result);
end;

destructor TAul2AudioUserPreset.Destroy;
begin
  FAliasItems.Free;
  inherited;
end;

procedure TAul2AudioUserPreset.AssignAliasText(const AliasText: string);
var
  CurrentSection: string;
  EqualPos     : Integer;
  Index        : Integer;
  Item         : TAul2AudioPresetAliasItem;
  Lines        : TStringList;
  TextLine     : string;
begin
  FAliasItems.Clear;
  CurrentSection := '';
  Lines := TStringList.Create;
  try
    Lines.Text := AliasText;
    for Index := 0 to Lines.Count - 1 do
    begin
      TextLine := Lines[Index];
      if TextLine = '' then
        Continue;
      if (TextLine[1] = '[') and (TextLine[Length(TextLine)] = ']') then
      begin
        CurrentSection := Copy(TextLine, 2, Length(TextLine) - 2);
        Continue;
      end;

      EqualPos := Pos('=', TextLine);
      if EqualPos <= 0 then
        Continue;
      Item := FAliasItems.AddNew;
      Item.Section := CurrentSection;
      Item.Key := Copy(TextLine, 1, EqualPos - 1);
      Item.Value := Copy(TextLine, EqualPos + 1, MaxInt);
    end;
  finally
    Lines.Free;
  end;
end;

function TAul2AudioUserPreset.BuildAliasText: string;
var
  CurrentSection: string;
  Index        : Integer;
  Item         : TAul2AudioPresetAliasItem;
  Lines        : TStringList;
begin
  Lines := TStringList.Create;
  try
    CurrentSection := '';
    for Index := 0 to FAliasItems.Count - 1 do
    begin
      Item := FAliasItems[Index];
      if not SameText(CurrentSection, Item.Section) then
      begin
        CurrentSection := Item.Section;
        Lines.Add('[' + CurrentSection + ']');
      end;
      Lines.Add(Item.Key + '=' + Item.Value);
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure TAul2AudioUserPresetList.LoadFromFile;
var
  AliasIndex : Integer;
  Index      : Integer;
  Inner      : TSectionFileManager;
  Item       : TAul2AudioPresetAliasItem;
  ItemLines  : TStringList;
  Outer      : TSectionFileManager;
  Preset     : TAul2AudioUserPreset;
  PresetLines: TStringList;
  SectionLines: TStringList;
  SectionName: string;
begin
  Clear;
  if (FFilename = '') or not FileExists(FFilename) then
    Exit;

  Outer := TSectionFileManager.Create;
  Inner := TSectionFileManager.Create;
  PresetLines := TStringList.Create;
  ItemLines := TStringList.Create;
  try
    Outer.SetBrackets('[', ']');
    Outer.LoadFromFile(FFilename);
    Inner.SetBrackets('<', '>');
    Index := 0;
    while True do
    begin
      SectionName := 'Preset.' + IntToStr(Index);
      SectionLines := Outer.GetSection(SectionName);
      if SectionLines = nil then
        Break;
      ItemLines.Assign(SectionLines);

      Preset := AddNew;
      Preset.LoadPropertiesFromStrings(ItemLines);
      Inner.LoadFromStrings(ItemLines);
      AliasIndex := 0;
      while True do
      begin
        SectionLines := Inner.GetSection('Alias.' + IntToStr(AliasIndex));
        if SectionLines = nil then
          Break;
        PresetLines.Assign(SectionLines);
        Item := Preset.AliasItems.AddNew;
        Item.LoadPropertiesFromStrings(PresetLines);
        Inc(AliasIndex);
      end;
      Inc(Index);
    end;
  finally
    ItemLines.Free;
    PresetLines.Free;
    Inner.Free;
    Outer.Free;
  end;
end;

procedure TAul2AudioUserPresetList.SaveToFile;
var
  AliasIndex : Integer;
  Index      : Integer;
  Inner      : TSectionFileManager;
  ItemLines  : TStringList;
  Outer      : TSectionFileManager;
  Preset     : TAul2AudioUserPreset;
  PresetLines: TStringList;
  SectionName: string;
begin
  if FFilename = '' then
    Exit;

  Outer := TSectionFileManager.Create;
  Inner := TSectionFileManager.Create;
  PresetLines := TStringList.Create;
  ItemLines := TStringList.Create;
  try
    Outer.SetBrackets('[', ']');
    Inner.SetBrackets('<', '>');
    for Index := 0 to Count - 1 do
    begin
      PresetLines.Clear;
      Inner.Clear;
      Preset := Items[Index];
      SectionName := 'Preset.' + IntToStr(Index);
      Preset.SavePropertiesToStrings(PresetLines);
      for AliasIndex := 0 to Preset.AliasItems.Count - 1 do
      begin
        ItemLines.Clear;
        Preset.AliasItems[AliasIndex].SavePropertiesToStrings(ItemLines);
        Inner.AddSection('Alias.' + IntToStr(AliasIndex), ItemLines);
      end;
      Inner.SaveToStrings(PresetLines);
      Outer.AddSection(SectionName, PresetLines);
    end;
    Outer.SaveToFile(FFilename);
  finally
    ItemLines.Free;
    PresetLines.Free;
    Inner.Free;
    Outer.Free;
  end;
end;

end.
