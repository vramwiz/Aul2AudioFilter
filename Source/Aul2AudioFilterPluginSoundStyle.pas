unit Aul2AudioFilterPluginSoundStyle;

// 日本語 GUI の「スタイル」項目と、用途別のかんたんな音作りを担当する。

interface

uses
  System.Math,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddSoundStyleItems;
function ProcessSoundStyle(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;

implementation

const
  SOUND_STYLE_NONE             = 0;
  SOUND_STYLE_TELEPHONE_LIGHT  = 1;
  SOUND_STYLE_TELEPHONE_STRONG = 2;
  SOUND_STYLE_RADIO_LIGHT      = 3;
  SOUND_STYLE_RADIO_STRONG     = 4;
  SOUND_STYLE_MEGAPHONE        = 5;
  SOUND_STYLE_NEXT_ROOM_THIN   = 6;
  SOUND_STYLE_NEXT_ROOM_THICK  = 7;
  SOUND_STYLE_DISTANT_NEAR     = 8;
  SOUND_STYLE_DISTANT_FAR      = 9;
  SOUND_STYLE_BATH_SMALL       = 10;
  SOUND_STYLE_BATH_LARGE       = 11;
  SOUND_STYLE_TUNNEL           = 12;
  SOUND_STYLE_ANNOUNCEMENT     = 13;
  SOUND_STYLE_NARRATION_CLEAR  = 14;
  SOUND_STYLE_DREAM_LIGHT      = 15;
  SOUND_STYLE_DREAM_DEEP       = 16;

type
  PSoundStyleChannelState = ^TSoundStyleChannelState;

  TSoundStyleChannelState = record
    LowCutLP     : Single;         // low cut を作るための low-pass 状態
    HighCutLP    : Single;         // high cut を作るための low-pass 状態
    ToneLP       : Single;         // こもりや明るさ調整で使う low-pass 状態
    SpaceLP      : Single;         // 空間反射を少し丸めるための low-pass 状態
    Envelope     : Single;         // ナレーション補正などで使う簡易レベル検出
    Seed         : Cardinal;       // チャンネル別の疑似乱数状態
    DelayBuffer  : TArray<Single>; // 空間系スタイル用の簡易 delay line
    DelayPosition: Integer;        // 次に読み書きするリングバッファ位置
  end;

var
  GSoundStyleSelect    : TFILTER_ITEM_SELECT;
  GSoundStyleList      : array[0..17] of TFILTER_ITEM_SELECT_ITEM;
  GSoundStyleChannels  : array of TSoundStyleChannelState; // チャンネル別のスタイル処理状態
  GSoundStyleSampleRate: Integer;                           // 状態を構築したサンプルレート
  GSoundStyleMode      : Integer;                           // 状態を構築したスタイル
  GSoundStyleObjectID  : Int64;                             // 状態を構築した対象オブジェクト
  GSoundStyleEffectID  : Int64;                             // 状態を構築した対象エフェクト
  GSoundStyleNextIndex : Int64;                             // 連続処理を判定する次のサンプル位置

procedure ClearSoundStyleState;
begin
  SetLength(GSoundStyleChannels, 0);
  GSoundStyleSampleRate := 0;
  GSoundStyleMode := SOUND_STYLE_NONE;
  GSoundStyleObjectID := 0;
  GSoundStyleEffectID := 0;
  GSoundStyleNextIndex := 0;
end;

procedure ResetSoundStyleState(ChannelNum, SampleRate, Mode: Integer);
var
  Channel: Integer;
  DelaySamples: Integer;
begin
  SetLength(GSoundStyleChannels, ChannelNum);
  DelaySamples := Round(SampleRate * 0.85);
  if DelaySamples < 1 then
    DelaySamples := 1;

  for Channel := 0 to ChannelNum - 1 do
  begin
    GSoundStyleChannels[Channel].LowCutLP := 0.0;
    GSoundStyleChannels[Channel].HighCutLP := 0.0;
    GSoundStyleChannels[Channel].ToneLP := 0.0;
    GSoundStyleChannels[Channel].SpaceLP := 0.0;
    GSoundStyleChannels[Channel].Envelope := 0.0;
    GSoundStyleChannels[Channel].Seed := Cardinal($2468ACE0 + (Channel * $00100193) + (Mode * $00010101));
    SetLength(GSoundStyleChannels[Channel].DelayBuffer, DelaySamples);
    FillChar(GSoundStyleChannels[Channel].DelayBuffer[0], DelaySamples * SizeOf(Single), 0);
    GSoundStyleChannels[Channel].DelayPosition := 0;
  end;

  GSoundStyleSampleRate := SampleRate;
  GSoundStyleMode := Mode;
end;

procedure EnsureSoundStyleState(Audio: PFILTER_PROC_AUDIO; ChannelNum, Mode: Integer);
var
  ObjectInfo: POBJECT_INFO;
begin
  ObjectInfo := Audio^.Object_;

  // スタイルごとの状態が別素材や別スタイルへ混ざらないよう、対象や連続位置が変わったら作り直す。
  if (Length(GSoundStyleChannels) <> ChannelNum) or
     (GSoundStyleSampleRate <> Audio^.Scene^.SampleRate) or
     (GSoundStyleMode <> Mode) or
     (GSoundStyleObjectID <> ObjectInfo^.ID) or
     (GSoundStyleEffectID <> ObjectInfo^.EffectID) or
     (GSoundStyleNextIndex <> ObjectInfo^.SampleIndex) then
  begin
    ResetSoundStyleState(ChannelNum, Audio^.Scene^.SampleRate, Mode);
    GSoundStyleObjectID := ObjectInfo^.ID;
    GSoundStyleEffectID := ObjectInfo^.EffectID;
  end;
end;

function ClampSingle(Value, MinValue, MaxValue: Single): Single;
begin
  Result := Value;
  if Result < MinValue then
    Result := MinValue
  else if Result > MaxValue then
    Result := MaxValue;
end;

function DbToLinear(ValueDb: Single): Single;
begin
  Result := Power(10.0, ValueDb / 20.0);
end;

function LowPassCoeff(CutoffHz: Single; SampleRate: Integer): Single;
var
  Cutoff: Single;
  Nyquist: Single;
begin
  Nyquist := SampleRate * 0.5;
  Cutoff := ClampSingle(CutoffHz, 1.0, Nyquist * 0.99);
  Result := 1.0 - Exp(-2.0 * Pi * Cutoff / SampleRate);
end;

function TimeCoeff(TimeMs: Single; SampleRate: Integer): Single;
begin
  TimeMs := ClampSingle(TimeMs, 0.1, 1000.0);
  Result := Exp(-1.0 / (SampleRate * TimeMs / 1000.0));
end;

function ApplyLowPass(InputSample: Single; Coeff: Single; var State: Single): Single;
begin
  State := State + (Coeff * (InputSample - State));
  Result := State;
end;

function ApplyHighPass(InputSample: Single; Coeff: Single; var State: Single): Single;
begin
  State := State + (Coeff * (InputSample - State));
  Result := InputSample - State;
end;

function NextRandom(var Seed: Cardinal): Single;
begin
  Seed := (Seed * 1664525) + 1013904223;
  Result := ((Seed shr 8) * (1.0 / 16777215.0)) * 2.0 - 1.0;
end;

procedure ApplyBandStyle(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  LowCutHz, HighCutHz, GainDb, Drive, NoiseDb: Single);
var
  I: Integer;
  Sample: Single;
  LowCutCoeff: Single;
  HighCutCoeff: Single;
  Gain: Single;
  NoiseGain: Single;
  State: PSoundStyleChannelState;
begin
  LowCutCoeff := LowPassCoeff(LowCutHz, SampleRate);
  HighCutCoeff := LowPassCoeff(HighCutHz, SampleRate);
  Gain := DbToLinear(GainDb);
  NoiseGain := DbToLinear(NoiseDb);
  State := @GSoundStyleChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    Sample := ApplyHighPass(Buffer[I], LowCutCoeff, State^.LowCutLP);
    Sample := ApplyLowPass(Sample, HighCutCoeff, State^.HighCutLP);

    if Drive > 0.0 then
      Sample := Tanh(Sample * Drive) / Tanh(Drive);
    if NoiseDb > -100.0 then
      Sample := Sample + (NextRandom(State^.Seed) * NoiseGain);

    Buffer[I] := ClampSingle(Sample * Gain, -1.0, 1.0);
  end;
end;

procedure ApplyMuffleStyle(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  CutoffHz, Dry, Wet, GainDb: Single);
var
  I: Integer;
  DrySample: Single;
  WetSample: Single;
  Coeff: Single;
  Gain: Single;
  State: PSoundStyleChannelState;
begin
  Coeff := LowPassCoeff(CutoffHz, SampleRate);
  Gain := DbToLinear(GainDb);
  State := @GSoundStyleChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    WetSample := ApplyLowPass(DrySample, Coeff, State^.ToneLP);
    Buffer[I] := ClampSingle(((DrySample * Dry) + (WetSample * Wet)) * Gain, -1.0, 1.0);
  end;
end;

function ReadDelaySample(State: PSoundStyleChannelState; DelaySamples: Integer): Single;
var
  ReadPosition: Integer;
  BufferLength: Integer;
begin
  BufferLength := Length(State^.DelayBuffer);
  ReadPosition := State^.DelayPosition - DelaySamples;
  while ReadPosition < 0 do
    Inc(ReadPosition, BufferLength);
  Result := State^.DelayBuffer[ReadPosition mod BufferLength];
end;

procedure StepDelayPosition(State: PSoundStyleChannelState);
begin
  Inc(State^.DelayPosition);
  if State^.DelayPosition >= Length(State^.DelayBuffer) then
    State^.DelayPosition := 0;
end;

procedure ApplySpaceStyle(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  DelayMs, Feedback, Wet, ToneHz, GainDb: Single);
var
  I: Integer;
  DelaySamples: Integer;
  DrySample: Single;
  DelayedSample: Single;
  SoftReflection: Single;
  ToneCoeff: Single;
  Gain: Single;
  State: PSoundStyleChannelState;
begin
  DelaySamples := Round(SampleRate * DelayMs / 1000.0);
  DelaySamples := Round(DelaySamples * (1.0 + (Channel * 0.07)));
  if DelaySamples < 1 then
    DelaySamples := 1
  else if DelaySamples >= Length(GSoundStyleChannels[Channel].DelayBuffer) then
    DelaySamples := Length(GSoundStyleChannels[Channel].DelayBuffer) - 1;
  ToneCoeff := LowPassCoeff(ToneHz, SampleRate);
  Feedback := ClampSingle(Feedback, 0.0, 0.85);
  Wet := ClampSingle(Wet, 0.0, 1.5);
  Gain := DbToLinear(GainDb);
  State := @GSoundStyleChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    DrySample := Buffer[I];
    DelayedSample := ReadDelaySample(State, DelaySamples);
    SoftReflection := ApplyLowPass(DelayedSample, ToneCoeff, State^.SpaceLP);
    State^.DelayBuffer[State^.DelayPosition] := DrySample + (SoftReflection * Feedback);
    Buffer[I] := ClampSingle(((DrySample * (1.0 - (Wet * 0.25))) + (SoftReflection * Wet)) * Gain, -1.0, 1.0);
    StepDelayPosition(State);
  end;
end;

procedure ApplyNarrationStyle(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer);
var
  I: Integer;
  Sample: Single;
  Level: Single;
  Gain: Single;
  AttackCoeff: Single;
  ReleaseCoeff: Single;
  LowCutCoeff: Single;
  HighCutCoeff: Single;
  State: PSoundStyleChannelState;
begin
  AttackCoeff := TimeCoeff(5.0, SampleRate);
  ReleaseCoeff := TimeCoeff(160.0, SampleRate);
  LowCutCoeff := LowPassCoeff(120.0, SampleRate);
  HighCutCoeff := LowPassCoeff(9000.0, SampleRate);
  State := @GSoundStyleChannels[Channel];

  for I := 0 to SampleNum - 1 do
  begin
    Sample := ApplyHighPass(Buffer[I], LowCutCoeff, State^.LowCutLP);
    Sample := ApplyLowPass(Sample, HighCutCoeff, State^.HighCutLP);
    Level := Abs(Sample);

    if Level > State^.Envelope then
      State^.Envelope := (AttackCoeff * State^.Envelope) + ((1.0 - AttackCoeff) * Level)
    else
      State^.Envelope := (ReleaseCoeff * State^.Envelope) + ((1.0 - ReleaseCoeff) * Level);

    Gain := 1.25;
    if State^.Envelope > 0.35 then
      Gain := Gain * (0.35 / State^.Envelope);
    Buffer[I] := ClampSingle(Sample * Gain, -1.0, 1.0);
  end;
end;

procedure ApplyDreamStyle(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate: Integer;
  Deep: Boolean);
begin
  if Deep then
  begin
    ApplyMuffleStyle(Buffer, Channel, SampleNum, SampleRate, 1800.0, 0.25, 0.90, -1.5);
    ApplySpaceStyle(Buffer, Channel, SampleNum, SampleRate, 420.0, 0.58, 0.55, 1800.0, -1.0);
  end
  else
  begin
    ApplyMuffleStyle(Buffer, Channel, SampleNum, SampleRate, 2600.0, 0.45, 0.70, -0.5);
    ApplySpaceStyle(Buffer, Channel, SampleNum, SampleRate, 280.0, 0.35, 0.35, 2400.0, -0.5);
  end;
end;

procedure ApplySoundStyle(var Buffer: TArray<Single>; Channel, SampleNum, SampleRate, Mode: Integer);
begin
  case Mode of
    SOUND_STYLE_TELEPHONE_LIGHT:
      begin
        // 電話（小）は声の帯域を少し狭め、軽い電話越しの質感に寄せる。
        ApplyBandStyle(Buffer, Channel, SampleNum, SampleRate, 300.0, 3400.0, 1.5, 0.0, -120.0);
      end;
    SOUND_STYLE_TELEPHONE_STRONG:
      begin
        // 電話（大）は帯域をさらに狭め、少し歪ませて小型スピーカー感を強める。
        ApplyBandStyle(Buffer, Channel, SampleNum, SampleRate, 450.0, 2800.0, 3.0, 1.8, -120.0);
      end;
    SOUND_STYLE_RADIO_LIGHT:
      begin
        // 無線（小）は電話風の帯域に薄いノイズを足し、通信越しのざらつきを作る。
        ApplyBandStyle(Buffer, Channel, SampleNum, SampleRate, 250.0, 4200.0, 1.0, 1.2, -42.0);
      end;
    SOUND_STYLE_RADIO_STRONG:
      begin
        // 無線（大）は帯域、歪み、ノイズを強めて古い無線機の荒さに寄せる。
        ApplyBandStyle(Buffer, Channel, SampleNum, SampleRate, 500.0, 2500.0, 3.0, 2.5, -32.0);
      end;
    SOUND_STYLE_MEGAPHONE:
      begin
        // メガホンは中域を強く残して硬く歪ませ、拡声器らしい押し出しを作る。
        ApplyBandStyle(Buffer, Channel, SampleNum, SampleRate, 600.0, 5200.0, 4.0, 3.0, -120.0);
      end;
    SOUND_STYLE_NEXT_ROOM_THIN:
      begin
        // 隣室（小）は高域を軽く落とし、薄い壁越しのこもりを作る。
        ApplyMuffleStyle(Buffer, Channel, SampleNum, SampleRate, 1800.0, 0.25, 0.80, -2.0);
      end;
    SOUND_STYLE_NEXT_ROOM_THICK:
      begin
        // 隣室（大）は高域と音量を大きく落とし、厚い壁越しの聞こえ方にする。
        ApplyMuffleStyle(Buffer, Channel, SampleNum, SampleRate, 850.0, 0.10, 0.95, -7.0);
      end;
    SOUND_STYLE_DISTANT_NEAR:
      begin
        // 遠声（小）は音量と高域を少し落とし、距離感を控えめに足す。
        ApplyMuffleStyle(Buffer, Channel, SampleNum, SampleRate, 3600.0, 0.55, 0.55, -4.0);
      end;
    SOUND_STYLE_DISTANT_FAR:
      begin
        // 遠声（大）は音量を落として反射を薄く足し、遠くから届く声に寄せる。
        ApplyMuffleStyle(Buffer, Channel, SampleNum, SampleRate, 2200.0, 0.30, 0.80, -9.0);
        ApplySpaceStyle(Buffer, Channel, SampleNum, SampleRate, 180.0, 0.22, 0.20, 2200.0, 0.0);
      end;
    SOUND_STYLE_BATH_SMALL:
      begin
        // 風呂（小）は短い反射を強め、狭い硬い空間の響きを作る。
        ApplySpaceStyle(Buffer, Channel, SampleNum, SampleRate, 34.0, 0.42, 0.55, 6500.0, -0.5);
      end;
    SOUND_STYLE_BATH_LARGE:
      begin
        // 風呂（大）は少し長めの反射で、広い浴室の残響に寄せる。
        ApplySpaceStyle(Buffer, Channel, SampleNum, SampleRate, 72.0, 0.55, 0.65, 5200.0, -1.0);
      end;
    SOUND_STYLE_TUNNEL:
      begin
        // トンネルは長い反射を強め、奥行きのある反響空間として聞こえるようにする。
        ApplySpaceStyle(Buffer, Channel, SampleNum, SampleRate, 260.0, 0.68, 0.75, 3600.0, -2.0);
      end;
    SOUND_STYLE_ANNOUNCEMENT:
      begin
        // アナウンスは声の帯域を整理し、少し圧縮した場内放送寄りの音にする。
        ApplyBandStyle(Buffer, Channel, SampleNum, SampleRate, 180.0, 6500.0, 2.5, 0.8, -120.0);
      end;
    SOUND_STYLE_NARRATION_CLEAR:
      begin
        // ナレーションは低域の不要な揺れを削り、ピークを軽く抑えて聞き取りやすくする。
        ApplyNarrationStyle(Buffer, Channel, SampleNum, SampleRate);
      end;
    SOUND_STYLE_DREAM_LIGHT:
      begin
        // 夢（小）は高域を丸めて短い反射を足し、回想風の柔らかさを作る。
        ApplyDreamStyle(Buffer, Channel, SampleNum, SampleRate, False);
      end;
    SOUND_STYLE_DREAM_DEEP:
      begin
        // 夢（大）はさらにこもらせて長めの反射を足し、ぼんやりした演出に寄せる。
        ApplyDreamStyle(Buffer, Channel, SampleNum, SampleRate, True);
      end;
  else
    begin
      // なし、または未定義のスタイルでは元音を変更しない。
    end;
  end;
end;

procedure AddStyleItem(Index: Integer; Name: PWideChar; Value: Integer);
begin
  GSoundStyleList[Index].Name := Name;
  GSoundStyleList[Index].Value := Value;
end;

procedure AddSoundStyleItems;
begin
  AddStyleItem(0, 'なし', SOUND_STYLE_NONE);
  AddStyleItem(1, '電話（小）', SOUND_STYLE_TELEPHONE_LIGHT);
  AddStyleItem(2, '電話（大）', SOUND_STYLE_TELEPHONE_STRONG);
  AddStyleItem(3, '無線（小）', SOUND_STYLE_RADIO_LIGHT);
  AddStyleItem(4, '無線（大）', SOUND_STYLE_RADIO_STRONG);
  AddStyleItem(5, 'メガホン', SOUND_STYLE_MEGAPHONE);
  AddStyleItem(6, '隣室（小）', SOUND_STYLE_NEXT_ROOM_THIN);
  AddStyleItem(7, '隣室（大）', SOUND_STYLE_NEXT_ROOM_THICK);
  AddStyleItem(8, '遠声（小）', SOUND_STYLE_DISTANT_NEAR);
  AddStyleItem(9, '遠声（大）', SOUND_STYLE_DISTANT_FAR);
  AddStyleItem(10, '風呂（小）', SOUND_STYLE_BATH_SMALL);
  AddStyleItem(11, '風呂（大）', SOUND_STYLE_BATH_LARGE);
  AddStyleItem(12, 'トンネル', SOUND_STYLE_TUNNEL);
  AddStyleItem(13, 'アナウンス', SOUND_STYLE_ANNOUNCEMENT);
  AddStyleItem(14, 'ナレーション', SOUND_STYLE_NARRATION_CLEAR);
  AddStyleItem(15, '夢（小）', SOUND_STYLE_DREAM_LIGHT);
  AddStyleItem(16, '夢（大）', SOUND_STYLE_DREAM_DEEP);
  AddStyleItem(17, nil, 0);
  AddSelect(GSoundStyleSelect, 'スタイル', SOUND_STYLE_NONE, @GSoundStyleList[0]);
end;

function ProcessSoundStyle(Audio: PFILTER_PROC_AUDIO; SampleNum, ChannelNum: Integer): Boolean;
var
  Channel: Integer;
  Buffer: TArray<Single>;
  Mode: Integer;
begin
  Mode := GSoundStyleSelect.Value;
  Result := Mode <> SOUND_STYLE_NONE;
  if not Result then
  begin
    ClearSoundStyleState;
    Exit;
  end;

  EnsureSoundStyleState(Audio, ChannelNum, Mode);
  SetLength(Buffer, SampleNum);

  for Channel := 0 to ChannelNum - 1 do
  begin
    Audio^.GetSampleData(@Buffer[0], Channel);
    ApplySoundStyle(Buffer, Channel, SampleNum, Audio^.Scene^.SampleRate, Mode);
    Audio^.SetSampleData(@Buffer[0], Channel);
  end;

  GSoundStyleNextIndex := Audio^.Object_^.SampleIndex + SampleNum;
end;

end.
