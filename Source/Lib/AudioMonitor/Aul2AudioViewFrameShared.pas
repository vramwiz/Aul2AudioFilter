unit Aul2AudioViewFrameShared;

// Aul2AudioView が実際に描画しているフレームを Monitor へ渡す小さな共有メモリ。

interface

uses
  SharedMemoryBase;

const
  AUDIO_VIEW_FRAME_SHARED_NAME    = 'Local\Aul2AudioViewFrame'; // View と Monitor が開くマップ名。
  AUDIO_VIEW_FRAME_SHARED_MAGIC   = $41564652;                   // 構造判定用の識別値 AVFR。
  AUDIO_VIEW_FRAME_SHARED_VERSION = 1;                           // レコード配置を変更したら更新する。

type
  // View が最後に描画した編集全体のフレームを Monitor へ通知する状態。
  PAul2AudioViewFrameState = ^TAul2AudioViewFrameState;
  TAul2AudioViewFrameState = record
    Magic     : Cardinal; // AUDIO_VIEW_FRAME_SHARED_MAGIC。
    Version   : Cardinal; // AUDIO_VIEW_FRAME_SHARED_VERSION。
    UpdateTick: UInt64;   // 更新の鮮度を判定する GetTickCount64 値。
    Frame     : Integer;  // View が実際に処理した編集全体のフレーム番号。
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

implementation

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
    end;
  end;
end;

function TAul2AudioViewFrameSharedMemory.GetState: PAul2AudioViewFrameState;
begin
  Result := PAul2AudioViewFrameState(View);
end;

end.
