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
  Aul2AudioControllerBitCrusherGraph,
  Aul2AudioControllerCompressorGraph,
  Aul2AudioControllerDelayGraph,
  Aul2AudioControllerDistortionGraph,
  Aul2AudioControllerEqGraph,
  Aul2AudioControllerEffectDefinition,
  Aul2AudioControllerLampSwitch,
  Aul2AudioControllerLimiterGraph,
  Aul2AudioControllerMuffleGraph,
  Aul2AudioControllerNoiseGateGraph,
  Aul2AudioControllerOutputGraph,
  Aul2AudioControllerPitchGraph,
  Aul2AudioControllerRingModGraph,
  Aul2AudioControllerWhisperGraph,
  Aul2AudioControllerSync,
  Aul2AudioControllerVolumeControl,
  Aul2AudioBasePanel,
  Aul2AudioPresetPanel,
  Aul2AudioMonitorShared,
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioPitchSpectrumShared,
  Aul2AudioRingModSpectrumShared;

const
  CONTROLLER_PRESET_ITEM_INDEX = CONTROLLER_EFFECT_COUNT;
  CONTROLLER_PRESET_ITEM_NAME  = 'エフェクトプリセットの管理';
  CONTROLLER_BASE_ITEM_INDEX   = CONTROLLER_EFFECT_COUNT + 1;
  CONTROLLER_BASE_ITEM_NAME    = '波形表示オブジェクトの配置';
  CONTROLLER_IDLE_BACKGROUND_COLOR = TColor($00292624); // RGB(36, 38, 41)
  CONTROLLER_IDLE_TEXT_COLOR       = TColor($0078CDE8); // RGB(232, 205, 120)

type
  TControlAccess = class(TControl);

  TEffectComboBox = class(TComboBox)
  protected
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
  end;

  TRoundedPanel = class(TPanel)
  private
    procedure UpdateRoundedRegion;
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
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
  SyncMessageLabel: TLabel;
  StatusLabel    : TLabel;
  EffectCombo    : TEffectComboBox;
  LampSwitchHost : TPanel;
  UseLamp        : TAul2LampSwitch;
  UseDescriptionHost: TRoundedPanel;
  UseDescriptionLabel: TLabel;
  ModeHost       : TRoundedPanel;
  ModeLabel      : TLabel;
  ModeCombo      : TComboBox;
  DelayGraph     : TAul2ControllerDelayGraph;
  EqGraph        : TAul2ControllerEqGraph;
  CompressorGraph: TAul2ControllerCompressorGraph;
  DistortionGraph: TAul2ControllerDistortionGraph;
  BitCrusherGraph: TAul2ControllerBitCrusherGraph;
  NoiseGateGraph  : TAul2ControllerNoiseGateGraph;
  LimiterGraph    : TAul2ControllerLimiterGraph;
  OutputGraph     : TAul2ControllerOutputGraph;
  MuffleGraph     : TAul2ControllerMuffleGraph;
  PitchGraph      : TAul2ControllerPitchGraph;
  RingModGraph    : TAul2ControllerRingModGraph;
  WhisperGraph    : TAul2ControllerWhisperGraph;
  MonitorMemory   : TAul2AudioMonitorSharedMemory;
  SpectrumMemory  : TAul2AudioMonitorSpectrumSharedMemory;
  PitchSpectrumMemory: TAul2AudioPitchSpectrumSharedMemory;
  RingSpectrumMemory: TAul2AudioRingSpectrumSharedMemory;
  VolumeControls : array[0..CONTROLLER_MAX_VOLUME_COUNT - 1] of TAul2VolumeControl;
  MouseTimer     : TTimer;
  EventTarget    : TControllerEventTarget;
  MouseInside    : Boolean;
  Refreshing     : Boolean;
  LastUse        : Boolean;
  LastSelectIndex: Integer;
  ControllerSynchronized: Boolean;

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

procedure TRoundedPanel.UpdateRoundedRegion;
var
  Region: HRGN;
begin
  if not HandleAllocated or (ClientWidth <= 1) or (ClientHeight <= 1) then
    Exit;
  Region := CreateRoundRectRgn(0, 0, ClientWidth + 1, ClientHeight + 1, 7, 7);
  if SetWindowRgn(Handle, Region, True) = 0 then
    DeleteObject(Region);
end;

procedure TRoundedPanel.CreateWnd;
begin
  inherited;
  UpdateRoundedRegion;
end;

procedure TRoundedPanel.Resize;
begin
  inherited;
  UpdateRoundedRegion;
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
  UseDescriptionHost.Color := Definition.VolumeColor;
  UseDescriptionLabel.Color := Definition.VolumeColor;
  UseDescriptionLabel.Font.Color := Definition.TextColor;
  ModeHost.Color := Definition.VolumeColor;
  ModeLabel.Color := Definition.VolumeColor;
  ModeLabel.Font.Color := Definition.TextColor;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
  begin
    VolumeControls[ControlIndex].Color := ThemeColor;
    VolumeControls[ControlIndex].PanelColor := Definition.VolumeColor;
    VolumeControls[ControlIndex].AccentColor := Definition.IndicatorColor;
    VolumeControls[ControlIndex].TextColor := Definition.TextColor;
  end;
  if Assigned(DelayGraph) then
    DelayGraph.AccentColor := Definition.IndicatorColor;
  if Assigned(EqGraph) then
    EqGraph.AccentColor := Definition.IndicatorColor;
  if Assigned(CompressorGraph) then
    CompressorGraph.AccentColor := Definition.IndicatorColor;
  if Assigned(DistortionGraph) then
    DistortionGraph.AccentColor := Definition.IndicatorColor;
  if Assigned(BitCrusherGraph) then
    BitCrusherGraph.AccentColor := Definition.IndicatorColor;
  if Assigned(NoiseGateGraph) then
    NoiseGateGraph.AccentColor := Definition.IndicatorColor;
  if Assigned(LimiterGraph) then
    LimiterGraph.AccentColor := Definition.IndicatorColor;
  if Assigned(MuffleGraph) then
    MuffleGraph.AccentColor := Definition.IndicatorColor;
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

procedure UpdateDelayGraph(ChangedIndex: Integer = -1; const ChangedValueText: string = '');
var
  Feedback: Double;
  Dry     : Double;
  TimeMs  : Double;
  Values  : array[0..3] of Double;
  Wet     : Double;
  Index   : Integer;
begin
  if not Assigned(DelayGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 0) then
    Exit;

  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);

  TimeMs := Values[0];
  Dry := Values[1];
  Wet := Values[2];
  Feedback := Values[3];
  DelayGraph.SetDelay(TimeMs, Dry, Wet, Feedback,
    Assigned(ModeCombo) and (ModeCombo.ItemIndex = 1),
    Assigned(UseLamp) and UseLamp.Checked);
end;

procedure UpdateEqGraph(ChangedIndex: Integer = -1; const ChangedValueText: string = '');
var
  HighCutHz: Double;
  Index    : Integer;
  LowCutHz : Double;
  Mix      : Double;
  Values   : array[0..2] of Double;
begin
  if not Assigned(EqGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 1) then
    Exit;

  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);

  LowCutHz := Values[0];
  HighCutHz := Values[1];
  Mix := Values[2];
  EqGraph.SetEq(ModeCombo.ItemIndex, LowCutHz, HighCutHz, Mix,
    Assigned(UseLamp) and UseLamp.Checked);
end;

procedure UpdateCompressorGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Index : Integer;
  Values: array[0..5] of Double;
begin
  if not Assigned(CompressorGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 2) then
    Exit;

  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);

  CompressorGraph.SetCompressor(Values[0], Values[1], Values[2], Values[3],
    Values[4], Values[5], Assigned(UseLamp) and UseLamp.Checked);
end;

procedure UpdateDistortionGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Index : Integer;
  Values: array[0..3] of Double;
begin
  if not Assigned(DistortionGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 4) then
    Exit;

  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);

  DistortionGraph.SetDistortion(ModeCombo.ItemIndex, Values[0], Values[1],
    Values[2], Values[3], Assigned(UseLamp) and UseLamp.Checked);
end;

procedure UpdateBitCrusherGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Index : Integer;
  Values: array[0..2] of Double;
begin
  if not Assigned(BitCrusherGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 6) then
    Exit;

  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);

  BitCrusherGraph.SetBitCrusher(Values[0], Values[1], Values[2],
    Assigned(UseLamp) and UseLamp.Checked);
end;

procedure UpdateNoiseGateGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Index : Integer;
  Values: array[0..3] of Double;
begin
  if not Assigned(NoiseGateGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 14) then
    Exit;

  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);

  NoiseGateGraph.SetNoiseGate(Values[0], Values[1], Values[2], Values[3],
    Assigned(UseLamp) and UseLamp.Checked);
end;

procedure UpdateLimiterGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Index : Integer;
  Values: array[0..2] of Double;
begin
  if not Assigned(LimiterGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 19) then
    Exit;

  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);

  LimiterGraph.SetLimiter(Values[0], Values[1], Values[2],
    Assigned(UseLamp) and UseLamp.Checked);
end;

function MuffleSpectrumStateUsable(State: PAul2AudioMonitorSpectrumState;
  Layer: Integer): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) and
    (State^.Version = AUDIO_MONITOR_SPECTRUM_SHARED_VERSION) and
    (State^.SourceLayer = Layer) and (State^.BandCount > 0) and
    (State^.UpdateTick > 0);
end;

function PitchSpectrumStateUsable(State: PAul2AudioPitchSpectrumState;
  Layer: Integer): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_PITCH_SPECTRUM_SHARED_MAGIC) and
    (State^.Version = AUDIO_PITCH_SPECTRUM_SHARED_VERSION) and
    (State^.SourceLayer = Layer) and (State^.BandCount > 0) and
    (State^.UpdateTick > 0);
end;

function RingSpectrumStateUsable(State: PAul2AudioRingSpectrumState;
  Layer: Integer): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_RING_SPECTRUM_SHARED_MAGIC) and
    (State^.Version = AUDIO_RING_SPECTRUM_SHARED_VERSION) and
    (State^.SourceLayer = Layer) and (State^.BandCount > 0) and
    (State^.UpdateTick > 0);
end;

procedure UpdatePitchGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Fraction: Double;
  Index: Integer;
  Layer: Integer;
  MonitorIndex: Integer;
  MonitorNext: Integer;
  MonitorPosition: Double;
  MonitorState: PAul2AudioMonitorSpectrumState;
  PitchInput: TAudioPitchSpectrumData;
  PitchOutput: TAudioPitchSpectrumData;
  State: PAul2AudioPitchSpectrumState;
  Values: array[0..6] of Double;
begin
  if not Assigned(PitchGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 9) then
    Exit;
  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);
  PitchGraph.SetPitch(ModeCombo.ItemIndex, Values[0], Values[2], Values[4],
    Values[6], Assigned(UseLamp) and UseLamp.Checked);

  if not CaptureSelectedObjectLayer(Layer) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
  begin
    PitchGraph.ClearSpectrum;
    Exit;
  end;
  State := nil;
  // OFF時は以前の専用解析値を残さず、常に現在のMonitor値を使う。
  if Assigned(UseLamp) and UseLamp.Checked and
     Assigned(PitchSpectrumMemory) then
  begin
    State := PitchSpectrumMemory.GetStateForLayer(Layer);
    if not PitchSpectrumStateUsable(State, Layer) then
    begin
      State := PitchSpectrumMemory.State;
      if State <> nil then
        Layer := State^.SourceLayer;
    end;
  end;
  if Assigned(UseLamp) and UseLamp.Checked and
     PitchSpectrumStateUsable(State, Layer) then
  begin
    PitchGraph.SetSpectrum(State^.InputBands, State^.OutputBands,
      State^.BandCount, State^.MinHz, State^.MaxHz);
    Exit;
  end;

  // PitchがOFFまたは専用解析前なら、Monitorの64バンドを128バンドへ
  // 線形補間して初期表示する。専用値が得られた後は上の経路へ切り替わる。
  MonitorState := nil;
  if Assigned(SpectrumMemory) then
    MonitorState := SpectrumMemory.GetStateForLayer(Layer);
  if not MuffleSpectrumStateUsable(MonitorState, Layer) and
     Assigned(SpectrumMemory) then
  begin
    MonitorState := SpectrumMemory.State;
    if MonitorState <> nil then
      Layer := MonitorState^.SourceLayer;
  end;
  if not MuffleSpectrumStateUsable(MonitorState, Layer) then
  begin
    PitchGraph.ClearSpectrum;
    Exit;
  end;
  for Index := 0 to AUDIO_PITCH_SPECTRUM_BAND_LAST do
  begin
    MonitorPosition := Index * (MonitorState^.BandCount - 1) /
      Max(1, AUDIO_PITCH_SPECTRUM_BAND_COUNT - 1);
    MonitorIndex := EnsureRange(Floor(MonitorPosition), 0,
      MonitorState^.BandCount - 1);
    MonitorNext := Min(MonitorState^.BandCount - 1, MonitorIndex + 1);
    Fraction := MonitorPosition - MonitorIndex;
    PitchInput[Index] := MonitorState^.InputBands[MonitorIndex] *
      (1.0 - Fraction) + MonitorState^.InputBands[MonitorNext] * Fraction;
    PitchOutput[Index] := MonitorState^.OutputBands[MonitorIndex] *
      (1.0 - Fraction) + MonitorState^.OutputBands[MonitorNext] * Fraction;
  end;
  PitchGraph.SetSpectrum(PitchInput, PitchOutput,
    AUDIO_PITCH_SPECTRUM_BAND_COUNT, MonitorState^.MinHz,
    MonitorState^.MaxHz);
end;

procedure UpdateRingModGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Fraction, MonitorPosition: Double;
  Index, Layer, MonitorIndex, MonitorNext: Integer;
  MonitorState: PAul2AudioMonitorSpectrumState;
  RingInput, RingOutput: TAudioRingSpectrumData;
  State: PAul2AudioRingSpectrumState;
  Values: array[0..2] of Double;
begin
  if not Assigned(RingModGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 10) then Exit;
  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then Values[Index] := VolumeControls[Index].Value
    else Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);
  RingModGraph.SetRingMod(Values[0], Values[1], Values[2],
    Assigned(UseLamp) and UseLamp.Checked);
  if not CaptureSelectedObjectLayer(Layer) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
  begin
    RingModGraph.ClearSpectrum;
    Exit;
  end;
  State := nil;
  if Assigned(UseLamp) and UseLamp.Checked and Assigned(RingSpectrumMemory) then
  begin
    State := RingSpectrumMemory.GetStateForLayer(Layer);
    if not RingSpectrumStateUsable(State, Layer) then
    begin
      State := RingSpectrumMemory.State;
      if State <> nil then Layer := State^.SourceLayer;
    end;
  end;
  if Assigned(UseLamp) and UseLamp.Checked and RingSpectrumStateUsable(State, Layer) then
  begin
    RingModGraph.SetSpectrum(State^.InputBands, State^.OutputBands,
      State^.BandCount, State^.MinHz, State^.MaxHz);
    Exit;
  end;
  MonitorState := nil;
  if Assigned(SpectrumMemory) then MonitorState := SpectrumMemory.GetStateForLayer(Layer);
  if not MuffleSpectrumStateUsable(MonitorState, Layer) and Assigned(SpectrumMemory) then
  begin
    MonitorState := SpectrumMemory.State;
    if MonitorState <> nil then Layer := MonitorState^.SourceLayer;
  end;
  if not MuffleSpectrumStateUsable(MonitorState, Layer) then
  begin
    RingModGraph.ClearSpectrum;
    Exit;
  end;
  for Index := 0 to AUDIO_RING_SPECTRUM_BAND_LAST do
  begin
    MonitorPosition := Index * (MonitorState^.BandCount - 1) /
      Max(1, AUDIO_RING_SPECTRUM_BAND_COUNT - 1);
    MonitorIndex := EnsureRange(Floor(MonitorPosition), 0, MonitorState^.BandCount - 1);
    MonitorNext := Min(MonitorState^.BandCount - 1, MonitorIndex + 1);
    Fraction := MonitorPosition - MonitorIndex;
    RingInput[Index] := MonitorState^.InputBands[MonitorIndex] * (1.0 - Fraction) +
      MonitorState^.InputBands[MonitorNext] * Fraction;
    RingOutput[Index] := MonitorState^.OutputBands[MonitorIndex] * (1.0 - Fraction) +
      MonitorState^.OutputBands[MonitorNext] * Fraction;
  end;
  RingModGraph.SetSpectrum(RingInput, RingOutput,
    AUDIO_RING_SPECTRUM_BAND_COUNT, MonitorState^.MinHz, MonitorState^.MaxHz);
end;

procedure UpdateWhisperGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Index, Layer: Integer;
  MonitorState: PAul2AudioMonitorSpectrumState;
  Values: array[0..2] of Double;
begin
  if not Assigned(WhisperGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 12) then Exit;
  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then Values[Index] := VolumeControls[Index].Value
    else Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);
  WhisperGraph.SetWhisper(Values[0], Values[1], Values[2],
    Assigned(UseLamp) and UseLamp.Checked);
  if not CaptureSelectedObjectLayer(Layer) or (Layer < 0) or
     (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
  begin WhisperGraph.ClearSpectrum; Exit; end;
  MonitorState := nil;
  if Assigned(SpectrumMemory) then MonitorState := SpectrumMemory.GetStateForLayer(Layer);
  if not MuffleSpectrumStateUsable(MonitorState, Layer) and Assigned(SpectrumMemory) then
  begin
    MonitorState := SpectrumMemory.State;
    if MonitorState <> nil then Layer := MonitorState^.SourceLayer;
  end;
  if not MuffleSpectrumStateUsable(MonitorState, Layer) then
  begin WhisperGraph.ClearSpectrum; Exit; end;
  WhisperGraph.SetSpectrum(MonitorState^.InputBands, MonitorState^.BandCount,
    MonitorState^.MinHz, MonitorState^.MaxHz);
end;

procedure UpdateMuffleGraph(ChangedIndex: Integer = -1;
  const ChangedValueText: string = '');
var
  Index : Integer;
  Layer : Integer;
  State : PAul2AudioMonitorSpectrumState;
  Values: array[0..2] of Double;
begin
  if not Assigned(MuffleGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 11) then
    Exit;

  for Index := Low(Values) to High(Values) do
    if Assigned(VolumeControls[Index]) then
      Values[Index] := VolumeControls[Index].Value
    else
      Values[Index] := 0;
  if (ChangedIndex >= Low(Values)) and (ChangedIndex <= High(Values)) then
    TryStrToFloat(ChangedValueText, Values[ChangedIndex], FormatSettings);

  MuffleGraph.SetMuffle(Values[0], Values[1], Values[2],
    Assigned(UseLamp) and UseLamp.Checked);
  if not Assigned(SpectrumMemory) or not CaptureSelectedObjectLayer(Layer) or
     (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
  begin
    MuffleGraph.ClearSpectrum;
    Exit;
  end;

  State := SpectrumMemory.GetStateForLayer(Layer);
  if not MuffleSpectrumStateUsable(State, Layer) then
  begin
    State := SpectrumMemory.State;
    if State <> nil then
      Layer := State^.SourceLayer;
    if not MuffleSpectrumStateUsable(State, Layer) then
    begin
      MuffleGraph.ClearSpectrum;
      Exit;
    end;
  end;

  MuffleGraph.SetSpectrum(State^.InputBands, State^.OutputBands,
    State^.BandCount, State^.MinHz, State^.MaxHz);
end;

function OutputMonitorStateUsable(State: PAul2AudioMonitorState;
  Layer: Integer): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_MONITOR_SHARED_MAGIC) and
    (State^.Version = AUDIO_MONITOR_SHARED_VERSION) and
    (State^.SourceLayer = Layer) and (State^.SampleNum > 0) and
    (State^.UpdateTick > 0);
end;

procedure UpdateOutputGraph;
var
  HistoryIndex: Integer;
  HistorySlot : Integer;
  InputRmsL   : TControllerOutputHistory;
  InputRmsR   : TControllerOutputHistory;
  Layer       : Integer;
  OutputRmsL  : TControllerOutputHistory;
  OutputRmsR  : TControllerOutputHistory;
  Root        : PAul2AudioMonitorLayeredState;
  State       : PAul2AudioMonitorState;
  ValidCount  : Integer;
begin
  if not Assigned(OutputGraph) or not Assigned(EffectCombo) or
     (EffectCombo.ItemIndex <> 18) then
    Exit;

  OutputGraph.SetActive(Assigned(UseLamp) and UseLamp.Checked);
  if not Assigned(MonitorMemory) or not CaptureSelectedObjectLayer(Layer) or
     (Layer < 0) or (Layer > AUDIO_MONITOR_LAYER_SLOT_LAST) then
  begin
    OutputGraph.ClearData;
    Exit;
  end;

  Root := MonitorMemory.Root;
  if (Root = nil) or (Root^.Magic <> AUDIO_MONITOR_SHARED_MAGIC) or
     (Root^.Version <> AUDIO_MONITOR_SHARED_VERSION) then
  begin
    OutputGraph.ClearData;
    Exit;
  end;

  State := MonitorMemory.GetStateForLayer(Layer);
  if not OutputMonitorStateUsable(State, Layer) then
  begin
    // グループ制御（音声）を選択している場合、選択Objectのレイヤーと
    // 実際に処理された音声レイヤーは一致しない。Monitorと同じく、
    // 最後に更新された有効レイヤーへフォールバックする。
    State := MonitorMemory.State;
    if State <> nil then
      Layer := State^.SourceLayer;
    if not OutputMonitorStateUsable(State, Layer) then
    begin
      OutputGraph.ClearData;
      Exit;
    end;
  end;

  FillChar(InputRmsL, SizeOf(InputRmsL), 0);
  FillChar(InputRmsR, SizeOf(InputRmsR), 0);
  FillChar(OutputRmsL, SizeOf(OutputRmsL), 0);
  FillChar(OutputRmsR, SizeOf(OutputRmsR), 0);
  ValidCount := 0;
  for HistoryIndex := 0 to CONTROLLER_OUTPUT_HISTORY_COUNT - 1 do
  begin
    HistorySlot := (Root^.HistoryIndex[Layer] -
      CONTROLLER_OUTPUT_HISTORY_COUNT + HistoryIndex +
      AUDIO_MONITOR_HISTORY_COUNT) mod AUDIO_MONITOR_HISTORY_COUNT;
    State := MonitorMemory.GetHistoryStateForLayer(Layer, HistorySlot);
    if not OutputMonitorStateUsable(State, Layer) then
      Continue;
    InputRmsL[ValidCount] := State^.InputRmsL;
    InputRmsR[ValidCount] := State^.InputRmsR;
    OutputRmsL[ValidCount] := State^.OutputRmsL;
    OutputRmsR[ValidCount] := State^.OutputRmsR;
    Inc(ValidCount);
  end;

  State := MonitorMemory.GetStateForLayer(Layer);
  if ValidCount = 0 then
  begin
    InputRmsL[0] := State^.InputRmsL;
    InputRmsR[0] := State^.InputRmsR;
    OutputRmsL[0] := State^.OutputRmsL;
    OutputRmsR[0] := State^.OutputRmsR;
    ValidCount := 1;
  end;
  OutputGraph.SetMonitorData(State^.InputPeakL, State^.InputPeakR,
    State^.OutputPeakL, State^.OutputPeakR, InputRmsL, InputRmsR,
    OutputRmsL, OutputRmsR, ValidCount);
end;

procedure UpdateEffectGraph(ChangedIndex: Integer = -1; const ChangedValueText: string = '');
begin
  UpdateDelayGraph(ChangedIndex, ChangedValueText);
  UpdateEqGraph(ChangedIndex, ChangedValueText);
  UpdateCompressorGraph(ChangedIndex, ChangedValueText);
  UpdateDistortionGraph(ChangedIndex, ChangedValueText);
  UpdateBitCrusherGraph(ChangedIndex, ChangedValueText);
  UpdateNoiseGateGraph(ChangedIndex, ChangedValueText);
  UpdateLimiterGraph(ChangedIndex, ChangedValueText);
  UpdatePitchGraph(ChangedIndex, ChangedValueText);
  UpdateRingModGraph(ChangedIndex, ChangedValueText);
  UpdateWhisperGraph(ChangedIndex, ChangedValueText);
  UpdateMuffleGraph(ChangedIndex, ChangedValueText);
  UpdateOutputGraph;
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
  GraphHeight : Integer;
  GraphLeft   : Integer;
  GraphTop    : Integer;
  GraphWidth  : Integer;
  LabelWidth  : Integer;
  LeftMargin  : Integer;
  RowCount    : Integer;
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

  EffectCombo.SetBounds(LeftMargin, Scale(6), ContentWidth, Scale(27));
  DelayGraph.Visible := False;
  EqGraph.Visible := False;
  CompressorGraph.Visible := False;
  DistortionGraph.Visible := False;
  BitCrusherGraph.Visible := False;
  NoiseGateGraph.Visible := False;
  LimiterGraph.Visible := False;
  OutputGraph.Visible := False;
  MuffleGraph.Visible := False;
  PitchGraph.Visible := False;
  RingModGraph.Visible := False;
  WhisperGraph.Visible := False;
  SyncMessageLabel.SetBounds(LeftMargin, Scale(42), ContentWidth,
    Max(Scale(72), RootPanel.ClientHeight - Scale(54)));
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
  UseLamp.SetBounds(0, 0, Scale(76), Scale(28));
  UseDescriptionHost.SetBounds(Scale(86), 0,
    Max(1, ContentWidth - Scale(86)), Scale(28));
  UseDescriptionLabel.SetBounds(Scale(8), Scale(3),
    Max(1, UseDescriptionHost.ClientWidth - Scale(16)), Scale(22));

  TopPosition := Scale(69);
  if ModeHost.Visible then
  begin
    ModeHost.SetBounds(LeftMargin, TopPosition, ContentWidth, Scale(33));
    ModeLabel.SetBounds(Scale(8), Scale(5), LabelWidth - Scale(8), Scale(23));
    ModeCombo.SetBounds(LabelWidth, Scale(4),
      Max(1, ContentWidth - LabelWidth - Scale(4)), Scale(25));
    Inc(TopPosition, RowHeight);
  end;

  VisibleControlCount := 0;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
    if VolumeControls[ControlIndex].Visible then
      Inc(VisibleControlCount);
  if VisibleControlCount = 0 then
    Exit;

  ControlGap := Scale(6);
  // ノブ描画の103pxは固定し、DPIで高くなる値欄の分だけカードを下へ延ばす。
  ControlHeight := 103 + Scale(23);
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

  RowCount := (VisibleControlCount + ColumnCount - 1) div ColumnCount;
  GraphTop := TopPosition + RowCount * ControlHeight +
    Max(0, RowCount - 1) * ControlGap + Scale(10);
  GraphWidth := Min(Scale(300), ContentWidth);
  GraphHeight := Scale(150);
  GraphLeft := LeftMargin + (ContentWidth - GraphWidth) div 2;
  if ControllerSynchronized and (EffectCombo.ItemIndex in [0, 1, 2, 4, 6, 9, 10, 11, 12, 14, 18, 19]) and
     (GraphWidth >= Scale(180)) and
     (GraphTop + GraphHeight + Scale(6) <= RootPanel.ClientHeight) then
  begin
    if EffectCombo.ItemIndex = 0 then
    begin
      DelayGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      DelayGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 1 then
    begin
      EqGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      EqGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 2 then
    begin
      CompressorGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      CompressorGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 4 then
    begin
      DistortionGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      DistortionGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 6 then
    begin
      BitCrusherGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      BitCrusherGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 14 then
    begin
      NoiseGateGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      NoiseGateGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 9 then
    begin
      PitchGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      PitchGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 10 then
    begin
      RingModGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      RingModGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 11 then
    begin
      MuffleGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      MuffleGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 12 then
    begin
      WhisperGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      WhisperGraph.Visible := True;
    end
    else if EffectCombo.ItemIndex = 18 then
    begin
      OutputGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      OutputGraph.Visible := True;
    end
    else
    begin
      LimiterGraph.SetBounds(GraphLeft, GraphTop, GraphWidth, GraphHeight);
      LimiterGraph.Visible := True;
    end;
  end;
end;

procedure ConfigureCurrentEffect; forward;

procedure ShowUnsynchronizedState;
var
  ControlIndex: Integer;
begin
  ControllerSynchronized := False;
  ControllerForm.Color := CONTROLLER_IDLE_BACKGROUND_COLOR;
  RootPanel.Color := CONTROLLER_IDLE_BACKGROUND_COLOR;
  EffectCombo.Visible := True;
  LampSwitchHost.Visible := False;
  ModeHost.Visible := False;
  BasePanel.Visible := False;
  PresetPanel.Visible := False;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
    VolumeControls[ControlIndex].Visible := False;
  DelayGraph.Visible := False;
  EqGraph.Visible := False;
  CompressorGraph.Visible := False;
  DistortionGraph.Visible := False;
  BitCrusherGraph.Visible := False;
  NoiseGateGraph.Visible := False;
  LimiterGraph.Visible := False;
  OutputGraph.Visible := False;
  MuffleGraph.Visible := False;
  PitchGraph.Visible := False;
  RingModGraph.Visible := False;
  WhisperGraph.Visible := False;
  SyncMessageLabel.Visible := True;
  SyncMessageLabel.BringToFront;
end;

procedure ShowSynchronizedState;
begin
  if ControllerSynchronized then
    Exit;
  ControllerSynchronized := True;
  SyncMessageLabel.Visible := False;
  EffectCombo.Visible := True;
  ConfigureCurrentEffect;
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
  UseDescriptionHost.Invalidate;
  UseDescriptionLabel.Invalidate;
  ModeHost.Invalidate;
  ModeLabel.Invalidate;
  ModeCombo.Invalidate;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
    VolumeControls[ControlIndex].Invalidate;
  DelayGraph.Invalidate;
  EqGraph.Invalidate;
  CompressorGraph.Invalidate;
  DistortionGraph.Invalidate;
  BitCrusherGraph.Invalidate;
  NoiseGateGraph.Invalidate;
  LimiterGraph.Invalidate;
  OutputGraph.Invalidate;
  MuffleGraph.Invalidate;
  PitchGraph.Invalidate;
  RingModGraph.Invalidate;
  WhisperGraph.Invalidate;
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
      ControllerSynchronized := False;
      SyncMessageLabel.Visible := False;
      LampSwitchHost.Visible := False;
      ModeHost.Visible := False;
      for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
        VolumeControls[ControlIndex].Visible := False;
      DelayGraph.Visible := False;
      EqGraph.Visible := False;
      CompressorGraph.Visible := False;
      DistortionGraph.Visible := False;
      BitCrusherGraph.Visible := False;
      NoiseGateGraph.Visible := False;
      LimiterGraph.Visible := False;
      OutputGraph.Visible := False;
      MuffleGraph.Visible := False;
      PitchGraph.Visible := False;
      RingModGraph.Visible := False;
      WhisperGraph.Visible := False;
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
      ControllerSynchronized := False;
      SyncMessageLabel.Visible := False;
      LampSwitchHost.Visible := False;
      ModeHost.Visible := False;
      for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
        VolumeControls[ControlIndex].Visible := False;
      DelayGraph.Visible := False;
      EqGraph.Visible := False;
      CompressorGraph.Visible := False;
      DistortionGraph.Visible := False;
      BitCrusherGraph.Visible := False;
      NoiseGateGraph.Visible := False;
      LimiterGraph.Visible := False;
      OutputGraph.Visible := False;
      MuffleGraph.Visible := False;
      PitchGraph.Visible := False;
      RingModGraph.Visible := False;
      WhisperGraph.Visible := False;
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
    UseDescriptionLabel.Caption := Definition.LampCaption;
    UseLamp.Enabled := Definition.UseItemName <> '';
    ModeLabel.Caption := Definition.SelectControl.DisplayName;
    ModeHost.Visible := Definition.SelectControl.Visible;
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
      ShowSynchronizedState;
      // ConfigureCurrentEffect が変更した更新抑止状態を、読込処理中へ戻す。
      Refreshing := True;
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
      UpdateEffectGraph;
      LayoutControllerView;
      StatusLabel.Caption := Definition.DisplayName + ' loaded';
      StatusLabel.Font.Color := RGB(112, 232, 142);
    end
    else
    begin
      ApplyEmptyEffectState;
      ShowUnsynchronizedState;
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
  begin
    LastUse := UseLamp.Checked;
    UpdateEffectGraph;
  end
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
  begin
    LastSelectIndex := ModeCombo.ItemIndex;
    UpdateEffectGraph;
  end
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
  if Accept then
    UpdateEffectGraph(ControlIndex, ValueText);
  ShowWriteStatus(Accept, ItemName);
end;

procedure TControllerEventTarget.EffectComboChange(Sender: TObject);
begin
  if not Assigned(EffectCombo) or (EffectCombo.ItemIndex < 0) then
    Exit;
  StatusLabel.Caption := 'Selected: ' + EffectCombo.Items[EffectCombo.ItemIndex];
  StatusLabel.Font.Color := RGB(112, 180, 232);
  StatusLabel.Invalidate;
  if IsBasePanelSelected or IsPresetPanelSelected then
    ConfigureCurrentEffect
  else
  begin
    ShowUnsynchronizedState;
    LayoutControllerView;
    RefreshEffectState;
  end;
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

  CreateLabel(SyncMessageLabel,
    'エフェクタープラグインを追加した音声オブジェクト、または' + sLineBreak +
    'グループ制御（音声）を選択してください');
  SyncMessageLabel.Alignment := taCenter;
  SyncMessageLabel.Layout := tlCenter;
  SyncMessageLabel.WordWrap := True;
  SyncMessageLabel.Font.Color := CONTROLLER_IDLE_TEXT_COLOR;
  RegisterMouseEnter(SyncMessageLabel);

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
  UseLamp.Font.Assign(ControllerForm.Font);
  UseLamp.OnClick := EventTarget.UseLampClick;
  UseLamp.Parent := LampSwitchHost;
  RegisterMouseEnter(UseLamp);

  UseDescriptionHost := TRoundedPanel.Create(ControllerForm);
  UseDescriptionHost.BevelOuter := bvNone;
  UseDescriptionHost.Caption := '';
  UseDescriptionHost.Color := RGB(34, 37, 41);
  UseDescriptionHost.ParentBackground := False;
  UseDescriptionHost.Parent := LampSwitchHost;
  RegisterMouseEnter(UseDescriptionHost);

  CreateLabel(UseDescriptionLabel, '遅延音を加える');
  UseDescriptionLabel.Parent := UseDescriptionHost;
  UseDescriptionLabel.AutoSize := False;
  UseDescriptionLabel.Layout := tlCenter;
  UseDescriptionLabel.Font.Assign(ControllerForm.Font);
  UseDescriptionLabel.Font.Height := UseDescriptionLabel.Font.Height - Scale(2);

  ModeHost := TRoundedPanel.Create(ControllerForm);
  ModeHost.BevelOuter := bvNone;
  ModeHost.Caption := '';
  ModeHost.Color := RGB(34, 37, 41);
  ModeHost.ParentBackground := False;
  ModeHost.Parent := RootPanel;
  RegisterMouseEnter(ModeHost);

  CreateLabel(ModeLabel, 'Stereo Mode');
  ModeLabel.Parent := ModeHost;
  ModeCombo := TComboBox.Create(ControllerForm);
  ModeCombo.Style := csDropDownList;
  ModeCombo.Color := RGB(42, 45, 49);
  ModeCombo.Font.Assign(ControllerForm.Font);
  ModeCombo.Font.Color := RGB(250, 250, 250);
  ModeCombo.ParentFont := False;
  ModeCombo.Parent := ModeHost;
  ModeCombo.Items.Add('Normal');
  ModeCombo.Items.Add('Ping-Pong');
  ModeCombo.ItemIndex := 0;
  ModeCombo.Enabled := True;
  ModeCombo.TabStop := False;
  ModeCombo.OnChange := EventTarget.ModeComboChange;
  ApplyDarkComboStyle(ModeCombo);
  RegisterMouseEnter(ModeCombo);

  DelayGraph := TAul2ControllerDelayGraph.Create(ControllerForm);
  DelayGraph.Font.Assign(ControllerForm.Font);
  DelayGraph.Parent := RootPanel;
  DelayGraph.Visible := False;
  RegisterMouseEnter(DelayGraph);

  EqGraph := TAul2ControllerEqGraph.Create(ControllerForm);
  EqGraph.Font.Assign(ControllerForm.Font);
  EqGraph.Parent := RootPanel;
  EqGraph.Visible := False;
  RegisterMouseEnter(EqGraph);

  CompressorGraph := TAul2ControllerCompressorGraph.Create(ControllerForm);
  CompressorGraph.Font.Assign(ControllerForm.Font);
  CompressorGraph.Parent := RootPanel;
  CompressorGraph.Visible := False;
  RegisterMouseEnter(CompressorGraph);

  DistortionGraph := TAul2ControllerDistortionGraph.Create(ControllerForm);
  DistortionGraph.Font.Assign(ControllerForm.Font);
  DistortionGraph.Parent := RootPanel;
  DistortionGraph.Visible := False;
  RegisterMouseEnter(DistortionGraph);

  BitCrusherGraph := TAul2ControllerBitCrusherGraph.Create(ControllerForm);
  BitCrusherGraph.Font.Assign(ControllerForm.Font);
  BitCrusherGraph.Parent := RootPanel;
  BitCrusherGraph.Visible := False;
  RegisterMouseEnter(BitCrusherGraph);

  NoiseGateGraph := TAul2ControllerNoiseGateGraph.Create(ControllerForm);
  NoiseGateGraph.Font.Assign(ControllerForm.Font);
  NoiseGateGraph.Parent := RootPanel;
  NoiseGateGraph.Visible := False;
  RegisterMouseEnter(NoiseGateGraph);

  LimiterGraph := TAul2ControllerLimiterGraph.Create(ControllerForm);
  LimiterGraph.Font.Assign(ControllerForm.Font);
  LimiterGraph.Parent := RootPanel;
  LimiterGraph.Visible := False;
  RegisterMouseEnter(LimiterGraph);

  OutputGraph := TAul2ControllerOutputGraph.Create(ControllerForm);
  OutputGraph.Font.Assign(ControllerForm.Font);
  OutputGraph.Parent := RootPanel;
  OutputGraph.Visible := False;
  RegisterMouseEnter(OutputGraph);

  MuffleGraph := TAul2ControllerMuffleGraph.Create(ControllerForm);
  MuffleGraph.Font.Assign(ControllerForm.Font);
  MuffleGraph.Parent := RootPanel;
  MuffleGraph.Visible := False;
  RegisterMouseEnter(MuffleGraph);

  PitchGraph := TAul2ControllerPitchGraph.Create(ControllerForm);
  PitchGraph.Font.Assign(ControllerForm.Font);
  PitchGraph.Parent := RootPanel;
  PitchGraph.Visible := False;
  RegisterMouseEnter(PitchGraph);

  RingModGraph := TAul2ControllerRingModGraph.Create(ControllerForm);
  RingModGraph.Font.Assign(ControllerForm.Font);
  RingModGraph.Parent := RootPanel;
  RingModGraph.Visible := False;
  RegisterMouseEnter(RingModGraph);

  WhisperGraph := TAul2ControllerWhisperGraph.Create(ControllerForm);
  WhisperGraph.Font.Assign(ControllerForm.Font);
  WhisperGraph.Parent := RootPanel;
  WhisperGraph.Visible := False;
  RegisterMouseEnter(WhisperGraph);

  MonitorMemory := TAul2AudioMonitorSharedMemory.Create;
  SpectrumMemory := TAul2AudioMonitorSpectrumSharedMemory.Create;
  PitchSpectrumMemory := TAul2AudioPitchSpectrumSharedMemory.Create;
  RingSpectrumMemory := TAul2AudioRingSpectrumSharedMemory.Create;

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
  ControllerSynchronized := False;

  MouseTimer := TTimer.Create(ControllerForm);
  MouseTimer.Interval := 100;
  MouseTimer.OnTimer := EventTarget.MouseBoundaryTimer;
  MouseTimer.Enabled := True;

  ShowUnsynchronizedState;
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
  FreeAndNil(RingSpectrumMemory);
  FreeAndNil(PitchSpectrumMemory);
  FreeAndNil(SpectrumMemory);
  FreeAndNil(MonitorMemory);
  FreeAndNil(ControllerForm);
  ClientWindow := 0;
  RootPanel := nil;
  BasePanel := nil;
  PresetPanel := nil;
  SyncMessageLabel := nil;
  StatusLabel := nil;
  EffectCombo := nil;
  LampSwitchHost := nil;
  UseLamp := nil;
  UseDescriptionHost := nil;
  UseDescriptionLabel := nil;
  ModeHost := nil;
  ModeLabel := nil;
  ModeCombo := nil;
  DelayGraph := nil;
  EqGraph := nil;
  CompressorGraph := nil;
  DistortionGraph := nil;
  BitCrusherGraph := nil;
  NoiseGateGraph := nil;
  LimiterGraph := nil;
  OutputGraph := nil;
  MuffleGraph := nil;
  PitchGraph := nil;
  RingModGraph := nil;
  WhisperGraph := nil;
  for ControlIndex := Low(VolumeControls) to High(VolumeControls) do
    VolumeControls[ControlIndex] := nil;
  MouseTimer := nil;
  MonitorMemory := nil;
  SpectrumMemory := nil;
  PitchSpectrumMemory := nil;
  RingSpectrumMemory := nil;
  EventTarget := nil;
  MouseInside := False;
  Refreshing := False;
end;

end.
