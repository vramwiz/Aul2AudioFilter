unit Aul2AudioViewDiagnostics;

// Aul2Audio Viewの3D検証ログをプラグイン配置先へ安全に追記する。

interface

// 前回の診断ログを削除し、今回のプラグイン起動分を開始する。
procedure ResetView3DLog;
// 時刻付きの1行をAul2AudioView3D.logへ追記する。
procedure WriteView3DLog(const MessageText: string);

implementation

uses
  System.SysUtils,
  Winapi.Windows;

var
  LogLock: TRTLCriticalSection;

function LogFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(GetModuleName(HInstance))) +
    'Aul2AudioView3D.log';
end;

procedure ResetView3DLog;
begin
  EnterCriticalSection(LogLock);
  try
    DeleteFile(PChar(LogFileName));
  finally
    LeaveCriticalSection(LogLock);
  end;
end;

procedure WriteView3DLog(const MessageText: string);
var
  Handle: THandle;
  Line: UTF8String;
  Written: DWORD;
begin
  Line := UTF8String(Format('[%d] %s'#13#10, [GetTickCount64, MessageText]));
  EnterCriticalSection(LogLock);
  try
    Handle := CreateFile(PChar(LogFileName), FILE_APPEND_DATA,
      FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
    if Handle = INVALID_HANDLE_VALUE then
      Exit;
    try
      Written := 0;
      WriteFile(Handle, Pointer(Line)^, Length(Line), Written, nil);
    finally
      CloseHandle(Handle);
    end;
  finally
    LeaveCriticalSection(LogLock);
  end;
end;

initialization
  InitializeCriticalSection(LogLock);

finalization
  DeleteCriticalSection(LogLock);

end.
