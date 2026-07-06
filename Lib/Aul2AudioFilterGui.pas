unit Aul2AudioFilterGui;

// AviUtl2 のフィルター GUI 項目登録を Delphi 側から扱いやすくする。

interface

uses
  System.SysUtils,
  Aul2AudioFilterTypes;

procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
procedure AddGroup(var Item: TFILTER_ITEM_GROUP; Name: PWideChar;
  DefaultVisible: Integer);
procedure AddCheck(var Item: TFILTER_ITEM_CHECK; Name: PWideChar; Value: Integer);
procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double; ZeroDisplay: PWideChar = nil;
  SliderRatio: Double = 1.0);
procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar; Value: Integer;
  List: Pointer);

var
  GTable: TFILTER_PLUGIN_TABLE; // AviUtl2 へ返すフィルターテーブル

implementation

const
  MAX_GUI_ITEMS = 100; // GTable.Items に登録できる最大 GUI 項目数

var
  FItemIndex: Integer;                              // 次に登録する Items の位置
  Items     : array[0..MAX_GUI_ITEMS - 1] of Pointer; // nil 終端の GUI 項目配列

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

end.
