unit AviUtl2Alias;

interface

  uses
  System.SysUtils,   // string, FileName操作, FormatDateTime など
  System.Classes,    // TStringList, TStrings
  System.IOUtils;    // TFile.ReadAllBytes 等（LoadFileText 内で使用）

type
  TAviUtl2Alias = class
  private
    FStrings: TStringList;
    function GetText: string;
    procedure SetText(const Value: string);
  public
    constructor Create;
    destructor Destroy; override;

    // TStringList 風 API
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);

    // テキスト= プロパティ
    property Text: string read GetText write SetText;
  end;

function AviUtl2AliasDandD(const FileName, Text : string): string;

implementation

uses AliasManager,AviUtl2TimeConvert,AliasManagerObjectSound,SoundFileUtils,
     Math,TextEncodingUtils;


procedure ReplaceTextValue(Strings: TStrings; const Text: string);
var
  i: Integer;
  S: string;
  P: Integer;
  Key: string;
begin
  for i := 0 to Strings.Count - 1 do
  begin
    S := Strings[i];

    // key=value 形式のみ対象（= が無い行は無視）
    P := Pos('=', S);
    if P <= 0 then
      Continue;

    Key := Copy(S, 1, P - 1);

    if Key = 'テキスト' then
      Strings[i] := 'テキスト=' + Text;
  end;
end;


{
function LoadFileText(const FileName: string): string;
var
  SL : TStringList;
  S  : string;
begin
  SL := TStringList.Create;
  try
    // ① UTF-8（BOMあり／なし）を最優先で試す
    try
      SL.LoadFromFile(FileName, TEncoding.UTF8);
      S := SL.Text;

      // UTF-8 として読めたが内容が怪しい場合
      if Pos(#$FFFD, S) > 0 then
        raise Exception.Create('Invalid UTF-8');
    except
      // ② UTF-8 失敗 → Shift-JIS (CP932)
      SL.Clear;
      SL.LoadFromFile(FileName, TEncoding.GetEncoding(932));
      S := SL.Text;
    end;

    Result := S;
  finally
    SL.Free;
  end;
end;
}

procedure SaveStringsAsUtf8NoBom(const FileName: string; Strings: TStrings);
var
  Utf8: TEncoding;
begin
  Utf8 := TUTF8Encoding.Create(False); // BOMなし
  try
    Strings.SaveToFile(FileName, Utf8);
  finally
    Utf8.Free;
  end;
end;

function AviUtl2AliasDandD(const FileName, Text: string): string;
var
  SaveFileName: string;
  SL: TStringList;
begin
  // 保存先ファイル名を取得
  SaveFileName := GAliasManager.FileName;

  SL := TStringList.Create;
  try
    // 入力ファイルを読み込む
    // ※ 文字コード混在対応済みの LoadFileText を使用する前提
    SL.Text := LoadTextAutoEncoding(FileName);

    // テキスト= の値をすべて置換
    ReplaceTextValue(SL, Text);

    // BOMなし UTF-8 で保存
    SaveStringsAsUtf8NoBom(SaveFileName, SL);
  finally
    SL.Free;
  end;

  Result := SaveFileName;
end;


{ TAviUtl2Alias }

constructor TAviUtl2Alias.Create;
begin
  inherited Create;
  FStrings := TStringList.Create;
end;

destructor TAviUtl2Alias.Destroy;
begin
  FStrings.Free;
  inherited Destroy;
end;

procedure TAviUtl2Alias.LoadFromFile(const FileName: string);
begin
  FStrings.Clear;

  // 念のため存在チェック
  if not FileExists(FileName) then
    Exit;

  // 文字コード混在対応済み関数を使用
  FStrings.Text := LoadTextAutoEncoding(FileName);
end;

procedure TAviUtl2Alias.SaveToFile(const FileName: string);
var
  Utf8: TEncoding;
begin
  Utf8 := TUTF8Encoding.Create(False); // BOMなし UTF-8
  try
    FStrings.SaveToFile(FileName, Utf8);
  finally
    Utf8.Free;
  end;
end;

function TAviUtl2Alias.GetText: string;
var
  i, P: Integer;
  S: string;
begin
  Result := '';

  for i := 0 to FStrings.Count - 1 do
  begin
    S := FStrings[i];
    P := Pos('=', S);
    if P <= 0 then
      Continue;

    if Copy(S, 1, P - 1) = 'テキスト' then
    begin
      Result := Copy(S, P + 1, MaxInt);
      Exit;
    end;
  end;
end;

procedure TAviUtl2Alias.SetText(const Value: string);
var
  i, P: Integer;
  S: string;
begin
  for i := 0 to FStrings.Count - 1 do
  begin
    S := FStrings[i];
    P := Pos('=', S);
    if P <= 0 then
      Continue;

    if Copy(S, 1, P - 1) = 'テキスト' then
      FStrings[i] := 'テキスト=' + Value;
  end;
end;

end.
