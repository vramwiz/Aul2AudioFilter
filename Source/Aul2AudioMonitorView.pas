unit Aul2AudioMonitorView;

// Aul2AudioMonitor の VCL フォーム、タイマー、共有メモリ読み取りを担当する。

interface

uses
  Winapi.Windows;

const
  MONITOR_WINDOW_NAME = 'Aul2AudioMonitor'; // フォームとクライアントで共有する表示名。

// Monitorフォームを生成し、ParentWindowの子としてWave/Spectrum/Baseページを構築する。
procedure CreateMonitorView(ParentWindow: HWND);
// タイマー、共有メモリ、フォームを停止・解放し、表示用履歴を破棄する。
procedure DestroyMonitorView;
// 作成済みMonitorフォームを表示して前面へ移す。
procedure ShowMonitorView;
// 親クライアントの現在サイズへMonitorフォームを追従させる。
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
  Aul2AudioPresetPanel,
  AviUtl2PluginCore,
  ToolBarPanelManager;

const
  // Monitor はタイマー描画のため View より先行して見える。再生時の履歴参照をこのフレーム数だけ後方へずらす。
  MONITOR_PLAYBACK_FRAME_DELAY = 10;

type
  TAudioMonitorPage = (
    ampWave,
    ampSpectrum,
    ampBase,
    ampPreset
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
  HeaderPanel : TPanel;
  ToolBar     : TToolBar;
  ButtonWave  : TToolButton;
  ButtonSpectrum: TToolButton;
  ButtonBase  : TToolButton;
  ButtonPreset: TToolButton;
  StateLabel  : TLabel;
  PanelWave   : TPanel;
  PanelSpectrum: TPanel;
  PanelBase   : TPanel;
  PanelPreset : TPanel;
  BasePanel   : TAul2AudioBasePanel;
  PresetPanel : TAul2AudioPresetPanel;
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
  PlaybackMonitorSnapshot: TAul2AudioMonitorState;
  PlaybackSpectrumSnapshot: TAul2AudioMonitorSpectrumState;
  PlaybackMonitorSnapshotValid: Boolean;
  PlaybackSpectrumSnapshotValid: Boolean;

procedure ClearPlaybackHistory;
begin
  PlaybackMonitorSnapshotValid := False;
  PlaybackSpectrumSnapshotValid := False;
end;

procedure PositionStateLabel;
var
  LabelWidth: Integer;
  LabelLeft : Integer;
begin
  if not Assigned(StateLabel) or not Assigned(ToolBar) then
    Exit;

  LabelWidth := MulDiv(118, MonitorForm.Font.PixelsPerInch, 96);
  if Assigned(HeaderPanel) then
    LabelLeft := HeaderPanel.ClientWidth - LabelWidth - MulDiv(10, MonitorForm.Font.PixelsPerInch, 96)
  else
    LabelLeft := ToolBar.Left + ToolBar.Width + MulDiv(10, MonitorForm.Font.PixelsPerInch, 96);
  LabelLeft := Max(LabelLeft, ToolBar.Left + ToolBar.Width +
    MulDiv(10, MonitorForm.Font.PixelsPerInch, 96));

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

function MonitorDisplayFrame: Integer;
begin
  Result := MonitorFrame - MONITOR_PLAYBACK_FRAME_DELAY;
  if Result < 0 then
    Result := 0;
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

function MonitorStateUsable(State: PAul2AudioMonitorState): Boolean;
begin
  Result := (State <> nil) and
            (State^.Magic = AUDIO_MONITOR_SHARED_MAGIC) and
            (State^.Version = AUDIO_MONITOR_SHARED_VERSION) and
            (State^.UpdateTick <> 0);
end;

function SpectrumStateUsable(State: PAul2AudioMonitorSpectrumState): Boolean;
begin
  Result := (State <> nil) and
            (State^.Magic = AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) and
            (State^.Version = AUDIO_MONITOR_SPECTRUM_SHARED_VERSION) and
            (State^.UpdateTick <> 0);
end;

function GetMonitorSharedMemory: TAul2AudioMonitorSharedMemory; forward;
function GetSpectrumSharedMemory: TAul2AudioMonitorSpectrumSharedMemory; forward;

function MonitorStateDisplayFrame(State: PAul2AudioMonitorState): Integer;
begin
  Result := State^.SourceFrameS + State^.SourceFrame;
end;

function SpectrumStateDisplayFrame(State: PAul2AudioMonitorSpectrumState): Integer;
begin
  Result := State^.SourceFrameS + State^.SourceFrame;
end;

function MonitorStateFrameDistance(State: PAul2AudioMonitorState; Frame: Integer): Integer;
begin
  if Frame < 0 then
    Exit(0);

  Result := Abs(MonitorStateDisplayFrame(State) - Frame);
end;

function SpectrumStateFrameDistance(State: PAul2AudioMonitorSpectrumState; Frame: Integer): Integer;
begin
  if Frame < 0 then
    Exit(0);

  Result := Abs(SpectrumStateDisplayFrame(State) - Frame);
end;

function PreferMonitorState(Candidate, Current: PAul2AudioMonitorState;
  Frame: Integer): Boolean;
var
  CandidateDistance: Integer;
  CurrentDistance: Integer;
begin
  if Current = nil then
    Exit(True);

  CandidateDistance := MonitorStateFrameDistance(Candidate, Frame);
  CurrentDistance := MonitorStateFrameDistance(Current, Frame);
  if CandidateDistance <> CurrentDistance then
    Exit(CandidateDistance < CurrentDistance);

  Result := Candidate^.UpdateTick > Current^.UpdateTick;
end;

function PreferSpectrumState(Candidate, Current: PAul2AudioMonitorSpectrumState;
  Frame: Integer): Boolean;
var
  CandidateDistance: Integer;
  CurrentDistance: Integer;
begin
  if Current = nil then
    Exit(True);

  CandidateDistance := SpectrumStateFrameDistance(Candidate, Frame);
  CurrentDistance := SpectrumStateFrameDistance(Current, Frame);
  if CandidateDistance <> CurrentDistance then
    Exit(CandidateDistance < CurrentDistance);

  Result := Candidate^.UpdateTick > Current^.UpdateTick;
end;

function FindMonitorHistoryState(Frame: Integer): PAul2AudioMonitorState;
var
  Layer: Integer;
  Index: Integer;
  State: PAul2AudioMonitorState;
  Memory: TAul2AudioMonitorSharedMemory;
begin
  Result := nil;

  Memory := GetMonitorSharedMemory;
  if (Memory = nil) or (Memory.Root = nil) then
    Exit;

  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    for Index := 0 to AUDIO_MONITOR_HISTORY_LAST do
    begin
      State := Memory.GetHistoryStateForLayer(Layer, Index);
      if MonitorStateUsable(State) and MonitorStateMatchesFrame(State^, Frame) and
         PreferMonitorState(State, Result, Frame) then
        Result := State;
    end;
  end;
end;

function FindSpectrumHistoryState(Frame: Integer): PAul2AudioMonitorSpectrumState;
var
  Layer: Integer;
  Index: Integer;
  State: PAul2AudioMonitorSpectrumState;
  Memory: TAul2AudioMonitorSpectrumSharedMemory;
begin
  Result := nil;

  Memory := GetSpectrumSharedMemory;
  if (Memory = nil) or (Memory.Root = nil) then
    Exit;

  for Layer := 0 to AUDIO_MONITOR_LAYER_SLOT_LAST do
  begin
    for Index := 0 to AUDIO_MONITOR_SPECTRUM_HISTORY_LAST do
    begin
      State := Memory.GetHistoryStateForLayer(Layer, Index);
      if SpectrumStateUsable(State) and SpectrumStateMatchesFrame(State^, Frame) and
         PreferSpectrumState(State, Result, Frame) then
        Result := State;
    end;
  end;
end;

procedure DecayMonitorSnapshot(var State: TAul2AudioMonitorState);
const
  DECAY = 0.72;
var
  Index: Integer;
begin
  State.InputPeakL := State.InputPeakL * DECAY;
  State.InputPeakR := State.InputPeakR * DECAY;
  State.OutputPeakL := State.OutputPeakL * DECAY;
  State.OutputPeakR := State.OutputPeakR * DECAY;
  State.InputRmsL := State.InputRmsL * DECAY;
  State.InputRmsR := State.InputRmsR * DECAY;
  State.OutputRmsL := State.OutputRmsL * DECAY;
  State.OutputRmsR := State.OutputRmsR * DECAY;
  for Index := 0 to AUDIO_MONITOR_WAVE_POINT_LAST do
  begin
    State.InputWave[Index] := State.InputWave[Index] * DECAY;
    State.OutputWave[Index] := State.OutputWave[Index] * DECAY;
    State.InputWaveMin[Index] := State.InputWaveMin[Index] * DECAY;
    State.InputWaveMax[Index] := State.InputWaveMax[Index] * DECAY;
    State.OutputWaveMin[Index] := State.OutputWaveMin[Index] * DECAY;
    State.OutputWaveMax[Index] := State.OutputWaveMax[Index] * DECAY;
  end;
  State.UpdateTick := GetTickCount64;
end;

procedure DecaySpectrumSnapshot(var State: TAul2AudioMonitorSpectrumState);
const
  DECAY = 0.72;
var
  Index: Integer;
begin
  for Index := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
  begin
    State.InputBands[Index] := State.InputBands[Index] * DECAY;
    State.OutputBands[Index] := State.OutputBands[Index] * DECAY;
  end;
  State.UpdateTick := GetTickCount64;
end;

function SelectMonitorSnapshot(Current: PAul2AudioMonitorState;
  out Snapshot: TAul2AudioMonitorState): PAul2AudioMonitorState;
var
  DisplayFrame: Integer;
begin
  Result := Current;
  if not IsPlaybackDisplay then
    Exit;
  if not PlaybackFrameAvailable then
    Exit;

  DisplayFrame := MonitorDisplayFrame;
  Result := FindMonitorHistoryState(DisplayFrame);
  if (Result <> nil) and (MonitorStateFrameDistance(Result, DisplayFrame) > 1) then
    Result := nil;
  if Result = nil then
  begin
    if not PlaybackMonitorSnapshotValid then
      Exit(nil);
    DecayMonitorSnapshot(PlaybackMonitorSnapshot);
    Snapshot := PlaybackMonitorSnapshot;
    Exit(@Snapshot);
  end;
  if not MonitorStateUsable(Result) then
    Exit;

  Snapshot := Result^;
  Snapshot.UpdateTick := GetTickCount64;
  PlaybackMonitorSnapshot := Snapshot;
  PlaybackMonitorSnapshotValid := True;
  Result := @Snapshot;
end;

function SelectSpectrumSnapshot(Current: PAul2AudioMonitorSpectrumState;
  out Snapshot: TAul2AudioMonitorSpectrumState): PAul2AudioMonitorSpectrumState;
var
  DisplayFrame: Integer;
begin
  Result := Current;
  if not IsPlaybackDisplay then
    Exit;
  if not PlaybackFrameAvailable then
    Exit;

  DisplayFrame := MonitorDisplayFrame;
  Result := FindSpectrumHistoryState(DisplayFrame);
  if (Result <> nil) and (SpectrumStateFrameDistance(Result, DisplayFrame) > 1) then
    Result := nil;
  if Result = nil then
  begin
    if not PlaybackSpectrumSnapshotValid then
      Exit(nil);
    DecaySpectrumSnapshot(PlaybackSpectrumSnapshot);
    Snapshot := PlaybackSpectrumSnapshot;
    Exit(@Snapshot);
  end;
  if not SpectrumStateUsable(Result) then
    Exit;

  Snapshot := Result^;
  Snapshot.UpdateTick := GetTickCount64;
  PlaybackSpectrumSnapshot := Snapshot;
  PlaybackSpectrumSnapshotValid := True;
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
var
  ToolButtonWidth: Integer;
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

  if Assigned(ToolBar) then
  begin
    // 全ボタンで共通となる幅は、最長の Caption に左右の余白を加えて決める。
    MonitorForm.Canvas.Font.Assign(ToolBar.Font);
    ToolButtonWidth := Max(MonitorForm.Canvas.TextWidth(ButtonSpectrum.Caption),
      MonitorForm.Canvas.TextWidth(ButtonPreset.Caption)) +
      MulDiv(24, MonitorForm.Font.PixelsPerInch, 96);
    ToolBar.ButtonWidth := ToolButtonWidth;
    ToolBar.ButtonHeight := MulDiv(28, MonitorForm.Font.PixelsPerInch, 96);
    // 4個目の Preset を含む全ボタンと、ツールバー右端の内部余白を確保する。
    ToolBar.Width := ToolButtonWidth * 4 + MulDiv(4, MonitorForm.Font.PixelsPerInch, 96);
    ToolBar.Height := ToolBar.ButtonHeight;
    ToolBar.Realign;
    ToolBar.Invalidate;
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
  // 50msごとに再生状態と基準フレームを一度更新し、表示中のページだけを再描画する。
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
      DrawAudioSpectrumCanvas(Canvas, Rect, DisplaySpectrumState, DisplayMonitorState,
        True, IsPlaybackDisplay);
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

  HeaderPanel := TPanel.Create(MonitorForm);
  HeaderPanel.Parent := RootPanel;
  HeaderPanel.Align := alTop;
  HeaderPanel.Height := MulDiv(28, MonitorForm.Font.PixelsPerInch, 96);
  HeaderPanel.BevelOuter := bvNone;
  HeaderPanel.Caption := '';
  HeaderPanel.Color := RGB(48, 48, 48);
  HeaderPanel.ParentBackground := False;

  ToolBar := TToolBar.Create(MonitorForm);
  ToolBar.Parent := HeaderPanel;
  ToolBar.Align := alLeft;
  ToolBar.Height := MulDiv(28, MonitorForm.Font.PixelsPerInch, 96);
  ToolBar.ButtonWidth := MulDiv(74, MonitorForm.Font.PixelsPerInch, 96);
  ToolBar.ButtonHeight := ToolBar.Height;
  // TToolBar内部の右端余白を含め、最後のPresetボタンがDPI環境で切れない幅を確保する。
  ToolBar.Width := ToolBar.ButtonWidth * 4 + MulDiv(12, MonitorForm.Font.PixelsPerInch, 96);
  ToolBar.EdgeBorders := [];
  ToolBar.ShowCaptions := True;
  ToolBar.Flat := True;
  ToolBar.List := True;
  ToolBar.Color := RGB(48, 48, 48);
  ToolBar.ParentColor := False;
  ToolBar.ParentFont := False;
  ToolBar.Font.Assign(MonitorForm.Font);

  ButtonWave := TToolButton.Create(MonitorForm);
  ButtonWave.Caption := 'Wave';
  ButtonWave.Left := 0;
  ButtonWave.Top := 0;
  ButtonWave.Parent := ToolBar;

  ButtonSpectrum := TToolButton.Create(MonitorForm);
  ButtonSpectrum.Caption := 'Spectrum';
  ButtonSpectrum.Left := ToolBar.ButtonWidth;
  ButtonSpectrum.Top := 0;
  ButtonSpectrum.Parent := ToolBar;

  ButtonBase := TToolButton.Create(MonitorForm);
  ButtonBase.Caption := 'View';
  ButtonBase.Left := ToolBar.ButtonWidth * 2;
  ButtonBase.Top := 0;
  ButtonBase.Parent := ToolBar;

  ButtonPreset := TToolButton.Create(MonitorForm);
  ButtonPreset.Caption := 'Preset';
  ButtonPreset.Left := ToolBar.ButtonWidth * 3;
  ButtonPreset.Top := 0;
  ButtonPreset.Parent := ToolBar;

  StateLabel := TLabel.Create(MonitorForm);
  StateLabel.Parent := HeaderPanel;
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

  PanelPreset := TPanel.Create(MonitorForm);
  PanelPreset.Parent := RootPanel;
  PanelPreset.Align := alClient;
  PanelPreset.BevelOuter := bvNone;
  PanelPreset.Caption := '';
  PanelPreset.Color := RGB(36, 36, 36);
  PanelPreset.ParentBackground := False;

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

  PresetPanel := TAul2AudioPresetPanel.Create(MonitorForm);
  PresetPanel.Parent := PanelPreset;
  PresetPanel.Align := alClient;
  PresetPanel.Initialize;

  ToolBarManager := TToolBarPanelManager.Create;
  ToolBarManager.ToolBarBackgroundColor := RGB(48, 48, 48);
  ToolBarManager.ToolBarFontColor := RGB(230, 230, 230);
  ToolBarManager.ToolBarCheckedColor := RGB(70, 70, 70);
  ToolBarManager.ToolBarPressedColor := RGB(62, 62, 62);
  ToolBarManager.ToolBarHotColor := RGB(58, 58, 58);
  ToolBarManager.AddPanel(PanelWave);
  ToolBarManager.AddPanel(PanelSpectrum);
  ToolBarManager.AddPanel(PanelBase);
  ToolBarManager.AddPanel(PanelPreset);

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
  if Assigned(ReadTimer) then
  begin
    ReadTimer.Enabled := False;
    ReadTimer.OnTimer := nil;
  end;

  if Assigned(WavePaintBox) then
    WavePaintBox.OnPaint := nil;

  if Assigned(SpectrumPaintBox) then
    SpectrumPaintBox.OnPaint := nil;

  if Assigned(MonitorForm) then
  begin
    MonitorForm.Hide;
    MonitorForm.ParentWindow := 0;
  end;

  FreeAndNil(SharedMemory);
  FreeAndNil(SpectrumMemory);
  FreeAndNil(ViewFrameMemory);
  FreeAndNil(ReadTimer);
  FreeAndNil(ToolBarManager);
  FreeAndNil(MonitorForm);
  RootPanel := nil;
  HeaderPanel := nil;
  ToolBar := nil;
  ButtonWave := nil;
  ButtonSpectrum := nil;
  ButtonBase := nil;
  ButtonPreset := nil;
  StateLabel := nil;
  PanelWave := nil;
  PanelSpectrum := nil;
  PanelBase := nil;
  PanelPreset := nil;
  BasePanel := nil;
  PresetPanel := nil;
  InfoLabel := nil;
  WavePaintBox := nil;
  SpectrumPaintBox := nil;
  TimerTarget := nil;
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
