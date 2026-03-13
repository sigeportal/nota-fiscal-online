unit Auth.Middleware;

{
  Middleware de autenticaÃ§Ã£o JWT para Horse
  Protege todas as rotas exceto /swagger e /v1/auth/login
}

interface

uses
  Horse,
  Horse.JWT,
  System.SysUtils,
  System.StrUtils,
  App.Config;

procedure MiddlewareAuth(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);

implementation

procedure MiddlewareAuth(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
var
  LPath: string;
begin
  LPath := Req.RawWebRequest.PathInfo;

  // Rotas públicas - sem autenticação
  if LPath.StartsWith('/swagger') or
     LPath.StartsWith('/v1/auth/login') or
     LPath.StartsWith('/v1/login') or
     LPath.StartsWith('/v1/usuarios') or
     LPath.StartsWith('/v1/sefaz/status') or
     LPath.StartsWith('/health') or
     LPath.StartsWith('/favicon') 
  then
    Next
  else
    HorseJWT(TAppConfig.JWTSecret)(Req, Res, Next);
end;

end.
