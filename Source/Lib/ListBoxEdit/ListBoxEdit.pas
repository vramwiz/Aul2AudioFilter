{******************************************************************************
  Unit Name  : ListBoxEdit
  Class      : TListBoxEdit
  Author     : （あなた）
  Purpose    :
    TListBox を拡張し、リスト項目をその場で編集できる
    “インライン編集対応 ListBox” を提供するユニットです。

  Features :
    - 編集したい行の上に TEdit を重ねて配置し、その場で文字列編集が可能
    - Items[] とは独立した「データ責務」を想定しており、
      データ要求・編集開始・編集確定はイベントで外部へ通知
    - 編集開始時の文字列取得や、表示用文字列の取得は
      DoGetDisplayText / DoGetEditText / DoApplyEdit を通して行う
    - TListBox 側は「表示と編集機能のみを担当し、データを保持しない」
      という責任分離を実現

  Event Model :
    * OnGetDisplayText(Index, var Text)
        表示用の文字列を外部から取得（未実装なら Items[Index] を使用）

    * OnGetEditText(Index, var EditText)
        編集開始時に編集用の文字列を要求（未実装なら Items[Index] を使用）

    * OnApplyEdit(Index, var NewText)
        編集確定後、外部側へ “変更後文字列” を通知し、
        必要なら外部で書き換えも可能

  Usage :
    - ダブルクリックなどで DoBeginEdit(Index) を呼び出すか、
      OnDblClick 内で BeginEdit を呼ぶ
    - 編集確定は Enter、キャンセルは Esc
    - 編集確定後は OnApplyEdit で文字列を外部へ返し、
      本コンポーネントは Items[Index] を自動更新

  Notes :
    - 本クラスは OwnerDrawFixed を前提にしており、
      DrawItem は継承側で自由にカスタマイズ可能
    - TEdit の見た目と ListBox の行高さは一致しない場合があるため、
      必要に応じて微調整を行う想定

******************************************************************************}

unit ListBoxEdit;

interface

uses
  System.Classes, System.SysUtils, Winapi.Windows,
  Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.Menus;

type
  //===========================================================
  // イベント型
  //===========================================================

  // 表示用文字列要求
  TGetDisplayTextEvent = procedure(Sender: TObject; Index: Integer; var Text: string) of object;

  // 編集開始時の文字列要求
  TGetEditTextEvent = procedure(Sender: TObject; Index: Integer; var Text: string) of object;

  // 編集確定（ユーザー変更可能）
  TEditedEvent = procedure(Sender: TObject; Index: Integer; var NewText: string) of object;

type
  //===========================================================
  // 1行編集用汎用 ListBox
  //===========================================================
  TListBoxEdit = class(TListBox)
  private
    //--- 編集用 ------------------------------------------------
    FEdit: TEdit;            // 編集用コントロール
    FEditingIndex: Integer;  // 編集中アイテム
    FIsEditing: Boolean;     // 編集中フラグ
    FCharaHeight: Integer;   // 上部余白（外部で設定）

    //--- PopupMenu 保護 ----------------------------------------
    FSavedPopup: TPopupMenu;

    //--- イベント ----------------------------------------------
    FOnGetDisplayText: TGetDisplayTextEvent;
    FOnGetEditText:    TGetEditTextEvent;
    FOnEdited:         TEditedEvent;

    //--- 内部処理 ----------------------------------------------
    procedure InitEdit;
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EditExit(Sender: TObject);

  protected
    procedure CreateWnd; override;

    // OwnerDraw の表示
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;

    procedure DoBeginEdit(Index: Integer);virtual;
    procedure DoEndEdit(AEditingIndex : Integer;Apply: Boolean);virtual;

    procedure DoGetDisplayText(Index: Integer; var Text: string); virtual;
    procedure DoGetEditText(Index: Integer; var Text: string); virtual;
    procedure DoEdited(Index: Integer; var NewText: string); virtual;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure BeginEdit(Index: Integer);
    procedure EndEdit(ApplyChanges: Boolean);

    function IsEditing: Boolean;

    // 外部が設定する上部余白（配役など）
    property CharaHeight: Integer read FCharaHeight write FCharaHeight;

    // イベント公開
    property OnGetDisplayText: TGetDisplayTextEvent read FOnGetDisplayText write FOnGetDisplayText;
    property OnGetEditText:    TGetEditTextEvent   read FOnGetEditText    write FOnGetEditText;
    property OnEdited:         TEditedEvent        read FOnEdited         write FOnEdited;
  end;


type
  TListBoxEditColor = class(TListBoxEdit)
	private
		{ Private 宣言 }
  protected
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    // 背景の塗りつぶし
    procedure DrawItemBackground(Canvas: TCanvas; Index: Integer;Rect: TRect; State: TOwnerDrawState);
    // 文字描画
    procedure DrawTextOut(Canvas: TCanvas;Rect: TRect;State: TOwnerDrawState; const str: string);
  public
		{ Public 宣言 }
  end;


implementation

{---------------------------------------------------------------}
{ Constructor / Destructor                                       }
{---------------------------------------------------------------}

constructor TListBoxEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Style := lbOwnerDrawFixed;

  Color := RGB(32, 32, 32);
  FEditingIndex := -1;
  FIsEditing := False;
  FCharaHeight := 0;

  FSavedPopup := PopupMenu;

  InitEdit;
end;

destructor TListBoxEdit.Destroy;
begin
  FEdit.Free;
  inherited Destroy;
end;

{---------------------------------------------------------------}
{ Window                                                         }
{---------------------------------------------------------------}

procedure TListBoxEdit.CreateWnd;
begin
  inherited CreateWnd;
end;

{---------------------------------------------------------------}
{ 編集用 TEdit の構築                                           }
{---------------------------------------------------------------}

procedure TListBoxEdit.InitEdit;
begin
  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.BevelOuter := bvNone;
  FEdit.BevelInner := bvNone;
  //FEdit.AutoSize := true;
  FEdit.Visible := False;
  FEdit.PopupMenu := nil;
  FEdit.Color := RGB(32, 32, 32);
  FEdit.Font.Color := RGB(230, 230, 230);
  FEdit.AutoSize := False;

  FEdit.OnKeyDown := EditKeyDown;
  FEdit.OnExit := EditExit;
end;

{---------------------------------------------------------------}
{ 表示文字列要求（virtual）                                     }
{---------------------------------------------------------------}

procedure TListBoxEdit.DoGetDisplayText(Index: Integer; var Text: string);
begin
  if Assigned(FOnGetDisplayText) then
    FOnGetDisplayText(Self, Index, Text);
end;

{---------------------------------------------------------------}
{ 編集開始文字列要求（virtual）                                 }
{---------------------------------------------------------------}

procedure TListBoxEdit.DoGetEditText(Index: Integer; var Text: string);
begin
  if Assigned(FOnGetEditText) then
    FOnGetEditText(Self, Index, Text);
end;

{---------------------------------------------------------------}
{ 編集確定（virtual / var Text で外部が変更可）                  }
{---------------------------------------------------------------}

procedure TListBoxEdit.DoEdited(Index: Integer; var NewText: string);
begin
  if Assigned(FOnEdited) then
    FOnEdited(Self, Index, NewText);
end;

{---------------------------------------------------------------}
{ 編集開始                                                       }
{---------------------------------------------------------------}

procedure TListBoxEdit.BeginEdit(Index: Integer);
begin
  if (Index < 0) or (Index >= Items.Count) then Exit;
  DoBeginEdit(Index);
end;

procedure TListBoxEdit.DoBeginEdit(Index: Integer);
var
  R: TRect;
  S: string;
begin
  FEditingIndex := Index;
  FIsEditing := True;

  // 編集開始文字列（既定は Items[Index]）
  S := Items[Index];
  DoGetEditText(Index, S);
  // ListBox側で確定したDPI対応フォントを、編集開始時にそのまま反映する。
  FEdit.Font.Assign(Font);

  // アイテム矩形
  R := ItemRect(Index);

  // 上部余白を避ける
  Inc(R.Top, FCharaHeight);

  // 表示行と同じ領域へ重ね、表示時と編集中の文字サイズ・行高を揃える。
  FEdit.SetBounds(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
  FEdit.Text := S;
  FEdit.Visible := True;
  FEdit.SelectAll;
  FEdit.SetFocus;
end;

{---------------------------------------------------------------}
{ 編集終了                                                       }
{---------------------------------------------------------------}

procedure TListBoxEdit.EndEdit(ApplyChanges: Boolean);
begin
  DoEndEdit(FEditingIndex,ApplyChanges);
end;

procedure TListBoxEdit.DoEndEdit(AEditingIndex : Integer;Apply: Boolean);
var
  NewText: string;
begin
  if FEditingIndex < 0 then Exit;
  if FIsEditing = False then Exit;

  if Apply then
  begin
    // 編集結果取得
    NewText := FEdit.Text;

    // 外部に修正してもらう
    DoEdited(FEditingIndex, NewText);
    FIsEditing := False;

    // 最終結果を Items に保存（このクラスの責務）
    Items[FEditingIndex] := NewText;
  end;

  FEdit.Visible := False;
  FEditingIndex := -1;

  Invalidate;  // 表示更新
end;

function TListBoxEdit.IsEditing: Boolean;
begin
  Result := FIsEditing;
end;

{---------------------------------------------------------------}
{ TEdit のキーハンドリング                                       }
{---------------------------------------------------------------}

procedure TListBoxEdit.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    Key := 0;
    DoEndEdit(FEditingIndex,True);
    Exit;
  end;

  if Key = VK_ESCAPE then
  begin
    Key := 0;
    DoEndEdit(FEditingIndex,False);
    Exit;
  end;
end;

procedure TListBoxEdit.EditExit(Sender: TObject);
begin
  DoEndEdit(FEditingIndex,True);
end;

{---------------------------------------------------------------}
{ 描画（OwnerDrawFixed）                                         }
{---------------------------------------------------------------}

procedure TListBoxEdit.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  S: string;
begin
  S := Items[Index];
  DoGetDisplayText(Index, S);

  Canvas.FillRect(Rect);
  Canvas.TextOut(Rect.Left + 4, Rect.Top, S);
end;

const
  COLOR_CURSOL = clNavy;


{ TListBoxEditColor }

procedure TListBoxEditColor.DrawItem(Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  cv : TCanvas;
  s :string;
begin
  cv := Canvas;
  DrawItemBackground(cv,Index,Rect,State);
  s := Items.Strings[Index];
  DrawTextOut(cv,Rect,State,s);
end;


procedure TListBoxEditColor.DrawItemBackground(
  Canvas: TCanvas; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  cF, cB: TColor;
begin
  cB := RGB(32, 32, 32);
  // 通常背景
  case Index mod 3 of
    0: cB := RGB(32, 32, 32);
    1: cB := RGB(36, 36, 36);
    2: cB := RGB(40, 40, 40);
  end;

  cF := RGB(230, 230, 230);

  // 選択
  if (odSelected in State) then
  begin
    cB := RGB(0, 120, 215);
    cF := clWhite;
  end;

  Canvas.Brush.Color := cB;
  Canvas.Font.Color  := cF;
  Canvas.FillRect(Rect);
end;

procedure TListBoxEditColor.DrawTextOut(Canvas: TCanvas; Rect: TRect;  State: TOwnerDrawState; const str: string);
var
  cv : TCanvas;
begin
  cv := Canvas;
  if (odFocused in State) or (odSelected in State)  then begin
    Canvas.Brush.Color := COLOR_CURSOL ;
    Canvas.Font.Color  := clWhite;
  end;
  cv.TextRect(Rect,Rect.Left+5,Rect.Top+3,str);
end;

end.

