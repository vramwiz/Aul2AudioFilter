unit AliasManagerPositionList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, RTTIPersistentIni,AliasManagerStringList;

type
  //===========================================================
  //  フレームクラス
  //===========================================================
  TAliasManagerPositionItem = class(TRTTIPersistentIni)
  private
    FFrame: Integer;
  public
  published
    property Frame : Integer read FFrame write FFrame;

  end;

type
  //===========================================================
  // フレームリストクラス
  //===========================================================
  TAliasManagerPositionList = class(TRTTIPersistentIniList<TAliasManagerPositionItem>)
  private
    function GetPositions(Index: Integer): TAliasManagerPositionItem;
  public
    property Positions[Index : Integer] : TAliasManagerPositionItem read GetPositions; default;
  end;


implementation

{ TAliasManagerPositionList }

function TAliasManagerPositionList.GetPositions(  Index: Integer): TAliasManagerPositionItem;
begin
  Result := inherited Items[Index];
end;



end.
