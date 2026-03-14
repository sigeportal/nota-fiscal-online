unit Usuario.Service;

{
  Serviço de cadastro e gerenciamento de usuários
  - Valida campos obrigatórios
  - Garante unicidade de username e e-mail
  - Armazena senha como SHA-256 (compatível com Auth.Service)
  - Usa PortalORM (TModelUsuario): BuscaPorCampo, SalvaNoBanco, Apagar
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
    class function BuscarPorId(const AId: Integer): TJSONObject;
    class function AtualizarPerfil(const AId: Integer; const ABody: TJSONObject): TCadastroUsuarioResult;
  private
    class function HashPassword(const APassword: string): string;
    class function UsernameOuEmailJaExiste(const AUsername, AEmail: string): Boolean;
  end;

implementation

uses
  System.DateUtils,
  UnitDatabase,
  Models.NF,
  Logger.Utils,
  System.Hash;

{ TUsuarioService }

class function TUsuarioService.HashPassword(const APassword: string): string;
begin
  Result := THashSHA2.GetHashString(APassword, THashSHA2.TSHA2Version.SHA256).ToLower;
end;

class function TUsuarioService.UsernameOuEmailJaExiste(const AUsername, AEmail: string): Boolean;
var
  LUsuario: TModelUsuario;
begin
  // BuscaPorCampos verifica os dois campos de uma vez via AND,
  // mas como precisamos de OR usamos iQuery direto apenas para a checagem.
  // Alternativa: duas chamadas BuscaPorCampo independentes.
  LUsuario := TModelUsuario.Create(TDatabase.Connection);
  try
    LUsuario.BuscaPorCampo('USU_USERNAME', AUsername);
    Result := LUsuario.Codigo > 0;
    if not Result then
    begin
      LUsuario.BuscaPorCampo('USU_EMAIL', AEmail);
      Result := LUsuario.Codigo > 0;
    end;
  finally
    LUsuario.Free;
  end;
end;

class function TUsuarioService.Cadastrar(const AInput: TCadastroUsuarioInput): TCadastroUsuarioResult;
var
  LUsuario: TModelUsuario;
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

  // --- inserção via PortalORM ---
  LUsuario := TModelUsuario.Create(TDatabase.Connection);
  try
  	LUsuario.Codigo      := LUsuario.GeraCodigo('USU_CODIGO');
    LUsuario.Username    := AInput.Username.Trim;
    LUsuario.Email       := AInput.Email.Trim.ToLower;
    LUsuario.PasswordHash := HashPassword(AInput.Password);
    LUsuario.CNPJ        := AInput.CNPJ.Trim;
    LUsuario.RazaoSocial := AInput.RazaoSocial.Trim;
    LUsuario.Ativo       := 1;
    LUsuario.DataCriacao := Now;
    LUsuario.DataAtualizacao := Now;

    LUsuario.SalvaNoBanco(1);

    // Re-busca para obter o código gerado
    LUsuario.BuscaPorCampos(
      ['USU_USERNAME', 'USU_EMAIL'],
      [AInput.Username.Trim, AInput.Email.Trim.ToLower]
    );

    Result.Sucesso := LUsuario.Codigo > 0;
    Result.UserId  := LUsuario.Codigo;

    if Result.Sucesso then
      TLogger.Info('Usuario.Service: usuário "%s" cadastrado (id=%d)',
                   [AInput.Username, Result.UserId])
    else
      Result.Erro := 'Falha ao recuperar ID do usuário criado';
  finally
    LUsuario.Free;
  end;
end;

class function TUsuarioService.BuscarPorId(const AId: Integer): TJSONObject;
var
  LUsuario: TModelUsuario;
begin
  Result   := nil;
  LUsuario := TModelUsuario.Create(TDatabase.Connection);
  try
    LUsuario.BuscaDadosTabela(AId);
    if LUsuario.Codigo = 0 then
      Exit;
    Result := TJSONObject.Create;
    Result.AddPair('id',            TJSONNumber.Create(LUsuario.Codigo));
    Result.AddPair('username',      LUsuario.Username);
    Result.AddPair('email',         LUsuario.Email);
    Result.AddPair('cnpj',          LUsuario.CNPJ);
    Result.AddPair('razao_social',  LUsuario.RazaoSocial);
    Result.AddPair('inscricao_estadual', LUsuario.InscricaoEstadual);
    Result.AddPair('endereco',      LUsuario.Endereco);
    Result.AddPair('cidade',        LUsuario.Cidade);
    Result.AddPair('uf',            LUsuario.UF);
    Result.AddPair('cep',           LUsuario.CEP);
    Result.AddPair('telefone',      LUsuario.Telefone);
    Result.AddPair('ativo',         TJSONBool.Create(LUsuario.Ativo = 1));
  finally
    LUsuario.Free;
  end;
end;

class function TUsuarioService.AtualizarPerfil(const AId: Integer;
  const ABody: TJSONObject): TCadastroUsuarioResult;
var
  LUsuario: TModelUsuario;
  LValor  : string;
begin
  Result.Sucesso := False;
  Result.UserId  := AId;
  Result.Erro    := '';

  LUsuario := TModelUsuario.Create(TDatabase.Connection);
  try
    LUsuario.BuscaDadosTabela(AId);
    if LUsuario.Codigo = 0 then
    begin
      Result.Erro := 'Usuário não encontrado';
      Exit;
    end;

    // Atualiza somente os campos presentes no body
    if ABody.TryGetValue<string>('razao_social', LValor) then
      LUsuario.RazaoSocial := LValor;
    if ABody.TryGetValue<string>('inscricao_estadual', LValor) then
      LUsuario.InscricaoEstadual := LValor;
    if ABody.TryGetValue<string>('endereco', LValor) then
      LUsuario.Endereco := LValor;
    if ABody.TryGetValue<string>('cidade', LValor) then
      LUsuario.Cidade := LValor;
    if ABody.TryGetValue<string>('uf', LValor) then
      LUsuario.UF := LValor;
    if ABody.TryGetValue<string>('cep', LValor) then
      LUsuario.CEP := LValor;
    if ABody.TryGetValue<string>('telefone', LValor) then
      LUsuario.Telefone := LValor;

    LUsuario.DataAtualizacao := Now;
    LUsuario.SalvaNoBanco(1);
    Result.Sucesso := True;
  finally
    LUsuario.Free;
  end;
end;

end.
