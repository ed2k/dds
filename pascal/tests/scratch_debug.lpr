program scratch_debug;

{$mode objfpc}{$H+}

uses
  SysUtils, DDS_Types, DDS_SolverContext, DDS_Interface;

var
  table: DdTableResults;
  deal0_: DdTableDeal;
  holdings0: array[0..3, 0..3] of Cardinal;
  h, s: Integer;
  strain: Integer;
begin
  holdings0[0, 0] := $1000 or $0800 or $0040;
  holdings0[0, 1] := $0100 or $0080 or $0008;
  holdings0[0, 2] := $2000 or $0020;
  holdings0[0, 3] := $4000 or $0400 or $0200 or $0010 or $0004;
  
  holdings0[1, 0] := $2000 or $0040 or $0020 or $0004;
  holdings0[1, 1] := $0800 or $0200 or $0080;
  holdings0[1, 2] := $0400 or $0100 or $0008;
  holdings0[1, 3] := $4000 or $1000 or $0010;
  
  holdings0[2, 0] := $0800 or $0100 or $0020;
  holdings0[2, 1] := $4000 or $0400 or $0080 or $0040 or $0010;
  holdings0[2, 2] := $2000 or $1000 or $0200;
  holdings0[2, 3] := $0008 or $0004;
  
  holdings0[3, 0] := $0400 or $0200 or $0100;
  holdings0[3, 1] := $1000 or $0010;
  holdings0[3, 2] := $4000 or $0080 or $0040 or $0020 or $0004;
  holdings0[3, 3] := $2000 or $0800 or $0008;

  for h := 0 to 3 do
    for s := 0 to 3 do
      deal0_.cards[h, s] := holdings0[s, h];

  CalcDDtable(deal0_, @table);
  writeln('DD Table for Hand 0:');
  writeln('   N  E  S  W');
  for strain := 0 to 4 do
  begin
    case strain of
      0: write('S ');
      1: write('H ');
      2: write('D ');
      3: write('C ');
      4: write('N ');
    end;
    writeln(table.res_table[strain, 0]:3, table.res_table[strain, 1]:3, table.res_table[strain, 2]:3, table.res_table[strain, 3]:3);
  end;
end.
