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

procedure DataTriggerDebugLog(const Source, Text: string);
const
  LOG_FILE_NAME = 'Aul2AudioFilter_DataTrigger_Debug.log';
var
  Line: string;
begin
  Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [' + Source + '] ' + Text;
  OutputDebugString(PChar(Line));
  try
    TFile.AppendAllText(TPath.Combine(TPath.GetTempPath, LOG_FILE_NAME),
      Line + sLineBreak, TEncoding.UTF8);
  except
    // デバッグログの失敗をプラグイン処理へ伝播させない。
  end;
end;
{$ENDIF}

end.
