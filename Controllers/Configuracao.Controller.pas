unit Configuracao.Controller;

{
  Controlador de configurações por usuário
  GET  /v1/configuracoes      -> lê configurações do usuário autenticado
  PUT  /v1/configuracoes      -> salva/atualiza configurações do usuário autenticado
}

interface

uses
  Horse,
  Horse.Commons;

type
  TConfiguracaoController = class
  public
    class procedure Registrar;
    class function GetUsuarioIdFromToken(Req: THorseRequest): Integer;
  private
    class procedure Buscar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Salvar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

  // ---------- modelos para o Swagger ----------

  TConfiguracaoRequest = class
  private
    Fuf                 : string;
    Fambiente_producao  : Integer;
    Fnfce_id_csc        : string;
    Fnfce_csc           : string;
    Fnfce_serie         : string;
    Fnfce_numero_inicial: Integer;
    Fnfe_serie          : string;
    Fnfe_numero_inicial : Integer;
    Fresp_cnpj          : string;
    Fresp_contato       : string;
    Fresp_email         : string;
    Fresp_fone          : string;
    Fresp_id_csrt       : string;
    Fresp_csrt          : string;
    Femit_nome          : string;
    Femit_cnpj          : string;
    Femit_ie            : string;
    Femit_endereco      : string;
    Femit_numero        : string;
    Femit_bairro        : string;
    Femit_municipio     : string;
    Femit_cep           : string;
    Femit_telefone      : string;
    Femit_crt           : Integer;
    Femit_cod_municipio : string;
  published
    /// UF de emissão (ex: MS)
    property uf                  : string  read Fuf                  write Fuf;
    /// 0=Homologação, 1=Produção
    property ambiente_producao   : Integer read Fambiente_producao   write Fambiente_producao;
    /// NFCe - ID do CSC (token segurança)
    property nfce_id_csc         : string  read Fnfce_id_csc         write Fnfce_id_csc;
    /// NFCe - CSC (código segurança do contribuinte)
    property nfce_csc            : string  read Fnfce_csc            write Fnfce_csc;
    /// NFCe - Série
    property nfce_serie          : string  read Fnfce_serie          write Fnfce_serie;
    /// NFCe - Número inicial
    property nfce_numero_inicial : Integer read Fnfce_numero_inicial  write Fnfce_numero_inicial;
    /// NFe - Série
    property nfe_serie           : string  read Fnfe_serie           write Fnfe_serie;
    /// NFe - Número inicial
    property nfe_numero_inicial  : Integer read Fnfe_numero_inicial   write Fnfe_numero_inicial;
    /// Responsável Técnico - CNPJ
    property resp_cnpj           : string  read Fresp_cnpj           write Fresp_cnpj;
    /// Responsável Técnico - Nome do contato
    property resp_contato        : string  read Fresp_contato        write Fresp_contato;
    /// Responsável Técnico - E-mail
    property resp_email          : string  read Fresp_email          write Fresp_email;
    /// Responsável Técnico - Telefone
    property resp_fone           : string  read Fresp_fone           write Fresp_fone;
    /// Responsável Técnico - ID do CSRT
    property resp_id_csrt        : string  read Fresp_id_csrt        write Fresp_id_csrt;
    /// Responsável Técnico - CSRT
    property resp_csrt           : string  read Fresp_csrt           write Fresp_csrt;
    /// Emitente - Razão Social / Nome
    property emit_nome           : string  read Femit_nome           write Femit_nome;
    /// Emitente - CNPJ (somente números)
    property emit_cnpj           : string  read Femit_cnpj           write Femit_cnpj;
    /// Emitente - Inscrição Estadual
    property emit_ie             : string  read Femit_ie             write Femit_ie;
    /// Emitente - Endereço (logradouro)
    property emit_endereco       : string  read Femit_endereco       write Femit_endereco;
    /// Emitente - Número
    property emit_numero         : string  read Femit_numero         write Femit_numero;
    /// Emitente - Bairro
    property emit_bairro         : string  read Femit_bairro         write Femit_bairro;
    /// Emitente - Município
    property emit_municipio      : string  read Femit_municipio      write Femit_municipio;
    /// Emitente - CEP
    property emit_cep            : string  read Femit_cep            write Femit_cep;
    /// Emitente - Telefone
    property emit_telefone       : string  read Femit_telefone       write Femit_telefone;
    /// Emitente - CRT (1=SN, 2=SN excesso, 3=LR)
    property emit_crt            : Integer read Femit_crt            write Femit_crt;
    /// Emitente - Código IBGE do município
    property emit_cod_municipio  : string  read Femit_cod_municipio  write Femit_cod_municipio;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  Configuracao.Service,
  Response.Utils,
  Logger.Utils,
  Horse.GBSwagger;

{ TConfiguracaoController }

class function TConfiguracaoController.GetUsuarioIdFromToken(Req: THorseRequest): Integer;
begin
  Result := 0;
  try
    Result := Req.Session<TJSONObject>.GetValue<Integer>('user_id');
  except
    try
      Result := StrToIntDef(
        Req.Session<TJSONObject>.GetValue<string>('user_id'), 0);
    except end;
  end;
end;

class procedure TConfiguracaoController.Buscar(Req: THorseRequest;
  Res: THorseResponse; Next: TProc);
var
  LUsuId: Integer;
  LData : TJSONObject;
begin
  try
    LUsuId := GetUsuarioIdFromToken(Req);
    if LUsuId = 0 then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Não autorizado', 401))
         .Status(THTTPStatus.Unauthorized);
      Exit;
    end;

    LData := TConfiguracaoService.Buscar(LUsuId);
    if Assigned(LData) then
      Res.Send<TJSONObject>(TResponseUtils.SuccessData(LData)).Status(THTTPStatus.OK)
    else
      Res.Send<TJSONObject>(TResponseUtils.Error('Configurações não encontradas', 404))
         .Status(THTTPStatus.NotFound);
  except
    on E: Exception do
    begin
      TLogger.Error('Configuracao.Controller.Buscar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TConfiguracaoController.Salvar(Req: THorseRequest;
  Res: THorseResponse; Next: TProc);
var
  LUsuId : Integer;
  LBody  : TJSONObject;
  LResult: TConfiguracaoResult;
begin
  try
    LUsuId := GetUsuarioIdFromToken(Req);
    if LUsuId = 0 then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Não autorizado', 401))
         .Status(THTTPStatus.Unauthorized);
      Exit;
    end;

    LBody := Req.Body<TJSONObject>;
    if not Assigned(LBody) then
    begin
      Res.Send<TJSONObject>(TResponseUtils.Error('Body JSON inválido', 400))
         .Status(THTTPStatus.BadRequest);
      Exit;
    end;

    LResult := TConfiguracaoService.Salvar(LUsuId, LBody);

    if LResult.Sucesso then
      Res.Send<TJSONObject>(
        TResponseUtils.Success('Configurações salvas com sucesso', nil))
        .Status(THTTPStatus.OK)
    else
      Res.Send<TJSONObject>(TResponseUtils.Error(LResult.Erro, 422))
         .Status(THTTPStatus.UnprocessableEntity);
  except
    on E: Exception do
    begin
      TLogger.Error('Configuracao.Controller.Salvar', E);
      Res.Send<TJSONObject>(TResponseUtils.InternalError(E.Message))
         .Status(THTTPStatus.InternalServerError);
    end;
  end;
end;

class procedure TConfiguracaoController.Registrar;
begin
  THorse
    .Group
    .Prefix('/v1')
    .Route('/configuracoes')
      .Get(Buscar)
      .Put(Salvar);
end;

initialization
  Swagger
    .BasePath('/v1')
    .Path('/configuracoes')
      .Tag('Configurações')
      .GET
        .Summary('Buscar configurações do usuário autenticado')
        .Description('Retorna NFCe, NFe, Responsável Técnico e dados do emitente. ' +
                     'Cria registro vazio se ainda não houver configuração.')
        .AddResponse(200, 'Configurações encontradas').Schema(TConfiguracaoRequest).&End
        .AddResponse(401, 'Não autorizado').&End
      .&End  
      .PUT
        .Summary('Salvar configurações do usuário autenticado')
        .Description('Insere ou atualiza configurações individuais: NFCe (CSC/ID), ' +
                     'NFe (série), Emitente e Responsável Técnico. ' +
                     'Todos os campos são opcionais — envie apenas os que deseja alterar.')
        .AddParamBody('Model configurações', 'Atualiza as configurações').Schema(TConfiguracaoRequest).&End
        .AddResponse(200, 'Configurações salvas com sucesso').&End
        .AddResponse(400, 'Body inválido').&End
        .AddResponse(401, 'Não autorizado').&End
        .AddResponse(422, 'Erro de validação')
        .&End
    .&End;

end.
