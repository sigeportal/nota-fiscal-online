unit NFe.Controller;

{
  Controlador de Notas Fiscais Eletrônicas (modelo 55)
  POST   /v1/nfe                   -> emitir NFe
  GET    /v1/nfe/:chave            -> consultar NFe na SEFAZ
  POST   /v1/nfe/:chave/cancelar   -> cancelar NFe
  GET    /v1/nfe/:chave/xml        -> obter XML autorizado
  GET    /v1/nfe/:chave/danfe      -> obter DANFE em PDF
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
  TNFeEmitirRequest = class
  private
    Fcnpj_emitente   : string;
    Fnatureza_operacao: string;
    Fserie           : Integer;
    Fambiente        : Integer;
    Femit_razao_social: string;
    Femit_ie         : string;
    Femit_crt        : Integer;
  published
    property cnpj_emitente   : string  read Fcnpj_emitente    write Fcnpj_emitente;
    property natureza_operacao: string  read Fnatureza_operacao write Fnatureza_operacao;
    property serie            : Integer read Fserie             write Fserie;
    /// 1 = Produção, 2 = Homologação
    property ambiente         : Integer read Fambiente          write Fambiente;
    property emit_razao_social: string  read Femit_razao_social write Femit_razao_social;
    property emit_ie          : string  read Femit_ie           write Femit_ie;
    /// 1=SN, 2=SN com excesso, 3=Regime Normal
    property emit_crt         : Integer read Femit_crt          write Femit_crt;
  end;

  TNFeEmitirResponse = class
  private
    Fsucesso  : Boolean;
    Fchave    : string;
    Fprotocolo: string;
    Fcstat    : Integer;
    Fmotivo   : string;
  published
    property sucesso  : Boolean read Fsucesso   write Fsucesso;
    property chave    : string  read Fchave     write Fchave;
    property protocolo: string  read Fprotocolo write Fprotocolo;
    property cstat    : Integer read Fcstat     write Fcstat;
    property motivo   : string  read Fmotivo    write Fmotivo;
  end;

  TNFeCancelarRequest = class
  private
    Fprotocolo   : string;
    Fjustificativa: string;
  published
    property protocolo   : string read Fprotocolo    write Fprotocolo;
    property justificativa: string read Fjustificativa write Fjustificativa;
  end;

  TNFeController = class
  public
    class procedure Registrar;
  private
    class procedure Listar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Emitir(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Consultar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Cancelar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure ObterXML(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure ObterDANFE(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class function  ExtrairCNPJ(Req: THorseRequest): string;
    class function  ExtrairUserId(Req: THorseRequest): Integer;
    class function  SomenteDigitos(const AValue: string): string;
  end;

implementation

uses
  ACBr.Service,
  Response.Utils,
  Logger.Utils,
  Horse.GBSwagger,
  UnitDatabase,
  UnitConnection.Model.Interfaces,
  Data.DB;

{ TNFeController }

class function TNFeController.ExtrairCNPJ(Req: THorseRequest): string;
begin
  Result := '';
  try
    Result := Req.Session<TJSONObject>.GetValue<string>('cnpj');
  except end;
end;

class function TNFeController.ExtrairUserId(Req: THorseRequest): Integer;
begin
  Result := 0;
  try
    Result := Req.Session<TJSONObject>.GetValue<Integer>('user_id');
  except end;
end;

class function TNFeController.SomenteDigitos(const AValue: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValue) do
    if CharInSet(AValue[I], ['0'..'9']) then
      Result := Result + AValue[I];
end;

class procedure TNFeController.Listar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LCNPJ: string;
  LLimit: Integer;
  LCount: Integer;
  LQuery: iQuery;
  LData: TJSONArray;
  LItem: TJSONObject;
  LDataHora: string;
begin
  try
    LCNPJ := SomenteDigitos(ExtrairCNPJ(Req));
    if LCNPJ.IsEmpty then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Unauthorized('Token sem CNPJ do usuário'))
         .Status(THTTPStatus.Unauthorized);
      Exit;
    end;

    LLimit := StrToIntDef(Req.Query.Items['limit'], 50);
    if LLimit <= 0 then
      LLimit := 50;
    if LLimit > 200 then
      LLimit := 200;

    LQuery := TDatabase.Query;
    LQuery.Clear;
    LQuery.Add('SELECT NOT_CHAVE_NFE AS CHAVE, NOT_PROT_AUT_NFE AS PROTOCOLO,');
    LQuery.Add('       NOT_SITUACAO_NFE AS SITUACAO, NOT_DATA AS DATA_EMISSAO,');
    LQuery.Add('       NOT_HORA AS HORA_EMISSAO, NOT_VALOR AS VALOR, NOT_NF AS NUMERO, NOT_SERIE AS SERIE');
    LQuery.Add('  FROM NOTAS_FISCAIS');
    LQuery.Add(' WHERE SUBSTRING(NOT_CHAVE_NFE FROM 7 FOR 14) = :CNPJ');
    LQuery.Add(' ORDER BY NOT_DATA DESC, NOT_HORA DESC, NOT_CODIGO DESC');
    LQuery.AddParam('CNPJ', LCNPJ);
    LQuery.Open;

    LData := TJSONArray.Create;
    LCount := 0;
    while (not LQuery.DataSet.Eof) and (LCount < LLimit) do
    begin
      if (not LQuery.DataSet.FieldByName('DATA_EMISSAO').IsNull) and
         (not LQuery.DataSet.FieldByName('HORA_EMISSAO').IsNull) then
        LDataHora :=
          FormatDateTime('yyyy-mm-dd', LQuery.DataSet.FieldByName('DATA_EMISSAO').AsDateTime) + 'T' +
          FormatDateTime('hh:nn:ss', LQuery.DataSet.FieldByName('HORA_EMISSAO').AsDateTime)
      else
        LDataHora := '';

      LItem := TJSONObject.Create;
      LItem.AddPair('chave', LQuery.DataSet.FieldByName('CHAVE').AsString);
      LItem.AddPair('protocolo', LQuery.DataSet.FieldByName('PROTOCOLO').AsString);
      LItem.AddPair('situacao', LQuery.DataSet.FieldByName('SITUACAO').AsString);
      LItem.AddPair('numero', TJSONNumber.Create(LQuery.DataSet.FieldByName('NUMERO').AsInteger));
      LItem.AddPair('serie', LQuery.DataSet.FieldByName('SERIE').AsString);
      LItem.AddPair('valor', TJSONNumber.Create(LQuery.DataSet.FieldByName('VALOR').AsFloat));
      LItem.AddPair('emitida_em', LDataHora);
      LData.AddElement(LItem);

      Inc(LCount);
      LQuery.DataSet.Next;
    end;

    Res.Send<TJSONObject>(TResponseUtils.SuccessData(LData));
  except
    on E: Exception do
    begin
      TLogger.Error('NFe.Controller.Listar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFeController.Emitir(Req: THorseRequest; Res: THorseResponse; Next: TProc);
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
      if not LService.Configurar(LCNPJ, ExtrairUserId(Req)) then
      begin
        Res.Send<TJSONObject>(TResponseUtils.Error(
          'Certificado não encontrado para o CNPJ ' + LCNPJ, 400))
           .Status(THTTPStatus.BadRequest);
        Exit;
      end;
      LResult := LService.EmitirNFe(LBody);
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
      TLogger.Error('NFe.Controller.Emitir', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFeController.Consultar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
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
      LService.Configurar(LCNPJ, ExtrairUserId(Req));
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
      Res.Send<TJSONObject>(TResponseUtils.NotFound('NFe'))
         .Status(THTTPStatus.NotFound);
  except
    on E: Exception do
    begin
      TLogger.Error('NFe.Controller.Consultar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFeController.Cancelar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
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
      LService.Configurar(LCNPJ, ExtrairUserId(Req));
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
      Res.Send<TJSONObject>(TResponseUtils.Success('NFe cancelada com sucesso', LData));
    end
    else
      Res.Send<TJSONObject>(TResponseUtils.Error(LResult.Erro, 422))
         .Status(THTTPStatus.UnprocessableEntity);
  except
    on E: Exception do
    begin
      TLogger.Error('NFe.Controller.Cancelar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFeController.ObterXML(Req: THorseRequest; Res: THorseResponse; Next: TProc);
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
      LService.Configurar(LCNPJ, ExtrairUserId(Req));
      LXML := LService.ObterXML(LChave);
    finally
      LService.Free;
    end;

    if LXML.IsEmpty then
      Res.Send<TJSONObject>(TResponseUtils.NotFound('XML da NFe'))
         .Status(THTTPStatus.NotFound)
    else
      Res.Send(LXML);
  except
    on E: Exception do
    begin
      TLogger.Error('NFe.Controller.ObterXML', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFeController.ObterDANFE(Req: THorseRequest; Res: THorseResponse; Next: TProc);
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
      LService.Configurar(LCNPJ, ExtrairUserId(Req));
      LPDFPath := LService.GerarDANFe(LChave);
    finally
      LService.Free;
    end;

    if LPDFPath.IsEmpty then
      Res.Send<TJSONObject>(TResponseUtils.NotFound('DANFE'))
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
      TLogger.Error('NFe.Controller.ObterDANFE', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TNFeController.Registrar;
begin
  THorse.Group.Prefix('/v1').Route('/nfe').Get(Listar);
  THorse.Group.Prefix('/v1').Route('/nfe').Post(Emitir);
  THorse.Group.Prefix('/v1').Route('/nfe/:chave').Get(Consultar);
  THorse.Group.Prefix('/v1').Route('/nfe/:chave/cancelar').Post(Cancelar);
  THorse.Group.Prefix('/v1').Route('/nfe/:chave/xml').Get(ObterXML);
  THorse.Group.Prefix('/v1').Route('/nfe/:chave/danfe').Get(ObterDANFE);
end;

initialization
  Swagger
    .BasePath('v1')
      .Path('nfe')
        .Tag('NF-e')
        .GET('Listar NF-e emitidas do usuário logado')
          .AddResponse(200, 'Lista de NF-e emitidas').&End
        .&End
      .&End
      .Path('nfe')
        .Tag('NF-e')
        .POST('Emitir NF-e (modelo 55)')
          .AddParamBody('Dados NF-e', 'JSON com todos os dados para emissão')
            .Required(True)
            .Schema(TNFeEmitirRequest)
          .&End
          .AddResponse(201, 'NF-e autorizada')
            .Schema(TNFeEmitirResponse)
          .&End
          .AddResponse(400, 'Dados inválidos').&End
          .AddResponse(401, 'Não autorizado').&End
          .AddResponse(422, 'SEFAZ rejeitou').&End
          .AddResponse(500, 'Erro interno').&End
        .&End
      .&End
      .Path('nfe/{chave}')
        .Tag('NF-e')
        .GET('Consultar NF-e na SEFAZ')
          .AddParamPath('chave', 'Chave 44 dígitos').Required(True).&End
          .AddResponse(200, 'Status da NF-e').&End
          .AddResponse(404, 'Não encontrada').&End
        .&End
      .&End
      .Path('nfe/{chave}/cancelar')
        .Tag('NF-e')
        .POST('Cancelar NF-e')
          .AddParamPath('chave', 'Chave 44 dígitos').Required(True).&End
          .AddParamBody('Cancelamento', 'Protocolo e justificativa')
            .Required(True).Schema(TNFeCancelarRequest).&End
          .AddResponse(200, 'Cancelada com sucesso').&End
          .AddResponse(422, 'SEFAZ rejeitou').&End
        .&End
      .&End
      .Path('nfe/{chave}/xml')
        .Tag('NF-e')
        .GET('Obter XML autorizado')
          .AddParamPath('chave', 'Chave 44 dígitos').Required(True).&End
          .AddResponse(200, 'XML da NF-e').&End
          .AddResponse(404, 'XML não encontrado').&End
        .&End
      .&End
      .Path('nfe/{chave}/danfe')
        .Tag('NF-e')
        .GET('Obter DANFE em PDF')
          .AddParamPath('chave', 'Chave 44 dígitos').Required(True).&End
          .AddResponse(200, 'PDF do DANFE').&End
          .AddResponse(404, 'DANFE não encontrado').&End
        .&End
      .&End
    .&End

end.