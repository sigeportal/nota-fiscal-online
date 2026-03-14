unit UnitFunctions;

interface

uses
  System.SysUtils,
  System.DateUtils;

type
  TFunctions = class
    class function StringToDate(Value: string): TDateTime;
    class function DateToString(Value: TDateTime): string;
    class function CurrencyToString(Value: Currency): string;
    class function StringToCurrency(Value: string): Currency;
    class function BooleanToString(Value: Boolean): string;
    class function StringToBoolean(Value: string): Boolean;
  end;

implementation

{ TFunctions }

class function TFunctions.StringToDate(Value: string): TDateTime;
begin
  try
    Result := StrToDate(Value, FormatSettings);
  except
    Result := 0;
  end;
end;

class function TFunctions.DateToString(Value: TDateTime): string;
begin
  Result := FormatDateTime('dd/mm/yyyy', Value);
end;

class function TFunctions.CurrencyToString(Value: Currency): string;
begin
  Result := FormatCurr('0.00', Value);
end;

class function TFunctions.StringToCurrency(Value: string): Currency;
begin
  try
    Result := StrToCurr(Value);
  except
    Result := 0;
  end;
end;

class function TFunctions.BooleanToString(Value: Boolean): string;
begin
  if Value then
    Result := 'S'
  else
    Result := 'N';
end;

class function TFunctions.StringToBoolean(Value: string): Boolean;
begin
  Result := UpperCase(Value) = 'S';
end;

end.