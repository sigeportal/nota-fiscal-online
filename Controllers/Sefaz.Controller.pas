unit Sefaz.Controller;

{
  Controlador de consultas ao serviço SEFAZ
  GET /v1/sefaz/status?uf=SP&modelo=55   -> consulta status NF-e
  GET /v1/sefaz/status?uf=SP&modelo=65   -> consulta status NFC-e
  GET /v1/sefaz/inutilizar               -> inutilizar números de NF-e/NFC-e
}

interface

uses
  Horse,
  Horse.Commons,
  System.SysUtils,
  System.JSON,
  System.Classes;

type
  TSefazInutilizarRequest = class
  private
    Fcnpj        : string;
    Fjustificativa: string;
    Fserie        : string;
    Fnn_ini       : Integer;
    Fnn_fin       : Integer;
    Fmodelo       : Integer;
  published
    property cnpj         : string  read Fcnpj          write Fcnpj;
    property justificativa: string  read Fjustificativa  write Fjustificativa;
    property serie        : string  read Fserie          write Fserie;
    /// Número inicial da faixa a inutilizar
    property nn_ini       : Integer read Fnn_ini         write Fnn_ini;
    /// Número final da faixa a inutilizar
    property nn_fin       : Integer read Fnn_fin         write Fnn_fin;
    /// 55 = NF-e, 65 = NFC-e
    property modelo       : Integer read Fmodelo         write Fmodelo;
  end;

  TSefazController = class
  public
    class procedure Registrar;
  private
    class procedure Status(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Inutilizar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class function  ExtrairCNPJ(Req: THorseRequest): string;
  end;

implementation

uses
  ACBr.Service,
  Response.Utils,
  Logger.Utils,
  App.Config,
  System.StrUtils,
  Horse.GBSwagger;

{ TSefazController }

class function TSefazController.ExtrairCNPJ(Req: THorseRequest): string;
begin
  Result := '';
  try
    Result := Req.Session<TJSONObject>.GetValue<string>('cnpj');
  except end;
end;

class procedure TSefazController.Status(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LUF     : string;
  LModelo : Integer;
  LService: TACBrNFeService;
  LResult : TResultadoEmissao;
  LData   : TJSONObject;
begin
  try
    LUF     := Req.Query.Items['uf'];
    LModelo := StrToIntDef(Req.Query.Items['modelo'], 65);

    if LUF.IsEmpty then
      LUF := TAppConfig.UF;

    if LModelo = 0 then
      LModelo := 65;

    // Valida modelo
    if (LModelo <> 55) and (LModelo <> 65) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error(
        'Modelo inválido. Use 55 (NF-e) ou 65 (NFC-e)', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    // Valida UF (tamanho básico)
    if LUF.Length <> 2 then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('UF inválida. Use sigla de 2 letras (ex: SP)', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LService := TACBrNFeService.Create;
    try
      // ConsultarStatusSefaz não requer certificado configurado
      LResult := LService.ConsultarStatusSefaz(UpperCase(LUF), LModelo);
    finally
      LService.Free;
    end;

    LData := TJSONObject.Create;
    LData.AddPair('uf',          UpperCase(LUF));
    LData.AddPair('modelo',      TJSONNumber.Create(LModelo));
    LData.AddPair('cstat',       TJSONNumber.Create(LResult.CStat));
    LData.AddPair('motivo',      LResult.Motivo);
    LData.AddPair('operando',    TJSONBool.Create(LResult.CStat = 107));
    LData.AddPair('descricao',   IfThen(LResult.CStat = 107,
                                   'Serviço em operação normal',
                                   'Serviço com problema: ' + LResult.Motivo));

    if LResult.CStat = 107 then
      Res.Send<TJSONObject>(TResponseUtils.SuccessData(LData))
    else
      Res.Send<TJSONObject>(TResponseUtils.Success('Serviço SEFAZ com problema', LData))
         .Status(THTTPStatus.ServiceUnavailable);
  except
    on E: Exception do
    begin
      TLogger.Error('Sefaz.Controller.Status', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TSefazController.Inutilizar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  LBody         : TJSONObject;
  LCNPJ         : string;
  LJustificativa: string;
  LSerie        : string;
  LNNIni        : Integer;
  LNNFin        : Integer;
  LModelo       : Integer;
  LService      : TACBrNFeService;
  LResult       : TResultadoEmissao;
  LData         : TJSONObject;
begin
  try
    LBody := Req.Body<TJSONObject>;
    if not Assigned(LBody) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Body JSON inválido', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LCNPJ          := LBody.GetValue<string>('cnpj', ExtrairCNPJ(Req));
    LJustificativa := LBody.GetValue<string>('justificativa', '');
    LSerie         := LBody.GetValue<string>('serie', '1');
    LNNIni         := LBody.GetValue<Integer>('nn_ini', 0);
    LNNFin         := LBody.GetValue<Integer>('nn_fin', 0);
    LModelo        := LBody.GetValue<Integer>('modelo', 55);

    if LCNPJ.IsEmpty then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('CNPJ é obrigatório', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    if LJustificativa.Length < 15 then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error(
        'Justificativa deve ter mínimo 15 caracteres', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    if (LNNIni <= 0) or (LNNFin <= 0) or (LNNIni > LNNFin) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error(
        'Faixa de números inválida (nn_ini e nn_fin devem ser positivos e nn_ini <= nn_fin)', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LService := TACBrNFeService.Create;
    try
      if not LService.Configurar(LCNPJ) then
      begin
        Res.Send<TJSONObject>(TResponseUtils.Error(
          'Certificado não encontrado para CNPJ ' + LCNPJ, 400))
           .Status(THTTPStatus.BadRequest);
        Exit;
      end;
      LResult := LService.InutilizarNumeros(LCNPJ, LJustificativa, LSerie, LNNIni, LNNFin);
    finally
      LService.Free;
    end;

    if LResult.Sucesso then
    begin
      LData := TJSONObject.Create;
      LData.AddPair('cnpj',    LCNPJ);
      LData.AddPair('serie',   LSerie);
      LData.AddPair('nn_ini',  TJSONNumber.Create(LNNIni));
      LData.AddPair('nn_fin',  TJSONNumber.Create(LNNFin));
      LData.AddPair('modelo',  TJSONNumber.Create(LModelo));
      LData.AddPair('cstat',   TJSONNumber.Create(LResult.CStat));
      LData.AddPair('motivo',  LResult.Motivo);
      LData.AddPair('protocolo', LResult.Protocolo);
      Res.Send<TJSONObject>(TResponseUtils.Success('Inutilização realizada com sucesso', LData));
    end
    else
      Res.Send<TJSONObject>(TResponseUtils.Error(LResult.Erro, 422))
         .Status(THTTPStatus.UnprocessableEntity);
  except
    on E: Exception do
    begin
      TLogger.Error('Sefaz.Controller.Inutilizar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TSefazController.Registrar;
begin
  THorse.Group.Prefix('/v1').Route('/sefaz/status').Get(Status);
  THorse.Group.Prefix('/v1').Route('/sefaz/inutilizar').Post(Inutilizar);
end;

initialization
  Swagger
    .BasePath('v1')
      .Path('sefaz/status')
        .Tag('SEFAZ')
        .GET('Consultar status do serviço SEFAZ')
          .AddParamQuery('uf', 'UF (sigla, ex: SP). Padrão: configuração do servidor')
            .Required(False)
          .&End
          .AddParamQuery('modelo', 'Modelo fiscal: 55 (NF-e) ou 65 (NFC-e). Padrão: 65')
            .Required(False)
          .&End
          .AddResponse(200, 'Serviço operando normalmente').&End
          .AddResponse(503, 'Serviço SEFAZ com problema').&End
          .AddResponse(500, 'Erro interno').&End
        .&End
      .&End
      .Path('sefaz/inutilizar')
        .Tag('SEFAZ')
        .POST('Inutilizar números de NF-e ou NFC-e')
          .AddParamBody('Dados de inutilização', 'CNPJ, série, faixa de números e justificativa')
            .Required(True)
            .Schema(TSefazInutilizarRequest)
          .&End
          .AddResponse(200, 'Inutilização realizada').&End
          .AddResponse(400, 'Dados inválidos').&End
          .AddResponse(401, 'Não autorizado').&End
          .AddResponse(422, 'SEFAZ rejeitou').&End
          .AddResponse(500, 'Erro interno').&End
        .&End
      .&End
    .&End

end.
