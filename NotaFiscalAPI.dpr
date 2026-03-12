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
  Horse.ServerStatic,
  Horse.GBSwagger,
  UnitConstants in 'UnitConstants.pas',
  UnitDatabase in 'UnitDatabase.pas',
  UnitNotaFiscal.Model in 'Model\UnitNotaFiscal.Model.pas',
  UnitACBrNFe in 'ACBr\UnitACBrNFe.pas',
  NFCe.Controller in 'Controllers\NFCe.Controller.pas',
  NFe.Controller in 'Controllers\NFe.Controller.pas';

var
	LLogFileConfig: THorseLoggerConsoleConfig;

begin
//	ReportMemoryLeaksOnShutdown := True;
	LLogFileConfig              := THorseLoggerConsoleConfig.New.SetLogFormat('${request_clientip} [${time}] ${response_status}');
	try
		THorseLoggerManager.RegisterProvider(THorseLoggerProviderConsole.New());
		// middlewares
		THorse.Use(CORS);
		THorse.Use(Jhonson);
		THorse.Use(THorseLoggerManager.HorseCallback);
		THorse.Use(HandleException);
		THorse.Use(ServerStatic('site'));
		THorse.Use(HorseSwagger); // Access http://localhost:9000/swagger/doc/html

		// Inicio setup Documentacao
		Swagger.Info.Title('Servidor PDV Lanchonetes').Description('API Horse para o Sistema de PDV Lanchoentes').Contact.Name('Portal.com').Email('portalsoft.com@gmail.com').URL('http://www.portalsoft.net.br').&End.&End;

		// Controllers

		// start server
		THorse.Listen(9000,
			procedure
			begin
				Writeln('Servidor rodando na porta', ': ', THorse.Port.ToString);
				Readln;
			end);
	finally
		LLogFileConfig.Free;
	end;
end.
