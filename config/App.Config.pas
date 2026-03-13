unit App.Config;

{
  Configurações centrais da aplicação NotaFiscal API
  Leitura de arquivo INI: NotaFiscalAPI.ini
}

interface

uses
  System.SysUtils,
  System.IniFiles;

type
  TAppConfig = class
  private
    class var FIniFile       : TIniFile;
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
    // ACBr - NFe
    class var FAcbrSchemas   : string;
    class var FAcbrXmlDir    : string;
    // ACBr - NFCe
    class var FNFCeIdCSC     : string;
    class var FNFCeCSC       : string;
    class var FUF            : string;
    // Responsável Técnico
    class var FRespCNPJ      : string;
    class var FRespContato   : string;
    class var FRespEmail     : string;
    class var FRespFone      : string;
    class var FRespIdCSRT    : string;
    class var FRespCSRT      : string;
  public
    class procedure LoadConfig;
    class procedure SaveConfig;
    class procedure FreeConfig;

    // Server
    class property Port        : Integer read FPort;
    class property Environment : string read FEnvironment;

    // Database
    class property DatabaseHost : string read FDatabaseHost;
    class property DatabasePort : Integer read FDatabasePort;
    class property DatabaseName : string read FDatabaseName;
    class property DatabaseUser : string read FDatabaseUser;
    class property DatabasePass : string read FDatabasePass;

    // JWT
    class property JWTSecret     : string read FJWTSecret;
    class property JWTExpiration : Integer read FJWTExpiration;

    // Security
    class property EncryptionKey : string read FEncryptionKey;

    // ACBr
    class property AmbienteProducao : Boolean read FAmbienteProducao;
    class property AcbrSchemas      : string read FAcbrSchemas;
    class property AcbrXmlDir       : string read FAcbrXmlDir;

    // NFCe
    class property NFCeIdCSC : string read FNFCeIdCSC;
    class property NFCeCSC   : string read FNFCeCSC;
    class property UF        : string read FUF;

    // Responsável Técnico
    class property RespCNPJ    : string read FRespCNPJ;
    class property RespContato : string read FRespContato;
    class property RespEmail   : string read FRespEmail;
    class property RespFone    : string read FRespFone;
    class property RespIdCSRT  : string read FRespIdCSRT;
    class property RespCSRT    : string read FRespCSRT;
  end;

implementation

class procedure TAppConfig.LoadConfig;
var
  ConfigPath: string;
begin
  ConfigPath := ChangeFileExt(ParamStr(0), '.ini');

  FIniFile := TIniFile.Create(ConfigPath);
  try
    // Server
    FPort        := FIniFile.ReadInteger('Server', 'Port', 9000);
    FEnvironment := FIniFile.ReadString ('Server', 'Environment', 'development');

    // Database
    FDatabaseHost := FIniFile.ReadString ('Database', 'Host',     'localhost');
    FDatabasePort := FIniFile.ReadInteger('Database', 'Port',     3050);
    FDatabaseName := FIniFile.ReadString ('Database', 'Database', 'D:\PROJETOS\NotaFiscalOnline\DADOS\PRINCIPAL.FDB');
    FDatabaseUser := FIniFile.ReadString ('Database', 'Username', 'SYSDBA');
    FDatabasePass := FIniFile.ReadString ('Database', 'Password', 'masterkey');

    // JWT
    FJWTSecret     := FIniFile.ReadString ('JWT', 'Secret',            'P0rt@l3694!XyZ#7qW$NotaFiscalAPI_2026');
    FJWTExpiration := FIniFile.ReadInteger('JWT', 'ExpirationMinutes', 1440); // 24h

    if FJWTSecret.Length < 32 then
      raise Exception.Create('JWT Secret deve ter no mínimo 32 caracteres');

    // Security
    FEncryptionKey := FIniFile.ReadString('Security', 'EncryptionKey', 'Portal@3694NF');

    // ACBr
    FAmbienteProducao := FIniFile.ReadInteger('ACBr', 'AmbienteProducao', 0) = 1;
    FAcbrSchemas      := FIniFile.ReadString ('ACBr', 'Schemas', ExtractFileDir(ParamStr(0)) + '\Schemas\NFe\');
    FAcbrXmlDir       := FIniFile.ReadString ('ACBr', 'XmlDir',  ExtractFileDir(ParamStr(0)) + '\NFe\');

    // NFCe
    FNFCeIdCSC := FIniFile.ReadString('NFCe', 'IdCSC', '');
    FNFCeCSC   := FIniFile.ReadString('NFCe', 'CSC',   '');
    FUF        := FIniFile.ReadString('NFCe', 'UF',    'MS');

    // Responsável Técnico
    FRespCNPJ    := FIniFile.ReadString('RespTec', 'CNPJ',    '');
    FRespContato := FIniFile.ReadString('RespTec', 'Contato', 'Portal.com');
    FRespEmail   := FIniFile.ReadString('RespTec', 'Email',   'portalsoft.com@gmail.com');
    FRespFone    := FIniFile.ReadString('RespTec', 'Fone',    '');
    FRespIdCSRT  := FIniFile.ReadString('RespTec', 'IdCSRT',  '');
    FRespCSRT    := FIniFile.ReadString('RespTec', 'CSRT',    '');

  except
    on E: Exception do
    begin
      FIniFile.Free;
      raise Exception.CreateFmt('Erro ao carregar configurações de [%s]: %s', [ConfigPath, E.Message]);
    end;
  end;
end;

class procedure TAppConfig.SaveConfig;
begin
  if not Assigned(FIniFile) then
    Exit;
  FIniFile.WriteInteger('Server',   'Port',        FPort);
  FIniFile.WriteString ('Database', 'Database',    FDatabaseName);
  FIniFile.WriteString ('ACBr',     'Schemas',     FAcbrSchemas);
  FIniFile.WriteString ('ACBr',     'XmlDir',      FAcbrXmlDir);
  FIniFile.WriteInteger('ACBr',     'AmbienteProducao', Ord(FAmbienteProducao));
end;

class procedure TAppConfig.FreeConfig;
begin
  if Assigned(FIniFile) then
    FreeAndNil(FIniFile);
end;

end.
