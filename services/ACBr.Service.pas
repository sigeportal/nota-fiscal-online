unit ACBr.Service;

{
  Serviço ACBr para emissão e consulta de NFe / NFCe
  Baseado em UnitNotaFiscalConsumidor.pas (FormsComuns)

  Fluxo de emissão:
  1. Criar TACBrNFeService
  2. Chamar Configurar(CNPJ) para carregar certificado do banco
  3. Chamar EmitirNFe / EmitirNFCe com TJSONObject dos dados
  4. Destruir instância ao final

  Códigos cStat SEFAZ:
  100 = Autorizado o uso da NF-e
  204 = Duplicidade (aguardando)
  539 = Rejeição: chave diferente
  613 = Rejeição: chave difere BD
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Math,
  System.IOUtils,
  System.DateUtils,
  System.RegularExpressions,
  ACBrNFe,
  App.Config,
  Logger.Utils,
  UnitDatabase,
  blcksock,
  pcnConversaoNFe,
  ACBrDFe.Conversao,
  ACBrDFeSSL,
  UnitConnection.Model.Interfaces,
  Models.NF,
  ACBrNFeDANFeFPDF,
  ACBrNFCeDANFeFPDF,
  ACBrNFe.Classes,
  ACBrNFe.EnvEvento;

type
  TResultadoEmissao = record
    Sucesso: Boolean;
    Chave: string;
    Protocolo: string;
    CStat: Integer;
    Motivo: string;
    XML: string;
    PDFPath: string;
    Erro: string;
  end;

  TACBrNFeService = class
  private
    FACBrNFe: TACBrNFe;
    FDANFE55: TACBrNFeDANFeFPDF;
    FDANFE65: TACBrNFCeDANFeFPDF;
    FConfigurado: Boolean;
    FCNPJ: string;
    FUsuarioId: Integer;
    FConfig: TModelConfiguracaoUsuario;

    procedure ConfigurarGeral(AModeloDF: string);
    function CarregarCertificado(const ACNPJ: string): Boolean;
    function ProximoNumeroNF(const ATabela, ACampoNF, ACampoCodigo, ASerie: string): Integer;

    function MontarNFe(AJSON: TJSONObject; ANumero: Integer): Boolean;
    function MontarNFCe(AJSON: TJSONObject; ANumero: Integer): Boolean;
    procedure AdicionarItensNFe(AJSON: TJSONObject);
    procedure AdicionarItensNFCe(AJSON: TJSONObject);
    procedure AdicionarPagamentos(AJSON: TJSONObject);

    function ExecutarEnvio(const ALote, AModelo, ASerie: string; ANumero: Integer; AJSON: TJSONObject): TResultadoEmissao;
    function ObterNumeroInicialConfigurado(const AModelo: string): Integer;
    function DetectarTipoDocumento(const AChave: string): string;
    procedure SalvarNotaEItens(AJSON: TJSONObject; const AResult: TResultadoEmissao; const AModelo, ASerie: string; ANumero: Integer);
    procedure SalvarXML(const AChave, AConteudo, ATipo: string);
    procedure SalvarDANFE(const AChave, APDFPath: string);
    function ExtrairDadosNFe(const Chave: string; out CNPJ, NumSerie, NumeroNF: string): Boolean;
    function BytesToRawByteString(const Bytes: TArray<Byte>): RawByteString;
    procedure CalculaTotais(var LNFe: TNFe; TipoNF: string);
    procedure PrepararDANFE(const ATipo: string);

  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Configura o ACBr carregando o certificado e configurações do usuário</summary>
    function Configurar(const ACNPJ: string; AUsuarioId: Integer = 0): Boolean;

    function EmitirNFe(AJSON: TJSONObject): TResultadoEmissao;
    function EmitirNFCe(AJSON: TJSONObject): TResultadoEmissao;
    function Cancelar(const AChave, AProtocolo, AJustificativa: string): TResultadoEmissao;
    function InutilizarNumeros(const ACNPJ, AJustificativa, ASerie: string; ANNFIni, ANNFFin: Integer): TResultadoEmissao;
    function ConsultarNFe(const AChave: string): TResultadoEmissao;
    function ConsultarStatusSefaz(const AUF: string; AModelo: Integer = 65): TResultadoEmissao;
    function GerarDANFe(const AChave: string): string;
    function ObterXML(const AChave: string): string;
  end;

implementation

uses
  ACBrBase,
  ACBrUtil.Base,
  Data.DB,
  System.NetEncoding,
  ACBrNFe.EventoClass,
  ACBrNFeDANFEClass;

{ TACBrNFeService }

constructor TACBrNFeService.Create;
begin
  inherited Create;
  FACBrNFe := TACBrNFe.Create(nil);
  FDANFE55 := nil;
  FDANFE65 := nil;
  FConfigurado := False;
  FUsuarioId := 0;
  FConfig := nil;
end;

destructor TACBrNFeService.Destroy;
begin
  FreeAndNil(FDANFE65);
  FreeAndNil(FDANFE55);
  FreeAndNil(FACBrNFe);
  FreeAndNil(FConfig);
  inherited Destroy;
end;

procedure TACBrNFeService.PrepararDANFE(const ATipo: string);
begin
  if SameText(ATipo, 'nfce') then
  begin
    if not Assigned(FDANFE65) then
      FDANFE65 := TACBrNFCeDANFeFPDF.Create(FACBrNFe);

    FACBrNFe.DANFE := FDANFE65;
  end
  else
  begin
    if not Assigned(FDANFE55) then
      FDANFE55 := TACBrNFeDANFeFPDF.Create(FACBrNFe);

    FACBrNFe.DANFE := FDANFE55;
  end;

  FACBrNFe.DANFE.MostraPreview := False;
  FACBrNFe.DANFE.MostraStatus := False;
end;

function TACBrNFeService.Configurar(const ACNPJ: string; AUsuarioId: Integer = 0): Boolean;
begin
  FCNPJ := ACNPJ;
  FUsuarioId := AUsuarioId;
  Result := False;
  try
    // Carrega configurações por usuário (RespTec, NFCe CSC, etc.)
    FreeAndNil(FConfig);
    if FUsuarioId > 0 then
    begin
      FConfig := TModelConfiguracaoUsuario.Create(TDatabase.Connection);
      FConfig.BuscaPorCampo('CFG_USU', FUsuarioId);
      if FConfig.Codigo = 0 then
        FreeAndNil(FConfig)
        // usuário sem configuração ainda — sem dados de RespTec
      else
        FCNPJ := FConfig.EmitCNPJ;
    end;

    // Carrega o certificado do banco antes de configurar
    if not CarregarCertificado(FCNPJ) then
    begin
      TLogger.Error('ACBr.Service: Certificado não encontrado para CNPJ %s', [FCNPJ]);
      Exit;
    end;
    FConfigurado := True;
    Result := True;
    TLogger.Info('ACBr.Service: Configurado com sucesso para CNPJ %s', [FCNPJ]);
  except
    on E: Exception do
    begin
      TLogger.Error('ACBr.Service: Erro ao configurar', E);
      raise;
    end;
  end;
end;

procedure TACBrNFeService.ConfigurarGeral(AModeloDF: string);
var
  LUF: string;
begin
  with FACBrNFe.Configuracoes do
  begin
    Geral.ValidarDigest := False;
    WebServices.SSLType := LT_TLSv1_2;
    WebServices.Tentativas := 5;
    WebServices.TimeOut := 10000;
    Geral.VersaoQRCode := veqr200;
    Geral.VersaoDF := ve400;
    Geral.IdCSC := '';
    Geral.CSC := '';

    if AModeloDF = 'NFCe' then
    begin
      Geral.ModeloDF := moNFCe;
      if Assigned(FConfig) then
      begin
        Geral.IdCSC := Trim(FConfig.NFCeIdCSC);
        Geral.CSC := Trim(FConfig.NFCeCSC);
      end;
    end
    else
      Geral.ModeloDF := moNFe;

    LUF := Trim(TAppConfig.UF);
    if LUF.IsEmpty then
      LUF := 'MS';
    WebServices.UF := LUF;

    // Ambiente lido da variável AMBIENTE_PRODUCAO (0=homolog, 1=producao)
    if TAppConfig.AmbienteProducao then
      WebServices.Ambiente := taProducao
    else
      WebServices.Ambiente := taHomologacao;

    Arquivos.PathSchemas := TAppConfig.AcbrSchemas;
    Arquivos.PathSalvar := TAppConfig.AcbrXmlDir;

    // OpenSSL para PFX (não requer SP2 do Windows)
    Geral.SSLLib := libOpenSSL;
    Geral.SSLCryptLib := cryOpenSSL;
    Geral.SSLHttpLib := httpOpenSSL;
    Geral.SSLXmlSignLib := xsLibXml2;
  end;
end;

function TACBrNFeService.CarregarCertificado(const ACNPJ: string): Boolean;
var
  LQuery: iQuery;
  LBase64: string;
  LSenha: string;
  LDados: TBytes;
  LCNPJNum: string;
begin
  Result := False;
  LCNPJNum := ACNPJ;
  // Remove formatação do CNPJ se houver
  LCNPJNum := StringReplace(LCNPJNum, '.', '', [rfReplaceAll]);
  LCNPJNum := StringReplace(LCNPJNum, '/', '', [rfReplaceAll]);
  LCNPJNum := StringReplace(LCNPJNum, '-', '', [rfReplaceAll]);

  LQuery := TDatabase.Query;
  LQuery.Clear;
  LQuery.Add('SELECT CER_DADOS, CER_SENHA_CLARA FROM CERTIFICADOS');
  LQuery.Add('WHERE CER_CNPJ = :CNPJ AND CER_ATIVO = 1');
  LQuery.Add('ORDER BY CER_DATA_CRIACAO DESC');
  LQuery.AddParam('CNPJ', LCNPJNum);
  LQuery.Open;

  if LQuery.DataSet.IsEmpty then
  begin
    TLogger.Error('ACBr.Service.CarregarCertificado: Nenhum certificado ativo para CNPJ %s', [LCNPJNum]);
    Exit;
  end;

  LSenha := LQuery.DataSet.FieldByName('CER_SENHA_CLARA').AsString;
  LBase64 := LQuery.DataSet.FieldByName('CER_DADOS').AsString;

  if LBase64.IsEmpty then
  begin
    TLogger.Error('ACBr.Service.CarregarCertificado: Campo CER_DADOS vazio para CNPJ %s', [LCNPJNum]);
    Exit;
  end;

  // Decodifica o Base64 para bytes e passa via DadosPFX (sem arquivo temporário)
  try
    LDados := TNetEncoding.Base64.DecodeStringToBytes(LBase64);
  except
    on E: Exception do
    begin
      TLogger.Error('ACBr.Service.CarregarCertificado: Erro ao decodificar Base64 - %s', [E.Message]);
      Exit;
    end;
  end;

  if Length(LDados) = 0 then
  begin
    TLogger.Error('ACBr.Service.CarregarCertificado: DadosPFX vazio após decodificação para CNPJ %s', [LCNPJNum]);
    Exit;
  end;

  FACBrNFe.Configuracoes.Certificados.ArquivoPFX := '';
  FACBrNFe.Configuracoes.Certificados.NumeroSerie := '';
  FACBrNFe.Configuracoes.Certificados.Senha := LSenha;
  FACBrNFe.Configuracoes.Certificados.DadosPFX := BytesToRawByteString(LDados);

  Result := True;
  TLogger.Info('ACBr.Service.CarregarCertificado: Certificado carregado via DadosPFX para CNPJ %s', [LCNPJNum]);
end;

function TACBrNFeService.BytesToRawByteString(const Bytes: TArray<Byte>): RawByteString;
begin
  if Length(Bytes) > 0 then
    SetString(Result, PAnsiChar(@Bytes[0]), Length(Bytes))
  else
    Result := '';
end;

function TACBrNFeService.ProximoNumeroNF(const ATabela, ACampoNF, ACampoCodigo, ASerie: string): Integer;
var
  LQuery: iQuery;
  LMaxAtual: Integer;
  LModelo: string;
begin
  if SameText(ATabela, 'NFC') then
    LModelo := 'NFCe'
  else
    LModelo := 'NFe';

  Result := ObterNumeroInicialConfigurado(LModelo);

  LQuery := TDatabase.Query;
  LQuery.Clear;
  LQuery.Add('SELECT MAX(' + ACampoNF + ') FROM ' + ATabela);
  LQuery.Add('WHERE ' + ACampoNF + ' IS NOT NULL');
  if ASerie <> '' then
  begin
    LQuery.Add('AND ' + ACampoCodigo + '_SERIE = :SERIE');
    LQuery.AddParam('SERIE', ASerie);
  end;
  LQuery.Open;
  LMaxAtual := 0;
  if (not LQuery.DataSet.IsEmpty) and (not LQuery.DataSet.Fields[0].IsNull) then
    LMaxAtual := LQuery.DataSet.Fields[0].AsInteger;

  if LMaxAtual > 0 then
    Result := Max(Result, LMaxAtual + 1);

  TLogger.Info('ACBr.Service.ProximoNumeroNF: modelo=%s serie=%s numero=%d', [LModelo, ASerie, Result]);
end;

function TACBrNFeService.ObterNumeroInicialConfigurado(const AModelo: string): Integer;
var
  LQuery: iQuery;
  LCampoNumero: string;
  LCNPJNum: string;
begin
  Result := 1;

  if SameText(AModelo, 'NFCe') then
    LCampoNumero := 'CFG_NFCE_NUMERO_INICIAL'
  else
    LCampoNumero := 'CFG_NFE_NUMERO_INICIAL';

  LCNPJNum := StringReplace(FCNPJ, '.', '', [rfReplaceAll]);
  LCNPJNum := StringReplace(LCNPJNum, '/', '', [rfReplaceAll]);
  LCNPJNum := StringReplace(LCNPJNum, '-', '', [rfReplaceAll]);

  try
    LQuery := TDatabase.Query;
    LQuery.Clear;
    LQuery.Add('SELECT FIRST 1 ' + LCampoNumero);
    LQuery.Add('  FROM CONFIGURACOES_USUARIO');

    if FUsuarioId > 0 then
    begin
      LQuery.Add(' WHERE CFG_USU = :USU');
      LQuery.AddParam('USU', FUsuarioId);
    end
    else
    begin
      LQuery.Add(' WHERE CFG_EMIT_CNPJ = :CNPJ');
      LQuery.AddParam('CNPJ', LCNPJNum);
    end;

    LQuery.Add(' ORDER BY CFG_DATA_ATUALIZACAO DESC, CFG_CODIGO DESC');
    LQuery.Open;

    if (not LQuery.DataSet.IsEmpty) and (not LQuery.DataSet.Fields[0].IsNull)
      and (LQuery.DataSet.Fields[0].AsInteger > 0) then
      Result := LQuery.DataSet.Fields[0].AsInteger;
  except
    on E: Exception do
      TLogger.Warn('ACBr.Service.ObterNumeroInicialConfigurado: %s', [E.Message]);
  end;

  if Result <= 0 then
    Result := 1;
end;

// ============================================================
// EMISSÃO NFe (modelo 55)
// ============================================================

function TACBrNFeService.EmitirNFe(AJSON: TJSONObject): TResultadoEmissao;
var
  LNumero: Integer;
  LSerie: string;
  LAmbiente: string;
  LLote: string;
begin
  Result.Sucesso := False;
  Result.Erro := '';

  if not FConfigurado then
  begin
    Result.Erro := 'ACBr não configurado. Chame Configurar(CNPJ) antes.';
    Exit;
  end;

  try
    ConfigurarGeral('NFe');

    // Ambiente do JSON: 1=Producao, 2=Homologacao
    LAmbiente := AJSON.GetValue<string>('ambiente', '2');
    if LAmbiente = '1' then
      FACBrNFe.Configuracoes.WebServices.Ambiente := taProducao
    else
      FACBrNFe.Configuracoes.WebServices.Ambiente := taHomologacao;

    LSerie := AJSON.GetValue<string>('serie', '1');
    LNumero := ProximoNumeroNF('NOTAS_FISCAIS', 'NOT_NF', 'NOT', LSerie);

    FACBrNFe.NotasFiscais.Clear;
    if not MontarNFe(AJSON, LNumero) then
    begin
      Result.Erro := 'Erro ao montar XML da NFe';
      Exit;
    end;

    // Log de debug: verificar nós principais antes de gerar o XML
    if (Assigned(FACBrNFe) and (FACBrNFe.NotasFiscais.Count > 0) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe)) then
    begin
      TLogger.Debug('ACBr.Service.EmitirNFe - pré-GerarNFe: Notas=%d DetCount=%d PagCount=%d Emit.EnderEmit=%s Dest.EnderDest=%s InfAdic=%s infRespTec=%s',
        [FACBrNFe.NotasFiscais.Count,
         FACBrNFe.NotasFiscais.Items[0].NFe.Det.Count,
         FACBrNFe.NotasFiscais.Items[0].NFe.Pag.Count,
         BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Emit) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Emit.EnderEmit), True),
         BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Dest) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Dest.EnderDest), True),
         BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.InfAdic), True),
         BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.infRespTec), True)]);
    end;

    // Geração do XML
    try
      FACBrNFe.NotasFiscais.GerarNFe;
    except
      on E: Exception do
      begin
        Result.Sucesso := False;
        Result.Erro := Format('Erro ao gerar XML da NFe: %s - %s', [E.ClassName, E.Message]);
        TLogger.Error('ACBr.Service.EmitirNFe - GerarNFe exception: %s', [E.ToString]);
        Exit;
      end;
    end;

    LLote := LSerie + IntToStr(LNumero);
    Result := ExecutarEnvio(LLote, 'NFe', LSerie, LNumero, AJSON);
  except
    on E: Exception do
    begin
      Result.Sucesso := False;
      Result.Erro := E.Message;
      TLogger.Error('ACBr.Service.EmitirNFe', E);
    end;
  end;
end;

function TACBrNFeService.MontarNFe(AJSON: TJSONObject; ANumero: Integer): Boolean;
var
  LNFe: TNFe;
  LEmitEnd: TJSONObject;
  LEmitUF: string;
  LDest: TJSONObject;
  LDestEnd: TJSONObject;
begin
  Result := False;
  try
    // Debug: log basic payload summary to help diagnose missing nodes
    try
      TLogger.Debug('ACBr.Service.MontarNFe - inicio: natOp=%s serie=%d ambiente=%s itens=%d pagamentos=%d', [AJSON.GetValue<string>('natureza_operacao', ''), AJSON.GetValue<Integer>('serie', 1), AJSON.GetValue<string>('ambiente', '2'), AJSON.GetValue<TJSONArray>('itens').Count, AJSON.GetValue<TJSONArray>('pagamentos').Count]);
    except
      // ignore logging errors
    end;
    with FACBrNFe.NotasFiscais.Add do
    begin
      LNFe := NFe;

      // Identificação
      LNFe.Ide.cNF := StrToInt(Format('%08d', [Random(99999999)]));
      LNFe.Ide.natOp := AJSON.GetValue<string>('natureza_operacao', 'VENDA DE MERCADORIAS');
      LNFe.Ide.modelo := 55;
      LNFe.Ide.serie := AJSON.GetValue<Integer>('serie', 1);
      LNFe.Ide.cUF := AJSON.GetValue<Integer>('emit_cod_uf', 50);
      LNFe.Ide.cMunFG := AJSON.GetValue<Integer>('emit_cod_mun_ibge', 5003801);
      LNFe.Ide.nNF := ANumero;
      LNFe.Ide.tpNF := tnSaida;
      LNFe.Ide.tpImp := tiRetrato;
      LNFe.Ide.indFinal := TpcnConsumidorFinal(AJSON.GetValue<Integer>('consumidor_final', 1));
      LNFe.Ide.indPres := TpcnPresencaComprador(AJSON.GetValue<Integer>('indicador_presenca', 1));
      LNFe.Ide.tpAmb := TACBrTipoAmbiente(AJSON.GetValue<Integer>('ambiente', 2) - 1);
      LNFe.Ide.dEmi := Now;
      LNFe.Ide.dSaiEnt := Now;
      LNFe.Ide.hSaiEnt := Now;
      LNFe.Ide.hSaiEnt := Now;
      // Responsável Técnico (só preenche se todos os campos obrigatórios existirem)
      if Assigned(FConfig) and not FConfig.RespCNPJ.IsEmpty
         and not FConfig.RespContato.IsEmpty and not FConfig.RespEmail.IsEmpty then
      begin
        if Assigned(LNFe.infRespTec) then
        begin
          LNFe.infRespTec.CNPJ     := FConfig.RespCNPJ;
          LNFe.infRespTec.xContato := FConfig.RespContato;
          LNFe.infRespTec.email    := FConfig.RespEmail;
          LNFe.infRespTec.fone     := FConfig.RespFone;
        end;
      end;

      // Emitente - lido do banco pelo CNPJ
      LNFe.Emit.CNPJCPF := FCNPJ;
      LNFe.Emit.xNome := AJSON.GetValue<string>('emit_razao_social', '');
      LNFe.Emit.xFant := AJSON.GetValue<string>('emit_nome_fantasia', '');
      LNFe.Emit.IE := AJSON.GetValue<string>('emit_ie', '');
      LNFe.Emit.CRT := TpcnCRT(AJSON.GetValue<Integer>('emit_crt', 3) - 1);

      // Endereço emitente
      LEmitEnd := AJSON.GetValue<TJSONObject>('emit_endereco');
      if Assigned(LEmitEnd) then
      begin
        if Assigned(LNFe.Emit) and Assigned(LNFe.Emit.EnderEmit) then
        begin
          LNFe.Emit.EnderEmit.xLgr := LEmitEnd.GetValue<string>('logradouro', '');
          LNFe.Emit.EnderEmit.nro := LEmitEnd.GetValue<string>('numero', 'SN');
          LNFe.Emit.EnderEmit.xBairro := LEmitEnd.GetValue<string>('bairro', '');
          LNFe.Emit.EnderEmit.xMun := LEmitEnd.GetValue<string>('municipio', '');
          LEmitUF := Trim(LEmitEnd.GetValue<string>('uf', ''));
          if LEmitUF.IsEmpty then
            LEmitUF := Trim(TAppConfig.UF);
          if LEmitUF.IsEmpty then
            LEmitUF := 'MS';
          LNFe.Emit.EnderEmit.UF := LEmitUF;
          LNFe.Emit.EnderEmit.CEP := StrToInt(LEmitEnd.GetValue<string>('cep', '0'));
          LNFe.Emit.EnderEmit.cMun := LEmitEnd.GetValue<Integer>('codigo_municipio', 0);
        end
        else
          TLogger.Warn('ACBr.Service.MontarNFe: EnderEmit não inicializado; pulando endereco do emitente');
      end;

      // Destinatário
      LDest := AJSON.GetValue<TJSONObject>('destinatario');
      if Assigned(LDest) then
      begin
        if Assigned(LNFe.Dest) then
        begin
          LNFe.Dest.CNPJCPF := LDest.GetValue<string>('cnpj', '');
          if LNFe.Dest.CNPJCPF.IsEmpty then
            LNFe.Dest.CNPJCPF := LDest.GetValue<string>('cpf', '');
          LNFe.Dest.xNome := LDest.GetValue<string>('nome', '');
          LNFe.Dest.IE    := LDest.GetValue<string>('ie', '');
          LNFe.Dest.email := LDest.GetValue<string>('email', '');

          // indIEDest é obrigatório na NFe 4.00:
          //   1 = Contribuinte ICMS  2 = Contribuinte isento  9 = Não contribuinte
          if LNFe.Dest.IE.IsEmpty then
            LNFe.Dest.indIEDest := inNaoContribuinte
          else
            LNFe.Dest.indIEDest := inContribuinte;

          LDestEnd := LDest.GetValue<TJSONObject>('endereco');
          if Assigned(LDestEnd) then
          begin
            if Assigned(LNFe.Dest.EnderDest) then
            begin
              LNFe.Dest.EnderDest.xLgr   := LDestEnd.GetValue<string>('logradouro', '');
              LNFe.Dest.EnderDest.nro     := LDestEnd.GetValue<string>('numero', 'SN');
              LNFe.Dest.EnderDest.xBairro := LDestEnd.GetValue<string>('bairro', '');
              LNFe.Dest.EnderDest.xMun    := LDestEnd.GetValue<string>('municipio', '');
              LNFe.Dest.EnderDest.UF      := LDestEnd.GetValue<string>('uf', '');
              LNFe.Dest.EnderDest.CEP     := StrToInt(LDestEnd.GetValue<string>('cep', '0'));
              LNFe.Dest.EnderDest.cMun    := LDestEnd.GetValue<Integer>('codigo_municipio', 0);
            end
            else
              TLogger.Warn('ACBr.Service.MontarNFe: EnderDest não inicializado; pulando endereco do destinatario');
          end;
        end
        else
          TLogger.Warn('ACBr.Service.MontarNFe: Dest não inicializado; pulando destinatario');
      end;

      // Itens
      AdicionarItensNFe(AJSON);
      //calcula totais
      CalculaTotais(LNFe, 'NFe');
      // Pagamentos
      AdicionarPagamentos(AJSON);

      // Informações adicionais (defensive)
      try
        if Assigned(LNFe.InfAdic) then
        begin
          LNFe.InfAdic.infCpl := AJSON.GetValue<string>('info_complementar', '');
          LNFe.InfAdic.infAdFisco := AJSON.GetValue<string>('info_fisco', '');
        end
        else
          TLogger.Warn('ACBr.Service.MontarNFe: InfAdic não inicializado; pulando informações adicionais');
      except
        on E: Exception do
        begin
          TLogger.Error('ACBr.Service.MontarNFe - erro ao setar InfAdic: %s', [E.Message]);
        end;
      end;
    end;

    // Debug: resumo da nota criada (nós principais)
    try
      if (Assigned(FACBrNFe) and (FACBrNFe.NotasFiscais.Count > 0) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe)) then
      begin
        TLogger.Debug('ACBr.Service.MontarNFe - pós-montagem: DetCount=%d PagCount=%d Emit.EnderEmit=%s Dest.EnderDest=%s InfAdic=%s infRespTec=%s', [FACBrNFe.NotasFiscais.Items[0].NFe.Det.Count, FACBrNFe.NotasFiscais.Items[0].NFe.Pag.Count, BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Emit) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Emit.EnderEmit), True), BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Dest) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Dest.EnderDest), True), BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.InfAdic), True), BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.infRespTec), True)]);
      end;
    except
    end;

    Result := True;
  except
    on E: Exception do
    begin
      TLogger.Error('ACBr.Service.MontarNFe', E);
      raise;
    end;
  end;
end;

procedure TACBrNFeService.AdicionarItensNFe(AJSON: TJSONObject);
var
  LItens: TJSONArray;
  LItem: TJSONObject;
  i: Integer;
  LDet: TDetCollectionItem;
  LAliqICMS: Double;
  LCST: TCSTIcms;
  CST: string;
  LCSOSN: TCSOSNIcms;
begin
  LItens := AJSON.GetValue<TJSONArray>('itens');
  if not Assigned(LItens) then
    Exit;

  // Defensive checks: ensure Nota/NFe exist before adding items
  if not Assigned(FACBrNFe) or (FACBrNFe.NotasFiscais.Count = 0) or (not Assigned(FACBrNFe.NotasFiscais.Items[0].NFe)) then
  begin
    TLogger.Error('ACBr.Service.AdicionarItensNFe: NFe node not initialized');
    raise Exception.Create('NFe interno não inicializado. Verifique se MontarNFe criou a nota corretamente.');
  end;
  for i := 0 to LItens.Count - 1 do
  begin
    LItem := LItens.Items[i] as TJSONObject;
    try
      LDet := FACBrNFe.NotasFiscais.Items[0].NFe.Det.New;

      LDet.Prod.nItem := i + 1;
      LDet.Prod.cProd := LItem.GetValue<string>('codigo', IntToStr(i + 1));
      LDet.Prod.cEAN := LItem.GetValue<string>('ean', 'SEM GTIN');
      LDet.Prod.xProd := LItem.GetValue<string>('descricao', '');
      LDet.Prod.NCM := LItem.GetValue<string>('ncm', '');
      LDet.Prod.CFOP := LItem.GetValue<string>('cfop', '5102');
      LDet.Prod.uCom := LItem.GetValue<string>('unidade', 'UN');
      LDet.Prod.qCom := LItem.GetValue<Double>('quantidade', 1);
      LDet.Prod.vUnCom := LItem.GetValue<Double>('valor_unitario', 0);
      LDet.Prod.vProd := LItem.GetValue<Double>('valor_total', 0);
      LDet.Prod.uTrib := LItem.GetValue<string>('unidade', 'UN');
      LDet.Prod.qTrib := LItem.GetValue<Double>('quantidade', 1);
      LDet.Prod.vUnTrib := LItem.GetValue<Double>('valor_unitario', 0);
      LDet.Prod.vDesc := LItem.GetValue<Double>('desconto', 0);
      LDet.Prod.indTot := itSomaTotalNFe;
      LDet.Prod.CEST := LItem.GetValue<string>('cest', '');

      LAliqICMS := LItem.GetValue<Double>('aliq_icms', 0);
      // ICMS
      CST := LItem.GetValue<string>('cst_icms', '102');
      if CST.Trim.ToInteger > 2 then
      begin
        LCSOSN := StrToCSOSNIcms(CST);
        LDet.Imposto.ICMS.CSOSN := LCSOSN;
      end
      else
      begin
        LCST := StrToCSTICMS(CST);
        LDet.Imposto.ICMS.CST := LCST;
      end;
      LDet.Imposto.ICMS.orig := TOrigemMercadoria.oeNacional;
      if LAliqICMS > 0 then
      begin
        LDet.Imposto.ICMS.modBC := TpcnDeterminacaoBaseIcms.dbiMargemValorAgregado;
        LDet.Imposto.ICMS.vBC := LDet.Prod.vProd;
        LDet.Imposto.ICMS.pICMS := LAliqICMS;
        LDet.Imposto.ICMS.vICMS := (LDet.Prod.vProd * LAliqICMS) / 100;
      end;

      // PIS
      LDet.Imposto.PIS.CST := StrToCSTPIS(LItem.GetValue<string>('cst_pis', '07'));
      LDet.Imposto.PIS.vBC := 0;
      LDet.Imposto.PIS.pPIS := LItem.GetValue<Double>('aliq_pis', 0);
      LDet.Imposto.PIS.vPIS := 0;

      // COFINS
      LDet.Imposto.COFINS.CST := StrToCSTCOFINS(LItem.GetValue<string>('cst_cofins', '07'));
      LDet.Imposto.COFINS.vBC := 0;
      LDet.Imposto.COFINS.pCOFINS := LItem.GetValue<Double>('aliq_cofins', 0);
      LDet.Imposto.COFINS.vCOFINS := 0;
    except
      on E: Exception do
      begin
        TLogger.Error('ACBr.Service.AdicionarItensNFe - erro no item %d: %s | JSON: %s', [i, E.Message, LItem.ToString]);
        raise;
      end;
    end;
  end;
end;

// ============================================================
// EMISSÃO NFCe (modelo 65)
// ============================================================

function TACBrNFeService.EmitirNFCe(AJSON: TJSONObject): TResultadoEmissao;
var
  LNumero: Integer;
  LSerie: string;
  LAmbiente: string;
  LLote: string;
begin
  Result.Sucesso := False;
  Result.Erro := '';

  if not FConfigurado then
  begin
    Result.Erro := 'ACBr não configurado. Chame Configurar(CNPJ) antes.';
    Exit;
  end;

  try
    ConfigurarGeral('NFCe');

    if FACBrNFe.Configuracoes.Geral.IdCSC.IsEmpty or FACBrNFe.Configuracoes.Geral.CSC.IsEmpty then
    begin
      Result.Erro := 'CSC e IdCSC da NFC-e não configurados para o usuário. Configure esses dados antes de emitir NFC-e.';
      Exit;
    end;

    LAmbiente := AJSON.GetValue<string>('ambiente', '2');
    if LAmbiente = '1' then
      FACBrNFe.Configuracoes.WebServices.Ambiente := taProducao
    else
      FACBrNFe.Configuracoes.WebServices.Ambiente := taHomologacao;

    LSerie := AJSON.GetValue<string>('serie', '1');
    LNumero := ProximoNumeroNF('NFC', 'NFC_NF', 'NFC', LSerie);

    FACBrNFe.NotasFiscais.Clear;
    if not MontarNFCe(AJSON, LNumero) then
    begin
      Result.Erro := 'Erro ao montar XML da NFCe';
      Exit;
    end;

    // Geração do XML - envolvemos em try/except para capturar erros internos do ACBr
    try
      FACBrNFe.NotasFiscais.GerarNFe;
    except
      on E: Exception do
      begin
        Result.Sucesso := False;
        Result.Erro := Format('Erro ao gerar XML da NFCe: %s - %s', [E.ClassName, E.Message]);
        TLogger.Error('ACBr.Service.EmitirNFCe - GerarNFe exception: %s', [E.ToString]);
        Exit;
      end;
    end;

    LLote := LSerie + IntToStr(LNumero);
    Result := ExecutarEnvio(LLote, 'NFCe', LSerie, LNumero, AJSON);
  except
    on E: Exception do
    begin
      Result.Sucesso := False;
      Result.Erro := E.Message;
      TLogger.Error('ACBr.Service.EmitirNFCe', E);
    end;
  end;
end;

function TACBrNFeService.MontarNFCe(AJSON: TJSONObject; ANumero: Integer): Boolean;
var
  LNFe: TNFe;
  LEmitEnd: TJSONObject;
  LEmitUF: string;
  LCPF: string;  
begin
  Result := False;
  try
    // Debug: resumo do payload para NFCe
    try
      TLogger.Debug('ACBr.Service.MontarNFCe - inicio: natOp=%s serie=%d ambiente=%s itens=%d pagamentos=%d', [AJSON.GetValue<string>('natureza_operacao', ''), AJSON.GetValue<Integer>('serie', 1), AJSON.GetValue<string>('ambiente', '2'), AJSON.GetValue<TJSONArray>('itens').Count, AJSON.GetValue<TJSONArray>('pagamentos').Count]);
    except
    end;
    with FACBrNFe.NotasFiscais.Add do
    begin
      LNFe := NFe;

      // Identificação
      LNFe.Ide.cNF := StrToInt(Format('%08d', [Random(99999999)]));
      LNFe.Ide.natOp := AJSON.GetValue<string>('natureza_operacao', 'VENDA A CONSUMIDOR');
      LNFe.Ide.modelo := 65;
      LNFe.Ide.serie := AJSON.GetValue<Integer>('serie', 1);
      LNFe.Ide.cUF := AJSON.GetValue<Integer>('emit_cod_uf', 50);
      LNFe.Ide.cMunFG := AJSON.GetValue<Integer>('emit_cod_mun_ibge', 5003801);
      LNFe.Ide.nNF := ANumero;
      LNFe.Ide.tpNF := tnSaida;
      LNFe.Ide.tpImp := tiNFCe;
      LNFe.Ide.indFinal := TpcnConsumidorFinal.cfConsumidorFinal;
      // sempre consumidor final na NFCe
      LNFe.Ide.indPres := TpcnPresencaComprador.pcPresencial; // presencial
      LNFe.Transp.ModFrete := mfSemFrete; // 9 = Sem frete
      LNFe.Ide.tpAmb := TACBrTipoAmbiente(AJSON.GetValue<Integer>('ambiente', 2)-1);
      LNFe.Ide.dEmi := Now;
      LNFe.Ide.dSaiEnt := Now;
      LNFe.Ide.hSaiEnt := Now;

      // Responsável Técnico (por usuário, via CONFIGURACOES_USUARIO)
      if Assigned(FConfig) and not FConfig.RespCNPJ.IsEmpty then
      begin
        if Assigned(LNFe.infRespTec) then
        begin
          LNFe.infRespTec.CNPJ := FConfig.RespCNPJ;
          LNFe.infRespTec.xContato := FConfig.RespContato;
          LNFe.infRespTec.email := FConfig.RespEmail;
          LNFe.infRespTec.fone := FConfig.RespFone;
        end
        else
          TLogger.Warn('ACBr.Service.MontarNFCe: infRespTec não inicializado; pulando responsavel tecnico');
      end;

      // Emitente
      LNFe.Emit.CNPJCPF := FCNPJ;
      LNFe.Emit.xNome := AJSON.GetValue<string>('emit_razao_social', '');
      LNFe.Emit.IE := AJSON.GetValue<string>('emit_ie', '');
      LNFe.Emit.CRT := TpcnCRT(AJSON.GetValue<Integer>('emit_crt', 1)-1);

      LEmitEnd := AJSON.GetValue<TJSONObject>('emit_endereco');
      if Assigned(LEmitEnd) then
      begin
        if Assigned(LNFe.Emit) and Assigned(LNFe.Emit.EnderEmit) then
        begin
          LNFe.Emit.EnderEmit.xLgr := LEmitEnd.GetValue<string>('logradouro', '');
          LNFe.Emit.EnderEmit.nro := LEmitEnd.GetValue<string>('numero', 'SN');
          LNFe.Emit.EnderEmit.xBairro := LEmitEnd.GetValue<string>('bairro', '');
          LNFe.Emit.EnderEmit.xMun := LEmitEnd.GetValue<string>('municipio', '');
          LEmitUF := Trim(LEmitEnd.GetValue<string>('uf', ''));
          if LEmitUF.IsEmpty then
            LEmitUF := Trim(TAppConfig.UF);
          if LEmitUF.IsEmpty then
            LEmitUF := 'MS';
          LNFe.Emit.EnderEmit.UF := LEmitUF;
          LNFe.Emit.EnderEmit.CEP := StrToInt(LEmitEnd.GetValue<string>('cep', '0'));
          LNFe.Emit.EnderEmit.cMun := LEmitEnd.GetValue<Integer>('codigo_municipio', 0);
        end
        else
          TLogger.Warn('ACBr.Service.MontarNFCe: EnderEmit não inicializado; pulando endereco do emitente');
      end;

      // Destinatário (opcional na NFCe)
      LCPF := AJSON.GetValue<string>('cpf_cliente', '');
      if not LCPF.IsEmpty then
      begin
        LNFe.Dest.CNPJCPF := LCPF;
        LNFe.Dest.xNome := AJSON.GetValue<string>('nome_cliente', '');
      end;

      // Itens
      AdicionarItensNFCe(AJSON);
      //calcula totais
      CalculaTotais(LNFe, 'NFCe');
      // Pagamentos
      AdicionarPagamentos(AJSON);
    end;

    // Debug: resumo da nota criada (nós principais) para NFCe
    try
      if (Assigned(FACBrNFe) and (FACBrNFe.NotasFiscais.Count > 0) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe)) then
      begin
        TLogger.Debug('ACBr.Service.MontarNFCe - pós-montagem: DetCount=%d PagCount=%d Emit.EnderEmit=%s Dest.EnderDest=%s InfAdic=%s infRespTec=%s', [FACBrNFe.NotasFiscais.Items[0].NFe.Det.Count, FACBrNFe.NotasFiscais.Items[0].NFe.Pag.Count, BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Emit) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Emit.EnderEmit), True), BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Dest) and Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.Dest.EnderDest), True), BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.InfAdic), True), BoolToStr(Assigned(FACBrNFe.NotasFiscais.Items[0].NFe.infRespTec), True)]);
      end;
    except
    end;

    Result := True;
  except
    on E: Exception do
    begin
      TLogger.Error('ACBr.Service.MontarNFCe', E);
      raise;
    end;
  end;
end;

procedure TACBrNFeService.CalculaTotais(var LNFe: TNFe; TipoNF: string);
var 
	nTotalItens, nTotalDesc, nTotalFrete, nTotalSeg, nTotalOutros, nTotalST, nTotalIPI: Double;
  i: integer;
begin
		// Totais (calculados automaticamente pelo ACBr ao GerarNFe)
    nTotalItens := 0;
    nTotalDesc := 0;
    nTotalFrete := 0;
    nTotalSeg := 0;
    nTotalOutros := 0;
    nTotalST := 0;
    nTotalIPI := 0;

    // 1. Somar os valores percorrendo os itens (Det)
    for i := 0 to LNFe.Det.Count - 1 do
    begin
      // Verifica se o item compõe o total da nota (1 = itCompoeTotal)
      if LNFe.Det.Items[i].Prod.indTot = itSomaTotalNFe then
      begin
        nTotalItens := nTotalItens + LNFe.Det.Items[i].Prod.vProd;
        nTotalDesc := nTotalDesc + LNFe.Det.Items[i].Prod.vDesc;
        // Impostos que somam no total da nota
        nTotalST := nTotalST + LNFe.Det.Items[i].Imposto.ICMS.vICMSST;
        nTotalIPI := nTotalIPI + LNFe.Det.Items[i].Imposto.IPI.vIPI;
        if TipoNF.Contains('NFe') then
        begin
          nTotalFrete := nTotalFrete + LNFe.Det.Items[i].Prod.vFrete;
          nTotalSeg := nTotalSeg + LNFe.Det.Items[i].Prod.vSeg;          
        	nTotalOutros := nTotalOutros + LNFe.Det.Items[i].Prod.vOutro;
        end;
      end;
    end;

    // 2. Atribuir os totais ao grupo ICMSTot usando a variável LNFe
    LNFe.Total.ICMSTot.vProd := nTotalItens;
    LNFe.Total.ICMSTot.vDesc := nTotalDesc;
    LNFe.Total.ICMSTot.vST := nTotalST;
    LNFe.Total.ICMSTot.vIPI := nTotalIPI;
		if TipoNF.Contains('NFe') then
    begin
      LNFe.Total.ICMSTot.vFrete := nTotalFrete;
      LNFe.Total.ICMSTot.vSeg := nTotalSeg;
      LNFe.Total.ICMSTot.vOutro := nTotalOutros;
    end;    
    // 3. Calcular o valor final da nota (vNF)
    LNFe.Total.ICMSTot.vNF := (nTotalItens - nTotalDesc) + nTotalST + nTotalFrete + nTotalSeg + nTotalOutros + nTotalIPI;
end;

procedure TACBrNFeService.AdicionarItensNFCe(AJSON: TJSONObject);
var
  LItens: TJSONArray;
  LItem: TJSONObject;
  i: Integer;
  LDet: TDetCollectionItem;
  LCST: TCSTIcms;
  LCSOSN: TCSOSNIcms;
  LAliqICMS: Double;
  CST: string;
begin
  LItens := AJSON.GetValue<TJSONArray>('itens');
  if not Assigned(LItens) then
    Exit;

  // Defensive checks: ensure Nota/NFe exist before adding items
  if not Assigned(FACBrNFe) or (FACBrNFe.NotasFiscais.Count = 0) or (not Assigned(FACBrNFe.NotasFiscais.Items[0].NFe)) then
  begin
    TLogger.Error('ACBr.Service.AdicionarItensNFCe: NFe node not initialized');
    raise Exception.Create('NFe interno não inicializado. Verifique se MontarNFCe criou a nota corretamente.');
  end;

  for i := 0 to LItens.Count - 1 do
  begin
    LItem := LItens.Items[i] as TJSONObject;
    try
      LDet := FACBrNFe.NotasFiscais.Items[0].NFe.Det.New;

      LDet.Prod.nItem := i + 1;
      LDet.Prod.cProd := LItem.GetValue<string>('codigo', IntToStr(i + 1));
      LDet.Prod.cEAN := LItem.GetValue<string>('ean', 'SEM GTIN');
      LDet.Prod.xProd := LItem.GetValue<string>('descricao', '');
      LDet.Prod.NCM := LItem.GetValue<string>('ncm', '');
      LDet.Prod.CFOP := LItem.GetValue<string>('cfop', '5102');
      LDet.Prod.uCom := LItem.GetValue<string>('unidade', 'UN');
      LDet.Prod.qCom := LItem.GetValue<Double>('quantidade', 1);
      LDet.Prod.vUnCom := LItem.GetValue<Double>('valor_unitario', 0);
      LDet.Prod.vProd := LItem.GetValue<Double>('valor_total', 0);
      LDet.Prod.uTrib := LItem.GetValue<string>('unidade', 'UN');
      LDet.Prod.qTrib := LItem.GetValue<Double>('quantidade', 1);
      LDet.Prod.vUnTrib := LItem.GetValue<Double>('valor_unitario', 0);
      LDet.Prod.vDesc := LItem.GetValue<Double>('desconto', 0);
      LDet.Prod.indTot := itSomaTotalNFe;
      LDet.Prod.CEST := LItem.GetValue<string>('cest', '');

      // ICMS
      CST := LItem.GetValue<string>('cst_icms', '102');
      if CST.Trim.ToInteger > 2 then
      begin
        LCSOSN := StrToCSOSNIcms(CST);
        LDet.Imposto.ICMS.CSOSN := LCSOSN;
      end
      else
      begin
        LCST := StrToCSTICMS(CST);
        LDet.Imposto.ICMS.CST := LCST;
      end;

      LDet.Imposto.ICMS.orig := TOrigemMercadoria.oeNacional;
      LAliqICMS := LItem.GetValue<Double>('aliq_icms', 0);
      if LAliqICMS > 0 then
      begin
        LDet.Imposto.ICMS.modBC := TpcnDeterminacaoBaseIcms.dbiMargemValorAgregado;
        LDet.Imposto.ICMS.vBC := LDet.Prod.vProd;
        LDet.Imposto.ICMS.pICMS := LAliqICMS;
        LDet.Imposto.ICMS.vICMS := (LDet.Prod.vProd * LAliqICMS) / 100;
      end;

      // PIS / COFINS (sem incidência é cST 07 padrão no varejo)
      LDet.Imposto.PIS.CST := StrToCSTPIS(LItem.GetValue<string>('cst_pis', '07'));
      LDet.Imposto.COFINS.CST := StrToCSTCOFINS(LItem.GetValue<string>('cst_cofins', '07'));
    except
      on E: Exception do
      begin
        TLogger.Error('ACBr.Service.AdicionarItensNFCe - erro no item %d: %s | JSON: %s', [i, E.Message, LItem.ToString]);
        raise;
      end;
    end;
  end;
end;

procedure TACBrNFeService.AdicionarPagamentos(AJSON: TJSONObject);
var
  LPgtos: TJSONArray;
  LPgto: TJSONObject;
  i: Integer;
  LPag: TpagCollectionItem;
begin
  LPgtos := AJSON.GetValue<TJSONArray>('pagamentos');
  if not Assigned(LPgtos) then
  begin
    // Fallback: cria um pagamento único = valor total
    if not Assigned(FACBrNFe) or (FACBrNFe.NotasFiscais.Count = 0) or (not Assigned(FACBrNFe.NotasFiscais.Items[0].NFe)) then
    begin
      TLogger.Error('ACBr.Service.AdicionarPagamentos: NFe node not initialized');
      raise Exception.Create('NFe interno não inicializado. Verifique se MontarNFe/MontarNFCe criou a nota corretamente.');
    end;

    LPag := FACBrNFe.NotasFiscais.Items[0].NFe.Pag.New;
    LPag.tPag := TpcnFormaPagamento.fpDinheiro;
    LPag.vPag := AJSON.GetValue<Double>('valor_total', 0);
    Exit;
  end;

  for i := 0 to LPgtos.Count - 1 do
  begin
    LPgto := LPgtos.Items[i] as TJSONObject;
    if not Assigned(FACBrNFe) or (FACBrNFe.NotasFiscais.Count = 0) or (not Assigned(FACBrNFe.NotasFiscais.Items[0].NFe)) then
    begin
      TLogger.Error('ACBr.Service.AdicionarPagamentos: NFe node not initialized');
      raise Exception.Create('NFe interno não inicializado. Verifique se MontarNFe/MontarNFCe criou a nota corretamente.');
    end;

    LPag := FACBrNFe.NotasFiscais.Items[0].NFe.Pag.New;
    LPag.tPag := TpcnFormaPagamento(LPgto.GetValue<Integer>('forma', 1) - 1);
    LPag.vPag := LPgto.GetValue<Double>('valor', 0);
  end;
end;

// ============================================================
// ENVIO (comum NFe/NFCe)
// ============================================================

function TACBrNFeService.ExecutarEnvio(const ALote, AModelo, ASerie: string; ANumero: Integer; AJSON: TJSONObject): TResultadoEmissao;
var
  LTipo: string;
begin
  Result.Sucesso := False;
  Result.Chave := '';
  Result.Protocolo := '';
  Result.CStat := 0;
  Result.Motivo := '';
  Result.XML := '';
  Result.Erro := '';

  try
    FACBrNFe.Enviar(ALote, False, True);

    Result.CStat := FACBrNFe.WebServices.Enviar.CStat;
    Result.Motivo := FACBrNFe.WebServices.Enviar.XMotivo;
    Result.Chave := FACBrNFe.NotasFiscais.Items[0].NFe.procNFe.chNFe;
    Result.Protocolo := FACBrNFe.WebServices.Enviar.Protocolo;
    Result.XML := FACBrNFe.NotasFiscais.Items[0].XMLOriginal;
    Result.Sucesso := Result.CStat = 100;

    if Result.Sucesso then
    begin
      if SameText(AModelo, 'NFCe') then
        LTipo := 'nfce'
      else
        LTipo := 'nfe';

      SalvarNotaEItens(AJSON, Result, AModelo, ASerie, ANumero);
      SalvarXML(Result.Chave, Result.XML, LTipo);
    end
    else
      Result.Erro := Format('SEFAZ retornou cStat=%d: %s', [Result.CStat, Result.Motivo]);

    TLogger.Info('ACBr.Service.ExecutarEnvio: chave=%s cStat=%d motivo=%s', [Result.Chave, Result.CStat, Result.Motivo]);
  except
    on E: Exception do
    begin
      Result.Sucesso := False;
      Result.Erro := E.Message;
      TLogger.Error('ACBr.Service.ExecutarEnvio', E);
    end;
  end;
end;

function TACBrNFeService.DetectarTipoDocumento(const AChave: string): string;
begin
  if (Length(AChave) = 44) and (Copy(AChave, 21, 2) = '65') then
    Result := 'nfce'
  else
    Result := 'nfe';
end;

procedure TACBrNFeService.SalvarNotaEItens(AJSON: TJSONObject; const AResult: TResultadoEmissao; const AModelo, ASerie: string; ANumero: Integer);
var
  LCabQuery: iQuery;
  LItemQuery: iQuery;
  LDelItensQuery: iQuery;
  LItens: TJSONArray;
  LItem: TJSONObject;
  LNotaCodigo: Integer;
  LItemCodigo: Integer;
  LValorTotal: Currency;
  LDescontoTotal: Currency;
  LValorProdutos: Currency;
  LBCIcms: Currency;
  LVIcms: Currency;
  LValorItem: Currency;
  LAliqIcms: Double;
  LCFOPPrincipal: string;
  LProdutoNum: Integer;
  LCPFCliente: string;
  LNomeCliente: string;
  i: Integer;
begin
  if not Assigned(AJSON) then
    Exit;

  LItens := AJSON.GetValue<TJSONArray>('itens');
  LValorTotal := 0;
  LDescontoTotal := 0;
  LValorProdutos := 0;
  LBCIcms := 0;
  LVIcms := 0;
  LCFOPPrincipal := '';

  if Assigned(LItens) then
  begin
    for i := 0 to LItens.Count - 1 do
    begin
      LItem := LItens.Items[i] as TJSONObject;
      LValorItem := LItem.GetValue<Currency>('valor_total', 0);
      LAliqIcms := LItem.GetValue<Double>('aliq_icms', 0);

      LValorTotal := LValorTotal + LValorItem;
      LValorProdutos := LValorProdutos + LValorItem;
      LDescontoTotal := LDescontoTotal + LItem.GetValue<Currency>('desconto', 0);

      if LAliqIcms > 0 then
      begin
        LBCIcms := LBCIcms + LValorItem;
        LVIcms := LVIcms + ((LValorItem * LAliqIcms) / 100);
      end;

      if LCFOPPrincipal.IsEmpty then
        LCFOPPrincipal := LItem.GetValue<string>('cfop', '5102');
    end;
  end;

  if LCFOPPrincipal.IsEmpty then
    LCFOPPrincipal := '5102';

  if SameText(AModelo, 'NFCe') then
  begin
    LCPFCliente := AJSON.GetValue<string>('cpf_cliente', '');
    LNomeCliente := AJSON.GetValue<string>('nome_cliente', '');

    LCabQuery := TDatabase.Query;
    LCabQuery.Clear;
    LCabQuery.Add('SELECT FIRST 1 NFC_CODIGO FROM NFC WHERE NFC_CHAVE_NFCE = :CHAVE');
    LCabQuery.AddParam('CHAVE', AResult.Chave);
    LCabQuery.Open;

    if not LCabQuery.DataSet.IsEmpty then
      LNotaCodigo := LCabQuery.DataSet.FieldByName('NFC_CODIGO').AsInteger
    else
    begin
      LCabQuery.Clear;
      LCabQuery.Add('SELECT COALESCE(MAX(NFC_CODIGO), 0) + 1 AS CODIGO FROM NFC');
      LCabQuery.Open;
      LNotaCodigo := LCabQuery.DataSet.FieldByName('CODIGO').AsInteger;

      LCabQuery.Clear;
      LCabQuery.Add('INSERT INTO NFC ('+
        'NFC_CODIGO, NFC_NF, NFC_CFOP, NFC_DATA, NFC_HORA, NFC_MODELO, NFC_SERIE, ' +
        'NFC_CHAVE_NFCE, NFC_SITUACAO_NFCE, NFC_VALOR, NFC_DESCONTO, NFC_BCICMS, NFC_VICMS, NFC_VTPROD, ' +
        'NFC_NUM_RECIBO_NFCE, NFC_PROT_AUT_NFCE, NFC_CPF_CLIENTE, NFC_NOME_CLIENTE, NFC_OPER_CONSUM_FINAL, NFC_CONDICAO_PGTO)' );
      LCabQuery.Add('VALUES ('+
        ':CODIGO, :NF, :CFOP, CURRENT_DATE, CURRENT_TIME, ''65'', :SERIE, ' +
        ':CHAVE, ''AUTORIZADA'', :VALOR, :DESCONTO, :BCICMS, :VICMS, :VTPROD, ' +
        ':RECIBO, :PROTOCOLO, :CPF, :NOME, ''S'', ''1'')');
      LCabQuery.AddParam('CODIGO', LNotaCodigo);
      LCabQuery.AddParam('NF', ANumero);
      LCabQuery.AddParam('CFOP', LCFOPPrincipal);
      LCabQuery.AddParam('SERIE', ASerie);
      LCabQuery.AddParam('CHAVE', AResult.Chave);
      LCabQuery.AddParam('VALOR', LValorTotal);
      LCabQuery.AddParam('DESCONTO', LDescontoTotal);
      LCabQuery.AddParam('BCICMS', LBCIcms);
      LCabQuery.AddParam('VICMS', LVIcms);
      LCabQuery.AddParam('VTPROD', LValorProdutos);
      LCabQuery.AddParam('RECIBO', AResult.Protocolo);
      LCabQuery.AddParam('PROTOCOLO', AResult.Protocolo);
      LCabQuery.AddParam('CPF', LCPFCliente);
      LCabQuery.AddParam('NOME', LNomeCliente);
      LCabQuery.ExecSQL;
    end;

    LCabQuery.Clear;
    LCabQuery.Add('UPDATE NFC SET ' +
                  'NFC_NF = :NF, NFC_SERIE = :SERIE, NFC_CFOP = :CFOP, ' +
                  'NFC_SITUACAO_NFCE = ''AUTORIZADA'', NFC_NUM_RECIBO_NFCE = :RECIBO, NFC_PROT_AUT_NFCE = :PROTOCOLO, ' +
                  'NFC_VALOR = :VALOR, NFC_DESCONTO = :DESCONTO, NFC_BCICMS = :BCICMS, NFC_VICMS = :VICMS, NFC_VTPROD = :VTPROD, ' +
                  'NFC_CPF_CLIENTE = :CPF, NFC_NOME_CLIENTE = :NOME ' +
                  'WHERE NFC_CODIGO = :CODIGO');
    LCabQuery.AddParam('NF', ANumero);
    LCabQuery.AddParam('SERIE', ASerie);
    LCabQuery.AddParam('CFOP', LCFOPPrincipal);
    LCabQuery.AddParam('RECIBO', AResult.Protocolo);
    LCabQuery.AddParam('PROTOCOLO', AResult.Protocolo);
    LCabQuery.AddParam('VALOR', LValorTotal);
    LCabQuery.AddParam('DESCONTO', LDescontoTotal);
    LCabQuery.AddParam('BCICMS', LBCIcms);
    LCabQuery.AddParam('VICMS', LVIcms);
    LCabQuery.AddParam('VTPROD', LValorProdutos);
    LCabQuery.AddParam('CPF', LCPFCliente);
    LCabQuery.AddParam('NOME', LNomeCliente);
    LCabQuery.AddParam('CODIGO', LNotaCodigo);
    LCabQuery.ExecSQL;

    LDelItensQuery := TDatabase.Query;
    LDelItensQuery.Clear;
    LDelItensQuery.Add('DELETE FROM NFC_PRO WHERE NP_NFC = :NFC');
    LDelItensQuery.AddParam('NFC', LNotaCodigo);
    LDelItensQuery.ExecSQL;

    if Assigned(LItens) then
    begin
      for i := 0 to LItens.Count - 1 do
      begin
        LItem := LItens.Items[i] as TJSONObject;

        LItemQuery := TDatabase.Query;
        LItemQuery.Clear;
        LItemQuery.Add('SELECT COALESCE(MAX(NP_CODIGO), 0) + 1 AS CODIGO FROM NFC_PRO');
        LItemQuery.Open;
        LItemCodigo := LItemQuery.DataSet.FieldByName('CODIGO').AsInteger;

        LAliqIcms := LItem.GetValue<Double>('aliq_icms', 0);
        LValorItem := LItem.GetValue<Currency>('valor_total', 0);

        LProdutoNum := StrToIntDef(LItem.GetValue<string>('codigo', '0'), 0);

        LItemQuery.Clear;
        LItemQuery.Add('INSERT INTO NFC_PRO ('+
                       'NP_CODIGO, NP_NFC, NP_PRO, NP_NOME, NP_QUANTIDADE, NP_VALOR, NP_CFOP, NP_CST_ICMS, NP_ALIQ_ICMS, NP_BC_ICMS)');
        LItemQuery.Add('VALUES ('+
                       ':CODIGO, :NFC, :PRO, :NOME, :QTD, :VALOR, :CFOP, :CST, :ALIQ, :BC)');
        LItemQuery.AddParam('CODIGO', LItemCodigo);
        LItemQuery.AddParam('NFC', LNotaCodigo);
        LItemQuery.AddParam('PRO', LProdutoNum);
        LItemQuery.AddParam('NOME', LItem.GetValue<string>('descricao', ''));
        LItemQuery.AddParam('QTD', LItem.GetValue<Double>('quantidade', 0));
        LItemQuery.AddParam('VALOR', LValorItem);
        LItemQuery.AddParam('CFOP', LItem.GetValue<string>('cfop', '5102'));
        LItemQuery.AddParam('CST', LItem.GetValue<string>('cst_icms', '102'));
        LItemQuery.AddParam('ALIQ', LAliqIcms);
        if LAliqIcms > 0 then
          LItemQuery.AddParam('BC', LValorItem)
        else
          LItemQuery.AddParam('BC', 0);
        LItemQuery.ExecSQL;
      end;
    end;
  end
  else
  begin
    LCabQuery := TDatabase.Query;
    LCabQuery.Clear;
    LCabQuery.Add('SELECT FIRST 1 NOT_CODIGO FROM NOTAS_FISCAIS WHERE NOT_CHAVE_NFE = :CHAVE');
    LCabQuery.AddParam('CHAVE', AResult.Chave);
    LCabQuery.Open;

    if not LCabQuery.DataSet.IsEmpty then
      LNotaCodigo := LCabQuery.DataSet.FieldByName('NOT_CODIGO').AsInteger
    else
    begin
      LCabQuery.Clear;
      LCabQuery.Add('SELECT COALESCE(MAX(NOT_CODIGO), 0) + 1 AS CODIGO FROM NOTAS_FISCAIS');
      LCabQuery.Open;
      LNotaCodigo := LCabQuery.DataSet.FieldByName('CODIGO').AsInteger;

      LCabQuery.Clear;
      LCabQuery.Add('INSERT INTO NOTAS_FISCAIS ('+
                    'NOT_CODIGO, NOT_DATA, NOT_DATA_ES, NOT_HORA, NOT_CFOP, NOT_NF, NOT_MODELO, NOT_SERIE, NOT_CHAVE_NFE, ' +
                    'NOT_SITUACAO_NFE, NOT_VALOR, NOT_DESCONTO, NOT_BCICMS, NOT_VICMS, NOT_VTPROD, NOT_NUM_RECIBO_NFE, NOT_PROT_AUT_NFE, ' +
                    'NOT_IND_EMISSAO, NOT_OPER_CONSUM_FINAL, NOT_OBS)');
      LCabQuery.Add('VALUES ('+
                    ':CODIGO, CURRENT_DATE, CURRENT_DATE, CURRENT_TIME, :CFOP, :NF, ''55'', :SERIE, :CHAVE, ' +
                    '''AUTORIZADA'', :VALOR, :DESCONTO, :BCICMS, :VICMS, :VTPROD, :RECIBO, :PROTOCOLO, ' +
                    '''P'', ''S'', :OBS)');
      LCabQuery.AddParam('CODIGO', LNotaCodigo);
      LCabQuery.AddParam('CFOP', LCFOPPrincipal);
      LCabQuery.AddParam('NF', ANumero);
      LCabQuery.AddParam('SERIE', ASerie);
      LCabQuery.AddParam('CHAVE', AResult.Chave);
      LCabQuery.AddParam('VALOR', LValorTotal);
      LCabQuery.AddParam('DESCONTO', LDescontoTotal);
      LCabQuery.AddParam('BCICMS', LBCIcms);
      LCabQuery.AddParam('VICMS', LVIcms);
      LCabQuery.AddParam('VTPROD', LValorProdutos);
      LCabQuery.AddParam('RECIBO', AResult.Protocolo);
      LCabQuery.AddParam('PROTOCOLO', AResult.Protocolo);
      LCabQuery.AddParam('OBS', AJSON.GetValue<string>('info_complementar', ''));
      LCabQuery.ExecSQL;
    end;

    LCabQuery.Clear;
    LCabQuery.Add('UPDATE NOTAS_FISCAIS SET ' +
                  'NOT_NF = :NF, NOT_SERIE = :SERIE, NOT_CFOP = :CFOP, ' +
                  'NOT_SITUACAO_NFE = ''AUTORIZADA'', NOT_NUM_RECIBO_NFE = :RECIBO, NOT_PROT_AUT_NFE = :PROTOCOLO, ' +
                  'NOT_VALOR = :VALOR, NOT_DESCONTO = :DESCONTO, NOT_BCICMS = :BCICMS, NOT_VICMS = :VICMS, NOT_VTPROD = :VTPROD, ' +
                  'NOT_OBS = :OBS ' +
                  'WHERE NOT_CODIGO = :CODIGO');
    LCabQuery.AddParam('NF', ANumero);
    LCabQuery.AddParam('SERIE', ASerie);
    LCabQuery.AddParam('CFOP', LCFOPPrincipal);
    LCabQuery.AddParam('RECIBO', AResult.Protocolo);
    LCabQuery.AddParam('PROTOCOLO', AResult.Protocolo);
    LCabQuery.AddParam('VALOR', LValorTotal);
    LCabQuery.AddParam('DESCONTO', LDescontoTotal);
    LCabQuery.AddParam('BCICMS', LBCIcms);
    LCabQuery.AddParam('VICMS', LVIcms);
    LCabQuery.AddParam('VTPROD', LValorProdutos);
    LCabQuery.AddParam('OBS', AJSON.GetValue<string>('info_complementar', ''));
    LCabQuery.AddParam('CODIGO', LNotaCodigo);
    LCabQuery.ExecSQL;

    LDelItensQuery := TDatabase.Query;
    LDelItensQuery.Clear;
    LDelItensQuery.Add('DELETE FROM NOT_ITENS WHERE NI_NOT = :NOTA');
    LDelItensQuery.AddParam('NOTA', LNotaCodigo);
    LDelItensQuery.ExecSQL;

    if Assigned(LItens) then
    begin
      for i := 0 to LItens.Count - 1 do
      begin
        LItem := LItens.Items[i] as TJSONObject;

        LItemQuery := TDatabase.Query;
        LItemQuery.Clear;
        LItemQuery.Add('SELECT COALESCE(MAX(NI_CODIGO), 0) + 1 AS CODIGO FROM NOT_ITENS');
        LItemQuery.Open;
        LItemCodigo := LItemQuery.DataSet.FieldByName('CODIGO').AsInteger;

        LAliqIcms := LItem.GetValue<Double>('aliq_icms', 0);
        LValorItem := LItem.GetValue<Currency>('valor_total', 0);
        LProdutoNum := StrToIntDef(LItem.GetValue<string>('codigo', '0'), 0);

        LItemQuery.Clear;
        LItemQuery.Add('INSERT INTO NOT_ITENS ('+
                       'NI_CODIGO, NI_NOT, NI_PRO, NI_NOME, NI_QUANTIDADE, NI_VALOR, NI_CFOP, NI_CST, NI_ALIQ_ICMS, NI_BCICMS, NI_VICMS, ' +
                       'NI_UNIDADE, NI_VDESC, NI_CST_PIS, NI_ALIQ_PIS, NI_CST_COFINS, NI_ALIQ_COFINS)');
        LItemQuery.Add('VALUES ('+
                       ':CODIGO, :NOTA, :PRO, :NOME, :QTD, :VALOR, :CFOP, :CST, :ALIQ, :BC, :VICMS, :UNID, :VDESC, :CSTPIS, :ALIQPIS, :CSTCOF, :ALIQCOF)');
        LItemQuery.AddParam('CODIGO', LItemCodigo);
        LItemQuery.AddParam('NOTA', LNotaCodigo);
        LItemQuery.AddParam('PRO', LProdutoNum);
        LItemQuery.AddParam('NOME', LItem.GetValue<string>('descricao', ''));
        LItemQuery.AddParam('QTD', LItem.GetValue<Double>('quantidade', 0));
        LItemQuery.AddParam('VALOR', LValorItem);
        LItemQuery.AddParam('CFOP', LItem.GetValue<string>('cfop', '5102'));
        LItemQuery.AddParam('CST', LItem.GetValue<string>('cst_icms', '102'));
        LItemQuery.AddParam('ALIQ', LAliqIcms);
        if LAliqIcms > 0 then
        begin
          LItemQuery.AddParam('BC', LValorItem);
          LItemQuery.AddParam('VICMS', (LValorItem * LAliqIcms) / 100);
        end
        else
        begin
          LItemQuery.AddParam('BC', 0);
          LItemQuery.AddParam('VICMS', 0);
        end;
        LItemQuery.AddParam('UNID', LItem.GetValue<string>('unidade', 'UN'));
        LItemQuery.AddParam('VDESC', LItem.GetValue<Currency>('desconto', 0));
        LItemQuery.AddParam('CSTPIS', LItem.GetValue<string>('cst_pis', '07'));
        LItemQuery.AddParam('ALIQPIS', LItem.GetValue<Double>('aliq_pis', 0));
        LItemQuery.AddParam('CSTCOF', LItem.GetValue<string>('cst_cofins', '07'));
        LItemQuery.AddParam('ALIQCOF', LItem.GetValue<Double>('aliq_cofins', 0));
        LItemQuery.ExecSQL;
      end;
    end;
  end;

  TLogger.Info('ACBr.Service.SalvarNotaEItens: modelo=%s chave=%s numero=%d codigo=%d', [AModelo, AResult.Chave, ANumero, LNotaCodigo]);
end;

// ============================================================
// CANCELAMENTO
// ============================================================
function TACBrNFeService.ExtrairDadosNFe(const Chave: string; out CNPJ, NumSerie, NumeroNF: string): Boolean;
begin
  Result := False;
  if Length(Chave) <> 44 then
    Exit; // chave inválida

  try
    // Estrutura da chave NFe:
    // 01-02: Código da UF
    // 03-06: Ano e mês de emissão
    // 07-20: CNPJ do emitente
    // 21-22: Modelo
    // 23-25: Série
    // 26-34: Número da NF
    // 35-43: Código numérico
    // 44: Dígito verificador

    CNPJ := Copy(Chave, 7, 14);
    NumSerie := Copy(Chave, 23, 3);
    NumeroNF := Copy(Chave, 26, 9);

    Result := True;
  except
    Result := False;
  end;
end;

function TACBrNFeService.Cancelar(const AChave, AProtocolo, AJustificativa: string): TResultadoEmissao;
var
  CancNFe: TInfEvento;
  NumeroLote: string;
  CNPJEmitente: string;
  SerieNF: string;
  NumeroNF: string;
begin
  Result.Sucesso := False;
  Result.Erro := '';

  if not FConfigurado then
  begin
    Result.Erro := 'ACBr não configurado';
    Exit;
  end;

  try
    ExtrairDadosNFe(AChave, CNPJEmitente, SerieNF, NumeroNF);
    ConfigurarGeral('NFe'); // modelo não importa para cancelamento
    FACBrNFe.EventoNFe.Evento.Clear;
    CancNFe := FACBrNFe.EventoNFe.Evento.New.InfEvento;
    CancNFe.chNFe := AChave;
    CancNFe.CNPJ := CNPJEmitente;
    CancNFe.detEvento.nProt := AProtocolo;
    CancNFe.detEvento.xJust := AJustificativa;
    NumeroLote := (SerieNF.ToInteger * 1000000).ToString + NumeroNF;
    FACBrNFe.EnviarEvento(NumeroLote.ToInteger());

    Result.CStat := FACBrNFe.WebServices.EnvEvento.CStat;
    Result.Motivo := FACBrNFe.WebServices.EnvEvento.XMotivo;
    // Result.Protocolo := FACBrNFe.WebServices.EnvEvento.EventoRetorno.xMotivo;
    Result.Sucesso := Result.CStat = 135;
    // 135 = Evento registrado e vinculado a NF-e

    if not Result.Sucesso then
      Result.Erro := Format('cStat=%d: %s', [Result.CStat, Result.Motivo]);

    TLogger.Info('ACBr.Service.Cancelar: chave=%s cStat=%d', [AChave, Result.CStat]);
  except
    on E: Exception do
    begin
      Result.Sucesso := False;
      Result.Erro := E.Message;
      TLogger.Error('ACBr.Service.Cancelar', E);
    end;
  end;
end;

// ============================================================
// CONSULTA STATUS SEFAZ
// ============================================================

// Extrai o valor de uma tag XML simples do XML bruto.
// Ex: ExtractXMLTag('<cStat>107</cStat>', 'cStat') → '107'
function ExtractXMLTag(const AXML, ATag: string): string;
var
  LMatch: TMatch;
begin
  Result := '';
  LMatch := TRegEx.Match(AXML, '<' + ATag + '[^>]*>([^<]+)</' + ATag + '>',
    [roIgnoreCase]);
  if LMatch.Success and (LMatch.Groups.Count > 1) then
    Result := Trim(LMatch.Groups[1].Value);
end;

function SanitizarXMLConteudo(const AXML: string): string;
var
  I: Integer;
  LChar: Char;
  LDeclEnd: Integer;
  LPosTag: Integer;
  LAposDecl: string;
begin
  Result := AXML;

  if Result.IsEmpty then
    Exit;

  // Remove BOM e nulos que podem vir do banco/blob e quebrar o parser XML.
  Result := Result.Replace(#$FEFF, '');
  Result := Result.Replace(#0, '');

  // Mantém apenas caracteres válidos para XML texto (TAB, CR, LF e >= #32).
  LAposDecl := '';
  SetLength(LAposDecl, Length(Result));
  LPosTag := 0;
  for I := 1 to Length(Result) do
  begin
    LChar := Result[I];
    if (Ord(LChar) >= 32) or (LChar = #9) or (LChar = #10) or (LChar = #13) then
    begin
      Inc(LPosTag);
      LAposDecl[LPosTag] := LChar;
    end;
  end;
  SetLength(LAposDecl, LPosTag);
  Result := LAposDecl;

  // Garante que não existam bytes/lixo entre a declaração XML e a tag raiz.
  LDeclEnd := Pos('?>', Result);
  if LDeclEnd > 0 then
  begin
    LAposDecl := Copy(Result, LDeclEnd + 2, MaxInt);
    while (not LAposDecl.IsEmpty) and (LAposDecl[1] <> '<') do
      Delete(LAposDecl, 1, 1);
    Result := Copy(Result, 1, LDeclEnd + 2) + LAposDecl;
  end;

  // Remove qualquer lixo antes da primeira tag.
  LPosTag := Pos('<', Result);
  if LPosTag > 1 then
    Delete(Result, 1, LPosTag - 1)
  else if LPosTag = 0 then
    Result := '';
end;

function TACBrNFeService.ConsultarStatusSefaz(const AUF: string; AModelo: Integer): TResultadoEmissao;
var
  LRetornoXML: string;
  LCStat: string;
  LXMotivo: string;
begin
  Result.Sucesso := False;
  Result.Erro    := '';
  Result.CStat   := 0;
  Result.Motivo  := '';

  try
    if AModelo = 65 then
      ConfigurarGeral('NFCe')
    else
      ConfigurarGeral('NFe');

    if not AUF.IsEmpty then
      FACBrNFe.Configuracoes.WebServices.UF := AUF;

    TLogger.Debug('ACBr.Service.ConsultarStatusSefaz - Config: UF=%s Ambiente=%d Schemas=%s XmlDir=%s',
      [FACBrNFe.Configuracoes.WebServices.UF,
       Integer(FACBrNFe.Configuracoes.WebServices.Ambiente),
       TAppConfig.AcbrSchemas,
       TAppConfig.AcbrXmlDir]);

    try
      FACBrNFe.WebServices.StatusServico.Executar;
    except
      on E: Exception do
      begin
        TLogger.Error('ACBr.Service.ConsultarStatusSefaz - Exception em StatusServico: %s', [E.ToString]);
        Result.Erro := E.Message;
        Exit;
      end;
    end;

    // --- Tentar via propriedades do componente ACBr (caminho normal) ---
    Result.CStat  := FACBrNFe.WebServices.StatusServico.CStat;
    Result.Motivo := FACBrNFe.WebServices.StatusServico.XMotivo;

    // --- Fallback: extrair diretamente do XML bruto quando ACBr retorna 0 ---
    // Isso acontece quando o namespace do envelope SOAP não bate com o esperado
    // pelo parser interno do ACBr (ex: NFeStatusServico4 vs NfeStatusServico4).
    if Result.CStat = 0 then
    begin
      LRetornoXML := FACBrNFe.WebServices.StatusServico.RetornoWS;

      TLogger.Debug('ACBr.Service.ConsultarStatusSefaz - RetornoXML bruto (0..800): %s',
        [Copy(LRetornoXML, 1, 800)]);

      if not LRetornoXML.IsEmpty then
      begin
        LCStat   := ExtractXMLTag(LRetornoXML, 'cStat');
        LXMotivo := ExtractXMLTag(LRetornoXML, 'xMotivo');

        if not LCStat.IsEmpty then
        begin
          TryStrToInt(LCStat, Result.CStat);
          Result.Motivo := LXMotivo;
          TLogger.Info('ACBr.Service.ConsultarStatusSefaz - cStat extraído do XML: %d (%s)',
            [Result.CStat, Result.Motivo]);
        end
        else
          TLogger.Error('ACBr.Service.ConsultarStatusSefaz - cStat não encontrado no XML bruto');
      end
      else
        TLogger.Error('ACBr.Service.ConsultarStatusSefaz - RetornoWS vazio após Executar');
    end
    else
      TLogger.Info('ACBr.Service.ConsultarStatusSefaz - CStat via ACBr: %d (%s)',
        [Result.CStat, Result.Motivo]);

    Result.Sucesso := Result.CStat = 107; // 107 = Serviço em Operação

    if not Result.Sucesso then
      Result.Erro := Format('cStat=%d: %s', [Result.CStat, Result.Motivo]);

  except
    on E: Exception do
    begin
      Result.Sucesso := False;
      Result.Erro    := E.Message;
      TLogger.Error('ACBr.Service.ConsultarStatusSefaz', E);
    end;
  end;
end;

function TACBrNFeService.ConsultarNFe(const AChave: string): TResultadoEmissao;
begin
  Result.Sucesso := False;
  Result.Erro := '';

  if not FConfigurado then
  begin
    Result.Erro := 'ACBr não configurado';
    Exit;
  end;

  try
    ConfigurarGeral('NFe');
    FACBrNFe.WebServices.Consulta.NFeChave := AChave;
    FACBrNFe.WebServices.Consulta.Executar;

    Result.CStat := FACBrNFe.WebServices.Consulta.CStat;
    Result.Motivo := FACBrNFe.WebServices.Consulta.XMotivo;
    Result.Protocolo := FACBrNFe.WebServices.Consulta.Protocolo;
    Result.Chave := AChave;
    Result.Sucesso := Result.CStat = 100;
  except
    on E: Exception do
    begin
      Result.Sucesso := False;
      Result.Erro := E.Message;
      TLogger.Error('ACBr.Service.ConsultarNFe', E);
    end;
  end;
end;

function TACBrNFeService.InutilizarNumeros(const ACNPJ, AJustificativa, ASerie: string; ANNFIni, ANNFFin: Integer): TResultadoEmissao;
begin
  Result.Sucesso := False;
  Result.Erro := '';

  if not FConfigurado then
  begin
    Result.Erro := 'ACBr não configurado';
    Exit;
  end;

  try
    ConfigurarGeral('NFe');
    with FACBrNFe.WebServices.Inutilizacao do
    begin
      serie := ASerie.ToInteger;
      NumeroInicial := ANNFIni;
      NumeroFinal := ANNFFin;
      Justificativa := AJustificativa;
      Executar;
      Result.CStat := CStat;
      Result.Motivo := XMotivo;
      Result.Sucesso := CStat = 102; // 102 = Inutilização de número homologado
    end;
  except
    on E: Exception do
    begin
      Result.Sucesso := False;
      Result.Erro := E.Message;
      TLogger.Error('ACBr.Service.InutilizarNumeros', E);
    end;
  end;
end;

// ============================================================
// DANFE / XML
// ============================================================

// Resolve o XML da NFe/NFCe:
//   1. Tenta /tmp/nfe/<chave>-nfe.xml (cache da mesma sessão)
//   2. Busca no banco (NOT_XML_NFE / NFC_XML_NFCE)
//   3. Devolve '' se não encontrar
function TACBrNFeService.ObterXML(const AChave: string): string;
var
  LTmpPath: string;
  LTmpPathLegacy: string;
  LQuery  : iQuery;
  LTabela, LColXML, LColChave: string;
  LTipo: string;
begin
  Result := '';

  // 1. Cache /tmp (disponível na mesma instância Cloud Run)
  LTipo := DetectarTipoDocumento(AChave);
  LTmpPath := TPath.Combine('/tmp/nfe', AChave + '-' + LTipo + '.xml');
  LTmpPathLegacy := TPath.Combine('/tmp/nfe', AChave + '-nfe.xml');
  if TFile.Exists(LTmpPath) then
  begin
    Result := SanitizarXMLConteudo(TFile.ReadAllText(LTmpPath, TEncoding.UTF8));
    Exit;
  end;
  if TFile.Exists(LTmpPathLegacy) then
  begin
    Result := SanitizarXMLConteudo(TFile.ReadAllText(LTmpPathLegacy, TEncoding.UTF8));
    Exit;
  end;

  // 2. Banco de dados — fonte definitiva
  // Detecta modelo pelo tamanho da chave (44 dígitos) e posição 21-22 (55=NFe, 65=NFCe)
  if (Length(AChave) = 44) and (Copy(AChave, 21, 2) = '65') then
  begin
    LTabela  := 'NFC';
    LColXML  := 'NFC_XML_NFCE';
    LColChave := 'NFC_CHAVE_NFCE';
  end
  else
  begin
    LTabela  := 'NOTAS_FISCAIS';
    LColXML  := 'NOT_XML_NFE';
    LColChave := 'NOT_CHAVE_NFE';
  end;

  try
    LQuery := TDatabase.Query;
    LQuery.Clear;
    LQuery.Add('SELECT ' + LColXML + ' FROM ' + LTabela);
    LQuery.Add(' WHERE ' + LColChave + ' = :CHAVE');
    LQuery.AddParam('CHAVE', AChave);
    LQuery.Open;
    if not LQuery.DataSet.IsEmpty then
      Result := SanitizarXMLConteudo(LQuery.DataSet.Fields[0].AsString);
  except
    on E: Exception do
      TLogger.Error('ACBr.Service.ObterXML: %s', [E.Message]);
  end;
end;

function TACBrNFeService.GerarDANFe(const AChave: string): string;
var
  LXMLContent: string;
  LTmpDir    : string;
  LXMLPath   : string;
  LPDFPath   : string;
  LPDFGerado : string;
  LPDFSize   : Int64;
  LTipo      : string;
  LFileStream: TFileStream;
begin
  Result := '';

  // Resolve o XML (cache /tmp ou banco)
  LXMLContent := SanitizarXMLConteudo(ObterXML(AChave));
  if LXMLContent.IsEmpty then
  begin
    TLogger.Warn('ACBr.Service.GerarDANFe: XML não encontrado para chave %s', [AChave]);
    Exit;
  end;

  // Grava em /tmp e carrega do arquivo para evitar problemas de encoding no Linux.
  LTipo := DetectarTipoDocumento(AChave);
  LTmpDir  := '/tmp/nfe';
  LXMLPath := TPath.Combine(LTmpDir, AChave + '-' + LTipo + '.xml');
  LPDFPath := TPath.Combine(LTmpDir, AChave + '-danfe.pdf');

  try
    if not TDirectory.Exists(LTmpDir) then
      TDirectory.CreateDirectory(LTmpDir);

    if TFile.Exists(LPDFPath) then
      TFile.Delete(LPDFPath);

    TFile.WriteAllBytes(LXMLPath, TEncoding.UTF8.GetBytes(LXMLContent));

    PrepararDANFE(LTipo);

    if not Assigned(FACBrNFe.DANFE) then
    begin
      TLogger.Error('ACBr.Service.GerarDANFe: componente DANFE não inicializado para tipo %s', [LTipo]);
      Exit;
    end;

    FACBrNFe.NotasFiscais.Clear;
    FACBrNFe.DANFE.NomeDocumento := LPDFPath;
    FACBrNFe.NotasFiscais.LoadFromFile(LXMLPath);
    FACBrNFe.NotasFiscais.ImprimirPDF;

    LPDFGerado := '';
    LPDFSize := 0;

    if TFile.Exists(LPDFPath) then
    begin
      LFileStream := TFileStream.Create(LPDFPath, fmOpenRead or fmShareDenyWrite);
      try
        LPDFSize := LFileStream.Size;
      finally
        LFileStream.Free;
      end;
      if LPDFSize > 0 then
        LPDFGerado := LPDFPath;
    end
    else if (not FACBrNFe.DANFE.ArquivoPDF.IsEmpty) and TFile.Exists(FACBrNFe.DANFE.ArquivoPDF) then
    begin
      LFileStream := TFileStream.Create(FACBrNFe.DANFE.ArquivoPDF, fmOpenRead or fmShareDenyWrite);
      try
        LPDFSize := LFileStream.Size;
      finally
        LFileStream.Free;
      end;
      if LPDFSize > 0 then
        LPDFGerado := FACBrNFe.DANFE.ArquivoPDF;
    end;

    if LPDFGerado.IsEmpty then
    begin
      TLogger.Error('ACBr.Service.GerarDANFe: PDF não gerado ou vazio para chave %s', [AChave]);
      Exit;
    end;

    Result := LPDFGerado;
    SalvarDANFE(AChave, Result);

    TLogger.Info('ACBr.Service.GerarDANFe: PDF gerado em %s (%d bytes)', [Result, LPDFSize]);
  except
    on E: Exception do
      TLogger.Error('ACBr.Service.GerarDANFe: %s', [E.Message]);
  end;
end;

procedure TACBrNFeService.SalvarDANFE(const AChave, APDFPath: string);
var
  LQuery: iQuery;
  LPDFBase64: string;
  LTabela: string;
  LColDANFE: string;
  LColChave: string;
begin
  if AChave.IsEmpty or APDFPath.IsEmpty or (not TFile.Exists(APDFPath)) then
    Exit;

  if DetectarTipoDocumento(AChave) = 'nfce' then
  begin
    LTabela := 'NFC';
    LColDANFE := 'NFC_DANFE';
    LColChave := 'NFC_CHAVE_NFCE';
  end
  else
  begin
    LTabela := 'NOTAS_FISCAIS';
    LColDANFE := 'NOT_DANFE';
    LColChave := 'NOT_CHAVE_NFE';
  end;

  try
    LPDFBase64 := TNetEncoding.Base64.EncodeBytesToString(TFile.ReadAllBytes(APDFPath));

    LQuery := TDatabase.Query;
    LQuery.Clear;
    LQuery.Add('UPDATE ' + LTabela);
    LQuery.Add('   SET ' + LColDANFE + ' = :DANFE');
    LQuery.Add(' WHERE ' + LColChave + ' = :CHAVE');
    LQuery.AddParam('CHAVE', AChave);
    LQuery.AddParam('DANFE', LPDFBase64);
    LQuery.ExecSQL;

    TLogger.Info('ACBr.Service.SalvarDANFE: DANFE salvo no banco (chave=%s)', [AChave]);
  except
    on E: Exception do
      TLogger.Warn('ACBr.Service.SalvarDANFE: %s', [E.Message]);
  end;
end;


procedure TACBrNFeService.SalvarXML(const AChave, AConteudo, ATipo: string);
var
  LXML: string;
  LTmpDir : string;
  LTmpPath: string;
  LTabela : string;
  LColXML : string;
  LColChave: string;
  LQuery  : iQuery;
begin
  if AChave.IsEmpty or AConteudo.IsEmpty then
    Exit;
  TLogger.Info('ACBr.Service.SalvarXML: %s', [AConteudo]);
  LXML := AConteudo;
  if LXML.IsEmpty then
  begin
    TLogger.Warn('ACBr.Service.SalvarXML: conteúdo XML inválido após sanitização (chave=%s)', [AChave]);
    Exit;
  end;

  // ------------------------------------------------------------------
  // 1. Persiste no banco de dados (Firebird) — armazenamento definitivo.
  //    No Cloud Run o filesystem é efêmero; o banco é o único storage
  //    permanente sem custo adicional.
  //
  //    Estrutura esperada:
  //      NOTAS_FISCAIS.NOT_XML_NFE  BLOB SUB_TYPE 1  (NFe modelo 55)
  //      NFC.NFC_XML_NFCE           BLOB SUB_TYPE 1  (NFCe modelo 65)
  //
  //    Script de migração: dist/scripts/migrate-add-xml-blob.sql
  // ------------------------------------------------------------------
  if ATipo = 'nfe' then
  begin
    LTabela  := 'NOTAS_FISCAIS';
    LColXML  := 'NOT_XML_NFE';
    LColChave := 'NOT_CHAVE_NFE';
  end
  else
  begin
    LTabela  := 'NFC';
    LColXML  := 'NFC_XML_NFCE';
    LColChave := 'NFC_CHAVE_NFCE';
  end;

  try
    LQuery := TDatabase.Query;
    LQuery.Clear;
    LQuery.Add('UPDATE ' + LTabela);
    LQuery.Add('   SET ' + LColXML + ' = :XML');
    LQuery.Add(' WHERE ' + LColChave + ' = :CHAVE');
    LQuery.AddParam('CHAVE', AChave);
    LQuery.AddParam('XML',   LXML);
    LQuery.ExecSQL;
    TLogger.Info('ACBr.Service.SalvarXML: XML da %s gravado no banco (chave=%s)', [ATipo, AChave]);
  except
    on E: Exception do
      TLogger.Error('ACBr.Service.SalvarXML - banco: %s', [E.Message]);
      // Não re-raise: falha no save não deve cancelar a nota já autorizada
  end;

  // ------------------------------------------------------------------
  // 2. Cópia temporária em /tmp — usada apenas para gerar o DANFE na
  //    mesma requisição. O arquivo some quando a instância Cloud Run
  //    escala para zero, mas o XML original já está no banco.
  // ------------------------------------------------------------------
  try
    LTmpDir := TPath.Combine('/tmp', 'nfe');
    if not TDirectory.Exists(LTmpDir) then
      TDirectory.CreateDirectory(LTmpDir);
    LTmpPath := TPath.Combine(LTmpDir, AChave + '-' + ATipo + '.xml');
    TFile.WriteAllText(LTmpPath, LXML, TEncoding.UTF8);
    TLogger.Debug('ACBr.Service.SalvarXML: cópia temporária em %s', [LTmpPath]);
  except
    on E: Exception do
      TLogger.Warn('ACBr.Service.SalvarXML - /tmp: %s (ignorado)', [E.Message]);
  end;
end;

end.
