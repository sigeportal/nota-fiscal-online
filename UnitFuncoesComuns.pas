unit UnitFuncoesComuns;

interface

type
  TFuncoesComuns = class
    class function GerarChaveNFCe(NumeroNFCe: Integer; SerieNFCe: Integer): string;
    class function GerarChaveNFe(NumeroNFe: Integer; SerieNFe: Integer): string;
    class function FormatarChave(Chave: string): string;
    class function ValidarChave(Chave: string): Boolean;
  end;

implementation

uses
  System.SysUtils;

{ TFuncoesComuns }

class function TFuncoesComuns.GerarChaveNFCe(NumeroNFCe: Integer; SerieNFCe: Integer): string;
begin
  // Implementação simplificada - será substituída por lógica real com ACBr
  Result := Format('%d%05d%05d', [Year(Now), SerieNFCe, NumeroNFCe]);
end;

class function TFuncoesComuns.GerarChaveNFe(NumeroNFe: Integer; SerieNFe: Integer): string;
begin
  // Implementação simplificada - será substituída por lógica real com ACBr
  Result := Format('%d%05d%05d', [Year(Now), SerieNFe, NumeroNFe]);
end;

class function TFuncoesComuns.FormatarChave(Chave: string): string;
begin
  // Formata chave: XXXX XXXX XXXX XXXX XXXX XXXX XXXX XXXX XXXX XXXX
  if Length(Chave) = 44 then
    Result := Copy(Chave, 1, 4) + ' ' + Copy(Chave, 5, 4) + ' ' + Copy(Chave, 9, 4) + ' ' +
              Copy(Chave, 13, 4) + ' ' + Copy(Chave, 17, 4) + ' ' + Copy(Chave, 21, 4) + ' ' +
              Copy(Chave, 25, 4) + ' ' + Copy(Chave, 29, 4) + ' ' + Copy(Chave, 33, 4) + ' ' +
              Copy(Chave, 37, 4) + ' ' + Copy(Chave, 41, 4)
  else
    Result := Chave;
end;

class function TFuncoesComuns.ValidarChave(Chave: string): Boolean;
begin
  // Validação básica de chave
  Result := Length(Chave) = 44;
end;

end.