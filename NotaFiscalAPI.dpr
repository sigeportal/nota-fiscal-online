program NotaFiscalAPI;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  Horse,
  Horse.CORS,
  Horse.Jhonson,
  Horse.HandleException,
  Horse.Logger,
  Horse.Logger.Provider.Console,
  Horse.GBSwagger,
  Horse.JWT,
  App.Config in 'config\App.Config.pas',
  Logger.Utils in 'utils\Logger.Utils.pas',
  Response.Utils in 'utils\Response.Utils.pas',
  Auth.Middleware in 'middlewares\Auth.Middleware.pas',
  JWT.Utils in 'security\JWT.Utils.pas',
  Models.NF in 'Model\Models.NF.pas',
  ACBr.Service in 'services\ACBr.Service.pas',
  Auth.Service in 'services\Auth.Service.pas',
  Certificado.Service in 'services\Certificado.Service.pas',
  Auth.Controller in 'controllers\Auth.Controller.pas',
  Certificado.Controller in 'controllers\Certificado.Controller.pas',
  NFe.Controller in 'Controllers\NFe.Controller.pas',
  NFCe.Controller in 'Controllers\NFCe.Controller.pas',
  Sefaz.Controller in 'controllers\Sefaz.Controller.pas',
  JOSE.Types.JSON,
  App.Routes in 'routes\App.Routes.pas',
  UnitDatabase in '..\..\FormsComuns\Classes\ServidoresUtils\Database\UnitDatabase.pas',
  UnitConstants in '..\..\FormsComuns\Classes\ServidoresUtils\Utils\UnitConstants.pas',
  Usuario.Controller in 'Controllers\Usuario.Controller.pas',
  Usuario.Service in 'services\Usuario.Service.pas';

var
  LLogConfig: THorseLoggerConsoleConfig;    

begin
  ReportMemoryLeaksOnShutdown := False;

  // Carrega configurações do arquivo INI
  TAppConfig.LoadConfig;

  // Configura logger
  TLogger.Setup;
  ///
  LLogConfig := THorseLoggerConsoleConfig.New
    .SetLogFormat('${request_clientip} [${time}] ${request_method} ${request_path} -> ${response_status}');
  try
    THorseLoggerManager.RegisterProvider(THorseLoggerProviderConsole.New);

    // ---- Middlewares ----
    THorse.Use(CORS);
    THorse.Use(Jhonson);
    THorse.Use(THorseLoggerManager.HorseCallback);
    THorse.Use(HandleException);
    THorse.Use(HorseSwagger);      // http://localhost:<porta>/swagger/doc/html
    THorse.Use(MiddlewareAuth);    // JWT em todas as rotas exceto as públicas

    // ---- Swagger Info ----
    Swagger
      .Info
        .Title('NotaFiscal Online API')
        .Description(
          'API REST para emissão de NF-e (modelo 55) e NFC-e (modelo 65) ' +
          'com integração ao ACBr e SEFAZ.')
        .Version('1.0.0')
        .Contact
          .Name('Portal Soft')
          .Email('contato@portalsoft.net.br')
          .URL('http://www.portalsoft.net.br')
        .&End
      .&End
      .AddBearerSecurity
       .AddCallBack(MiddlewareAuth)
      .&End;

    // ---- Controllers registram suas rotas via initialization ----
    //   Auth.Controller       -> POST /v1/auth/login
    //   Certificado.Controller-> POST /v1/certificados/upload
    //                            GET  /v1/certificados/:cnpj
    //   NFe.Controller        -> POST /v1/nfe
    //                            GET  /v1/nfe/:chave
    //                            POST /v1/nfe/:chave/cancelar
    //                            GET  /v1/nfe/:chave/xml
    //                            GET  /v1/nfe/:chave/danfe
    //   NFCe.Controller       -> POST /v1/nfce
    //                            GET  /v1/nfce/:chave
    //                            POST /v1/nfce/:chave/cancelar
    //                            GET  /v1/nfce/:chave/xml
    //                            GET  /v1/nfce/:chave/danfe
    //   Sefaz.Controller      -> GET  /v1/sefaz/status
    //                            POST /v1/sefaz/inutilizar

    // ---- Health check (rota pública sem autenticação) ----
    THorse.Get('/health',
      procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
      var
        LData: TJSONObject;
      begin
        LData := TJSONObject.Create;
        LData.AddPair('status',  'ok');
        LData.AddPair('version', '1.0.0');
        LData.AddPair('port',    TJSONNumber.Create(TAppConfig.Port));
        Res.Send<TJSONObject>(LData);
      end
    );

    //Registro das rotas dos controllers
  	TAppRoutes.Routes;
  
    THorse.Listen(TAppConfig.Port,
      procedure
      begin
        Writeln('=================================================');
        Writeln(' NotaFiscal Online API  -  porta ', THorse.Port.ToString);
        Writeln(' Swagger: http://localhost:', THorse.Port.ToString, '/swagger/doc/html');
        Writeln('=================================================');
        Readln;
      end
    );
  finally
    LLogConfig.Free;
  end;
end.
