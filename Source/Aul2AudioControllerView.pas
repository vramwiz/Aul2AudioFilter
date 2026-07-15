unit Aul2AudioControllerView;

// ControllerのVCLフォーム、Delay取得、表示専用パラメーター配置を担当する。

interface

uses
  Winapi.Windows;

const
  CONTROLLER_WINDOW_NAME = 'Aul2AudioController'; // フォームとクライアントで共有する表示名。

// Controllerフォームを生成し、ParentWindowの子としてDelay確認GUIを構築する。
procedure CreateControllerView(ParentWindow: HWND);
// タイマーとControllerフォームを停止・解放する。
procedure DestroyControllerView;
// 作成済みControllerフォームを表示して前面へ移す。
procedure ShowControllerView;
// 親クライアントの現在サイズへControllerフォームを追従させる。
procedure SyncControllerViewBounds;
// AviUtl2クライアントから通知された寸法へRootPanelとフォームを追従させる。
procedure ResizeControllerView(Width, Height: Integer);
// クライアントWndProcのマウス進入通知からDelay再取得を1回だけ発火する。
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
  Aul2AudioControllerLampSwitch,
  Aul2AudioControllerSync,
  Aul2AudioControllerVolumeControl;

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
    procedure DelayVolumeChange(Sender: TObject; const ValueText: string; var Accept: Boolean);
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
  StatusLabel    : TLabel;
  EffectCombo    : TEffectComboBox;
  LampSwitchHost : TPanel;
  UseLamp        : TAul2LampSwitch;
  ModeLabel      : TLabel;
  ModeCombo      : TComboBox;
  TimeControl    : TAul2VolumeControl;
  DryControl     : TAul2VolumeControl;
  WetControl     : TAul2VolumeControl;
  FeedbackControl: TAul2VolumeControl;
  MouseTimer     : TTimer;
  EventTarget    : TControllerEventTarget;
  MouseInside    : Boolean;
  Refreshing     : Boolean;
  LastUse        : Boolean;
  LastStereoMode : Integer;

const
  DELAY_CONTROL_TIME     = 1;
  DELAY_CONTROL_DRY      = 2;
  DELAY_CONTROL_WET      = 3;
  DELAY_CONTROL_FEEDBACK = 4;

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

function GetEffectThemeColor(EffectIndex: Integer): TColor;
begin
  case EffectIndex of
    0:  Result := RGB(20, 31, 44); // Delay
    1:  Result := RGB(20, 38, 29); // EQ
    2:  Result := RGB(43, 38, 20); // Compressor
    3:  Result := RGB(45, 27, 18); // Voice Drive
    4:  Result := RGB(45, 22, 22); // Distortion
    5:  Result := RGB(32, 34, 37); // Noise
    6:  Result := RGB(31, 24, 45); // Bit Crusher
    7:  Result := RGB(21, 38, 38); // Tremble
    8:  Result := RGB(44, 21, 39); // Wobble
    9:  Result := RGB(42, 22, 45); // Pitch
    10: Result := RGB(20, 37, 42); // Ring Mod
    11: Result := RGB(40, 31, 22); // Muffle
    12: Result := RGB(27, 31, 40); // Whisper
    13: Result := RGB(22, 40, 27); // Auto Gain
    14: Result := RGB(27, 29, 32); // Noise Gate
    15: Result := RGB(34, 27, 43); // Ghost
    16: Result := RGB(19, 38, 44); // Chorus
    17: Result := RGB(35, 24, 45); // Reverb
    18: Result := RGB(25, 33, 40); // Output
    19: Result := RGB(45, 34, 17); // Limiter
  else
    Result := RGB(28, 30, 33);
  end;
end;

function LightenThemeColor(Color: TColor; Amount: Integer): TColor;
begin
  Color := ColorToRGB(Color);
  Result := RGB(
    Min(255, GetRValue(Color) + Amount),
    Min(255, GetGValue(Color) + Amount),
    Min(255, GetBValue(Color) + Amount));
end;

procedure ApplyEffectTheme(EffectIndex: Integer);
var
  PanelColor: TColor;
  ThemeColor: TColor;
begin
  if not Assigned(ControllerForm) or not Assigned(RootPanel) or not Assigned(UseLamp) then
    Exit;

  ThemeColor := GetEffectThemeColor(EffectIndex);
  PanelColor := LightenThemeColor(ThemeColor, 10);
  ControllerForm.Color := ThemeColor;
  RootPanel.Color := ThemeColor;
  LampSwitchHost.Color := ThemeColor;
  UseLamp.Color := ThemeColor;
  UseLamp.PanelColor := PanelColor;
  ModeLabel.Color := ThemeColor;
  TimeControl.Color := ThemeColor;
  TimeControl.PanelColor := PanelColor;
  DryControl.Color := ThemeColor;
  DryControl.PanelColor := PanelColor;
  WetControl.Color := ThemeColor;
  WetControl.PanelColor := PanelColor;
  FeedbackControl.Color := ThemeColor;
  FeedbackControl.PanelColor := PanelColor;
  RootPanel.Invalidate;
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
  Controls    : array[0..3] of TAul2VolumeControl;
  EditLeft    : Integer;
  EditWidth   : Integer;
  LabelWidth  : Integer;
  LeftMargin  : Integer;
  RowHeight   : Integer;
  TopPosition : Integer;
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
  LampSwitchHost.SetBounds(LeftMargin, Scale(37), ContentWidth, Scale(28));
  UseLamp.SetBounds(0, 0, ContentWidth, Scale(28));

  TopPosition := Scale(69);
  ModeLabel.SetBounds(LeftMargin, TopPosition + Scale(4), LabelWidth, Scale(23));
  ModeCombo.SetBounds(EditLeft, TopPosition, EditWidth, Scale(25));
  Inc(TopPosition, RowHeight);

  Controls[0] := TimeControl;
  Controls[1] := DryControl;
  Controls[2] := WetControl;
  Controls[3] := FeedbackControl;
  ControlGap := Scale(6);
  // ノブ内部は固定ピクセル描画のため、DPI拡大で値欄との間隔を広げない。
  ControlHeight := 126;
  ColumnCount := Max(1, (ContentWidth + ControlGap) div (Scale(64) + ControlGap));
  ColumnCount := Min(ColumnCount, Length(Controls));
  ControlWidth := (ContentWidth - ControlGap * (ColumnCount - 1)) div ColumnCount;
  ControlWidth := Min(ControlWidth, Scale(84));
  for ControlIndex := 0 to High(Controls) do
  begin
    ColumnIndex := ControlIndex mod ColumnCount;
    ControlLeft := LeftMargin + ColumnIndex * (ControlWidth + ControlGap);
    ControlTop := TopPosition + (ControlIndex div ColumnCount) * (ControlHeight + ControlGap);
    Controls[ControlIndex].SetBounds(ControlLeft, ControlTop, ControlWidth, ControlHeight);
  end;
end;

procedure ApplyEmptyDelayState;
begin
  UseLamp.Checked := False;
  ModeCombo.ItemIndex := 0;
  TimeControl.ValueText := '0';
  DryControl.ValueText := '0';
  WetControl.ValueText := '0';
  FeedbackControl.ValueText := '0';
end;

procedure RepaintDelayControls;
begin
  EffectCombo.Invalidate;
  StatusLabel.Invalidate;
  UseLamp.Invalidate;
  ModeLabel.Invalidate;
  ModeCombo.Invalidate;
  TimeControl.Invalidate;
  DryControl.Invalidate;
  WetControl.Invalidate;
  FeedbackControl.Invalidate;
  RootPanel.Update;
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

procedure RefreshDelayState;
var
  ReadResult: TControllerDelayReadResult;
  State     : TControllerDelayState;
begin
  if Refreshing or not Assigned(ControllerForm) then
    Exit;

  Refreshing := True;
  try
    StatusLabel.Caption := 'Mouse enter detected: reading...';
    StatusLabel.Font.Color := RGB(214, 174, 78);
    StatusLabel.Update;
    ReadResult := CaptureSelectedDelayState(State);
    if ReadResult = cdrrLoaded then
    begin
      UseLamp.Checked := State.Use;
      if (State.StereoMode >= 0) and (State.StereoMode < ModeCombo.Items.Count) then
        ModeCombo.ItemIndex := State.StereoMode
      else
        ModeCombo.ItemIndex := -1;
      TimeControl.ValueText := State.TimeText;
      DryControl.ValueText := State.DryText;
      WetControl.ValueText := State.WetText;
      FeedbackControl.ValueText := State.FeedbackText;
      LastUse := State.Use;
      LastStereoMode := State.StereoMode;
      StatusLabel.Caption := 'Delay loaded';
      StatusLabel.Font.Color := RGB(112, 232, 142);
    end
    else
    begin
      ApplyEmptyDelayState;
      case ReadResult of
        cdrrUnavailable:
          StatusLabel.Caption := 'Mouse enter detected: SDK unavailable';
        cdrrNoObject:
          StatusLabel.Caption := 'Mouse enter detected: no focus object';
        cdrrNoAlias:
          StatusLabel.Caption := 'Mouse enter detected: no alias';
        cdrrFilterNotFound:
          StatusLabel.Caption := 'Mouse enter detected: filter not found';
        cdrrDelayIncomplete:
          StatusLabel.Caption := 'Mouse enter detected: Delay items incomplete';
      else
        StatusLabel.Caption := 'Mouse enter detected: read failed';
      end;
      StatusLabel.Font.Color := RGB(170, 170, 170);
    end;
    RepaintDelayControls;
  finally
    Refreshing := False;
  end;
end;

procedure TControllerEventTarget.UseLampClick(Sender: TObject);
var
  Success: Boolean;
begin
  if Refreshing or (UseLamp.Checked = LastUse) then
    Exit;

  if UseLamp.Checked then
    Success := SetSelectedDelayItem('Dly: Use', '1')
  else
    Success := SetSelectedDelayItem('Dly: Use', '0');

  if Success then
    LastUse := UseLamp.Checked
  else
    UseLamp.Checked := LastUse;
  ShowWriteStatus(Success, 'Dly: Use');
end;

procedure TControllerEventTarget.ModeComboChange(Sender: TObject);
var
  Success: Boolean;
begin
  if Refreshing or (ModeCombo.ItemIndex < 0) or (ModeCombo.ItemIndex = LastStereoMode) then
    Exit;

  Success := SetSelectedDelayItem('Dly: Stereo Mode', ModeCombo.Items[ModeCombo.ItemIndex]);
  if Success then
    LastStereoMode := ModeCombo.ItemIndex
  else
    ModeCombo.ItemIndex := LastStereoMode;
  ShowWriteStatus(Success, 'Dly: Stereo Mode');
end;

procedure TControllerEventTarget.DelayVolumeChange(Sender: TObject; const ValueText: string;
  var Accept: Boolean);
var
  ItemName: string;
begin
  Accept := False;
  if Refreshing or not (Sender is TAul2VolumeControl) then
    Exit;

  case TAul2VolumeControl(Sender).Tag of
    DELAY_CONTROL_TIME:
      ItemName := 'Dly: Time(ms)';
    DELAY_CONTROL_DRY:
      ItemName := 'Dly: Dry';
    DELAY_CONTROL_WET:
      ItemName := 'Dly: Wet';
    DELAY_CONTROL_FEEDBACK:
      ItemName := 'Dly: Feedback';
  else
    Exit;
  end;

  Accept := SetSelectedDelayItem(ItemName, ValueText);
  ShowWriteStatus(Accept, ItemName);
end;

procedure TControllerEventTarget.EffectComboChange(Sender: TObject);
begin
  if not Assigned(EffectCombo) or (EffectCombo.ItemIndex < 0) then
    Exit;
  StatusLabel.Caption := 'Selected: ' + EffectCombo.Items[EffectCombo.ItemIndex] + ' (preview only)';
  StatusLabel.Font.Color := RGB(112, 180, 232);
  StatusLabel.Invalidate;
  ApplyEffectTheme(EffectCombo.ItemIndex);
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
  RefreshDelayState;
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
  EffectCombo.Items.Add('Delay');
  EffectCombo.Items.Add('EQ');
  EffectCombo.Items.Add('Compressor');
  EffectCombo.Items.Add('Voice Drive');
  EffectCombo.Items.Add('Distortion');
  EffectCombo.Items.Add('Noise');
  EffectCombo.Items.Add('Bit Crusher');
  EffectCombo.Items.Add('Tremble');
  EffectCombo.Items.Add('Wobble');
  EffectCombo.Items.Add('Pitch');
  EffectCombo.Items.Add('Ring Mod');
  EffectCombo.Items.Add('Muffle');
  EffectCombo.Items.Add('Whisper');
  EffectCombo.Items.Add('Auto Gain');
  EffectCombo.Items.Add('Noise Gate');
  EffectCombo.Items.Add('Ghost');
  EffectCombo.Items.Add('Chorus');
  EffectCombo.Items.Add('Reverb');
  EffectCombo.Items.Add('Output');
  EffectCombo.Items.Add('Limiter');
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

  TimeControl := TAul2VolumeControl.Create(ControllerForm);
  TimeControl.Configure('Time', 1, 1000, 1, 0, 'ms');
  TimeControl.Tag := DELAY_CONTROL_TIME;
  TimeControl.OnValueChange := EventTarget.DelayVolumeChange;
  TimeControl.Font.Assign(ControllerForm.Font);
  TimeControl.Parent := RootPanel;
  RegisterMouseEnter(TimeControl);

  DryControl := TAul2VolumeControl.Create(ControllerForm);
  DryControl.Configure('Dry', 0, 2, 0.01, 2);
  DryControl.Tag := DELAY_CONTROL_DRY;
  DryControl.OnValueChange := EventTarget.DelayVolumeChange;
  DryControl.Font.Assign(ControllerForm.Font);
  DryControl.Parent := RootPanel;
  RegisterMouseEnter(DryControl);

  WetControl := TAul2VolumeControl.Create(ControllerForm);
  WetControl.Configure('Wet', 0, 2, 0.01, 2);
  WetControl.Tag := DELAY_CONTROL_WET;
  WetControl.OnValueChange := EventTarget.DelayVolumeChange;
  WetControl.Font.Assign(ControllerForm.Font);
  WetControl.Parent := RootPanel;
  RegisterMouseEnter(WetControl);

  FeedbackControl := TAul2VolumeControl.Create(ControllerForm);
  FeedbackControl.Configure('Feedback', 0, 0.95, 0.01, 2);
  FeedbackControl.Tag := DELAY_CONTROL_FEEDBACK;
  FeedbackControl.OnValueChange := EventTarget.DelayVolumeChange;
  FeedbackControl.Font.Assign(ControllerForm.Font);
  FeedbackControl.Parent := RootPanel;
  RegisterMouseEnter(FeedbackControl);

  ApplyEmptyDelayState;
  MouseInside := False;
  Refreshing := False;

  MouseTimer := TTimer.Create(ControllerForm);
  MouseTimer.Interval := 100;
  MouseTimer.OnTimer := EventTarget.MouseBoundaryTimer;
  MouseTimer.Enabled := True;

  ApplyEffectTheme(EffectCombo.ItemIndex);
  LayoutControllerView;
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
  StatusLabel := nil;
  EffectCombo := nil;
  LampSwitchHost := nil;
  UseLamp := nil;
  ModeLabel := nil;
  ModeCombo := nil;
  TimeControl := nil;
  DryControl := nil;
  WetControl := nil;
  FeedbackControl := nil;
  MouseTimer := nil;
  EventTarget := nil;
  MouseInside := False;
  Refreshing := False;
end;

end.
