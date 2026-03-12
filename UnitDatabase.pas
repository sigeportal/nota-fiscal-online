unit UnitDatabase;

interface
uses
  UnitConnection.Model.Interfaces,
  UnitQuery.FireDAC.Model;

type
  TDatabase = class
    class function Query: iQuery;
    class function Connection: iConnection;
  end;

implementation

{ TDatabase }

uses
  UnitConstants,
  UnitFactory.Connection.Firedac,
  UnitConnection.Firedac.Model;

class function TDatabase.Connection: iConnection;
begin
  Result := TConnectionFiredac.New(TConstants.BancoDados);
end;

class function TDatabase.Query: iQuery;
begin
  Result := TFactoryConnectionFiredac.New(TConstants.BancoDados).Query;
end;

end.