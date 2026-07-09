unit Aul2AudioViewPlugin;

// Provides the entry point for the view filter placed on Aul2AudioBaseInput.

interface

uses
  Aul2AudioFilterTypes;

function GetViewFilterTable: PFILTER_PLUGIN_TABLE;
procedure InitializeViewPlugin;
procedure FinalizeViewPlugin;

implementation

uses
  Aul2AudioFilterGui;

procedure InitializeViewPlugin;
begin
end;

function ViewProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  Result := 1;
end;

function GetViewFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if GTable.Name = nil then
    SetupPluginTable(
      FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,       // モード指定
      'Aul2Audio View',                              // 名称
      'Video Effects',                               // グループ
      'Aul2AudioView for AviUtl ExEdit2',            // 詳細
      ViewProcVideo,
      nil
    );

  Result := @GTable;
end;

procedure FinalizeViewPlugin;
begin
end;

end.
