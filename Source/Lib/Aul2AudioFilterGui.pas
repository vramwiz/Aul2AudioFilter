unit Aul2AudioFilterGui;

// AviUtl2 のフィルター GUI 項目登録を Delphi 側から扱いやすくする。

interface

uses
  System.SysUtils,
  Aul2AudioFilterTypes,
  Aul2AudioControllerRequest;

// フィルター基本情報と映像・音声コールバックを GTable へ設定する。
procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
// 後続項目をまとめる折りたたみ可能な GUI グループを登録する。
procedure AddGroup(var Item: TFILTER_ITEM_GROUP; Name: PWideChar;
  DefaultVisible: Integer);
// ON/OFF 値を保持するチェック項目を登録する。
procedure AddCheck(var Item: TFILTER_ITEM_CHECK; Name: PWideChar; Value: Integer);
// RGBA 初期値を持つ色選択項目を登録する。
procedure AddColor(var Item: TFILTER_ITEM_COLOR; Name: PWideChar; R, G, B: Byte;
  Alpha: Byte = 255);
// 初期値、範囲、刻み、表示倍率を持つ数値トラックを登録する。
procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double; ZeroDisplay: PWideChar = nil;
  SliderRatio: Double = 1.0);
// nil 終端された選択肢配列を参照する選択項目を登録する。
procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar; Value: Integer;
  List: Pointer);
// AviUtl2 の編集コールバックを呼び出すボタン項目を登録する。
procedure AddButton(var Item: TFILTER_ITEM_BUTTON; Name: PWideChar;
  Callback: TFilterItemButtonCallback);
// GUIには表示されない1 byteの汎用データ項目を登録する。
procedure AddRequestData(var Item: TFILTER_ITEM_DATA_REQUEST; Name: PWideChar);
// 次に作る選択肢配列へ影響しないよう、選択リスト作成位置を初期化する。
procedure ClearSelectList;
// 選択肢配列の次の空き位置へ表示名と値を追加し、後続要素を nil 終端する。
procedure AddSelectList(var List: array of TFILTER_ITEM_SELECT_ITEM; Name: PWideChar;
  Value: Integer);

var
  GTable: TFILTER_PLUGIN_TABLE; // AviUtl2 へ返すプロセス共通のフィルターテーブル。

implementation

const
  MAX_GUI_ITEMS = 256; // GTable.Items に登録できる最大 GUI 項目数

var
  FItemIndex: Integer;                              // 次に登録する Items の位置
  Items     : array[0..MAX_GUI_ITEMS - 1] of Pointer; // nil 終端の GUI 項目配列
  FSelectIndex: Integer;                            // 次に登録する select list の位置

procedure AddItem(Item: Pointer);
begin
  // AviUtl2 側へ渡す配列は nil 終端にするため、末尾 1 要素を常に空ける。
  if FItemIndex >= High(Items) then
    raise ERangeError.Create('Too many filter GUI items');

  Items[FItemIndex] := Item;
  Inc(FItemIndex);
  Items[FItemIndex] := nil;
end;

procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
begin
  // テーブル再構築時に前回登録した GUI 項目を残さない。
  FItemIndex := 0;
  FillChar(Items, SizeOf(Items), 0);

  GTable.Flag := Flag;
  GTable.Name := Name;
  GTable.Label_ := Label_;
  GTable.Information := Information;
  GTable.Items := @Items[0];
  GTable.Func_Proc_Video := VideoProc;
  GTable.Func_Proc_Audio := AudioProc;
end;

procedure AddGroup(var Item: TFILTER_ITEM_GROUP; Name: PWideChar;
  DefaultVisible: Integer);
begin
  AddItem(@Item);

  Item.ItemType := PWideChar('group');
  Item.Name := Name;
  Item.DefaultVisible := Byte(DefaultVisible <> 0);
end;

procedure AddCheck(var Item: TFILTER_ITEM_CHECK; Name: PWideChar; Value: Integer);
begin
  AddItem(@Item);

  Item.ItemType := PWideChar('check');
  Item.Name := Name;
  Item.Value := Byte(Value <> 0);
end;

procedure AddColor(var Item: TFILTER_ITEM_COLOR; Name: PWideChar; R, G, B: Byte;
  Alpha: Byte);
begin
  AddItem(@Item);

  Item.ItemType := PWideChar('color');
  Item.Name := Name;
  Item.R := R;
  Item.G := G;
  Item.B := B;
  Item.X := Alpha;
end;

procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double; ZeroDisplay: PWideChar; SliderRatio: Double);
begin
  AddItem(@Item);

  Item.ItemType := PWideChar('track2');
  Item.Name := Name;
  Item.Value := Value;
  Item.S := S;
  Item.E := E;
  Item.Step := Step;
  Item.ZeroDisplay := ZeroDisplay;
  Item.SliderRatio := SliderRatio;
end;

procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar; Value: Integer;
  List: Pointer);
begin
  AddItem(@Item);

  Item.ItemType := PWideChar('select');
  Item.Name := Name;
  Item.Value := Value;
  Item.List := List;
end;

procedure ClearSelectList;
begin
  FSelectIndex := 0;
end;

procedure AddSelectList(var List: array of TFILTER_ITEM_SELECT_ITEM; Name: PWideChar;
  Value: Integer);
begin
  // 最後の 1 要素は nil 終端用に空けておく。
  if FSelectIndex >= High(List) then
    raise ERangeError.Create('Too many select list items');

  List[FSelectIndex].Name := Name;
  List[FSelectIndex].Value := Value;
  Inc(FSelectIndex);

  List[FSelectIndex].Name := nil;
  List[FSelectIndex].Value := 0;
end;

procedure AddButton(var Item: TFILTER_ITEM_BUTTON; Name: PWideChar;
  Callback: TFilterItemButtonCallback);
begin
  AddItem(@Item);

  Item.ItemType := PWideChar('button');
  Item.Name := Name;
  Item.Callback := Callback;
end;

procedure AddRequestData(var Item: TFILTER_ITEM_DATA_REQUEST; Name: PWideChar);
begin
  AddItem(@Item);

  Item.ItemType := PWideChar('data');
  Item.Name := Name;
  Item.Size := SizeOf(Item.DefaultValue);
  Item.DefaultValue := Default(TAul2AudioControllerRequestData);
  Item.Value := @Item.DefaultValue;
end;

end.
