{
******************************************************************************

  Unit Name : RTTIPersistentForm
  Purpose   : TPersistent 派生オブジェクトのRTTIベース保存・復元支援ユーティリティ

  概要：
    このユニットは、TPersistent を継承したオブジェクトに対し、RTTI を用いて
    プロパティの保存・復元処理を簡略化するためのクラス群を提供します。
    具体的には、INIファイルなどへの保存／読込、フォームの表示位置保存、
    ジェネリックなオブジェクトリストの永続化などに対応しています。

  主なクラス：
    - TRTTIFormPosition     : フォームの位置（Left/Top）を保存・復元
    - TRTTIFormBounds       : 上記に加えてサイズ・WindowState を保存・復元
    - TRTTIPersistentIniList<T> : オブジェクトのリストをファイルで保存・読込

******************************************************************************
}

unit RTTIPersistentForm;

interface

uses
  Windows, Messages, SysUtils, Classes,   Forms, Dialogs,
  StdCtrls, ExtCtrls,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistent,RTTIPersistentIni;

//--------------------------------------------------------------------------//
//  TFormの表示に必要な座標を保存、復元                                     //
//--------------------------------------------------------------------------//
type
	TRTTIFormPosition = class(TRTTIPersistentIni)
	private
		{ Private 宣言 }
    FLeft        : Integer;   //
    FTop         : Integer;
    FMonitor     : Integer;
   function IsWindowPositionVisible(ALeft, ATop: Integer): Boolean;
	public
		{ Public 宣言 }
    // 値を初期化
    procedure InitializeFromForm(aForm : TForm);
    // フォームの座標情報をデータ化
    procedure FormToSelf(aForm : TForm);virtual;
    // データをフォームの情報に復元
    procedure SelfToForm(aForm : TForm);virtual;

  published
    property Monitor   : Integer read FMonitor   write FMonitor;
    property Left   : Integer read FLeft   write FLeft;
    property Top    : Integer read FTop    write FTop;
	end;


//--------------------------------------------------------------------------//
//  TFormの表示に必要な座標を保存、復元                                     //
//--------------------------------------------------------------------------//
type
	TRTTIFormBounds = class(TRTTIFormPosition)
	private
		{ Private 宣言 }
    FWindowState : Integer;   // ウインドウ状態を管理 通常 / 最大化 / 最小化
    FWidth       : Integer;
    FHeight      : Integer;
	public
		{ Public 宣言 }
    // 値を初期化
    procedure InitializeFromForm(aForm : TForm);
    // フォームの座標情報をデータ化
    procedure FormToSelf(aForm : TForm);override;
    // データをフォームの情報に復元
    procedure SelfToForm(aForm : TForm);override;

  published
    property WindowState : Integer read FWindowState write FWindowState;
    property Width  : Integer read FWidth  write FWidth;
    property Height : Integer read FHeight write FHeight;
	end;




implementation

{ TRTTIFormPosition }

procedure TRTTIFormPosition.InitializeFromForm(aForm: TForm);
begin
  FLeft := Screen.Width  div 2 - aForm.Width div 2;  // 初期値は画面中央に配置されるように計算
  FTop  := Screen.Height div 2 - aForm.Height div 2;
end;

function TRTTIFormPosition.IsWindowPositionVisible(ALeft,  ATop: Integer): Boolean;
var
  R: TRect;
  I: Integer;
begin
  Result := False;
  for I := 0 to Screen.MonitorCount - 1 do begin
    R := Screen.Monitors[I].WorkareaRect;
    if PtInRect(R, Point(ALeft, ATop)) then begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TRTTIFormPosition.SelfToForm(aForm: TForm);
var
  Mon: TMonitor;
  WorkArea: TRect;
  aLeft, aTop: Integer;
begin
  // モニタ番号の妥当性チェック
  if (FMonitor < 0) or (FMonitor >= Screen.MonitorCount) then begin
    FMonitor := Screen.PrimaryMonitor.MonitorNum;
  end;

  Mon := Screen.Monitors[FMonitor];
  WorkArea := Mon.WorkareaRect;

  aLeft := WorkArea.Left + FLeft;
  aTop := WorkArea.Top + FTop;

  // モニタ範囲内かチェック
  if IsWindowPositionVisible(aLeft, aTop) then  begin
    aForm.Left := aLeft;
    aForm.Top := aTop;
  end
  else begin
    // フォールバック：中央に表示
    aForm.Position := poDesktopCenter;
  end;
end;

procedure TRTTIFormPosition.FormToSelf(aForm: TForm);
begin
  FMonitor := Screen.MonitorFromWindow(aForm.Handle, mdNearest).MonitorNum;
  aForm.WindowState := wsNormal;
  FLeft := aForm.Left;
  FTop := aForm.Top;
end;

{ TDMFormPosition }

procedure TRTTIFormBounds.InitializeFromForm(aForm: TForm);
begin
  FLeft := Screen.Width  div 2 - aForm.Width div 2;  // 初期値は画面中央に配置されるように計算
  FTop  := Screen.Height div 2 - aForm.Height div 2;
  FWidth := aForm.Width;
  FHeight :=aForm.Height;
end;

procedure TRTTIFormBounds.SelfToForm(aForm: TForm);
begin
  inherited;
  // 通常状態でサイズを先に設定
  aForm.WindowState := wsNormal;
  aForm.Width := FWidth;
  aForm.Height := FHeight;

  if aForm.Width < 100 then aForm.Width := 320;
  if aForm.Height < 100 then aForm.Height := 200;


  // 最後に状態を復元
  if TWindowState(FWindowState) <> wsNormal then
    aForm.WindowState := TWindowState(FWindowState);
end;

procedure TRTTIFormBounds.FormToSelf(aForm: TForm);
begin
  inherited;
  FWindowState := Ord(aForm.WindowState);

  // 最大化／最小化状態では正しいサイズが取れないため、一時的に復元
  if aForm.WindowState <> wsNormal then
    aForm.WindowState := wsNormal;

  FWidth := aForm.Width;
  FHeight := aForm.Height;
end;




end.
