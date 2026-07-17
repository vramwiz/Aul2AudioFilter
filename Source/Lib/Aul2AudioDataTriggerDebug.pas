unit Aul2AudioDataTriggerDebug;

interface

{$IFDEF DEBUG}
procedure DataTriggerDebugLog(const Source, Text: string);
{$ENDIF}

implementation

{$IFDEF DEBUG}
uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils;

var
  GLogMutex: THandle;

procedure DataTriggerDebugLog(const Source, Text: string);
const
  LOG_FILE_NAME = 'Aul2AudioFilter_DataTrigger_Debug.log';
var
  Bytes: TBytes;
  FileHandle: THandle;
  Line: string;
  LogPath: string;
  WaitResult: DWORD;
  Written: DWORD;
begin
  Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [' + Source + '] ' + Text;
  OutputDebugString(PChar(Line));
  // Filter／Controller／Monitorは別DLLなので、プロセス内CriticalSectionでは
  // 同じログファイルへの同時書込みを防げない。名前付きMutexを共有し、
  // 音声スレッドでは待たず、競合したログ行だけを破棄する。
  if GLogMutex = 0 then
    Exit;
  WaitResult := WaitForSingleObject(GLogMutex, 0);
  if (WaitResult <> WAIT_OBJECT_0) and (WaitResult <> WAIT_ABANDONED) then
    Exit;
  try
    try
      LogPath := TPath.Combine(TPath.GetTempPath, LOG_FILE_NAME);
      // TFile.AppendAllTextは共有拒否時にEFOpenErrorを生成し、捕捉しても
      // デバッガの例外停止対象になる。CreateFileは失敗を戻り値だけで扱う。
      FileHandle := CreateFile(PChar(LogPath), FILE_APPEND_DATA,
        FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil,
        OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
      if FileHandle = INVALID_HANDLE_VALUE then
        Exit;
      try
        Bytes := TEncoding.UTF8.GetBytes(Line + sLineBreak);
        if Length(Bytes) > 0 then
          WriteFile(FileHandle, Bytes[0], Length(Bytes), Written, nil);
      finally
        CloseHandle(FileHandle);
      end;
    except
      // 文字列生成を含む予期しない失敗もプラグイン処理へ伝播させない。
    end;
  finally
    ReleaseMutex(GLogMutex);
  end;
end;

initialization
  GLogMutex := CreateMutex(nil, False,
    'Local\Aul2AudioFilter_DataTrigger_Debug_Log_Mutex');

finalization
  if GLogMutex <> 0 then
  begin
    CloseHandle(GLogMutex);
    GLogMutex := 0;
  end;
{$ENDIF}

end.
