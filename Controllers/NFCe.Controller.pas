unit NFCe.Controller;

interface

uses
  Horse,
  Horse.Commons,
  Classes,
  SysUtils,
  System.Json,
  UnitNotaFiscal.Model;

type
  TNFCeController = class
  public
    class procedure Registrar;
    class procedure Emitir(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure ConsultarStatus(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure Cancelar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure ObterXML(Req: THorseRequest; Res: THorseResponse; Next: TProc);
    class procedure ObterDANFE(Req: THorseRequest; Res: THorseResponse; Next: TProc);
  end;

implementation

uses UnitACBrNFe;

{ TNFCeController }

class procedure TNFCeController.Emitir(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  ACBrManager: TACBrNFeManager;
  Dados: TJSONObject;
  Chave: string;
begin
  try
    Dados := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
    ACBrManager := TACBrNFeManager.Create;
    try
      Chave := ACBrManager.EmitirNFCe(Req.Body);
      Res.Status(THTTPStatus.Created).Send<TJSONObject>
        (TJSONObject.Create
          .AddPair('sucesso', TJSONTrue.Create)
          .AddPair('chave', Chave));
    finally
      ACBrManager.Free;
    end;
  except
    on E: Exception do
      Res.Status(THTTPStatus.BadRequest).Send<TJSONObject>
        (TJSONObject.Create
          .AddPair('sucesso', TJSONFalse.Create)
          .AddPair('erro', E.Message));
  end;
end;

class procedure TNFCeController.ConsultarStatus(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  ACBrManager: TACBrNFeManager;
  Id: string;
  Status: string;
begin
  try
    Id := Req.Params['id'];
    if Id.IsEmpty then
      raise Exception.Create('Parâmetro "id" não informado!');

    ACBrManager := TACBrNFeManager.Create;
    try
      Status := ACBrManager.ConsultarStatus(Id);
      Res.Send<TJSONObject>
        (TJSONObject.Create
          .AddPair('sucesso', TJSONTrue.Create)
          .AddPair('chave', Id)
          .AddPair('status', Status));
    finally
      ACBrManager.Free;
    end;
  except
    on E: Exception do
      Res.Status(THTTPStatus.BadRequest).Send<TJSONObject>
        (TJSONObject.Create
          .AddPair('sucesso', TJSONFalse.Create)
          .AddPair('erro', E.Message));
  end;
end;

class procedure TNFCeController.Cancelar(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  ACBrManager: TACBrNFeManager;
  Id: string;
  Justificativa: string;
  DadosJson: TJSONObject;
begin
  try
    Id := Req.Params['id'];
    if Id.IsEmpty then
      raise Exception.Create('Parâmetro "id" não informado!');

    DadosJson := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
    if not Assigned(DadosJson) or not DadosJson.TryGetValue('justificativa', Justificativa) then
      Justificativa := 'Cancelamento de NFC-e';

    ACBrManager := TACBrNFeManager.Create;
    try
      if ACBrManager.Cancelar(Id, Justificativa) then
        Res.Send<TJSONObject>
          (TJSONObject.Create
            .AddPair('sucesso', TJSONTrue.Create)
            .AddPair('mensagem', 'NFC-e cancelada com sucesso'))
      else
        Res.Status(THTTPStatus.BadRequest).Send<TJSONObject>
          (TJSONObject.Create
            .AddPair('sucesso', TJSONFalse.Create)
            .AddPair('erro', 'Erro ao cancelar NFC-e'));
    finally
      ACBrManager.Free;
    end;
  except
    on E: Exception do
      Res.Status(THTTPStatus.BadRequest).Send<TJSONObject>
        (TJSONObject.Create
          .AddPair('sucesso', TJSONFalse.Create)
          .AddPair('erro', E.Message));
  end;
end;

class procedure TNFCeController.ObterXML(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  ACBrManager: TACBrNFeManager;
  Id: string;
  XML: string;
begin
  try
    Id := Req.Params['id'];
    if Id.IsEmpty then
      raise Exception.Create('Parâmetro "id" não informado!');

    ACBrManager := TACBrNFeManager.Create;
    try
      XML := ACBrManager.ObterXML(Id);
      Res.Send(XML);
    finally
      ACBrManager.Free;
    end;
  except
    on E: Exception do
      Res.Status(THTTPStatus.BadRequest).Send<TJSONObject>
        (TJSONObject.Create
          .AddPair('sucesso', TJSONFalse.Create)
          .AddPair('erro', E.Message));
  end;
end;

class procedure TNFCeController.ObterDANFE(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  ACBrManager: TACBrNFeManager;
  Id: string;
  Stream: TStream;
begin
  try
    Id := Req.Params['id'];
    if Id.IsEmpty then
      raise Exception.Create('Parâmetro "id" não informado!');

    ACBrManager := TACBrNFeManager.Create;
    try
      Stream := ACBrManager.ObterDANFE(Id);
      Res.Send<TStream>(Stream);
    finally
      ACBrManager.Free;
    end;
  except
    on E: Exception do
      Res.Status(THTTPStatus.BadRequest).Send<TJSONObject>
        (TJSONObject.Create
          .AddPair('sucesso', TJSONFalse.Create)
          .AddPair('erro', E.Message));
  end;
end;

class procedure TNFCeController.Registrar;
begin
  THorse.Post('/nfce', Emitir);
  THorse.Get('/nfce/status/:id', ConsultarStatus);
  THorse.Post('/nfce/:id/cancelar', Cancelar);
  THorse.Get('/nfce/:id/xml', ObterXML);
  THorse.Get('/nfce/:id/danfe', ObterDANFE);
end;

end.