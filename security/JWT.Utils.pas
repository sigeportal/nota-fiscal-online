unit JWT.Utils;

{
  Utilitários JWT para geração e validação de tokens
  Usa biblioteca JOSE (horse-jwt)
}

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON;

type
  TJWTUtils = class
  public
    /// <summary>Gera um token JWT com o subject informado (login do usuário)</summary>
    class function GenerateToken(const AUserId: Integer; const ALogin: string): string;
    /// <summary>Retorna o subject (login) do token</summary>
    class function GetSubject(const AToken: string): string;
  end;

implementation

uses
  JOSE.Core.JWT,
  JOSE.Core.Builder,
  App.Config;

{ TJWTUtils }

class function TJWTUtils.GenerateToken(const AUserId: Integer; const ALogin: string): string;
var
  LJWT  : TJWT;
  LHours: Integer;
begin
  LJWT := TJWT.Create;
  try
    LHours := TAppConfig.JWTExpiration;
    if LHours <= 0 then
      LHours := 8;

    LJWT.Claims.Issuer     := 'NotaFiscalAPI';
    LJWT.Claims.Subject    := ALogin;
    LJWT.Claims.IssuedAt   := Now;
    LJWT.Claims.Expiration := IncHour(Now, LHours);
    // Claim customizado com o id do usuário
    LJWT.Claims.JSON.AddPair('user_id', TJSONNumber.Create(AUserId));

    Result := TJOSE.SHA256CompactToken(TAppConfig.JWTSecret, LJWT);
  finally
    LJWT.Free;
  end;
end;

class function TJWTUtils.GetSubject(const AToken: string): string;
var
  LJWT: TJWT;
begin
  Result := '';
  LJWT := TJOSE.Verify(TAppConfig.JWTSecret, AToken);
  if Assigned(LJWT) then
  try
    Result := LJWT.Claims.Subject;
  finally
    LJWT.Free;
  end;
end;

end.
