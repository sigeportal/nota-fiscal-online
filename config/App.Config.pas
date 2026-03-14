unit App.Config;

{
  Configurações centrais da aplicação NotaFiscal API
  Leitura exclusivamente por variáveis de ambiente.

  Variáveis obrigatórias:
    JWT_SECRET        (mínimo 32 caracteres)

  Variáveis opcionais (com padrões):
    PORT              (default: 9000)
    ENVIRONMENT       (default: production)
    DB_HOST           (default: localhost)
    DB_PORT           (default: 3050)
    DB_NAME           (default: path local)
    DB_USER           (default: SYSDBA)
    DB_PASS           (default: masterkey)
    JWT_EXPIRATION    (default: 1440 minutos)
    ENCRYPTION_KEY    (default: TROQUE_EM_PRODUCAO)
    AMBIENTE_PRODUCAO (default: 0)
    UF                (default: MS)
    ACBR_SCHEMAS      (default: <exedir>/Schemas/NFe/)
    ACBR_XMLDIR       (default: <exedir>/data/xml/)
}

interface

uses
  System.SysUtils;

type
  TAppConfig = class
  private
    class var FPort          : Integer;
    class var FEnvironment   : string;
    class var FDatabaseHost  : string;
    class var FDatabasePort  : Integer;
    class var FDatabaseName  : string;
    class var FDatabaseUser  : string;
    class var FDatabasePass  : string;
    class var FJWTSecret     : string;
    class var FJWTExpiration : Integer;
    class var FEncryptionKey : string;
    class var FAmbienteProducao : Boolean;
    class var FAcbrSchemas   : string;
    class var FAcbrXmlDir    : string;
    class var FUF            : string;

    class function Env(const AName, ADefault: string): string; static;
    class function EnvInt(const AName: string; ADefault: Integer): Integer; static;
  public
    class procedure LoadConfig;

    // Server
    class property Port        : Integer read FPort;
    class property Environment : string  read FEnvironment;

    // Database
    class property DatabaseHost : string  read FDatabaseHost;
    class property DatabasePort : Integer read FDatabasePort;
    class property DatabaseName : string  read FDatabaseName;
    class property DatabaseUser : string  read FDatabaseUser;
    class property DatabasePass : string  read FDatabasePass;

    // JWT
    class property JWTSecret     : string  read FJWTSecret;
    class property JWTExpiration : Integer read FJWTExpiration;

    // Security
    class property EncryptionKey : string read FEncryptionKey;

    // ACBr
    class property AmbienteProducao : Boolean read FAmbienteProducao;
    class property AcbrSchemas      : string  read FAcbrSchemas;
    class property AcbrXmlDir       : string  read FAcbrXmlDir;
    class property UF               : string  read FUF;
  end;

implementation

{ TAppConfig }

class function TAppConfig.Env(const AName, ADefault: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result.IsEmpty then
    Result := ADefault;
end;

class function TAppConfig.EnvInt(const AName: string; ADefault: Integer): Integer;
var
  LVal: string;
begin
  LVal := GetEnvironmentVariable(AName);
  if LVal.IsEmpty or not TryStrToInt(LVal, Result) then
    Result := ADefault;
end;

class procedure TAppConfig.LoadConfig;
var
  LExeDir: string;
begin
  LExeDir := ExtractFileDir(ParamStr(0));

  // Server
  FPort        := EnvInt('PORT', 9000);
  FEnvironment := Env('ENVIRONMENT', 'production');

  // Database
  FDatabaseHost := Env   ('DB_HOST', 'localhost');
  FDatabasePort := EnvInt('DB_PORT', 3050);
  FDatabaseName := Env   ('DB_NAME', LExeDir + PathDelim + 'PRINCIPAL.FDB');
  FDatabaseUser := Env   ('DB_USER', 'SYSDBA');
  FDatabasePass := Env   ('DB_PASS', 'masterkey');

  // JWT
  FJWTSecret     := Env   ('JWT_SECRET', 'Portal@3694_05557971000150140326');
  FJWTExpiration := EnvInt('JWT_EXPIRATION', 1440);

  if FJWTSecret.Length < 32 then
    raise Exception.Create(
      'Variável JWT_SECRET não definida ou menor que 32 caracteres');

  // Security
  FEncryptionKey := Env('ENCRYPTION_KEY', 'TROQUE_EM_PRODUCAO');

  // ACBr
  FAmbienteProducao := EnvInt('AMBIENTE_PRODUCAO', 0) = 1;
  FUF               := Env('UF', 'MS');
  FAcbrSchemas      := Env('ACBR_SCHEMAS', LExeDir + PathDelim + 'Schemas' + PathDelim + 'NFe' + PathDelim);
  FAcbrXmlDir       := Env('ACBR_XMLDIR',  LExeDir + PathDelim + 'data'    + PathDelim + 'xml' + PathDelim);
end;

end.

