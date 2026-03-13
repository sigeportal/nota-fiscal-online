unit App.Routes;

interface

type
	TAppRoutes = class
		class procedure Routes;
	end;

implementation

{ TAppRoutes }

uses
	Auth.Controller,
	Certificado.Controller,
	NFCe.Controller,
	NFe.Controller,
	Sefaz.Controller,
	Usuario.Controller;

class procedure TAppRoutes.Routes;
begin
	TAuthController.Registrar;
	TCertificadoController.Registrar;
	TNFeController.Registrar;
	TNFCeController.Registrar;
	TSefazController.Registrar;
	TUsuarioController.Registrar;
end;

end.
