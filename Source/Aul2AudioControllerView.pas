unit Aul2AudioControllerView;

// ControllerのVCLフォーム、選択エフェクターの取得、パラメーター配置を担当する。

interface

uses
  Winapi.Windows;

const
  CONTROLLER_WINDOW_NAME = 'Aul2AudioController'; // フォームとクライアントで共有する表示名。

// Controllerフォームを生成し、ParentWindowの子としてエフェクターGUIを構築する。
procedure CreateControllerView(ParentWindow: HWND);
// タイマーとControllerフォームを停止・解放する。
procedure DestroyControllerView;
// 作成済みControllerフォームを表示して前面へ移す。
procedure ShowControllerView;
// 親クライアントの現在サイズへControllerフォームを追従させる。
procedure SyncControllerViewBounds;
// AviUtl2クライアントから通知された寸法へRootPanelとフォームを追従させる。
procedure ResizeControllerView(Width, Height: Integer);
// クライアントWndProcのマウス進入通知から選択エフェクター再取得を1回だけ発火する。
procedure NotifyControllerMouseEnter;

implementation

uses
  Winapi.UxTheme,
  System.Classes,
  System.Math,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Aul2AudioControllerEffectDefinition,
  Aul2AudioControllerLampSwitch,
  Aul2AudioControllerSync,
  Aul2AudioControllerVolumeControl,
  Aul2AudioBasePanel,
  Aul2AudioPresetPanel;

const
  CONTROLLER_PRESET_ITEM_INDEX = CONTROLLER_EFFECT_COUNT;
  CONTROLLER_PRESET_ITEM_NAME  = 'エフェクトプリセットの管理';
  CONTROLLER_BASE_ITEM_INDEX   = CONTROLLER_EFFECT_COUNT + 1;
  CONTROLLER_BASE_ITEM_NAME    = '波形表示オブジェクトの配置';

type
  TControlAccess = class(TControl);

  TEffectComboBox = class(TComboBox)
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  end;

  TFormAudioController = class(TForm)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TControllerEventTarget = class(TComponent)
  public
    procedure EffectVolumeChange(Sender: TObject; const ValueText: string; var Accept: Boolean);
    procedure EffectComboChange(Sender: TObject);
    procedure ModeComboChange(Sender: TObject);
    procedure MouseBoundaryTimer(Sender: TObject);
    procedure ControllerMouseEnter(Sender: TObject);
    procedure UseLampClick(Sender: TObject);
  end;

var
  ClientWindow   : HWND;
  ControllerForm : TFormAudioController;
  RootPanel      : TPanel;
  BasePanel      : TAul2AudioBasePanel;
  PresetPanel    : TAul2AudioPresetPanel;
  StatusLabel    : TLabel;
  EffectCombo    : TEffectComboBox;
  LampSwitchHost : TPanel;
  UseLamp        : TAul2LampSwitch;
  ModeLabel      : TLabel;
  ModeCombo      : TComboBox;
  VolumeControls : array[0..CONTROLLER_MAX_VOLUME_COUNT - 1] of TAul2VolumeControl;
  MouseTimer     : TTimer;
  EventTarget    : TControllerEventTarget;
  MouseInside    : Boolean;
  Refreshing     : Boolean;
  LastUse        : Boolean;
  LastSelectIndex: Integer;

constructor TFormAudioController.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := CONTROLLER_WINDOW_NAME;
  BorderStyle := bsNone;
  Position := poDesigned;
  Color := RGB(28, 30, 33);
end;

function TEffectComboBox.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
var
  NewIndex: Integer;
begin
  if DroppedDown or (Items.Count = 0) or (WheelDelta = 0) then
    Exit(inherited DoMouseWheel(Shift, WheelDelta, MousePos));

  NewIndex := ItemIndex;
  if WheelDelta > 0 then
    Dec(NewIndex)
  else
    Inc(NewIndex);
  NewIndex := EnsureRange(NewIndex, 0, Items.Count - 1);
  if NewIndex <> ItemIndex then
  begin
    ItemIndex := NewIndex;
    Change;
  end;
  Result := True;
end;

function Scale(Value: Integer): Integer;
begin
  if Assigned(ControllerForm) then
    Result := MulDiv(Value, ControllerForm.Font.PixelsPerInch, 96)
  else
    Result := Value;
end;

procedure RegisterMouseEnter(Control: TControl);
begin
  if Assigned(Control) and Assigned(EventTarget) then
    TControlAccess(Control).OnMouseEnter := EventTarget.ControllerMouseEnter;
end;

procedure ApplyDarkComboStyle(Combo: TComboBox);
begin
  Combo.Color := RGB(42, 45, 49);
  Combo.Font.Assign(ControllerForm.Font);
  Combo.Font.Color := RGB(250, 250, 250);
  Combo.ParentFont := False;
  Combo.HandleNeeded;
  SetWindowTheme(Combo.Handle, '', '');
end;

procedure ApplyEffectTheme(EffectIndex: Integer);
var
  BackgroundColor: TColor;
  ControlIndex   : Integer;
  Definition     : TControllerEffectDefinition;
  ThemeColor: TColor;
begin
  if not Assigned(ControllerForm) or not Assigned(RootPanel) or not Assigned(UseLamp) then
    Exit;
  if not GetControllerEffectDefinition(EffectIndex, Definition) then
    Exit;

  ThemeColor := Definition.ThemeColor;
  BackgroundColor := Definition.BackgroundColor;
  ControllerForm.Color := BackgroundColor;
  RootPanel.Color := BackgroundColor;
  LampSwitchHost.Color := BackgroundColor;
  UseLamp.Color := BackgroundColor;
  UseLamp.PanelColor := Definition.VolumeColor;
  UseLamp.TextColor := Definition.TextColor;
  ModeLabel.Color := BackgroundColor;
  ModeLabel.Font.Color := Definition.TextColor;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
  begin
    VolumeControls[ControlIndex].Color := ThemeColor;
    VolumeControls[ControlIndex].PanelColor := Definition.VolumeColor;
    VolumeControls[ControlIndex].AccentColor := Definition.IndicatorColor;
    VolumeControls[ControlIndex].TextColor := Definition.TextColor;
  end;
  RootPanel.Invalidate;
end;

function GetVolumeControl(Index: Integer): TAul2VolumeControl;
begin
  if (Index >= Low(VolumeControls)) and (Index <= High(VolumeControls)) then
    Result := VolumeControls[Index]
  else
    Result := nil;
end;

function GetCurrentEffectDefinition(
  out Definition: TControllerEffectDefinition): Boolean;
begin
  Result := Assigned(EffectCombo) and
    GetControllerEffectDefinition(EffectCombo.ItemIndex, Definition);
end;

function IsBasePanelSelected: Boolean;
begin
  Result := Assigned(EffectCombo) and
    (EffectCombo.ItemIndex = CONTROLLER_BASE_ITEM_INDEX);
end;

function IsPresetPanelSelected: Boolean;
begin
  Result := Assigned(EffectCombo) and
    (EffectCombo.ItemIndex = CONTROLLER_PRESET_ITEM_INDEX);
end;

procedure LayoutControllerView;
var
  ContentWidth: Integer;
  ColumnCount : Integer;
  ColumnIndex : Integer;
  ControlGap  : Integer;
  ControlHeight: Integer;
  ControlIndex: Integer;
  ControlLeft : Integer;
  ControlTop  : Integer;
  ControlWidth: Integer;
  EditLeft    : Integer;
  EditWidth   : Integer;
  LabelWidth  : Integer;
  LeftMargin  : Integer;
  RowHeight   : Integer;
  TopPosition : Integer;
  VisibleControlCount: Integer;
begin
  if not Assigned(ControllerForm) or not Assigned(RootPanel) then
    Exit;

  LeftMargin := Scale(18);
  LabelWidth := Scale(96);
  RowHeight := Scale(34);
  ContentWidth := RootPanel.ClientWidth - LeftMargin * 2;
  EditLeft := LeftMargin + LabelWidth;
  EditWidth := ContentWidth - LabelWidth;
  if EditWidth < Scale(80) then
    EditWidth := Scale(80);

  EffectCombo.SetBounds(LeftMargin, Scale(6), ContentWidth, Scale(27));
  if IsBasePanelSelected then
  begin
    BasePanel.SetBounds(0, Scale(37), RootPanel.ClientWidth,
      Max(1, RootPanel.ClientHeight - Scale(37)));
    Exit;
  end;
  if IsPresetPanelSelected then
  begin
    PresetPanel.SetBounds(0, Scale(37), RootPanel.ClientWidth,
      Max(1, RootPanel.ClientHeight - Scale(37)));
    Exit;
  end;

  LampSwitchHost.SetBounds(LeftMargin, Scale(37), ContentWidth, Scale(28));
  UseLamp.SetBounds(0, 0, ContentWidth, Scale(28));

  TopPosition := Scale(69);
  if ModeCombo.Visible then
  begin
    ModeLabel.SetBounds(LeftMargin, TopPosition + Scale(4), LabelWidth, Scale(23));
    ModeCombo.SetBounds(EditLeft, TopPosition, EditWidth, Scale(25));
    Inc(TopPosition, RowHeight);
  end;

  VisibleControlCount := 0;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
    if VolumeControls[ControlIndex].Visible then
      Inc(VisibleControlCount);
  if VisibleControlCount = 0 then
    Exit;

  ControlGap := Scale(6);
  // ノブ内部は固定ピクセル描画のため、DPI拡大で値欄との間隔を広げない。
  ControlHeight := 126;
  ColumnCount := Max(1, (ContentWidth + ControlGap) div (Scale(64) + ControlGap));
  ColumnCount := Min(ColumnCount, VisibleControlCount);
  ControlWidth := (ContentWidth - ControlGap * (ColumnCount - 1)) div ColumnCount;
  ControlWidth := Min(ControlWidth, Scale(84));
  ColumnIndex := 0;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
  begin
    if not VolumeControls[ControlIndex].Visible then
      Continue;
    ControlLeft := LeftMargin + (ColumnIndex mod ColumnCount) * (ControlWidth + ControlGap);
    ControlTop := TopPosition + (ColumnIndex div ColumnCount) * (ControlHeight + ControlGap);
    VolumeControls[ControlIndex].SetBounds(ControlLeft, ControlTop, ControlWidth, ControlHeight);
    Inc(ColumnIndex);
  end;
end;

procedure ApplyEmptyEffectState;
var
  ControlIndex: Integer;
  VolumeControl: TAul2VolumeControl;
begin
  UseLamp.Checked := False;
  if ModeCombo.Items.Count > 0 then
    ModeCombo.ItemIndex := 0
  else
    ModeCombo.ItemIndex := -1;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
  begin
    VolumeControl := GetVolumeControl(ControlIndex);
    if Assigned(VolumeControl) and VolumeControl.Visible then
      VolumeControl.Value := VolumeControl.Minimum;
  end;
end;

procedure RepaintEffectControls;
var
  ControlIndex: Integer;
begin
  EffectCombo.Invalidate;
  StatusLabel.Invalidate;
  UseLamp.Invalidate;
  ModeLabel.Invalidate;
  ModeCombo.Invalidate;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
    VolumeControls[ControlIndex].Invalidate;
  RootPanel.Update;
end;

procedure ConfigureCurrentEffect;
var
  ControlIndex: Integer;
  Definition: TControllerEffectDefinition;
  SelectIndex: Integer;
  VolumeControl: TAul2VolumeControl;
begin
  Refreshing := True;
  try
    if IsBasePanelSelected then
    begin
      LampSwitchHost.Visible := False;
      ModeLabel.Visible := False;
      ModeCombo.Visible := False;
      for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
        VolumeControls[ControlIndex].Visible := False;
      PresetPanel.Visible := False;
      BasePanel.Visible := True;
      BasePanel.BringToFront;
      BasePanel.ReloadLayers;
      ControllerForm.Color := RGB(36, 36, 36);
      RootPanel.Color := RGB(36, 36, 36);
      LayoutControllerView;
      RootPanel.Invalidate;
      Exit;
    end;

    if IsPresetPanelSelected then
    begin
      LampSwitchHost.Visible := False;
      ModeLabel.Visible := False;
      ModeCombo.Visible := False;
      for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
        VolumeControls[ControlIndex].Visible := False;
      BasePanel.Visible := False;
      PresetPanel.Visible := True;
      PresetPanel.BringToFront;
      PresetPanel.RefreshLayout;
      ControllerForm.Color := RGB(36, 36, 36);
      RootPanel.Color := RGB(36, 36, 36);
      LayoutControllerView;
      RootPanel.Invalidate;
      Exit;
    end;

    if not GetCurrentEffectDefinition(Definition) then
      Exit;

    BasePanel.Visible := False;
    PresetPanel.Visible := False;
    LampSwitchHost.Visible := True;
    UseLamp.Caption := Definition.LampCaption;
    UseLamp.Enabled := Definition.UseItemName <> '';
    ModeLabel.Caption := Definition.SelectControl.DisplayName;
    ModeLabel.Visible := Definition.SelectControl.Visible;
    ModeCombo.Visible := Definition.SelectControl.Visible;
    ModeCombo.Items.BeginUpdate;
    try
      ModeCombo.Items.Clear;
      for SelectIndex := 0 to High(Definition.SelectControl.Items) do
        ModeCombo.Items.Add(Definition.SelectControl.Items[SelectIndex]);
    finally
      ModeCombo.Items.EndUpdate;
    end;

    for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
    begin
      VolumeControl := GetVolumeControl(ControlIndex);
      VolumeControl.Visible := ControlIndex < Length(Definition.Volumes);
      if VolumeControl.Visible then
      begin
        VolumeControl.Configure(
          Definition.Volumes[ControlIndex].DisplayName,
          Definition.Volumes[ControlIndex].Minimum,
          Definition.Volumes[ControlIndex].Maximum,
          Definition.Volumes[ControlIndex].Step,
          Definition.Volumes[ControlIndex].Decimals,
          Definition.Volumes[ControlIndex].UnitText);
        VolumeControl.Tag := ControlIndex;
      end;
    end;

    ApplyEmptyEffectState;
    LastUse := False;
    LastSelectIndex := ModeCombo.ItemIndex;
    ApplyEffectTheme(EffectCombo.ItemIndex);
    LayoutControllerView;
    RepaintEffectControls;
  finally
    Refreshing := False;
  end;
end;

procedure ShowWriteStatus(Success: Boolean; const ItemName: string);
begin
  if Success then
  begin
    StatusLabel.Caption := ItemName + ' written';
    StatusLabel.Font.Color := RGB(112, 232, 142);
  end
  else
  begin
    StatusLabel.Caption := ItemName + ' write failed';
    StatusLabel.Font.Color := RGB(232, 118, 104);
  end;
  StatusLabel.Invalidate;
  StatusLabel.Update;
end;

procedure RefreshEffectState;
var
  ControlIndex: Integer;
  Definition: TControllerEffectDefinition;
  ReadResult: TControllerEffectReadResult;
  State     : TControllerEffectState;
  VolumeControl: TAul2VolumeControl;
begin
  if Refreshing or not Assigned(ControllerForm) then
    Exit;
  if IsBasePanelSelected then
    Exit;
  if IsPresetPanelSelected then
    Exit;
  if not GetCurrentEffectDefinition(Definition) or
     (Definition.UseItemName = '') then
  begin
    StatusLabel.Caption := 'This effect is not connected yet';
    StatusLabel.Font.Color := RGB(170, 170, 170);
    Exit;
  end;

  Refreshing := True;
  try
    StatusLabel.Caption := 'Mouse enter detected: reading...';
    StatusLabel.Font.Color := RGB(214, 174, 78);
    StatusLabel.Update;
    ReadResult := CaptureSelectedEffectState(Definition, State);
    if ReadResult = cerrLoaded then
    begin
      UseLamp.Checked := State.Use;
      if Definition.SelectControl.Visible then
      begin
        if (State.SelectIndex >= 0) and (State.SelectIndex < ModeCombo.Items.Count) then
          ModeCombo.ItemIndex := State.SelectIndex
        else
          ModeCombo.ItemIndex := -1;
      end;
      for ControlIndex := 0 to Length(Definition.Volumes) - 1 do
      begin
        VolumeControl := GetVolumeControl(ControlIndex);
        if Assigned(VolumeControl) then
          VolumeControl.ValueText := State.ParameterTexts[ControlIndex];
      end;
      LastUse := State.Use;
      LastSelectIndex := State.SelectIndex;
      StatusLabel.Caption := Definition.DisplayName + ' loaded';
      StatusLabel.Font.Color := RGB(112, 232, 142);
    end
    else
    begin
      ApplyEmptyEffectState;
      case ReadResult of
        cerrUnavailable:
          StatusLabel.Caption := 'Mouse enter detected: SDK unavailable';
        cerrNoObject:
          StatusLabel.Caption := 'Mouse enter detected: no focus object';
        cerrNoAlias:
          StatusLabel.Caption := 'Mouse enter detected: no alias';
        cerrFilterNotFound:
          StatusLabel.Caption := 'Mouse enter detected: filter not found';
        cerrEffectIncomplete:
          StatusLabel.Caption := 'Mouse enter detected: ' +
            Definition.DisplayName + ' items incomplete';
      else
        StatusLabel.Caption := 'Mouse enter detected: read failed';
      end;
      StatusLabel.Font.Color := RGB(170, 170, 170);
    end;
    RepaintEffectControls;
  finally
    Refreshing := False;
  end;
end;

procedure TControllerEventTarget.UseLampClick(Sender: TObject);
var
  Definition: TControllerEffectDefinition;
  Success: Boolean;
begin
  if Refreshing or (UseLamp.Checked = LastUse) or
     not GetCurrentEffectDefinition(Definition) or
     (Definition.UseItemName = '') then
    Exit;

  if UseLamp.Checked then
    Success := SetSelectedEffectItem(Definition.UseItemName, '1')
  else
    Success := SetSelectedEffectItem(Definition.UseItemName, '0');

  if Success then
    LastUse := UseLamp.Checked
  else
    UseLamp.Checked := LastUse;
  ShowWriteStatus(Success, Definition.UseItemName);
end;

procedure TControllerEventTarget.ModeComboChange(Sender: TObject);
var
  Definition: TControllerEffectDefinition;
  Success: Boolean;
begin
  if Refreshing or (ModeCombo.ItemIndex < 0) or
     (ModeCombo.ItemIndex = LastSelectIndex) or
     not GetCurrentEffectDefinition(Definition) or
     not Definition.SelectControl.Visible then
    Exit;

  Success := SetSelectedEffectItem(Definition.SelectControl.ItemName,
    ModeCombo.Items[ModeCombo.ItemIndex]);
  if Success then
    LastSelectIndex := ModeCombo.ItemIndex
  else
    ModeCombo.ItemIndex := LastSelectIndex;
  ShowWriteStatus(Success, Definition.SelectControl.ItemName);
end;

procedure TControllerEventTarget.EffectVolumeChange(Sender: TObject; const ValueText: string;
  var Accept: Boolean);
var
  ControlIndex: Integer;
  Definition: TControllerEffectDefinition;
  ItemName: string;
begin
  Accept := False;
  if Refreshing or not (Sender is TAul2VolumeControl) or
     not GetCurrentEffectDefinition(Definition) then
    Exit;

  ControlIndex := TAul2VolumeControl(Sender).Tag;
  if (ControlIndex < 0) or (ControlIndex >= Length(Definition.Volumes)) then
    Exit;
  ItemName := Definition.Volumes[ControlIndex].ItemName;

  Accept := SetSelectedEffectItem(ItemName, ValueText);
  ShowWriteStatus(Accept, ItemName);
end;

procedure TControllerEventTarget.EffectComboChange(Sender: TObject);
begin
  if not Assigned(EffectCombo) or (EffectCombo.ItemIndex < 0) then
    Exit;
  StatusLabel.Caption := 'Selected: ' + EffectCombo.Items[EffectCombo.ItemIndex];
  StatusLabel.Font.Color := RGB(112, 180, 232);
  StatusLabel.Invalidate;
  ConfigureCurrentEffect;
  if not IsBasePanelSelected and not IsPresetPanelSelected then
    RefreshEffectState;
end;

function IsCursorInsideController: Boolean;
var
  CursorPosition: TPoint;
  WindowHandle  : HWND;
begin
  Result := False;
  if not Assigned(ControllerForm) or not GetCursorPos(CursorPosition) then
    Exit;

  WindowHandle := WindowFromPoint(CursorPosition);
  Result := (WindowHandle = ControllerForm.Handle) or IsChild(ControllerForm.Handle, WindowHandle);
end;

procedure TControllerEventTarget.ControllerMouseEnter(Sender: TObject);
begin
  NotifyControllerMouseEnter;
end;

procedure NotifyControllerMouseEnter;
begin
  // WM_SETCURSORや子コントロール間の多重通知では再取得しない。
  if MouseInside then
    Exit;

  MouseInside := True;
  RefreshEffectState;
end;

procedure TControllerEventTarget.MouseBoundaryTimer(Sender: TObject);
begin
  // WM_SETCURSORの多重発火を抑えるため、外へ出たことだけを軽量に監視する。
  if MouseInside and not IsCursorInsideController then
    MouseInside := False;
end;

procedure CreateLabel(var LabelControl: TLabel; const Caption: string);
begin
  LabelControl := TLabel.Create(ControllerForm);
  LabelControl.Parent := RootPanel;
  LabelControl.Caption := Caption;
  LabelControl.Color := RGB(28, 30, 33);
  LabelControl.Font.Color := RGB(232, 232, 232);
  LabelControl.ParentColor := False;
  LabelControl.ParentFont := False;
  LabelControl.Transparent := True;
  RegisterMouseEnter(LabelControl);
end;

procedure CreateControllerView(ParentWindow: HWND);
var
  ControlIndex: Integer;
  Definition: TControllerEffectDefinition;
  EffectIndex: Integer;
begin
  if Assigned(ControllerForm) or (ParentWindow = 0) then
    Exit;

  ClientWindow := ParentWindow;
  if Application = nil then
    Application := TApplication.Create(nil);

  Application.Title := CONTROLLER_WINDOW_NAME;
  ControllerForm := TFormAudioController.Create(nil);
  ControllerForm.ParentWindow := ClientWindow;
  ControllerForm.ParentFont := False;
  ControllerForm.Font.Name := 'Yu Gothic UI';
  ControllerForm.Font.Size := 9;
  ControllerForm.Font.Color := RGB(226, 226, 226);
  ControllerForm.DoubleBuffered := True;

  EventTarget := TControllerEventTarget.Create(ControllerForm);
  RegisterMouseEnter(ControllerForm);

  RootPanel := TPanel.Create(ControllerForm);
  RootPanel.Parent := ControllerForm;
  RootPanel.Align := alClient;
  RootPanel.BevelOuter := bvNone;
  RootPanel.Caption := '';
  RootPanel.Color := RGB(28, 30, 33);
  RootPanel.ParentBackground := False;
  RootPanel.DoubleBuffered := True;
  RegisterMouseEnter(RootPanel);

  BasePanel := TAul2AudioBasePanel.Create(ControllerForm);
  BasePanel.LayoutMode := ablVertical;
  BasePanel.Parent := RootPanel;
  BasePanel.Visible := False;
  BasePanel.Initialize;

  PresetPanel := TAul2AudioPresetPanel.Create(ControllerForm);
  PresetPanel.LayoutMode := aplVertical;
  PresetPanel.Parent := RootPanel;
  PresetPanel.Visible := False;
  PresetPanel.Initialize;

  CreateLabel(StatusLabel, 'Move the mouse into this window to read');
  StatusLabel.Font.Color := RGB(170, 170, 170);
  StatusLabel.Visible := False;

  EffectCombo := TEffectComboBox.Create(ControllerForm);
  EffectCombo.Style := csDropDownList;
  EffectCombo.Color := RGB(42, 45, 49);
  EffectCombo.Font.Assign(ControllerForm.Font);
  EffectCombo.Font.Color := RGB(250, 250, 250);
  EffectCombo.ParentFont := False;
  // Items.AddはHandleを要求するため、項目登録より先にParentへ接続する。
  EffectCombo.Parent := RootPanel;
  for EffectIndex := 0 to CONTROLLER_EFFECT_COUNT - 1 do
    if GetControllerEffectDefinition(EffectIndex, Definition) then
      EffectCombo.Items.Add(Definition.DisplayName);
  EffectCombo.Items.Add(CONTROLLER_PRESET_ITEM_NAME);
  EffectCombo.Items.Add(CONTROLLER_BASE_ITEM_NAME);
  EffectCombo.ItemIndex := 0;
  EffectCombo.OnChange := EventTarget.EffectComboChange;
  ApplyDarkComboStyle(EffectCombo);
  RegisterMouseEnter(EffectCombo);

  // 現在のUseと、将来の電源ボタン・表示灯を載せる領域を確保する。
  LampSwitchHost := TPanel.Create(ControllerForm);
  LampSwitchHost.BevelOuter := bvNone;
  LampSwitchHost.Caption := '';
  LampSwitchHost.Color := RGB(28, 30, 33);
  LampSwitchHost.ParentBackground := False;
  LampSwitchHost.Parent := RootPanel;
  LampSwitchHost.Visible := True;
  RegisterMouseEnter(LampSwitchHost);

  UseLamp := TAul2LampSwitch.Create(ControllerForm);
  UseLamp.Caption := '遅延音を加える';
  UseLamp.Font.Assign(ControllerForm.Font);
  UseLamp.OnClick := EventTarget.UseLampClick;
  UseLamp.Parent := LampSwitchHost;
  RegisterMouseEnter(UseLamp);

  CreateLabel(ModeLabel, 'Stereo Mode');
  ModeCombo := TComboBox.Create(ControllerForm);
  ModeCombo.Style := csDropDownList;
  ModeCombo.Color := RGB(42, 45, 49);
  ModeCombo.Font.Assign(ControllerForm.Font);
  ModeCombo.Font.Color := RGB(250, 250, 250);
  ModeCombo.ParentFont := False;
  ModeCombo.Parent := RootPanel;
  ModeCombo.Items.Add('Normal');
  ModeCombo.Items.Add('Ping-Pong');
  ModeCombo.ItemIndex := 0;
  ModeCombo.Enabled := True;
  ModeCombo.TabStop := False;
  ModeCombo.OnChange := EventTarget.ModeComboChange;
  ApplyDarkComboStyle(ModeCombo);
  RegisterMouseEnter(ModeCombo);

  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
  begin
    VolumeControls[ControlIndex] := TAul2VolumeControl.Create(ControllerForm);
    VolumeControls[ControlIndex].Configure('', 0, 1, 0.01, 2);
    VolumeControls[ControlIndex].Tag := ControlIndex;
    VolumeControls[ControlIndex].OnValueChange := EventTarget.EffectVolumeChange;
    VolumeControls[ControlIndex].Font.Assign(ControllerForm.Font);
    VolumeControls[ControlIndex].Parent := RootPanel;
    RegisterMouseEnter(VolumeControls[ControlIndex]);
  end;

  MouseInside := False;
  Refreshing := False;

  MouseTimer := TTimer.Create(ControllerForm);
  MouseTimer.Interval := 100;
  MouseTimer.OnTimer := EventTarget.MouseBoundaryTimer;
  MouseTimer.Enabled := True;

  ConfigureCurrentEffect;
  ControllerForm.Show;
  RootPanel.Visible := True;
  RootPanel.BringToFront;
end;

procedure ResizeControllerView(Width, Height: Integer);
begin
  if (Width <= 0) or (Height <= 0) or not Assigned(ControllerForm) then
    Exit;

  // Syncroh2の拡張画面と同じく、RootPanelを先に合わせてからフォームを親全体へ広げる。
  if Assigned(RootPanel) then
  begin
    RootPanel.SetBounds(0, 0, Width, Height);
    RootPanel.Visible := True;
    RootPanel.Realign;
    RootPanel.BringToFront;
  end;

  ControllerForm.SetBounds(0, 0, Width, Height);
  SetWindowPos(ControllerForm.Handle, 0, 0, 0, Width, Height,
    SWP_NOZORDER or SWP_NOACTIVATE or SWP_SHOWWINDOW);
  ControllerForm.Visible := True;
  LayoutControllerView;
  ControllerForm.Invalidate;
end;

procedure SyncControllerViewBounds;
var
  Rect: TRect;
begin
  if (ClientWindow = 0) or not Assigned(ControllerForm) then
    Exit;

  GetClientRect(ClientWindow, Rect);
  ResizeControllerView(Rect.Right, Rect.Bottom);
end;

procedure ShowControllerView;
begin
  if ClientWindow <> 0 then
  begin
    ShowWindow(ClientWindow, SW_SHOW);
    SyncControllerViewBounds;
    SetFocus(ClientWindow);
  end;

  if Assigned(ControllerForm) then
  begin
    ControllerForm.Show;
    ControllerForm.BringToFront;
    ControllerForm.SetFocus;
  end;
end;

procedure DestroyControllerView;
var
  ControlIndex: Integer;
begin
  if Assigned(MouseTimer) then
  begin
    MouseTimer.Enabled := False;
    MouseTimer.OnTimer := nil;
  end;

  if Assigned(ControllerForm) then
  begin
    ControllerForm.Hide;
    ControllerForm.ParentWindow := 0;
  end;

  FreeAndNil(MouseTimer);
  FreeAndNil(ControllerForm);
  ClientWindow := 0;
  RootPanel := nil;
  BasePanel := nil;
  PresetPanel := nil;
  StatusLabel := nil;
  EffectCombo := nil;
  LampSwitchHost := nil;
  UseLamp := nil;
  ModeLabel := nil;
  ModeCombo := nil;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
    VolumeControls[ControlIndex] := nil;
  MouseTimer := nil;
  EventTarget := nil;
  MouseInside := False;
  Refreshing := False;
end;

end.
