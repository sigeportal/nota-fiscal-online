unit UnitNotaFiscal.Model;

interface

uses
  System.Json,
  Rest.Json,
  modules.portalorm.src.Model.UnitPortalORM.Model;

type

  [TNomeTabela('ITEM_NFCE', 'ITE_CODIGO')]
  TModelItemNFCe = class(TTabela)
  private
    [TCampo('ITE_CODIGO', 'VARCHAR(50)')]
    FCodigo: string;
    [TCampo('ITE_DESCRICAO', 'VARCHAR(255)')]
    FDescricao: string;
    [TCampo('ITE_QUANTIDADE', 'FLOAT')]
    FQuantidade: Double;
    [TCampo('ITE_VALOR_UNITARIO', 'NUMERIC(18,2)')]
    FValorUnitario: Currency;
    [TCampo('ITE_VALOR_TOTAL', 'NUMERIC(18,2)')]
    FValorTotal: Currency;
  public
    property Codigo: string read FCodigo write FCodigo;
    property Descricao: string read FDescricao write FDescricao;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property ValorUnitario: Currency read FValorUnitario write FValorUnitario;
    property ValorTotal: Currency read FValorTotal write FValorTotal;
  end;


  [TNomeTabela('DESTINATARIO', 'DES_CPF')]
  TModelDestinatario = class(TTabela)
  private
    [TCampo('DES_CPF', 'VARCHAR(14)')]
    FCPF: string;
    [TCampo('DES_CNPJ', 'VARCHAR(18)')]
    FCNPJ: string;
    [TCampo('DES_NOME', 'VARCHAR(255)')]
    FNome: string;
  public
    property CPF: string read FCPF write FCPF;
    property CNPJ: string read FCNPJ write FCNPJ;
    property Nome: string read FNome write FNome;
  end;

  [TNomeTabela('NOTA_FISCAL', 'NOT_ID')]
  TModelNotaFiscal = class(TTabela)
  private
    [TCampo('NOT_ID', 'INTEGER')]
    FId: Integer;
    [TCampo('NOT_NUMERO', 'VARCHAR(20)')]
    FNumero: string;
    [TCampo('NOT_SERIE', 'VARCHAR(10)')]
    FSerie: string;
    [TCampo('NOT_CHAVE', 'VARCHAR(60)')]
    FChave: string;
    [TCampo('NOT_STATUS', 'VARCHAR(20)')]
    FStatus: string;
    [TCampo('NOT_XML', 'BLOB')]
    FXML: string;
    [TCampo('NOT_DANFE', 'BLOB')]
    FDANFE: string;
    [TCampo('NOT_DATA_EMISSAO', 'TIMESTAMP')]
    FDataEmissao: TDateTime;
    [TCampo('NOT_VALOR_TOTAL', 'NUMERIC(18,2)')]
    FValorTotal: Currency;
    // Relacionamentos
    [TRelacionamento('ITEM_NFCE', 'ITE_ID_NOTA_FISCAL', 'NOT_ID', TModelItemNFCe, UmPraMuitos)]
    FItens: TArray<TModelItemNFCe>;
    [TRelacionamento('DESTINATARIO', 'DES_ID_NOTA_FISCAL', 'DES_CPF', TModelDestinatario, UmPraUm)]
    FDestinatario: TModelDestinatario;
  public
    property Id: Integer read FId write FId;
    property Numero: string read FNumero write FNumero;
    property Serie: string read FSerie write FSerie;
    property Chave: string read FChave write FChave;
    property Status: string read FStatus write FStatus;
    property XML: string read FXML write FXML;
    property DANFE: string read FDANFE write FDANFE;
    property DataEmissao: TDateTime read FDataEmissao write FDataEmissao;
    property ValorTotal: Currency read FValorTotal write FValorTotal;
    property Itens: TArray<TModelItemNFCe> read FItens write FItens;
    property Destinatario: TModelDestinatario read FDestinatario write FDestinatario;

    class function FromJsonString(JsonString: string): TModelNotaFiscal;
    function ToJsonString: string;
    destructor Destroy; override;
  end;

implementation

{ TModelNotaFiscal }

class function TModelNotaFiscal.FromJsonString(JsonString: string): TModelNotaFiscal;
begin
  Result := TJson.JsonToObject<TModelNotaFiscal>(JsonString);
end;

function TModelNotaFiscal.ToJsonString: string;
begin
  Result := TJson.ObjectToJsonString(Self);
end;

destructor TModelNotaFiscal.Destroy;
begin
  if Assigned(FDestinatario) then
    FDestinatario.Free;
  inherited;
end;

end.