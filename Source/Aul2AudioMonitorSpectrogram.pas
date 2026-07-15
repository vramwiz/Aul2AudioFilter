unit Aul2AudioMonitorSpectrogram;

// Monitorの処理前/処理後スペクトログラム履歴と描画を担当する。

interface

uses
  System.Types,
  Vcl.Graphics,
  Aul2AudioMonitorSpectrumShared;

// 表示中に蓄積したスペクトログラム履歴を破棄する。
procedure ClearAudioSpectrogramHistory;
// 既存の64バンド解析値を履歴へ追加し、処理前と処理後を上下2段で描画する。
procedure DrawAudioSpectrogramCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorSpectrumState; AdvanceHistory: Boolean);

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils;

const
  SPECTROGRAM_APPEND_INTERVAL_MS = 40; // 再描画が重なっても約20fpsを超えて履歴を追加しない。

type
  TSpectrogramHistory = array[0..AUDIO_MONITOR_SPECTRUM_HISTORY_LAST] of
    TAudioMonitorSpectrumData;
  TRgbQuadRow = array[0..AUDIO_MONITOR_SPECTRUM_HISTORY_LAST] of TRGBQuad;
  PRgbQuadRow = ^TRgbQuadRow;

var
  InputHistory    : TSpectrogramHistory;
  OutputHistory   : TSpectrogramHistory;
  HistoryWriteIndex: Integer;
  HistoryCount    : Integer;
  LastAppendTick  : UInt64;
  LastGeneration  : Int64;
  LastSampleIndex : Int64;
  LastSourceFrame : Integer;
  LastSourceLayer : Integer;
  LastStateValid  : Boolean;

function SpectrumStateValid(State: PAul2AudioMonitorSpectrumState): Boolean;
begin
  Result := (State <> nil) and
    (State^.Magic = AUDIO_MONITOR_SPECTRUM_SHARED_MAGIC) and
    (State^.Version = AUDIO_MONITOR_SPECTRUM_SHARED_VERSION);
end;

function SpectrumStateFresh(State: PAul2AudioMonitorSpectrumState): Boolean;
const
  SPECTRUM_STALE_MS = 2500;
var
  NowTick: UInt64;
begin
  if not SpectrumStateValid(State) or (State^.UpdateTick = 0) then
    Exit(False);

  NowTick := GetTickCount64;
  Result := (NowTick >= State^.UpdateTick) and
    ((NowTick - State^.UpdateTick) <= SPECTRUM_STALE_MS);
end;

function SameSpectrumState(State: PAul2AudioMonitorSpectrumState): Boolean;
begin
  Result := LastStateValid and
    (LastGeneration = State^.Generation) and
    (LastSampleIndex = State^.SampleIndex) and
    (LastSourceFrame = State^.SourceFrame) and
    (LastSourceLayer = State^.SourceLayer);
end;

procedure RememberSpectrumState(State: PAul2AudioMonitorSpectrumState);
begin
  LastGeneration := State^.Generation;
  LastSampleIndex := State^.SampleIndex;
  LastSourceFrame := State^.SourceFrame;
  LastSourceLayer := State^.SourceLayer;
  LastStateValid := True;
end;

procedure AppendSpectrumState(State: PAul2AudioMonitorSpectrumState;
  AdvanceHistory: Boolean);
var
  NowTick: UInt64;
begin
  if not SpectrumStateFresh(State) then
    Exit;

  NowTick := GetTickCount64;
  if AdvanceHistory then
  begin
    if (LastAppendTick <> 0) and (NowTick >= LastAppendTick) and
       ((NowTick - LastAppendTick) < SPECTROGRAM_APPEND_INTERVAL_MS) then
      Exit;
  end
  else if SameSpectrumState(State) then
    Exit;

  InputHistory[HistoryWriteIndex] := State^.InputBands;
  OutputHistory[HistoryWriteIndex] := State^.OutputBands;
  HistoryWriteIndex := (HistoryWriteIndex + 1) mod AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT;
  HistoryCount := Min(HistoryCount + 1, AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT);
  LastAppendTick := NowTick;
  RememberSpectrumState(State);
end;

function BlendChannel(First, Second: Byte; Ratio: Single): Byte;
begin
  Result := EnsureRange(Round(First + (Second - First) * Ratio), 0, 255);
end;

function BlendColor(First, Second: TColor; Ratio: Single): TColor;
var
  FirstRgb : TColor;
  SecondRgb: TColor;
begin
  Ratio := EnsureRange(Ratio, 0.0, 1.0);
  FirstRgb := ColorToRGB(First);
  SecondRgb := ColorToRGB(Second);
  Result := RGB(
    BlendChannel(GetRValue(FirstRgb), GetRValue(SecondRgb), Ratio),
    BlendChannel(GetGValue(FirstRgb), GetGValue(SecondRgb), Ratio),
    BlendChannel(GetBValue(FirstRgb), GetBValue(SecondRgb), Ratio));
end;

function SpectrogramColor(Value: Single): TColor;
begin
  Value := EnsureRange(Value, 0.0, 1.0);
  if Value < 0.22 then
    Result := BlendColor(RGB(5, 7, 12), RGB(22, 39, 116), Value / 0.22)
  else if Value < 0.45 then
    Result := BlendColor(RGB(22, 39, 116), RGB(0, 160, 208), (Value - 0.22) / 0.23)
  else if Value < 0.68 then
    Result := BlendColor(RGB(0, 160, 208), RGB(54, 190, 92), (Value - 0.45) / 0.23)
  else if Value < 0.84 then
    Result := BlendColor(RGB(54, 190, 92), RGB(238, 214, 58), (Value - 0.68) / 0.16)
  else
    Result := BlendColor(RGB(238, 214, 58), RGB(232, 76, 48), (Value - 0.84) / 0.16);
end;

procedure SetQuadColor(var Quad: TRGBQuad; Color: TColor);
var
  Rgb: TColor;
begin
  Rgb := ColorToRGB(Color);
  Quad.rgbBlue := GetBValue(Rgb);
  Quad.rgbGreen := GetGValue(Rgb);
  Quad.rgbRed := GetRValue(Rgb);
  Quad.rgbReserved := 0;
end;

procedure BuildSpectrogramBitmap(Bitmap: Vcl.Graphics.TBitmap;
  const History: TSpectrogramHistory);
var
  Band        : Integer;
  FirstIndex  : Integer;
  HistoryIndex: Integer;
  HistoryOffset: Integer;
  PixelX      : Integer;
  Row         : PRgbQuadRow;
begin
  Bitmap.PixelFormat := pf32bit;
  Bitmap.SetSize(AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT,
    AUDIO_MONITOR_SPECTRUM_BAND_COUNT);

  for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
  begin
    Row := Bitmap.ScanLine[Band];
    FillChar(Row^, SizeOf(TRgbQuadRow), 0);
  end;

  FirstIndex := HistoryWriteIndex - HistoryCount;
  while FirstIndex < 0 do
    Inc(FirstIndex, AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT);

  for HistoryOffset := 0 to HistoryCount - 1 do
  begin
    HistoryIndex := (FirstIndex + HistoryOffset) mod AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT;
    PixelX := AUDIO_MONITOR_SPECTRUM_HISTORY_COUNT - HistoryCount + HistoryOffset;
    for Band := 0 to AUDIO_MONITOR_SPECTRUM_BAND_LAST do
    begin
      Row := Bitmap.ScanLine[Band];
      SetQuadColor(Row^[PixelX], SpectrogramColor(History[HistoryIndex][Band]));
    end;
  end;
end;

procedure DrawSpectrogramPanel(Canvas: TCanvas; const PanelRect: TRect;
  const History: TSpectrogramHistory; const Caption: string; CaptionColor: TColor);
var
  Bitmap  : Vcl.Graphics.TBitmap;
  ImageRect: TRect;
begin
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Color := CaptionColor;
  Canvas.TextOut(PanelRect.Left, PanelRect.Top, Caption);

  ImageRect := PanelRect;
  Inc(ImageRect.Top, 18);
  if (ImageRect.Right <= ImageRect.Left) or (ImageRect.Bottom <= ImageRect.Top) then
    Exit;

  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    BuildSpectrogramBitmap(Bitmap, History);
    SetStretchBltMode(Canvas.Handle, COLORONCOLOR);
    Canvas.StretchDraw(ImageRect, Bitmap);
  finally
    Bitmap.Free;
  end;

  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := RGB(68, 68, 68);
  Canvas.Rectangle(ImageRect);
  Canvas.Font.Color := RGB(150, 150, 150);
  Canvas.TextOut(ImageRect.Left + 4, ImageRect.Top + 2, 'High');
  Canvas.TextOut(ImageRect.Left + 4, ImageRect.Bottom - 16, 'Low');
end;

procedure ClearAudioSpectrogramHistory;
begin
  FillChar(InputHistory, SizeOf(InputHistory), 0);
  FillChar(OutputHistory, SizeOf(OutputHistory), 0);
  HistoryWriteIndex := 0;
  HistoryCount := 0;
  LastAppendTick := 0;
  LastGeneration := 0;
  LastSampleIndex := 0;
  LastSourceFrame := 0;
  LastSourceLayer := 0;
  LastStateValid := False;
end;

procedure DrawAudioSpectrogramCanvas(Canvas: TCanvas; const ClientRect: TRect;
  State: PAul2AudioMonitorSpectrumState; AdvanceHistory: Boolean);
var
  CaptionText: string;
  ContentRect: TRect;
  InputRect  : TRect;
  OutputRect : TRect;
  PanelHeight: Integer;
begin
  Canvas.Brush.Color := RGB(36, 36, 36);
  Canvas.FillRect(ClientRect);
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Size := 9;
  Canvas.Brush.Style := bsClear;

  try
    AppendSpectrumState(State, AdvanceHistory);
    if (HistoryCount = 0) and not SpectrumStateValid(State) then
    begin
      Canvas.Font.Color := RGB(220, 220, 220);
      Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
        'Spectrogram - waiting audio data');
      Exit;
    end;

    if SpectrumStateValid(State) then
      CaptionText := Format('Spectrogram  %d Hz  %d bands  Layer %d',
        [State^.SampleRate, State^.BandCount, State^.SourceLayer + 1])
    else
      CaptionText := 'Spectrogram';
    Canvas.Font.Color := RGB(220, 220, 220);
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8, CaptionText);

    ContentRect := ClientRect;
    InflateRect(ContentRect, -12, -12);
    Inc(ContentRect.Top, 24);
    if (ContentRect.Right - ContentRect.Left < 80) or
       (ContentRect.Bottom - ContentRect.Top < 96) then
      Exit;

    PanelHeight := (ContentRect.Bottom - ContentRect.Top - 8) div 2;
    InputRect := Rect(ContentRect.Left, ContentRect.Top, ContentRect.Right,
      ContentRect.Top + PanelHeight);
    OutputRect := Rect(ContentRect.Left, InputRect.Bottom + 8, ContentRect.Right,
      ContentRect.Bottom);

    DrawSpectrogramPanel(Canvas, InputRect, InputHistory, 'Input', RGB(92, 190, 122));
    DrawSpectrogramPanel(Canvas, OutputRect, OutputHistory, 'Output', RGB(224, 176, 72));
  except
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Color := RGB(220, 220, 220);
    Canvas.TextOut(ClientRect.Left + 12, ClientRect.Top + 8,
      'Spectrogram - draw error');
  end;

  Canvas.Brush.Style := bsSolid;
end;

initialization
  ClearAudioSpectrogramHistory;

end.
