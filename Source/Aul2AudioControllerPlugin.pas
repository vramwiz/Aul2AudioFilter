unit Aul2AudioControllerPlugin;

// AviUtl2 への Aul2AudioController 登録と最小クライアントウィンドウを管理する。

interface

uses
  AviUtl2PluginTypes;

// AviUtl2 の編集メニューとクライアントウィンドウへ Controller を登録する。
procedure RegisterControllerPlugin(Host: PHostAppTable);
// Controller のクライアントウィンドウと描画リソースを登録と逆順に解放する。
procedure UninitializeControllerPlugin;

implementation

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  Aul2AudioControllerView;

const
  CONTROLLER_WINDOW_CLASS_NAME = 'Aul2AudioControllerClient'; // AviUtl2へ登録するウィンドウクラス名。
  CONTROLLER_WINDOW_NAME       = 'Aul2AudioController';       // クライアントウィンドウの表示名。
  CONTROLLER_MENU_NAME         = 'Aul2AudioController';       // 編集メニューの表示名。

var
  ClientWindow: HWND;   // AviUtl2が親として管理するControllerクライアントウィンドウ。
  WindowBrush : HBRUSH; // クライアント背景を塗るダークテーマ用ブラシ。

function ControllerWndProc(WindowHandle: HWND; MessageId: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT; stdcall;
begin
  case MessageId of
    WM_SETCURSOR:
      begin
        // AviUtl2クライアント上へマウスが来た通知を、Controllerの一括読込契機にする。
        NotifyControllerMouseEnter;
      end;
    WM_SIZE:
      begin
        ResizeControllerView(LOWORD(LParam), HIWORD(LParam));
        Exit(0);
      end;
    WM_WINDOWPOSCHANGED, WM_SHOWWINDOW:
      begin
        SyncControllerViewBounds;
      end;
  end;

  Result := DefWindowProc(WindowHandle, MessageId, WParam, LParam);
end;

procedure RegisterControllerWindowClass;
var
  WindowClass: WNDCLASSEX;
begin
  FillChar(WindowClass, SizeOf(WindowClass), 0);
  WindowClass.cbSize := SizeOf(WindowClass);
  WindowClass.lpfnWndProc := @ControllerWndProc;
  WindowClass.hInstance := HInstance;
  WindowClass.hCursor := LoadCursor(0, IDC_ARROW);
  WindowClass.hbrBackground := WindowBrush;
  WindowClass.lpszClassName := CONTROLLER_WINDOW_CLASS_NAME;

  if (RegisterClassEx(WindowClass) = 0) and
     (GetLastError <> ERROR_CLASS_ALREADY_EXISTS) then
    RaiseLastOSError;
end;

procedure ControllerMenuClick(Edit: PEditSection); cdecl;
begin
  ShowControllerView;
end;

procedure RegisterControllerPlugin(Host: PHostAppTable);
begin
  if Host = nil then
    Exit;

  WindowBrush := CreateSolidBrush(RGB(28, 30, 33));
  if WindowBrush = 0 then
    RaiseLastOSError;

  RegisterControllerWindowClass;

  ClientWindow := CreateWindowEx(
    0,
    CONTROLLER_WINDOW_CLASS_NAME,
    CONTROLLER_WINDOW_NAME,
    WS_POPUP,
    CW_USEDEFAULT,
    CW_USEDEFAULT,
    520,
    360,
    0,
    0,
    HInstance,
    nil);

  if ClientWindow = 0 then
    RaiseLastOSError;

  Host^.RegisterWindowClient(CONTROLLER_WINDOW_NAME, ClientWindow);
  Host^.RegisterEditMenu(CONTROLLER_MENU_NAME, @ControllerMenuClick);
  CreateControllerView(ClientWindow);
end;

procedure UninitializeControllerPlugin;
begin
  DestroyControllerView;

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
