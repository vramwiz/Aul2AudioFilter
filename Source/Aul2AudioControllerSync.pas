unit Aul2AudioControllerSync;

// 選択中ObjectのエイリアスからController検証用のDelay設定を一括取得する。

interface

type
  TControllerDelayReadResult = (
    cdrrLoaded,
    cdrrUnavailable,
    cdrrNoObject,
    cdrrNoAlias,
    cdrrFilterNotFound,
    cdrrDelayIncomplete
  );

  TControllerDelayState = record
    Use         : Boolean; // Dly: UseのON/OFF。
    StereoMode  : Integer; // Dly: Stereo Modeの選択値。
    TimeText    : string;  // Dly: Time(ms)のエイリアス表記。
    DryText     : string;  // Dly: Dryのエイリアス表記。
    WetText     : string;  // Dly: Wetのエイリアス表記。
    FeedbackText: string;  // Dly: Feedbackのエイリアス表記。
  end;

// フォーカスObjectからエイリアスを1回取得し、最初の音声エフェクトにあるDelay設定と診断結果を返す。
function CaptureSelectedDelayState(out State: TControllerDelayState): TControllerDelayReadResult;
// フォーカスObjectの音声エフェクトへ、指定したDelay項目だけを書き込む。
function SetSelectedDelayItem(const ItemName, Value: string): Boolean;

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
  PDelayCaptureContext = ^TDelayCaptureContext;
  TDelayCaptureContext = record
    AliasText: string;  // SDKから取得してUTF-16へ変換したエイリアス全文。
    Result   : TControllerDelayReadResult; // SDK取得段階の診断結果。
  end;

  PDelayWriteContext = ^TDelayWriteContext;
  TDelayWriteContext = record
    ItemName: string;     // 書き込むAul2AudioFilterのGUI項目名。
    Value   : UTF8String; // SDKへ渡すUTF-8表記の値。
    Success : Boolean;    // SetObjectItemValueが成功した場合True。
  end;

procedure ClearDelayState(out State: TControllerDelayState);
begin
  State.Use := False;
  State.StereoMode := 0;
  State.TimeText := '0';
  State.DryText := '0';
  State.WetText := '0';
  State.FeedbackText := '0';
end;

procedure CaptureSelectedAliasParam(Param: Pointer; Edit: PEditSection); cdecl;
var
  AliasValue: LPCSTR;
  Context   : PDelayCaptureContext;
  Obj       : TObjectHandle;
begin
  Context := PDelayCaptureContext(Param);
  if Context = nil then
    Exit;

  Context^.Result := cdrrUnavailable;
  Context^.AliasText := '';
  if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or not Assigned(Edit^.GetObjectAlias) then
    Exit;

  Obj := Edit^.GetFocusObject;
  if Obj = nil then
  begin
    Context^.Result := cdrrNoObject;
    Exit;
  end;

  AliasValue := Edit^.GetObjectAlias(Obj);
  if AliasValue = nil then
  begin
    Context^.Result := cdrrNoAlias;
    Exit;
  end;

  Context^.AliasText := UTF8ToString(AnsiString(AliasValue));
  if Context^.AliasText = '' then
    Context^.Result := cdrrNoAlias
  else
    Context^.Result := cdrrLoaded;
end;

procedure SetSelectedDelayItemParam(Param: Pointer; Edit: PEditSection); cdecl;
var
  Context: PDelayWriteContext;
  Obj    : TObjectHandle;
begin
  Context := PDelayWriteContext(Param);
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

function TryBuildDelayState(const EffectName: string; Values: TStrings;
  out State: TControllerDelayState): Boolean;
var
  FeedbackText: string;
  ModeText    : string;
  UseText     : string;
begin
  Result := False;
  if not IsTargetFilterName(EffectName) then
    Exit;

  if not TryGetAliasValue(Values, 'Dly: Use', UseText) or
     not TryGetAliasValue(Values, 'Dly: Stereo Mode', ModeText) or
     not TryGetAliasValue(Values, 'Dly: Time(ms)', State.TimeText) or
     not TryGetAliasValue(Values, 'Dly: Dry', State.DryText) or
     not TryGetAliasValue(Values, 'Dly: Wet', State.WetText) or
     not TryGetAliasValue(Values, 'Dly: Feedback', FeedbackText) then
    Exit;

  State.Use := StrToIntDef(Trim(UseText), 0) <> 0;
  ModeText := Trim(ModeText);
  if SameText(ModeText, 'Ping-Pong') then
    State.StereoMode := 1
  else if SameText(ModeText, 'Normal') then
    State.StereoMode := 0
  else
    State.StereoMode := StrToIntDef(ModeText, 0);
  State.FeedbackText := FeedbackText;
  Result := True;
end;

function TryParseDelayState(const AliasText: string; out State: TControllerDelayState;
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
  ClearDelayState(State);
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
        if TryBuildDelayState(EffectName, Values, State) then
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
    Result := TryBuildDelayState(EffectName, Values, State);
  finally
    Values.Free;
    Lines.Free;
  end;
end;

function CaptureSelectedDelayState(out State: TControllerDelayState): TControllerDelayReadResult;
var
  Context          : TDelayCaptureContext;
  TargetFilterFound: Boolean;
begin
  ClearDelayState(State);
  Result := cdrrUnavailable;
  if not Assigned(EditHandle) or not Assigned(EditHandle^.CallEditSectionParam) then
    Exit;

  Context.AliasText := '';
  Context.Result := cdrrUnavailable;
  if not EditHandle^.CallEditSectionParam(@Context, @CaptureSelectedAliasParam) then
    Exit;

  if Context.Result <> cdrrLoaded then
    Exit(Context.Result);

  if TryParseDelayState(Context.AliasText, State, TargetFilterFound) then
    Exit(cdrrLoaded);

  if TargetFilterFound then
    Result := cdrrDelayIncomplete
  else
    Result := cdrrFilterNotFound;
end;

function SetSelectedDelayItem(const ItemName, Value: string): Boolean;
var
  Context: TDelayWriteContext;
begin
  Result := False;
  if (ItemName = '') or not Assigned(EditHandle) or not Assigned(EditHandle^.CallEditSectionParam) then
    Exit;

  Context.ItemName := ItemName;
  Context.Value := UTF8String(Value);
  Context.Success := False;
  if not EditHandle^.CallEditSectionParam(@Context, @SetSelectedDelayItemParam) then
    Exit;

  Result := Context.Success;
end;

end.
