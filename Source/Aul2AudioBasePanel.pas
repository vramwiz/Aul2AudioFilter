unit Aul2AudioBasePanel;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DragAgent,
  Aul2AudioBaseAlias;

type
  TAul2AudioBasePanel = class(TPanel)
  private
    FDrag: TDragShellFile;
    FTitleLabel: TLabel;
    FWidthLabel: TLabel;
    FHeightLabel: TLabel;
    FSecondsLabel: TLabel;
    FFpsLabel: TLabel;
    FLayerLabel: TLabel;
    FStatusLabel: TLabel;
    FWidthEdit: TEdit;
    FHeightEdit: TEdit;
    FSecondsEdit: TEdit;
    FFpsEdit: TEdit;
    FLayerList: TListBox;
    FCreateButton: TPanel;
    FSettingsPanel: TPanel;
    FLayerPanel: TPanel;
    FInitialized: Boolean;
    FDragInitialized: Boolean;
    FLastLayoutWidth: Integer;
    FLastLayoutHeight: Integer;
    procedure CreateControls;
    procedure EnsureDragInitialized;
    procedure CreateButtonClick(Sender: TObject);
    procedure DragRequest(Sender: TObject; FileNames: TStringList);
    procedure SetDarkStyle(Control: TControl);
    function ScalePx(Value: Integer): Integer;
    function GetSelectedLayer: Integer;
    function ReadParams: TAul2AudioBaseAliasParams;
    procedure SetStatus(const Text: string);
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Initialize;
    procedure ReloadLayers;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Graphics,
  Aul2AudioBaseCreate;

const
  UI_BACKGROUND = TColor($00242424);
  UI_PANEL      = TColor($00303030);
  UI_EDIT       = TColor($00202020);
  UI_TEXT       = TColor($00E6E6E6);
  UI_MUTED      = TColor($00B8B8B8);

function ParsePositiveInt(const Text: string; DefaultValue: Integer): Integer;
begin
  Result := StrToIntDef(Trim(Text), DefaultValue);
  if Result <= 0 then
    Result := DefaultValue;
end;

constructor TAul2AudioBasePanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  BevelOuter := bvNone;
  Caption := '';
  Color := UI_BACKGROUND;
  ParentBackground := False;
  ParentFont := False;
  Font.Color := UI_TEXT;
  Font.Name := 'Yu Gothic UI';
  Font.Size := 9;
  DoubleBuffered := True;
  ControlStyle := ControlStyle + [csOpaque];

  FInitialized := False;
  FDragInitialized := False;
  FLastLayoutWidth := -1;
  FLastLayoutHeight := -1;
end;

function TAul2AudioBasePanel.ScalePx(Value: Integer): Integer;
var
  PPI: Integer;
begin
  PPI := Font.PixelsPerInch;
  if PPI <= 0 then
    PPI := 96;

  Result := MulDiv(Value, PPI, 96);
end;

destructor TAul2AudioBasePanel.Destroy;
begin
  FDrag.Free;
  inherited;
end;

procedure TAul2AudioBasePanel.Initialize;
begin
  if FInitialized then
    Exit;

  CreateControls;

  FInitialized := True;
  EnsureDragInitialized;
  ReloadLayers;
  Resize;
end;

procedure TAul2AudioBasePanel.EnsureDragInitialized;
begin
  if FDragInitialized then
    Exit;

  FDrag := TDragShellFile.Create(nil);
  FDrag.Attach(FLayerList);
  FDrag.OnDragRequest := DragRequest;
  FDragInitialized := True;
end;

procedure TAul2AudioBasePanel.SetDarkStyle(Control: TControl);
begin
  if Control is TLabel then
  begin
    TLabel(Control).Transparent := True;
    TLabel(Control).Font.Color := UI_TEXT;
  end
  else if Control is TEdit then
  begin
    TEdit(Control).Color := UI_EDIT;
    TEdit(Control).Font.Color := UI_TEXT;
  end
  else if Control is TListBox then
  begin
    TListBox(Control).Color := UI_EDIT;
    TListBox(Control).Font.Color := UI_TEXT;
    TListBox(Control).ItemHeight := ScalePx(22);
  end
  else if Control is TPanel then
  begin
    TPanel(Control).Color := RGB(74, 74, 74);
    TPanel(Control).Font.Color := UI_TEXT;
    TPanel(Control).ParentBackground := False;
  end;
end;

procedure TAul2AudioBasePanel.CreateControls;
begin
  FSettingsPanel := TPanel.Create(Self);
  FSettingsPanel.Parent := Self;
  FSettingsPanel.BevelOuter := bvNone;
  FSettingsPanel.Caption := '';
  FSettingsPanel.Color := UI_PANEL;
  FSettingsPanel.ParentBackground := False;
  FSettingsPanel.DoubleBuffered := False;

  FLayerPanel := TPanel.Create(Self);
  FLayerPanel.Parent := Self;
  FLayerPanel.BevelOuter := bvNone;
  FLayerPanel.Caption := '';
  FLayerPanel.Color := UI_BACKGROUND;
  FLayerPanel.ParentBackground := False;
  FLayerPanel.DoubleBuffered := False;

  FTitleLabel := TLabel.Create(Self);
  FTitleLabel.Parent := FSettingsPanel;
  FTitleLabel.Caption := 'Base alias';
  FTitleLabel.Visible := False;
  FTitleLabel.Font.Style := [fsBold];
  SetDarkStyle(FTitleLabel);

  FWidthLabel := TLabel.Create(Self);
  FWidthLabel.Parent := FSettingsPanel;
  FWidthLabel.Caption := 'Width';
  SetDarkStyle(FWidthLabel);

  FHeightLabel := TLabel.Create(Self);
  FHeightLabel.Parent := FSettingsPanel;
  FHeightLabel.Caption := 'Height';
  SetDarkStyle(FHeightLabel);

  FSecondsLabel := TLabel.Create(Self);
  FSecondsLabel.Parent := FSettingsPanel;
  FSecondsLabel.Caption := 'Seconds';
  SetDarkStyle(FSecondsLabel);

  FFpsLabel := TLabel.Create(Self);
  FFpsLabel.Parent := FSettingsPanel;
  FFpsLabel.Caption := 'FPS';
  SetDarkStyle(FFpsLabel);

  FWidthEdit := TEdit.Create(Self);
  FWidthEdit.Parent := FSettingsPanel;
  FWidthEdit.Text := '1920';
  SetDarkStyle(FWidthEdit);

  FHeightEdit := TEdit.Create(Self);
  FHeightEdit.Parent := FSettingsPanel;
  FHeightEdit.Text := '1080';
  SetDarkStyle(FHeightEdit);

  FSecondsEdit := TEdit.Create(Self);
  FSecondsEdit.Parent := FSettingsPanel;
  FSecondsEdit.Text := '30';
  SetDarkStyle(FSecondsEdit);

  FFpsEdit := TEdit.Create(Self);
  FFpsEdit.Parent := FSettingsPanel;
  FFpsEdit.Text := '30';
  SetDarkStyle(FFpsEdit);

  FCreateButton := TPanel.Create(Self);
  FCreateButton.Parent := Self;
  FCreateButton.Caption := '選択レイヤーへ作成';
  FCreateButton.BevelOuter := bvLowered;
  FCreateButton.Cursor := crHandPoint;
  FCreateButton.Alignment := taCenter;
  FCreateButton.OnClick := CreateButtonClick;
  SetDarkStyle(FCreateButton);

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.Caption := '';
  FStatusLabel.Font.Color := UI_MUTED;
  FStatusLabel.WordWrap := True;
  SetDarkStyle(FStatusLabel);
  FStatusLabel.Font.Color := UI_MUTED;

  FLayerLabel := TLabel.Create(Self);
  FLayerLabel.Parent := FLayerPanel;
  FLayerLabel.Caption := 'Layer';
  FLayerLabel.Visible := False;
  FLayerLabel.Font.Style := [fsBold];
  SetDarkStyle(FLayerLabel);

  FLayerList := TListBox.Create(Self);
  FLayerList.Parent := FLayerPanel;
  FLayerList.Style := lbStandard;
  FLayerList.IntegralHeight := False;
  SetDarkStyle(FLayerList);
end;

procedure TAul2AudioBasePanel.Resize;
var
  Margin: Integer;
  LabelW: Integer;
  EditW: Integer;
  PanelH: Integer;
  SettingsW: Integer;
  LayerW: Integer;
  SendW: Integer;
  StatusW: Integer;
  X: Integer;
  Row1: Integer;
  Row2: Integer;

  procedure SetBoundsIfChanged(Control: TControl; ALeft, ATop, AWidth, AHeight: Integer);
  begin
    if Control = nil then
      Exit;

    if AWidth < 1 then
      AWidth := 1;
    if AHeight < 1 then
      AHeight := 1;

    if (Control.Left <> ALeft) or (Control.Top <> ATop) or
       (Control.Width <> AWidth) or (Control.Height <> AHeight) then
      Control.SetBounds(ALeft, ATop, AWidth, AHeight);
  end;
begin
  inherited;

  if not FInitialized then
    Exit;

  if (Width = FLastLayoutWidth) and (Height = FLastLayoutHeight) then
    Exit;
  FLastLayoutWidth := Width;
  FLastLayoutHeight := Height;

  Margin := ScalePx(6);
  LabelW := ScalePx(58);
  EditW := ScalePx(66);
  SettingsW := ScalePx(320);
  LayerW := ScalePx(170);
  SendW := ScalePx(180);
  PanelH := Height - Margin * 2;
  if PanelH < ScalePx(60) then
    PanelH := ScalePx(60);
  if PanelH > ScalePx(74) then
    PanelH := ScalePx(74);

  DisableAlign;
  try
    SetBoundsIfChanged(FSettingsPanel, Margin, Margin, SettingsW, PanelH);
    SetBoundsIfChanged(FLayerPanel, FSettingsPanel.Left + FSettingsPanel.Width + Margin, Margin, LayerW, PanelH);

    X := ScalePx(8);
    Row1 := ScalePx(7);
    Row2 := ScalePx(39);
    SetBoundsIfChanged(FTitleLabel, X, Row1 + ScalePx(2), 1, 1);

    SetBoundsIfChanged(FWidthLabel, X, Row1 + ScalePx(4), LabelW, ScalePx(20));
    Inc(X, LabelW);
    SetBoundsIfChanged(FWidthEdit, X, Row1, EditW, ScalePx(24));

    Inc(X, EditW + ScalePx(10));
    SetBoundsIfChanged(FHeightLabel, X, Row1 + ScalePx(4), LabelW, ScalePx(20));
    Inc(X, LabelW);
    SetBoundsIfChanged(FHeightEdit, X, Row1, EditW, ScalePx(24));

    X := ScalePx(8);
    SetBoundsIfChanged(FSecondsLabel, X, Row2 + ScalePx(4), LabelW, ScalePx(20));
    Inc(X, LabelW);
    SetBoundsIfChanged(FSecondsEdit, X, Row2, EditW, ScalePx(24));

    Inc(X, EditW + ScalePx(10));
    SetBoundsIfChanged(FFpsLabel, X, Row2 + ScalePx(4), LabelW, ScalePx(20));
    Inc(X, LabelW);
    SetBoundsIfChanged(FFpsEdit, X, Row2, EditW, ScalePx(24));

    SetBoundsIfChanged(FCreateButton, FLayerPanel.Left + FLayerPanel.Width + Margin, Margin, SendW, ScalePx(32));

    StatusW := Width - FCreateButton.Left - FCreateButton.Width - Margin * 2;
    if StatusW < ScalePx(120) then
      StatusW := ScalePx(120);
    SetBoundsIfChanged(FStatusLabel, FCreateButton.Left + FCreateButton.Width + Margin, Margin, StatusW, PanelH);

    SetBoundsIfChanged(FLayerLabel, 0, 0, 1, 1);
    SetBoundsIfChanged(FLayerList, 0, 0, FLayerPanel.Width, FLayerPanel.Height);
  finally
    EnableAlign;
  end;

  if HandleAllocated then
    RedrawWindow(Handle, nil, 0, RDW_INVALIDATE or RDW_NOERASE or RDW_ALLCHILDREN);
end;

procedure TAul2AudioBasePanel.ReloadLayers;
var
  I: Integer;
  LayerCount: Integer;
begin
  if not FInitialized then
    Exit;

  FLayerList.Items.BeginUpdate;
  try
    FLayerList.Items.Clear;
    LayerCount := 100;

    for I := 0 to LayerCount - 1 do
      FLayerList.Items.Add('レイヤー ' + IntToStr(I + 1));

    if FLayerList.Items.Count > 0 then
      FLayerList.ItemIndex := 0;
  finally
    FLayerList.Items.EndUpdate;
  end;
end;

function TAul2AudioBasePanel.GetSelectedLayer: Integer;
begin
  Result := FLayerList.ItemIndex;
  if Result < 0 then
    Result := 0;
end;

function TAul2AudioBasePanel.ReadParams: TAul2AudioBaseAliasParams;
begin
  Result := DefaultBaseAliasParams;
  Result.Width := ParsePositiveInt(FWidthEdit.Text, Result.Width);
  Result.Height := ParsePositiveInt(FHeightEdit.Text, Result.Height);
  Result.MaxSec := ParsePositiveInt(FSecondsEdit.Text, Result.MaxSec);
  Result.Rate := ParsePositiveInt(FFpsEdit.Text, Result.Rate);
  Result.Scale := 1;
  Result.Layer := GetSelectedLayer;
  Result.FrameStart := GetCurrentEditFrame;
  Result.FrameLength := Result.MaxSec * Result.Rate div Result.Scale;
end;

procedure TAul2AudioBasePanel.SetStatus(const Text: string);
begin
  FStatusLabel.Caption := Text;
end;

procedure TAul2AudioBasePanel.CreateButtonClick(Sender: TObject);
var
  Params: TAul2AudioBaseAliasParams;
begin
  Params := ReadParams;
  if CreateBaseAliasObject(GetSelectedLayer, Params) <> nil then
    SetStatus('作成しました: ' + BuildBaseVirtualFileName(Params))
  else
    SetStatus('作成できませんでした。AviUtl2 の編集ハンドルを確認してください。');
end;

procedure TAul2AudioBasePanel.DragRequest(Sender: TObject; FileNames: TStringList);
var
  Params: TAul2AudioBaseAliasParams;
  FileName: string;
begin
  Params := ReadParams;
  FileName := SaveBaseAliasFile(Params);
  FileNames.Add(FileName);
  SetStatus('D&D 用エイリアスを作成: ' + ExtractFileName(FileName));
end;

end.
