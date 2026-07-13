unit AviUtl2AliasSelected;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes,
  AviUtl2PluginCore, AviUtl2PluginTypes;

procedure AviUtl2GetSelectedAlias(List: TStringList);

implementation

uses
  System.StrUtils,
  AviUtl2PluginObjectFind,
  AviUtl2PluginObjectInfo,
  AviUtl2TextUtils,AviUtl2PluginObjectAlias;

// <? ?> ブロック内と直後の改行だけを \n 表記へ戻す
function RestoreScriptBlockLineBreaks(const S: string): string;
var
  BlockStart: Integer;
  BlockEnd: Integer;
  SearchFrom: Integer;
  BlockLength: Integer;
  BlockText: string;
begin
  Result := S;
  SearchFrom := 1;

  while True do
  begin
    BlockStart := PosEx('<?', Result, SearchFrom);
    if BlockStart = 0 then
      Break;

    BlockEnd := PosEx('?>', Result, BlockStart + 2);
    if BlockEnd = 0 then
      Break;

    BlockLength := BlockEnd - BlockStart + 2;
    if Copy(Result, BlockEnd + 2, Length(sLineBreak)) = sLineBreak then
      Inc(BlockLength, Length(sLineBreak))
    else if (BlockEnd + 2 <= Length(Result)) and CharInSet(Result[BlockEnd + 2], [#13, #10]) then
      Inc(BlockLength);

    BlockText := Copy(Result, BlockStart, BlockLength);
    BlockText := StringReplace(BlockText, sLineBreak, '\n', [rfReplaceAll]);
    BlockText := StringReplace(BlockText, #13, '\n', [rfReplaceAll]);
    BlockText := StringReplace(BlockText, #10, '\n', [rfReplaceAll]);

    Result := Copy(Result, 1, BlockStart - 1) + BlockText +
      Copy(Result, BlockStart + BlockLength, MaxInt);
    SearchFrom := BlockStart + Length(BlockText);
  end;
end;

// frame= の直後に固定の group=1 を挿入する
procedure InsertGroupLine(Strings: TStrings);
var
  i: Integer;
begin
  if Strings = nil then Exit;

  for i := 0 to Strings.Count - 1 do
  begin
    if StartsText('frame=', Strings[i]) then
    begin
      Strings.Insert(i + 1, 'group=1');
      Exit;
    end;
  end;
end;

procedure AliasConvertSection(const Src: string; ObjIndex,Layer: Integer; Dest: TStringList);
var
  SL: TStringList;
  i: Integer;
  s: string;
  p1,p2: Integer;
  name: string;
begin
  SL := TStringList.Create;
  try
    SL.Text := Src;

    s := 'layer='+IntToStr(Layer);
    SL.Insert(1,s);
    InsertGroupLine(SL);

    for i := 0 to SL.Count-1 do
    begin
      s := SL[i];

      if (Length(s) > 2) and (s[1] = '[') then
      begin
        p2 := Pos(']', s);
        if p2 > 0 then
        begin
          name := Copy(s,2,p2-2);

          p1 := Pos('.', name);
          if p1 > 0 then
            s := '[' + IntToStr(ObjIndex) + Copy(name,p1,Length(name)) + ']'
          else
            s := '[' + IntToStr(ObjIndex) + ']';
        end;
      end;

      Dest.Add(s);
    end;

  finally
    SL.Free;
  end;
end;


procedure AviUtl2GetSelectedAlias(List: TStringList);
var
  obj : TObjectHandle;
  s   : string;
  i,n ,layer,frame_s,frame_e: Integer;
begin
  if List = nil then Exit;

  List.Clear;

  n := AviUtl2FindObjectSelectedNum();

  if n > 0 then
  begin
    for i := 0 to n-1 do
    begin
      obj := AviUtl2FindObjectSelected(i);
      if obj = nil then Continue;

      s := AviUtl2GetObjectAlias(obj);
      //s := AvrUtl2_AviUtlToStr(s);
      s := RestoreScriptBlockLineBreaks(s);

      AviUtl2GetObjectLayerFrame(obj,layer,frame_s,frame_e);

      AliasConvertSection(s,i,layer,List);
    end;
  end
  else
  begin
    obj := AviUtl2FindObjectFocus();
    if obj = nil then Exit;

    s := AviUtl2GetObjectAlias(obj);
    s := AvrUtl2_AviUtlToStr(s);
    s := RestoreScriptBlockLineBreaks(s);

    AliasConvertSection(s,0,0,List);
  end;
end;

end.
