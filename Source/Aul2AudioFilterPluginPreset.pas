unit Aul2AudioFilterPluginPreset;

// 日本語 GUI の「プリセット」項目と、詳細エフェクト設定への反映を担当する。

interface

uses
  System.SysUtils,
  Aul2AudioFilterTypes,
  Aul2AudioFilterGui;

procedure AddPresetItems;

implementation

uses
  Aul2AudioFilterPluginDelay,
  Aul2AudioFilterPluginEq,
  Aul2AudioFilterPluginCompressor,
  Aul2AudioFilterPluginVoiceDrive,
  Aul2AudioFilterPluginDistortion,
  Aul2AudioFilterPluginNoise,
  Aul2AudioFilterPluginBitCrusher,
  Aul2AudioFilterPluginTremble,
  Aul2AudioFilterPluginWobble,
  Aul2AudioFilterPluginPitch,
  Aul2AudioFilterPluginRingMod,
  Aul2AudioFilterPluginMuffle,
  Aul2AudioFilterPluginWhisper,
  Aul2AudioFilterPluginAutoGain,
  Aul2AudioFilterPluginNoiseGate,
  Aul2AudioFilterPluginGhost,
  Aul2AudioFilterPluginOutput,
  Aul2AudioFilterPluginLimiter,
  Aul2AudioFilterPluginChorus,
  Aul2AudioFilterPluginReverb;

const
  SOUND_PRESET_NONE       = 0;
  SOUND_PRESET_ECHO       = 1;
  SOUND_PRESET_PING_PONG  = 2;
  SOUND_PRESET_REVERB     = 3;
  SOUND_PRESET_WIDE       = 4;
  SOUND_PRESET_NARRATION  = 5;
  SOUND_PRESET_TELEPHONE  = 6;
  SOUND_PRESET_RADIO      = 7;
  SOUND_PRESET_MEGAPHONE  = 8;
  SOUND_PRESET_LOW_QUALITY = 9;
  SOUND_PRESET_MALE       = 10;
  SOUND_PRESET_FEMALE     = 11;
  SOUND_PRESET_ROBOT      = 12;
  SOUND_PRESET_FEAR       = 13;
  SOUND_PRESET_SHOUT      = 14;
  SOUND_PRESET_WHISPER    = 15;
  SOUND_PRESET_UNDERWATER = 16;
  SOUND_PRESET_WALL       = 17;
  SOUND_PRESET_DREAM      = 18;

var
  GSoundPresetSelect: TFILTER_ITEM_SELECT;
  GSoundPresetList  : array[0..18] of TFILTER_ITEM_SELECT_ITEM;
  GSoundPresetButton: TFILTER_ITEM_BUTTON;

procedure AddPresetItem(Index: Integer; Name: PWideChar; Value: Integer);
begin
  GSoundPresetList[Index].Name := Name;
  GSoundPresetList[Index].Value := Value;
end;

procedure ResetLocalPresetTargets;
begin
  // プリセット適用時は前回プリセットの残りを避けるため、対象エフェクトをいったん既定値へ戻す。
  SetDelayGuiParams(False, 250.0, 1.0, 0.0, 0.0, False);
  SetEqBandPassGuiParams(False, 300.0, 3400.0, 1.0);
  SetCompressorGuiParams(False, -18.0, 4.0, 10.0, 120.0, 0.0, 1.0);
  SetVoiceDriveGuiParams(False, 9.0, 0.45, -6.0, 0.6);
  SetDistortionGuiParams(False, False, 6.0, 1.0, -6.0, 1.0);
  SetNoiseGuiParams(False, False, -36.0, 1.0);
  SetBitCrusherGuiParams(False, 8.0, 4.0, 1.0);
  SetTrembleGuiParams(False, 8.0, 0.35, 1.0);
  SetWobbleGuiParams(False, 24.0, 12.0, 1.2, 0.65);
  SetPitchGuiParams(False, 0, 0.0, 60.0, 0.0, 0.7, 5.0, 4.0, 1.0);
  SetRingModGuiParams(False, 45.0, 0.7, 0.7);
  SetMuffleGuiParams(False, 1200.0, 0.8, 1.0);
  SetWhisperGuiParams(False, -18.0, 0.65, 0.5);
  SetAutoGainGuiParams(False, -12.0, 400.0, 12.0, 1.0);
  SetNoiseGateGuiParams(False, -45.0, 5.0, 120.0, -60.0);
  SetGhostGuiParams(False, 420.0, 0.45, 0.35, 1.0);
  SetOutputGuiParams(False, 0.0);
  SetLimiterGuiParams(False, -1.0, 50.0, 1.0);
  SetChorusGuiParams(False, False, 15.0, 5.0, 0.5, 0.5);
  SetReverbGuiParams(False, 0, 0.5, 0.4, 1.0, 0.3);
end;

procedure ApplyPresetToLocalItems(Preset: Integer);
begin
  ResetLocalPresetTargets;

  case Preset of
    SOUND_PRESET_ECHO:
      begin
        // エコーは Delay の基本的な反復音を作り、Time/Wet/Feedback を後から詰められるようにする。
        SetDelayGuiParams(True, 250.0, 1.0, 0.55, 0.35, False);
      end;
    SOUND_PRESET_PING_PONG:
      begin
        // 反響は左右に跳ね返る Delay を初期値として設定する。
        SetDelayGuiParams(True, 320.0, 1.0, 0.55, 0.30, True);
      end;
    SOUND_PRESET_REVERB:
      begin
        // ホールはスピーカー確認でも分かるよう、直音より残響を少し前に出す。
        SetReverbGuiParams(True, 1, 0.90, 0.20, 0.85, 0.95);
      end;
    SOUND_PRESET_WIDE:
      begin
        // 空間は Wide Chorus で左右差を作り、最後に少し音量を戻す。
        SetChorusGuiParams(True, True, 18.0, 7.0, 0.45, 0.45);
        SetOutputGuiParams(True, 4.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_NARRATION:
      begin
        // ナレーションは声を前に出す EQ / Compressor / VoiceDrive / Output / Limiter をまとめて設定する。
        SetEqBandPassGuiParams(True, 140.0, 8500.0, 1.0);
        SetCompressorGuiParams(True, -26.0, 4.5, 3.0, 90.0, 5.0, 1.0);
        SetVoiceDriveGuiParams(True, 7.0, 0.35, -2.0, 0.40);
        SetOutputGuiParams(True, 3.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_TELEPHONE:
      begin
        // 電話は帯域制限に軽い歪みと粗さを足し、最後に体感音量を戻す。
        SetEqBandPassGuiParams(True, 500.0, 2600.0, 1.0);
        SetDistortionGuiParams(True, False, 8.0, 0.80, -3.0, 0.50);
        SetBitCrusherGuiParams(True, 9.0, 1.0, 0.50);
        SetOutputGuiParams(True, 4.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_RADIO:
      begin
        // 無線は狭い帯域、歪み、粗さを組み合わせる。Noise はクラッシュ対策で使わない。
        SetEqBandPassGuiParams(True, 700.0, 2300.0, 1.0);
        SetDistortionGuiParams(True, False, 14.0, 1.0, -5.0, 0.75);
        SetNoiseGuiParams(False, False, -36.0, 0.0);
        SetBitCrusherGuiParams(True, 7.0, 3.0, 0.70);
        SetLimiterGuiParams(True, -1.0, 40.0, 1.0);
      end;
    SOUND_PRESET_MEGAPHONE:
      begin
        // 拡声器は中域寄りの帯域、強い圧縮、声向け押し出し、硬い歪みで作る。
        SetEqBandPassGuiParams(True, 550.0, 4800.0, 1.0);
        SetCompressorGuiParams(True, -28.0, 6.0, 2.0, 80.0, 6.0, 1.0);
        SetVoiceDriveGuiParams(True, 12.0, 0.55, -3.0, 0.65);
        SetDistortionGuiParams(True, True, 18.0, 1.0, -7.0, 0.85);
        SetOutputGuiParams(True, -2.2);
        SetLimiterGuiParams(True, -1.0, 35.0, 1.0);
      end;
    SOUND_PRESET_LOW_QUALITY:
      begin
        // 劣化は BitCrusher と軽い歪みを中心に作る。Noise は処理例外対策で使わない。
        SetEqBandPassGuiParams(True, 300.0, 4200.0, 1.0);
        SetDistortionGuiParams(True, False, 8.0, 0.85, -4.0, 0.45);
        SetNoiseGuiParams(False, False, -45.0, 0.0);
        SetBitCrusherGuiParams(True, 5.0, 10.0, 0.85);
        SetOutputGuiParams(True, 3.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_MALE:
      begin
        // 男性は音程と声色の重心を下げる。Dry も混ぜてぶつ切れを抑える。
        SetPitchGuiParams(True, 0, -2.0, 110.0, -2.5, 0.6, 5.0, 4.0, 0.60);
        SetEqBandPassGuiParams(True, 90.0, 7600.0, 1.0);
        SetOutputGuiParams(True, 5.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_FEMALE:
      begin
        // 女性は音程と声色の重心を上げる。Dry も混ぜてぶつ切れを抑える。
        SetPitchGuiParams(True, 0, 2.0, 100.0, 2.5, 0.6, 5.0, 4.0, 0.60);
        SetEqBandPassGuiParams(True, 150.0, 9000.0, 1.0);
        SetOutputGuiParams(True, 5.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_ROBOT:
      begin
        SetRingModGuiParams(True, 95.0, 1.0, 0.90);
        SetPitchGuiParams(True, 3, 0.0, 90.0, 0.0, 0.7, 3.0, 7.0, 0.45);
        SetBitCrusherGuiParams(True, 6.0, 3.0, 0.65);
        SetEqBandPassGuiParams(True, 220.0, 4800.0, 1.0);
        SetOutputGuiParams(True, 10.0);
        SetLimiterGuiParams(True, -1.0, 45.0, 1.0);
      end;
    SOUND_PRESET_FEAR:
      begin
        SetTrembleGuiParams(True, 11.0, 0.75, 1.0);
        SetWobbleGuiParams(True, 35.0, 28.0, 0.70, 0.75);
        SetPitchGuiParams(True, 0, -1.5, 100.0, -2.0, 0.5, 5.0, 4.0, 0.55);
        SetMuffleGuiParams(True, 2600.0, 0.45, 0.60);
        SetGhostGuiParams(True, 650.0, 0.55, 0.45, 1.0);
        SetReverbGuiParams(True, 1, 0.70, 0.40, 1.0, 0.45);
        SetOutputGuiParams(True, 3.0);
        SetLimiterGuiParams(True, -1.0, 60.0, 1.0);
      end;
    SOUND_PRESET_SHOUT:
      begin
        SetCompressorGuiParams(True, -30.0, 8.0, 1.5, 70.0, 7.0, 1.0);
        SetVoiceDriveGuiParams(True, 18.0, 0.65, -4.0, 0.85);
        SetDistortionGuiParams(True, True, 10.0, 1.0, -8.0, 0.35);
        SetOutputGuiParams(True, 5.0);
        SetLimiterGuiParams(True, -1.0, 25.0, 1.0);
      end;
    SOUND_PRESET_WHISPER:
      begin
        SetWhisperGuiParams(True, 0.0, 1.0, 1.0);
        SetEqBandPassGuiParams(True, 900.0, 11000.0, 1.0);
        SetCompressorGuiParams(True, -38.0, 2.0, 18.0, 260.0, 0.0, 0.45);
        SetOutputGuiParams(True, 9.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_UNDERWATER:
      begin
        SetMuffleGuiParams(True, 850.0, 0.95, 1.0);
        SetWobbleGuiParams(True, 35.0, 22.0, 0.75, 0.55);
        SetChorusGuiParams(True, True, 22.0, 9.0, 0.35, 0.35);
        SetReverbGuiParams(True, 0, 0.45, 0.75, 1.0, 0.25);
        SetOutputGuiParams(True, 14.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_WALL:
      begin
        SetMuffleGuiParams(True, 650.0, 1.0, 1.0);
        SetEqBandPassGuiParams(True, 120.0, 1800.0, 1.0);
        SetReverbGuiParams(True, 0, 0.25, 0.7, 1.0, 0.12);
        SetOutputGuiParams(True, 6.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
    SOUND_PRESET_DREAM:
      begin
        SetWobbleGuiParams(True, 34.0, 24.0, 0.38, 0.62);
        SetChorusGuiParams(True, True, 28.0, 13.0, 0.22, 0.58);
        SetGhostGuiParams(True, 760.0, 0.52, 0.42, 1.0);
        SetReverbGuiParams(True, 1, 0.72, 0.42, 1.0, 0.48);
        SetOutputGuiParams(True, 6.0);
        SetLimiterGuiParams(True, -1.0, 50.0, 1.0);
      end;
  else
    begin
      // なしは ResetLocalPresetTargets の結果をそのまま使い、プリセット対象をOFFにする。
    end;
  end;
end;

function SetPresetObjectItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  Item: PWideChar; const Value: UTF8String): Boolean;
begin
  Result := False;
  if (Edit = nil) or (Obj = nil) or not Assigned(Edit^.SetObjectItemValue) then
    Exit;

  // AviUtl2 側の対象エフェクト名が環境で揺れる可能性を見るため、名称と初期ラベルの両方を試す。
  Result := Edit^.SetObjectItemValue(Obj, 'サウンドエフェクター', Item, PAnsiChar(Value)) <> 0;
  if not Result then
    Result := Edit^.SetObjectItemValue(Obj, '音声効果', Item, PAnsiChar(Value)) <> 0;
end;

procedure ResetObjectPresetTargets(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE);
begin
  // GUI 表示側も既定値へ戻し、前回プリセットでONにしたエフェクトが残らないようにする。
  SetPresetObjectItem(Edit, Obj, 'Dly: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Dly: Stereo Mode', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Dly: Time(ms)', UTF8String('250'));
  SetPresetObjectItem(Edit, Obj, 'Dly: Dry', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Dly: Wet', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Dly: Feedback', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'EQ: Mode', UTF8String('2'));
  SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('300'));
  SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('3400'));
  SetPresetObjectItem(Edit, Obj, 'EQ: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Comp: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Comp: Threshold(dB)', UTF8String('-18'));
  SetPresetObjectItem(Edit, Obj, 'Comp: Ratio', UTF8String('4'));
  SetPresetObjectItem(Edit, Obj, 'Comp: Attack(ms)', UTF8String('10'));
  SetPresetObjectItem(Edit, Obj, 'Comp: Release(ms)', UTF8String('120'));
  SetPresetObjectItem(Edit, Obj, 'Comp: Makeup(dB)', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Comp: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Drive: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Drive: Drive(dB)', UTF8String('9'));
  SetPresetObjectItem(Edit, Obj, 'Drive: Body', UTF8String('0.45'));
  SetPresetObjectItem(Edit, Obj, 'Drive: Level(dB)', UTF8String('-6'));
  SetPresetObjectItem(Edit, Obj, 'Drive: Mix', UTF8String('0.6'));
  SetPresetObjectItem(Edit, Obj, 'Dist: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Dist: Mode', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Dist: Drive(dB)', UTF8String('6'));
  SetPresetObjectItem(Edit, Obj, 'Dist: Tone', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Dist: Level(dB)', UTF8String('-6'));
  SetPresetObjectItem(Edit, Obj, 'Dist: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Noise: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Noise: Mode', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Noise: Level(dB)', UTF8String('-36'));
  SetPresetObjectItem(Edit, Obj, 'Noise: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Crush: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Crush: BitDepth', UTF8String('8'));
  SetPresetObjectItem(Edit, Obj, 'Crush: SampleHold', UTF8String('4'));
  SetPresetObjectItem(Edit, Obj, 'Crush: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Trem: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Trem: Rate(Hz)', UTF8String('8'));
  SetPresetObjectItem(Edit, Obj, 'Trem: Depth', UTF8String('0.35'));
  SetPresetObjectItem(Edit, Obj, 'Trem: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Wob: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Wob: Delay(ms)', UTF8String('24'));
  SetPresetObjectItem(Edit, Obj, 'Wob: Depth(ms)', UTF8String('12'));
  SetPresetObjectItem(Edit, Obj, 'Wob: Rate(Hz)', UTF8String('1.2'));
  SetPresetObjectItem(Edit, Obj, 'Wob: Mix', UTF8String('0.65'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Mode', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Semitone', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Window(ms)', UTF8String('60'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Formant', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Amount', UTF8String('0.7'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Step(semi)', UTF8String('5'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Rate(Hz)', UTF8String('4'));
  SetPresetObjectItem(Edit, Obj, 'Pitch: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Ring: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Ring: Frequency(Hz)', UTF8String('45'));
  SetPresetObjectItem(Edit, Obj, 'Ring: Depth', UTF8String('0.7'));
  SetPresetObjectItem(Edit, Obj, 'Ring: Mix', UTF8String('0.7'));
  SetPresetObjectItem(Edit, Obj, 'Muffle: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Muffle: Cutoff(Hz)', UTF8String('1200'));
  SetPresetObjectItem(Edit, Obj, 'Muffle: Amount', UTF8String('0.8'));
  SetPresetObjectItem(Edit, Obj, 'Muffle: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Breath: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Breath: Level(dB)', UTF8String('-18'));
  SetPresetObjectItem(Edit, Obj, 'Breath: Tone', UTF8String('0.65'));
  SetPresetObjectItem(Edit, Obj, 'Breath: Mix', UTF8String('0.5'));
  SetPresetObjectItem(Edit, Obj, 'AGain: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'AGain: Target(dB)', UTF8String('-12'));
  SetPresetObjectItem(Edit, Obj, 'AGain: Speed(ms)', UTF8String('400'));
  SetPresetObjectItem(Edit, Obj, 'AGain: MaxGain(dB)', UTF8String('12'));
  SetPresetObjectItem(Edit, Obj, 'AGain: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Gate: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Gate: Threshold(dB)', UTF8String('-45'));
  SetPresetObjectItem(Edit, Obj, 'Gate: Attack(ms)', UTF8String('5'));
  SetPresetObjectItem(Edit, Obj, 'Gate: Release(ms)', UTF8String('120'));
  SetPresetObjectItem(Edit, Obj, 'Gate: Floor(dB)', UTF8String('-60'));
  SetPresetObjectItem(Edit, Obj, 'Ghost: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Ghost: Size(ms)', UTF8String('420'));
  SetPresetObjectItem(Edit, Obj, 'Ghost: Feedback', UTF8String('0.45'));
  SetPresetObjectItem(Edit, Obj, 'Ghost: Wet', UTF8String('0.35'));
  SetPresetObjectItem(Edit, Obj, 'Ghost: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Lim: Ceiling(dB)', UTF8String('-1'));
  SetPresetObjectItem(Edit, Obj, 'Lim: Release(ms)', UTF8String('50'));
  SetPresetObjectItem(Edit, Obj, 'Lim: Mix', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Cho: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Cho: Stereo Mode', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Cho: Delay(ms)', UTF8String('15'));
  SetPresetObjectItem(Edit, Obj, 'Cho: Depth(ms)', UTF8String('5'));
  SetPresetObjectItem(Edit, Obj, 'Cho: Rate(Hz)', UTF8String('0.5'));
  SetPresetObjectItem(Edit, Obj, 'Cho: Mix', UTF8String('0.5'));
  SetPresetObjectItem(Edit, Obj, 'Rev: Use', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Rev: Type', UTF8String('0'));
  SetPresetObjectItem(Edit, Obj, 'Rev: RoomSize', UTF8String('0.5'));
  SetPresetObjectItem(Edit, Obj, 'Rev: Damping', UTF8String('0.4'));
  SetPresetObjectItem(Edit, Obj, 'Rev: Dry', UTF8String('1'));
  SetPresetObjectItem(Edit, Obj, 'Rev: Wet', UTF8String('0.3'));
end;

procedure ApplyPresetToObjectItems(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE; Preset: Integer);
begin
  ResetObjectPresetTargets(Edit, Obj);

  case Preset of
    SOUND_PRESET_ECHO:
      begin
        SetPresetObjectItem(Edit, Obj, 'Dly: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dly: Time(ms)', UTF8String('250'));
        SetPresetObjectItem(Edit, Obj, 'Dly: Wet', UTF8String('0.55'));
        SetPresetObjectItem(Edit, Obj, 'Dly: Feedback', UTF8String('0.35'));
      end;
    SOUND_PRESET_PING_PONG:
      begin
        SetPresetObjectItem(Edit, Obj, 'Dly: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dly: Stereo Mode', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dly: Time(ms)', UTF8String('320'));
        SetPresetObjectItem(Edit, Obj, 'Dly: Wet', UTF8String('0.55'));
        SetPresetObjectItem(Edit, Obj, 'Dly: Feedback', UTF8String('0.30'));
      end;
    SOUND_PRESET_REVERB:
      begin
        SetPresetObjectItem(Edit, Obj, 'Rev: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Type', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: RoomSize', UTF8String('0.90'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Damping', UTF8String('0.20'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Dry', UTF8String('0.85'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Wet', UTF8String('0.95'));
      end;
    SOUND_PRESET_WIDE:
      begin
        SetPresetObjectItem(Edit, Obj, 'Cho: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Stereo Mode', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Delay(ms)', UTF8String('18'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Depth(ms)', UTF8String('7'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Rate(Hz)', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Mix', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('4'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_NARRATION:
      begin
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('140'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('8500'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Threshold(dB)', UTF8String('-26'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Ratio', UTF8String('4.5'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Attack(ms)', UTF8String('3'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Release(ms)', UTF8String('90'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Makeup(dB)', UTF8String('5'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Drive(dB)', UTF8String('7'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Body', UTF8String('0.35'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Level(dB)', UTF8String('-2'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Mix', UTF8String('0.40'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('3'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_TELEPHONE:
      begin
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('500'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('2600'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Drive(dB)', UTF8String('8'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Tone', UTF8String('0.80'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Level(dB)', UTF8String('-3'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Mix', UTF8String('0.50'));
        SetPresetObjectItem(Edit, Obj, 'Crush: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Crush: BitDepth', UTF8String('9'));
        SetPresetObjectItem(Edit, Obj, 'Crush: SampleHold', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Crush: Mix', UTF8String('0.50'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('4'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_RADIO:
      begin
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('700'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('2300'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Drive(dB)', UTF8String('14'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Tone', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Level(dB)', UTF8String('-5'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Mix', UTF8String('0.75'));
        SetPresetObjectItem(Edit, Obj, 'Noise: Use', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Noise: Mode', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Noise: Level(dB)', UTF8String('-36'));
        SetPresetObjectItem(Edit, Obj, 'Noise: Mix', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Crush: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Crush: BitDepth', UTF8String('7'));
        SetPresetObjectItem(Edit, Obj, 'Crush: SampleHold', UTF8String('3'));
        SetPresetObjectItem(Edit, Obj, 'Crush: Mix', UTF8String('0.70'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Release(ms)', UTF8String('40'));
      end;
    SOUND_PRESET_MEGAPHONE:
      begin
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('550'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('4800'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Threshold(dB)', UTF8String('-28'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Ratio', UTF8String('6'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Attack(ms)', UTF8String('2'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Release(ms)', UTF8String('80'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Makeup(dB)', UTF8String('6'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Drive(dB)', UTF8String('12'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Body', UTF8String('0.55'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Level(dB)', UTF8String('-3'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Mix', UTF8String('0.65'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Mode', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Drive(dB)', UTF8String('18'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Level(dB)', UTF8String('-7'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Mix', UTF8String('0.85'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('-2.2'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Release(ms)', UTF8String('35'));
      end;
    SOUND_PRESET_LOW_QUALITY:
      begin
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('300'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('4200'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Drive(dB)', UTF8String('8'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Tone', UTF8String('0.85'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Level(dB)', UTF8String('-4'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Mix', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Noise: Use', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Noise: Level(dB)', UTF8String('-45'));
        SetPresetObjectItem(Edit, Obj, 'Noise: Mix', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Crush: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Crush: BitDepth', UTF8String('5'));
        SetPresetObjectItem(Edit, Obj, 'Crush: SampleHold', UTF8String('10'));
        SetPresetObjectItem(Edit, Obj, 'Crush: Mix', UTF8String('0.85'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('3'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_MALE:
      begin
        SetPresetObjectItem(Edit, Obj, 'Pitch: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Mode', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Semitone', UTF8String('-2'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Window(ms)', UTF8String('110'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Formant', UTF8String('-2.5'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Amount', UTF8String('0.6'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Mix', UTF8String('0.60'));
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('90'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('7600'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('5'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_FEMALE:
      begin
        SetPresetObjectItem(Edit, Obj, 'Pitch: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Mode', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Semitone', UTF8String('2'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Window(ms)', UTF8String('100'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Formant', UTF8String('2.5'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Amount', UTF8String('0.6'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Mix', UTF8String('0.60'));
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('150'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('9000'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('5'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_ROBOT:
      begin
        SetPresetObjectItem(Edit, Obj, 'Ring: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Ring: Frequency(Hz)', UTF8String('95'));
        SetPresetObjectItem(Edit, Obj, 'Ring: Depth', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Ring: Mix', UTF8String('0.90'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Mode', UTF8String('3'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Window(ms)', UTF8String('90'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Step(semi)', UTF8String('3'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Rate(Hz)', UTF8String('7'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Mix', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Crush: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Crush: BitDepth', UTF8String('6'));
        SetPresetObjectItem(Edit, Obj, 'Crush: SampleHold', UTF8String('3'));
        SetPresetObjectItem(Edit, Obj, 'Crush: Mix', UTF8String('0.65'));
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('220'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('4800'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('10'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Release(ms)', UTF8String('45'));
      end;
    SOUND_PRESET_FEAR:
      begin
        SetPresetObjectItem(Edit, Obj, 'Trem: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Trem: Rate(Hz)', UTF8String('11'));
        SetPresetObjectItem(Edit, Obj, 'Trem: Depth', UTF8String('0.75'));
        SetPresetObjectItem(Edit, Obj, 'Trem: Mix', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Delay(ms)', UTF8String('35'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Depth(ms)', UTF8String('28'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Rate(Hz)', UTF8String('0.70'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Mix', UTF8String('0.75'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Mode', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Semitone', UTF8String('-1.5'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Window(ms)', UTF8String('100'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Formant', UTF8String('-2'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Amount', UTF8String('0.5'));
        SetPresetObjectItem(Edit, Obj, 'Pitch: Mix', UTF8String('0.55'));
        SetPresetObjectItem(Edit, Obj, 'Muffle: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Muffle: Cutoff(Hz)', UTF8String('2600'));
        SetPresetObjectItem(Edit, Obj, 'Muffle: Amount', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Muffle: Mix', UTF8String('0.60'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Size(ms)', UTF8String('650'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Feedback', UTF8String('0.55'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Wet', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Mix', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Type', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: RoomSize', UTF8String('0.70'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Damping', UTF8String('0.40'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Wet', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('3'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Release(ms)', UTF8String('60'));
      end;
    SOUND_PRESET_SHOUT:
      begin
        SetPresetObjectItem(Edit, Obj, 'Comp: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Threshold(dB)', UTF8String('-30'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Ratio', UTF8String('8'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Attack(ms)', UTF8String('1.5'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Release(ms)', UTF8String('70'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Makeup(dB)', UTF8String('7'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Drive(dB)', UTF8String('18'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Body', UTF8String('0.65'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Level(dB)', UTF8String('-4'));
        SetPresetObjectItem(Edit, Obj, 'Drive: Mix', UTF8String('0.85'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Mode', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Drive(dB)', UTF8String('10'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Tone', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Level(dB)', UTF8String('-8'));
        SetPresetObjectItem(Edit, Obj, 'Dist: Mix', UTF8String('0.35'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('5'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Release(ms)', UTF8String('25'));
      end;
    SOUND_PRESET_WHISPER:
      begin
        SetPresetObjectItem(Edit, Obj, 'Breath: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Breath: Level(dB)', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Breath: Tone', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Breath: Mix', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('900'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('11000'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Threshold(dB)', UTF8String('-38'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Ratio', UTF8String('2'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Attack(ms)', UTF8String('18'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Release(ms)', UTF8String('260'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Makeup(dB)', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Comp: Mix', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Gate: Use', UTF8String('0'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('9'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_UNDERWATER:
      begin
        SetPresetObjectItem(Edit, Obj, 'Muffle: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Muffle: Cutoff(Hz)', UTF8String('850'));
        SetPresetObjectItem(Edit, Obj, 'Muffle: Amount', UTF8String('0.95'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Delay(ms)', UTF8String('35'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Depth(ms)', UTF8String('22'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Rate(Hz)', UTF8String('0.75'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Mix', UTF8String('0.55'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Stereo Mode', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Delay(ms)', UTF8String('22'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Depth(ms)', UTF8String('9'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Rate(Hz)', UTF8String('0.35'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Mix', UTF8String('0.35'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: RoomSize', UTF8String('0.45'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Damping', UTF8String('0.75'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Wet', UTF8String('0.25'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('14'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_WALL:
      begin
        SetPresetObjectItem(Edit, Obj, 'Muffle: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Muffle: Cutoff(Hz)', UTF8String('650'));
        SetPresetObjectItem(Edit, Obj, 'Muffle: Amount', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'EQ: LowCut(Hz)', UTF8String('120'));
        SetPresetObjectItem(Edit, Obj, 'EQ: HighCut(Hz)', UTF8String('1800'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: RoomSize', UTF8String('0.25'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Damping', UTF8String('0.7'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Wet', UTF8String('0.12'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('6'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
    SOUND_PRESET_DREAM:
      begin
        SetPresetObjectItem(Edit, Obj, 'Wob: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Delay(ms)', UTF8String('34'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Depth(ms)', UTF8String('24'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Rate(Hz)', UTF8String('0.38'));
        SetPresetObjectItem(Edit, Obj, 'Wob: Mix', UTF8String('0.62'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Stereo Mode', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Delay(ms)', UTF8String('28'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Depth(ms)', UTF8String('13'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Rate(Hz)', UTF8String('0.22'));
        SetPresetObjectItem(Edit, Obj, 'Cho: Mix', UTF8String('0.58'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Size(ms)', UTF8String('760'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Feedback', UTF8String('0.52'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Wet', UTF8String('0.42'));
        SetPresetObjectItem(Edit, Obj, 'Ghost: Mix', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Type', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Rev: RoomSize', UTF8String('0.72'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Damping', UTF8String('0.42'));
        SetPresetObjectItem(Edit, Obj, 'Rev: Wet', UTF8String('0.48'));
        SetPresetObjectItem(Edit, Obj, 'Out: Use', UTF8String('1'));
        SetPresetObjectItem(Edit, Obj, 'Out: Gain(dB)', UTF8String('6'));
        SetPresetObjectItem(Edit, Obj, 'Lim: Use', UTF8String('1'));
      end;
  end;
end;

procedure ApplyPresetButton(Edit: PEDIT_SECTION); cdecl;
var
  Obj: OBJECT_HANDLE;
  Preset: Integer;
begin
  if Edit = nil then
    Exit;

  Preset := GSoundPresetSelect.Value;
  ApplyPresetToLocalItems(Preset);

  if not Assigned(Edit^.GetFocusObject) then
    Exit;

  Obj := Edit^.GetFocusObject;
  if Obj = nil then
    Exit;

  ApplyPresetToObjectItems(Edit, Obj, Preset);
end;

procedure AddPresetItems;
begin
  AddPresetItem(0, 'なし', SOUND_PRESET_NONE);
  AddPresetItem(1, 'エコー', SOUND_PRESET_ECHO);
  AddPresetItem(2, '反響', SOUND_PRESET_PING_PONG);
  AddPresetItem(3, 'ホール', SOUND_PRESET_REVERB);
  AddPresetItem(4, '空間', SOUND_PRESET_WIDE);
  AddPresetItem(5, 'ナレーション', SOUND_PRESET_NARRATION);
  AddPresetItem(6, '電話', SOUND_PRESET_TELEPHONE);
  AddPresetItem(7, '無線', SOUND_PRESET_RADIO);
  AddPresetItem(8, '拡声器', SOUND_PRESET_MEGAPHONE);
  AddPresetItem(9, '劣化', SOUND_PRESET_LOW_QUALITY);
  AddPresetItem(10, '男性', SOUND_PRESET_MALE);
  AddPresetItem(11, '女性', SOUND_PRESET_FEMALE);
  AddPresetItem(12, 'ロボ', SOUND_PRESET_ROBOT);
  AddPresetItem(13, '恐怖', SOUND_PRESET_FEAR);
  AddPresetItem(14, '叫び', SOUND_PRESET_SHOUT);
  AddPresetItem(15, '水中', SOUND_PRESET_UNDERWATER);
  AddPresetItem(16, '壁越し', SOUND_PRESET_WALL);
  AddPresetItem(17, '夢/回想', SOUND_PRESET_DREAM);
  AddPresetItem(18, nil, 0);
  AddSelect(GSoundPresetSelect, 'プリセット', SOUND_PRESET_NONE, @GSoundPresetList[0]);
  AddButton(GSoundPresetButton, 'プリセット適用', ApplyPresetButton);
end;

end.
