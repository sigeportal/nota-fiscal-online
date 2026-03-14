unit Models.NF;

{
  Modelos PortalORM mapeando as tabelas do banco de dados PRINCIPAL.FDB
  Todas as entidades principais: Usuários, Certificados, NFe, NFCe e itens

  IMPORTANTE: O atributo [TCampo] deve decorar a PROPERTY (não o field),
  pois VarreCampos() usa Tipo.GetProperties para descobrir os mapeamentos.
}

interface

uses
  System.SysUtils,
  UnitPortalORM.Model;

// ============================================================
//  USUÁRIOS
// ============================================================
type
  [TNomeTabela('USUARIOS', 'USU_CODIGO')]
  TModelUsuario = class(TTabela)
  private
    FCodigo            : Integer;
    FUsername          : string;
    FEmail             : string;
    FPasswordHash      : string;
    FCNPJ              : string;
    FRazaoSocial       : string;
    FInscricaoEstadual : string;
    FEndereco          : string;
    FCidade            : string;
    FUF                : string;
    FCEP               : string;
    FTelefone          : string;
    FAtivo             : Integer;
    FDataCriacao       : TDateTime;
    FDataAtualizacao   : TDateTime;
  public
    [TCampo('USU_CODIGO', 'INTEGER')]
    property Codigo: Integer read FCodigo write FCodigo;
    [TCampo('USU_USERNAME', 'VARCHAR(100)')]
    property Username: string read FUsername write FUsername;
    [TCampo('USU_EMAIL', 'VARCHAR(150)')]
    property Email: string read FEmail write FEmail;
    [TCampo('USU_PASSWORD_HASH', 'VARCHAR(500)')]
    property PasswordHash: string read FPasswordHash write FPasswordHash;
    [TCampo('USU_CNPJ', 'VARCHAR(14)')]
    property CNPJ: string read FCNPJ write FCNPJ;
    [TCampo('USU_RAZAO_SOCIAL', 'VARCHAR(255)')]
    property RazaoSocial: string read FRazaoSocial write FRazaoSocial;
    [TCampo('USU_INSCRICAO_ESTADUAL', 'VARCHAR(20)')]
    property InscricaoEstadual: string read FInscricaoEstadual write FInscricaoEstadual;
    [TCampo('USU_ENDERECO', 'VARCHAR(255)')]
    property Endereco: string read FEndereco write FEndereco;
    [TCampo('USU_CIDADE', 'VARCHAR(100)')]
    property Cidade: string read FCidade write FCidade;
    [TCampo('USU_UF', 'CHAR(2)')]
    property UF: string read FUF write FUF;
    [TCampo('USU_CEP', 'VARCHAR(9)')]
    property CEP: string read FCEP write FCEP;
    [TCampo('USU_TELEFONE', 'VARCHAR(20)')]
    property Telefone: string read FTelefone write FTelefone;
    [TCampo('USU_ATIVO', 'SMALLINT')]
    property Ativo: Integer read FAtivo write FAtivo;
    [TCampo('USU_DATA_CRIACAO', 'TIMESTAMP')]
    property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;
    [TCampo('USU_DATA_ATUALIZACAO', 'TIMESTAMP')]
    property DataAtualizacao: TDateTime read FDataAtualizacao write FDataAtualizacao;
  end;

// ============================================================
//  CERTIFICADOS
// ============================================================
  [TNomeTabela('CERTIFICADOS', 'CER_CODIGO')]
  TModelCertificado = class(TTabela)
  private
    FCodigo          : Integer;
    FUsuario         : Integer;
    FCNPJ            : string;
    FDados           : TBytes;
    FSenhaHash       : string;
    FSenhaClara      : string;
    FAssunto         : string;
    FEmissor         : string;
    FValidadeIni     : TDateTime;
    FValidadeFim     : TDateTime;
    FThumbprint      : string;
    FAtivo           : Integer;
    FDataCriacao     : TDateTime;
    FDataAtualizacao : TDateTime;
  public
    [TCampo('CER_CODIGO', 'INTEGER')]
    property Codigo: Integer read FCodigo write FCodigo;
    [TCampo('CER_USU', 'INTEGER')]
    property Usuario: Integer read FUsuario write FUsuario;
    [TCampo('CER_CNPJ', 'VARCHAR(14)')]
    property CNPJ: string read FCNPJ write FCNPJ;
    [TCampo('CER_DADOS', 'BLOB')]
    property Dados: TBytes read FDados write FDados;
    [TCampo('CER_SENHA_HASH', 'VARCHAR(500)')]
    property SenhaHash: string read FSenhaHash write FSenhaHash;
    [TCampo('CER_SENHA_CLARA', 'VARCHAR(500)')]
    property SenhaClara: string read FSenhaClara write FSenhaClara;
    [TCampo('CER_ASSUNTO', 'VARCHAR(500)')]
    property Assunto: string read FAssunto write FAssunto;
    [TCampo('CER_EMISSOR', 'VARCHAR(500)')]
    property Emissor: string read FEmissor write FEmissor;
    [TCampo('CER_VALIDADE_INI', 'TIMESTAMP')]
    property ValidadeIni: TDateTime read FValidadeIni write FValidadeIni;
    [TCampo('CER_VALIDADE_FIM', 'TIMESTAMP')]
    property ValidadeFim: TDateTime read FValidadeFim write FValidadeFim;
    [TCampo('CER_THUMBPRINT', 'VARCHAR(100)')]
    property Thumbprint: string read FThumbprint write FThumbprint;
    [TCampo('CER_ATIVO', 'SMALLINT')]
    property Ativo: Integer read FAtivo write FAtivo;
    [TCampo('CER_DATA_CRIACAO', 'TIMESTAMP')]
    property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;
    [TCampo('CER_DATA_ATUALIZACAO', 'TIMESTAMP')]
    property DataAtualizacao: TDateTime read FDataAtualizacao write FDataAtualizacao;
  end;

// ============================================================
//  NOTAS FISCAIS (NFe)
// ============================================================
  [TNomeTabela('NOTAS_FISCAIS', 'NOT_CODIGO')]
  TModelNFe = class(TTabela)
  private
    FCodigo          : Integer;
    FData            : TDateTime;
    FDataES          : TDateTime;
    FHora            : TDateTime;
    FCFOP            : string;
    FNumeroNF        : Integer;
    FModelo          : string;
    FSerie           : string;
    FChaveNFe        : string;
    FSituacao        : string;
    FValor           : Currency;
    FDesconto        : Currency;
    FBCIcms          : Currency;
    FVIcms           : Currency;
    FVTProd          : Currency;
    FArqAssinada     : string;
    FArqAutorizada   : string;
    FNumRecibo       : string;
    FProtocolo       : string;
    FJustificativa   : string;
    FObs             : string;
    FIndEmissao      : string;
    FOperConsumFinal : string;
  public
    [TCampo('NOT_CODIGO', 'INTEGER')]
    property Codigo: Integer read FCodigo write FCodigo;
    [TCampo('NOT_DATA', 'DATE')]
    property Data: TDateTime read FData write FData;
    [TCampo('NOT_DATA_ES', 'DATE')]
    property DataES: TDateTime read FDataES write FDataES;
    [TCampo('NOT_HORA', 'TIME')]
    property Hora: TDateTime read FHora write FHora;
    [TCampo('NOT_CFOP', 'VARCHAR(6)')]
    property CFOP: string read FCFOP write FCFOP;
    [TCampo('NOT_NF', 'INTEGER')]
    property NumeroNF: Integer read FNumeroNF write FNumeroNF;
    [TCampo('NOT_MODELO', 'VARCHAR(5)')]
    property Modelo: string read FModelo write FModelo;
    [TCampo('NOT_SERIE', 'VARCHAR(5)')]
    property Serie: string read FSerie write FSerie;
    [TCampo('NOT_CHAVE_NFE', 'VARCHAR(60)')]
    property ChaveNFe: string read FChaveNFe write FChaveNFe;
    [TCampo('NOT_SITUACAO_NFE', 'VARCHAR(10)')]
    property Situacao: string read FSituacao write FSituacao;
    [TCampo('NOT_VALOR', 'NUMERIC(12,4)')]
    property Valor: Currency read FValor write FValor;
    [TCampo('NOT_DESCONTO', 'NUMERIC(9,2)')]
    property Desconto: Currency read FDesconto write FDesconto;
    [TCampo('NOT_BCICMS', 'NUMERIC(12,4)')]
    property BCIcms: Currency read FBCIcms write FBCIcms;
    [TCampo('NOT_VICMS', 'NUMERIC(12,4)')]
    property VIcms: Currency read FVIcms write FVIcms;
    [TCampo('NOT_VTPROD', 'NUMERIC(12,4)')]
    property VTProd: Currency read FVTProd write FVTProd;
    [TCampo('NOT_ARQ_NFE_ASSINADA', 'VARCHAR(200)')]
    property ArqAssinada: string read FArqAssinada write FArqAssinada;
    [TCampo('NOT_ARQ_NFE_AUTORIZADA', 'VARCHAR(200)')]
    property ArqAutorizada: string read FArqAutorizada write FArqAutorizada;
    [TCampo('NOT_NUM_RECIBO_NFE', 'VARCHAR(20)')]
    property NumRecibo: string read FNumRecibo write FNumRecibo;
    [TCampo('NOT_PROT_AUT_NFE', 'VARCHAR(20)')]
    property Protocolo: string read FProtocolo write FProtocolo;
    [TCampo('NOT_JUSTIF_CANC', 'VARCHAR(200)')]
    property Justificativa: string read FJustificativa write FJustificativa;
    [TCampo('NOT_OBS', 'VARCHAR(350)')]
    property Obs: string read FObs write FObs;
    [TCampo('NOT_IND_EMISSAO', 'CHAR(1)')]
    property IndEmissao: string read FIndEmissao write FIndEmissao;
    [TCampo('NOT_OPER_CONSUM_FINAL', 'CHAR(1)')]
    property OperConsumFinal: string read FOperConsumFinal write FOperConsumFinal;
  end;

// ============================================================
//  ITENS DA NFe
// ============================================================
  [TNomeTabela('NOT_ITENS', 'NI_CODIGO')]
  TModelNFeItem = class(TTabela)
  private
    FCodigo      : Integer;
    FNotCodigo   : Integer;
    FProduto     : Integer;
    FNome        : string;
    FQuantidade  : Double;
    FValor       : Currency;
    FCFOP        : string;
    FCST         : string;
    FAliqIcms    : Double;
    FBCIcms      : Currency;
    FVIcms       : Currency;
    FUnidade     : string;
    FDesconto    : Currency;
    FCST_PIS     : string;
    FAliqPIS     : Double;
    FCST_COFINS  : string;
    FAliqCOFINS  : Double;
  public
    [TCampo('NI_CODIGO', 'INTEGER')]
    property Codigo: Integer read FCodigo write FCodigo;
    [TCampo('NI_NOT', 'INTEGER')]
    property NotCodigo: Integer read FNotCodigo write FNotCodigo;
    [TCampo('NI_PRO', 'INTEGER')]
    property Produto: Integer read FProduto write FProduto;
    [TCampo('NI_NOME', 'VARCHAR(200)')]
    property Nome: string read FNome write FNome;
    [TCampo('NI_QUANTIDADE', 'NUMERIC(18,6)')]
    property Quantidade: Double read FQuantidade write FQuantidade;
    [TCampo('NI_VALOR', 'NUMERIC(12,4)')]
    property Valor: Currency read FValor write FValor;
    [TCampo('NI_CFOP', 'VARCHAR(6)')]
    property CFOP: string read FCFOP write FCFOP;
    [TCampo('NI_CST', 'VARCHAR(5)')]
    property CST: string read FCST write FCST;
    [TCampo('NI_ALIQ_ICMS', 'NUMERIC(5,2)')]
    property AliqIcms: Double read FAliqIcms write FAliqIcms;
    [TCampo('NI_BCICMS', 'NUMERIC(12,4)')]
    property BCIcms: Currency read FBCIcms write FBCIcms;
    [TCampo('NI_VICMS', 'NUMERIC(12,4)')]
    property VIcms: Currency read FVIcms write FVIcms;
    [TCampo('NI_UNIDADE', 'VARCHAR(10)')]
    property Unidade: string read FUnidade write FUnidade;
    [TCampo('NI_VDESC', 'NUMERIC(12,4)')]
    property Desconto: Currency read FDesconto write FDesconto;
    [TCampo('NI_CST_PIS', 'VARCHAR(6)')]
    property CST_PIS: string read FCST_PIS write FCST_PIS;
    [TCampo('NI_ALIQ_PIS', 'NUMERIC(5,2)')]
    property AliqPIS: Double read FAliqPIS write FAliqPIS;
    [TCampo('NI_CST_COFINS', 'VARCHAR(6)')]
    property CST_COFINS: string read FCST_COFINS write FCST_COFINS;
    [TCampo('NI_ALIQ_COFINS', 'NUMERIC(5,2)')]
    property AliqCOFINS: Double read FAliqCOFINS write FAliqCOFINS;
  end;

// ============================================================
//  NFC (NFCe)
// ============================================================
  [TNomeTabela('NFC', 'NFC_CODIGO')]
  TModelNFC = class(TTabela)
  private
    FCodigo          : Integer;
    FCliente         : Integer;
    FNumeroNF        : Integer;
    FCFOP            : string;
    FData            : TDateTime;
    FHora            : TDateTime;
    FModelo          : string;
    FSerie           : string;
    FChaveNFCe       : string;
    FSituacao        : string;
    FValor           : Currency;
    FDesconto        : Currency;
    FBCIcms          : Currency;
    FVIcms           : Currency;
    FVTProd          : Currency;
    FArqAssinada     : string;
    FArqAutorizada   : string;
    FNumRecibo       : string;
    FProtocolo       : string;
    FJustificativa   : string;
    FCPFCliente      : string;
    FNomeCliente     : string;
    FOperConsumFinal : string;
    FCondicaoPgto    : string;
  public
    [TCampo('NFC_CODIGO', 'INTEGER')]
    property Codigo: Integer read FCodigo write FCodigo;
    [TCampo('NFC_CLI', 'INTEGER')]
    property Cliente: Integer read FCliente write FCliente;
    [TCampo('NFC_NF', 'INTEGER')]
    property NumeroNF: Integer read FNumeroNF write FNumeroNF;
    [TCampo('NFC_CFOP', 'VARCHAR(8)')]
    property CFOP: string read FCFOP write FCFOP;
    [TCampo('NFC_DATA', 'DATE')]
    property Data: TDateTime read FData write FData;
    [TCampo('NFC_HORA', 'TIME')]
    property Hora: TDateTime read FHora write FHora;
    [TCampo('NFC_MODELO', 'VARCHAR(5)')]
    property Modelo: string read FModelo write FModelo;
    [TCampo('NFC_SERIE', 'VARCHAR(5)')]
    property Serie: string read FSerie write FSerie;
    [TCampo('NFC_CHAVE_NFCE', 'VARCHAR(60)')]
    property ChaveNFCe: string read FChaveNFCe write FChaveNFCe;
    [TCampo('NFC_SITUACAO_NFCE', 'VARCHAR(10)')]
    property Situacao: string read FSituacao write FSituacao;
    [TCampo('NFC_VALOR', 'NUMERIC(12,4)')]
    property Valor: Currency read FValor write FValor;
    [TCampo('NFC_DESCONTO', 'NUMERIC(9,2)')]
    property Desconto: Currency read FDesconto write FDesconto;
    [TCampo('NFC_BCICMS', 'NUMERIC(12,4)')]
    property BCIcms: Currency read FBCIcms write FBCIcms;
    [TCampo('NFC_VICMS', 'NUMERIC(12,4)')]
    property VIcms: Currency read FVIcms write FVIcms;
    [TCampo('NFC_VTPROD', 'NUMERIC(12,4)')]
    property VTProd: Currency read FVTProd write FVTProd;
    [TCampo('NFC_ARQ_NFCE_ASSINADA', 'VARCHAR(200)')]
    property ArqAssinada: string read FArqAssinada write FArqAssinada;
    [TCampo('NFC_ARQ_NFCE_AUTORIZADA', 'VARCHAR(200)')]
    property ArqAutorizada: string read FArqAutorizada write FArqAutorizada;
    [TCampo('NFC_NUM_RECIBO_NFCE', 'VARCHAR(20)')]
    property NumRecibo: string read FNumRecibo write FNumRecibo;
    [TCampo('NFC_PROT_AUT_NFCE', 'VARCHAR(20)')]
    property Protocolo: string read FProtocolo write FProtocolo;
    [TCampo('NFC_JUSTIF_CANC', 'VARCHAR(200)')]
    property Justificativa: string read FJustificativa write FJustificativa;
    [TCampo('NFC_CPF_CLIENTE', 'VARCHAR(18)')]
    property CPFCliente: string read FCPFCliente write FCPFCliente;
    [TCampo('NFC_NOME_CLIENTE', 'VARCHAR(100)')]
    property NomeCliente: string read FNomeCliente write FNomeCliente;
    [TCampo('NFC_OPER_CONSUM_FINAL', 'CHAR(1)')]
    property OperConsumFinal: string read FOperConsumFinal write FOperConsumFinal;
    [TCampo('NFC_CONDICAO_PGTO', 'CHAR(1)')]
    property CondicaoPgto: string read FCondicaoPgto write FCondicaoPgto;
  end;

// ============================================================
//  CONFIGURAÇÕES POR USUÁRIO (NFCe + Responsável Técnico)
// ============================================================
  [TNomeTabela('CONFIGURACOES_USUARIO', 'CFG_CODIGO')]
  TModelConfiguracaoUsuario = class(TTabela)
  private
    FCodigo              : Integer;
    FUsuario             : Integer;
    FUF                  : string;
    FAmbienteProducao    : Integer;
    FNFCeIdCSC           : string;
    FNFCeCSC             : string;
    FNFCeSerie           : string;
    FNFCeNumeroInicial   : Integer;
    FNFeSerie            : string;
    FNFeNumeroInicial    : Integer;
    FRespCNPJ            : string;
    FRespContato         : string;
    FRespEmail           : string;
    FRespFone            : string;
    FRespIdCSRT          : string;
    FRespCSRT            : string;
    FEmitNome            : string;
    FEmitCNPJ            : string;
    FEmitIE              : string;
    FEmitEndereco        : string;
    FEmitNumero          : string;
    FEmitBairro          : string;
    FEmitMunicipio       : string;
    FEmitCEP             : string;
    FEmitTelefone        : string;
    FEmitCRT             : Integer;
    FEmitCodMunicipio    : string;
    FDataCriacao         : TDateTime;
    FDataAtualizacao     : TDateTime;
  public
    [TCampo('CFG_CODIGO', 'INTEGER')]
    property Codigo: Integer read FCodigo write FCodigo;
    [TCampo('CFG_USU', 'INTEGER')]
    property Usuario: Integer read FUsuario write FUsuario;
    // NFe / NFCe geral
    [TCampo('CFG_UF', 'CHAR(2)')]
    property UF: string read FUF write FUF;
    [TCampo('CFG_AMBIENTE_PRODUCAO', 'SMALLINT')]
    property AmbienteProducao: Integer read FAmbienteProducao write FAmbienteProducao;
    // NFCe
    [TCampo('CFG_NFCE_ID_CSC', 'VARCHAR(50)')]
    property NFCeIdCSC: string read FNFCeIdCSC write FNFCeIdCSC;
    [TCampo('CFG_NFCE_CSC', 'VARCHAR(200)')]
    property NFCeCSC: string read FNFCeCSC write FNFCeCSC;
    [TCampo('CFG_NFCE_SERIE', 'VARCHAR(5)')]
    property NFCeSerie: string read FNFCeSerie write FNFCeSerie;
    [TCampo('CFG_NFCE_NUMERO_INICIAL', 'INTEGER')]
    property NFCeNumeroInicial: Integer read FNFCeNumeroInicial write FNFCeNumeroInicial;
    // NFe
    [TCampo('CFG_NFE_SERIE', 'VARCHAR(5)')]
    property NFeSerie: string read FNFeSerie write FNFeSerie;
    [TCampo('CFG_NFE_NUMERO_INICIAL', 'INTEGER')]
    property NFeNumeroInicial: Integer read FNFeNumeroInicial write FNFeNumeroInicial;
    // Responsável Técnico
    [TCampo('CFG_RESP_CNPJ', 'VARCHAR(14)')]
    property RespCNPJ: string read FRespCNPJ write FRespCNPJ;
    [TCampo('CFG_RESP_CONTATO', 'VARCHAR(100)')]
    property RespContato: string read FRespContato write FRespContato;
    [TCampo('CFG_RESP_EMAIL', 'VARCHAR(150)')]
    property RespEmail: string read FRespEmail write FRespEmail;
    [TCampo('CFG_RESP_FONE', 'VARCHAR(20)')]
    property RespFone: string read FRespFone write FRespFone;
    [TCampo('CFG_RESP_ID_CSRT', 'VARCHAR(10)')]
    property RespIdCSRT: string read FRespIdCSRT write FRespIdCSRT;
    [TCampo('CFG_RESP_CSRT', 'VARCHAR(200)')]
    property RespCSRT: string read FRespCSRT write FRespCSRT;
    // Emitente
    [TCampo('CFG_EMIT_NOME', 'VARCHAR(255)')]
    property EmitNome: string read FEmitNome write FEmitNome;
    [TCampo('CFG_EMIT_CNPJ', 'VARCHAR(14)')]
    property EmitCNPJ: string read FEmitCNPJ write FEmitCNPJ;
    [TCampo('CFG_EMIT_IE', 'VARCHAR(20)')]
    property EmitIE: string read FEmitIE write FEmitIE;
    [TCampo('CFG_EMIT_ENDERECO', 'VARCHAR(255)')]
    property EmitEndereco: string read FEmitEndereco write FEmitEndereco;
    [TCampo('CFG_EMIT_NUMERO', 'VARCHAR(20)')]
    property EmitNumero: string read FEmitNumero write FEmitNumero;
    [TCampo('CFG_EMIT_BAIRRO', 'VARCHAR(100)')]
    property EmitBairro: string read FEmitBairro write FEmitBairro;
    [TCampo('CFG_EMIT_MUNICIPIO', 'VARCHAR(100)')]
    property EmitMunicipio: string read FEmitMunicipio write FEmitMunicipio;
    [TCampo('CFG_EMIT_CEP', 'VARCHAR(9)')]
    property EmitCEP: string read FEmitCEP write FEmitCEP;
    [TCampo('CFG_EMIT_TELEFONE', 'VARCHAR(20)')]
    property EmitTelefone: string read FEmitTelefone write FEmitTelefone;
    [TCampo('CFG_EMIT_CRT', 'SMALLINT')]
    property EmitCRT: Integer read FEmitCRT write FEmitCRT;
    [TCampo('CFG_EMIT_COD_MUNICIPIO', 'VARCHAR(10)')]
    property EmitCodMunicipio: string read FEmitCodMunicipio write FEmitCodMunicipio;
    // Controle
    [TCampo('CFG_DATA_CRIACAO', 'TIMESTAMP')]
    property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;
    [TCampo('CFG_DATA_ATUALIZACAO', 'TIMESTAMP')]
    property DataAtualizacao: TDateTime read FDataAtualizacao write FDataAtualizacao;
  end;

// ============================================================
//  ITENS DA NFCe
// ============================================================
  [TNomeTabela('NFC_PRO', 'NP_CODIGO')]
  TModelNFCItem = class(TTabela)
  private
    FCodigo    : Integer;
    FNFCCodigo : Integer;
    FProduto   : Integer;
    FNome      : string;
    FQuantidade: Double;
    FValor     : Currency;
    FCFOP      : string;
    FCST_ICMS  : string;
    FAliqIcms  : Double;
    FBCIcms    : Currency;
  public
    [TCampo('NP_CODIGO', 'INTEGER')]
    property Codigo: Integer read FCodigo write FCodigo;
    [TCampo('NP_NFC', 'INTEGER')]
    property NFCCodigo: Integer read FNFCCodigo write FNFCCodigo;
    [TCampo('NP_PRO', 'INTEGER')]
    property Produto: Integer read FProduto write FProduto;
    [TCampo('NP_NOME', 'VARCHAR(200)')]
    property Nome: string read FNome write FNome;
    [TCampo('NP_QUANTIDADE', 'NUMERIC(18,6)')]
    property Quantidade: Double read FQuantidade write FQuantidade;
    [TCampo('NP_VALOR', 'NUMERIC(12,4)')]
    property Valor: Currency read FValor write FValor;
    [TCampo('NP_CFOP', 'VARCHAR(6)')]
    property CFOP: string read FCFOP write FCFOP;
    [TCampo('NP_CST_ICMS', 'VARCHAR(5)')]
    property CST_ICMS: string read FCST_ICMS write FCST_ICMS;
    [TCampo('NP_ALIQ_ICMS', 'NUMERIC(5,2)')]
    property AliqIcms: Double read FAliqIcms write FAliqIcms;
    [TCampo('NP_BC_ICMS', 'NUMERIC(12,4)')]
    property BCIcms: Currency read FBCIcms write FBCIcms;
  end;

implementation

end.
