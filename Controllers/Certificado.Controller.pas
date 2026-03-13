unit Certificado.Controller;

{
  Controlador de certificados A1
  POST /v1/certificados/upload   -> envia PFX em Base64 + senha + CNPJ
  GET  /v1/certificados/:cnpj    -> consulta status/validade do certificado
}

interface

uses
  Horse,
  Horse.Commons;

type
  TCertificadoController = class
  public
    class procedure Registrar;
  private
    class procedure Upload(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Status(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

  // Modelos Swagger
  TCertificadoUploadRequest = class
  private
    Fcnpj      : string;
    Fcertificado: string;
    Fsenha     : string;
  published
    /// CNPJ da empresa (apenas números)
    property cnpj       : string read Fcnpj       write Fcnpj;
    /// Certificado PFX codificado em Base64
    property certificado: string read Fcertificado write Fcertificado;
    /// Senha do certificado PFX
    property senha      : string read Fsenha       write Fsenha;
  end;

  TCertificadoResponse = class
  private
    Fcod_certificado: Integer;
    Fcnpj           : string;
    Fassunto        : string;
    Femissor        : string;
    Fvalidade_ini   : string;
    Fvalidade_fim   : string;
    Fthumbprint     : string;
    Fdias_restantes : Integer;
    Fvalido         : Boolean;
  published
    property cod_certificado: Integer read Fcod_certificado write Fcod_certificado;
    property cnpj           : string  read Fcnpj            write Fcnpj;
    property assunto        : string  read Fassunto         write Fassunto;
    property emissor        : string  read Femissor         write Femissor;
    property validade_ini   : string  read Fvalidade_ini    write Fvalidade_ini;
    property validade_fim   : string  read Fvalidade_fim    write Fvalidade_fim;
    property thumbprint     : string  read Fthumbprint      write Fthumbprint;
    property dias_restantes : Integer read Fdias_restantes  write Fdias_restantes;
    property valido         : Boolean read Fvalido          write Fvalido;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  Certificado.Service,
  Response.Utils,
  Logger.Utils,
  Horse.GBSwagger;

{ TCertificadoController }

class procedure TCertificadoController.Upload(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LBody  : TJSONObject;
  LResult: TCertificadoResult;
  LData  : TJSONObject;
  LUsuId : Integer;
begin
  try
    LBody := Req.Body<TJSONObject>;
    if not Assigned(LBody) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Body JSON inválido', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    // Extrai user_id do token JWT via Session
    LUsuId := 0;
    try
      LUsuId := Req.Session<TJSONObject>.GetValue<Integer>('user_id');
    except
      // se não conseguir, tenta como string
      try
        LUsuId := StrToIntDef(Req.Session<TJSONObject>.GetValue<string>('user_id'), 0);
      except end;
    end;

    LResult := TCertificadoService.UploadCertificado(
      LBody.GetValue<string>('certificado', ''),
      LBody.GetValue<string>('senha', ''),
      LBody.GetValue<string>('cnpj', ''),
      LUsuId
    );

    if LResult.Sucesso then
    begin
      LData := TJSONObject.Create;
      LData.AddPair('cod_certificado', TJSONNumber.Create(LResult.CodCertificado));
      LData.AddPair('cnpj',           LResult.CNPJ);
      LData.AddPair('assunto',        LResult.Assunto);
      LData.AddPair('emissor',        LResult.Emissor);
      LData.AddPair('validade_ini',   FormatDateTime('yyyy-mm-dd', LResult.ValidadeIni));
      LData.AddPair('validade_fim',   FormatDateTime('yyyy-mm-dd', LResult.ValidadeFim));
      LData.AddPair('thumbprint',     LResult.Thumbprint);
      LData.AddPair('dias_restantes', TJSONNumber.Create(LResult.DiasRestantes));
      LData.AddPair('valido',         TJSONBool.Create(LResult.Valido));
      Res.Send<TJSONObject>(TResponseUtils.SuccessData(LData)).Status(THTTPStatus.Created);
    end
    else
      Res.Send<TJSONObject>(TResponseUtils.Error(LResult.Erro, 400))
         .Status(THTTPStatus.BadRequest);
  except
    on E: Exception do
    begin
      TLogger.Error('Certificado.Controller.Upload', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TCertificadoController.Status(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LCNPJ  : string;
  LResult: TCertificadoResult;
  LData  : TJSONObject;
begin
  try
    LCNPJ := Req.Params.Items['cnpj'];

    LResult := TCertificadoService.StatusCertificado(LCNPJ);

    if LResult.Sucesso then
    begin
      LData := TJSONObject.Create;
      LData.AddPair('cod_certificado', TJSONNumber.Create(LResult.CodCertificado));
      LData.AddPair('cnpj',           LResult.CNPJ);
      LData.AddPair('assunto',        LResult.Assunto);
      LData.AddPair('emissor',        LResult.Emissor);
      LData.AddPair('validade_ini',   FormatDateTime('yyyy-mm-dd', LResult.ValidadeIni));
      LData.AddPair('validade_fim',   FormatDateTime('yyyy-mm-dd', LResult.ValidadeFim));
      LData.AddPair('thumbprint',     LResult.Thumbprint);
      LData.AddPair('dias_restantes', TJSONNumber.Create(LResult.DiasRestantes));
      LData.AddPair('valido',         TJSONBool.Create(LResult.Valido));
      Res.Send<TJSONObject>(TResponseUtils.SuccessData(LData));
    end
    else
      Res.Send<TJSONObject>(TResponseUtils.NotFound('Certificado'))
         .Status(THTTPStatus.NotFound);
  except
    on E: Exception do
    begin
      TLogger.Error('Certificado.Controller.Status', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TCertificadoController.Registrar;
begin
  THorse
    .Group
    .Prefix('/v1')
    .Route('/certificados/upload')
      .Post(Upload)
    .&End
    .Group
    .Prefix('/v1')
    .Route('/certificados/:cnpj')
      .Get(Status)
    .&End;
end;

initialization
  Swagger
    .BasePath('v1')
      .Path('certificados/upload')
        .Tag('Certificados')
        .POST('Upload de Certificado A1 (PFX)')
          .AddParamBody('Certificado', 'Dados do certificado PFX em Base64')
            .Required(True)
            .Schema(TCertificadoUploadRequest)
          .&End
          .AddResponse(201, 'Certificado enviado com sucesso')
            .Schema(TCertificadoResponse)
          .&End
          .AddResponse(400, 'Dados inválidos ou senha incorreta').&End
          .AddResponse(401, 'Não autorizado').&End
          .AddResponse(500, 'Erro interno').&End
        .&End
      .&End
      .Path('certificados/{cnpj}')
        .Tag('Certificados')
        .GET('Consulta status do certificado pelo CNPJ')
          .AddParamPath('cnpj', 'CNPJ da empresa (apenas números)')
            .Required(True)
          .&End
          .AddResponse(200, 'Certificado encontrado')
            .Schema(TCertificadoResponse)
          .&End
          .AddResponse(404, 'Certificado não encontrado').&End
          .AddResponse(401, 'Não autorizado').&End
        .&End
      .&End
    .&End

end.
