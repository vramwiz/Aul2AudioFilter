unit Aul2AudioViewFrameShared;

// Aul2AudioView が実際に描画しているフレームを Monitor へ渡す小さな共有メモリ。

interface

uses
  SharedMemoryBase;

const
  AUDIO_VIEW_FRAME_SHARED_NAME    = 'Local\Aul2AudioViewFrame';
  AUDIO_VIEW_FRAME_SHARED_MAGIC   = $41564652; // AVFR
  AUDIO_VIEW_FRAME_SHARED_VERSION = 1;

type
  PAul2AudioViewFrameState = ^TAul2AudioViewFrameState;
  TAul2AudioViewFrameState = record
    Magic     : Cardinal;
    Version   : Cardinal;
    UpdateTick: UInt64;
    Frame     : Integer;
  end;

  TAul2AudioViewFrameSharedMemory = class(TSharedMemoryBase)
  private
    function GetState: PAul2AudioViewFrameState;
  public
    constructor Create; reintroduce;
    property State: PAul2AudioViewFrameState read GetState;
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
