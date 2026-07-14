unit Aul2AudioPresetPanel;

// MonitorのPresetページで仮プリセットを一覧表示し、D&D用の音声グループObjectを生成する。

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  DragAgent,
  ListBoxEdit,
  ShortcutAction,
  Aul2AudioPresetModel;

type
  // 仮プリセット一覧と、選択項目をタイムラインへ渡すD&D操作を管理するパネル。
  TAul2AudioPresetPanel = class(TPanel)
  private
    FDrag       : TDragShellFile;
    FListBorder : TPanel;
    FPresetList : TListBoxEdit;
    FSaveButton : TButton;
    FDeleteButton: TButton;
    FStatusLabel : TLabel;
    FShortcuts  : TShortcutAction;
    FInitialized: Boolean;
    FPresets    : TAul2AudioUserPresetList;
    procedure CreateControls;
    procedure PresetListDblClick(Sender: TObject);
    procedure PresetListEdited(Sender: TObject; Index: Integer; var NewText: string);
    procedure PresetListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MoveSelectedPreset(Offset: Integer);
    procedure SaveButtonClick(Sender: TObject);
    procedure DeleteButtonClick(Sender: TObject);
    procedure DragRequest(Sender: TObject; FileNames: TStringList);
    procedure LoadPresets;
    procedure SavePresets;
    procedure RefreshPresetList;
    function NewPresetName: string;
    function CaptureSelectedObjectAlias(out AliasText: string): Boolean;
    function PresetFileName: string;
    function SaveSelectedPresetAlias: string;
  protected
    // AviUtl2内の動的なページサイズに合わせ、一覧を説明欄と状態欄の間へ配置する。
    procedure Resize; override;
  public
    // ダークテーマのPresetページを構築し、一覧へD&Dエージェントを関連付ける。
    constructor Create(AOwner: TComponent); override;
    // D&Dエージェントを子コントロールより先に解放する。
    destructor Destroy; override;
    // 親ウィンドウへの関連付け後に、子コントロールとD&Dを一度だけ構築する。
    procedure Initialize;
    // 親ページの再表示後に、一覧と操作欄の配置・可視性・前面順を復元する。
    procedure RefreshLayout;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  Vcl.Graphics,
  AviUtl2PluginCore,
  AviUtl2PluginTypes;

const
  PRESET_TEMP_DIR       = 'Aul2AudioFilter';             // D&D用Objectを置く一時サブフォルダー。
  PRESET_FILE_NAME      = 'Aul2AudioPreset.object';      // シェルへ渡す再構築済みエイリアス名。
  PRESET_EFFECT_NAME    = 'Aul2AudioFilter';             // この一覧が扱うエフェクト識別名。
  PRESET_PREVIEW_PREFIX = 'グループ制御（音声） / ';    // 復号せず確認する概要の先頭文字列。

type
  // CallEditSectionParam内で選択Objectのエイリアスを受け取る一時コンテキスト。
  PPresetCaptureContext = ^TPresetCaptureContext;
  TPresetCaptureContext = record
    AliasText: string;  // SDKから取得してUTF-16へ変換したエイリアス全文。
    Success  : Boolean; // 選択Objectとエイリアスの両方を取得できた場合True。
  end;

procedure CaptureSelectedAliasParam(Param: Pointer; Edit: PEditSection); cdecl;
var
  AliasValue: LPCSTR;
  Context   : PPresetCaptureContext;
  Obj       : TObjectHandle;
begin
  Context := PPresetCaptureContext(Param);
  if Context = nil then
    Exit;

  Context^.Success := False;
  Context^.AliasText := '';
  if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or not Assigned(Edit^.GetObjectAlias) then
    Exit;

  Obj := Edit^.GetFocusObject;
  if Obj = nil then
    Exit;

  AliasValue := Edit^.GetObjectAlias(Obj);
  if AliasValue = nil then
    Exit;

  Context^.AliasText := UTF8ToString(AnsiString(AliasValue));
  Context^.Success := Context^.AliasText <> '';
end;

constructor TAul2AudioPresetPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  Color := RGB(36, 36, 36);
  ParentBackground := False;
  ParentFont := False;
  Font.Name := 'Yu Gothic UI';
  Font.Size := 9;
  Font.Color := RGB(230, 230, 230);
  FPresets := TAul2AudioUserPresetList.Create(True);
  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(VK_UP, [ssCtrl],
    procedure
    begin
      MoveSelectedPreset(-1);
    end);
  FShortcuts.Add(VK_DOWN, [ssCtrl],
    procedure
    begin
      MoveSelectedPreset(1);
    end);
  FInitialized := False;
end;

destructor TAul2AudioPresetPanel.Destroy;
begin
  FDrag.Free;
  FShortcuts.Free;
  FPresets.Free;
  inherited;
end;

procedure TAul2AudioPresetPanel.Initialize;
begin
  if FInitialized then
    Exit;

  // VCLハンドル生成は、PresetPanelがMonitorの親ウィンドウへ接続された後に限定する。
  CreateControls;
  FDrag := TDragShellFile.Create(nil);
  FDrag.Attach(FPresetList);
  FDrag.OnDragRequest := DragRequest;
  LoadPresets;
  FInitialized := True;
end;

procedure NudgePresetWindow(Control: TWinControl);
var
  ControlHeight: Integer;
  ControlWidth : Integer;
begin
  if not Assigned(Control) or not Control.HandleAllocated then
    Exit;
  ControlWidth := Control.Width;
  ControlHeight := Control.Height;
  if (ControlWidth <= 1) or (ControlHeight <= 0) then
    Exit;
  // 同じサイズのSetBoundsはVCL側で省略されるため、Win32へ1px差のWM_SIZEを明示的に送る。
  SetWindowPos(Control.Handle, 0, Control.Left, Control.Top,
    ControlWidth - 1, ControlHeight, SWP_NOZORDER or SWP_NOACTIVATE or SWP_SHOWWINDOW);
  SetWindowPos(Control.Handle, 0, Control.Left, Control.Top,
    ControlWidth, ControlHeight, SWP_NOZORDER or SWP_NOACTIVATE or SWP_SHOWWINDOW);
end;

procedure TAul2AudioPresetPanel.RefreshLayout;
begin
  if not FInitialized then
    Exit;
  Resize;
  // VCLのVisible値がTrueのままネイティブ子ウィンドウだけ隠れる場合も強制的に復旧する。
  if HandleAllocated then
    ShowWindow(Handle, SW_SHOWNA);
  if Assigned(FPresetList) and FPresetList.HandleAllocated then
    ShowWindow(FPresetList.Handle, SW_SHOWNA);
  if Assigned(FListBorder) and FListBorder.HandleAllocated then
    ShowWindow(FListBorder.Handle, SW_SHOWNA);
  if Assigned(FSaveButton) and FSaveButton.HandleAllocated then
    ShowWindow(FSaveButton.Handle, SW_SHOWNA);
  if Assigned(FDeleteButton) and FDeleteButton.HandleAllocated then
    ShowWindow(FDeleteButton.Handle, SW_SHOWNA);
  if Assigned(FStatusLabel) then
  begin
    FStatusLabel.Visible := True;
    FStatusLabel.BringToFront;
  end;
  // 親リサイズ後に通常の再描画要求が失われるため、1pxのダミーリサイズでWM_SIZEを発生させる。
  NudgePresetWindow(Self);
  NudgePresetWindow(FListBorder);
  NudgePresetWindow(FPresetList);
  NudgePresetWindow(FSaveButton);
  NudgePresetWindow(FDeleteButton);
  FStatusLabel.Invalidate;
end;

procedure TAul2AudioPresetPanel.CreateControls;
begin
  FListBorder := TPanel.Create(Self);
  FListBorder.Parent := Self;
  FListBorder.BevelOuter := bvLowered;
  FListBorder.BevelWidth := 1;
  FListBorder.Caption := '';
  FListBorder.Color := RGB(32, 32, 32);
  FListBorder.ParentBackground := False;
  FPresetList := TListBoxEdit.Create(Self);
  FPresetList.Parent := FListBorder;
  FPresetList.Align := alNone;
  FPresetList.BorderStyle := bsNone;
  FPresetList.Color := RGB(32, 32, 32);
  FPresetList.Font.Color := RGB(230, 230, 230);
  FPresetList.ItemHeight := 24;
  FPresetList.OnDblClick := PresetListDblClick;
  FPresetList.OnEdited := PresetListEdited;
  FPresetList.OnKeyDown := PresetListKeyDown;
  FSaveButton := TButton.Create(Self);
  FSaveButton.Parent := Self;
  FSaveButton.Caption := '保存';
  FSaveButton.OnClick := SaveButtonClick;
  FDeleteButton := TButton.Create(Self);
  FDeleteButton.Parent := Self;
  FDeleteButton.Caption := '削除';
  FDeleteButton.OnClick := DeleteButtonClick;
  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.AutoSize := False;
  FStatusLabel.WordWrap := True;
  FStatusLabel.Font.Color := RGB(255, 160, 96);
  FStatusLabel.Caption := '';
  Resize;
end;

procedure TAul2AudioPresetPanel.PresetListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FPresetList.IsEditing then
    Exit;
  FShortcuts.KeyDown(Key, Shift);
end;

procedure TAul2AudioPresetPanel.MoveSelectedPreset(Offset: Integer);
var
  Index   : Integer;
  NewIndex: Integer;
begin
  Index := FPresetList.ItemIndex;
  NewIndex := Index + Offset;
  if (Index < 0) or (Index >= FPresets.Count) or
     (NewIndex < 0) or (NewIndex >= FPresets.Count) then
    Exit;

  FPresets.Exchange(Index, NewIndex);
  SavePresets;
  RefreshPresetList;
  FPresetList.ItemIndex := NewIndex;
end;

procedure TAul2AudioPresetPanel.Resize;
var
  ListTop   : Integer;
  ListHeight: Integer;
  ButtonLeft: Integer;
begin
  inherited;
  if (FListBorder = nil) or (FPresetList = nil) or (FSaveButton = nil) or
     (FDeleteButton = nil) or (FStatusLabel = nil) then
    Exit;

  // 左側を一覧、右側を操作ボタン用の固定幅領域として使う。
  ListTop := 12;
  ListHeight := Max(32, ClientHeight - 24);
  ButtonLeft := Max(12, ClientWidth - 104);
  FListBorder.SetBounds(12, ListTop, Max(1, ButtonLeft - 20), ListHeight);
  FPresetList.SetBounds(1, 1, Max(1, FListBorder.ClientWidth - 2),
    Max(1, FListBorder.ClientHeight - 2));
  FListBorder.Visible := True;
  FListBorder.BringToFront;
  FPresetList.Visible := True;
  FPresetList.BringToFront;
  FSaveButton.SetBounds(ButtonLeft, ListTop, 92, 30);
  FSaveButton.Visible := True;
  FSaveButton.BringToFront;
  FDeleteButton.SetBounds(ButtonLeft, ListTop + 38, 92, 30);
  FDeleteButton.Visible := True;
  FDeleteButton.BringToFront;
  FStatusLabel.SetBounds(ButtonLeft, ListTop + 76, 92, Max(1, ListHeight - 76));
  FStatusLabel.Visible := True;
  FStatusLabel.BringToFront;
end;

procedure TAul2AudioPresetPanel.SaveButtonClick(Sender: TObject);
var
  AliasText: string;
  Preset   : TAul2AudioUserPreset;
  PresetName: string;
begin
  if not CaptureSelectedObjectAlias(AliasText) then
  begin
    FStatusLabel.Caption := '保存するObjectを選択してください。';
    Exit;
  end;

  FStatusLabel.Caption := '';
  PresetName := NewPresetName;
  Preset := FPresets.AddNew;
  Preset.Name := PresetName;
  Preset.Effect := PRESET_EFFECT_NAME;
  Preset.Preview := PRESET_PREVIEW_PREFIX + PresetName;
  Preset.AssignAliasText(AliasText);
  SavePresets;
  RefreshPresetList;
  FPresetList.ItemIndex := FPresetList.Items.Count - 1;
end;

procedure TAul2AudioPresetPanel.DeleteButtonClick(Sender: TObject);
var
  Index   : Integer;
  NewIndex: Integer;
begin
  FStatusLabel.Caption := '';
  Index := FPresetList.ItemIndex;
  if (Index < 0) or (Index >= FPresets.Count) then
  begin
    FStatusLabel.Caption := '削除するプリセットを選択してください。';
    Exit;
  end;

  FPresets.Delete(Index);
  SavePresets;
  RefreshPresetList;
  if FPresets.Count = 0 then
    NewIndex := -1
  else
    NewIndex := Min(Index, FPresets.Count - 1);
  FPresetList.ItemIndex := NewIndex;
end;

function TAul2AudioPresetPanel.NewPresetName: string;
var
  Index    : Integer;
  Number   : Integer;
  Candidate: string;
  Exists   : Boolean;
begin
  Number := 1;
  repeat
    Candidate := '新しいプリセット ' + IntToStr(Number);
    Exists := False;
    for Index := 0 to FPresets.Count - 1 do
      if SameText(FPresets[Index].Name, Candidate) then
      begin
        Exists := True;
        Break;
      end;
    Inc(Number);
  until not Exists;
  Result := Candidate;
end;

procedure TAul2AudioPresetPanel.PresetListDblClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := FPresetList.ItemIndex;
  if (Index < 0) or (Index >= FPresets.Count) then
    Exit;

  FPresetList.BeginEdit(Index);
end;

procedure TAul2AudioPresetPanel.PresetListEdited(Sender: TObject; Index: Integer; var NewText: string);
begin
  if (Index < 0) or (Index >= FPresets.Count) then
    Exit;

  NewText := Trim(NewText);
  if NewText = '' then
    NewText := FPresets[Index].Name;
  FPresets[Index].Name := NewText;
  FPresets[Index].Preview := PRESET_PREVIEW_PREFIX + NewText;
  SavePresets;
end;

function TAul2AudioPresetPanel.CaptureSelectedObjectAlias(out AliasText: string): Boolean;
var
  Context: TPresetCaptureContext;
begin
  AliasText := '';
  Result := False;
  if not Assigned(EditHandle) then
    Exit;

  Context.AliasText := '';
  Context.Success := False;
  if not EditHandle^.CallEditSectionParam(@Context, @CaptureSelectedAliasParam) then
    Exit;

  AliasText := Context.AliasText;
  Result := Context.Success;
end;

function TAul2AudioPresetPanel.PresetFileName: string;
var
  DirectoryName: string;
begin
  DirectoryName := TPath.Combine(TPath.GetDocumentsPath, 'Aul2AudioFilter');
  ForceDirectories(DirectoryName);
  Result := TPath.Combine(DirectoryName, 'UserPresets.ini');
end;

procedure TAul2AudioPresetPanel.RefreshPresetList;
var
  Index: Integer;
begin
  FPresetList.Items.BeginUpdate;
  try
    FPresetList.Items.Clear;
    for Index := 0 to FPresets.Count - 1 do
      FPresetList.Items.Add(FPresets[Index].Name);
    if FPresetList.Items.Count > 0 then
      FPresetList.ItemIndex := 0;
  finally
    FPresetList.Items.EndUpdate;
  end;
end;

procedure TAul2AudioPresetPanel.LoadPresets;
var
  Index: Integer;
begin
  FPresets.Clear;
  FPresets.Filename := PresetFileName;
  FPresets.LoadFromFile;
  for Index := FPresets.Count - 1 downto 0 do
    if not SameText(FPresets[Index].Effect, PRESET_EFFECT_NAME) or
       (FPresets[Index].AliasItems.Count = 0) then
      FPresets.Delete(Index);
  RefreshPresetList;
end;

procedure TAul2AudioPresetPanel.SavePresets;
begin
  FPresets.Filename := PresetFileName;
  FPresets.SaveToFile;
end;

function TAul2AudioPresetPanel.SaveSelectedPresetAlias: string;
var
  DirectoryName: string;
  Index        : Integer;
  Strings      : TStringList;
  Encoding     : TEncoding;
begin
  Result := '';
  Index := FPresetList.ItemIndex;
  if (Index < 0) or (Index >= FPresets.Count) then
    Exit;

  DirectoryName := TPath.Combine(TPath.GetTempPath, PRESET_TEMP_DIR);
  ForceDirectories(DirectoryName);
  Result := TPath.Combine(DirectoryName, PRESET_FILE_NAME);

  Strings := TStringList.Create;
  Encoding := TUTF8Encoding.Create(False);
  try
    // 型付きAlias項目から保存時のObject構成を復元し、シェルD&D用の一時ファイルへ書き出す。
    Strings.Text := FPresets[Index].BuildAliasText;
    Strings.SaveToFile(Result, Encoding);
  finally
    Encoding.Free;
    Strings.Free;
  end;
end;

procedure TAul2AudioPresetPanel.DragRequest(Sender: TObject; FileNames: TStringList);
var
  FileName: string;
begin
  FileName := SaveSelectedPresetAlias;
  if FileName = '' then
    Exit;
  FileNames.Add(FileName);
end;

end.
