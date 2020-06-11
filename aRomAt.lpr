program aRomAt;

{$MODE Delphi}

uses
  Forms,
  Interfaces,
  MainDumpForm;

{$R *.res}

begin
  Application.Scaled:=True;
  Application.Initialize;
  Application.Title:='aRomAt';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
