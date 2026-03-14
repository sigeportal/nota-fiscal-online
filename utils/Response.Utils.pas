unit Response.Utils;


//  Utilitário de respostas padronizadas para a API
//  Padrão: { success: bool, data: ..., error: { code, message } }


interface

uses
  System.JSON,
  System.SysUtils;

type
  TResponseUtils = class
  public
    class function Success(const AMessage: string = '';
                           AData: TJSONValue = nil): TJSONObject;
    class function SuccessData(AData: TJSONValue): TJSONObject;
    class function Error(const AMessage: string;
                         ACode: Integer = 400): TJSONObject;
    class function ValidationError(const AErrors: TJSONArray): TJSONObject;
    class function NotFound(const AResource: string = 'Recurso'): TJSONObject;
    class function Unauthorized(const AMessage: string = 'Não autorizado'): TJSONObject;
    class function InternalError(const AMessage: string): TJSONObject;
  end;

implementation

{ TResponseUtils }

class function TResponseUtils.Success(const AMessage: string; AData: TJSONValue): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('success', TJSONBool.Create(True));

  if not AMessage.IsEmpty then
    Result.AddPair('message', AMessage);

  if Assigned(AData) then
    Result.AddPair('data', AData)
  else
    Result.AddPair('data', TJSONNull.Create);
end;

class function TResponseUtils.SuccessData(AData: TJSONValue): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('success', TJSONBool.Create(True));
  if Assigned(AData) then
    Result.AddPair('data', AData)
  else
    Result.AddPair('data', TJSONNull.Create);
end;

class function TResponseUtils.Error(const AMessage: string; ACode: Integer): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('success', TJSONBool.Create(False));
  Result.AddPair('error',
    TJSONObject.Create
      .AddPair('code',    TJSONNumber.Create(ACode))
      .AddPair('message', AMessage));
end;

class function TResponseUtils.ValidationError(const AErrors: TJSONArray): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('success', TJSONBool.Create(False));
  Result.AddPair('error',
    TJSONObject.Create
      .AddPair('code',    TJSONNumber.Create(422))
      .AddPair('message', 'Erro de validação')
      .AddPair('errors',  AErrors));
end;

class function TResponseUtils.NotFound(const AResource: string): TJSONObject;
begin
  Result := Error(AResource + ' não encontrado', 404);
end;

class function TResponseUtils.Unauthorized(const AMessage: string): TJSONObject;
begin
  Result := Error(AMessage, 401);
end;

class function TResponseUtils.InternalError(const AMessage: string): TJSONObject;
begin
  Result := Error('Erro interno: ' + AMessage, 500);
end;

end.
