# Nota Fiscal Online API

API REST em Delphi para emissão de NFC-e e NFe usando Horse e ACBr.

## Estrutura do Projeto

```
nota-fiscal-online/
├── NotaFiscalConsole/          # Executável principal
│   ├── NotaFiscalAPI.dpr       # Projeto Delphi
│   ├── NotaFiscalAPI.dproj     # Arquivo de projeto
│   └── Win32/
│       └── Debug/              # Saída compilada
├── Shared/
│   ├── UnitConstants.pas        # Constantes e configurações
│   ├── UnitDatabase.pas         # Acesso ao banco de dados
│   ├── UnitFuncoesComuns.pas    # Funções compartilhadas
│   ├── UnitFunctions.pas        # Utilitários gerais
│   ├── Model/
│   │   └── UnitNotaFiscal.Model.pas
│   ├── Controllers/
│   │   ├── NFCe.Controller.pas
│   │   └── NFe.Controller.pas
│   └── ACBr/
│       └── UnitACBrNFe.pas
└── README.md
```

## Pré-requisitos

- Delphi RAD Studio (2016 ou superior)
- Horse Framework (instalar via Boss)
- ACBr (instalar via GitHub: https://github.com/fs-opensource/ACBr)
- FireDAC (incluído no Delphi)
- Certificado Digital (.pfx ou .pem)

## Instalação das Dependências

### 1. Horse Framework

```bash
boss install horse
boss install horse-cors
boss install horse-json
boss install horse-exception-handler
boss install horse-logger
boss install horse-static
boss install horse-swagger
```

### 2. ACBr

Clonar o repositório ACBr e adicionar ao SearchPath do Delphi:
```bash
git clone https://github.com/fs-opensource/ACBr.git
```

Adicionar em Tools > Options > Environment Options > Delphi Options > Library:
- `ACBr\Fontes\ACBrComum`
- `ACBr\Fontes\ACBrNFe`
- E outras units necessárias

## Configuração

1. Copie e renomeie `NotaFiscalAPI.ini.example` para `NotaFiscalAPI.ini`
2. Configure os seguintes parâmetros:

```ini
[CONEXAO]
DB=PRINCIPAL.FDB

[SEFAZ]
AMBIENTE=2
CERTIFICADO=C:\Caminho\Para\Certificado.pfx
SENHA_CERTIFICADO=sua_senha

[API]
PORTA=9000
```

## Build e Execução

### No Delphi IDE
1. Abra `NotaFiscalConsole\NotaFiscalAPI.dproj`
2. Build > Build All
3. Run > Run (F9)

### Via Command Line
```bash
cd NotaFiscalConsole
dcc32 NotaFiscalAPI.dpr
NotaFiscalAPI.exe
```

## Endpoints

### NFC-e

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/nfce` | Emitir NFC-e |
| GET | `/nfce/status/:id` | Consultar status |
| POST | `/nfce/:id/cancelar` | Cancelar NFC-e |
| GET | `/nfce/:id/xml` | Obter XML |
| GET | `/nfce/:id/danfe` | Obter DANFE (PDF) |

### NFe

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| POST | `/nfe` | Emitir NFe |
| GET | `/nfe/status/:id` | Consultar status |
| POST | `/nfe/:id/cancelar` | Cancelar NFe |
| GET | `/nfe/:id/xml` | Obter XML |
| GET | `/nfe/:id/danfe` | Obter DANFE (PDF) |

## Exemplo de Requisição

### POST /nfce

```json
{
  "numero": "123",
  "serie": "1",
  "dataEmissao": "2026-03-04",
  "valorTotal": 150.00,
  "destinatario": {
    "cpf": "12345678900",
    "nome": "João da Silva"
  },
  "itens": [
    {
      "codigo": "001",
      "descricao": "Produto Teste",
      "quantidade": 2.00,
      "valorUnitario": 75.00,
      "valorTotal": 150.00
    }
  ]
}
```

### Resposta de Sucesso (201)

```json
{
  "sucesso": true,
  "chave": "35260301234567000167590010000000011234567890"
}
```

### Resposta de Erro (400)

```json
{
  "sucesso": false,
  "erro": "Mensagem de erro descritiva"
}
```

## Documentação Swagger

Após iniciar o servidor, acesse:
```
http://localhost:9000/swagger/doc/html
```

## Logs

Os logs são salvos em `NotaFiscalAPI.log` no mesmo diretório do executável.

## Estrutura de Controllers

Os controllers seguem o padrão do `Servidor/ServidorConsole`:

```delphi
type
  TNFCeController = class
  public
    class procedure Registrar;
    class procedure Emitir(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure ConsultarStatus(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    // ...
  end;
```

## Estrutura de Models

Models implementam serialização JSON via Rest.Json:

```delphi
type
  TModelNotaFiscal = class
  public
    class function FromJsonString(JsonString: string): TModelNotaFiscal;
    function ToJsonString: string;
  end;
```

## Middleware

- **CORS**: Aceita requisições de qualquer origem
- **Jhonson**: Serialização JSON
- **HandleException**: Tratamento automático de exceções
- **Logger**: Logging em console
- **ServerStatic**: Serve arquivos estáticos da pasta `site/`
- **GBSwagger**: Documentação Swagger automática

## TODO (Implementação Real do ACBr)

- [ ] Integrar TACBrNFe com componentes reais
- [ ] Implementar validação de certificado digital
- [ ] Integrar com SEFAZ (ambiente de testes e produção)
- [ ] Implementar persistência de XMLs emitidos
- [ ] Adicionar suporte a contingência
- [ ] Implementar geração real de DANFE em PDF
- [ ] Adicionar suporte a múltiplos documentos em lote
- [ ] Implementar webhook para notificações de status

## Suporte

Para dúvidas ou problemas, contate: suporte@portalsystems.com.br

## Licença

Propriedade de Portal Systems. Todos os direitos reservados.