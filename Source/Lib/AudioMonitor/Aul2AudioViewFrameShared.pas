unit Aul2AudioViewFrameShared;

// Aul2AudioView が実際に描画しているフレームを Monitor へ渡す小さな共有メモリ。

interface

uses
  SharedMemoryBase;

const
  AUDIO_VIEW_FRAME_SHARED_NAME    = 'Local\Aul2AudioViewFrameV3'; // View と Monitor が開くマップ名。
  AUDIO_VIEW_FRAME_SHARED_MAGIC   = $41564652;                   // 構造判定用の識別値 AVFR。
  AUDIO_VIEW_FRAME_SHARED_VERSION = 3;                           // レコード配置を変更したら更新する。

type
  // View が最後に描画した編集全体のフレームを Monitor へ通知する状態。
  PAul2AudioViewFrameState = ^TAul2AudioViewFrameState;
  TAul2AudioViewFrameState = record
    Magic     : Cardinal; // AUDIO_VIEW_FRAME_SHARED_MAGIC。
    Version   : Cardinal; // AUDIO_VIEW_FRAME_SHARED_VERSION。
    UpdateTick: UInt64;   // 更新の鮮度を判定する GetTickCount64 値。
    Frame     : Integer;  // View が実際に処理した編集全体のフレーム番号。
    EditState : Integer;  // Monitorが通知する編集状態。0=Edit、1=Play、2=Encode。
    MonitorRequested: LongBool; // Monitor表示中だけViewからのフレーム通知を要求する。
  end;

  // ViewFrame 状態を固定サイズの名前付き共有メモリとして公開する。
  TAul2AudioViewFrameSharedMemory = class(TSharedMemoryBase)
  private
    function GetState: PAul2AudioViewFrameState;
  public
    // ViewFrame 用のマップを開き、初回作成時は識別情報を初期化する。
    constructor Create; reintroduce;
    property State: PAul2AudioViewFrameState read GetState; // マップ先を型付き状態として返す。
  end;

// Viewの表示タイプに関係なく、描画した編集全体フレームをMonitorへ通知する。
procedure AudioViewFrameNotify(CurrentFrame: Integer);
// Monitorの表示状態に合わせてViewのフレーム通知要求を切り替える。
procedure AudioViewFrameSetMonitorRequest(Requested: Boolean);

implementation

uses
  System.SysUtils,
  Winapi.Windows;

var
  ViewFrameNotifyMemory: TAul2AudioViewFrameSharedMemory;

constructor TAul2AudioViewFrameSharedMemory.Create;
begin
  inherited Create(AUDIO_VIEW_FRAME_SHARED_NAME, SizeOf(TAul2AudioViewFrameState));

  if State <> nil then
  begin
    State^.Magic := AUDIO_VIEW_FRAME_SHARED_MAGIC;
    State^.Version := AUDIO_VIEW_FRAME_SHARED_VERSION;
    if IsOwner then
    begin
      State^.UpdateTick := 0;
      State^.Frame := -1;
      State^.EditState := 0;
      State^.MonitorRequested := False;
    end;
  end;
end;

function TAul2AudioViewFrameSharedMemory.GetState: PAul2AudioViewFrameState;
begin
  Result := PAul2AudioViewFrameState(View);
end;

procedure AudioViewFrameNotify(CurrentFrame: Integer);
var
  FrameState: PAul2AudioViewFrameState;
begin
  try
    if ViewFrameNotifyMemory = nil then
      ViewFrameNotifyMemory := TAul2AudioViewFrameSharedMemory.Create;
    FrameState := ViewFrameNotifyMemory.State;
    if FrameState = nil then
      Exit;
    if not FrameState^.MonitorRequested then
      Exit;
    FrameState^.Magic := AUDIO_VIEW_FRAME_SHARED_MAGIC;
    FrameState^.Version := AUDIO_VIEW_FRAME_SHARED_VERSION;
    FrameState^.Frame := CurrentFrame;
    FrameState^.UpdateTick := GetTickCount64;
  except
    FreeAndNil(ViewFrameNotifyMemory);
  end;
end;

procedure AudioViewFrameSetMonitorRequest(Requested: Boolean);
var
  FrameState: PAul2AudioViewFrameState;
begin
  try
    if ViewFrameNotifyMemory = nil then
      ViewFrameNotifyMemory := TAul2AudioViewFrameSharedMemory.Create;
    FrameState := ViewFrameNotifyMemory.State;
    if FrameState = nil then
      Exit;
    FrameState^.MonitorRequested := Requested;
    if not Requested then
    begin
      FrameState^.UpdateTick := 0;
      FrameState^.Frame := -1;
    end;
  except
    FreeAndNil(ViewFrameNotifyMemory);
  end;
end;

initialization
  ViewFrameNotifyMemory := nil;

finalization
  FreeAndNil(ViewFrameNotifyMemory);

end.
