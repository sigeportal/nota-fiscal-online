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
	System.IOUtils,
	System.DateUtils,
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
		FACBrNFe    : TACBrNFe;
		FConfigurado: Boolean;
		FCNPJ       : string;
		FUsuarioId  : Integer;
		FConfig     : TModelConfiguracaoUsuario;

		procedure ConfigurarGeral(AModeloDF: string);
		function CarregarCertificado(const ACNPJ: string): Boolean;
		function ProximoNumeroNF(const ATabela, ACampoNF, ACampoCodigo, ASerie: string): Integer;

		function MontarNFe(AJSON: TJSONObject; ANumero: Integer): Boolean;
		function MontarNFCe(AJSON: TJSONObject; ANumero: Integer): Boolean;
		procedure AdicionarItensNFe(AJSON: TJSONObject);
		procedure AdicionarItensNFCe(AJSON: TJSONObject);
		procedure AdicionarPagamentos(AJSON: TJSONObject);

		function ExecutarEnvio(ALote: string): TResultadoEmissao;
		procedure SalvarXML(const AChave, AConteudo, ATipo: string);
    function ExtrairDadosNFe(const chave: string; out CNPJ, NumSerie,
      NumeroNF: string): Boolean;

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
	ACBrNFe.EventoClass,
  ACBrNFeDANFEClass;

{ TACBrNFeService }

constructor TACBrNFeService.Create;
begin
	inherited Create;
	FACBrNFe     := TACBrNFe.Create(nil);
	FConfigurado := False;
	FUsuarioId   := 0;
	FConfig      := nil;
end;

destructor TACBrNFeService.Destroy;
begin
	FreeAndNil(FACBrNFe);
	FreeAndNil(FConfig);
	inherited Destroy;
end;

function TACBrNFeService.Configurar(const ACNPJ: string; AUsuarioId: Integer = 0): Boolean;
begin
	FCNPJ      := ACNPJ;
	FUsuarioId := AUsuarioId;
	Result     := False;
	try
		// Carrega configurações por usuário (RespTec, NFCe CSC, etc.)
		FreeAndNil(FConfig);
		if FUsuarioId > 0 then
		begin
			FConfig := TModelConfiguracaoUsuario.Create(TDatabase.Connection);
			FConfig.BuscaPorCampo('CFG_USU', FUsuarioId);
			if FConfig.Codigo = 0 then
				FreeAndNil(FConfig); // usuário sem configuração ainda — sem dados de RespTec
		end;

		// Carrega o certificado do banco antes de configurar
		if not CarregarCertificado(ACNPJ) then
		begin
			TLogger.Error('ACBr.Service: Certificado não encontrado para CNPJ %s', [ACNPJ]);
			Exit;
		end;
		FConfigurado := True;
		Result       := True;
		TLogger.Info('ACBr.Service: Configurado com sucesso para CNPJ %s', [ACNPJ]);
	except
		on E: Exception do
		begin
			TLogger.Error('ACBr.Service: Erro ao configurar', E);
			raise;
		end;
	end;
end;

procedure TACBrNFeService.ConfigurarGeral(AModeloDF: string);
begin
	with FACBrNFe.Configuracoes do
	begin
		Geral.ValidarDigest    := False;
		WebServices.SSLType    := LT_TLSv1_2;
		WebServices.Tentativas := 5;
		WebServices.TimeOut    := 5000;
		Geral.VersaoQRCode     := veqr200;
		Geral.VersaoDF         := ve400;

		if AModeloDF = 'NFCe' then
		begin
			Geral.ModeloDF := moNFCe;
			if Assigned(FConfig) then
			begin
				Geral.IdCSC := FConfig.NFCeIdCSC;
				Geral.CSC   := FConfig.NFCeCSC;
			end;
		end
		else
			Geral.ModeloDF := moNFe;

		WebServices.UF       := TAppConfig.UF;
		WebServices.Ambiente := taHomologacao; // será substituído pelo JSON

		Arquivos.PathSchemas := TAppConfig.AcbrSchemas;
		Arquivos.PathSalvar  := TAppConfig.AcbrXmlDir;

		// OpenSSL para PFX (não requer SP2 do Windows)
		Geral.SSLLib        := libOpenSSL;
		Geral.SSLCryptLib   := cryOpenSSL;
		Geral.SSLHttpLib    := httpOpenSSL;
		Geral.SSLXmlSignLib := xsLibXml2;
	end;
end;

function TACBrNFeService.CarregarCertificado(const ACNPJ: string): Boolean;
var
	LQuery  : iQuery;
	LDados  : TBytes;
	LSenha  : string;
	LStream : TMemoryStream;
	LCNPJNum: string;
	LTmpFile: string;
begin
	Result   := False;
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
		Exit;

	LSenha := LQuery.DataSet.FieldByName('CER_SENHA_CLARA').AsString;

	// Lê o BLOB do certificado para um Stream
	LStream := TMemoryStream.Create;
	try
		TBlobField(LQuery.DataSet.FieldByName('CER_DADOS')).SaveToStream(LStream);
		LStream.Position := 0;
		SetLength(LDados, LStream.Size);
		LStream.ReadBuffer(LDados[0], LStream.Size);
	finally
		LStream.Free;
	end;

	if Length(LDados) = 0 then
		Exit;

	// Salva o PFX em arquivo temporário para o ACBr carregar
	LTmpFile := TPath.GetTempFileName + '.pfx';
	try
		TFile.WriteAllBytes(LTmpFile, LDados);

		FACBrNFe.Configuracoes.Certificados.ArquivoPFX  := LTmpFile;
		FACBrNFe.Configuracoes.Certificados.Senha       := LSenha;
		FACBrNFe.Configuracoes.Certificados.NumeroSerie := '';

		Result := True;
	except
		on E: Exception do
		begin
			if TFile.Exists(LTmpFile) then
				TFile.Delete(LTmpFile);
			raise;
		end;
	end;
end;

function TACBrNFeService.ProximoNumeroNF(const ATabela, ACampoNF, ACampoCodigo, ASerie: string): Integer;
var
	LQuery: iQuery;
begin
	Result := 1;
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
	if not LQuery.DataSet.IsEmpty then
		Result := LQuery.DataSet.Fields[0].AsInteger + 1;
end;

// ============================================================
// EMISSÃO NFe (modelo 55)
// ============================================================

function TACBrNFeService.EmitirNFe(AJSON: TJSONObject): TResultadoEmissao;
var
	LNumero  : Integer;
	LSerie   : string;
	LAmbiente: string;
	LLote    : string;
begin
	Result.Sucesso := False;
	Result.Erro    := '';

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

		LSerie  := AJSON.GetValue<string>('serie', '1');
		LNumero := ProximoNumeroNF('NOTAS_FISCAIS', 'NOT_NF', 'NOT', LSerie);

		FACBrNFe.NotasFiscais.Clear;
		if not MontarNFe(AJSON, LNumero) then
		begin
			Result.Erro := 'Erro ao montar XML da NFe';
			Exit;
		end;

		FACBrNFe.NotasFiscais.GerarNFe;

		LLote  := LSerie + IntToStr(LNumero);
		Result := ExecutarEnvio(LLote);
	except
		on E: Exception do
		begin
			Result.Sucesso := False;
			Result.Erro    := E.Message;
			TLogger.Error('ACBr.Service.EmitirNFe', E);
		end;
	end;
end;

function TACBrNFeService.MontarNFe(AJSON: TJSONObject; ANumero: Integer): Boolean;
var
	LNFe    : TNFe;
	LEmitEnd: TJSONObject;
	LDest   : TJSONObject;
	LDestEnd: TJSONObject;
begin
	Result := False;
	try
		with FACBrNFe.NotasFiscais.Add do
		begin
			LNFe := NFe;

			// Identificação
			LNFe.Ide.cNF      := StrToInt(Format('%08d', [Random(99999999)]));
			LNFe.Ide.natOp    := AJSON.GetValue<string>('natureza_operacao', 'VENDA DE MERCADORIAS');
			LNFe.Ide.modelo   := 55;
			LNFe.Ide.serie    := AJSON.GetValue<Integer>('serie', 1);
			LNFe.Ide.nNF      := ANumero;
			LNFe.Ide.tpNF     := tnSaida;
			LNFe.Ide.indFinal := TpcnConsumidorFinal(AJSON.GetValue<Integer>('consumidor_final', 1));
			LNFe.Ide.indPres  := TpcnPresencaComprador(AJSON.GetValue<Integer>('indicador_presenca', 1));
			LNFe.Ide.tpAmb    := TACBrTipoAmbiente(AJSON.GetValue<Integer>('ambiente', 2));

			// Responsável Técnico (por usuário, via CONFIGURACOES_USUARIO)
			if Assigned(FConfig) and not FConfig.RespCNPJ.IsEmpty then
			begin
				LNFe.infRespTec.CNPJ     := FConfig.RespCNPJ;
				LNFe.infRespTec.xContato := FConfig.RespContato;
				LNFe.infRespTec.email    := FConfig.RespEmail;
				LNFe.infRespTec.fone     := FConfig.RespFone;
			end;

			// Emitente - lido do banco pelo CNPJ
			LNFe.Emit.CNPJCPF := FCNPJ;
			LNFe.Emit.xNome   := AJSON.GetValue<string>('emit_razao_social', '');
			LNFe.Emit.xFant   := AJSON.GetValue<string>('emit_nome_fantasia', '');
			LNFe.Emit.IE      := AJSON.GetValue<string>('emit_ie', '');
			LNFe.Emit.CRT     := TpcnCRT(AJSON.GetValue<Integer>('emit_crt', 3));

			// Endereço emitente
			LEmitEnd := AJSON.GetValue<TJSONObject>('emit_endereco');
			if Assigned(LEmitEnd) then
			begin
				LNFe.Emit.EnderEmit.xLgr    := LEmitEnd.GetValue<string>('logradouro', '');
				LNFe.Emit.EnderEmit.nro     := LEmitEnd.GetValue<string>('numero', 'SN');
				LNFe.Emit.EnderEmit.xBairro := LEmitEnd.GetValue<string>('bairro', '');
				LNFe.Emit.EnderEmit.xMun    := LEmitEnd.GetValue<string>('municipio', '');
				LNFe.Emit.EnderEmit.UF      := LEmitEnd.GetValue<string>('uf', TAppConfig.UF);
				LNFe.Emit.EnderEmit.CEP     := StrToInt(LEmitEnd.GetValue<string>('cep', '0'));
				LNFe.Emit.EnderEmit.cMun    := LEmitEnd.GetValue<Integer>('codigo_municipio', 0);
			end;

			// Destinatário
			LDest := AJSON.GetValue<TJSONObject>('destinatario');
			if Assigned(LDest) then
			begin
				LNFe.Dest.CNPJCPF := LDest.GetValue<string>('cnpj', '');
				if LNFe.Dest.CNPJCPF.IsEmpty then
					LNFe.Dest.CNPJCPF := LDest.GetValue<string>('cpf', '');
				LNFe.Dest.xNome     := LDest.GetValue<string>('nome', '');
				LNFe.Dest.IE        := LDest.GetValue<string>('ie', '');
				LNFe.Dest.email     := LDest.GetValue<string>('email', '');
				LDestEnd            := LDest.GetValue<TJSONObject>('endereco');
				if Assigned(LDestEnd) then
				begin
					LNFe.Dest.EnderDest.xLgr    := LDestEnd.GetValue<string>('logradouro', '');
					LNFe.Dest.EnderDest.nro     := LDestEnd.GetValue<string>('numero', 'SN');
					LNFe.Dest.EnderDest.xBairro := LDestEnd.GetValue<string>('bairro', '');
					LNFe.Dest.EnderDest.xMun    := LDestEnd.GetValue<string>('municipio', '');
					LNFe.Dest.EnderDest.UF      := LDestEnd.GetValue<string>('uf', '');
					LNFe.Dest.EnderDest.CEP     := StrToInt(LDestEnd.GetValue<string>('cep', '0'));
					LNFe.Dest.EnderDest.cMun    := LDestEnd.GetValue<Integer>('codigo_municipio', 0);
				end;
			end;

			// Itens
			AdicionarItensNFe(AJSON);

			// Totais (calculados automaticamente pelo ACBr ao GerarNFe)

			// Pagamentos
			AdicionarPagamentos(AJSON);

			// Informações adicionais
			LNFe.InfAdic.infCpl     := AJSON.GetValue<string>('info_complementar', '');
			LNFe.InfAdic.infAdFisco := AJSON.GetValue<string>('info_fisco', '');
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
	LItens   : TJSONArray;
	LItem    : TJSONObject;
	I        : Integer;
	LDet     : TDetCollectionItem;
	LAliqICMS: double;
	LCST     : TCSTIcms;
begin
	LItens := AJSON.GetValue<TJSONArray>('itens');
	if not Assigned(LItens) then
		Exit;

	for I := 0 to LItens.Count - 1 do
	begin
		LItem := LItens.Items[I] as TJSONObject;
		LDet  := FACBrNFe.NotasFiscais.Items[0].NFe.Det.New;

		LDet.Prod.nItem   := I + 1;
		LDet.Prod.cProd   := LItem.GetValue<string>('codigo', IntToStr(I + 1));
		LDet.Prod.cEAN    := LItem.GetValue<string>('ean', 'SEM GTIN');
		LDet.Prod.xProd   := LItem.GetValue<string>('descricao', '');
		LDet.Prod.NCM     := LItem.GetValue<string>('ncm', '');
		LDet.Prod.CFOP    := LItem.GetValue<string>('cfop', '5102');
		LDet.Prod.uCom    := LItem.GetValue<string>('unidade', 'UN');
		LDet.Prod.qCom    := LItem.GetValue<double>('quantidade', 1);
		LDet.Prod.vUnCom  := LItem.GetValue<double>('valor_unitario', 0);
		LDet.Prod.vProd   := LItem.GetValue<double>('valor_total', 0);
		LDet.Prod.uTrib   := LItem.GetValue<string>('unidade', 'UN');
		LDet.Prod.qTrib   := LItem.GetValue<double>('quantidade', 1);
		LDet.Prod.vUnTrib := LItem.GetValue<double>('valor_unitario', 0);
		LDet.Prod.vDesc   := LItem.GetValue<double>('desconto', 0);
		LDet.Prod.indTot  := itSomaTotalNFe;
		LDet.Prod.CEST    := LItem.GetValue<string>('cest', '');

		// ICMS
		LAliqICMS              := LItem.GetValue<double>('aliq_icms', 0);
		LCST                   := StrToCSTICMS(LItem.GetValue<string>('cst_icms', '102'));
		LDet.Imposto.ICMS.orig := TOrigemMercadoria.oeNacional;
		LDet.Imposto.ICMS.CST  := LCST;
		if LAliqICMS > 0 then
		begin
			LDet.Imposto.ICMS.modBC := TpcnDeterminacaoBaseIcms.dbiMargemValorAgregado;
			LDet.Imposto.ICMS.vBC   := LDet.Prod.vProd;
			LDet.Imposto.ICMS.pICMS := LAliqICMS;
			LDet.Imposto.ICMS.vICMS := (LDet.Prod.vProd * LAliqICMS) / 100;
		end;

		// PIS
		LDet.Imposto.PIS.CST  := StrToCSTPIS(LItem.GetValue<string>('cst_pis', '07'));
		LDet.Imposto.PIS.vBC  := 0;
		LDet.Imposto.PIS.pPIS := LItem.GetValue<double>('aliq_pis', 0);
		LDet.Imposto.PIS.vPIS := 0;

		// COFINS
		LDet.Imposto.COFINS.CST     := StrToCSTCOFINS(LItem.GetValue<string>('cst_cofins', '07'));
		LDet.Imposto.COFINS.vBC     := 0;
		LDet.Imposto.COFINS.pCOFINS := LItem.GetValue<double>('aliq_cofins', 0);
		LDet.Imposto.COFINS.vCOFINS := 0;
	end;
end;

// ============================================================
// EMISSÃO NFCe (modelo 65)
// ============================================================

function TACBrNFeService.EmitirNFCe(AJSON: TJSONObject): TResultadoEmissao;
var
	LNumero  : Integer;
	LSerie   : string;
	LAmbiente: string;
	LLote    : string;
begin
	Result.Sucesso := False;
	Result.Erro    := '';

	if not FConfigurado then
	begin
		Result.Erro := 'ACBr não configurado. Chame Configurar(CNPJ) antes.';
		Exit;
	end;

	try
		ConfigurarGeral('NFCe');

		LAmbiente := AJSON.GetValue<string>('ambiente', '2');
		if LAmbiente = '1' then
			FACBrNFe.Configuracoes.WebServices.Ambiente := taProducao
		else
			FACBrNFe.Configuracoes.WebServices.Ambiente := taHomologacao;

		LSerie  := AJSON.GetValue<string>('serie', '1');
		LNumero := ProximoNumeroNF('NFC', 'NFC_NF', 'NFC', LSerie);

		FACBrNFe.NotasFiscais.Clear;
		if not MontarNFCe(AJSON, LNumero) then
		begin
			Result.Erro := 'Erro ao montar XML da NFCe';
			Exit;
		end;

		FACBrNFe.NotasFiscais.GerarNFe;

		LLote  := LSerie + IntToStr(LNumero);
		Result := ExecutarEnvio(LLote);
	except
		on E: Exception do
		begin
			Result.Sucesso := False;
			Result.Erro    := E.Message;
			TLogger.Error('ACBr.Service.EmitirNFCe', E);
		end;
	end;
end;

function TACBrNFeService.MontarNFCe(AJSON: TJSONObject; ANumero: Integer): Boolean;
var
	LNFe    : TNFe;
	LEmitEnd: TJSONObject;
	LCPF    : string;
begin
	Result := False;
	try
		with FACBrNFe.NotasFiscais.Add do
		begin
			LNFe := NFe;

			// Identificação
			LNFe.Ide.cNF      := StrToInt(Format('%08d', [Random(99999999)]));
			LNFe.Ide.natOp    := AJSON.GetValue<string>('natureza_operacao', 'VENDA A CONSUMIDOR');
			LNFe.Ide.modelo   := 65;
			LNFe.Ide.serie    := AJSON.GetValue<Integer>('serie', 1);
			LNFe.Ide.nNF      := ANumero;
			LNFe.Ide.tpNF     := tnSaida;
			LNFe.Ide.indFinal := TpcnConsumidorFinal.cfConsumidorFinal; // sempre consumidor final na NFCe
			LNFe.Ide.indPres  := TpcnPresencaComprador.pcPresencial; // presencial
			LNFe.Ide.tpAmb    := TACBrTipoAmbiente(AJSON.GetValue<Integer>('ambiente', 2));

			// Responsável Técnico (por usuário, via CONFIGURACOES_USUARIO)
			if Assigned(FConfig) and not FConfig.RespCNPJ.IsEmpty then
			begin
				LNFe.infRespTec.CNPJ     := FConfig.RespCNPJ;
				LNFe.infRespTec.xContato := FConfig.RespContato;
				LNFe.infRespTec.email    := FConfig.RespEmail;
				LNFe.infRespTec.fone     := FConfig.RespFone;
			end;

			// Emitente
			LNFe.Emit.CNPJCPF := FCNPJ;
			LNFe.Emit.xNome   := AJSON.GetValue<string>('emit_razao_social', '');
			LNFe.Emit.IE      := AJSON.GetValue<string>('emit_ie', '');
			LNFe.Emit.CRT     := TpcnCRT(AJSON.GetValue<Integer>('emit_crt', 3));

			LEmitEnd := AJSON.GetValue<TJSONObject>('emit_endereco');
			if Assigned(LEmitEnd) then
			begin
				LNFe.Emit.EnderEmit.xLgr    := LEmitEnd.GetValue<string>('logradouro', '');
				LNFe.Emit.EnderEmit.nro     := LEmitEnd.GetValue<string>('numero', 'SN');
				LNFe.Emit.EnderEmit.xBairro := LEmitEnd.GetValue<string>('bairro', '');
				LNFe.Emit.EnderEmit.xMun    := LEmitEnd.GetValue<string>('municipio', '');
				LNFe.Emit.EnderEmit.UF      := LEmitEnd.GetValue<string>('uf', TAppConfig.UF);
				LNFe.Emit.EnderEmit.CEP     := StrToInt(LEmitEnd.GetValue<string>('cep', '0'));
				LNFe.Emit.EnderEmit.cMun    := LEmitEnd.GetValue<Integer>('codigo_municipio', 0);
			end;

			// Destinatário (opcional na NFCe)
			LCPF := AJSON.GetValue<string>('cpf_cliente', '');
			if not LCPF.IsEmpty then
			begin
				LNFe.Dest.CNPJCPF := LCPF;
				LNFe.Dest.xNome   := AJSON.GetValue<string>('nome_cliente', '');
			end;

			// Itens
			AdicionarItensNFCe(AJSON);

			// Pagamentos
			AdicionarPagamentos(AJSON);
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

procedure TACBrNFeService.AdicionarItensNFCe(AJSON: TJSONObject);
var
	LItens   : TJSONArray;
	LItem    : TJSONObject;
	I        : Integer;
	LDet     : TDetCollectionItem;
	LCST     : TCSTIcms;
	LAliqICMS: double;
begin
	LItens := AJSON.GetValue<TJSONArray>('itens');
	if not Assigned(LItens) then
		Exit;

	for I := 0 to LItens.Count - 1 do
	begin
		LItem := LItens.Items[I] as TJSONObject;
		LDet  := FACBrNFe.NotasFiscais.Items[0].NFe.Det.New;

		LDet.Prod.nItem   := I + 1;
		LDet.Prod.cProd   := LItem.GetValue<string>('codigo', IntToStr(I + 1));
		LDet.Prod.cEAN    := LItem.GetValue<string>('ean', 'SEM GTIN');
		LDet.Prod.xProd   := LItem.GetValue<string>('descricao', '');
		LDet.Prod.NCM     := LItem.GetValue<string>('ncm', '');
		LDet.Prod.CFOP    := LItem.GetValue<string>('cfop', '5102');
		LDet.Prod.uCom    := LItem.GetValue<string>('unidade', 'UN');
		LDet.Prod.qCom    := LItem.GetValue<double>('quantidade', 1);
		LDet.Prod.vUnCom  := LItem.GetValue<double>('valor_unitario', 0);
		LDet.Prod.vProd   := LItem.GetValue<double>('valor_total', 0);
		LDet.Prod.uTrib   := LItem.GetValue<string>('unidade', 'UN');
		LDet.Prod.qTrib   := LItem.GetValue<double>('quantidade', 1);
		LDet.Prod.vUnTrib := LItem.GetValue<double>('valor_unitario', 0);
		LDet.Prod.vDesc   := LItem.GetValue<double>('desconto', 0);
		LDet.Prod.indTot  := itSomaTotalNFe;
		LDet.Prod.CEST    := LItem.GetValue<string>('cest', '');

		// ICMS
		LCST                   := StrToCSTICMS(LItem.GetValue<string>('cst_icms', '102'));
		LDet.Imposto.ICMS.orig := TOrigemMercadoria.oeNacional;
		LDet.Imposto.ICMS.CST  := LCST;

		LAliqICMS := LItem.GetValue<double>('aliq_icms', 0);
		if LAliqICMS > 0 then
		begin
			LDet.Imposto.ICMS.modBC := TpcnDeterminacaoBaseIcms.dbiMargemValorAgregado;
			LDet.Imposto.ICMS.vBC   := LDet.Prod.vProd;
			LDet.Imposto.ICMS.pICMS := LAliqICMS;
			LDet.Imposto.ICMS.vICMS := (LDet.Prod.vProd * LAliqICMS) / 100;
		end;

		// PIS / COFINS (sem incidência é cST 07 padrão no varejo)
		LDet.Imposto.PIS.CST    := StrToCSTPIS(LItem.GetValue<string>('cst_pis', '07'));
		LDet.Imposto.COFINS.CST := StrToCSTCOFINS(LItem.GetValue<string>('cst_cofins', '07'));
	end;
end;

procedure TACBrNFeService.AdicionarPagamentos(AJSON: TJSONObject);
var
	LPgtos: TJSONArray;
	LPgto : TJSONObject;
	I     : Integer;
	LPag  : TpagCollectionItem;
begin
	LPgtos := AJSON.GetValue<TJSONArray>('pagamentos');
	if not Assigned(LPgtos) then
	begin
		// Fallback: cria um pagamento único = valor total
		LPag      := FACBrNFe.NotasFiscais.Items[0].NFe.Pag.New;
		LPag.tPag := TpcnFormaPagamento.fpDinheiro;
		LPag.vPag := AJSON.GetValue<double>('valor_total', 0);
		Exit;
	end;

	for I := 0 to LPgtos.Count - 1 do
	begin
		LPgto     := LPgtos.Items[I] as TJSONObject;
		LPag      := FACBrNFe.NotasFiscais.Items[0].NFe.Pag.New;
		LPag.tPag := TpcnFormaPagamento(LPgto.GetValue<Integer>('forma', 1));
		LPag.vPag := LPgto.GetValue<double>('valor', 0);
	end;
end;

// ============================================================
// ENVIO (comum NFe/NFCe)
// ============================================================

function TACBrNFeService.ExecutarEnvio(ALote: string): TResultadoEmissao;
begin
	Result.Sucesso   := False;
	Result.Chave     := '';
	Result.Protocolo := '';
	Result.CStat     := 0;
	Result.Motivo    := '';
	Result.XML       := '';
	Result.Erro      := '';

	try
		FACBrNFe.Enviar(ALote, False, True);

		Result.CStat     := FACBrNFe.WebServices.Enviar.CStat;
		Result.Motivo    := FACBrNFe.WebServices.Enviar.XMotivo;
		Result.Chave     := FACBrNFe.NotasFiscais.Items[0].NFe.procNFe.chNFe;
		Result.Protocolo := FACBrNFe.WebServices.Enviar.Protocolo;
		Result.XML       := FACBrNFe.NotasFiscais.Items[0].XMLOriginal;
		Result.Sucesso   := Result.CStat = 100;

		if Result.Sucesso then
			SalvarXML(Result.Chave, Result.XML, 'nfe')
		else
			Result.Erro := Format('SEFAZ retornou cStat=%d: %s', [Result.CStat, Result.Motivo]);

		TLogger.Info('ACBr.Service.ExecutarEnvio: chave=%s cStat=%d motivo=%s', [Result.Chave, Result.CStat, Result.Motivo]);
	except
		on E: Exception do
		begin
			Result.Sucesso := False;
			Result.Erro    := E.Message;
			TLogger.Error('ACBr.Service.ExecutarEnvio', E);
		end;
	end;
end;

// ============================================================
// CANCELAMENTO
// ============================================================
function TACBrNFeService.ExtrairDadosNFe(const chave: string; out CNPJ, NumSerie, NumeroNF: string): Boolean;
begin
  Result := False;
  if Length(chave) <> 44 then
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

    CNPJ     := Copy(chave, 7, 14);
    NumSerie := Copy(chave, 23, 3);
    NumeroNF := Copy(chave, 26, 9);

    Result := True;
  except
    Result := False;
  end;
end;

function TACBrNFeService.Cancelar(const AChave, AProtocolo, AJustificativa: string): TResultadoEmissao;
var
	CancNFe   : TInfEvento;
	NumeroLote: string;
  CNPJEmitente: string;
  SerieNF: string;
  NumeroNF: string;
begin
	Result.Sucesso := False;
	Result.Erro    := '';

	if not FConfigurado then
	begin
		Result.Erro := 'ACBr não configurado';
		Exit;
	end;

	try
  	ExtrairDadosNFe(AChave, CNPJEmitente, SerieNF, NumeroNF);
		ConfigurarGeral('NFe'); // modelo não importa para cancelamento
		FACBrNFe.EventoNFe.Evento.Clear;
		CancNFe                 := FACBrNFe.EventoNFe.Evento.New.InfEvento;
		CancNFe.chNFe           := AChave;
		CancNFe.CNPJ            := CNPJEmitente;
		CancNFe.detEvento.nProt := AProtocolo;
		CancNFe.detEvento.xJust := AJustificativa;
		NumeroLote              := (SerieNF.ToInteger * 1000000).ToString + NumeroNF;
		FACBrNFe.EnviarEvento(NumeroLote.ToInteger());

		Result.CStat  := FACBrNFe.WebServices.EnvEvento.CStat;
		Result.Motivo := FACBrNFe.WebServices.EnvEvento.XMotivo;
		// Result.Protocolo := FACBrNFe.WebServices.EnvEvento.EventoRetorno.xMotivo;
		Result.Sucesso := Result.CStat = 135; // 135 = Evento registrado e vinculado a NF-e

		if not Result.Sucesso then
			Result.Erro := Format('cStat=%d: %s', [Result.CStat, Result.Motivo]);

		TLogger.Info('ACBr.Service.Cancelar: chave=%s cStat=%d', [AChave, Result.CStat]);
	except
		on E: Exception do
		begin
			Result.Sucesso := False;
			Result.Erro    := E.Message;
			TLogger.Error('ACBr.Service.Cancelar', E);
		end;
	end;
end;

// ============================================================
// CONSULTA STATUS SEFAZ
// ============================================================

function TACBrNFeService.ConsultarStatusSefaz(const AUF: string; AModelo: Integer): TResultadoEmissao;
begin
	Result.Sucesso := False;
	Result.Erro    := '';

	try
		if AModelo = 65 then
			ConfigurarGeral('NFCe')
		else
			ConfigurarGeral('NFe');

		if not AUF.IsEmpty then
			FACBrNFe.Configuracoes.WebServices.UF := AUF;

		FACBrNFe.WebServices.StatusServico.Executar;

		Result.CStat   := FACBrNFe.WebServices.StatusServico.CStat;
		Result.Motivo  := FACBrNFe.WebServices.StatusServico.XMotivo;
		Result.Sucesso := Result.CStat = 107; // 107 = Serviço em Operação
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
	Result.Erro    := '';

	if not FConfigurado then
	begin
		Result.Erro := 'ACBr não configurado';
		Exit;
	end;

	try
		ConfigurarGeral('NFe');
		FACBrNFe.WebServices.Consulta.NFeChave := AChave;
		FACBrNFe.WebServices.Consulta.Executar;

		Result.CStat     := FACBrNFe.WebServices.Consulta.CStat;
		Result.Motivo    := FACBrNFe.WebServices.Consulta.XMotivo;
		Result.Protocolo := FACBrNFe.WebServices.Consulta.Protocolo;
		Result.Chave     := AChave;
		Result.Sucesso   := Result.CStat = 100;
	except
		on E: Exception do
		begin
			Result.Sucesso := False;
			Result.Erro    := E.Message;
			TLogger.Error('ACBr.Service.ConsultarNFe', E);
		end;
	end;
end;

function TACBrNFeService.InutilizarNumeros(const ACNPJ, AJustificativa, ASerie: string; ANNFIni, ANNFFin: Integer): TResultadoEmissao;
begin
	Result.Sucesso := False;
	Result.Erro    := '';

	if not FConfigurado then
	begin
		Result.Erro := 'ACBr não configurado';
		Exit;
	end;

	try
		ConfigurarGeral('NFe');
		with FACBrNFe.WebServices.Inutilizacao do
		begin
			serie         := ASerie.ToInteger;
			NumeroInicial := ANNFIni;
			NumeroFinal   := ANNFFin;
			Justificativa := AJustificativa;
			Executar;
			Result.CStat   := CStat;
			Result.Motivo  := XMotivo;
			Result.Sucesso := CStat = 102; // 102 = Inutilização de número homologado
		end;
	except
		on E: Exception do
		begin
			Result.Sucesso := False;
			Result.Erro    := E.Message;
			TLogger.Error('ACBr.Service.InutilizarNumeros', E);
		end;
	end;
end;

// ============================================================
// DANFE / XML
// ============================================================

function TACBrNFeService.GerarDANFe(const AChave: string): string;
var
	LXMLPath: string;
	LPDFPath: string;
	LDANFCe : TACBrNFeDANFCEClass;
begin
	Result   := '';
	LXMLPath := TPath.Combine(TAppConfig.AcbrXmlDir, AChave + '-nfe.xml');
	if not TFile.Exists(LXMLPath) then
		Exit;

	LPDFPath := TPath.Combine(TAppConfig.AcbrXmlDir, AChave + '.pdf');
	LDANFCe  := TACBrNFeDANFCEClass.Create(nil);
	try
		LDANFCe.NomeDocumento := LXMLPath;
//		LDANFCe.Imprimir(LPDFPath);
		Result := LPDFPath;
	finally
		LDANFCe.Free;
	end;
end;

function TACBrNFeService.ObterXML(const AChave: string): string;
var
	LXMLPath: string;
begin
	Result   := '';
	LXMLPath := TPath.Combine(TAppConfig.AcbrXmlDir, AChave + '-nfe.xml');
	if TFile.Exists(LXMLPath) then
		Result := TFile.ReadAllText(LXMLPath, TEncoding.UTF8);
end;

procedure TACBrNFeService.SalvarXML(const AChave, AConteudo, ATipo: string);
var
	LPath: string;
begin
	if AChave.IsEmpty or AConteudo.IsEmpty then
		Exit;

	try
		ForceDirectories(TAppConfig.AcbrXmlDir);
		LPath := TPath.Combine(TAppConfig.AcbrXmlDir, AChave + '-' + ATipo + '.xml');
		TFile.WriteAllText(LPath, AConteudo, TEncoding.UTF8);
		TLogger.Info('ACBr.Service: XML salvo em %s', [LPath]);
	except
		on E: Exception do
			TLogger.Error('ACBr.Service.SalvarXML: %s', [E.Message]);
	end;
end;

end.
