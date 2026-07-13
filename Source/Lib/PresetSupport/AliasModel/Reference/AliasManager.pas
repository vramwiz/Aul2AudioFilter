unit AliasManager;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, System.Generics.Collections,RTTIPersistentIni,
  AliasManagerStringList,
  AliasManagerFilterList,AliasManagerObjectList,
    AppFolderUtils,AliasManagerFilterPsd,
  AliasManagerScriptDress,AliasManagerScriptFace,
  AliasManagerNormalAudio,AliasManagerScriptSerif,AliasManagerFilterLipSyncTalk,
  AliasManagerObjectSound,AliasManagerObjectPicture,AliasManagerFilterEyeSyncBlink,
  AliasManagerScriptSong,AliasManagerObjectVideoFile,AliasManagerInputBase;


type
  //===========================================================
  // AliasManager 本体
  //===========================================================
  TAliasManager = class(TRTTIPersistentIni)
  private
    FObjects    : TList<TAliasManagerObjectItem>;  // 登録されたオブジェクト一覧
    FStrings    : TAliasStringList;         // 生成途中のエリアス文字列バッファ
    FFileName   : string;
    function AddObject<T: TAliasManagerObjectItem, constructor>: T;
    function GetObjectName: string;
    procedure SetObjectName(const Value: string);                   // 出力ファイル名
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;
    //function  Add(const ObjectName : string) : TAliasManagerObjectItem;
    // PSDオブジェクト作成
    function  AddDress()       : TAliasManagerScriptDress;
    function  AddFace()        : TAliasManagerScriptFace;
    function  AddAudio()       : TAliasManagerNormalAudio;
    function  AddSerifIn()     : TAliasManagerScriptSerifInput;
    function  AddSerifOut()    : TAliasManagerScriptSerifOutput;
    function  AddSound()       : TAliasManagerObjectSound;
    function  AddPicture()     : TAliasManagerObjectPicture;
    function  AddPictureFile() : TAliasManagerObjectPictureFile;
    function  AddSong()        : TAliasManagerScriptSong;
    function  AddVideoFile()   : TAliasManagerObjectVideoFile;
    function AddBase()         : TAliasManagerInputBase;

    procedure SaveToAlias;
    procedure LoadFromAlias;
    function SaveToText() : string;

    property FileName : string read FFileName write FFileName;
    property ObjectName : string read GetObjectName write SetObjectName;
  end;

var
  GAliasManager : TAliasManager;    // グローバル管理インスタンス

implementation

uses TextEncodingUtils,SectionFileManager;

{============================================================}
{  TAliasManager                                              }
{============================================================}

constructor TAliasManager.Create;
begin
  inherited Create;

  SetAppFolderRoot('Syncroh2');
  FFileName := GetAppFolder('Temp') + 'Temp.object';

  FObjects := TList<TAliasManagerObjectItem>.Create;
  FStrings := TAliasStringList.Create;

end;

destructor TAliasManager.Destroy;
begin
  FStrings.Free;
  FObjects.Free;
  inherited;
end;

procedure TAliasManager.Clear;
begin
  FObjects.Clear;
  FStrings.Clear;
end;

function TAliasManager.AddObject<T>: T;
begin
  Result := T.Create;
  FObjects.Add(Result);
end;

function TAliasManager.AddPicture: TAliasManagerObjectPicture;
begin
  Result := AddObject<TAliasManagerObjectPicture>;
end;

function TAliasManager.AddPictureFile: TAliasManagerObjectPictureFile;
begin
  Result := AddObject<TAliasManagerObjectPictureFile>;
end;

function TAliasManager.AddSerifIn: TAliasManagerScriptSerifInput;
begin
  Result := AddObject<TAliasManagerScriptSerifInput>;
end;

function TAliasManager.AddSerifOut: TAliasManagerScriptSerifOutput;
begin
  Result := AddObject<TAliasManagerScriptSerifOutput>;
end;

function TAliasManager.AddSong: TAliasManagerScriptSong;
begin
  Result := AddObject<TAliasManagerScriptSong>;
end;

function TAliasManager.AddSound: TAliasManagerObjectSound;
begin
  Result := AddObject<TAliasManagerObjectSound>;
end;

function TAliasManager.AddVideoFile: TAliasManagerObjectVideoFile;
begin
  Result := AddObject<TAliasManagerObjectVideoFile>;
end;

function TAliasManager.AddAudio: TAliasManagerNormalAudio;
begin
  Result := AddObject<TAliasManagerNormalAudio>;
end;

function TAliasManager.AddBase: TAliasManagerInputBase;
begin
  Result := AddObject<TAliasManagerInputBase>;
end;

function TAliasManager.AddDress: TAliasManagerScriptDress;
begin
  Result := AddObject<TAliasManagerScriptDress>;
end;

function TAliasManager.AddFace: TAliasManagerScriptFace;
begin
  Result := AddObject<TAliasManagerScriptFace>;
end;

procedure TAliasManager.SaveToAlias;
var
  i : Integer;
begin
  for i := 0 to FObjects.Count-1 do begin
    FObjects[i].SaveToAlias(FStrings);
  end;
  FStrings.SaveToFile(FFileName);
end;

procedure TAliasManager.LoadFromAlias;
var
  n : Integer;
  s : string;
  t,ts : TStringList;
  sm : TSectionFileManager;
begin
  FObjects.Clear;
  t := TStringList.Create;
  sm := TSectionFileManager.Create;
  try
    if not FileExists(FFileName) then Exit;
    s := LoadTextAutoEncoding(FFileName);
    t.Text := s;
    sm.LoadFromStrings(t);
    n := 0;
    while n < 9999 do begin
      ts := sm.GetSection(IntToStr(n));
      if ts = nil then break;

      Inc(n);
    end;

  finally
    sm.Free;
    t.Free;
  end;

end;


function TAliasManager.SaveToText: string;
var
  i : Integer;
begin
  for i := 0 to FObjects.Count-1 do begin
    FObjects[i].SaveToAlias(FStrings);
  end;
  Result := FStrings.SaveToText();
end;

function TAliasManager.GetObjectName: string;
begin
  Result := FStrings.ObjectName;
end;

procedure TAliasManager.SetObjectName(const Value: string);
begin
  FStrings.ObjectName := Value;
end;


initialization
  GAliasManager := TAliasManager.Create;

finalization
  GAliasManager.Free;

end.

