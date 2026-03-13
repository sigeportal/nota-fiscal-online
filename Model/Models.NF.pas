unit Models.NF;

{
  Modelos PortalORM mapeando as tabelas do banco de dados PRINCIPAL.FDB
  Todas as entidades principais: Usuários, Certificados, NFe, NFCe e itens
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
    [TCampo('USU_CODIGO', 'INTEGER')]
    FCodigo: Integer;
    [TCampo('USU_USERNAME', 'VARCHAR(100)')]
    FUsername: string;
    [TCampo('USU_EMAIL', 'VARCHAR(150)')]
    FEmail: string;
    [TCampo('USU_PASSWORD_HASH', 'VARCHAR(500)')]
    FPasswordHash: string;
    [TCampo('USU_CNPJ', 'VARCHAR(14)')]
    FCNPJ: string;
    [TCampo('USU_RAZAO_SOCIAL', 'VARCHAR(255)')]
    FRazaoSocial: string;
    [TCampo('USU_INSCRICAO_ESTADUAL', 'VARCHAR(20)')]
    FInscricaoEstadual: string;
    [TCampo('USU_ENDERECO', 'VARCHAR(255)')]
    FEndereco: string;
    [TCampo('USU_CIDADE', 'VARCHAR(100)')]
    FCidade: string;
    [TCampo('USU_UF', 'CHAR(2)')]
    FUF: string;
    [TCampo('USU_CEP', 'VARCHAR(9)')]
    FCEP: string;
    [TCampo('USU_TELEFONE', 'VARCHAR(20)')]
    FTelefone: string;
    [TCampo('USU_ATIVO', 'SMALLINT')]
    FAtivo: Integer;
    [TCampo('USU_DATA_CRIACAO', 'TIMESTAMP')]
    FDataCriacao: TDateTime;
    [TCampo('USU_DATA_ATUALIZACAO', 'TIMESTAMP')]
    FDataAtualizacao: TDateTime;
  public
    property Codigo: Integer read FCodigo write FCodigo;
    property Username: string read FUsername write FUsername;
    property Email: string read FEmail write FEmail;
    property PasswordHash: string read FPasswordHash write FPasswordHash;
    property CNPJ: string read FCNPJ write FCNPJ;
    property RazaoSocial: string read FRazaoSocial write FRazaoSocial;
    property InscricaoEstadual: string read FInscricaoEstadual write FInscricaoEstadual;
    property Endereco: string read FEndereco write FEndereco;
    property Cidade: string read FCidade write FCidade;
    property UF: string read FUF write FUF;
    property CEP: string read FCEP write FCEP;
    property Telefone: string read FTelefone write FTelefone;
    property Ativo: Integer read FAtivo write FAtivo;
    property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;
    property DataAtualizacao: TDateTime read FDataAtualizacao write FDataAtualizacao;
  end;

// ============================================================
//  CERTIFICADOS
// ============================================================
  [TNomeTabela('CERTIFICADOS', 'CER_CODIGO')]
  TModelCertificado = class(TTabela)
  private
    [TCampo('CER_CODIGO', 'INTEGER')]
    FCodigo: Integer;
    [TCampo('CER_USU', 'INTEGER')]
    FUsuario: Integer;
    [TCampo('CER_CNPJ', 'VARCHAR(14)')]
    FCNPJ: string;
    [TCampo('CER_DADOS', 'BLOB')]
    FDados: TBytes;
    [TCampo('CER_SENHA_HASH', 'VARCHAR(500)')]
    FSenhaHash: string;
    [TCampo('CER_SENHA_CLARA', 'VARCHAR(500)')]
    FSenhaClara: string;
    [TCampo('CER_ASSUNTO', 'VARCHAR(500)')]
    FAssunto: string;
    [TCampo('CER_EMISSOR', 'VARCHAR(500)')]
    FEmissor: string;
    [TCampo('CER_VALIDADE_INI', 'TIMESTAMP')]
    FValidadeIni: TDateTime;
    [TCampo('CER_VALIDADE_FIM', 'TIMESTAMP')]
    FValidadeFim: TDateTime;
    [TCampo('CER_THUMBPRINT', 'VARCHAR(100)')]
    FThumbprint: string;
    [TCampo('CER_ATIVO', 'SMALLINT')]
    FAtivo: Integer;
    [TCampo('CER_DATA_CRIACAO', 'TIMESTAMP')]
    FDataCriacao: TDateTime;
    [TCampo('CER_DATA_ATUALIZACAO', 'TIMESTAMP')]
    FDataAtualizacao: TDateTime;
  public
    property Codigo: Integer read FCodigo write FCodigo;
    property Usuario: Integer read FUsuario write FUsuario;
    property CNPJ: string read FCNPJ write FCNPJ;
    property Dados: TBytes read FDados write FDados;
    property SenhaHash: string read FSenhaHash write FSenhaHash;
    property SenhaClara: string read FSenhaClara write FSenhaClara;
    property Assunto: string read FAssunto write FAssunto;
    property Emissor: string read FEmissor write FEmissor;
    property ValidadeIni: TDateTime read FValidadeIni write FValidadeIni;
    property ValidadeFim: TDateTime read FValidadeFim write FValidadeFim;
    property Thumbprint: string read FThumbprint write FThumbprint;
    property Ativo: Integer read FAtivo write FAtivo;
    property DataCriacao: TDateTime read FDataCriacao write FDataCriacao;
    property DataAtualizacao: TDateTime read FDataAtualizacao write FDataAtualizacao;
  end;

// ============================================================
//  NOTAS FISCAIS (NFe)
// ============================================================
  [TNomeTabela('NOTAS_FISCAIS', 'NOT_CODIGO')]
  TModelNFe = class(TTabela)
  private
    [TCampo('NOT_CODIGO', 'INTEGER')]
    FCodigo: Integer;
    [TCampo('NOT_DATA', 'DATE')]
    FData: TDateTime;
    [TCampo('NOT_DATA_ES', 'DATE')]
    FDataES: TDateTime;
    [TCampo('NOT_HORA', 'TIME')]
    FHora: TDateTime;
    [TCampo('NOT_CFOP', 'VARCHAR(6)')]
    FCFOP: string;
    [TCampo('NOT_NF', 'INTEGER')]
    FNumeroNF: Integer;
    [TCampo('NOT_MODELO', 'VARCHAR(5)')]
    FModelo: string;
    [TCampo('NOT_SERIE', 'VARCHAR(5)')]
    FSerie: string;
    [TCampo('NOT_CHAVE_NFE', 'VARCHAR(60)')]
    FChaveNFe: string;
    [TCampo('NOT_SITUACAO_NFE', 'VARCHAR(10)')]
    FSituacao: string;
    [TCampo('NOT_VALOR', 'NUMERIC(12,4)')]
    FValor: Currency;
    [TCampo('NOT_DESCONTO', 'NUMERIC(9,2)')]
    FDesconto: Currency;
    [TCampo('NOT_BCICMS', 'NUMERIC(12,4)')]
    FBCIcms: Currency;
    [TCampo('NOT_VICMS', 'NUMERIC(12,4)')]
    FVIcms: Currency;
    [TCampo('NOT_VTPROD', 'NUMERIC(12,4)')]
    FVTProd: Currency;
    [TCampo('NOT_ARQ_NFE_ASSINADA', 'VARCHAR(200)')]
    FArqAssinada: string;
    [TCampo('NOT_ARQ_NFE_AUTORIZADA', 'VARCHAR(200)')]
    FArqAutorizada: string;
    [TCampo('NOT_NUM_RECIBO_NFE', 'VARCHAR(20)')]
    FNumRecibo: string;
    [TCampo('NOT_PROT_AUT_NFE', 'VARCHAR(20)')]
    FProtocolo: string;
    [TCampo('NOT_JUSTIF_CANC', 'VARCHAR(200)')]
    FJustificativa: string;
    [TCampo('NOT_OBS', 'VARCHAR(350)')]
    FObs: string;
    [TCampo('NOT_IND_EMISSAO', 'CHAR(1)')]
    FIndEmissao: string;
    [TCampo('NOT_OPER_CONSUM_FINAL', 'CHAR(1)')]
    FOperConsumFinal: string;
  public
    property Codigo: Integer read FCodigo write FCodigo;
    property Data: TDateTime read FData write FData;
    property DataES: TDateTime read FDataES write FDataES;
    property Hora: TDateTime read FHora write FHora;
    property CFOP: string read FCFOP write FCFOP;
    property NumeroNF: Integer read FNumeroNF write FNumeroNF;
    property Modelo: string read FModelo write FModelo;
    property Serie: string read FSerie write FSerie;
    property ChaveNFe: string read FChaveNFe write FChaveNFe;
    property Situacao: string read FSituacao write FSituacao;
    property Valor: Currency read FValor write FValor;
    property Desconto: Currency read FDesconto write FDesconto;
    property BCIcms: Currency read FBCIcms write FBCIcms;
    property VIcms: Currency read FVIcms write FVIcms;
    property VTProd: Currency read FVTProd write FVTProd;
    property ArqAssinada: string read FArqAssinada write FArqAssinada;
    property ArqAutorizada: string read FArqAutorizada write FArqAutorizada;
    property NumRecibo: string read FNumRecibo write FNumRecibo;
    property Protocolo: string read FProtocolo write FProtocolo;
    property Justificativa: string read FJustificativa write FJustificativa;
    property Obs: string read FObs write FObs;
    property IndEmissao: string read FIndEmissao write FIndEmissao;
    property OperConsumFinal: string read FOperConsumFinal write FOperConsumFinal;
  end;

// ============================================================
//  ITENS DA NFe
// ============================================================
  [TNomeTabela('NOT_ITENS', 'NI_CODIGO')]
  TModelNFeItem = class(TTabela)
  private
    [TCampo('NI_CODIGO', 'INTEGER')]
    FCodigo: Integer;
    [TCampo('NI_NOT', 'INTEGER')]
    FNotCodigo: Integer;
    [TCampo('NI_PRO', 'INTEGER')]
    FProduto: Integer;
    [TCampo('NI_NOME', 'VARCHAR(200)')]
    FNome: string;
    [TCampo('NI_QUANTIDADE', 'NUMERIC(18,6)')]
    FQuantidade: Double;
    [TCampo('NI_VALOR', 'NUMERIC(12,4)')]
    FValor: Currency;
    [TCampo('NI_CFOP', 'VARCHAR(6)')]
    FCFOP: string;
    [TCampo('NI_CST', 'VARCHAR(5)')]
    FCST: string;
    [TCampo('NI_ALIQ_ICMS', 'NUMERIC(5,2)')]
    FAliqIcms: Double;
    [TCampo('NI_BCICMS', 'NUMERIC(12,4)')]
    FBCIcms: Currency;
    [TCampo('NI_VICMS', 'NUMERIC(12,4)')]
    FVIcms: Currency;
    [TCampo('NI_UNIDADE', 'VARCHAR(10)')]
    FUnidade: string;
    [TCampo('NI_VDESC', 'NUMERIC(12,4)')]
    FDesconto: Currency;
    [TCampo('NI_CST_PIS', 'VARCHAR(6)')]
    FCST_PIS: string;
    [TCampo('NI_ALIQ_PIS', 'NUMERIC(5,2)')]
    FAliqPIS: Double;
    [TCampo('NI_CST_COFINS', 'VARCHAR(6)')]
    FCST_COFINS: string;
    [TCampo('NI_ALIQ_COFINS', 'NUMERIC(5,2)')]
    FAliqCOFINS: Double;
  public
    property Codigo: Integer read FCodigo write FCodigo;
    property NotCodigo: Integer read FNotCodigo write FNotCodigo;
    property Produto: Integer read FProduto write FProduto;
    property Nome: string read FNome write FNome;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property Valor: Currency read FValor write FValor;
    property CFOP: string read FCFOP write FCFOP;
    property CST: string read FCST write FCST;
    property AliqIcms: Double read FAliqIcms write FAliqIcms;
    property BCIcms: Currency read FBCIcms write FBCIcms;
    property VIcms: Currency read FVIcms write FVIcms;
    property Unidade: string read FUnidade write FUnidade;
    property Desconto: Currency read FDesconto write FDesconto;
    property CST_PIS: string read FCST_PIS write FCST_PIS;
    property AliqPIS: Double read FAliqPIS write FAliqPIS;
    property CST_COFINS: string read FCST_COFINS write FCST_COFINS;
    property AliqCOFINS: Double read FAliqCOFINS write FAliqCOFINS;
  end;

// ============================================================
//  NFC (NFCe)
// ============================================================
  [TNomeTabela('NFC', 'NFC_CODIGO')]
  TModelNFC = class(TTabela)
  private
    [TCampo('NFC_CODIGO', 'INTEGER')]
    FCodigo: Integer;
    [TCampo('NFC_CLI', 'INTEGER')]
    FCliente: Integer;
    [TCampo('NFC_NF', 'INTEGER')]
    FNumeroNF: Integer;
    [TCampo('NFC_CFOP', 'VARCHAR(8)')]
    FCFOP: string;
    [TCampo('NFC_DATA', 'DATE')]
    FData: TDateTime;
    [TCampo('NFC_HORA', 'TIME')]
    FHora: TDateTime;
    [TCampo('NFC_MODELO', 'VARCHAR(5)')]
    FModelo: string;
    [TCampo('NFC_SERIE', 'VARCHAR(5)')]
    FSerie: string;
    [TCampo('NFC_CHAVE_NFCE', 'VARCHAR(60)')]
    FChaveNFCe: string;
    [TCampo('NFC_SITUACAO_NFCE', 'VARCHAR(10)')]
    FSituacao: string;
    [TCampo('NFC_VALOR', 'NUMERIC(12,4)')]
    FValor: Currency;
    [TCampo('NFC_DESCONTO', 'NUMERIC(9,2)')]
    FDesconto: Currency;
    [TCampo('NFC_BCICMS', 'NUMERIC(12,4)')]
    FBCIcms: Currency;
    [TCampo('NFC_VICMS', 'NUMERIC(12,4)')]
    FVIcms: Currency;
    [TCampo('NFC_VTPROD', 'NUMERIC(12,4)')]
    FVTProd: Currency;
    [TCampo('NFC_ARQ_NFCE_ASSINADA', 'VARCHAR(200)')]
    FArqAssinada: string;
    [TCampo('NFC_ARQ_NFCE_AUTORIZADA', 'VARCHAR(200)')]
    FArqAutorizada: string;
    [TCampo('NFC_NUM_RECIBO_NFCE', 'VARCHAR(20)')]
    FNumRecibo: string;
    [TCampo('NFC_PROT_AUT_NFCE', 'VARCHAR(20)')]
    FProtocolo: string;
    [TCampo('NFC_JUSTIF_CANC', 'VARCHAR(200)')]
    FJustificativa: string;
    [TCampo('NFC_CPF_CLIENTE', 'VARCHAR(18)')]
    FCPFCliente: string;
    [TCampo('NFC_NOME_CLIENTE', 'VARCHAR(100)')]
    FNomeCliente: string;
    [TCampo('NFC_OPER_CONSUM_FINAL', 'CHAR(1)')]
    FOperConsumFinal: string;
    [TCampo('NFC_CONDICAO_PGTO', 'CHAR(1)')]
    FCondicaoPgto: string;
  public
    property Codigo: Integer read FCodigo write FCodigo;
    property Cliente: Integer read FCliente write FCliente;
    property NumeroNF: Integer read FNumeroNF write FNumeroNF;
    property CFOP: string read FCFOP write FCFOP;
    property Data: TDateTime read FData write FData;
    property Hora: TDateTime read FHora write FHora;
    property Modelo: string read FModelo write FModelo;
    property Serie: string read FSerie write FSerie;
    property ChaveNFCe: string read FChaveNFCe write FChaveNFCe;
    property Situacao: string read FSituacao write FSituacao;
    property Valor: Currency read FValor write FValor;
    property Desconto: Currency read FDesconto write FDesconto;
    property BCIcms: Currency read FBCIcms write FBCIcms;
    property VIcms: Currency read FVIcms write FVIcms;
    property VTProd: Currency read FVTProd write FVTProd;
    property ArqAssinada: string read FArqAssinada write FArqAssinada;
    property ArqAutorizada: string read FArqAutorizada write FArqAutorizada;
    property NumRecibo: string read FNumRecibo write FNumRecibo;
    property Protocolo: string read FProtocolo write FProtocolo;
    property Justificativa: string read FJustificativa write FJustificativa;
    property CPFCliente: string read FCPFCliente write FCPFCliente;
    property NomeCliente: string read FNomeCliente write FNomeCliente;
    property OperConsumFinal: string read FOperConsumFinal write FOperConsumFinal;
    property CondicaoPgto: string read FCondicaoPgto write FCondicaoPgto;
  end;

// ============================================================
//  ITENS DA NFCe
// ============================================================
  [TNomeTabela('NFC_PRO', 'NP_CODIGO')]
  TModelNFCItem = class(TTabela)
  private
    [TCampo('NP_CODIGO', 'INTEGER')]
    FCodigo: Integer;
    [TCampo('NP_NFC', 'INTEGER')]
    FNFCCodigo: Integer;
    [TCampo('NP_PRO', 'INTEGER')]
    FProduto: Integer;
    [TCampo('NP_NOME', 'VARCHAR(200)')]
    FNome: string;
    [TCampo('NP_QUANTIDADE', 'NUMERIC(18,6)')]
    FQuantidade: Double;
    [TCampo('NP_VALOR', 'NUMERIC(12,4)')]
    FValor: Currency;
    [TCampo('NP_CFOP', 'VARCHAR(6)')]
    FCFOP: string;
    [TCampo('NP_CST_ICMS', 'VARCHAR(5)')]
    FCST_ICMS: string;
    [TCampo('NP_ALIQ_ICMS', 'NUMERIC(5,2)')]
    FAliqIcms: Double;
    [TCampo('NP_BC_ICMS', 'NUMERIC(12,4)')]
    FBCIcms: Currency;
  public
    property Codigo: Integer read FCodigo write FCodigo;
    property NFCCodigo: Integer read FNFCCodigo write FNFCCodigo;
    property Produto: Integer read FProduto write FProduto;
    property Nome: string read FNome write FNome;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property Valor: Currency read FValor write FValor;
    property CFOP: string read FCFOP write FCFOP;
    property CST_ICMS: string read FCST_ICMS write FCST_ICMS;
    property AliqIcms: Double read FAliqIcms write FAliqIcms;
    property BCIcms: Currency read FBCIcms write FBCIcms;
  end;

implementation

end.
