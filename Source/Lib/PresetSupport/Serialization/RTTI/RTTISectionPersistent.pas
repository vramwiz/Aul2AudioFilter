unit RTTISectionPersistent;

interface

uses
  Windows, Messages, SysUtils, Classes,   Forms, Dialogs,
  StdCtrls, ExtCtrls,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistentIni;

type
  TRTTISectionPersistentList <T: TRTTIPersistentIni, constructor> =class(TRTTIPersistentIniList<T>)
  private
  public
    procedure LoadFromStrings(ts : TStringList;const ALeft : string = '{'; ARight: string = '}'); reintroduce; overload;
    procedure SaveToStrings(ts : TStringList;const ALeft : string = '{'; ARight: string = '}'); reintroduce; overload;

  end;

implementation

uses SectionFileManager;


{ TRTTISectionPersistentList<T> }

procedure TRTTISectionPersistentList<T>.LoadFromStrings(ts: TStringList;const ALeft : string = '{'; ARight: string = '}');
var
  j : Integer;
  tt : TStringList;
  ms : TSectionFileManager;
  Item : T;
begin
  ms := TSectionFileManager.Create;
  try
    ms.SetBrackets(ALeft,ARight);
    ms.LoadFromStrings(ts);
    j := 0;
    while j < 9999 do begin
      tt := ms.GetSection(IntToStr(j));
      if tt = nil then break;
      Item := AddNew();
      Item.DeserializeFromStrings(Item,tt);
      Inc(j);
    end;
  finally
    ms.Free;
  end;
end;

procedure TRTTISectionPersistentList<T>.SaveToStrings(ts: TStringList;const ALeft : string = '{'; ARight: string = '}');
var
  j : Integer;
  tt : TStringList;
  ms : TSectionFileManager;
  Item : T;
begin
  ms := TSectionFileManager.Create;
  tt := TStringList.Create;
  try
    ms.SetBrackets(ALeft,ARight);
    for j := 0 to Count-1 do begin
      Item := Items[j];
      tt.Clear;
      Item.SerializeToStrings(Item,tt);
      ms.AddSection(IntToStr(j),tt);
    end;
    ms.SaveToStrings(ts);
  finally
    ms.Free;
    tt.Free;
  end;
end;

end.
