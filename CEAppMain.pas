unit CEAppMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.Forms, FMX.Dialogs, FMX.TabControl, System.Actions, FMX.ActnList,
  FMX.Objects, FMX.StdCtrls, FMX.ScrollBox, FMX.Memo, FMX.Controls.Presentation,
  FMX.Layouts, FMX.ListBox, CE.Interfaces, CE.Types, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListView, FMX.Edit;

type
  TfrmCEAppMain = class(TForm)
    lstActions: TActionList;
    acPreviousTab: TPreviousTabAction;
    acNextTab: TNextTabAction;
    TopToolBar: TToolBar;
    btnBack: TSpeedButton;
    btnNext: TSpeedButton;
    pgMain: TTabControl;
    tabLanguageSelection: TTabItem;
    tabCodeEditor: TTabItem;
    BottomToolBar: TToolBar;
    edCodeEditor: TMemo;
    lstLanguages: TListBox;
    indicatorCompilation: TCircle;
    acCompile: TAction;
    cbCompilerSelection: TComboBox;
    btnCompilerSettings: TSpeedButton;
    acHeaderClick: TAction;
    lblCurrentTitle: TSpeedButton;
    btnKeyboard: TSpeedButton;
    tabCompilerOutput: TTabItem;
    splitOutput: TSplitter;
    lstAssembly: TMemo;
    lstCompilerOutput: TMemo;
    acToggleCompilerArguments: TAction;
    acSave: TAction;
    btnSave: TSpeedButton;
    acLoadFromLink: TAction;
    btnLoadFromLink: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure pgMainChange(Sender: TObject);
    procedure indicatorCompilationClick(Sender: TObject);
    procedure acCompileExecute(Sender: TObject);
    procedure edCodeEditorChange(Sender: TObject);
    procedure cbCompilerSelectionChange(Sender: TObject);
    procedure acHeaderClickExecute(Sender: TObject);
    procedure btnKeyboardClick(Sender: TObject);
    procedure acToggleCompilerArgumentsExecute(Sender: TObject);
    procedure acSaveExecute(Sender: TObject);
    procedure acLoadFromLinkExecute(Sender: TObject);
  private
    { Private declarations }
    FCELanguages: ICELanguages;
    FCECompilers: ICECompilers;
    FCECompile: ICECompile;
    FCELinkInfo: ICELinkInfo;
    FSelectedLanguage: TCELanguage;
    FLoadedLanguages: TCELanguages;
    FLoadedCompilers: TCECompilers;
    FSelectedCompiler: TCECompiler;
    FLatestCompileResult: TCECompileResult;
    FCurrentCompilerArguments: string;
    FHasLoadedCompilers: Boolean;
    FOnCompilersLoaded: TProc;
    procedure InitializeLanguageTab;
    procedure InitializeCodeEditor;
    procedure HandleCompileResult;
    procedure UpdateLanguageList;
    procedure UpdateCompilerList;
    procedure InitializeCompilerOutput;
    procedure SelectLanguage(const Id: string);
    procedure TypeCode(const Code: string);
    procedure SelectCompiler(const Id: string);
    procedure SetCompilerOptions(const Options: string);
    procedure GoToTab(const Tab: TTabItem);
  public
    { Public declarations }
  end;

var
  frmCEAppMain: TfrmCEAppMain;

implementation

uses
  CE.Languages, System.Generics.Collections, CE.Compilers, CE.Compile,
  FMX.VirtualKeyboard, FMX.Platform, FMX.DialogService,
  System.IOUtils, System.DateUtils, System.StrUtils, CE.LinkInfo,
  CE.ClientState;

{$R *.fmx}
{$R *.LgXhdpiPh.fmx ANDROID}
{$R *.iPhone55in.fmx IOS}
{$R *.iPhone4in.fmx IOS}

procedure TfrmCEAppMain.acCompileExecute(Sender: TObject);
begin
  if Assigned(FSelectedLanguage) and Assigned(FSelectedCompiler) then
  begin
    FCECompile.Compile(FSelectedLanguage.Id, FSelectedCompiler.CompilerId, edCodeEditor.Text, FCurrentCompilerArguments,
      procedure(CompileResult: TCECompileResult)
      begin
        FLatestCompileResult.Free;
        FLatestCompileResult := CompileResult;

        HandleCompileResult;
      end
    );
  end;
end;

procedure TfrmCEAppMain.acHeaderClickExecute(Sender: TObject);
var
  Service: IFMXVirtualKeyboardService;
begin
  if pgMain.ActiveTab = tabCodeEditor then
  begin
    FreeAndNil(FLatestCompileResult);
    HandleCompileResult;

    TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, IInterface(Service));
    if Assigned(Service) then
    begin
      Service.HideVirtualKeyboard;
    end;
  end;
end;

procedure TfrmCEAppMain.SelectLanguage(const Id: string);
var
  Language: TCELanguage;
begin
  if Assigned(FLoadedLanguages) and (FLoadedLanguages.Count <> 0) then
  begin
    Language := FLoadedLanguages.GetById(Id);
    lstLanguages.ItemIndex := lstLanguages.Items.IndexOfObject(Language);

    GoToTab(tabCodeEditor);
  end;
end;

procedure TfrmCEAppMain.TypeCode(const Code: string);
begin
  edCodeEditor.Text := Code;
end;

procedure TfrmCEAppMain.SelectCompiler(const Id: string);
var
  Compiler: TCECompiler;
begin
  while not FHasLoadedCompilers do
  begin
    Sleep(100);
  end;

  if Assigned(FLoadedCompilers) and (FLoadedCompilers.Count <> 0) then
  begin
    Compiler := FLoadedCompilers.FindById(Id);
    cbCompilerSelection.ItemIndex := cbCompilerSelection.Items.IndexOfObject(Compiler);
  end;
end;

procedure TfrmCEAppMain.SetCompilerOptions(const Options: string);
begin
  FCurrentCompilerArguments := Options;
end;

procedure TfrmCEAppMain.acLoadFromLinkExecute(Sender: TObject);
var
  Link: string;
begin
  Link := 'http://192.168.4.139:10240/z/3MbByS';

  FCELinkInfo.GetClientState(Link,
    procedure(State: TCEClientState)
    var
      Session: TCEClientStateSession;
      Compiler: TCEClientStateCompiler;
    begin
      TThread.Synchronize(nil,
        procedure
        begin
          Session := State.Sessions.First;
          FOnCompilersLoaded :=
            procedure
            begin
              TypeCode(Session.Source);

              Compiler := Session.Compilers.First;
              SelectCompiler(Compiler.Id);

              SetCompilerOptions(Compiler.Options);
              acCompile.Execute;
            end;
          SelectLanguage(Session.Language);
        end);
    end);
end;

procedure TfrmCEAppMain.acSaveExecute(Sender: TObject);
var
  SavePath: string;
  Filename: string;
begin
  SavePath := TPath.Combine(TPath.GetDocumentsPath, 'CEApp');
  ForceDirectories(SavePath);

  Filename := TPath.Combine(SavePath, FormatDateTime('yyyymmddhhnnss', Now) + '.txt');
  edCodeEditor.Lines.SaveToFile(Filename);
end;

procedure TfrmCEAppMain.acToggleCompilerArgumentsExecute(Sender: TObject);
begin
  TDialogService.InputQuery('Compiler arguments', [''], [FCurrentCompilerArguments],
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      if FCurrentCompilerArguments <> AValues[0] then
      begin
        FCurrentCompilerArguments := AValues[0];

        FreeAndNil(FLatestCompileResult);
        HandleCompileResult;
      end;
    end
  );
end;

procedure TfrmCEAppMain.cbCompilerSelectionChange(Sender: TObject);
begin
  FSelectedCompiler := nil;
  if Assigned(cbCompilerSelection.Selected) then
  begin
    FSelectedCompiler := (cbCompilerSelection.Selected.Data as TCECompiler);
  end;

  btnCompilerSettings.Visible := Assigned(FSelectedCompiler);

  FreeAndNil(FLatestCompileResult);
  HandleCompileResult;
end;

procedure TfrmCEAppMain.edCodeEditorChange(Sender: TObject);
begin
  FreeAndNil(FLatestCompileResult);
  HandleCompileResult;
end;

procedure TfrmCEAppMain.FormCreate(Sender: TObject);
begin
  FCELanguages := TCELanguagesFromRest.Create;
  FCECompilers := TCECompilersFromRest.Create;
  FCECompile := TCECompileViaRest.Create;
  FCELinkInfo := TCELinkInfo.Create;

  pgMain.First(TTabTransition.None);
  pgMainChange(nil);

{$IFDEF ANDROID}
  edCodeEditor.Font.Family := 'monospace';
{$ENDIF}
end;

procedure TfrmCEAppMain.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if (Key = vkHardwareBack) and (pgMain.TabIndex <> 0) then
  begin
    pgMain.First;
    Key := 0;
  end;
end;

procedure TfrmCEAppMain.GoToTab(const Tab: TTabItem);
begin
  pgMain.ActiveTab := Tab;
  pgMainChange(pgMain);
end;

procedure TfrmCEAppMain.HandleCompileResult;
begin
  TThread.Synchronize(nil,
    procedure
    begin
      if Assigned(FLatestCompileResult) then
      begin
        if FLatestCompileResult.Successful then
        begin
          indicatorCompilation.Fill.Color := TAlphaColorRec.Green;
        end
        else
        begin
          indicatorCompilation.Fill.Color := TAlphaColorRec.Red;
        end;
      end
      else
      begin
        indicatorCompilation.Fill.Color := TAlphaColorRec.Lightgray;
      end;

      if pgMain.ActiveTab = tabCompilerOutput then
      begin
        InitializeCompilerOutput;
      end;
    end);
end;

procedure TfrmCEAppMain.UpdateLanguageList;
begin
  TThread.Synchronize(nil,
    procedure
    var
      Lang: TCELanguage;
    begin
      lstLanguages.BeginUpdate;
      try
        lstLanguages.Clear;
        for Lang in FLoadedLanguages do
        begin
          lstLanguages.Items.AddObject(Lang.LanguageName, Lang);
        end;
      finally
        lstLanguages.EndUpdate;
      end;
    end);
end;

procedure TfrmCEAppMain.UpdateCompilerList;
begin
  TThread.Synchronize(nil,
    procedure
    var
      Compiler: TCECompiler;
    begin
      cbCompilerSelection.BeginUpdate;
      try
        cbCompilerSelection.Clear;
        cbCompilerSelection.Visible := True;
        for Compiler in FLoadedCompilers do
        begin
          cbCompilerSelection.Items.AddObject(Compiler.Description, Compiler);
        end;
        cbCompilerSelection.ItemIndex := cbCompilerSelection.Items.IndexOfObject(FLoadedCompilers.First);
      finally
        cbCompilerSelection.EndUpdate;
      end;
    end);
end;

procedure TfrmCEAppMain.InitializeCompilerOutput;
var
  AsmLine: TCEAssemblyLine;
  ErrorLine: TCEErrorLine;
begin
  lstCompilerOutput.BeginUpdate;
  try
    lstCompilerOutput.Lines.Clear;
    if Assigned(FLatestCompileResult) then
    begin
      for ErrorLine in FLatestCompileResult.CompilerOutput do
      begin
        lstCompilerOutput.Lines.AddObject(ErrorLine.Text, ErrorLine);
      end;
    end;
  finally
    lstCompilerOutput.EndUpdate;
  end;

  lstAssembly.BeginUpdate;
  try
    lstAssembly.Lines.Clear;
    if Assigned(FLatestCompileResult) then
    begin
      for AsmLine in FLatestCompileResult.Assembly do
      begin
        lstAssembly.Lines.AddObject(AsmLine.Text, AsmLine);
      end;
    end;
  finally
    lstAssembly.EndUpdate;
  end;
end;

procedure TfrmCEAppMain.indicatorCompilationClick(Sender: TObject);
begin
  acCompile.Execute;
end;

procedure TfrmCEAppMain.pgMainChange(Sender: TObject);
begin
  if pgMain.ActiveTab <> nil then
    lblCurrentTitle.Text := pgMain.ActiveTab.Text
  else
    lblCurrentTitle.Text := '';

  btnKeyboard.Visible := False;
  btnSave.Visible := False;
  BottomToolbar.Visible := pgMain.ActiveTab <> tabLanguageSelection;

  if pgMain.ActiveTab = tabLanguageSelection then
  begin
    btnBack.Visible := False;
    InitializeLanguageTab;
  end
  else if pgMain.ActiveTab = tabCodeEditor then
  begin
    btnBack.Visible := True;
    InitializeCodeEditor;
    btnKeyboard.Visible := True;
  end
  else if pgMain.ActiveTab = tabCompilerOutput then
  begin
    InitializeCompilerOutput;
  end;

end;

procedure TfrmCEAppMain.btnKeyboardClick(Sender: TObject);
var
  Service: IFMXVirtualKeyboardService;
begin
  TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, IInterface(Service));
  if Assigned(Service) then
  begin
    Service.ShowVirtualKeyboard(edCodeEditor);
  end;
end;

procedure TfrmCEAppMain.InitializeLanguageTab;
begin
  if (lstLanguages.Count = 0) then
  begin
    FCELanguages.GetLanguages(
      procedure(Languages: TCELanguages)
      begin
        FLoadedLanguages.Free;
        FLoadedLanguages := Languages;

        UpdateLanguageList;
      end);
  end;
end;

procedure TfrmCEAppMain.InitializeCodeEditor;
var
  NewLanguage: TCELanguage;
begin
  if Assigned(lstLanguages.Selected) then
  begin
    NewLanguage := (lstLanguages.Selected.Data as TCELanguage);
    if FSelectedLanguage <> NewLanguage then
    begin
      FHasLoadedCompilers := False;
      edCodeEditor.Text := '';
      FSelectedLanguage := NewLanguage;
      cbCompilerSelection.Visible := False;

      FCECompilers.GetCompilers(FSelectedLanguage.Id,
        procedure(Compilers: TCECompilers)
        begin
          FLoadedCompilers.Free;
          FLoadedCompilers := Compilers;

          UpdateCompilerList;

          FHasLoadedCompilers := True;
          if Assigned(FOnCompilersLoaded) then
          begin
            FOnCompilersLoaded();
            FOnCompilersLoaded := nil;
          end;
        end);
    end;
  end;

  if Assigned(FSelectedLanguage) and (edCodeEditor.Text = '') then
  begin
    edCodeEditor.Text := FSelectedLanguage.ExampleCode;
  end;
end;

end.
