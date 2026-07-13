unit Aul2AudioMonitorPlugin;

// AviUtl2 への Aul2AudioMonitor 登録とクライアントウィンドウ管理を担当する。

interface

uses
  Winapi.Windows,
  AviUtl2PluginTypes;

// AviUtl2 の編集メニューとクライアントウィンドウへ Monitor を登録する。
procedure RegisterMonitorPlugin(Host: PHostAppTable);
// Monitor のフォーム、クライアントウィンドウ、ウィンドウクラスを登録と逆順に解放する。
procedure UninitializeMonitorPlugin;

implementation

uses
  Winapi.Messages,
  System.SysUtils,
  Aul2AudioMonitorView;

const
  MONITOR_WINDOW_CLASS_NAME = 'Aul2AudioMonitorClient'; // AviUtl2へ登録する子ウィンドウクラス名。
  MONITOR_MENU_NAME         = 'Aul2AudioMonitor';       // 編集メニューとクライアントの表示名。

var
  ClientWindow: HWND;   // AviUtl2が親として管理するMonitorクライアントウィンドウ。
  WindowBrush : HBRUSH; // クライアント背景を塗るダークテーマ用ブラシ。

procedure PaintMonitorWindow(hWnd: HWND);
var
  PaintStruct: TPaintStruct;
  DC: HDC;
  Rect: TRect;
begin
  DC := BeginPaint(hWnd, PaintStruct);
  try
    GetClientRect(hWnd, Rect);
    SetBkColor(DC, RGB(36, 36, 36));
    FillRect(DC, Rect, WindowBrush);
  finally
    EndPaint(hWnd, PaintStruct);
  end;
end;

function MonitorWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM;
  lParam: LPARAM): LRESULT; stdcall;
begin
  // VCLフォームはクライアントの生成・サイズ変更・破棄通知に合わせて管理する。
  case uMsg of
    WM_SIZE:
      begin
        SyncMonitorViewBounds;
        InvalidateRect(hWnd, nil, True);
        Exit(0);
      end;
    WM_WINDOWPOSCHANGED, WM_SHOWWINDOW:
      begin
        SyncMonitorViewBounds;
        InvalidateRect(hWnd, nil, True);
      end;
    WM_PAINT:
      begin
        PaintMonitorWindow(hWnd);
        Exit(0);
      end;
  end;

  Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
end;

procedure RegisterMonitorWindowClass;
var
  WindowClass: WNDCLASSEX;
begin
  FillChar(WindowClass, SizeOf(WindowClass), 0);
  WindowClass.cbSize := SizeOf(WindowClass);
  WindowClass.lpfnWndProc := @MonitorWndProc;
  WindowClass.hInstance := HInstance;
  WindowClass.hCursor := LoadCursor(0, IDC_ARROW);
  WindowClass.hbrBackground := WindowBrush;
  WindowClass.lpszClassName := MONITOR_WINDOW_CLASS_NAME;

  if (RegisterClassEx(WindowClass) = 0) and
     (GetLastError <> ERROR_CLASS_ALREADY_EXISTS) then
    RaiseLastOSError;
end;

procedure MonitorMenuClick(Edit: PEditSection); cdecl;
begin
  ShowMonitorView;
end;

procedure RegisterMonitorPlugin(Host: PHostAppTable);
begin
  if Host = nil then
    Exit;

  WindowBrush := CreateSolidBrush(RGB(36, 36, 36));
  RegisterMonitorWindowClass;

  ClientWindow := CreateWindowEx(
    0,
    MONITOR_WINDOW_CLASS_NAME,
    MONITOR_WINDOW_NAME,
    WS_POPUP,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    480,
    260,
    0,
    0,
    HInstance,
    nil);

  if ClientWindow = 0 then
    RaiseLastOSError;

  Host^.RegisterWindowClient(MONITOR_WINDOW_NAME, ClientWindow);
  Host^.RegisterEditMenu(MONITOR_MENU_NAME, @MonitorMenuClick);

  CreateMonitorView(ClientWindow);
end;

procedure UninitializeMonitorPlugin;
begin
  DestroyMonitorView;

  if ClientWindow <> 0 then
  begin
    DestroyWindow(ClientWindow);
    ClientWindow := 0;
  end;

  if WindowBrush <> 0 then
  begin
    DeleteObject(WindowBrush);
    WindowBrush := 0;
  end;
end;

end.
