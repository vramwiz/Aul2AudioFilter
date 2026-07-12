unit Aul2AudioViewRenderFilledSpectrum;

// スペクトラム値を下端から連続して塗り、Filled Spectrum を描画する。

interface

uses
  Aul2AudioFilterTypes,
  Aul2AudioViewParams;

// 現在フレームのスペクトラムを下端から塗り、透明 RGBA バッファへ描画する。
procedure DrawFilledSpectrum(Buffer: PPIXEL_RGBA; Width, Height: Integer;
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

const
  VIEW_MARGIN_X = 0; // 将来 GUI 設定へ昇格できるよう、描画領域の左右余白を名前付きで保持する。
  VIEW_MARGIN_Y = 0; // 将来 GUI 設定へ昇格できるよう、描画領域の上下余白を名前付きで保持する。

function BandValue(const Settings: TAul2AudioViewSettings; Index, Count: Integer): Single;
begin
  Result := GetSpectrumDisplayValue(CurrentBands, CurrentBandsValid,
    CurrentSourceMinHz, CurrentSourceMaxHz, Settings, Index, Count);
end;

procedure DrawSolidFilled(Buffer: PPIXEL_RGBA; Width, Height, AreaW, AreaH,
  MarginX, BaseY: Integer; const Settings: TAul2AudioViewSettings);
var
  X: Integer;
  FillH: Integer;
  TopY: Integer;
  R, G, B: Byte;
begin
  for X := 0 to AreaW - 1 do
  begin
    FillH := Round(AreaH * BandValue(Settings, X, AreaW));
    if FillH <= 0 then
      Continue;

    GetViewColor(Settings, X, AreaW, R, G, B);

    TopY := BaseY - FillH + 1;
    // 上端の白線は周波数ごとの振幅輪郭を背景色から分離する。
    FillRect(Buffer, Width, Height, MarginX + X, TopY, MarginX + X, BaseY, R, G, B, 255);
    FillRect(Buffer, Width, Height, MarginX + X, TopY, MarginX + X, TopY + 1, 255, 255, 255, 255);
  end;
end;

procedure DrawBlockFilled(Buffer: PPIXEL_RGBA; Width, Height, AreaW, AreaH,
  MarginX, BaseY: Integer; const Settings: TAul2AudioViewSettings);
var
  Gap: Integer;
  BlockH: Integer;
  BlockCount: Integer;
  FillCount: Integer;
  X: Integer;
  Block: Integer;
  Y2: Integer;
  R, G, B: Byte;
begin
  Gap := Max(0, Min(32, Settings.Spacing));
  BlockH := Max(1, AreaH div Max(6, Min(64, Settings.Density)));
  BlockCount := Max(1, (AreaH + Gap) div Max(1, BlockH + Gap));

  for X := 0 to AreaW - 1 do
  begin
    FillCount := Round(BlockCount * BandValue(Settings, X, AreaW));
    if FillCount <= 0 then
      Continue;

    GetViewColor(Settings, X, AreaW, R, G, B);
    for Block := 0 to FillCount - 1 do
    begin
      Y2 := BaseY - Block * (BlockH + Gap);
      FillRect(Buffer, Width, Height, MarginX + X, Y2 - BlockH + 1, MarginX + X, Y2, R, G, B, 255);
    end;

    // ブロック表示でも最上段へ輪郭線を置き、Solid と同じ振幅位置を読み取れるようにする。
    Y2 := BaseY - FillCount * (BlockH + Gap) + Gap;
    FillRect(Buffer, Width, Height, MarginX + X, Y2, MarginX + X, Y2 + 1, 255, 255, 255, 255);
  end;
end;

procedure DrawFilledSpectrum(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Settings: TAul2AudioViewSettings; CurrentFrame: Integer);
var
  MarginX: Integer;
  MarginY: Integer;
  AreaW: Integer;
  AreaH: Integer;
  BaseY: Integer;
begin
  if (Buffer = nil) or (Width <= 0) or (Height <= 0) then
    Exit;

  ClearPixels(Buffer, Width, Height);
  UpdateViewSpectrum(Settings.Smooth, CurrentBands, CurrentBandsValid,
    CurrentSourceMinHz, CurrentSourceMaxHz, CurrentFrame, Settings.SourceLayer);

  MarginX := VIEW_MARGIN_X;
  MarginY := VIEW_MARGIN_Y;
  AreaW := Width - (MarginX * 2);
  AreaH := Height - (MarginY * 2);
  if (AreaW <= 0) or (AreaH <= 0) then
    Exit;

  BaseY := Height - MarginY - 1;

  if Settings.Style = VIEW_STYLE_BLOCKS then
    DrawBlockFilled(Buffer, Width, Height, AreaW, AreaH, MarginX, BaseY, Settings)
  else
    DrawSolidFilled(Buffer, Width, Height, AreaW, AreaH, MarginX, BaseY, Settings);
end;

end.
