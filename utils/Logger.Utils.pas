unit Logger.Utils;

{
  Utilitário de log para a API
  Grava em arquivo e console
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils;

type
  TLogLevel = (llDEBUG, llINFO, llWARN, llERROR);

  TLogger = class
  private
    class var FLogFile : string;
    class procedure WriteLog(ALevel: TLogLevel; const AMsg: string);
    class function LevelStr(ALevel: TLogLevel): string;
  public
    class procedure Setup(const ALogFile: string = '');
    class procedure Debug(const AMsg: string); overload;
    class procedure Debug(const AFmt: string; const AArgs: array of const); overload;
    class procedure Info(const AMsg: string); overload;
    class procedure Info(const AFmt: string; const AArgs: array of const); overload;
    class procedure Warn(const AMsg: string); overload;
    class procedure Warn(const AFmt: string; const AArgs: array of const); overload;
    class procedure Error(const AMsg: string); overload;
    class procedure Error(const AFmt: string; const AArgs: array of const); overload;
    class procedure Error(const AMsg: string; E: Exception); overload;
  end;

implementation

class procedure TLogger.Setup(const ALogFile: string);
begin
  if ALogFile.IsEmpty then
    FLogFile := ChangeFileExt(ParamStr(0), '.log')
  else
    FLogFile := ALogFile;
end;

class function TLogger.LevelStr(ALevel: TLogLevel): string;
begin
  case ALevel of
    llDEBUG: Result := 'DEBUG';
    llINFO:  Result := 'INFO ';
    llWARN:  Result := 'WARN ';
    llERROR: Result := 'ERROR';
  end;
end;

class procedure TLogger.WriteLog(ALevel: TLogLevel; const AMsg: string);
var
  Line : string;
begin
  Line := Format('[%s] [%s] %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), LevelStr(ALevel), AMsg]);

  // Console
  Writeln(Line);

  // Arquivo
  try
    if not FLogFile.IsEmpty then
      TFile.AppendAllText(FLogFile, Line + sLineBreak, TEncoding.UTF8);
  except
    // falha silenciosa no log
  end;
end;

class procedure TLogger.Debug(const AMsg: string);
begin
  WriteLog(llDEBUG, AMsg);
end;

class procedure TLogger.Debug(const AFmt: string; const AArgs: array of const);
begin
  WriteLog(llDEBUG, Format(AFmt, AArgs));
end;

class procedure TLogger.Info(const AMsg: string);
begin
  WriteLog(llINFO, AMsg);
end;

class procedure TLogger.Info(const AFmt: string; const AArgs: array of const);
begin
  WriteLog(llINFO, Format(AFmt, AArgs));
end;

class procedure TLogger.Warn(const AMsg: string);
begin
  WriteLog(llWARN, AMsg);
end;

class procedure TLogger.Warn(const AFmt: string; const AArgs: array of const);
begin
  WriteLog(llWARN, Format(AFmt, AArgs));
end;

class procedure TLogger.Error(const AMsg: string);
begin
  WriteLog(llERROR, AMsg);
end;

class procedure TLogger.Error(const AFmt: string; const AArgs: array of const);
begin
  WriteLog(llERROR, Format(AFmt, AArgs));
end;

class procedure TLogger.Error(const AMsg: string; E: Exception);
begin
  WriteLog(llERROR, Format('%s | Exception: [%s] %s', [AMsg, E.ClassName, E.Message]));
end;

end.
