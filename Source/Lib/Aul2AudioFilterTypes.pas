unit Aul2AudioFilterTypes;

// AviUtl2 SDK のフィルター関連構造体を Delphi から参照するための型定義。

{$ALIGN 8}

interface

uses
  Winapi.Windows;

type
  PEDIT_SECTION = ^TEDIT_SECTION;
  TFilterItemButtonCallback = procedure(Edit: PEDIT_SECTION); cdecl;

  LPCWSTR       = PWideChar; // SDK 側の wide string pointer
  OBJECT_HANDLE = Pointer; // AviUtl2 内部オブジェクトへの不透明ハンドル

  // GUI グループ項目。後続の track/check/select を AviUtl2 上でまとめる。
  PFILTER_ITEM_GROUP = ^TFILTER_ITEM_GROUP;
  TFILTER_ITEM_GROUP = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    DefaultVisible: Byte;
  end;

  // ON/OFF 用の GUI 項目。
  PFILTER_ITEM_CHECK = ^TFILTER_ITEM_CHECK;
  TFILTER_ITEM_CHECK = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: Byte;
  end;

  // 色選択用の GUI 項目。
  PFILTER_ITEM_COLOR = ^TFILTER_ITEM_COLOR;
  TFILTER_ITEM_COLOR = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    B, G, R, X: Byte;
  end;

  // 数値スライダー用の GUI 項目。
  PFILTER_ITEM_TRACK = ^TFILTER_ITEM_TRACK;
  TFILTER_ITEM_TRACK = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: Double;
    S, E: Double;
    Step: Double;
    ZeroDisplay: LPCWSTR;
    SliderRatio: Double;
  end;

  // 選択肢リスト用の GUI 項目。
  PFILTER_ITEM_SELECT = ^TFILTER_ITEM_SELECT;
  TFILTER_ITEM_SELECT_ITEM = record
    Name: LPCWSTR;
    Value: Integer;
  end;

  TFILTER_ITEM_SELECT = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: Integer;
    List: ^TFILTER_ITEM_SELECT_ITEM;
  end;

  // ボタン項目。押下時に編集コールバックとして呼ばれるため、設定変更APIの実験に使う。
  PFILTER_ITEM_BUTTON = ^TFILTER_ITEM_BUTTON;
  TFILTER_ITEM_BUTTON = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Callback: TFilterItemButtonCallback;
  end;

  TSetObjectItemValueFunc = function(Obj: OBJECT_HANDLE; Effect: LPCWSTR;
    Item: LPCWSTR; Value: PAnsiChar): Byte; cdecl;
  TGetFocusObjectFunc = function: OBJECT_HANDLE; cdecl;

  // EDIT_SECTION はSDK上大きな構造体だが、ここでは先頭から必要な関数までだけ定義する。
  TEDIT_SECTION = record
    Info: Pointer;
    CreateObjectFromAlias: Pointer;
    FindObject: Pointer;
    CountObjectEffect: Pointer;
    GetObjectLayerFrame: Pointer;
    GetObjectAlias: Pointer;
    GetObjectItemValue: Pointer;
    SetObjectItemValue: TSetObjectItemValueFunc;
    MoveObject: Pointer;
    DeleteObject: Pointer;
    GetFocusObject: TGetFocusObjectFunc;
  end;

  // Scene は処理中の動画・音声全体に関する情報を持つ。
  PSCENE_INFO = ^TSCENE_INFO;
  TSCENE_INFO = record
    Width, Height: Integer;
    Rate, Scale: Integer;
    SampleRate: Integer;
  end;

  // Object_ は現在処理中の音声オブジェクトとエフェクト位置を識別する。
  POBJECT_INFO = ^TOBJECT_INFO;
  TOBJECT_INFO = record
    ID: Int64;
    Frame: Integer;
    FrameTotal: Integer;
    Time: Double;
    TimeTotal: Double;
    Width, Height: Integer;
    SampleIndex: Int64;
    SampleTotal: Int64;
    SampleNum: Integer;
    ChannelNum: Integer;
    EffectID: Int64;
    Flag: Integer;
    Layer: Integer;
    Index: Integer;
    Num: Integer;
    FrameS: Integer;
    FrameE: Integer;
  end;

  // AviUtl2 側の音量パラメーター。現時点では参照のみ。
  POBJECT_AUDIO_PARAM = ^TOBJECT_AUDIO_PARAM;
  TOBJECT_AUDIO_PARAM = record
    VolL, VolR: Single;
  end;

  TPIXEL_RGBA = packed record
    R, G, B, A: Byte;
  end;
  PPIXEL_RGBA = ^TPIXEL_RGBA;

  PID3D11Texture2D = Pointer;
  TFilterProcVideoGetTex2D = function: PID3D11Texture2D; cdecl;

  PFILTER_PROC_VIDEO = ^TFILTER_PROC_VIDEO;
  TFILTER_PROC_VIDEO = record
    Scene: PSCENE_INFO;
    Object_: POBJECT_INFO;
    GetImageData: procedure(Buffer: PPIXEL_RGBA); cdecl;
    SetImageData: procedure(Buffer: PPIXEL_RGBA; Width, Height: Integer); cdecl;
    GetImageTexture2D: TFilterProcVideoGetTex2D;
    GetFramebufferTexture2D: TFilterProcVideoGetTex2D;
  end;

  // 音声フィルター処理時に AviUtl2 から渡される入出力 API。
  PFILTER_PROC_AUDIO = ^TFILTER_PROC_AUDIO;
  TFILTER_PROC_AUDIO = record
    Scene: PSCENE_INFO;
    Object_: POBJECT_INFO;
    GetSampleData: procedure(Buffer: PSingle; Channel: Integer); cdecl;
    SetSampleData: procedure(Buffer: PSingle; Channel: Integer); cdecl;
    Edit: Pointer;
    Param: POBJECT_AUDIO_PARAM;
    GetOutputAudioParam: function(Obj: OBJECT_HANDLE; Offset: Double;
      Param: POBJECT_AUDIO_PARAM; ParamSize: Integer): Byte; cdecl;
    GetAudioObject: function(Layer: Integer; Offset: Double): OBJECT_HANDLE; cdecl;
  end;

  TFuncProcVideo = function(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
  TFuncProcAudio = function(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;

  // プラグインの能力、表示名、GUI 項目、処理関数を AviUtl2 へ渡す。
  PFILTER_PLUGIN_TABLE = ^TFILTER_PLUGIN_TABLE;
  TFILTER_PLUGIN_TABLE = record
    Flag: Integer;
    Name: LPCWSTR;
    Label_: LPCWSTR;
    Information: LPCWSTR;
    Items: ^Pointer;
    Func_Proc_Video: TFuncProcVideo;
    Func_Proc_Audio: TFuncProcAudio;
  end;

const
  FILTER_FLAG_VIDEO = 1;
  FILTER_FLAG_AUDIO = 2;
  FILTER_FLAG_INPUT = 4;
  FILTER_FLAG_FILTER = 8;

implementation

end.
