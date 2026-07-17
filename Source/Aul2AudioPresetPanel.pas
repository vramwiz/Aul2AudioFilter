unit Aul2AudioPresetPanel;

// プリセットを一覧表示し、D&D用の音声グループObjectを生成するUIを提供する。

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
  TAul2AudioPresetLayout = (aplHorizontal, aplVertical);

  // 仮プリセット一覧と、選択項目をタイムラインへ渡すD&D操作を管理するパネル。
  TAul2AudioPresetPanel = class(TPanel)
  private
    FDrag       : TDragShellFile;
    FListBorder : TPanel;
    FPresetList : TListBoxEdit;
    FSaveButton : TButton;
    FDeleteButton: TButton;
    FDeleteOkButton: TButton;
    FDeleteCancelButton: TButton;
    FStatusLabel : TLabel;
    FShortcuts  : TShortcutAction;
    FInitialized: Boolean;
    FLayoutMode : TAul2AudioPresetLayout;
    FPresets    : TAul2AudioUserPresetList;
    FDeleteConfirmIndex: Integer;
    procedure CreateControls;
    procedure PresetListClick(Sender: TObject);
    procedure PresetListDblClick(Sender: TObject);
    procedure PresetListEdited(Sender: TObject; Index: Integer; var NewText: string);
    procedure PresetListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MoveSelectedPreset(Offset: Integer);
    procedure SaveButtonClick(Sender: TObject);
    procedure DeleteButtonClick(Sender: TObject);
    procedure DeleteOkButtonClick(Sender: TObject);
    procedure DeleteCancelButtonClick(Sender: TObject);
    procedure BeginDeleteConfirmation(Index: Integer);
    procedure CancelDeleteConfirmation;
    procedure DragRequest(Sender: TObject; FileNames: TStringList);
    procedure LoadPresets;
    procedure SavePresets;
    procedure RefreshPresetList;
    function NewPresetName: string;
    function CaptureSelectedObjectAlias(out AliasText: string): Boolean;
    function PresetFileName: string;
    function SaveSelectedPresetAlias: string;
    procedure SetLayoutMode(Value: TAul2AudioPresetLayout);
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
    property LayoutMode: TAul2AudioPresetLayout read FLayoutMode write SetLayoutMode
      default aplHorizontal;
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

function ScalePresetMetric(Value, PixelsPerInch: Integer): Integer;
begin
  Result := MulDiv(Value, Max(96, PixelsPerInch), 96);
end;

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
  FLayoutMode := aplHorizontal;
  FDeleteConfirmIndex := -1;
end;

procedure TAul2AudioPresetPanel.SetLayoutMode(Value: TAul2AudioPresetLayout);
begin
  if FLayoutMode = Value then
    Exit;

  FLayoutMode := Value;
  Resize;
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
  // 別ページから戻った時に、以前の削除確認を持ち越さない。
  CancelDeleteConfirmation;
  FStatusLabel.Caption := '';
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
  // OwnerDrawの行高はVCLが自動DPI変換しないため、編集用TEditと同じPPIで明示する。
  FPresetList.ItemHeight := ScalePresetMetric(20, Font.PixelsPerInch);
  FPresetList.OnClick := PresetListClick;
  FPresetList.OnDblClick := PresetListDblClick;
  FPresetList.OnEdited := PresetListEdited;
  FPresetList.OnKeyDown := PresetListKeyDown;
  FSaveButton := TButton.Create(Self);
  FSaveButton.Parent := Self;
  FSaveButton.Caption := '登録';
  FSaveButton.OnClick := SaveButtonClick;
  FDeleteButton := TButton.Create(Self);
  FDeleteButton.Parent := Self;
  FDeleteButton.Caption := '削除';
  FDeleteButton.OnClick := DeleteButtonClick;
  FDeleteOkButton := TButton.Create(Self);
  FDeleteOkButton.Parent := Self;
  FDeleteOkButton.Caption := 'OK';
  FDeleteOkButton.Visible := False;
  FDeleteOkButton.OnClick := DeleteOkButtonClick;
  FDeleteCancelButton := TButton.Create(Self);
  FDeleteCancelButton.Parent := Self;
  FDeleteCancelButton.Caption := 'キャンセル';
  FDeleteCancelButton.Visible := False;
  FDeleteCancelButton.OnClick := DeleteCancelButtonClick;
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
  CancelDeleteConfirmation;
  if FPresetList.IsEditing then
    Exit;
  FShortcuts.KeyDown(Key, Shift);
end;

procedure TAul2AudioPresetPanel.MoveSelectedPreset(Offset: Integer);
var
  Index   : Integer;
  NewIndex: Integer;
begin
  CancelDeleteConfirmation;
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
  ButtonGap  : Integer;
  ButtonHeight: Integer;
  ButtonTop  : Integer;
  ButtonWidth: Integer;
  ListTop    : Integer;
  ListHeight : Integer;
  ButtonLeft : Integer;
  Margin     : Integer;
  PixelsPerInch: Integer;
  StatusTop  : Integer;
begin
  inherited;
  if (FListBorder = nil) or (FPresetList = nil) or (FSaveButton = nil) or
     (FDeleteButton = nil) or (FDeleteOkButton = nil) or
     (FDeleteCancelButton = nil) or (FStatusLabel = nil) then
    Exit;

  PixelsPerInch := Font.PixelsPerInch;
  Margin := ScalePresetMetric(12, PixelsPerInch);
  ListTop := Margin;
  ButtonHeight := ScalePresetMetric(24, PixelsPerInch);
  if FLayoutMode = aplVertical then
  begin
    ButtonGap := ScalePresetMetric(8, PixelsPerInch);
    ButtonWidth := Max(1, (ClientWidth - (Margin * 2) - ButtonGap) div 2);
    if FDeleteConfirmIndex >= 0 then
      ListHeight := Max(ScalePresetMetric(32, PixelsPerInch),
        ClientHeight - ScalePresetMetric(116, PixelsPerInch))
    else if FStatusLabel.Caption <> '' then
      ListHeight := Max(ScalePresetMetric(32, PixelsPerInch),
        ClientHeight - ScalePresetMetric(88, PixelsPerInch))
    else
      ListHeight := Max(ScalePresetMetric(32, PixelsPerInch),
        ClientHeight - ScalePresetMetric(78, PixelsPerInch));
    ButtonTop := ListTop + ListHeight + ScalePresetMetric(8, PixelsPerInch);
    StatusTop := ButtonTop + ButtonHeight + ScalePresetMetric(8, PixelsPerInch);
    FListBorder.SetBounds(Margin, ListTop, Max(1, ClientWidth - (Margin * 2)),
      ListHeight);
    FSaveButton.SetBounds(Margin, ButtonTop, ButtonWidth, ButtonHeight);
    FDeleteButton.SetBounds(Margin + ButtonWidth + ButtonGap, ButtonTop,
      ButtonWidth, ButtonHeight);
    FStatusLabel.SetBounds(Margin, StatusTop, Max(1, ClientWidth - (Margin * 2)),
      Max(1, ClientHeight - StatusTop - ScalePresetMetric(8, PixelsPerInch)));
    FDeleteOkButton.SetBounds(Margin, StatusTop + ScalePresetMetric(20, PixelsPerInch),
      ButtonWidth, Max(1, ClientHeight - StatusTop - ScalePresetMetric(28, PixelsPerInch)));
    FDeleteCancelButton.SetBounds(Margin + ButtonWidth + ButtonGap,
      StatusTop + ScalePresetMetric(20, PixelsPerInch), ButtonWidth,
      Max(1, ClientHeight - StatusTop - ScalePresetMetric(28, PixelsPerInch)));
  end
  else
  begin
    // Monitorでは左側を一覧、右側を操作ボタン用の固定幅領域として使う。
    ListHeight := Max(ScalePresetMetric(32, PixelsPerInch),
      ClientHeight - (Margin * 2));
    ButtonLeft := Max(Margin, ClientWidth - ScalePresetMetric(104, PixelsPerInch));
    FListBorder.SetBounds(Margin, ListTop,
      Max(1, ButtonLeft - ScalePresetMetric(20, PixelsPerInch)), ListHeight);
    FSaveButton.SetBounds(ButtonLeft, ListTop, ScalePresetMetric(92, PixelsPerInch),
      ButtonHeight);
    FDeleteButton.SetBounds(ButtonLeft,
      ListTop + ButtonHeight + ScalePresetMetric(8, PixelsPerInch),
      ScalePresetMetric(92, PixelsPerInch), ButtonHeight);
    FStatusLabel.SetBounds(ButtonLeft, ListTop + ScalePresetMetric(84, PixelsPerInch),
      ScalePresetMetric(92, PixelsPerInch),
      Max(1, ListHeight - ScalePresetMetric(84, PixelsPerInch)));
    FDeleteOkButton.SetBounds(ButtonLeft, ListTop + ScalePresetMetric(124, PixelsPerInch),
      ScalePresetMetric(43, PixelsPerInch), ScalePresetMetric(28, PixelsPerInch));
    FDeleteCancelButton.SetBounds(ButtonLeft + ScalePresetMetric(49, PixelsPerInch),
      ListTop + ScalePresetMetric(124, PixelsPerInch),
      ScalePresetMetric(43, PixelsPerInch), ScalePresetMetric(28, PixelsPerInch));
  end;

  FPresetList.SetBounds(1, 1, Max(1, FListBorder.ClientWidth - 2),
    Max(1, FListBorder.ClientHeight - 2));
  FListBorder.Visible := True;
  FListBorder.BringToFront;
  FPresetList.Visible := True;
  FPresetList.BringToFront;
  FSaveButton.Visible := True;
  FSaveButton.BringToFront;
  FDeleteButton.Visible := True;
  FDeleteButton.BringToFront;
  FStatusLabel.Visible := True;
  FStatusLabel.BringToFront;
  FDeleteOkButton.Visible := FDeleteConfirmIndex >= 0;
  FDeleteCancelButton.Visible := FDeleteConfirmIndex >= 0;
  if FDeleteOkButton.Visible then
  begin
    FDeleteOkButton.BringToFront;
    FDeleteCancelButton.BringToFront;
  end;
end;

procedure TAul2AudioPresetPanel.PresetListClick(Sender: TObject);
begin
  CancelDeleteConfirmation;
end;

procedure TAul2AudioPresetPanel.SaveButtonClick(Sender: TObject);
var
  AliasText: string;
  Preset   : TAul2AudioUserPreset;
  PresetName: string;
begin
  if not CaptureSelectedObjectAlias(AliasText) then
  begin
    FStatusLabel.Caption := '登録するObjectを選択してください。';
    Resize;
    Exit;
  end;

  FStatusLabel.Caption := '';
  Resize;
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
  Index: Integer;
begin
  CancelDeleteConfirmation;
  Index := FPresetList.ItemIndex;
  if (Index < 0) or (Index >= FPresets.Count) then
  begin
    FStatusLabel.Caption := '削除するプリセットを選択してください。';
    Resize;
    Exit;
  end;

  BeginDeleteConfirmation(Index);
end;

procedure TAul2AudioPresetPanel.BeginDeleteConfirmation(Index: Integer);
begin
  if (Index < 0) or (Index >= FPresets.Count) then
    Exit;
  FDeleteConfirmIndex := Index;
  FStatusLabel.Caption := '「' + FPresets[Index].Name + '」を削除しますか？';
  FSaveButton.Enabled := False;
  FDeleteButton.Enabled := False;
  Resize;
end;

procedure TAul2AudioPresetPanel.CancelDeleteConfirmation;
var
  WasConfirming: Boolean;
begin
  WasConfirming := FDeleteConfirmIndex >= 0;
  FDeleteConfirmIndex := -1;
  FSaveButton.Enabled := True;
  FDeleteButton.Enabled := True;
  FDeleteOkButton.Visible := False;
  FDeleteCancelButton.Visible := False;
  if FDeleteOkButton.HandleAllocated then
    ShowWindow(FDeleteOkButton.Handle, SW_HIDE);
  if FDeleteCancelButton.HandleAllocated then
    ShowWindow(FDeleteCancelButton.Handle, SW_HIDE);
  if WasConfirming then
  begin
    FStatusLabel.Caption := '';
    Resize;
  end;
end;

procedure TAul2AudioPresetPanel.DeleteOkButtonClick(Sender: TObject);
var
  Index   : Integer;
  NewIndex: Integer;
begin
  Index := FDeleteConfirmIndex;
  CancelDeleteConfirmation;
  if (Index < 0) or (Index >= FPresets.Count) then
  begin
    FStatusLabel.Caption := '削除対象が変更されました。もう一度選択してください。';
    Resize;
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

procedure TAul2AudioPresetPanel.DeleteCancelButtonClick(Sender: TObject);
begin
  CancelDeleteConfirmation;
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
  CancelDeleteConfirmation;
  Index := FPresetList.ItemIndex;
  if (Index < 0) or (Index >= FPresets.Count) then
    Exit;

  FPresetList.BeginEdit(Index);
end;

procedure TAul2AudioPresetPanel.PresetListEdited(Sender: TObject; Index: Integer; var NewText: string);
begin
  CancelDeleteConfirmation;
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
  CancelDeleteConfirmation;
  FileName := SaveSelectedPresetAlias;
  if FileName = '' then
    Exit;
  FileNames.Add(FileName);
end;

end.
