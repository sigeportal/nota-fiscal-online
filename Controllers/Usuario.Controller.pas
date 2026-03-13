unit Usuario.Controller;

{
  Controlador de Usuários
  POST /v1/usuarios -> cadastrar novo usuário (rota pública)
}

interface

uses
  Horse,
  Horse.Commons;

type
  TUsuarioController = class
  public
    class procedure Registrar;
  private
    class procedure Cadastrar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

  // ---------- modelos para o Swagger ----------

  TUsuarioCadastroRequest = class
  private
    Fusername   : string;
    Femail      : string;
    Fpassword   : string;
    Fcnpj       : string;
    Frazao_social: string;
  published
    /// Login do usuário (único)
    property username   : string read Fusername    write Fusername;
    /// E-mail do usuário (único)
    property email      : string read Femail       write Femail;
    /// Senha em texto claro (mínimo 6 caracteres)
    property password   : string read Fpassword    write Fpassword;
    /// CNPJ da empresa (somente números)
    property cnpj       : string read Fcnpj        write Fcnpj;
    /// Razão social da empresa
    property razao_social: string read Frazao_social write Frazao_social;
  end;

  TUsuarioCadastroResponse = class
  private
    Fsuccess: Boolean;
    Fuser_id: Integer;
    Fmessage: string;
  published
    property success: Boolean read Fsuccess write Fsuccess;
    property user_id: Integer read Fuser_id write Fuser_id;
    property message: string  read Fmessage write Fmessage;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  Usuario.Service,
  Response.Utils,
  Logger.Utils,
  Horse.GBSwagger;

{ TUsuarioController }

class procedure TUsuarioController.Cadastrar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LBody : TJSONObject;
  LInput: TCadastroUsuarioInput;
  LResult: TCadastroUsuarioResult;
  LData : TJSONObject;
begin
  try
    LBody := Req.Body<TJSONObject>;
    if not Assigned(LBody) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Body JSON inválido', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LInput.Username    := LBody.GetValue<string>('username',    '');
    LInput.Email       := LBody.GetValue<string>('email',       '');
    LInput.Password    := LBody.GetValue<string>('password',    '');
    LInput.CNPJ        := LBody.GetValue<string>('cnpj',        '');
    LInput.RazaoSocial := LBody.GetValue<string>('razao_social','');

    LResult := TUsuarioService.Cadastrar(LInput);

    if LResult.Sucesso then
    begin
      LData := TJSONObject.Create;
      LData.AddPair('user_id', TJSONNumber.Create(LResult.UserId));
      LData.AddPair('username', LInput.Username);
      Res.Send<TJSONObject>(TResponseUtils.Success('Usuário cadastrado com sucesso', LData))
         .Status(THTTPStatus.Created);
    end
    else
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error(LResult.Erro, 422))
         .Status(THTTPStatus.UnprocessableEntity);
    end;

  except
    on E: Exception do
    begin
      TLogger.Error('Usuario.Controller.Cadastrar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TUsuarioController.Registrar;
begin
  THorse
    .Group
    .Prefix('/v1')
    .Route('/usuarios')
      .Post(Cadastrar)
    .&End;
end;

initialization
  Swagger
    .BasePath('v1')
      .Path('usuarios')
        .Tag('Usuários')
        .POST('Cadastrar novo usuário')
          .AddParamBody('body', 'Dados do novo usuário')
            .Required(True)
            .Schema(TUsuarioCadastroRequest)
          .&End
          .AddResponse(201, 'Usuário criado com sucesso')
            .Schema(TUsuarioCadastroResponse)
          .&End
          .AddResponse(422, 'Erro de validação (campo inválido ou duplicado)').&End
          .AddResponse(400, 'Body JSON inválido').&End
          .AddResponse(500, 'Erro interno do servidor').&End
        .&End
      .&End
    .&End

end.
