unit NFCe.Controller;

{
  Controlador de Notas Fiscais ao Consumidor (modelo 65)
  POST   /v1/nfce                   -> emitir NFCe
  GET    /v1/nfce/:chave            -> consultar NFCe na SEFAZ
  POST   /v1/nfce/:chave/cancelar   -> cancelar NFCe
  GET    /v1/nfce/:chave/xml        -> obter XML autorizado
  GET    /v1/nfce/:chave/danfe      -> obter DANFCe em PDF
}

interface

uses
  Horse,
  Horse.Commons,
  System.SysUtils,
  System.JSON,
  System.Classes;

type
  // Modelos Swagger
  TNFCeEmitirRequest = class
  private
    Fcnpj_emitente   : string;
    Fnatureza_operacao: string;
    Fserie           : Integer;
    Fambiente        : Integer;
    Fcpf_cliente     : string;
    Fnome_cliente    : string;
    Femit_razao_social: string;
  published
    property cnpj_emitente   : string  read Fcnpj_emitente    write Fcnpj_emitente;
    property natureza_operacao: string  read Fnatureza_operacao write Fnatureza_operacao;
    property serie            : Integer read Fserie             write Fserie;
    /// 1 = Produção, 2 = Homologação
    property ambiente         : Integer read Fambiente          write Fambiente;
    property cpf_cliente      : string  read Fcpf_cliente       write Fcpf_cliente;
    property nome_cliente     : string  read Fnome_cliente      write Fnome_cliente;
    property emit_razao_social: string  read Femit_razao_social write Femit_razao_social;
  end;

  TNFCeController = class
  public
    class procedure Registrar;
  private
    class procedure Emitir(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Consultar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Cancelar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure ObterXML(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure ObterDANFE(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class function  ExtrairCNPJ(Req: THorseRequest): string;
  end;

implementation

uses
  ACBr.Service,
  Response.Utils,
  Logger.Utils,
  Horse.GBSwagger;

{ TNFCeController }

class function TNFCeController.ExtrairCNPJ(Req: THorseRequest): string;
begin
  Result := '';
  try
    Result := Req.Session<TJSONObject>.GetValue<string>('cnpj');
  except end;
end;

class procedure TNFCeController.Emitir(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LBody   : TJSONObject;
  LCNPJ   : string;
  LService: TACBrNFeService;
  LResult : TResultadoEmissao;
  LData   : TJSONObject;
begin
  try
    LBody := Req.Body<TJSONObject>;
    if not Assigned(LBody) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Body JSON inválido', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LCNPJ := LBody.GetValue<string>('cnpj_emitente', ExtrairCNPJ(Req));
    if LCNPJ.IsEmpty then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('CNPJ do emitente é obrigatório', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LService := TACBrNFeService.Create;
    try
      if not LService.Configurar(LCNPJ) then
      begin
        Res.Send<TJSONObject>(TResponseUtils.Error(
          'Certificado não encontrado para o CNPJ ' + LCNPJ, 400))
           .Status(THTTPStatus.BadRequest);
        Exit;
      end;
      LResult := LService.EmitirNFCe(LBody);
    finally
      LService.Free;
    end;

    if LResult.Sucesso then
    begin
      LData := TJSONObject.Create;
      LData.AddPair('chave',     LResult.Chave);
      LData.AddPair('protocolo', LResult.Protocolo);
      LData.AddPair('cstat',     TJSONNumber.Create(LResult.CStat));
      LData.AddPair('motivo',    LResult.Motivo);
      Res.Send<TJSONObject>(TResponseUtils.SuccessData(LData)).Status(THTTPStatus.Created);
    end
    else
      Res.Send<TJSONObject>(TResponseUtils.Error(LResult.Erro, 422))
         .Status(THTTPStatus.UnprocessableEntity);
  except
    on E: Exception do
    begin
      TLogger.Error('NFCe.Controller.Emitir', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFCeController.Consultar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LChave  : string;
  LCNPJ   : string;
  LService: TACBrNFeService;
  LResult : TResultadoEmissao;
  LData   : TJSONObject;
begin
  try
    LChave := Req.Params.Items['chave'];
    LCNPJ  := ExtrairCNPJ(Req);

    LService := TACBrNFeService.Create;
    try
      LService.Configurar(LCNPJ);
      LResult := LService.ConsultarNFe(LChave);
    finally
      LService.Free;
    end;

    if LResult.Sucesso then
    begin
      LData := TJSONObject.Create;
      LData.AddPair('chave',     LChave);
      LData.AddPair('protocolo', LResult.Protocolo);
      LData.AddPair('cstat',     TJSONNumber.Create(LResult.CStat));
      LData.AddPair('motivo',    LResult.Motivo);
      Res.Send<TJSONObject>(TResponseUtils.SuccessData(LData));
    end
    else
      Res.Send<TJSONObject>(TResponseUtils.NotFound('NFCe'))
         .Status(THTTPStatus.NotFound);
  except
    on E: Exception do
    begin
      TLogger.Error('NFCe.Controller.Consultar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFCeController.Cancelar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LChave        : string;
  LBody         : TJSONObject;
  LProtocolo    : string;
  LJustificativa: string;
  LCNPJ         : string;
  LService      : TACBrNFeService;
  LResult       : TResultadoEmissao;
  LData         : TJSONObject;
begin
  try
    LChave := Req.Params.Items['chave'];
    LBody  := Req.Body<TJSONObject>;
    LCNPJ  := ExtrairCNPJ(Req);

    if not Assigned(LBody) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Body JSON inválido', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LProtocolo     := LBody.GetValue<string>('protocolo', '');
    LJustificativa := LBody.GetValue<string>('justificativa', 'Cancelamento solicitado');

    if LProtocolo.IsEmpty then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Protocolo é obrigatório', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    if LJustificativa.Length < 15 then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Justificativa deve ter mínimo 15 caracteres', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LService := TACBrNFeService.Create;
    try
      LService.Configurar(LCNPJ);
      LResult := LService.Cancelar(LChave, LProtocolo, LJustificativa);
    finally
      LService.Free;
    end;

    if LResult.Sucesso then
    begin
      LData := TJSONObject.Create;
      LData.AddPair('chave',     LChave);
      LData.AddPair('protocolo', LResult.Protocolo);
      LData.AddPair('cstat',     TJSONNumber.Create(LResult.CStat));
      LData.AddPair('motivo',    LResult.Motivo);
      Res.Send<TJSONObject>(TResponseUtils.Success('NFCe cancelada com sucesso', LData));
    end
    else
      Res.Send<TJSONObject>(TResponseUtils.Error(LResult.Erro, 422))
         .Status(THTTPStatus.UnprocessableEntity);
  except
    on E: Exception do
    begin
      TLogger.Error('NFCe.Controller.Cancelar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFCeController.ObterXML(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LChave  : string;
  LCNPJ   : string;
  LService: TACBrNFeService;
  LXML    : string;
begin
  try
    LChave := Req.Params.Items['chave'];
    LCNPJ  := ExtrairCNPJ(Req);

    LService := TACBrNFeService.Create;
    try
      LService.Configurar(LCNPJ);
      LXML := LService.ObterXML(LChave);
    finally
      LService.Free;
    end;

    if LXML.IsEmpty then
      Res.Send<TJSONObject>(TResponseUtils.NotFound('XML da NFCe'))
         .Status(THTTPStatus.NotFound)
    else
      Res.Send(LXML);
  except
    on E: Exception do
    begin
      TLogger.Error('NFCe.Controller.ObterXML', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFCeController.ObterDANFE(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LChave  : string;
  LCNPJ   : string;
  LService: TACBrNFeService;
  LPDFPath: string;
  LStream : TFileStream;
begin
  try
    LChave := Req.Params.Items['chave'];
    LCNPJ  := ExtrairCNPJ(Req);

    LService := TACBrNFeService.Create;
    try
      LService.Configurar(LCNPJ);
      LPDFPath := LService.GerarDANFe(LChave);
    finally
      LService.Free;
    end;

    if LPDFPath.IsEmpty then
      Res.Send<TJSONObject>(TResponseUtils.NotFound('DANFCe'))
         .Status(THTTPStatus.NotFound)
    else
    begin
      LStream := TFileStream.Create(LPDFPath, fmOpenRead or fmShareDenyWrite);
      try
        Res.Send<TStream>(LStream);
      finally
        LStream.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      TLogger.Error('NFCe.Controller.ObterDANFE', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFCeController.Registrar;
begin
  THorse.Group.Prefix('/v1').Route('/nfce').Post(Emitir);
  THorse.Group.Prefix('/v1').Route('/nfce/:chave').Get(Consultar);
  THorse.Group.Prefix('/v1').Route('/nfce/:chave/cancelar').Post(Cancelar);
  THorse.Group.Prefix('/v1').Route('/nfce/:chave/xml').Get(ObterXML);
  THorse.Group.Prefix('/v1').Route('/nfce/:chave/danfe').Get(ObterDANFE);
end;

initialization
  Swagger
    .BasePath('v1')
      .Path('nfce')
        .Tag('NFC-e')
        .POST('Emitir NFC-e (modelo 65)')
          .AddParamBody('Dados NFC-e', 'JSON com todos os dados para emissão')
            .Required(True)
            .Schema(TNFCeEmitirRequest)
          .&End
          .AddResponse(201, 'NFC-e autorizada').&End
          .AddResponse(400, 'Dados inválidos').&End
          .AddResponse(401, 'Não autorizado').&End
          .AddResponse(422, 'SEFAZ rejeitou').&End
          .AddResponse(500, 'Erro interno').&End
        .&End
      .&End
      .Path('nfce/{chave}')
        .Tag('NFC-e')
        .GET('Consultar NFC-e na SEFAZ')
          .AddParamPath('chave', 'Chave 44 dígitos').Required(True).&End
          .AddResponse(200, 'Status').&End
          .AddResponse(404, 'Não encontrada').&End
        .&End
      .&End
      .Path('nfce/{chave}/cancelar')
        .Tag('NFC-e')
        .POST('Cancelar NFC-e')
          .AddParamPath('chave', 'Chave 44 dígitos').Required(True).&End
          .AddParamBody('Cancelamento', 'Protocolo e justificativa').Required(True).&End
          .AddResponse(200, 'Cancelada com sucesso').&End
          .AddResponse(422, 'SEFAZ rejeitou').&End
        .&End
      .&End
      .Path('nfce/{chave}/xml')
        .Tag('NFC-e')
        .GET('Obter XML autorizado da NFC-e')
          .AddParamPath('chave', 'Chave 44 dígitos').Required(True).&End
          .AddResponse(200, 'XML da NFC-e').&End
          .AddResponse(404, 'XML não encontrado').&End
        .&End
      .&End
      .Path('nfce/{chave}/danfe')
        .Tag('NFC-e')
        .GET('Obter DANFCe em PDF')
          .AddParamPath('chave', 'Chave 44 dígitos').Required(True).&End
          .AddResponse(200, 'PDF do DANFCe').&End
          .AddResponse(404, 'DANFCe não encontrado').&End
        .&End
      .&End
    .&End

end.