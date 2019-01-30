unit CEAppState;

interface

uses
  CE.Types, CE.Interfaces, CE.ClientState, System.SysUtils,
  System.Generics.Collections;

type
  TCEAppState = class
  private
    FCELanguages: ICELanguages;
    FCECompilers: ICECompilers;
    FCELibraries: ICELibraries;
    FCECompile: ICECompile;
    FCELinkInfo: ICELinkInfo;

    FLoadedLanguages: TCELanguages;
    FLoadedCompilers: TCECompilers;
    FLoadedLibraries: TCELibraries;

    FLoadedState: TCEClientState;

    FHasLoadedCompilers: Boolean;
    FHasLoadedLibraries: Boolean;

    FSelectedLanguage: TCELanguage;
    FSelectedCompiler: TCECompiler;
    FLatestCompileResult: TCECompileResult;
    FCurrentCompilerArguments: string;

    FOnCompilersLoaded: TProc;
    FOnLibrariesLoaded: TProc;
    FSelectedLibraries: TList<TCELibraryVersion>;
    FOnCompileResultChange: TProc;

    procedure SetCurrentCompilerArguments(const Value: string);

    procedure CallSynchronized<T>(Proc: TProc<T>; Param: T);
    procedure CallSynchronizedNoParam(Proc: TProc);
    procedure SetOnRestError(const Value: TProc<string>);
  public
    property LoadedLanguages: TCELanguages read FLoadedLanguages;
    property LoadedCompilers: TCECompilers read FLoadedCompilers;
    property LoadedLibraries: TCELibraries read FLoadedLibraries;

    property LoadedState: TCEClientState read FLoadedState;

    property SelectedLanguage: TCELanguage read FSelectedLanguage write FSelectedLanguage;
    property SelectedCompiler: TCECompiler read FSelectedCompiler write FSelectedCompiler;

    property CompilerArguments: string read FCurrentCompilerArguments write SetCurrentCompilerArguments;

    property LatestCompileResult: TCECompileResult read FLatestCompileResult;
    property CurrentCompilerArguments: string read FCurrentCompilerArguments write FCurrentCompilerArguments;

    property SelectedLibraries: TList<TCELibraryVersion> read FSelectedLibraries;

    property OnCompilersLoaded: TProc read FOnCompilersLoaded write FOnCompilersLoaded;
    property OnLibrariesLoaded: TProc read FOnLibrariesLoaded write FOnLibrariesLoaded;

    property OnCompileResultChange: TProc read FOnCompileResultChange write FOnCompileResultChange;
    property OnRestError: TProc<string> write SetOnRestError;

    constructor Create;
    destructor Destroy; override;

    procedure LoadLanguages(Callback: TProc);
    procedure LoadCompilers(Callback: TProc);
    procedure LoadLibraries(Callback: TProc);

    procedure Compile(const Code: string; Callback: TProc);
    procedure ClearCompileResult;

    procedure LoadClientState(const Link: string; Callback: TProc<TCEClientState>);

    procedure SaveAsLink(const Code: string; Callback: TProc<string>);

    function HasLoadedCompilers: Boolean;
    function HasLoadedLanguages: Boolean;
    function HasLoadedLibraries: Boolean;
  end;

implementation

uses
  System.Classes, CE.LinkSaver, CE.Languages, CE.Compilers, CE.Libraries,
  CE.Compile, CE.LinkInfo;

{ TLocalData }

procedure TCEAppState.CallSynchronized<T>(Proc: TProc<T>; Param: T);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      Proc(Param);
    end);
end;

procedure TCEAppState.CallSynchronizedNoParam(Proc: TProc);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      Proc();
    end);
end;

procedure TCEAppState.ClearCompileResult;
begin
  FreeAndNil(FLatestCompileResult);
  OnCompileResultChange();
end;

procedure TCEAppState.Compile(const Code: string; Callback: TProc);
begin
  FCECompile.Compile(FSelectedLanguage.Id, FSelectedCompiler.CompilerId, Code, FCurrentCompilerArguments, SelectedLibraries,
    procedure(CompileResult: TCECompileResult)
    begin
      FLatestCompileResult.Free;
      FLatestCompileResult := CompileResult;

      TThread.Synchronize(nil,
        procedure
        begin
          OnCompileResultChange();

          Callback();
        end);
    end
  );
end;

constructor TCEAppState.Create;
begin
  FCELanguages := TCELanguagesFromRest.Create;
  FCECompilers := TCECompilersFromRest.Create;
  FCELibraries := TCELibrariesFromRest.Create;
  FCECompile := TCECompileViaRest.Create;
  FCELinkInfo := TCELinkInfo.Create;
  FSelectedLibraries := TList<TCELibraryVersion>.Create;
end;

destructor TCEAppState.Destroy;
begin
  FreeAndNil(FSelectedLibraries);
  FreeAndNil(FLoadedState);
  FreeAndNil(FLoadedLibraries);
  FreeAndNil(FLoadedLanguages);
  FreeAndNil(FLoadedCompilers);
  FreeAndNil(FLatestCompileResult);

  inherited;
end;

function TCEAppState.HasLoadedCompilers: Boolean;
begin
  Result := FHasLoadedCompilers;
end;

function TCEAppState.HasLoadedLanguages: Boolean;
begin
  Result := Assigned(FLoadedLanguages) and (FLoadedLanguages.Count <> 0);
end;

function TCEAppState.HasLoadedLibraries: Boolean;
begin
  Result := FHasLoadedLibraries;
end;

procedure TCEAppState.LoadClientState(const Link: string; Callback: TProc<TCEClientState>);
begin
  FCELinkInfo.GetClientState(Link,
    procedure(State: TCEClientState)
    begin
      FLoadedState.Free;
      FLoadedState := State;

      CallSynchronized<TCEClientState>(Callback, FLoadedState);
    end);
end;

procedure TCEAppState.LoadCompilers(Callback: TProc);
begin
  FHasLoadedCompilers := False;

  FCECompilers.GetCompilers(FSelectedLanguage.Id,
    procedure(Compilers: TCECompilers)
    begin
      FLoadedCompilers.Free;
      FLoadedCompilers := Compilers;

      CallSynchronizedNoParam(Callback);

      FHasLoadedCompilers := True;
      if Assigned(FOnCompilersLoaded) then
      begin
        FOnCompilersLoaded();
        FOnCompilersLoaded := nil;
      end;
    end);
end;

procedure TCEAppState.LoadLanguages(Callback: TProc);
begin
  FCELanguages.GetLanguages(
    procedure(Languages: TCELanguages)
    begin
      FLoadedLanguages.Free;
      FLoadedLanguages := Languages;

      CallSynchronizedNoParam(Callback);
    end);
end;

procedure TCEAppState.LoadLibraries(Callback: TProc);
begin
  FHasLoadedLibraries := False;

  FCELibraries.GetLibraries(FSelectedLanguage.Id,
    procedure(Libraries: TCELibraries)
    begin
      FLoadedLibraries.Free;
      FLoadedLibraries := Libraries;

      CallSynchronizedNoParam(Callback);

      FHasLoadedLibraries := True;
      if Assigned(FOnLibrariesLoaded) then
      begin
        FOnLibrariesLoaded();
        FOnLibrariesLoaded := nil;
      end;
    end);
end;

procedure TCEAppState.SaveAsLink(const Code: string; Callback: TProc<string>);
var
  Saver: TCELinkSaver;
begin
  Saver := TCELinkSaver.Create;
  Saver.Save(
    FSelectedLanguage.Id,
    FSelectedCompiler.CompilerId,
    Code,
    FCurrentCompilerArguments,
    FSelectedLibraries,
    procedure(LinkId: string)
    begin
      CallSynchronized<string>(Callback, UrlCompilerExplorer + '/z/' + LinkId);
    end
  );
end;

procedure TCEAppState.SetCurrentCompilerArguments(const Value: string);
begin
  FCurrentCompilerArguments := Value;

  ClearCompileResult;
end;

procedure TCEAppState.SetOnRestError(const Value: TProc<string>);
begin
  FCELanguages.SetErrorCallback(Value);
  FCECompilers.SetErrorCallback(Value);
  FCECompile.SetErrorCallback(Value);
  FCELibraries.SetErrorCallback(Value);
  FCELinkInfo.SetErrorCallback(Value);
end;

end.
