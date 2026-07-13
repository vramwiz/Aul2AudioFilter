unit AliasManagerFilterList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, RTTIPersistentIni,AliasManagerStringList;

type
  //===========================================================
  // 基底オブジェクト（Filter）
  //===========================================================
  TAliasManagerFilterItem = class(TRTTIPersistentIni)
  private
    // （フィールドなし）
  public
    procedure SaveToAlias(Strings : TAliasStringList); virtual;
  published
  end;

type
  //===========================================================
  // フィルターのリスト
  //===========================================================
  TAliasManagerFilterList = class(TRTTIPersistentIniListEx)
  private
    // フィルター要素取得用
    function GetLists(Index: Integer): TAliasManagerFilterItem;
  public
    procedure SaveToAlias(Strings : TAliasStringList);
    property Lists[Index : Integer] : TAliasManagerFilterItem read GetLists; default;
  end;


implementation

{ TAliasManagerFilterList }

function TAliasManagerFilterList.GetLists(Index: Integer): TAliasManagerFilterItem;
begin
  Result := inherited Items[Index];
end;

procedure TAliasManagerFilterList.SaveToAlias(Strings: TAliasStringList);
var
  i  : Integer;
begin
  for i := 0 to Count-1 do begin
    Lists[i].SaveToAlias(Strings);
  end;

end;

{ TAliasManagerFilterItem }

procedure TAliasManagerFilterItem.SaveToAlias(Strings: TAliasStringList);
begin
  Strings.AddSectionFilter();
end;


end.
