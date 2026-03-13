unit Auth.Service;

{
  Serviço de autenticação
  - Valida usuário e senha no banco USUARIOS
  - Gera token JWT
}

interface

uses
  System.SysUtils,
  System.JSON, UnitConnection.Model.Interfaces;

type
  TAuthResult = record
    Sucesso  : Boolean;
    Token    : string;
    UserId   : Integer;
    Username : string;
    CNPJ     : string;
    RazaoSocial: string;
    Erro     : string;
  end;

  TAuthService = class
  public
    class function Login(const AUsername, APassword: string): TAuthResult;
  private
    class function HashPassword(const APassword: string): string;
  end;

var
  LAuthenticated  : TAuthResult;

implementation

uses
  UnitDatabase,
  JWT.Utils,
  Logger.Utils,
  System.Hash;

{ TAuthService }

class function TAuthService.HashPassword(const APassword: string): string;
begin
  // SHA-256 hex lowercase (compatível com Python hashlib.sha256)
  Result := THashSHA2.GetHashString(APassword, THashSHA2.TSHA2Version.SHA256).ToLower;
end;

class function TAuthService.Login(const AUsername, APassword: string): TAuthResult;
var
  LQuery     : iQuery;
  LHashSenha : string;
begin
  Result.Sucesso := False;
  Result.Erro    := '';

  if AUsername.IsEmpty or APassword.IsEmpty then
  begin
    Result.Erro := 'Usuário e senha são obrigatórios';
    Exit;
  end;

  LHashSenha := HashPassword(APassword);

  LQuery := TDatabase.Query;
  LQuery.Clear;
  LQuery.Add('SELECT USU_CODIGO, USU_USERNAME, USU_CNPJ, USU_RAZAO_SOCIAL');
  LQuery.Add('FROM USUARIOS');
  LQuery.Add('WHERE (USU_USERNAME = :USERNAME OR USU_EMAIL = :USERNAME)');
  LQuery.Add('AND USU_PASSWORD_HASH = :SENHA');
  LQuery.Add('AND USU_ATIVO = 1');
  LQuery.AddParam('USERNAME', AUsername);
  LQuery.AddParam('SENHA', LHashSenha);
  LQuery.Open;

  if LQuery.DataSet.IsEmpty then
  begin
    Result.Erro := 'Credenciais inválidas';
    TLogger.Warn('Auth.Service: Login falhou para usuário %s', [AUsername]);
    Exit;
  end;

  Result.UserId     := LQuery.DataSet.FieldByName('USU_CODIGO').AsInteger;
  Result.Username   := LQuery.DataSet.FieldByName('USU_USERNAME').AsString;
  Result.CNPJ       := LQuery.DataSet.FieldByName('USU_CNPJ').AsString;
  Result.RazaoSocial := LQuery.DataSet.FieldByName('USU_RAZAO_SOCIAL').AsString;
  Result.Token      := TJWTUtils.GenerateToken(Result.UserId, Result.Username);
  Result.Sucesso    := True;

  TLogger.Info('Auth.Service: Login bem-sucedido para %s (id=%d)', [Result.Username, Result.UserId]);
end;

end.
