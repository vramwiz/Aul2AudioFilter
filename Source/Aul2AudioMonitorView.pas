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
  System.Math,
  System.SysUtils,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  Vcl.ToolWin,
  Aul2AudioMonitorPaint,
  Aul2AudioMonitorShared,
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioViewFrameShared,
  Aul2AudioBasePanel,
  AviUtl2PluginCore,
  ToolBarPanelManager;

type
  TAudioMonitorPage = (
    ampWave,
    ampSpectrum,
    ampBase
  );

  TMonitorStateSnapshot = record
    Valid: Boolean;
    Tick : UInt64;
    State: TAul2AudioMonitorState;
  end;

  TSpectrumStateSnapshot = record
    Valid: Boolean;
    Tick : UInt64;
    State: TAul2AudioMonitorSpectrumState;
  end;

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
  ButtonBase  : TToolButton;
  StateLabel  : TLabel;
  PanelWave   : TPanel;
  PanelSpectrum: TPanel;
  PanelBase   : TPanel;
  BasePanel   : TAul2AudioBasePanel;
  InfoLabel   : TLabel;
  WavePaintBox: TPaintBox;
  SpectrumPaintBox: TPaintBox;
  ReadTimer   : TTimer;
  TimerTarget : TMonitorTimerTarget;
  ToolBarManager: TToolBarPanelManager;
  SharedMemory: TAul2AudioMonitorSharedMemory;
  SpectrumMemory: TAul2AudioMonitorSpectrumSharedMemory;
  ViewFrameMemory: TAul2AudioViewFrameSharedMemory;
  LastViewWidth: Integer;
  LastViewHeight: Integer;
  LastEditStatePollTick: UInt64;
  MonitorEditState: TAviUtl2EditState;
  MonitorEditStateValid: Boolean;
  LastMonitorEditState: TAviUtl2EditState;
  LastMonitorEditStateValid: Boolean;
  MonitorFrame: Integer;
  MonitorFrameValid: Boolean;
  MonitorHistory: array[0..127] of TMonitorStateSnapshot;
  SpectrumHistory: array[0..127] of TSpectrumStateSnapshot;
  MonitorHistoryIndex: Integer;
  SpectrumHistoryIndex: Integer;

procedure ClearPlaybackHistory;
begin
  FillChar(MonitorHistory, SizeOf(MonitorHistory), 0);
  FillChar(SpectrumHistory, SizeOf(SpectrumHistory), 0);
  MonitorHistoryIndex := 0;
  SpectrumHistoryIndex := 0;
end;

procedure PositionStateLabel;
var
  LabelWidth: Integer;
  LabelLeft : Integer;
begin
  if not Assigned(StateLabel) or not Assigned(ToolBar) then
    Exit;

  LabelWidth := MulDiv(118, MonitorForm.Font.PixelsPerInch, 96);
  LabelLeft := ToolBar.ClientWidth - LabelWidth - MulDiv(10, MonitorForm.Font.PixelsPerInch, 96);
  if Assigned(ButtonBase) then
    LabelLeft := Max(LabelLeft, ButtonBase.Left + ButtonBase.Width +
      MulDiv(32, MonitorForm.Font.PixelsPerInch, 96));

  StateLabel.SetBounds(LabelLeft, 0, LabelWidth, ToolBar.Height);
  StateLabel.BringToFront;
end;

procedure UpdateStateLabel;
begin
  if not Assigned(StateLabel) then
    Exit;

  if not MonitorEditStateValid then
  begin
    StateLabel.Caption := 'State: ?';
    StateLabel.Font.Color := RGB(170, 170, 170);
    StateLabel.Invalidate;
    Exit;
  end;

  case MonitorEditState of
    aesPlay:
      begin
        StateLabel.Caption := 'State: Play';
        StateLabel.Font.Color := RGB(224, 176, 72);
      end;
    aesSave:
      begin
        StateLabel.Caption := 'State: Save';
        StateLabel.Font.Color := RGB(210, 92, 76);
      end;
  else
    begin
      StateLabel.Caption := 'State: Edit';
      StateLabel.Font.Color := RGB(92, 190, 122);
    end;
  end;

  StateLabel.Invalidate;
end;

procedure RefreshEditState;
const
  EDIT_STATE_POLL_MS = 500;
var
  NowTick: UInt64;
  NewEditState: TAviUtl2EditState;
begin
  NowTick := GetTickCount64;
  if (LastEditStatePollTick <> 0) and
     (NowTick >= LastEditStatePollTick) and
     ((NowTick - LastEditStatePollTick) < EDIT_STATE_POLL_MS) then
    Exit;

  LastEditStatePollTick := NowTick;
  try
    NewEditState := AviUtl2GetEditState;
    if LastMonitorEditStateValid and
       (LastMonitorEditState = aesEdit) and
       (NewEditState = aesPlay) then
    begin
      ClearPlaybackHistory;
      ClearAudioMonitorDisplay;
    end;

    MonitorEditState := NewEditState;
    MonitorEditStateValid := True;
    LastMonitorEditState := MonitorEditState;
    LastMonitorEditStateValid := True;
  except
    MonitorEditState := aesEdit;
    MonitorEditStateValid := False;
  end;

  UpdateStateLabel;
end;

procedure RefreshMonitorFrame;
const
  VIEW_FRAME_STALE_MS = 300;
var
  State: PAul2AudioViewFrameState;
  NowTick: UInt64;
begin
  MonitorFrame := -1;
  MonitorFrameValid := False;

  try
    if ViewFrameMemory = nil then
      ViewFrameMemory := TAul2AudioViewFrameSharedMemory.Create;
    State := ViewFrameMemory.State;
    NowTick := GetTickCount64;
    if (State <> nil) and
       (State^.Magic = AUDIO_VIEW_FRAME_SHARED_MAGIC) and
       (State^.Version = AUDIO_VIEW_FRAME_SHARED_VERSION) and
       (State^.Frame >= 0) and
       (State^.UpdateTick <> 0) and
       (NowTick >= State^.UpdateTick) and
       ((NowTick - State^.UpdateTick) <= VIEW_FRAME_STALE_MS) then
    begin
      MonitorFrame := State^.Frame;
      MonitorFrameValid := True;
      Exit;
    end;
  except
    MonitorFrame := -1;
    MonitorFrameValid := False;
  end;

  try
    MonitorFrameValid := AviUtl2GetEditFrame(MonitorFrame);
  except
    MonitorFrame := -1;
    MonitorFrameValid := False;
  end;
end;

function IsPlaybackDisplay: Boolean;
begin
  Result := MonitorEditStateValid and (MonitorEditState = aesPlay);
end;

function PlaybackFrameAvailable: Boolean;
begin
  Result := MonitorFrameValid and (MonitorFrame >= 0);
end;

function MonitorStateMatchesFrame(const State: TAul2AudioMonitorState; Frame: Integer): Boolean;
begin
  if Frame < 0 then
  begin
    Result := True;
    Exit;
  end;

  if (State.SourceFrameS <= 0) and (State.SourceFrameE <= 0) then
  begin
    Result := True;
    Exit;
  end;

  Result := (Frame >= State.SourceFrameS) and (Frame <= State.SourceFrameE);
end;

function SpectrumStateMatchesFrame(const State: TAul2AudioMonitorSpectrumState; Frame: Integer): Boolean;
begin
  if Frame < 0 then
  begin
    Result := True;
    Exit;
  end;

  if (State.SourceFrameS <= 0) and (State.SourceFrameE <= 0) then
  begin
    Result := True;
    Exit;
  end;

  Result := (Frame >= State.SourceFrameS) and (Frame <= State.SourceFrameE);
end;

procedure PushMonitorHistory(State: PAul2AudioMonitorState);
begin
  if State = nil then
    Exit;

  MonitorHistoryIndex := (MonitorHistoryIndex + 1) mod Length(MonitorHistory);
  MonitorHistory[MonitorHistoryIndex].Valid := True;
  MonitorHistory[MonitorHistoryIndex].Tick := GetTickCount64;
  MonitorHistory[MonitorHistoryIndex].State := State^;
end;

procedure PushSpectrumHistory(State: PAul2AudioMonitorSpectrumState);
begin
  if State = nil then
    Exit;

  SpectrumHistoryIndex := (SpectrumHistoryIndex + 1) mod Length(SpectrumHistory);
  SpectrumHistory[SpectrumHistoryIndex].Valid := True;
  SpectrumHistory[SpectrumHistoryIndex].Tick := GetTickCount64;
  SpectrumHistory[SpectrumHistoryIndex].State := State^;
end;

function SelectMonitorSnapshot(Current: PAul2AudioMonitorState;
  out Snapshot: TAul2AudioMonitorState): PAul2AudioMonitorState;
var
  I: Integer;
  BestIndex: Integer;
begin
  Result := Current;
  PushMonitorHistory(Current);
  if not IsPlaybackDisplay then
    Exit;
  if not PlaybackFrameAvailable then
  begin
    Result := nil;
    Exit;
  end;

  BestIndex := -1;
  for I := Low(MonitorHistory) to High(MonitorHistory) do
  begin
    if not MonitorHistory[I].Valid then
      Continue;

    if MonitorStateMatchesFrame(MonitorHistory[I].State, MonitorFrame) then
      if (BestIndex < 0) or (MonitorHistory[I].Tick > MonitorHistory[BestIndex].Tick) then
        BestIndex := I;
  end;

  if BestIndex < 0 then
  begin
    Result := nil;
    Exit;
  end;

  Snapshot := MonitorHistory[BestIndex].State;
  Snapshot.UpdateTick := GetTickCount64;
  Result := @Snapshot;
end;

function SelectSpectrumSnapshot(Current: PAul2AudioMonitorSpectrumState;
  out Snapshot: TAul2AudioMonitorSpectrumState): PAul2AudioMonitorSpectrumState;
var
  I: Integer;
  BestIndex: Integer;
begin
  Result := Current;
  PushSpectrumHistory(Current);
  if not IsPlaybackDisplay then
    Exit;
  if not PlaybackFrameAvailable then
  begin
    Result := nil;
    Exit;
  end;

  BestIndex := -1;
  for I := Low(SpectrumHistory) to High(SpectrumHistory) do
  begin
    if not SpectrumHistory[I].Valid then
      Continue;

    if SpectrumStateMatchesFrame(SpectrumHistory[I].State, MonitorFrame) then
      if (BestIndex < 0) or (SpectrumHistory[I].Tick > SpectrumHistory[BestIndex].Tick) then
        BestIndex := I;
  end;

  if BestIndex < 0 then
  begin
    Result := nil;
    Exit;
  end;

  Snapshot := SpectrumHistory[BestIndex].State;
  Snapshot.UpdateTick := GetTickCount64;
  Result := @Snapshot;
end;

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

  if (Width = LastViewWidth) and (Height = LastViewHeight) then
    Exit;

  LastViewWidth := Width;
  LastViewHeight := Height;

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

  PositionStateLabel;
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
  if Assigned(WavePaintBox) and WavePaintBox.Visible and PanelWave.Visible then
    WavePaintBox.Invalidate;

  if Assigned(SpectrumPaintBox) and SpectrumPaintBox.Visible and PanelSpectrum.Visible then
    SpectrumPaintBox.Invalidate;
end;

procedure DrawBuffered(PaintBox: TPaintBox; DrawProc: TProc<TCanvas, TRect>);
var
  Buffer: TBitmap;
begin
  if (PaintBox.ClientWidth <= 0) or (PaintBox.ClientHeight <= 0) then
    Exit;

  Buffer := TBitmap.Create;
  try
    Buffer.SetSize(PaintBox.ClientWidth, PaintBox.ClientHeight);
    Buffer.Canvas.Font.Assign(PaintBox.Canvas.Font);
    DrawProc(Buffer.Canvas, Rect(0, 0, Buffer.Width, Buffer.Height));
    PaintBox.Canvas.Draw(0, 0, Buffer);
  finally
    Buffer.Free;
  end;
end;

procedure TMonitorTimerTarget.ReadTimerTick(Sender: TObject);
begin
  RefreshEditState;
  RefreshMonitorFrame;
  SyncMonitorViewBounds;
  InvalidateMonitorView;
end;

procedure TMonitorTimerTarget.WavePaint(Sender: TObject);
var
  PaintBox: TPaintBox;
  State: PAul2AudioMonitorState;
  DisplayState: PAul2AudioMonitorState;
  StateSnapshot: TAul2AudioMonitorState;
begin
  if not (Sender is TPaintBox) then
    Exit;

  PaintBox := TPaintBox(Sender);

  try
    State := GetMonitorSharedMemory.State;
  except
    State := nil;
  end;
  DisplayState := SelectMonitorSnapshot(State, StateSnapshot);

  DrawBuffered(PaintBox,
    procedure(Canvas: TCanvas; Rect: TRect)
    begin
      DrawAudioMonitorCanvas(Canvas, Rect, DisplayState, True);
    end);
end;

procedure TMonitorTimerTarget.SpectrumPaint(Sender: TObject);
var
  PaintBox: TPaintBox;
  MonitorState: PAul2AudioMonitorState;
  SpectrumState: PAul2AudioMonitorSpectrumState;
  DisplayMonitorState: PAul2AudioMonitorState;
  DisplaySpectrumState: PAul2AudioMonitorSpectrumState;
  MonitorSnapshot: TAul2AudioMonitorState;
  SpectrumSnapshot: TAul2AudioMonitorSpectrumState;
begin
  if not (Sender is TPaintBox) then
    Exit;

  PaintBox := TPaintBox(Sender);

  try
    SpectrumState := GetSpectrumSharedMemory.State;
  except
    SpectrumState := nil;
  end;

  try
    MonitorState := GetMonitorSharedMemory.State;
  except
    MonitorState := nil;
  end;
  DisplaySpectrumState := SelectSpectrumSnapshot(SpectrumState, SpectrumSnapshot);
  DisplayMonitorState := SelectMonitorSnapshot(MonitorState, MonitorSnapshot);

  DrawBuffered(PaintBox,
    procedure(Canvas: TCanvas; Rect: TRect)
    begin
      DrawAudioSpectrumCanvas(Canvas, Rect, DisplaySpectrumState, DisplayMonitorState, True);
    end);
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
  MonitorForm.ParentFont := False;
  MonitorForm.Font.Name := 'Yu Gothic UI';
  MonitorForm.Font.Size := 9;
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
  ToolBar.Height := MulDiv(28, MonitorForm.Font.PixelsPerInch, 96);
  ToolBar.ButtonWidth := MulDiv(74, MonitorForm.Font.PixelsPerInch, 96);
  ToolBar.ButtonHeight := ToolBar.Height;
  ToolBar.EdgeBorders := [];
  ToolBar.ShowCaptions := True;
  ToolBar.Flat := True;
  ToolBar.List := True;
  ToolBar.ParentFont := False;
  ToolBar.Font.Assign(MonitorForm.Font);

  ButtonBase := TToolButton.Create(MonitorForm);
  ButtonBase.Parent := ToolBar;
  ButtonBase.Caption := 'View';
  ButtonBase.Left := ToolBar.ButtonWidth * 2;
  ButtonBase.Top := 0;

  ButtonSpectrum := TToolButton.Create(MonitorForm);
  ButtonSpectrum.Parent := ToolBar;
  ButtonSpectrum.Caption := 'Spectrum';
  ButtonSpectrum.Left := ToolBar.ButtonWidth;
  ButtonSpectrum.Top := 0;

  ButtonWave := TToolButton.Create(MonitorForm);
  ButtonWave.Parent := ToolBar;
  ButtonWave.Caption := 'Wave';
  ButtonWave.Left := 0;
  ButtonWave.Top := 0;

  StateLabel := TLabel.Create(MonitorForm);
  StateLabel.Parent := ToolBar;
  StateLabel.AutoSize := False;
  StateLabel.Transparent := False;
  StateLabel.Color := RGB(48, 48, 48);
  StateLabel.ParentFont := False;
  StateLabel.Font.Assign(MonitorForm.Font);
  StateLabel.Layout := tlCenter;
  StateLabel.Alignment := taLeftJustify;
  StateLabel.Caption := 'State: ?';
  StateLabel.Font.Color := RGB(170, 170, 170);
  StateLabel.Visible := False;

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

  PanelBase := TPanel.Create(MonitorForm);
  PanelBase.Parent := RootPanel;
  PanelBase.Align := alClient;
  PanelBase.BevelOuter := bvNone;
  PanelBase.Caption := '';
  PanelBase.Color := RGB(36, 36, 36);
  PanelBase.ParentBackground := False;

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

  BasePanel := TAul2AudioBasePanel.Create(MonitorForm);
  BasePanel.Parent := PanelBase;
  BasePanel.Align := alClient;
  BasePanel.Initialize;

  ToolBarManager := TToolBarPanelManager.Create;
  ToolBarManager.ToolBarBackgroundColor := RGB(48, 48, 48);
  ToolBarManager.ToolBarFontColor := RGB(230, 230, 230);
  ToolBarManager.ToolBarCheckedColor := RGB(70, 70, 70);
  ToolBarManager.ToolBarPressedColor := RGB(62, 62, 62);
  ToolBarManager.ToolBarHotColor := RGB(58, 58, 58);
  ToolBarManager.AddPanel(PanelWave);
  ToolBarManager.AddPanel(PanelSpectrum);
  ToolBarManager.AddPanel(PanelBase);

  MonitorForm.Show;
  MonitorForm.Visible := True;

  if GetClientRect(ClientWindow, Rect) then
    ResizeMonitorView(Rect.Right - Rect.Left, Rect.Bottom - Rect.Top)
  else
    ResizeMonitorView(480, 260);

  SyncMonitorViewBounds;
  ToolBarManager.Attach(ToolBar);
  ToolBarManager.Activate(Ord(ampSpectrum));
  PositionStateLabel;
  StateLabel.Visible := True;
  UpdateStateLabel;
  ToolBar.Invalidate;

  ReadTimer := TTimer.Create(MonitorForm);
  ReadTimer.Interval := 50;
  ReadTimer.OnTimer := TimerTarget.ReadTimerTick;
  ReadTimer.Enabled := True;

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
  FreeAndNil(ViewFrameMemory);
  FreeAndNil(ReadTimer);
  FreeAndNil(ToolBarManager);
  FreeAndNil(TimerTarget);
  FreeAndNil(SpectrumPaintBox);
  FreeAndNil(WavePaintBox);
  FreeAndNil(InfoLabel);
  FreeAndNil(BasePanel);
  FreeAndNil(PanelBase);
  FreeAndNil(PanelSpectrum);
  FreeAndNil(PanelWave);
  FreeAndNil(StateLabel);
  FreeAndNil(ButtonBase);
  FreeAndNil(ButtonSpectrum);
  FreeAndNil(ButtonWave);
  FreeAndNil(ToolBar);
  FreeAndNil(RootPanel);
  FreeAndNil(MonitorForm);
  ClientWindow := 0;
  LastViewWidth := 0;
  LastViewHeight := 0;
  LastEditStatePollTick := 0;
  MonitorEditState := aesEdit;
  MonitorEditStateValid := False;
  LastMonitorEditState := aesEdit;
  LastMonitorEditStateValid := False;
  MonitorFrame := -1;
  MonitorFrameValid := False;
  ClearPlaybackHistory;
  ClearAudioMonitorDisplay;
end;

end.
