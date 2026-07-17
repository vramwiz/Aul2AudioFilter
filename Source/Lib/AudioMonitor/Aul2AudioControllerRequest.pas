unit Aul2AudioControllerRequest;

{$ALIGN 8}

interface

uses
  Winapi.Windows,
  SharedMemoryBase;

const
  AUDIO_CONTROLLER_REQUEST_ITEM_NAME = 'Controller Request V1';
  AUDIO_CONTROLLER_REQUEST_VERSION = 1;
  AUDIO_CONTROLLER_REQUEST_GRAPH_NONE = 0;
  AUDIO_CONTROLLER_REQUEST_GRAPH_FIRST = 1;
  AUDIO_CONTROLLER_REQUEST_GRAPH_LAST = 20;
  AUDIO_CONTROLLER_GRAPH_DELAY = 1;
  AUDIO_CONTROLLER_GRAPH_EQ = 2;
  AUDIO_CONTROLLER_GRAPH_COMPRESSOR = 3;
  AUDIO_CONTROLLER_GRAPH_VOICE_DRIVE = 4;
  AUDIO_CONTROLLER_GRAPH_DISTORTION = 5;
  AUDIO_CONTROLLER_GRAPH_NOISE = 6;
  AUDIO_CONTROLLER_GRAPH_BIT_CRUSHER = 7;
  AUDIO_CONTROLLER_GRAPH_TREMBLE = 8;
  AUDIO_CONTROLLER_GRAPH_WOBBLE = 9;
  AUDIO_CONTROLLER_GRAPH_PITCH = 10;
  AUDIO_CONTROLLER_GRAPH_RING_MOD = 11;
  AUDIO_CONTROLLER_GRAPH_MUFFLE = 12;
  AUDIO_CONTROLLER_GRAPH_WHISPER = 13;
  AUDIO_CONTROLLER_GRAPH_AUTO_GAIN = 14;
  AUDIO_CONTROLLER_GRAPH_NOISE_GATE = 15;
  AUDIO_CONTROLLER_GRAPH_GHOST = 16;
  AUDIO_CONTROLLER_GRAPH_CHORUS = 17;
  AUDIO_CONTROLLER_GRAPH_REVERB = 18;
  AUDIO_CONTROLLER_GRAPH_OUTPUT = 19;
  AUDIO_CONTROLLER_GRAPH_LIMITER = 20;

  AUDIO_CONTROLLER_REQUEST_SHARED_NAME = 'Local\Aul2AudioControllerRequestV2';
  AUDIO_CONTROLLER_REQUEST_SHARED_MAGIC = $41524351; // ARCQ
  AUDIO_CONTROLLER_REQUEST_SHARED_VERSION = 1;

type
  PAul2AudioControllerRequestData = ^TAul2AudioControllerRequestData;
  TAul2AudioControllerRequestData = record
    Version  : Cardinal;
    GraphKind: Cardinal;
    RequestId: TGUID;
  end;

  PAul2AudioControllerRequestState = ^TAul2AudioControllerRequestState;
  TAul2AudioControllerRequestState = record
    Magic           : Cardinal;
    Version         : Cardinal;
    Active          : LongBool;
    GraphKind       : Cardinal;
    ControllerWindow: UInt64;
    RequestId       : TGUID;
    MonitorWindow   : UInt64;
    ViewUpdateTick  : UInt64;
  end;

  TAul2AudioControllerRequestSharedMemory = class(TSharedMemoryBase)
  private
    function GetState: PAul2AudioControllerRequestState;
  public
    constructor Create; reintroduce;
    procedure Activate(GraphKind: Cardinal; ControllerWindow: HWND;
      const RequestId: TGUID);
    procedure Deactivate;
    property State: PAul2AudioControllerRequestState read GetState;
  end;

function ControllerGraphKindFromEffectIndex(EffectIndex: Integer): Cardinal;
function ControllerRequestDataToHex(
  const Data: TAul2AudioControllerRequestData): string;
function ControllerRequestIdsEqual(const A, B: TGUID): Boolean;

// FilterProcAudioの1回分について、現在Objectの要求を検証して保持する。
procedure ControllerRequestBegin(Data: PAul2AudioControllerRequestData);
procedure ControllerRequestEnd;
function ControllerGraphRequested(GraphKind: Cardinal): Boolean;
function ControllerCurrentGraphKind: Cardinal;
function ControllerCurrentRequestId: TGUID;
// MonitorウィンドウまたはAul2Audio Viewが共通解析値を必要としていることを通知する。
procedure AudioConsumerSetMonitorWindow(WindowHandle: HWND);
procedure AudioConsumerNotifyView;
function CommonAudioDataRequested: Boolean;

implementation

uses
  System.SysUtils;

threadvar
  ActiveRequest: TAul2AudioControllerRequestData;
  ActiveRequestValid: Boolean;

var
  FilterRequestMemory: TAul2AudioControllerRequestSharedMemory;

function GetRequestMemory: TAul2AudioControllerRequestSharedMemory;
begin
  if FilterRequestMemory = nil then
    FilterRequestMemory := TAul2AudioControllerRequestSharedMemory.Create;
  Result := FilterRequestMemory;
end;

constructor TAul2AudioControllerRequestSharedMemory.Create;
begin
  inherited Create(AUDIO_CONTROLLER_REQUEST_SHARED_NAME,
    SizeOf(TAul2AudioControllerRequestState));
  if State <> nil then
  begin
    if (State^.Magic <> AUDIO_CONTROLLER_REQUEST_SHARED_MAGIC) or
       (State^.Version <> AUDIO_CONTROLLER_REQUEST_SHARED_VERSION) then
      FillChar(State^, SizeOf(State^), 0);
    State^.Magic := AUDIO_CONTROLLER_REQUEST_SHARED_MAGIC;
    State^.Version := AUDIO_CONTROLLER_REQUEST_SHARED_VERSION;
  end;
end;

function TAul2AudioControllerRequestSharedMemory.GetState:
  PAul2AudioControllerRequestState;
begin
  Result := PAul2AudioControllerRequestState(View);
end;

procedure TAul2AudioControllerRequestSharedMemory.Activate(GraphKind: Cardinal;
  ControllerWindow: HWND; const RequestId: TGUID);
begin
  if State = nil then
    Exit;
  State^.Active := False;
  State^.Magic := AUDIO_CONTROLLER_REQUEST_SHARED_MAGIC;
  State^.Version := AUDIO_CONTROLLER_REQUEST_SHARED_VERSION;
  State^.GraphKind := GraphKind;
  State^.ControllerWindow := UInt64(ControllerWindow);
  State^.RequestId := RequestId;
  MemoryBarrier;
  State^.Active := True;
end;

procedure TAul2AudioControllerRequestSharedMemory.Deactivate;
begin
  if State = nil then
    Exit;
  State^.Active := False;
  State^.GraphKind := AUDIO_CONTROLLER_REQUEST_GRAPH_NONE;
  State^.ControllerWindow := 0;
  State^.RequestId := Default(TGUID);
end;

function ControllerGraphKindFromEffectIndex(EffectIndex: Integer): Cardinal;
begin
  if (EffectIndex < 0) or
     (EffectIndex >= AUDIO_CONTROLLER_REQUEST_GRAPH_LAST) then
    Exit(AUDIO_CONTROLLER_REQUEST_GRAPH_NONE);
  Result := Cardinal(EffectIndex + 1);
end;

function ControllerRequestDataToHex(
  const Data: TAul2AudioControllerRequestData): string;
const
  HEX_DIGITS: array[0..15] of Char = '0123456789ABCDEF';
var
  Bytes: PByte;
  Index: Integer;
begin
  SetLength(Result, SizeOf(Data) * 2);
  Bytes := @Data;
  for Index := 0 to SizeOf(Data) - 1 do
  begin
    Result[Index * 2 + 1] := HEX_DIGITS[Bytes^ shr 4];
    Result[Index * 2 + 2] := HEX_DIGITS[Bytes^ and $0F];
    Inc(Bytes);
  end;
end;

function ControllerRequestIdsEqual(const A, B: TGUID): Boolean;
begin
  Result := CompareMem(@A, @B, SizeOf(TGUID));
end;

procedure ControllerRequestBegin(Data: PAul2AudioControllerRequestData);
var
  RequestState: PAul2AudioControllerRequestState;
begin
  ActiveRequestValid := False;
  ActiveRequest := Default(TAul2AudioControllerRequestData);
  if (Data = nil) or (Data^.Version <> AUDIO_CONTROLLER_REQUEST_VERSION) or
     (Data^.GraphKind < AUDIO_CONTROLLER_REQUEST_GRAPH_FIRST) or
     (Data^.GraphKind > AUDIO_CONTROLLER_REQUEST_GRAPH_LAST) then
    Exit;

  RequestState := GetRequestMemory.State;
  if (RequestState = nil) or not RequestState^.Active or
     (RequestState^.Magic <> AUDIO_CONTROLLER_REQUEST_SHARED_MAGIC) or
     (RequestState^.Version <> AUDIO_CONTROLLER_REQUEST_SHARED_VERSION) or
     (RequestState^.GraphKind <> Data^.GraphKind) or
     not ControllerRequestIdsEqual(RequestState^.RequestId, Data^.RequestId) or
     (RequestState^.ControllerWindow = 0) or
     not IsWindow(HWND(RequestState^.ControllerWindow)) then
    Exit;

  ActiveRequest := Data^;
  ActiveRequestValid := True;
end;

procedure ControllerRequestEnd;
begin
  ActiveRequestValid := False;
  ActiveRequest := Default(TAul2AudioControllerRequestData);
end;

function ControllerGraphRequested(GraphKind: Cardinal): Boolean;
begin
  Result := ActiveRequestValid and (ActiveRequest.GraphKind = GraphKind);
end;

function ControllerCurrentGraphKind: Cardinal;
begin
  if ActiveRequestValid then
    Result := ActiveRequest.GraphKind
  else
    Result := AUDIO_CONTROLLER_REQUEST_GRAPH_NONE;
end;

function ControllerCurrentRequestId: TGUID;
begin
  if ActiveRequestValid then
    Result := ActiveRequest.RequestId
  else
    Result := Default(TGUID);
end;

procedure AudioConsumerSetMonitorWindow(WindowHandle: HWND);
var
  RequestState: PAul2AudioControllerRequestState;
begin
  RequestState := GetRequestMemory.State;
  if RequestState <> nil then
    RequestState^.MonitorWindow := UInt64(WindowHandle);
end;

procedure AudioConsumerNotifyView;
var
  RequestState: PAul2AudioControllerRequestState;
begin
  RequestState := GetRequestMemory.State;
  if RequestState <> nil then
    RequestState^.ViewUpdateTick := GetTickCount64;
end;

function CommonAudioDataRequested: Boolean;
const
  VIEW_REQUEST_TIMEOUT_MS = 1000;
var
  RequestState: PAul2AudioControllerRequestState;
  Tick: UInt64;
begin
  Result := ControllerGraphRequested(AUDIO_CONTROLLER_GRAPH_MUFFLE) or
    ControllerGraphRequested(AUDIO_CONTROLLER_GRAPH_WHISPER) or
    ControllerGraphRequested(AUDIO_CONTROLLER_GRAPH_OUTPUT);
  if Result then
    Exit;

  RequestState := GetRequestMemory.State;
  if RequestState = nil then
    Exit(False);
  if (RequestState^.MonitorWindow <> 0) and
     IsWindow(HWND(RequestState^.MonitorWindow)) then
    Exit(True);

  Tick := GetTickCount64;
  Result := (RequestState^.ViewUpdateTick > 0) and
    (Tick >= RequestState^.ViewUpdateTick) and
    (Tick - RequestState^.ViewUpdateTick <= VIEW_REQUEST_TIMEOUT_MS);
end;

initialization
  FilterRequestMemory := nil;

finalization
  FreeAndNil(FilterRequestMemory);

end.
