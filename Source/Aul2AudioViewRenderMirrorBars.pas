unit Aul2AudioViewRenderMirrorBars;

// スペクトラム値を画面中央から上下対称に伸びるバーへ変換し、Mirror Bars を描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 現在フレームのスペクトラムを上下対称のバーとして透明 RGBA バッファへ描画する。
procedure DrawMirrorBars(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);

implementation

uses
  System.Math,
  Aul2AudioMonitorSpectrumShared,
  Aul2AudioViewRenderUtils,
  Aul2AudioViewSpectrum;

var
  CurrentBands      : TAudioMonitorSpectrumData;
  CurrentBandsValid : Boolean;
  CurrentSourceMinHz: Single;
  CurrentSourceMaxHz: Single;

function BandValue(const Settings: TAul2AudioViewSettings; Index, Count: Integer): Single;
begin
  Result := GetSpectrumDisplayValue(CurrentBands, CurrentBandsValid,
    CurrentSourceMinHz, CurrentSourceMaxHz, Settings, Index, Count);
end;

procedure DrawSolidMirror(Buffer: PPIXEL_RGBA; Width, Height, AreaW, HalfH,
  CenterY: Integer; const Settings: TAul2AudioViewSettings);
var
  Count: Integer;
  BarW: Integer;
  I: Integer;
  X: Integer;
  Value: Single;
  BarH: Integer;
  R, G, B: Byte;
begin
  Count := Max(4, Min(128, Settings.Density));
  BarW := Max(1, AreaW div Count);

  for I := 0 to Count - 1 do
  begin
    Value := Max(0.0, Min(1.0, BandValue(Settings, I, Count)));
    BarH := Round(HalfH * Value);
    if BarH <= 0 then
      Continue;

    X := I * BarW;
    GetViewColor(Settings, I, Count, R, G, B);
    // 中央線を空けて上下を分離し、対称形の基準位置を見失わないようにする。
    FillRect(Buffer, Width, Height, X, CenterY - BarH, X + BarW - 1, CenterY - 1, R, G, B, 255);
    FillRect(Buffer, Width, Height, X, CenterY + 1, X + BarW - 1, CenterY + BarH, R, G, B, 255);
  end;
end;

procedure DrawBlockMirror(Buffer: PPIXEL_RGBA; Width, Height, AreaW, HalfH,
  CenterY: Integer; const Settings: TAul2AudioViewSettings);
var
  Count: Integer;
  Gap: Integer;
  BarW: Integer;
  BlockH: Integer;
  BlockCount: Integer;
  FillCount: Integer;
  I: Integer;
  X: Integer;
  Block: Integer;
  TopY: Integer;
  BottomY: Integer;
  R, G, B: Byte;
begin
  Count := Max(4, Min(128, Settings.Density));
  Gap := Max(0, Min(32, Settings.Spacing));
  BarW := Max(1, (AreaW - (Gap * (Count - 1))) div Count);
  BlockH := Max(1, Round(Max(1, BarW) * 0.62));
  BlockCount := Max(1, (HalfH + Gap) div Max(1, BlockH + Gap));

  for I := 0 to Count - 1 do
  begin
    FillCount := Round(BlockCount * Max(0.0, Min(1.0, BandValue(Settings, I, Count))));
    if FillCount <= 0 then
      Continue;

    X := I * (BarW + Gap);
    GetViewColor(Settings, I, Count, R, G, B);
    for Block := 0 to FillCount - 1 do
    begin
      TopY := CenterY - 1 - Block * (BlockH + Gap);
      BottomY := CenterY + 1 + Block * (BlockH + Gap);
      FillRect(Buffer, Width, Height, X, TopY - BlockH + 1, X + BarW - 1, TopY, R, G, B, 255);
      FillRect(Buffer, Width, Height, X, BottomY, X + BarW - 1, BottomY + BlockH - 1, R, G, B, 255);
    end;
  end;
end;

procedure DrawMirrorBars(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
var
  CenterY: Integer;
  HalfH: Integer;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  UpdateViewSpectrum(Settings.Smooth, CurrentBands, CurrentBandsValid,
    CurrentSourceMinHz, CurrentSourceMaxHz, CurrentFrame, Settings.SourceLayer);

  CenterY := Height div 2;
  // 奇数・偶数どちらの高さでも上下が画像範囲へ収まる短い側を描画半径にする。
  HalfH := Max(1, Min(CenterY, Height - CenterY - 1));
  if Settings.Style = VIEW_STYLE_BLOCKS then
    DrawBlockMirror(Buffer, Width, Height, Width, HalfH, CenterY, Settings)
  else
    DrawSolidMirror(Buffer, Width, Height, Width, HalfH, CenterY, Settings);
end;

end.
