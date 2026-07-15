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
  System.Classes,
  System.Math,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Aul2AudioControllerSync,
  Aul2AudioControllerVolumeControl;

type
  TControlAccess = class(TControl);

  TFormAudioController = class(TForm)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TControllerEventTarget = class(TComponent)
  public
    procedure ModeComboChange(Sender: TObject);
    procedure MouseBoundaryTimer(Sender: TObject);
    procedure ControllerMouseEnter(Sender: TObject);
    procedure UseCheckClick(Sender: TObject);
  end;

var
  ClientWindow   : HWND;
  ControllerForm : TFormAudioController;
  RootPanel      : TPanel;
  TitleLabel     : TLabel;
  StatusLabel    : TLabel;
  UseCheck       : TCheckBox;
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

constructor TFormAudioController.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := CONTROLLER_WINDOW_NAME;
  BorderStyle := bsNone;
  Position := poDesigned;
  Color := RGB(28, 30, 33);
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

  TitleLabel.SetBounds(LeftMargin, Scale(14), ContentWidth, Scale(22));
  StatusLabel.SetBounds(LeftMargin, Scale(39), ContentWidth, Scale(20));
  UseCheck.SetBounds(LeftMargin, Scale(68), ContentWidth, Scale(24));

  TopPosition := Scale(102);
  ModeLabel.SetBounds(LeftMargin, TopPosition + Scale(4), LabelWidth, Scale(23));
  ModeCombo.SetBounds(EditLeft, TopPosition, EditWidth, Scale(25));
  Inc(TopPosition, RowHeight + Scale(2));

  Controls[0] := TimeControl;
  Controls[1] := DryControl;
  Controls[2] := WetControl;
  Controls[3] := FeedbackControl;
  ControlGap := Scale(6);
  ControlHeight := Scale(126);
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
  UseCheck.Checked := False;
  ModeCombo.ItemIndex := 0;
  TimeControl.ValueText := '0';
  DryControl.ValueText := '0';
  WetControl.ValueText := '0';
  FeedbackControl.ValueText := '0';
end;

procedure RepaintDelayControls;
begin
  TitleLabel.Invalidate;
  StatusLabel.Invalidate;
  UseCheck.Invalidate;
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
      UseCheck.Checked := State.Use;
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

procedure TControllerEventTarget.UseCheckClick(Sender: TObject);
var
  Success: Boolean;
begin
  if Refreshing or (UseCheck.Checked = LastUse) then
    Exit;

  if UseCheck.Checked then
    Success := SetSelectedDelayItem('Dly: Use', '1')
  else
    Success := SetSelectedDelayItem('Dly: Use', '0');

  if Success then
    LastUse := UseCheck.Checked
  else
    UseCheck.Checked := LastUse;
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
  LabelControl.Transparent := False;
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

  CreateLabel(TitleLabel, 'Delay controller preview');
  TitleLabel.Font.Style := [fsBold];
  TitleLabel.Font.Color := RGB(232, 232, 232);

  CreateLabel(StatusLabel, 'Move the mouse into this window to read');
  StatusLabel.Font.Color := RGB(170, 170, 170);

  UseCheck := TCheckBox.Create(ControllerForm);
  UseCheck.Parent := RootPanel;
  UseCheck.Caption := 'Use';
  UseCheck.Enabled := True;
  UseCheck.TabStop := False;
  UseCheck.Font.Color := RGB(245, 245, 245);
  UseCheck.ParentFont := False;
  UseCheck.OnClick := EventTarget.UseCheckClick;
  RegisterMouseEnter(UseCheck);

  CreateLabel(ModeLabel, 'Stereo Mode');
  ModeCombo := TComboBox.Create(ControllerForm);
  ModeCombo.Parent := RootPanel;
  ModeCombo.Style := csDropDownList;
  ModeCombo.Items.Add('Normal');
  ModeCombo.Items.Add('Ping-Pong');
  ModeCombo.ItemIndex := 0;
  ModeCombo.Enabled := True;
  ModeCombo.TabStop := False;
  ModeCombo.Color := RGB(42, 45, 49);
  ModeCombo.Font.Color := RGB(250, 250, 250);
  ModeCombo.ParentFont := False;
  ModeCombo.OnChange := EventTarget.ModeComboChange;
  RegisterMouseEnter(ModeCombo);

  TimeControl := TAul2VolumeControl.Create(ControllerForm);
  TimeControl.Parent := RootPanel;
  TimeControl.Configure('Time', 1, 1000, 'ms');
  TimeControl.Font.Assign(ControllerForm.Font);
  RegisterMouseEnter(TimeControl);

  DryControl := TAul2VolumeControl.Create(ControllerForm);
  DryControl.Parent := RootPanel;
  DryControl.Configure('Dry', 0, 2);
  DryControl.Font.Assign(ControllerForm.Font);
  RegisterMouseEnter(DryControl);

  WetControl := TAul2VolumeControl.Create(ControllerForm);
  WetControl.Parent := RootPanel;
  WetControl.Configure('Wet', 0, 2);
  WetControl.Font.Assign(ControllerForm.Font);
  RegisterMouseEnter(WetControl);

  FeedbackControl := TAul2VolumeControl.Create(ControllerForm);
  FeedbackControl.Parent := RootPanel;
  FeedbackControl.Configure('Feedback', 0, 0.95);
  FeedbackControl.Font.Assign(ControllerForm.Font);
  RegisterMouseEnter(FeedbackControl);

  ApplyEmptyDelayState;
  MouseInside := False;
  Refreshing := False;

  MouseTimer := TTimer.Create(ControllerForm);
  MouseTimer.Interval := 100;
  MouseTimer.OnTimer := EventTarget.MouseBoundaryTimer;
  MouseTimer.Enabled := True;

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
  TitleLabel := nil;
  StatusLabel := nil;
  UseCheck := nil;
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
