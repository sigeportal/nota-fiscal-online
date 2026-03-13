unit Certificado.Service;

{
  Serviço de gerenciamento de certificados A1 (PFX)
  - Recebe certificado como Base64
  - Extrai informações (assunto, validade, thumbprint) via ACBr
  - Salva BLOB e metadados no banco CERTIFICADOS
  - Consulta status por CNPJ
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON, UnitConnection.Model.Interfaces;

type
  TCertificadoResult = record
    Sucesso       : Boolean;
    CodCertificado: Integer;
    CNPJ          : string;
    Assunto       : string;
    Emissor       : string;
    ValidadeIni   : TDateTime;
    ValidadeFim   : TDateTime;
    Thumbprint    : string;
    DiasRestantes : Integer;
    Valido        : Boolean;
    Erro          : string;
  end;

  TCertificadoService = class
  public
    class function UploadCertificado(
      const ABase64   : string;
      const ASenha    : string;
      const ACNPJ     : string;
      const AUsuarioId: Integer
    ): TCertificadoResult;

    class function StatusCertificado(const ACNPJ: string): TCertificadoResult;
  private
    class function HashSenha(const ASenha: string): string;
    class function ExtrairInfoCertificado(
      const ADados  : TBytes;
      const ASenha  : string;
      out   AAssunto: string;
      out   AEmissor: string;
      out   AValIni : TDateTime;
      out   AValFim : TDateTime;
      out   AThumb  : string
    ): Boolean;
  end;

implementation

uses
  System.NetEncoding,
  System.DateUtils,
  System.IOUtils,
  System.Hash,
  UnitDatabase,
  Logger.Utils,
  ACBrNFe, ACBrDFeSSL;

{ TCertificadoService }

class function TCertificadoService.HashSenha(const ASenha: string): string;
begin
  Result := THashSHA2.GetHashString(ASenha, THashSHA2.TSHA2Version.SHA256).ToLower;
end;

class function TCertificadoService.ExtrairInfoCertificado(
  const ADados  : TBytes;
  const ASenha  : string;
  out   AAssunto: string;
  out   AEmissor: string;
  out   AValIni : TDateTime;
  out   AValFim : TDateTime;
  out   AThumb  : string
): Boolean;
var
  LACBrNFe  : TACBrNFe;
  LTmpFile  : string;
begin
  Result   := False;
  AAssunto := '';
  AEmissor := '';
  AValIni  := 0;
  AValFim  := 0;
  AThumb   := '';

  LTmpFile := TPath.GetTempFileName + '.pfx';
  LACBrNFe := TACBrNFe.Create(nil);
  try
    TFile.WriteAllBytes(LTmpFile, ADados);

    with LACBrNFe.Configuracoes do
    begin
      Geral.SSLLib      := libOpenSSL;
      Geral.SSLCryptLib := cryOpenSSL;
      Geral.SSLHttpLib  := httpOpenSSL;
      Certificados.ArquivoPFX := LTmpFile;
      Certificados.Senha      := ASenha;
    end;

    LACBrNFe.SSL.CarregarCertificado;
    if LACBrNFe.SSL.CertificadoLido then
    begin
      AAssunto := LACBrNFe.SSL.CertSubjectName;
      AEmissor := LACBrNFe.SSL.CertCertificadora;
      AValIni  := LACBrNFe.SSL.CertDataVenc;
      AValFim  := LACBrNFe.SSL.CertDataVenc;
      AThumb   := LACBrNFe.SSL.CertIssuerName;
      Result := True;
    end;                 
  except
    on E: Exception do
    begin
      TLogger.Error('Certificado.Service.ExtrairInfo: %s', [E.Message]);
      Result := False;
    end;
  end;
  LACBrNFe.Free;

  if TFile.Exists(LTmpFile) then
    TFile.Delete(LTmpFile);
end;

class function TCertificadoService.UploadCertificado(
  const ABase64   : string;
  const ASenha    : string;
  const ACNPJ     : string;
  const AUsuarioId: Integer
): TCertificadoResult;
var
  LDados    : TBytes;
  LAssunto  : string;
  LEmissor  : string;
  LValIni   : TDateTime;
  LValFim   : TDateTime;
  LThumb    : string;
  LHashSenha: string;
  LQuery    : iQuery;
  LCodigo   : Integer;
  LCNPJNum  : string;
  LStream   : TMemoryStream;
begin
  Result.Sucesso := False;
  Result.Erro    := '';

  // Remove formatação do CNPJ
  LCNPJNum := ACNPJ;
  LCNPJNum := StringReplace(LCNPJNum, '.', '', [rfReplaceAll]);
  LCNPJNum := StringReplace(LCNPJNum, '/', '', [rfReplaceAll]);
  LCNPJNum := StringReplace(LCNPJNum, '-', '', [rfReplaceAll]);

  // Decodifica o Base64
  try
    LDados := TNetEncoding.Base64.DecodeStringToBytes(ABase64);
  except
    on E: Exception do
    begin
      Result.Erro := 'Base64 inválido: ' + E.Message;
      Exit;
    end;
  end;

  if Length(LDados) = 0 then
  begin
    Result.Erro := 'Arquivo do certificado está vazio';
    Exit;
  end;

  // Extrai informações do certificado
  if not ExtrairInfoCertificado(LDados, ASenha, LAssunto, LEmissor, LValIni, LValFim, LThumb) then
  begin
    Result.Erro := 'Não foi possível ler o certificado. Verifique o arquivo e a senha.';
    Exit;
  end;

  LHashSenha := HashSenha(ASenha);

  // Desativa certificados anteriores do mesmo CNPJ
  LQuery := TDatabase.Query;
  LQuery.Clear;
  LQuery.Add('UPDATE CERTIFICADOS SET CER_ATIVO = 0');
  LQuery.Add('WHERE CER_CNPJ = :CNPJ AND CER_ATIVO = 1');
  LQuery.AddParam('CNPJ', LCNPJNum);
  LQuery.ExecSQL;

  // Gera novo código
  LQuery.Clear;
  LQuery.Add('SELECT GEN_ID(GEN_CER_CODIGO, 1) FROM RDB$DATABASE');
  LQuery.Open;
  LCodigo := LQuery.DataSet.Fields[0].AsInteger;

  // Grava o novo certificado com os dados BLOB
  LStream := TMemoryStream.Create;
  try
    LStream.WriteBuffer(LDados[0], Length(LDados));
    LStream.Position := 0;

    LQuery.Clear;
    LQuery.Add('INSERT INTO CERTIFICADOS (');
    LQuery.Add('  CER_CODIGO, CER_USU, CER_CNPJ, CER_DADOS,');
    LQuery.Add('  CER_SENHA_HASH, CER_SENHA_CLARA, CER_ASSUNTO, CER_EMISSOR,');
    LQuery.Add('  CER_VALIDADE_INI, CER_VALIDADE_FIM, CER_THUMBPRINT,');
    LQuery.Add('  CER_ATIVO, CER_DATA_CRIACAO, CER_DATA_ATUALIZACAO');
    LQuery.Add(') VALUES (');
    LQuery.Add('  :CODIGO, :USU, :CNPJ, :DADOS,');
    LQuery.Add('  :SENHA_HASH, :SENHA_CLARA, :ASSUNTO, :EMISSOR,');
    LQuery.Add('  :VALINI, :VALFIM, :THUMB,');
    LQuery.Add('  1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP');
    LQuery.Add(')');
    LQuery.AddParam('CODIGO',      LCodigo);
    LQuery.AddParam('USU',         AUsuarioId);
    LQuery.AddParam('CNPJ',        LCNPJNum);
    LQuery.AddParam('DADOS',   LStream.ToString);
    LQuery.AddParam('SENHA_HASH',  LHashSenha);
    LQuery.AddParam('SENHA_CLARA', ASenha);
    LQuery.AddParam('ASSUNTO',     LAssunto);
    LQuery.AddParam('EMISSOR',     LEmissor);
    LQuery.AddParam('VALINI',      LValIni);
    LQuery.AddParam('VALFIM',      LValFim);
    LQuery.AddParam('THUMB',       LThumb);
    LQuery.ExecSQL;
  finally
    LStream.Free;
  end;

  // Preenche resultado
  Result.Sucesso        := True;
  Result.CodCertificado := LCodigo;
  Result.CNPJ           := LCNPJNum;
  Result.Assunto        := LAssunto;
  Result.Emissor        := LEmissor;
  Result.ValidadeIni    := LValIni;
  Result.ValidadeFim    := LValFim;
  Result.Thumbprint     := LThumb;
  Result.DiasRestantes  := DaysBetween(Now, LValFim);
  Result.Valido         := LValFim > Now;

  TLogger.Info('Certificado.Service: Upload OK CNPJ=%s codigo=%d validade=%s',
    [LCNPJNum, LCodigo, DateTimeToStr(LValFim)]);
end;

class function TCertificadoService.StatusCertificado(const ACNPJ: string): TCertificadoResult;
var
  LQuery  : iQuery;
  LCNPJNum: string;
begin
  Result.Sucesso := False;
  Result.Erro    := '';

  LCNPJNum := ACNPJ;
  LCNPJNum := StringReplace(LCNPJNum, '.', '', [rfReplaceAll]);
  LCNPJNum := StringReplace(LCNPJNum, '/', '', [rfReplaceAll]);
  LCNPJNum := StringReplace(LCNPJNum, '-', '', [rfReplaceAll]);

  LQuery := TDatabase.Query;
  LQuery.Clear;
  LQuery.Add('SELECT CER_CODIGO, CER_CNPJ, CER_ASSUNTO, CER_EMISSOR,');
  LQuery.Add('       CER_VALIDADE_INI, CER_VALIDADE_FIM, CER_THUMBPRINT');
  LQuery.Add('FROM CERTIFICADOS');
  LQuery.Add('WHERE CER_CNPJ = :CNPJ AND CER_ATIVO = 1');
  LQuery.Add('ORDER BY CER_DATA_CRIACAO DESC');
  LQuery.AddParam('CNPJ', LCNPJNum);
  LQuery.Open;

  if LQuery.DataSet.IsEmpty then
  begin
    Result.Erro := 'Nenhum certificado ativo encontrado para o CNPJ informado';
    Exit;
  end;

  Result.Sucesso        := True;
  Result.CodCertificado := LQuery.DataSet.FieldByName('CER_CODIGO').AsInteger;
  Result.CNPJ           := LQuery.DataSet.FieldByName('CER_CNPJ').AsString;
  Result.Assunto        := LQuery.DataSet.FieldByName('CER_ASSUNTO').AsString;
  Result.Emissor        := LQuery.DataSet.FieldByName('CER_EMISSOR').AsString;
  Result.ValidadeIni    := LQuery.DataSet.FieldByName('CER_VALIDADE_INI').AsDateTime;
  Result.ValidadeFim    := LQuery.DataSet.FieldByName('CER_VALIDADE_FIM').AsDateTime;
  Result.Thumbprint     := LQuery.DataSet.FieldByName('CER_THUMBPRINT').AsString;
  Result.DiasRestantes  := DaysBetween(Now, Result.ValidadeFim);
  Result.Valido         := Result.ValidadeFim > Now;
end;

end.
