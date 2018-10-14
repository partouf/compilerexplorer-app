program CEApp;

uses
  System.StartUpCopy,
  FMX.Forms,
  CEAppMain in 'CEAppMain.pas' {frmCEAppMain},
  CE.Languages in '..\compilerexplorer-api\CE\CE.Languages.pas',
  CE.Interfaces in '..\compilerexplorer-api\CE\CE.Interfaces.pas',
  CE.Compilers in '..\compilerexplorer-api\CE\CE.Compilers.pas',
  CE.RESTBase in '..\compilerexplorer-api\CE\CE.RESTBase.pas',
  CE.Types in '..\compilerexplorer-api\CE\CE.Types.pas',
  CE.Compile in '..\compilerexplorer-api\CE\CE.Compile.pas',
  CE.LinkInfo in '..\compilerexplorer-api\CE\CE.LinkInfo.pas',
  CE.ClientState in '..\compilerexplorer-api\CE\CE.ClientState.pas',
  CE.LinkSaver in '..\compilerexplorer-api\CE\CE.LinkSaver.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmCEAppMain, frmCEAppMain);
  Application.Run;
end.
