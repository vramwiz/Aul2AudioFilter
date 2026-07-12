unit Aul2AudioFilterTypes;

// AviUtl2 SDK のフィルター関連構造体を Delphi から参照するための型定義。

{$ALIGN 8}

interface

uses
  Winapi.Windows;

type
  PEDIT_SECTION = ^TEDIT_SECTION;
  TFilterItemButtonCallback = procedure(Edit: PEDIT_SECTION); cdecl;

  LPCWSTR       = PWideChar; // SDK 側の変更不可Wide文字列ポインター。
  OBJECT_HANDLE = Pointer;   // AviUtl2 内部オブジェクトへの不透明ハンドル。

  // GUI グループ項目。後続の track/check/select を AviUtl2 上でまとめる。
  PFILTER_ITEM_GROUP = ^TFILTER_ITEM_GROUP;
  TFILTER_ITEM_GROUP = record
    ItemType      : LPCWSTR; // SDK が識別する項目種別文字列。
    Name          : LPCWSTR; // GUI に表示するグループ名。
    DefaultVisible: Byte;    // 初期状態で展開する場合1。
  end;

  // ON/OFF 用の GUI 項目。
  PFILTER_ITEM_CHECK = ^TFILTER_ITEM_CHECK;
  TFILTER_ITEM_CHECK = record
    ItemType: LPCWSTR; // SDK が識別する項目種別文字列。
    Name    : LPCWSTR; // GUI に表示する項目名。
    Value   : Byte;    // OFF=0、ON=1の現在値。
  end;

  // 色選択用の GUI 項目。
  PFILTER_ITEM_COLOR = ^TFILTER_ITEM_COLOR;
  TFILTER_ITEM_COLOR = record
    ItemType  : LPCWSTR; // SDK が識別する項目種別文字列。
    Name      : LPCWSTR; // GUI に表示する項目名。
    B, G, R, X: Byte;    // SDK 配置順の青、緑、赤、アルファ成分。
  end;

  // 数値スライダー用の GUI 項目。
  PFILTER_ITEM_TRACK = ^TFILTER_ITEM_TRACK;
  TFILTER_ITEM_TRACK = record
    ItemType  : LPCWSTR; // SDK が識別する項目種別文字列。
    Name      : LPCWSTR; // GUI に表示する項目名。
    Value     : Double;  // 現在値。
    S, E      : Double;  // スライダーの開始値と終了値。
    Step      : Double;  // 操作時の最小変化量。
    ZeroDisplay: LPCWSTR; // 値0の代わりに表示する文字列。
    SliderRatio: Double;  // GUI 表示へ適用するスライダー倍率。
  end;

  // 選択肢リスト用の GUI 項目。
  PFILTER_ITEM_SELECT = ^TFILTER_ITEM_SELECT;
  TFILTER_ITEM_SELECT_ITEM = record
    Name : LPCWSTR; // GUI に表示する選択肢名。
    Value: Integer; // 選択時に項目へ格納する値。
  end;

  TFILTER_ITEM_SELECT = record
    ItemType: LPCWSTR;                     // SDK が識別する項目種別文字列。
    Name    : LPCWSTR;                     // GUI に表示する項目名。
    Value   : Integer;                     // 現在選択されている値。
    List    : ^TFILTER_ITEM_SELECT_ITEM;   // nil 終端された選択肢配列。
  end;

  // ボタン項目。押下時に編集コールバックとして呼ばれるため、設定変更APIの実験に使う。
  PFILTER_ITEM_BUTTON = ^TFILTER_ITEM_BUTTON;
  TFILTER_ITEM_BUTTON = record
    ItemType: LPCWSTR;                   // SDK が識別する項目種別文字列。
    Name    : LPCWSTR;                   // GUI に表示するボタン名。
    Callback: TFilterItemButtonCallback; // 押下時に呼ばれる編集コールバック。
  end;

  TSetObjectItemValueFunc = function(Obj: OBJECT_HANDLE; Effect: LPCWSTR;
    Item: LPCWSTR; Value: PAnsiChar): Byte; cdecl;
  TGetFocusObjectFunc = function: OBJECT_HANDLE; cdecl;

  // EDIT_SECTION はSDK上大きな構造体だが、ここでは先頭から必要な関数までだけ定義する。
  TEDIT_SECTION = record
    Info                 : Pointer;                 // SDK内部の編集情報。
    CreateObjectFromAlias: Pointer;                 // エイリアスからオブジェクトを作るSDK関数。
    FindObject           : Pointer;                 // 条件に合うオブジェクトを探すSDK関数。
    CountObjectEffect    : Pointer;                 // オブジェクトのエフェクト数を得るSDK関数。
    GetObjectLayerFrame  : Pointer;                 // オブジェクトのレイヤーとフレームを得るSDK関数。
    GetObjectAlias       : Pointer;                 // オブジェクトのエイリアスを得るSDK関数。
    GetObjectItemValue   : Pointer;                 // GUI項目値を得るSDK関数。
    SetObjectItemValue   : TSetObjectItemValueFunc; // GUI項目値を変更するSDK関数。
    MoveObject           : Pointer;                 // オブジェクトを移動するSDK関数。
    DeleteObject         : Pointer;                 // オブジェクトを削除するSDK関数。
    GetFocusObject       : TGetFocusObjectFunc;     // 現在選択中のオブジェクトを得るSDK関数。
  end;

  // Scene は処理中の動画・音声全体に関する情報を持つ。
  PSCENE_INFO = ^TSCENE_INFO;
  TSCENE_INFO = record
    Width, Height: Integer; // シーンの映像幅と高さ。
    Rate, Scale  : Integer; // フレームレートを Rate / Scale で表す値。
    SampleRate   : Integer; // シーンの音声サンプリング周波数。
  end;

  // Object_ は現在処理中の音声オブジェクトとエフェクト位置を識別する。
  POBJECT_INFO = ^TOBJECT_INFO;
  TOBJECT_INFO = record
    ID           : Int64;   // AviUtl2内でオブジェクトを識別する値。
    Frame        : Integer; // オブジェクト内の現在相対フレーム。
    FrameTotal   : Integer; // オブジェクトの総フレーム数。
    Time         : Double;  // オブジェクト内の現在相対時間。
    TimeTotal    : Double;  // オブジェクトの総時間。
    Width, Height: Integer; // 現在の映像幅と高さ。
    SampleIndex  : Int64;   // オブジェクト内の現在先頭サンプル位置。
    SampleTotal  : Int64;   // オブジェクトの総サンプル数。
    SampleNum    : Integer; // 今回処理する1チャンネル当たりのサンプル数。
    ChannelNum   : Integer; // 音声チャンネル数。
    EffectID     : Int64;   // 現在処理中のエフェクト識別値。
    Flag         : Integer; // SDKが定義するオブジェクト状態フラグ。
    Layer        : Integer; // 内部0-basedレイヤー番号。
    Index        : Integer; // コールバック対象ブロックの位置。
    Num          : Integer; // 同一処理単位に含まれるブロック数。
    FrameS       : Integer; // 編集全体でのオブジェクト開始フレーム。
    FrameE       : Integer; // 編集全体でのオブジェクト終了フレーム。
  end;

  // AviUtl2 側の音量パラメーター。現時点では参照のみ。
  POBJECT_AUDIO_PARAM = ^TOBJECT_AUDIO_PARAM;
  TOBJECT_AUDIO_PARAM = record
    VolL, VolR: Single; // AviUtl2側の左右音量倍率。
  end;

  // SetImageData が受け取る8bit RGBA画素。packed配置を変更しない。
  TPIXEL_RGBA = packed record
    R, G, B, A: Byte; // 赤、緑、青、アルファの各成分。
  end;
  PPIXEL_RGBA = ^TPIXEL_RGBA;

  PID3D11Texture2D = Pointer;
  TFilterProcVideoGetTex2D = function: PID3D11Texture2D; cdecl;

  PFILTER_PROC_VIDEO = ^TFILTER_PROC_VIDEO;
  TFILTER_PROC_VIDEO = record
    Scene                  : PSCENE_INFO; // 現在のシーン情報。
    Object_                : POBJECT_INFO; // 現在処理中のオブジェクト情報。
    GetImageData           : procedure(Buffer: PPIXEL_RGBA); cdecl; // 入力画像をCPUメモリへ得る。
    SetImageData           : procedure(Buffer: PPIXEL_RGBA; Width, Height: Integer); cdecl; // 画像を出力する。
    GetImageTexture2D      : TFilterProcVideoGetTex2D; // 入力画像のD3D11テクスチャを得る。
    GetFramebufferTexture2D: TFilterProcVideoGetTex2D; // 出力先のD3D11テクスチャを得る。
  end;

  // 音声フィルター処理時に AviUtl2 から渡される入出力 API。
  PFILTER_PROC_AUDIO = ^TFILTER_PROC_AUDIO;
  TFILTER_PROC_AUDIO = record
    Scene          : PSCENE_INFO;  // 現在のシーン情報。
    Object_        : POBJECT_INFO; // 現在処理中のオブジェクト情報。
    GetSampleData  : procedure(Buffer: PSingle; Channel: Integer); cdecl; // 指定チャンネルを得る。
    SetSampleData  : procedure(Buffer: PSingle; Channel: Integer); cdecl; // 指定チャンネルを戻す。
    Edit           : Pointer;             // SDK内部の編集コンテキスト。
    Param          : POBJECT_AUDIO_PARAM; // 現在の音量パラメーター。
    GetOutputAudioParam: function(Obj: OBJECT_HANDLE; Offset: Double;
      Param: POBJECT_AUDIO_PARAM; ParamSize: Integer): Byte; cdecl; // 指定位置の出力音量を得る。
    GetAudioObject : function(Layer: Integer; Offset: Double): OBJECT_HANDLE; cdecl; // 音声Objectを得る。
  end;

  TFuncProcVideo = function(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
  TFuncProcAudio = function(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;

  // プラグインの能力、表示名、GUI 項目、処理関数を AviUtl2 へ渡す。
  PFILTER_PLUGIN_TABLE = ^TFILTER_PLUGIN_TABLE;
  TFILTER_PLUGIN_TABLE = record
    Flag           : Integer;        // FILTER_FLAG_* を組み合わせた能力指定。
    Name           : LPCWSTR;        // AviUtl2上のフィルター表示名。
    Label_         : LPCWSTR;        // フィルターを配置するGUIグループ名。
    Information    : LPCWSTR;        // プラグイン情報表示用の説明。
    Items          : ^Pointer;       // nil終端されたGUI項目ポインター配列。
    Func_Proc_Video: TFuncProcVideo; // 映像処理コールバック。
    Func_Proc_Audio: TFuncProcAudio; // 音声処理コールバック。
  end;

const
  FILTER_FLAG_VIDEO  = 1; // 映像処理を持つ。
  FILTER_FLAG_AUDIO  = 2; // 音声処理を持つ。
  FILTER_FLAG_INPUT  = 4; // 入力プラグインとして登録する。
  FILTER_FLAG_FILTER = 8; // フィルターとして登録する。

implementation

end.
