unit AliasManagerObjectList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls,System.Generics.Collections, RTTIPersistentIni,AliasManagerStringList,
  AliasManagerPositionList,AliasManagerFilterList,AliasManagerFilterPsd,
  AliasManagerFilterEyeSyncBlink,AliasManagerFilterLipSyncTalk,
  AliasManagerFilterFace,AliasManagerFilterLipSyncSong,
  AliasManagerFilterPSDAnime,AliasManagerFilterPianoRoll,AliasManagerFilterLyricTelop,
  AliasManagerFilterSerifDraw;

type
  //===========================================================
  // オブジェクトの基底クラス
  //===========================================================
  TAliasManagerObjectItem = class(TRTTIPersistentIni)
  private
    FLayer      : Integer;                        // オブジェクトの表示レイヤー番号
    FFrameStart : Integer;                        // 開始フレーム
    FFrameEnd   : Integer;                        // 終了フレーム
    //FFilters    : TAliasManagerFilterList;      // フィルターの一覧
    FFilters    : TList<TAliasManagerFilterItem>; // 登録されたオブジェクト一覧

    FPositions  : TAliasManagerPositionList;      // 中間フレーム一覧
    FGroup      : Integer;                        // グループ番号
    FUID        : string;                         // セリフ毎に割り振られるID
    // フィルター追加
    function AddFilter<T: TAliasManagerFilterItem, constructor>: T;

    function GetFrameLength: Integer;
    procedure SetFrameLength(const Value: Integer);
    function GetPositionStr: string;
    procedure SetPositionStr(const Value: string);
  protected
    procedure DoSaveToAlias(Strings : TAliasStringList); virtual;abstract;
    // Delphi の文字列中の #13#10（CRLF）を \n に変換する関数
    function CRLFToBackslashN(const S: string): string;
  public
    //function  Add(const ObjectName : string) : TAliasManagerFilterItem;
    procedure SaveToAlias(Strings : TAliasStringList); virtual;

    function AddEyeSyncBlink() : TAliasManagerFilterEyeSyncBlink;
    function AddLipSyncTalk() : TAliasManagerFilterLipSyncTalk;
    function AddLipSyncSong() : TAliasManagerFilterLipSyncSong;
    function AddFace() : TAliasManagerFilterFace;
    function AddPSDAnime() : TAliasManagerFilterPSDAnime;
    function AddPSD() : TAliasManagerFilterPsd;
    function AddPianoRoll : TAliasManagerFilterPianoRoll;
    function AddLyricTelop : TAliasManagerFilterLyricTelop;
    function AddSerifDraw : TAliasManagerFilterSerifDraw;

    property Positions : TAliasManagerPositionList read FPositions;
    property Filters : TList<TAliasManagerFilterItem> read FFilters;
  published
    constructor Create; virtual;
    destructor Destroy; override;
    property Layer       : Integer read FLayer         write FLayer;
    property FrameStart  : Integer read FFrameStart    write FFrameStart;
    property FrameEnd    : Integer read FFrameEnd      write FFrameEnd;
    property FrameLength : Integer read GetFrameLength write SetFrameLength;
    property Group       : Integer read FGroup         write FGroup;
    property PositionStr : string  read GetPositionStr write SetPositionStr;
    property UID         : string  read FUID           write FUID;
  end;

implementation

uses
  AppFolderUtils,
  AliasManagerScriptDress,AliasManagerScriptFace,
  AliasManagerNormalAudio,AliasManagerScriptSerif,
  AliasManagerObjectSound,AliasManagerObjectPicture;

{ TAliasManagerObjectItem }


function TAliasManagerObjectItem.AddFilter<T>: T;
begin
  Result := T.Create;
  FFilters.Add(Result);
end;

function TAliasManagerObjectItem.AddLipSyncSong: TAliasManagerFilterLipSyncSong;
begin
  Result := AddFilter<TAliasManagerFilterLipSyncSong>;
end;

function TAliasManagerObjectItem.AddLipSyncTalk: TAliasManagerFilterLipSyncTalk;
begin
  Result := AddFilter<TAliasManagerFilterLipSyncTalk>;
end;

function TAliasManagerObjectItem.AddLyricTelop: TAliasManagerFilterLyricTelop;
begin
  Result := AddFilter<TAliasManagerFilterLyricTelop>;
end;

function TAliasManagerObjectItem.AddPianoRoll: TAliasManagerFilterPianoRoll;
begin
  Result := AddFilter<TAliasManagerFilterPianoRoll>;
end;

function TAliasManagerObjectItem.AddPSD: TAliasManagerFilterPsd;
begin
  Result := AddFilter<TAliasManagerFilterPsd>;
end;

function TAliasManagerObjectItem.AddPSDAnime: TAliasManagerFilterPSDAnime;
begin
  Result := AddFilter<TAliasManagerFilterPSDAnime>;
end;

function TAliasManagerObjectItem.AddSerifDraw: TAliasManagerFilterSerifDraw;
begin
  Result := AddFilter<TAliasManagerFilterSerifDraw>;
end;

function TAliasManagerObjectItem.AddEyeSyncBlink: TAliasManagerFilterEyeSyncBlink;
begin
  Result := AddFilter<TAliasManagerFilterEyeSyncBlink>;
end;

function TAliasManagerObjectItem.AddFace: TAliasManagerFilterFace;
begin
  Result := AddFilter<TAliasManagerFilterFace>;
end;

constructor TAliasManagerObjectItem.Create;
begin
   FLayer := 2;
   FrameStart := 30;
   FrameEnd := 110;
   //FFilters := TAliasManagerFilterList.Create;
   FFilters := TList<TAliasManagerFilterItem>.Create;
   FPositions := TAliasManagerPositionList.Create;
end;

function TAliasManagerObjectItem.CRLFToBackslashN(const S: string): string;
begin
  // Delphi の改行 #13#10 を AviUtl 用の "\n" に置き換える
  Result := StringReplace(S, #13#10, '\n', [rfReplaceAll]);
end;

destructor TAliasManagerObjectItem.Destroy;
begin
  FPositions.Free;
  FFilters.Free;
  inherited;
end;

procedure TAliasManagerObjectItem.SaveToAlias(Strings: TAliasStringList);
var
  i  : Integer;
begin
  Strings.AddObject(Self);                   // [n] layer= frame= を書き込み
  DoSaveToAlias(Strings);                    // 下位クラスに書き込みを指示
  if Filters = nil then Exit;

  //Filters.SaveToAlias(Strings);              // フィルターに書き込みを指示
  for i := 0 to Filters.Count-1 do begin
    Filters[i].SaveToAlias(Strings);
  end;

end;

function TAliasManagerObjectItem.GetFrameLength: Integer;
begin
 Result := FFrameEnd - FFrameStart;
end;

procedure TAliasManagerObjectItem.SetFrameLength(const Value: Integer);
begin
  FFrameEnd := FFrameStart + Value;
end;

function TAliasManagerObjectItem.GetPositionStr: string;
begin
  Result := FPositions.SerializeToText;
end;

procedure TAliasManagerObjectItem.SetPositionStr(const Value: string);
begin
  FPositions.DeserializeFromText(Value);
end;

end.
