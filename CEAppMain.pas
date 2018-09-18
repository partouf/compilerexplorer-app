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
    lblCurrentTitle: TLabel;
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
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure pgMainChange(Sender: TObject);
    procedure indicatorCompilationClick(Sender: TObject);
    procedure acCompileExecute(Sender: TObject);
    procedure edCodeEditorChange(Sender: TObject);
    procedure cbCompilerSelectionChange(Sender: TObject);
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
  public
    { Public declarations }
  end;

var
  frmCEAppMain: TfrmCEAppMain;

implementation

uses
  CE.Languages, System.Generics.Collections, CE.Compilers, CE.Compile;

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
    InitializeLanguageTab;
  end
  else if pgMain.ActiveTab = tabCodeEditor then
  begin
    InitializeCodeEditor;
  end;
end;

procedure TfrmCEAppMain.InitializeLanguageTab;
begin
  if (lstLanguages.Count = 0) then
  begin
    FCELanguages.GetLanguages(
      procedure(Languages: TCELanguages)
      var
        Lang: TCELanguage;
      begin
        lstLanguages.Clear;
        for Lang in Languages do
        begin
          lstLanguages.Items.AddObject(Lang.LanguageName, Lang);
        end;

        FLoadedLanguages.Free;
        FLoadedLanguages := Languages;
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
        var
          Compiler: TCECompiler;
        begin
          FLoadedCompilers.Free;
          FLoadedCompilers := Compilers;

          cbCompilerSelection.Clear;
          cbCompilerSelection.Visible := True;
          for Compiler in FLoadedCompilers do
          begin
            cbCompilerSelection.Items.AddObject(Compiler.Description, Compiler);
          end;

          cbCompilerSelection.ItemIndex := cbCompilerSelection.Items.IndexOfObject(FLoadedCompilers.First);
        end);
    end;
  end;

  if Assigned(FSelectedLanguage) and (edCodeEditor.Text = '') then
  begin
    edCodeEditor.Text := FSelectedLanguage.ExampleCode;
  end;
end;

end.
