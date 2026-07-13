unit AppFolderUtils;

interface

uses
  System.SysUtils, System.IOUtils, Winapi.Windows, Winapi.ShlObj;

// -----------------------------------------------------------------------------
// 静音・多段フォールバック型 AppFolderUtils
//
// 優先順位:
//   1) Documents
//   2) LocalAppData
//   3) ProgramData
//   4) Temp
//
// 例外は外へ出さない。
// フォルダ作成失敗時は自動的にフォールバック。
//
// テスト用:
//   {$DEFINE SYNCROH2_FORCE_DOC_FAIL}
//   {$DEFINE SYNCROH2_FORCE_LOCAL_FAIL}
//   {$DEFINE SYNCROH2_FORCE_PROGRAMDATA_FAIL}
// -----------------------------------------------------------------------------

procedure SetAppFolderRoot(const FolderName: string);
function  GetAppFolder(const SubFolder: string): string;
function  GetAppRootFolder: string;

implementation

var
  GAppRootFolder: string = '';

function SafeForceDirectories(const Path: string): Boolean;
begin
  Result := False;
  try
    if Path = '' then Exit;
    if TDirectory.Exists(Path) then Exit(True);
    Result := ForceDirectories(Path);
  except
    Result := False;
  end;
end;

function GetLocalAppDataPathSafe: string;
var
  Buf: array[0..MAX_PATH - 1] of Char;
begin
  Result := '';
  try
    Result := GetEnvironmentVariable('LOCALAPPDATA');
    if Result <> '' then Exit;

    FillChar(Buf, SizeOf(Buf), 0);
    if Succeeded(SHGetFolderPath(0, CSIDL_LOCAL_APPDATA, 0, SHGFP_TYPE_CURRENT, Buf)) then
      Result := Buf;
  except
    Result := '';
  end;
end;

function GetProgramDataPathSafe: string;
var
  Buf: array[0..MAX_PATH - 1] of Char;
begin
  Result := '';
  try
    Result := GetEnvironmentVariable('ProgramData');
    if Result <> '' then Exit;

    FillChar(Buf, SizeOf(Buf), 0);
    if Succeeded(SHGetFolderPath(0, CSIDL_COMMON_APPDATA, 0, SHGFP_TYPE_CURRENT, Buf)) then
      Result := Buf;
  except
    Result := '';
  end;
end;

function TryCreateRoot(const BasePath, FolderName: string): string;
var
  Root: string;
begin
  Result := '';
  if BasePath = '' then Exit;

  try
    Root := TPath.Combine(BasePath, FolderName);
    Root := IncludeTrailingPathDelimiter(Root);
    if SafeForceDirectories(Root) then Result := Root;
  except
    Result := '';
  end;
end;

procedure SetAppFolderRoot(const FolderName: string);
var
  Path: string;
begin
  GAppRootFolder := '';
  if Trim(FolderName) = '' then Exit;

  // 1) Documents
  try
  {$IFDEF SYNCROH2_FORCE_DOC_FAIL}
    Path := '';
  {$ELSE}
    Path := TryCreateRoot(TPath.GetDocumentsPath, FolderName);
  {$ENDIF}
    if Path <> '' then begin GAppRootFolder := Path; Exit; end;
  except
  end;

  // 2) LocalAppData
  try
  {$IFDEF SYNCROH2_FORCE_LOCAL_FAIL}
    Path := '';
  {$ELSE}
    Path := TryCreateRoot(GetLocalAppDataPathSafe, FolderName);
  {$ENDIF}
    if Path <> '' then begin GAppRootFolder := Path; Exit; end;
  except
  end;

  // 3) ProgramData
  try
  {$IFDEF SYNCROH2_FORCE_PROGRAMDATA_FAIL}
    Path := '';
  {$ELSE}
    Path := TryCreateRoot(GetProgramDataPathSafe, FolderName);
  {$ENDIF}
    if Path <> '' then begin GAppRootFolder := Path; Exit; end;
  except
  end;

  // 4) Temp（最終避難）
  try
    Path := TryCreateRoot(TPath.GetTempPath, FolderName);
    if Path <> '' then GAppRootFolder := Path;
  except
    GAppRootFolder := '';
  end;
end;

function GetAppFolder(const SubFolder: string): string;
var
  Path: string;
begin
  Result := '';
  if GAppRootFolder = '' then Exit;
  if Trim(SubFolder) = '' then Exit(GAppRootFolder);

  try
    Path := TPath.Combine(GAppRootFolder, SubFolder);
    Path := IncludeTrailingPathDelimiter(Path);
    SafeForceDirectories(Path);
    Result := Path;
  except
    Result := GAppRootFolder;
  end;
end;

function GetAppRootFolder: string;
begin
  Result := GAppRootFolder;
end;

end.

