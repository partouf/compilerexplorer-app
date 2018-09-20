unit CEAppMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.Forms, FMX.Dialogs, FMX.TabControl, System.Actions, FMX.ActnList,
  FMX.Objects, FMX.StdCtrls, FMX.ScrollBox, FMX.Memo, FMX.Controls.Presentation,
  FMX.Layouts, FMX.ListBox, CE.Interfaces, CE.Types;

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
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure pgMainChange(Sender: TObject);
    procedure indicatorCompilationClick(Sender: TObject);
    procedure acCompileExecute(Sender: TObject);
    procedure edCodeEditorChange(Sender: TObject);
    procedure cbCompilerSelectionChange(Sender: TObject);
    procedure acHeaderClickExecute(Sender: TObject);
    procedure btnKeyboardClick(Sender: TObject);
  private
    { Private declarations }
    FCELanguages: ICELanguages;
    FSelectedLanguage: TCELanguage;
    FCECompilers: ICECompilers;
    FLoadedLanguages: TCELanguages;
    FLoadedCompilers: TCECompilers;
    FCECompile: ICECompile;
    FSelectedCompiler: TCECompiler;
    FLatestCompileResult: TCECompileResult;
    procedure InitializeLanguageTab;
    procedure InitializeCodeEditor;
    procedure HandleCompileResult;
    procedure UpdateLanguageList;
    procedure UpdateCompilerList;
  public
    { Public declarations }
  end;

var
  frmCEAppMain: TfrmCEAppMain;

implementation

uses
  CE.Languages, System.Generics.Collections, CE.Compilers, CE.Compile,
  FMX.VirtualKeyboard, FMX.Platform;

{$R *.fmx}
{$R *.LgXhdpiPh.fmx ANDROID}
{$R *.iPhone4in.fmx IOS}

procedure TfrmCEAppMain.acCompileExecute(Sender: TObject);
begin
  if Assigned(FSelectedLanguage) and Assigned(FSelectedCompiler) then
  begin
    FCECompile.Compile(FSelectedLanguage.Id, FSelectedCompiler.CompilerId, edCodeEditor.Text,
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
  FreeAndNil(FLatestCompileResult);
  HandleCompileResult;

  TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, IInterface(Service));
  if Assigned(Service) then
  begin
    Service.HideVirtualKeyboard;
  end;
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

  pgMain.First(TTabTransition.None);
  pgMainChange(nil);
end;

procedure TfrmCEAppMain.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if (Key = vkHardwareBack) and (pgMain.TabIndex <> 0) then
  begin
    pgMain.First;
    Key := 0;
  end;
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

  if pgMain.ActiveTab = tabLanguageSelection then
  begin
    btnBack.Visible := False;
    InitializeLanguageTab;
  end
  else if pgMain.ActiveTab = tabCodeEditor then
  begin
    btnBack.Visible := True;
    InitializeCodeEditor;
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
      edCodeEditor.Text := '';
      FSelectedLanguage := NewLanguage;
      cbCompilerSelection.Visible := False;

      FCECompilers.GetCompilers(FSelectedLanguage.Id,
        procedure(Compilers: TCECompilers)
        begin
          FLoadedCompilers.Free;
          FLoadedCompilers := Compilers;

          UpdateCompilerList;
        end);
    end;
  end;

  if Assigned(FSelectedLanguage) and (edCodeEditor.Text = '') then
  begin
    edCodeEditor.Text := FSelectedLanguage.ExampleCode;
  end;
end;

end.
