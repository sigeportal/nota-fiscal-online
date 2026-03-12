unit UnitConstants;

interface
uses IniFiles;

type
  TConstants = class
    class function BuscaArquivoIni: string;
    class procedure GravaArquivoIni(CaminhoBD: string);
    class function BancoDados: string;
  public
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils;

{ TConstants }

class function TConstants.BancoDados: string;
var Ini: TIniFile;
    CaminhoBancoDados: string;
begin
  CaminhoBancoDados := BuscaArquivoIni;
  Result := CaminhoBancoDados;
  GravaArquivoIni(CaminhoBancoDados);
end;

class function TConstants.BuscaArquivoIni: string;
var Ini: TIniFile;
begin
  Ini := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  try
    Result := Ini.ReadString('CONEXAO', 'DB', 'PRINCIPAL.FDB');
  finally
    Ini.Free;
  end;
end;

destructor TConstants.Destroy;
var Ini: TIniFile;
begin

  inherited;
end;

class procedure TConstants.GravaArquivoIni(CaminhoBD: string);
var Ini: TIniFile;
begin
  Ini := TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini'));
  try
    Ini.WriteString('CONEXAO', 'DB', CaminhoBD);
  finally
    Ini.Free;
  end;
end;

end.