unit Aul2AudioMonitorView;

// Aul2AudioMonitor の VCL フォーム、タイマー、共有メモリ読み取りを担当する。

interface

uses
  Winapi.Windows;

const
  MONITOR_WINDOW_NAME = 'Aul2AudioMonitor';

procedure CreateMonitorView(ParentWindow: HWND);
procedure DestroyMonitorView;
procedure ShowMonitorView;
procedure SyncMonitorViewBounds;

implementation

uses
  System.Classes,
  System.SysUtils,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ToolWin,
  Aul2AudioMonitorPaint,
  Aul2AudioMonitorShared,
  Aul2AudioMonitorSpectrumShared,
  ToolBarPanelManager;

type
  TAudioMonitorPage = (
    ampWave,
    ampSpectrum
  );

  TFormAudioMonitor = class(TForm)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TMonitorTimerTarget = class(TComponent)
  public
    procedure ReadTimerTick(Sender: TObject);
    procedure WavePaint(Sender: TObject);
    procedure SpectrumPaint(Sender: TObject);
  end;

var
  ClientWindow: HWND;
  MonitorForm : TFormAudioMonitor;
  RootPanel   : TPanel;
  ToolBar     : TToolBar;
  ButtonWave  : TToolButton;
  ButtonSpectrum: TToolButton;
  PanelWave   : TPanel;
  PanelSpectrum: TPanel;
  InfoLabel   : TLabel;
  WavePaintBox: TPaintBox;
  SpectrumPaintBox: TPaintBox;
  ReadTimer   : TTimer;
  TimerTarget : TMonitorTimerTarget;
  ToolBarManager: TToolBarPanelManager;
  SharedMemory: TAul2AudioMonitorSharedMemory;
  SpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;

function GetMonitorSharedMemory: TAul2AudioMonitorSharedMemory;
begin
  if SharedMemory = nil then
    SharedMemory := TAul2AudioMonitorSharedMemory.Create;

  Result := SharedMemory;
end;

function GetSpectrumSharedMemory: TAul2AudioMonitorSpectrumSharedMemory;
begin
  if SpectrumMemory = nil then
    SpectrumMemory := TAul2AudioMonitorSpectrumSharedMemory.Create;

  Result := SpectrumMemory;
end;

constructor TFormAudioMonitor.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := MONITOR_WINDOW_NAME;
  BorderStyle := bsNone;
  Position := poDesigned;
  Color := RGB(36, 36, 36);
end;

procedure ResizeMonitorView(Width, Height: Integer);
begin
  if (Width <= 0) or (Height <= 0) then
    Exit;

  if Assigned(MonitorForm) then
  begin
    MonitorForm.SetBounds(0, 0, Width, Height);
    SetWindowPos(MonitorForm.Handle, 0, 0, 0, Width, Height,
      SWP_NOZORDER or SWP_NOACTIVATE);
  end;

  if Assigned(RootPanel) then
  begin
    RootPanel.SetBounds(0, 0, Width, Height);
    RootPanel.Realign;
  end;

  if Assigned(InfoLabel) then
    InfoLabel.SetBounds(0, 0, Width, Height);

  if Assigned(WavePaintBox) then
    WavePaintBox.SetBounds(0, 0, PanelWave.Width, PanelWave.Height);

  if Assigned(SpectrumPaintBox) then
    SpectrumPaintBox.SetBounds(0, 0, PanelSpectrum.Width, PanelSpectrum.Height);
end;

procedure SyncMonitorViewBounds;
var
  Rect: TRect;
begin
  if ClientWindow = 0 then
    Exit;

  if GetClientRect(ClientWindow, Rect) then
    ResizeMonitorView(Rect.Right - Rect.Left, Rect.Bottom - Rect.Top);
end;

procedure InvalidateMonitorView;
begin
  if Assigned(WavePaintBox) then
    WavePaintBox.Invalidate;

  if Assigned(SpectrumPaintBox) then
    SpectrumPaintBox.Invalidate;
end;

procedure TMonitorTimerTarget.ReadTimerTick(Sender: TObject);
begin
  SyncMonitorViewBounds;
  InvalidateMonitorView;
end;

procedure TMonitorTimerTarget.WavePaint(Sender: TObject);
var
  PaintBox: TPaintBox;
  State: PAul2AudioMonitorState;
begin
  if not (Sender is TPaintBox) then
    Exit;

  PaintBox := TPaintBox(Sender);

  try
    State := GetMonitorSharedMemory.State;
  except
    State := nil;
  end;

  DrawAudioMonitorCanvas(PaintBox.Canvas, PaintBox.ClientRect, State);
end;

procedure TMonitorTimerTarget.SpectrumPaint(Sender: TObject);
var
  PaintBox: TPaintBox;
  State: PAul2AudioMonitorSpectrumState;
begin
  if not (Sender is TPaintBox) then
    Exit;

  PaintBox := TPaintBox(Sender);

  try
    State := GetSpectrumSharedMemory.State;
  except
    State := nil;
  end;

  DrawAudioSpectrumCanvas(PaintBox.Canvas, PaintBox.ClientRect, State);
end;

procedure CreateMonitorView(ParentWindow: HWND);
var
  Rect: TRect;
begin
  if Assigned(MonitorForm) or (ParentWindow = 0) then
    Exit;

  ClientWindow := ParentWindow;

  if Application = nil then
    Application := TApplication.Create(nil);

  Application.Handle := 0;
  Application.Title := MONITOR_WINDOW_NAME;

  MonitorForm := TFormAudioMonitor.Create(nil);
  MonitorForm.ParentWindow := ClientWindow;
  MonitorForm.Font.Color := RGB(230, 230, 230);
  MonitorForm.DoubleBuffered := True;

  RootPanel := TPanel.Create(MonitorForm);
  RootPanel.Parent := MonitorForm;
  RootPanel.Align := alClient;
  RootPanel.BevelOuter := bvNone;
  RootPanel.Caption := '';
  RootPanel.Color := RGB(36, 36, 36);
  RootPanel.Font.Color := RGB(230, 230, 230);
  RootPanel.ParentBackground := False;
  RootPanel.ParentFont := False;
  RootPanel.DoubleBuffered := True;

  TimerTarget := TMonitorTimerTarget.Create(MonitorForm);

  ToolBar := TToolBar.Create(MonitorForm);
  ToolBar.Parent := RootPanel;
  ToolBar.Align := alTop;
  ToolBar.Height := 24;
  ToolBar.EdgeBorders := [];
  ToolBar.ShowCaptions := True;
  ToolBar.Flat := True;

  ButtonWave := TToolButton.Create(MonitorForm);
  ButtonWave.Parent := ToolBar;
  ButtonWave.Caption := 'Wave';

  ButtonSpectrum := TToolButton.Create(MonitorForm);
  ButtonSpectrum.Parent := ToolBar;
  ButtonSpectrum.Caption := 'Spectrum';

  PanelWave := TPanel.Create(MonitorForm);
  PanelWave.Parent := RootPanel;
  PanelWave.Align := alClient;
  PanelWave.BevelOuter := bvNone;
  PanelWave.Caption := '';
  PanelWave.Color := RGB(36, 36, 36);
  PanelWave.ParentBackground := False;

  PanelSpectrum := TPanel.Create(MonitorForm);
  PanelSpectrum.Parent := RootPanel;
  PanelSpectrum.Align := alClient;
  PanelSpectrum.BevelOuter := bvNone;
  PanelSpectrum.Caption := '';
  PanelSpectrum.Color := RGB(36, 36, 36);
  PanelSpectrum.ParentBackground := False;

  InfoLabel := TLabel.Create(MonitorForm);
  InfoLabel.Parent := PanelWave;
  InfoLabel.Align := alClient;
  InfoLabel.AutoSize := False;
  InfoLabel.Color := RGB(36, 36, 36);
  InfoLabel.ParentColor := False;
  InfoLabel.ParentFont := False;
  InfoLabel.Transparent := False;
  InfoLabel.Font.Color := RGB(220, 220, 220);
  InfoLabel.Font.Name := 'Consolas';
  InfoLabel.Font.Size := 10;
  InfoLabel.Layout := tlTop;
  InfoLabel.WordWrap := True;
  InfoLabel.Caption := 'Aul2AudioMonitor';
  InfoLabel.Visible := False;

  WavePaintBox := TPaintBox.Create(MonitorForm);
  WavePaintBox.Parent := PanelWave;
  WavePaintBox.Align := alClient;
  WavePaintBox.OnPaint := TimerTarget.WavePaint;
  WavePaintBox.BringToFront;

  SpectrumPaintBox := TPaintBox.Create(MonitorForm);
  SpectrumPaintBox.Parent := PanelSpectrum;
  SpectrumPaintBox.Align := alClient;
  SpectrumPaintBox.OnPaint := TimerTarget.SpectrumPaint;
  SpectrumPaintBox.BringToFront;

  ToolBarManager := TToolBarPanelManager.Create;
  ToolBarManager.ToolBarBackgroundColor := RGB(48, 48, 48);
  ToolBarManager.ToolBarFontColor := RGB(230, 230, 230);
  ToolBarManager.ToolBarCheckedColor := RGB(70, 70, 70);
  ToolBarManager.ToolBarPressedColor := RGB(62, 62, 62);
  ToolBarManager.ToolBarHotColor := RGB(58, 58, 58);
  ToolBarManager.AddPanel(PanelWave);
  ToolBarManager.AddPanel(PanelSpectrum);
  ToolBarManager.Attach(ToolBar);
  ToolBarManager.Activate(Ord(ampSpectrum));

  ReadTimer := TTimer.Create(MonitorForm);
  ReadTimer.Interval := 50;
  ReadTimer.OnTimer := TimerTarget.ReadTimerTick;
  ReadTimer.Enabled := True;

  MonitorForm.Show;
  MonitorForm.Visible := True;

  if GetClientRect(ClientWindow, Rect) then
    ResizeMonitorView(Rect.Right - Rect.Left, Rect.Bottom - Rect.Top)
  else
    ResizeMonitorView(480, 260);

  SyncMonitorViewBounds;
  InvalidateMonitorView;
end;

procedure ShowMonitorView;
begin
  if ClientWindow <> 0 then
  begin
    ShowWindow(ClientWindow, SW_SHOW);
    SyncMonitorViewBounds;
    SetFocus(ClientWindow);
  end;

  if Assigned(MonitorForm) then
  begin
    MonitorForm.Show;
    MonitorForm.SetFocus;
  end;
end;

procedure DestroyMonitorView;
begin
  FreeAndNil(SharedMemory);
  FreeAndNil(SpectrumMemory);
  FreeAndNil(ReadTimer);
  FreeAndNil(ToolBarManager);
  FreeAndNil(TimerTarget);
  FreeAndNil(SpectrumPaintBox);
  FreeAndNil(WavePaintBox);
  FreeAndNil(InfoLabel);
  FreeAndNil(PanelSpectrum);
  FreeAndNil(PanelWave);
  FreeAndNil(ButtonSpectrum);
  FreeAndNil(ButtonWave);
  FreeAndNil(ToolBar);
  FreeAndNil(RootPanel);
  FreeAndNil(MonitorForm);
  ClientWindow := 0;
end;

end.
