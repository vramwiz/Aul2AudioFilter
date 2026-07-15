unit Aul2AudioControllerSync;

// 選択中Objectのエイリアスから、定義で指定されたエフェクター設定を一括取得する。

interface

uses
  Aul2AudioControllerEffectDefinition;

type
  TControllerEffectReadResult = (
    cerrLoaded,
    cerrUnavailable,
    cerrNoObject,
    cerrNoAlias,
    cerrFilterNotFound,
    cerrEffectIncomplete
  );

  TControllerEffectState = record
    Use           : Boolean;
    SelectIndex   : Integer;
    ParameterTexts: array[0..CONTROLLER_MAX_VOLUME_COUNT - 1] of string;
  end;

// フォーカスObjectからエイリアスを1回取得し、指定エフェクターの設定と診断結果を返す。
function CaptureSelectedEffectState(const Definition: TControllerEffectDefinition;
  out State: TControllerEffectState): TControllerEffectReadResult;
// フォーカスObjectの音声エフェクトへ、指定したGUI項目だけを書き込む。
function SetSelectedEffectItem(const ItemName, Value: string): Boolean;

implementation

uses
  System.Classes,
  System.SysUtils,
  AviUtl2PluginCore,
  AviUtl2PluginTypes;

const
  FILTER_NAME_PRIMARY  = 'サウンドエフェクター'; // Aul2AudioFilterの現在の表示名。
  FILTER_NAME_FALLBACK = '音声効果';             // 旧名またはグループ名との互換候補。
  FILTER_NAME_INTERNAL = 'Aul2AudioFilter';      // 内部名がAliasへ出る環境の互換候補。

type
  PEffectCaptureContext = ^TEffectCaptureContext;
  TEffectCaptureContext = record
    AliasText: string;  // SDKから取得してUTF-16へ変換したエイリアス全文。
    Result   : TControllerEffectReadResult; // SDK取得段階の診断結果。
  end;

  PEffectWriteContext = ^TEffectWriteContext;
  TEffectWriteContext = record
    ItemName: string;     // 書き込むAul2AudioFilterのGUI項目名。
    Value   : UTF8String; // SDKへ渡すUTF-8表記の値。
    Success : Boolean;    // SetObjectItemValueが成功した場合True。
  end;

procedure ClearEffectState(out State: TControllerEffectState);
var
  Index: Integer;
begin
  State.Use := False;
  State.SelectIndex := 0;
  for Index := Low(State.ParameterTexts) to High(State.ParameterTexts) do
    State.ParameterTexts[Index] := '0';
end;

procedure CaptureSelectedAliasParam(Param: Pointer; Edit: PEditSection); cdecl;
var
  AliasValue: LPCSTR;
  Context   : PEffectCaptureContext;
  Obj       : TObjectHandle;
begin
  Context := PEffectCaptureContext(Param);
  if Context = nil then
    Exit;

  Context^.Result := cerrUnavailable;
  Context^.AliasText := '';
  if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or not Assigned(Edit^.GetObjectAlias) then
    Exit;

  Obj := Edit^.GetFocusObject;
  if Obj = nil then
  begin
    Context^.Result := cerrNoObject;
    Exit;
  end;

  AliasValue := Edit^.GetObjectAlias(Obj);
  if AliasValue = nil then
  begin
    Context^.Result := cerrNoAlias;
    Exit;
  end;

  Context^.AliasText := UTF8ToString(AnsiString(AliasValue));
  if Context^.AliasText = '' then
    Context^.Result := cerrNoAlias
  else
    Context^.Result := cerrLoaded;
end;

procedure SetSelectedEffectItemParam(Param: Pointer; Edit: PEditSection); cdecl;
var
  Context: PEffectWriteContext;
  Obj    : TObjectHandle;
begin
  Context := PEffectWriteContext(Param);
  if Context = nil then
    Exit;

  Context^.Success := False;
  if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or not Assigned(Edit^.SetObjectItemValue) then
    Exit;

  Obj := Edit^.GetFocusObject;
  if Obj = nil then
    Exit;

  Context^.Success := Edit^.SetObjectItemValue(
    Obj,
    PWideChar(FILTER_NAME_PRIMARY),
    PWideChar(Context^.ItemName),
    PAnsiChar(Context^.Value)) = True;
  if not Context^.Success then
    Context^.Success := Edit^.SetObjectItemValue(
      Obj,
      PWideChar(FILTER_NAME_FALLBACK),
      PWideChar(Context^.ItemName),
      PAnsiChar(Context^.Value)) = True;
end;

function IsTargetFilterName(const Value: string): Boolean;
begin
  Result := SameText(Value, FILTER_NAME_PRIMARY) or
    SameText(Value, FILTER_NAME_FALLBACK) or
    SameText(Value, FILTER_NAME_INTERNAL);
end;

function TryGetAliasValue(Values: TStrings; const Name: string; out Value: string): Boolean;
var
  Index: Integer;
begin
  Index := Values.IndexOfName(Name);
  Result := Index >= 0;
  if Result then
    Value := Values.ValueFromIndex[Index]
  else
    Value := '';
end;

function TryBuildEffectState(const EffectName: string; Values: TStrings;
  const Definition: TControllerEffectDefinition;
  out State: TControllerEffectState): Boolean;
var
  ItemIndex: Integer;
  SelectText: string;
  UseText: string;
begin
  Result := False;
  if not IsTargetFilterName(EffectName) then
    Exit;

  if (Definition.UseItemName = '') or
     not TryGetAliasValue(Values, Definition.UseItemName, UseText) then
    Exit;

  State.Use := StrToIntDef(Trim(UseText), 0) <> 0;

  if Definition.SelectControl.Visible then
  begin
    if not TryGetAliasValue(Values, Definition.SelectControl.ItemName, SelectText) then
      Exit;
    State.SelectIndex := -1;
    SelectText := Trim(SelectText);
    for ItemIndex := 0 to High(Definition.SelectControl.Items) do
      if SameText(SelectText, Definition.SelectControl.Items[ItemIndex]) then
      begin
        State.SelectIndex := ItemIndex;
        Break;
      end;
    if State.SelectIndex < 0 then
      State.SelectIndex := StrToIntDef(SelectText, -1);
  end;

  if Length(Definition.Volumes) > Length(State.ParameterTexts) then
    Exit;
  for ItemIndex := 0 to High(Definition.Volumes) do
    if not TryGetAliasValue(Values, Definition.Volumes[ItemIndex].ItemName,
      State.ParameterTexts[ItemIndex]) then
      Exit;
  Result := True;
end;

function TryParseEffectState(const AliasText: string;
  const Definition: TControllerEffectDefinition; out State: TControllerEffectState;
  out TargetFilterFound: Boolean): Boolean;
var
  EffectName: string;
  Key       : string;
  Line      : string;
  Lines     : TStringList;
  LineIndex : Integer;
  Separator : Integer;
  Value     : string;
  Values    : TStringList;
begin
  Result := False;
  TargetFilterFound := False;
  ClearEffectState(State);
  if AliasText = '' then
    Exit;

  Lines := TStringList.Create;
  Values := TStringList.Create;
  try
    Lines.Text := AliasText;
    EffectName := '';

    for LineIndex := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[LineIndex]);
      if Line = '' then
        Continue;

      if (Line[1] = '[') and (Line[Length(Line)] = ']') then
      begin
        TargetFilterFound := TargetFilterFound or IsTargetFilterName(EffectName);
        if TryBuildEffectState(EffectName, Values, Definition, State) then
          Exit(True);

        EffectName := '';
        Values.Clear;
        Continue;
      end;

      Separator := Pos('=', Line);
      if Separator <= 0 then
        Continue;

      Key := Trim(Copy(Line, 1, Separator - 1));
      Value := Copy(Line, Separator + 1, MaxInt);
      if SameText(Key, 'effect.name') then
        EffectName := Value
      else
        Values.Values[Key] := Value;
    end;

    TargetFilterFound := TargetFilterFound or IsTargetFilterName(EffectName);
    Result := TryBuildEffectState(EffectName, Values, Definition, State);
  finally
    Values.Free;
    Lines.Free;
  end;
end;

function CaptureSelectedEffectState(const Definition: TControllerEffectDefinition;
  out State: TControllerEffectState): TControllerEffectReadResult;
var
  Context          : TEffectCaptureContext;
  TargetFilterFound: Boolean;
begin
  ClearEffectState(State);
  Result := cerrUnavailable;
  if not Assigned(EditHandle) or not Assigned(EditHandle^.CallEditSectionParam) then
    Exit;

  Context.AliasText := '';
  Context.Result := cerrUnavailable;
  if not EditHandle^.CallEditSectionParam(@Context, @CaptureSelectedAliasParam) then
    Exit;

  if Context.Result <> cerrLoaded then
    Exit(Context.Result);

  if TryParseEffectState(Context.AliasText, Definition, State, TargetFilterFound) then
    Exit(cerrLoaded);

  if TargetFilterFound then
    Result := cerrEffectIncomplete
  else
    Result := cerrFilterNotFound;
end;

function SetSelectedEffectItem(const ItemName, Value: string): Boolean;
var
  Context: TEffectWriteContext;
begin
  Result := False;
  if (ItemName = '') or not Assigned(EditHandle) or not Assigned(EditHandle^.CallEditSectionParam) then
    Exit;

  Context.ItemName := ItemName;
  Context.Value := UTF8String(Value);
  Context.Success := False;
  if not EditHandle^.CallEditSectionParam(@Context, @SetSelectedEffectItemParam) then
    Exit;

  Result := Context.Success;
end;

end.
