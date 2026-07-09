unit AviUtl2PluginCore;

interface

uses
  AviUtl2PluginTypes;

type
  TAviUtl2EditState = (
    aesEdit,   // 編集中
    aesPlay,   // 再生中
    aesSave    // 出力中
  );

// エディタが編集状態か取得
function AviUtl2GetEditState: TAviUtl2EditState;

var

  EditHandle         : PEditHandle = nil;    // 編集用ハンドル
  ProjectFile        : PProjectFile = nil;   // プロジェクト用ハンドル
  GAviUtl2Plugin     : Boolean;              // True : AviUtl2拡張プラグインとして実行 ※現在未使用

implementation


function AviUtl2GetEditState: TAviUtl2EditState;
var
  State: Integer;
begin
  if EditHandle = nil then Exit(aesEdit);

  State := EditHandle.GetEditState;

  if (State >= Ord(Low(TAviUtl2EditState))) and (State <= Ord(High(TAviUtl2EditState))) then
    Result := TAviUtl2EditState(State)
  else
    Result := aesEdit;
end;

end.
