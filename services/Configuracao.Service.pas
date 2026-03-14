unit Configuracao.Service;

{
  Serviço de configurações por usuário
  Cada usuário tem UM registro em CONFIGURACOES_USUARIO com:
    - Dados do emitente (nome, CNPJ, IE, endereço, CRT, cód. município)
    - NFe (UF, série, número inicial, ambiente)
    - NFCe (ID CSC, CSC, série, número inicial)
    - Responsável Técnico (CNPJ, contato, e-mail, fone, ID CSRT, CSRT)

  Usa PortalORM: BuscaPorCampo, SalvaNoBanco
  Para listagem usa PreencheListaWhere (UnitTabela.Helpers)
}

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections;

type
  TConfiguracaoResult = record
    Sucesso: Boolean;
    Erro   : string;
  end;

  TConfiguracaoService = class
  public
    /// Retorna as configurações do usuário como JSON.
    /// Cria um registro vazio se ainda não existir.
    class function Buscar(const AUsuarioId: Integer): TJSONObject;

    /// Salva (INSERT ou UPDATE) as configurações do usuário.
    class function Salvar(const AUsuarioId: Integer;
                          const ABody: TJSONObject): TConfiguracaoResult;
  end;

implementation

uses
  System.DateUtils,
  UnitDatabase,
  Models.NF,
  UnitTabela.Helpers,
  Logger.Utils;

{ TConfiguracaoService }

class function TConfiguracaoService.Buscar(const AUsuarioId: Integer): TJSONObject;
var
  LCfg : TModelConfiguracaoUsuario;
  LLista: TObjectList<TModelConfiguracaoUsuario>;
begin
  Result := nil;
  LCfg   := TModelConfiguracaoUsuario.Create(TDatabase.Connection);
  try
    // Busca via PreencheListaWhere do helper
    LLista := TObjectList<TModelConfiguracaoUsuario>(
      LCfg.PreencheListaWhere<TModelConfiguracaoUsuario>(
        'CFG_USU = ' + AUsuarioId.ToString
      )
    );
    try
      if (LLista <> nil) and (LLista.Count > 0) then
      begin
        LCfg.BuscaDadosTabela(LLista[0].Codigo);
      end
      else
      begin
        // Ainda não existe — retorna objeto vazio com usuario
        Result := TJSONObject.Create;
        Result.AddPair('usuario_id',         TJSONNumber.Create(AUsuarioId));
        Result.AddPair('uf',                 '');
        Result.AddPair('ambiente_producao',  TJSONNumber.Create(0));
        Result.AddPair('nfce_id_csc',        '');
        Result.AddPair('nfce_csc',           '');
        Result.AddPair('nfce_serie',         '1');
        Result.AddPair('nfce_numero_inicial', TJSONNumber.Create(1));
        Result.AddPair('nfe_serie',          '1');
        Result.AddPair('nfe_numero_inicial', TJSONNumber.Create(1));
        Result.AddPair('resp_cnpj',          '');
        Result.AddPair('resp_contato',       '');
        Result.AddPair('resp_email',         '');
        Result.AddPair('resp_fone',          '');
        Result.AddPair('resp_id_csrt',       '');
        Result.AddPair('resp_csrt',          '');
        Result.AddPair('emit_nome',          '');
        Result.AddPair('emit_cnpj',          '');
        Result.AddPair('emit_ie',            '');
        Result.AddPair('emit_endereco',      '');
        Result.AddPair('emit_numero',        '');
        Result.AddPair('emit_bairro',        '');
        Result.AddPair('emit_municipio',     '');
        Result.AddPair('emit_cep',           '');
        Result.AddPair('emit_telefone',      '');
        Result.AddPair('emit_crt',           TJSONNumber.Create(1));
        Result.AddPair('emit_cod_municipio', '');
        Exit;
      end;
    finally
      if Assigned(LLista) then
        LLista.Free;
    end;

    // Monta JSON com os dados encontrados
    Result := TJSONObject.Create;
    Result.AddPair('id',                   TJSONNumber.Create(LCfg.Codigo));
    Result.AddPair('usuario_id',           TJSONNumber.Create(LCfg.Usuario));
    Result.AddPair('uf',                   LCfg.UF);
    Result.AddPair('ambiente_producao',    TJSONNumber.Create(LCfg.AmbienteProducao));
    Result.AddPair('nfce_id_csc',          LCfg.NFCeIdCSC);
    Result.AddPair('nfce_csc',             LCfg.NFCeCSC);
    Result.AddPair('nfce_serie',           LCfg.NFCeSerie);
    Result.AddPair('nfce_numero_inicial',  TJSONNumber.Create(LCfg.NFCeNumeroInicial));
    Result.AddPair('nfe_serie',            LCfg.NFeSerie);
    Result.AddPair('nfe_numero_inicial',   TJSONNumber.Create(LCfg.NFeNumeroInicial));
    Result.AddPair('resp_cnpj',            LCfg.RespCNPJ);
    Result.AddPair('resp_contato',         LCfg.RespContato);
    Result.AddPair('resp_email',           LCfg.RespEmail);
    Result.AddPair('resp_fone',            LCfg.RespFone);
    Result.AddPair('resp_id_csrt',         LCfg.RespIdCSRT);
    Result.AddPair('resp_csrt',            LCfg.RespCSRT);
    Result.AddPair('emit_nome',            LCfg.EmitNome);
    Result.AddPair('emit_cnpj',            LCfg.EmitCNPJ);
    Result.AddPair('emit_ie',              LCfg.EmitIE);
    Result.AddPair('emit_endereco',        LCfg.EmitEndereco);
    Result.AddPair('emit_numero',          LCfg.EmitNumero);
    Result.AddPair('emit_bairro',          LCfg.EmitBairro);
    Result.AddPair('emit_municipio',       LCfg.EmitMunicipio);
    Result.AddPair('emit_cep',             LCfg.EmitCEP);
    Result.AddPair('emit_telefone',        LCfg.EmitTelefone);
    Result.AddPair('emit_crt',             TJSONNumber.Create(LCfg.EmitCRT));
    Result.AddPair('emit_cod_municipio',   LCfg.EmitCodMunicipio);
  finally
    LCfg.Free;
  end;
end;

class function TConfiguracaoService.Salvar(const AUsuarioId: Integer;
  const ABody: TJSONObject): TConfiguracaoResult;
var
  LCfg  : TModelConfiguracaoUsuario;
  LLista: TObjectList<TModelConfiguracaoUsuario>;
  LValor: string;
  LNum  : Integer;
  LIsNovo: Boolean;
begin
  Result.Sucesso := False;
  Result.Erro    := '';

  LCfg := TModelConfiguracaoUsuario.Create(TDatabase.Connection);
  try
    // Verifica se já existe configuração para o usuário
    LLista := TObjectList<TModelConfiguracaoUsuario>(
      LCfg.PreencheListaWhere<TModelConfiguracaoUsuario>(
        'CFG_USU = ' + AUsuarioId.ToString
      )
    );
    try
      LIsNovo := (LLista = nil) or (LLista.Count = 0);
      if not LIsNovo then
        LCfg.BuscaDadosTabela(LLista[0].Codigo);
    finally
      if Assigned(LLista) then
        LLista.Free;
    end;

    // Preenche campos do body (somente os presentes)
    LCfg.Usuario := AUsuarioId;

    if ABody.TryGetValue<string>('uf', LValor) then
      LCfg.UF := LValor;
    if ABody.TryGetValue<Integer>('ambiente_producao', LNum) then
      LCfg.AmbienteProducao := LNum;

    // NFCe
    if ABody.TryGetValue<string>('nfce_id_csc', LValor) then
      LCfg.NFCeIdCSC := LValor;
    if ABody.TryGetValue<string>('nfce_csc', LValor) then
      LCfg.NFCeCSC := LValor;
    if ABody.TryGetValue<string>('nfce_serie', LValor) then
      LCfg.NFCeSerie := LValor;
    if ABody.TryGetValue<Integer>('nfce_numero_inicial', LNum) then
      LCfg.NFCeNumeroInicial := LNum;

    // NFe
    if ABody.TryGetValue<string>('nfe_serie', LValor) then
      LCfg.NFeSerie := LValor;
    if ABody.TryGetValue<Integer>('nfe_numero_inicial', LNum) then
      LCfg.NFeNumeroInicial := LNum;

    // Responsável Técnico
    if ABody.TryGetValue<string>('resp_cnpj', LValor) then
      LCfg.RespCNPJ := LValor;
    if ABody.TryGetValue<string>('resp_contato', LValor) then
      LCfg.RespContato := LValor;
    if ABody.TryGetValue<string>('resp_email', LValor) then
      LCfg.RespEmail := LValor;
    if ABody.TryGetValue<string>('resp_fone', LValor) then
      LCfg.RespFone := LValor;
    if ABody.TryGetValue<string>('resp_id_csrt', LValor) then
      LCfg.RespIdCSRT := LValor;
    if ABody.TryGetValue<string>('resp_csrt', LValor) then
      LCfg.RespCSRT := LValor;

    // Emitente
    if ABody.TryGetValue<string>('emit_nome', LValor) then
      LCfg.EmitNome := LValor;
    if ABody.TryGetValue<string>('emit_cnpj', LValor) then
      LCfg.EmitCNPJ := LValor;
    if ABody.TryGetValue<string>('emit_ie', LValor) then
      LCfg.EmitIE := LValor;
    if ABody.TryGetValue<string>('emit_endereco', LValor) then
      LCfg.EmitEndereco := LValor;
    if ABody.TryGetValue<string>('emit_numero', LValor) then
      LCfg.EmitNumero := LValor;
    if ABody.TryGetValue<string>('emit_bairro', LValor) then
      LCfg.EmitBairro := LValor;
    if ABody.TryGetValue<string>('emit_municipio', LValor) then
      LCfg.EmitMunicipio := LValor;
    if ABody.TryGetValue<string>('emit_cep', LValor) then
      LCfg.EmitCEP := LValor;
    if ABody.TryGetValue<string>('emit_telefone', LValor) then
      LCfg.EmitTelefone := LValor;
    if ABody.TryGetValue<Integer>('emit_crt', LNum) then
      LCfg.EmitCRT := LNum;
    if ABody.TryGetValue<string>('emit_cod_municipio', LValor) then
      LCfg.EmitCodMunicipio := LValor;

    if LIsNovo then
      LCfg.DataCriacao := Now;
    LCfg.DataAtualizacao := Now;

    LCfg.SalvaNoBanco(1);
    Result.Sucesso := True;

    TLogger.Info('Configuracao.Service: configurações do usuário %d salvas',
                 [AUsuarioId]);
  finally
    LCfg.Free;
  end;
end;

end.
