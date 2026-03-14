unit Auth.Controller;

{
  Controlador de autenticação
  POST /v1/auth/login -> retorna JWT token
}

interface

uses
  Horse,
  Horse.Commons;

type
  TAuthController = class
  public
    class procedure Registrar;
  private
    class procedure Login(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

  // Modelos para Swagger
  TLoginRequest = class
  private
    Fusername: string;
    Fpassword: string;
  published
    property username: string read Fusername write Fusername;
    property password: string read Fpassword write Fpassword;
  end;

  TLoginResponse = class
  private
    Ftoken      : string;
    Fuser_id    : Integer;
    Fusername   : string;
    Fcnpj       : string;
    Frazao_social: string;
  published
    property token      : string  read Ftoken       write Ftoken;
    property user_id    : Integer read Fuser_id     write Fuser_id;
    property username   : string  read Fusername    write Fusername;
    property cnpj       : string  read Fcnpj        write Fcnpj;
    property razao_social: string read Frazao_social write Frazao_social;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  Auth.Service,
  Response.Utils,
  Logger.Utils,
  Horse.GBSwagger;

{ TAuthController }

class procedure TAuthController.Login(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LBody    : TJSONObject;
  LUsername: string;
  LPassword: string;
  LResp    : TJSONObject;
begin
  try
    LBody := Req.Body<TJSONObject>;
    if not Assigned(LBody) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Body JSON inválido', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LUsername := LBody.GetValue<string>('username', '');
    LPassword := LBody.GetValue<string>('password', '');

    LAuthenticated := TAuthService.Login(LUsername, LPassword);

    if LAuthenticated.Sucesso then
    begin
      LResp := TJSONObject.Create;
      LResp.AddPair('token',       LAuthenticated.Token);
      LResp.AddPair('user_id',     TJSONNumber.Create(LAuthenticated.UserId));
      LResp.AddPair('username',    LAuthenticated.Username);
      LResp.AddPair('cnpj',        LAuthenticated.CNPJ);
      LResp.AddPair('razao_social', LAuthenticated.RazaoSocial);
      Res.Send<TJSONObject>(TResponseUtils.SuccessData(LResp));
    end
    else
      Res.Send<TJSONObject>(TResponseUtils.Error(LAuthenticated.Erro, 401))
         .Status(THTTPStatus.Unauthorized);
  except
    on E: Exception do
    begin
      TLogger.Error('Auth.Controller.Login', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TAuthController.Registrar;
begin
  THorse
    .Group
    .Prefix('/v1')
    .Route('/auth/login')
      .Post(Login)
    .&End;
end;

initialization
  Swagger
    .BasePath('v1')
      .Path('auth/login')
        .Tag('Autenticação')
        .POST('Login na API')
          .AddParamBody('Credenciais', 'Usuário e senha')
            .Required(True)
            .Schema(TLoginRequest)
          .&End
          .AddResponse(200, 'Login bem-sucedido')
            .Schema(TLoginResponse)
          .&End
          .AddResponse(401, 'Credenciais inválidas').&End
          .AddResponse(400, 'Dados inválidos').&End
          .AddResponse(500, 'Erro interno').&End
        .&End
      .&End
    .&End

end.
