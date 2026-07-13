unit RTTIPersistentFrame;

interface

uses
  Windows, Messages, SysUtils, Classes,   Forms, Dialogs,
  StdCtrls, ExtCtrls,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistent,RTTIPersistentIni;

//--------------------------------------------------------------------------//
//  TFrameの表示に必要な座標を保存、復元                                    //
//--------------------------------------------------------------------------//
type
	TRTTIFrame = class(TRTTIPersistentIni)
	private
		{ Private 宣言 }
	public
		{ Public 宣言 }
    // 値を初期化
    // フレームの座標情報をデータ化
    procedure FrameToSelf(AFrame : TFRame);virtual;abstract;
    // データをフレームの情報に復元
    procedure SelfToFrame(AFrame : TFRame);virtual;abstract;

	end;


implementation

{ TRTTIFrame }


{ TRTTIFrame }


end.
