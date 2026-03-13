unit Usuario.Service;

{
  Serviço de cadastro de usuários
  - Valida campos obrigatórios
  - Garante unicidade de username e e-mail
  - Armazena senha como SHA-256 (compatível com Auth.Service)
  - Insere registro na tabela USUARIOS
}

interface

uses
  System.SysUtils,
  System.JSON,
  UnitConnection.Model.Interfaces;

type
  TCadastroUsuarioInput = record
    Username   : string;
    Email      : string;
    Password   : string;
    CNPJ       : string;
    RazaoSocial: string;
  end;

  TCadastroUsuarioResult = record
    Sucesso : Boolean;
    UserId  : Integer;
    Erro    : string;
  end;

  TUsuarioService = class
  public
    class function Cadastrar(const AInput: TCadastroUsuarioInput): TCadastroUsuarioResult;
  private
    class function HashPassword(const APassword: string): string;
    class function UsernameOuEmailJaExiste(const AUsername, AEmail: string): Boolean;
  end;

implementation

uses
  UnitDatabase,
  Logger.Utils,
  System.Hash;

{ TUsuarioService }

class function TUsuarioService.HashPassword(const APassword: string): string;
begin
  Result := THashSHA2.GetHashString(APassword, THashSHA2.TSHA2Version.SHA256).ToLower;
end;

class function TUsuarioService.UsernameOuEmailJaExiste(const AUsername, AEmail: string): Boolean;
var
  LQuery: iQuery;
begin
  LQuery := TDatabase.Query;
  LQuery.Clear;
  LQuery.Add('SELECT COUNT(*) AS QTD FROM USUARIOS');
  LQuery.Add('WHERE USU_USERNAME = :USERNAME OR USU_EMAIL = :EMAIL');
  LQuery.AddParam('USERNAME', AUsername);
  LQuery.AddParam('EMAIL',    AEmail);
  LQuery.Open;
  Result := LQuery.DataSet.FieldByName('QTD').AsInteger > 0;
end;

class function TUsuarioService.Cadastrar(const AInput: TCadastroUsuarioInput): TCadastroUsuarioResult;
var
  LQuery: iQuery;
begin
  Result.Sucesso := False;
  Result.UserId  := 0;
  Result.Erro    := '';

  // --- validações básicas ---
  if AInput.Username.Trim.IsEmpty then
  begin
    Result.Erro := 'O campo "username" é obrigatório';
    Exit;
  end;

  if AInput.Email.Trim.IsEmpty then
  begin
    Result.Erro := 'O campo "email" é obrigatório';
    Exit;
  end;

  if AInput.Password.Trim.IsEmpty then
  begin
    Result.Erro := 'O campo "password" é obrigatório';
    Exit;
  end;

  if Length(AInput.Password) < 6 then
  begin
    Result.Erro := 'A senha deve ter ao menos 6 caracteres';
    Exit;
  end;

  if AInput.CNPJ.Trim.IsEmpty then
  begin
    Result.Erro := 'O campo "cnpj" é obrigatório';
    Exit;
  end;

  if AInput.RazaoSocial.Trim.IsEmpty then
  begin
    Result.Erro := 'O campo "razao_social" é obrigatório';
    Exit;
  end;

  // --- unicidade ---
  if UsernameOuEmailJaExiste(AInput.Username, AInput.Email) then
  begin
    Result.Erro := 'Username ou e-mail já cadastrado';
    Exit;
  end;

  // --- inserção ---
  LQuery := TDatabase.Query;
  LQuery.Clear;
  LQuery.Add('INSERT INTO USUARIOS');
  LQuery.Add('  (USU_CODIGO, USU_USERNAME, USU_EMAIL, USU_PASSWORD_HASH,');
  LQuery.Add('   USU_CNPJ, USU_RAZAO_SOCIAL, USU_ATIVO)');
  LQuery.Add('VALUES');
  LQuery.Add('  (GEN_ID(GEN_USU_CODIGO, 1), :USERNAME, :EMAIL, :SENHA,');
  LQuery.Add('   :CNPJ, :RAZAO_SOCIAL, 1)');
  LQuery.Add('RETURNING USU_CODIGO');
  LQuery.AddParam('USERNAME',    AInput.Username.Trim);
  LQuery.AddParam('EMAIL',       AInput.Email.Trim.ToLower);
  LQuery.AddParam('SENHA',       HashPassword(AInput.Password));
  LQuery.AddParam('CNPJ',        AInput.CNPJ.Trim);
  LQuery.AddParam('RAZAO_SOCIAL', AInput.RazaoSocial.Trim);
  LQuery.Open;
  if not LQuery.DataSet.IsEmpty then
  begin
    Result.Sucesso := True;
    Result.UserId := LQuery.DataSet.FieldByName('USU_CODIGO').AsInteger;
    TLogger.Info('Usuario.Service: usuário "%s" cadastrado (id=%d)', [AInput.Username, Result.UserId]);
  end;
end;

end.
