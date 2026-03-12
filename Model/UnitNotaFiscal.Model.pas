unit UnitNotaFiscal.Model;

interface

uses
  System.Json,
  Rest.Json;

type
  TModelItemNFCe = class
  private
    FCodigo: string;
    FDescricao: string;
    FQuantidade: Double;
    FValorUnitario: Currency;
    FValorTotal: Currency;
  public
    property Codigo: string read FCodigo write FCodigo;
    property Descricao: string read FDescricao write FDescricao;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property ValorUnitario: Currency read FValorUnitario write FValorUnitario;
    property ValorTotal: Currency read FValorTotal write FValorTotal;
  end;

  TModelDestinatario = class
  private
    FCPF: string;
    FCNPJ: string;
    FNome: string;
  public
    property CPF: string read FCPF write FCPF;
    property CNPJ: string read FCNPJ write FCNPJ;
    property Nome: string read FNome write FNome;
  end;

  TModelNotaFiscal = class
  private
    FId: Integer;
    FNumero: string;
    FSerie: string;
    FChave: string;
    FStatus: string;
    FXML: string;
    FDANFE: string;
    FDataEmissao: TDateTime;
    FValorTotal: Currency;
    FItens: TArray<TModelItemNFCe>;
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