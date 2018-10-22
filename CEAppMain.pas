unit CEAppMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Graphics, FMX.Forms, FMX.Dialogs, FMX.TabControl, System.Actions, FMX.ActnList,
  FMX.Objects, FMX.StdCtrls, FMX.ScrollBox, FMX.Memo, FMX.Controls.Presentation,
  FMX.Layouts, FMX.ListBox, CE.Interfaces, CE.Types, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListView, FMX.Edit,
  {$ifdef ANDROID}
  Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.JavaTypes,
  {$endif}
  {$ifdef IOS}
  FMX.Platform.IOS,
  {$endif}
  FMX.Platform, System.Messaging, CE.ClientState, System.Generics.Collections,
  FMX.TreeView,
  CEAppState, FMX.Gestures;

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
    tabLanguageLibraries: TTabItem;
    lstLanguageLibraries: TListBox;
    btnSelectLibraries: TSpeedButton;
    acSelectLibraries: TAction;
    btnLoadFromLink: TSpeedButton;
    aniBusy: TAniIndicator;
    tmrBusy: TTimer;
    tabClientState: TTabItem;
    treeClientState: TTreeView;
    btnPlaySessionCompiler: TSpeedButton;
    acPlaySessionCompiler: TAction;
    gestMgr: TGestureManager;
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
    procedure FormDestroy(Sender: TObject);
    procedure acSelectLibrariesExecute(Sender: TObject);
    procedure tmrBusyTimer(Sender: TObject);
    procedure acLoadFromLinkExecute(Sender: TObject);
    procedure acPlaySessionCompilerExecute(Sender: TObject);
    procedure lstLanguageLibrariesChangeCheck(Sender: TObject);
    procedure FormGesture(Sender: TObject; const EventInfo: TGestureEventInfo;
      var Handled: Boolean);
    procedure lstLanguagesChange(Sender: TObject);
  private
    { Private declarations }
    FCEAppState: TCEAppState;
    FDefaultFontSize: Single;
    FPreviousDistance: Integer;

    procedure RegisterIntent;
    procedure InitializeLanguageTab;
    procedure InitializeCodeEditor;
    procedure HandleCompileResult;
    procedure UpdateLanguageList;
    procedure UpdateCompilerList;
    procedure InitializeCompilerOutput;
    procedure SelectLanguage(const Id: string);
    procedure TypeCode(const Code: string);
    procedure SelectCompiler(const Id: string);
    procedure SetCompilerArguments(const Options: string);
    procedure GoToTab(const Tab: TTabItem);
    procedure HandleActivityMessage(const Sender: TObject; const M: TMessage);
    function HandleAppEvent(AAppEvent: TApplicationEvent;
      AContext: TObject): Boolean;
    {$ifdef ANDROID}
    function HandleAnroidIntentAction(const Data: JIntent): Boolean;
    {$endif}
    {$ifdef IOS}
    function HandleIOSIntentAction(const Context: TiOSOpenApplicationContext): Boolean;
    {$endif}
    procedure LoadState(const State: TCEClientState);
    procedure LoadStateFromLink(const Link: string);
    procedure UpdateLibrariesList;
    procedure SelectLibraries(const Libs: TList<TCEClientStateLibraryVersion>);
    procedure ShowAssemblyOutput;
    procedure ShowCompilerOutputAndErrors;
    procedure EnableBusyIndicator;
    procedure DisableBusyIndicator;
    function GetSelectedLibraries: TList<TCELibraryVersion>;
    procedure ShowPossibleSessions;
    procedure LoadSessionAndCompiler(const Session: TCEClientStateSession;
      const Compiler: TCEClientStateCompiler);
  public
    { Public declarations }
  end;

var
  frmCEAppMain: TfrmCEAppMain;

implementation

uses
{$ifdef ANDROID}
  FMX.Platform.Android, Androidapi.JNI.Net, Androidapi.JNI.Os, Androidapi.Helpers,
{$endif}
  CE.Languages, CE.Compilers, CE.Compile,
  FMX.VirtualKeyboard, FMX.DialogService,
  System.IOUtils, System.DateUtils, System.StrUtils, CE.LinkInfo,
  CE.LinkSaver, CE.Libraries, System.Math;

{$R *.fmx}
{$R *.Windows.fmx MSWINDOWS}

procedure TfrmCEAppMain.acCompileExecute(Sender: TObject);
var
  Libraries: TList<TCELibraryVersion>;
begin
  if Assigned(FCEAppState.SelectedLanguage) and Assigned(FCEAppState.SelectedCompiler) then
  begin
    FCEAppState.SelectedLibraries.Clear;
    Libraries := GetSelectedLibraries;
    try
      FCEAppState.SelectedLibraries.AddRange(Libraries);
    finally
      Libraries.Free;
    end;

    FCEAppState.Compile(edCodeEditor.Text,
      procedure
      begin
      end);
  end;
end;

procedure TfrmCEAppMain.acHeaderClickExecute(Sender: TObject);
var
  Service: IFMXVirtualKeyboardService;
begin
  if pgMain.ActiveTab = tabCodeEditor then
  begin
    FCEAppState.ClearCompileResult;

    TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, IInterface(Service));
    if Assigned(Service) then
    begin
      Service.HideVirtualKeyboard;
    end;
  end;
end;

procedure TfrmCEAppMain.acLoadFromLinkExecute(Sender: TObject);
var
  DefaultUrl: string;
begin
  DefaultUrl := '';

  TDialogService.InputQuery('Got a link?', [''], [DefaultUrl],
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      if AResult = mrOk then
      begin
        LoadStateFromLink(AValues[0]);
      end;
    end);
end;

procedure TfrmCEAppMain.acPlaySessionCompilerExecute(Sender: TObject);
var
  Item: TTreeViewItem;
begin
  if Assigned(treeClientState.Selected) then
  begin
    Item := treeClientState.Selected;
    if Item.TagObject is TCEClientStateCompiler then
    begin
      if Item.ParentItem.TagObject is TCEClientStateSession then
      begin
        LoadSessionAndCompiler(
          Item.ParentItem.TagObject as TCEClientStateSession,
          Item.TagObject as TCEClientStateCompiler
        );
      end;
    end;
  end;
end;

procedure TfrmCEAppMain.SelectLanguage(const Id: string);
var
  Language: TCELanguage;
begin
  if FCEAppState.HasLoadedLanguages then
  begin
    Language := FCEAppState.LoadedLanguages.GetById(Id);
    lstLanguages.ItemIndex := lstLanguages.Items.IndexOfObject(Language);

    GoToTab(tabCodeEditor);
  end;
end;

procedure TfrmCEAppMain.TypeCode(const Code: string);
begin
  edCodeEditor.Text := Code;
end;

procedure TfrmCEAppMain.SelectLibraries(const Libs: TList<TCEClientStateLibraryVersion>);
var
  Lib: TCEClientStateLibraryVersion;
  LibVersion: TCELibraryVersion;
  Idx: Integer;
begin
  for Idx := 0 to lstLanguageLibraries.Count - 1 do
  begin
    TListBoxItem(lstLanguageLibraries.ListItems[Idx]).IsChecked := False;
  end;

  for Lib in Libs do
  begin
    LibVersion := FCEAppState.LoadedLibraries.GetLibraryVersion(Lib.LibraryId, Lib.Version);
    if Assigned(LibVersion) then
    begin
      Idx := lstLanguageLibraries.Items.IndexOfObject(LibVersion);
      if Idx <> -1 then
      begin
        lstLanguageLibraries.ItemByIndex(Idx).IsChecked := True;
      end;
    end;
  end;
end;

procedure TfrmCEAppMain.ShowAssemblyOutput;
var
  AsmLine: TCEAssemblyLine;
begin
  lstAssembly.BeginUpdate;
  try
    lstAssembly.Lines.Clear;
    if Assigned(FCEAppState.LatestCompileResult) then
    begin
      for AsmLine in FCEAppState.LatestCompileResult.Assembly do
      begin
        lstAssembly.Lines.AddObject(AsmLine.Text, AsmLine);
      end;
    end;
  finally
    lstAssembly.EndUpdate;
  end;
end;

procedure TfrmCEAppMain.ShowCompilerOutputAndErrors;
var
  ErrorLine: TCEErrorLine;
begin
  lstCompilerOutput.BeginUpdate;
  try
    lstCompilerOutput.Lines.Clear;
    if Assigned(FCEAppState.LatestCompileResult) then
    begin
      for ErrorLine in FCEAppState.LatestCompileResult.CompilerOutput do
      begin
        lstCompilerOutput.Lines.AddObject(ErrorLine.Text, ErrorLine);
      end;
    end;
  finally
    lstCompilerOutput.EndUpdate;
  end;
end;

procedure TfrmCEAppMain.EnableBusyIndicator;
begin
  if not aniBusy.Enabled then
  begin
    aniBusy.Visible := True;
    aniBusy.Enabled := True;
  end;
end;

procedure TfrmCEAppMain.DisableBusyIndicator;
begin
  if aniBusy.Enabled then
  begin
    aniBusy.Enabled := False;
    aniBusy.Visible := False;
  end;
end;

procedure TfrmCEAppMain.tmrBusyTimer(Sender: TObject);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      if not Assigned(FCEAppState.LoadedLanguages) then
      begin
        EnableBusyIndicator;
      end
      else
      begin
        acLoadFromLink.Visible := True;

        if not Assigned(FCEAppState.SelectedLanguage) then
        begin
          DisableBusyIndicator;
        end
        else
        begin
          if not (FCEAppState.HasLoadedCompilers and FCEAppState.HasLoadedLibraries) then
          begin
            EnableBusyIndicator;
          end
          else
          begin
            DisableBusyIndicator;
          end;
        end;
      end;
    end);
end;

procedure TfrmCEAppMain.SelectCompiler(const Id: string);
var
  Compiler: TCECompiler;
begin
  if Assigned(FCEAppState.LoadedCompilers) and (FCEAppState.LoadedCompilers.Count <> 0) then
  begin
    Compiler := FCEAppState.LoadedCompilers.FindById(Id);
    cbCompilerSelection.ItemIndex := cbCompilerSelection.Items.IndexOfObject(Compiler);
  end;
end;

procedure TfrmCEAppMain.SetCompilerArguments(const Options: string);
begin
  FCEAppState.CompilerArguments := Options;
end;

procedure TfrmCEAppMain.ShowPossibleSessions;
var
  SessionItem: TTreeViewItem;
  Session: TCEClientStateSession;
  Language: TCELanguage;
  SessionCompiler: TCEClientStateCompiler;
  CompilerItem: TTreeViewItem;
  Libsummary: string;
begin
  treeClientState.Clear;

  for Session in FCEAppState.LoadedState.Sessions do
  begin
    Language := FCEAppState.LoadedLanguages.GetById(Session.Language);
    if Assigned(Language) then
    begin
      SessionItem := TTreeViewItem.Create(treeClientState);
      SessionItem.Text := Language.LanguageName;
      SessionItem.Parent := treeClientState;
      SessionItem.TagObject := Session;

      for SessionCompiler in Session.Compilers do
      begin
        CompilerItem := TTreeViewItem.Create(treeClientState);
        Libsummary := SessionCompiler.GetShortLibrarySummary;

        if SessionCompiler.Arguments <> '' then
          CompilerItem.Text := SessionCompiler.Id + ' /' + SessionCompiler.Arguments + '/'
        else if Libsummary <> '' then
          CompilerItem.Text := SessionCompiler.Id + ' [' + Libsummary + ']'
        else
          CompilerItem.Text := SessionCompiler.Id;

        CompilerItem.Parent := SessionItem;
        CompilerItem.TagObject := SessionCompiler;
      end;
    end;
  end;

  treeClientState.ExpandAll;
end;

procedure TfrmCEAppMain.LoadSessionAndCompiler(const Session: TCEClientStateSession; const Compiler: TCEClientStateCompiler);
begin
  FCEAppState.OnCompilersLoaded :=
    procedure
    begin
      TypeCode(Session.Source);

      SelectCompiler(Compiler.Id);

      SetCompilerArguments(Compiler.Arguments);
      acCompile.Execute;
    end;

  FCEAppState.OnLibrariesLoaded :=
    procedure
    begin
      SelectLibraries(Compiler.Libs);
    end;

  SelectLanguage(Session.Language);
end;

procedure TfrmCEAppMain.LoadState(const State: TCEClientState);
var
  Session: TCEClientStateSession;
  Compiler: TCEClientStateCompiler;
begin
  tabClientState.Visible := True;
  pgMain.ActiveTab := tabClientState;

  if (State.Sessions.Count = 1) and (State.Sessions.First.Compilers.Count = 1) then
  begin
    Session := State.Sessions.First;
    Compiler := Session.Compilers.First;

    LoadSessionAndCompiler(Session, Compiler);
  end
  else
  begin
    ShowPossibleSessions;
  end;
end;

procedure TfrmCEAppMain.LoadStateFromLink(const Link: string);
begin
  TThread.Synchronize(nil,
  procedure
  begin
    if not ContainsText(Link, 'godbolt.org/') then
    begin
      TDialogService.ShowMessage('This link cannot be loaded, go to godbolt.org to create a new shortlink');
    end
    else if ContainsText(Link, 'godbolt.org/') and not ContainsText(Link, '/z/') then
    begin
      TDialogService.ShowMessage('This old style link cannot be loaded, click Share again on the website to create a new style /z/ shortlink.');
    end
    else
    begin
      FCEAppState.LoadClientState(Link,
        procedure(State: TCEClientState)
        begin
          LoadState(State);
        end);
    end;
  end);
end;

procedure TfrmCEAppMain.lstLanguageLibrariesChangeCheck(Sender: TObject);
begin
  FCEAppState.ClearCompileResult;
end;

procedure TfrmCEAppMain.lstLanguagesChange(Sender: TObject);
begin
  acNextTab.Visible := (lstLanguages.ItemIndex <> -1);
end;

function TfrmCEAppMain.GetSelectedLibraries: TList<TCELibraryVersion>;
var
  Idx: Integer;
begin
  Result := TList<TCELibraryVersion>.Create;
  for Idx := 0 to lstLanguageLibraries.Count - 1 do
  begin
    if lstLanguageLibraries.ListItems[Idx].IsChecked then
    begin
      Result.Add(lstLanguageLibraries.ListItems[Idx].Data as TCELibraryVersion);
    end;
  end;
end;

procedure TfrmCEAppMain.acSaveExecute(Sender: TObject);
var
  Svc: IFMXClipboardService;
  Libraries: TList<TCELibraryVersion>;
begin
  FCEAppState.SelectedLibraries.Clear;
  Libraries := GetSelectedLibraries;
  try
    FCEAppState.SelectedLibraries.AddRange(Libraries);
  finally
    Libraries.Free;
  end;

  FCEAppState.SaveAsLink(edCodeEditor.Lines.Text,
    procedure(Link: string)
    begin
      if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
      begin
        Svc.SetClipboard(Link);

        TDialogService.ShowMessage('Link copied to clipboard');
      end;
    end);
end;

procedure TfrmCEAppMain.acSelectLibrariesExecute(Sender: TObject);
begin
  pgMain.ActiveTab := tabLanguageLibraries;
end;

procedure TfrmCEAppMain.acToggleCompilerArgumentsExecute(Sender: TObject);
begin
  TDialogService.InputQuery('Compiler arguments', [''], [FCEAppState.CurrentCompilerArguments],
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      if FCEAppState.CurrentCompilerArguments <> AValues[0] then
      begin
        FCEAppState.CurrentCompilerArguments := AValues[0];

        FCEAppState.ClearCompileResult;
      end;
    end
  );
end;

procedure TfrmCEAppMain.cbCompilerSelectionChange(Sender: TObject);
begin
  FCEAppState.SelectedCompiler := nil;
  if Assigned(cbCompilerSelection.Selected) then
  begin
    FCEAppState.SelectedCompiler := (cbCompilerSelection.Selected.Data as TCECompiler);
  end;

  btnCompilerSettings.Visible := Assigned(FCEAppState.SelectedCompiler);

  FCEAppState.ClearCompileResult;
end;

procedure TfrmCEAppMain.edCodeEditorChange(Sender: TObject);
begin
  FCEAppState.ClearCompileResult;
end;

procedure TfrmCEAppMain.FormCreate(Sender: TObject);
begin
  FCEAppState := TCEAppState.Create;
  FCEAppState.OnCompileResultChange :=
    procedure
    begin
      HandleCompileResult;
    end;

  pgMain.First(TTabTransition.None);
  pgMainChange(nil);

{$IFDEF ANDROID}
  edCodeEditor.Font.Family := 'monospace';
{$ENDIF}

  FDefaultFontSize := edCodeEditor.Font.Size;
  FPreviousDistance := 0;

  RegisterIntent;
end;

procedure TfrmCEAppMain.FormDestroy(Sender: TObject);
begin
  FCEAppState.Free;
end;

procedure TfrmCEAppMain.FormGesture(Sender: TObject; const EventInfo: TGestureEventInfo; var Handled: Boolean);
begin
  if EventInfo.GestureID = igiZoom then
  begin
    if (not(TInteractiveGestureFlag.gfBegin in EventInfo.Flags)) and
       (not(TInteractiveGestureFlag.gfEnd in EventInfo.Flags)) then
    begin
      edCodeEditor.Font.Size := Max(FDefaultFontSize, Min(72, edCodeEditor.Font.Size + (EventInfo.Distance - FPreviousDistance)));
    end;

    FPreviousDistance := EventInfo.Distance;
  end;
end;

procedure TfrmCEAppMain.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
begin
  if (Key = vkHardwareBack) and (pgMain.TabIndex <> 0) then
  begin
    pgMain.ActiveTab := tabLanguageSelection;
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
  if Assigned(FCEAppState.LatestCompileResult) then
  begin
    if FCEAppState.LatestCompileResult.Successful then
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
end;

procedure TfrmCEAppMain.UpdateLanguageList;
var
  Lang: TCELanguage;
begin
  lstLanguages.BeginUpdate;
  try
    lstLanguages.Clear;
    for Lang in FCEAppState.LoadedLanguages do
    begin
      lstLanguages.Items.AddObject(Lang.LanguageName, Lang);
    end;
  finally
    lstLanguages.EndUpdate;
  end;
end;

procedure TfrmCEAppMain.UpdateCompilerList;
var
  Compiler: TCECompiler;
begin
  cbCompilerSelection.BeginUpdate;
  try
    cbCompilerSelection.Clear;
    for Compiler in FCEAppState.LoadedCompilers do
    begin
      cbCompilerSelection.Items.AddObject(Compiler.Description, Compiler);
    end;

    if FCEAppState.SelectedLanguage.DefaultCompilerId = '' then
    begin
      cbCompilerSelection.ItemIndex :=
        cbCompilerSelection.Items.IndexOfObject(FCEAppState.LoadedCompilers.First);
    end
    else
    begin
      cbCompilerSelection.ItemIndex :=
        cbCompilerSelection.Items.IndexOfObject(
          FCEAppState.LoadedCompilers.FindById(FCEAppState.SelectedLanguage.DefaultCompilerId)
        );
    end;

    cbCompilerSelection.Visible := True;
  finally
    cbCompilerSelection.EndUpdate;
  end;
end;

procedure TfrmCEAppMain.InitializeCompilerOutput;
begin
  ShowCompilerOutputAndErrors;
  ShowAssemblyOutput;
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

  btnKeyboard.Visible := (pgMain.ActiveTab = tabCodeEditor);
  acSave.Visible := (pgMain.ActiveTab = tabCodeEditor);
  BottomToolbar.Visible := (pgMain.ActiveTab = tabCodeEditor) or (pgMain.ActiveTab = tabCompilerOutput) or (pgMain.ActiveTab = tabLanguageLibraries);
  acPreviousTab.Visible := (pgMain.ActiveTab = tabCodeEditor) or (pgMain.ActiveTab = tabCompilerOutput) or (pgMain.ActiveTab = tabLanguageLibraries);
  acNextTab.Visible := (pgMain.ActiveTab <> tabClientState);
  btnPlaySessionCompiler.Visible := (pgMain.ActiveTab = tabClientState);

  if pgMain.ActiveTab = tabLanguageSelection then
  begin
    InitializeLanguageTab;
    acNextTab.Visible := (lstLanguages.ItemIndex <> -1);
  end
  else if pgMain.ActiveTab = tabCodeEditor then
  begin
    InitializeCodeEditor;
  end
  else if pgMain.ActiveTab = tabCompilerOutput then
  begin
    InitializeCompilerOutput;
  end;

  if pgMain.ActiveTab = tabLanguageLibraries then
  begin
    tabLanguageLibraries.Visible := True;
  end
  else
  begin
    tabLanguageLibraries.Visible := False;
  end;
end;

procedure TfrmCEAppMain.RegisterIntent;
var
  AppEventService: IFMXApplicationEventService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, AppEventService) then
    AppEventService.SetApplicationEventHandler(HandleAppEvent);

  {$ifdef ANDROID}
  MainActivity.registerIntentAction(TJIntent.JavaClass.ACTION_VIEW);
  {$endif}

  {$ifdef ANDROID or IOS}
  TMessageManager.DefaultManager.SubscribeToMessage(TMessageReceivedNotification, HandleActivityMessage);
  {$endif}
end;

procedure TfrmCEAppMain.HandleActivityMessage(const Sender: TObject; const M: TMessage);
begin
  {$ifdef ANDROID}
  if M is TMessageReceivedNotification then
    HandleAnroidIntentAction(TMessageReceivedNotification(M).Value);
  {$endif}
  {$ifdef IOS}
  Log.d('Received a message of some sorts');
//  if M is TMessageReceivedNotification then
//    HandleIOSIntentAction(TMessageReceivedNotification(M).Value);
  {$endif}
end;

function TfrmCEAppMain.HandleAppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
{$ifdef ANDROID}
var
  StartupIntent: JIntent;
{$endif}
begin
  Result := False;
  if AAppEvent = TApplicationEvent.BecameActive then
  begin
    {$ifdef ANDROID}
    StartupIntent := MainActivity.getIntent;
    if StartupIntent <> nil then
      Result := HandleAnroidIntentAction(StartupIntent);
    {$endif}
  end
  else if AAppEvent = TApplicationEvent.OpenURL then
  begin
    {$ifdef IOS}
    Result := HandleIOSIntentAction(TiOSOpenApplicationContext(AContext));
    {$endif}
  end;
end;

{$ifdef IOS}
function TfrmCEAppMain.HandleIOSIntentAction(const Context: TiOSOpenApplicationContext): Boolean;
begin
  Result := False;

  if ContainsText(Context.URL, '/z/') then
  begin
    Result := True;

    LoadStateFromLink(Context.URL);
  end;
end;
{$endif}

{$ifdef ANDROID}
function TfrmCEAppMain.HandleAnroidIntentAction(const Data: JIntent): Boolean;
var
  Link: string;
begin
  Result := False;
  if Data <> nil then
  begin
    Link := JStringToString(Data.getDataString);
    if ContainsText(Link, '/z/') then
    begin
      Result := True;

      LoadStateFromLink(Link);
    end;
  end;
end;
{$endif}

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
    FCEAppState.LoadLanguages(
      procedure
      begin
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
    if FCEAppState.SelectedLanguage <> NewLanguage then
    begin
      edCodeEditor.Text := '';
      FCEAppState.SelectedLanguage := NewLanguage;
      cbCompilerSelection.Visible := False;

      FCEAppState.LoadCompilers(
        procedure
        begin
          UpdateCompilerList;
        end);

      FCEAppState.LoadLibraries(
        procedure
        begin
          UpdateLibrariesList;
        end);
    end
    else
    begin
      if FCEAppState.HasLoadedCompilers and Assigned(FCEAppState.OnCompilersLoaded) then
      begin
        FCEAppState.OnCompilersLoaded();
        FCEAppState.OnCompilersLoaded := nil;
      end;

      if FCEAppState.HasLoadedLibraries and Assigned(FCEAppState.OnLibrariesLoaded) then
      begin
        FCEAppState.OnLibrariesLoaded();
        FCEAppState.OnLibrariesLoaded := nil;
      end;
    end;
  end;

  if Assigned(FCEAppState.SelectedLanguage) and (edCodeEditor.Text = '') then
  begin
    edCodeEditor.Text := FCEAppState.SelectedLanguage.ExampleCode;
  end;
end;

procedure TfrmCEAppMain.UpdateLibrariesList;
var
  Lib: TCELibrary;
  Version: TCELibraryVersion;
begin
  lstLanguageLibraries.Clear;

  for Lib in FCEAppState.LoadedLibraries do
  begin
    for Version in Lib.Versions do
    begin
      lstLanguageLibraries.Items.AddObject(
        ' ' + Lib.Name + ' - ' + Version.Version,
        Version
      );
    end;
  end;
end;

end.
