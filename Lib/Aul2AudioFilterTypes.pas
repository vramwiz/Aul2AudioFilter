unit Aul2AudioFilterTypes;

{$ALIGN 8}

interface

uses
  Winapi.Windows;

type
  LPCWSTR = PWideChar;
  OBJECT_HANDLE = Pointer;

  PFILTER_ITEM_GROUP = ^TFILTER_ITEM_GROUP;
  TFILTER_ITEM_GROUP = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    DefaultVisible: Byte;
  end;

  PFILTER_ITEM_CHECK = ^TFILTER_ITEM_CHECK;
  TFILTER_ITEM_CHECK = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: Byte;
  end;

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

  PSCENE_INFO = ^TSCENE_INFO;
  TSCENE_INFO = record
    Width, Height: Integer;
    Rate, Scale: Integer;
    SampleRate: Integer;
  end;

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

  POBJECT_AUDIO_PARAM = ^TOBJECT_AUDIO_PARAM;
  TOBJECT_AUDIO_PARAM = record
    VolL, VolR: Single;
  end;

  PFILTER_PROC_VIDEO = Pointer;

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
