unit test_calc_par;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  DDS_Types, DDS_SolverContext, DDS_Interface;

const
  R2 = $0004;
  R3 = $0008;
  R4 = $0010;
  R5 = $0020;
  R6 = $0040;
  R7 = $0080;
  R8 = $0100;
  R9 = $0200;
  RT = $0400;
  RJ = $0800;
  RQ = $1000;
  RK = $2000;
  RA = $4000;

type
  TCalcParTests = class(TTestCase)
  private
    deal0_: DdTableDeal;
    deal1_: DdTableDeal;
    deal2_: DdTableDeal;
    expected_par_score_: array[0..2, 0..1] of string;
    expected_par_contracts_: array[0..2, 0..1] of string;
    vulnerability_: array[0..2] of LongInt;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestBasicCalcParHand0;
    procedure TestBasicCalcParHand1;
    procedure TestBasicCalcParHand2;
    procedure TestCalcParWithContext;
    procedure TestContextReuseMultipleCalls;
    procedure TestCalcParFromTableHand0;
    procedure TestVulnerabilityVariations;
    procedure TestTableResultsPopulated;
    procedure TestCalcParFromTableVulnerability;
    procedure TestInvalidVulnerability;
    procedure TestEmptyDealHandling;
    procedure TestConsistencyCalcParVsFromTable;
    procedure TestCalcParContextOverloadMatchesNonContext;
    procedure TestContextReusePerformance;
  end;

implementation

procedure TCalcParTests.SetUp;
const
  holdings0: array[0..3, 0..3] of Cardinal = (
    // North           East            South         West
    (RQ or RJ or R6,         R8 or R7 or R3,       RK or R5,        RA or RT or R9 or R4 or R2),  // Spades
    (RK or R6 or R5 or R2,      RJ or R9 or R7,       RT or R8 or R3,     RA or RQ or R4),         // Hearts  
    (RJ or R8 or R5,         RA or RT or R7 or R6 or R4, RK or RQ or R9,     R3 or R2),            // Diamonds
    (RT or R9 or R8,         RQ or R4,          RA or R7 or R6 or R5 or R2, RK or RJ or R3)        // Clubs
  );
  holdings1: array[0..3, 0..3] of Cardinal = (
    (RA or RK or R9 or R6,      RQ or RJ or RT or R5 or R4 or R3 or R2, 0,            R8 or R7),        // Spades
    (RK or RQ or R8,         RT,                   RJ or R9 or R7 or R5 or R4 or R3, RA or R6 or R2),     // Hearts
    (RA or R9 or R8,         R6,                   RK or R7 or R5 or R3 or R2, RQ or RJ or RT or R4),   // Diamonds
    (RK or R6 or R3,         RQ or RJ or R8 or R2,          R9 or R4,        RA or RT or R7 or R5)       // Clubs
  );
  holdings2: array[0..3, 0..3] of Cardinal = (
    (R7 or R3,            RQ or RT or R6,       R5,           RA or RK or RJ or R9 or R8 or R4 or R2),  // Spades
    (RQ or RJ or RT,         R8 or R7 or R6,       RA or R9 or R5 or R4 or R3 or R2, RK),              // Hearts
    (RA or RQ or R5 or R4,      RK or RJ or R9,       R7 or R6 or R3 or R2,  RT or R8),                // Diamonds
    (RT or R7 or R5 or R2,      RA or RQ or R8 or R4,    RK or R6,        RJ or R9 or R3)               // Clubs
  );
var
  h, s: Integer;
begin
  for h := 0 to 3 do
  begin
    for s := 0 to 3 do
    begin
      deal0_.cards[h, s] := holdings0[s, h];
      deal1_.cards[h, s] := holdings1[s, h];
      deal2_.cards[h, s] := holdings2[s, h];
    end;
  end;

  expected_par_score_[0, 0] := 'NS -110';
  expected_par_score_[0, 1] := 'EW 110';
  expected_par_score_[1, 0] := 'NS 100';
  expected_par_score_[1, 1] := 'EW -100';
  expected_par_score_[2, 0] := 'NS -300';
  expected_par_score_[2, 1] := 'EW 300';

  expected_par_contracts_[0, 0] := 'NS:EW 2S';
  expected_par_contracts_[0, 1] := 'EW:EW 2S';
  expected_par_contracts_[1, 0] := 'NS:EW 4Sx';
  expected_par_contracts_[1, 1] := 'EW:EW 4Sx';
  expected_par_contracts_[2, 0] := 'NS:NS 5Hx';
  expected_par_contracts_[2, 1] := 'EW:NS 5Hx';

  vulnerability_[0] := 0; // None
  vulnerability_[1] := 2; // NS
  vulnerability_[2] := 0; // None
end;

procedure TCalcParTests.TearDown;
begin
end;

procedure TCalcParTests.TestBasicCalcParHand0;
var
  table: DdTableResults;
  par: ParResults;
  result: LongInt;
begin
  result := calc_par(deal0_, vulnerability_[0], @table, @par);
  AssertEquals('calc_par should return RETURN_NO_FAULT', RETURN_NO_FAULT, result);
  AssertEquals('par score NS should match', expected_par_score_[0, 0], PChar(@par.par_score[0]));
  AssertEquals('par score EW should match', expected_par_score_[0, 1], PChar(@par.par_score[1]));
  AssertEquals('par contract NS should match', expected_par_contracts_[0, 0], PChar(@par.par_contracts_string[0]));
  AssertEquals('par contract EW should match', expected_par_contracts_[0, 1], PChar(@par.par_contracts_string[1]));
end;

procedure TCalcParTests.TestBasicCalcParHand1;
var
  table: DdTableResults;
  par: ParResults;
  result: LongInt;
begin
  result := calc_par(deal1_, vulnerability_[1], @table, @par);
  AssertEquals('calc_par should return RETURN_NO_FAULT', RETURN_NO_FAULT, result);
  AssertEquals('par score NS should match', expected_par_score_[1, 0], PChar(@par.par_score[0]));
  AssertEquals('par score EW should match', expected_par_score_[1, 1], PChar(@par.par_score[1]));
  AssertEquals('par contract NS should match', expected_par_contracts_[1, 0], PChar(@par.par_contracts_string[0]));
  AssertEquals('par contract EW should match', expected_par_contracts_[1, 1], PChar(@par.par_contracts_string[1]));
end;

procedure TCalcParTests.TestBasicCalcParHand2;
var
  table: DdTableResults;
  par: ParResults;
  result: LongInt;
begin
  result := calc_par(deal2_, vulnerability_[2], @table, @par);
  AssertEquals('calc_par should return RETURN_NO_FAULT', RETURN_NO_FAULT, result);
  AssertEquals('par score NS should match', expected_par_score_[2, 0], PChar(@par.par_score[0]));
  AssertEquals('par score EW should match', expected_par_score_[2, 1], PChar(@par.par_score[1]));
  AssertEquals('par contract NS should match', expected_par_contracts_[2, 0], PChar(@par.par_contracts_string[0]));
  AssertEquals('par contract EW should match', expected_par_contracts_[2, 1], PChar(@par.par_contracts_string[1]));
end;

procedure TCalcParTests.TestCalcParWithContext;
var
  ctx: TSolverContext;
  table: DdTableResults;
  par: ParResults;
  result: LongInt;
begin
  ctx := TSolverContext.Create;
  try
    result := calc_par(ctx, deal0_, vulnerability_[0], @table, @par);
    AssertEquals('calc_par with context should return RETURN_NO_FAULT', RETURN_NO_FAULT, result);
    AssertEquals('par score NS should match', expected_par_score_[0, 0], PChar(@par.par_score[0]));
    AssertEquals('par score EW should match', expected_par_score_[0, 1], PChar(@par.par_score[1]));
    AssertEquals('par contract NS should match', expected_par_contracts_[0, 0], PChar(@par.par_contracts_string[0]));
    AssertEquals('par contract EW should match', expected_par_contracts_[0, 1], PChar(@par.par_contracts_string[1]));
  finally
    ctx.Free;
  end;
end;

procedure TCalcParTests.TestContextReuseMultipleCalls;
var
  ctx: TSolverContext;
  table1, table2, table3: DdTableResults;
  par1, par2, par3: ParResults;
  result1, result2, result3: LongInt;
begin
  ctx := TSolverContext.Create;
  try
    result1 := calc_par(ctx, deal0_, vulnerability_[0], @table1, @par1);
    AssertEquals(RETURN_NO_FAULT, result1);
    AssertEquals(expected_par_score_[0, 0], PChar(@par1.par_score[0]));

    result2 := calc_par(ctx, deal1_, vulnerability_[1], @table2, @par2);
    AssertEquals(RETURN_NO_FAULT, result2);
    AssertEquals(expected_par_score_[1, 0], PChar(@par2.par_score[0]));

    result3 := calc_par(ctx, deal2_, vulnerability_[2], @table3, @par3);
    AssertEquals(RETURN_NO_FAULT, result3);
    AssertEquals(expected_par_score_[2, 0], PChar(@par3.par_score[0]));
  finally
    ctx.Free;
  end;
end;

procedure TCalcParTests.TestCalcParFromTableHand0;
var
  table: DdTableResults;
  par_full, par_from_table: ParResults;
  result1, result2: LongInt;
begin
  result1 := calc_par(deal0_, vulnerability_[0], @table, @par_full);
  AssertEquals(RETURN_NO_FAULT, result1);

  result2 := calc_par_from_table(@table, vulnerability_[0], @par_from_table);
  AssertEquals(RETURN_NO_FAULT, result2);

  AssertEquals(PChar(@par_full.par_score[0]), PChar(@par_from_table.par_score[0]));
  AssertEquals(PChar(@par_full.par_score[1]), PChar(@par_from_table.par_score[1]));
  AssertEquals(PChar(@par_full.par_contracts_string[0]), PChar(@par_from_table.par_contracts_string[0]));
  AssertEquals(PChar(@par_full.par_contracts_string[1]), PChar(@par_from_table.par_contracts_string[1]));
end;

procedure TCalcParTests.TestVulnerabilityVariations;
var
  table: DdTableResults;
  par: ParResults;
  vuln, result: LongInt;
begin
  for vuln := 0 to 3 do
  begin
    result := calc_par(deal0_, vuln, @table, @par);
    AssertEquals('calc_par should succeed for vulnerability', RETURN_NO_FAULT, result);
    Assert(PChar(@par.par_score[0]) <> '');
    Assert(PChar(@par.par_score[1]) <> '');
  end;
end;

procedure TCalcParTests.TestTableResultsPopulated;
var
  table: DdTableResults;
  par: ParResults;
  result, strain, hand, tricks: LongInt;
begin
  result := calc_par(deal0_, vulnerability_[0], @table, @par);
  AssertEquals(RETURN_NO_FAULT, result);

  for strain := 0 to DDS_STRAINS - 1 do
  begin
    for hand := 0 to DDS_HANDS - 1 do
    begin
      tricks := table.res_table[strain, hand];
      Assert(tricks >= 0, 'Tricks should be >= 0');
      Assert(tricks <= 13, 'Tricks should be <= 13');
    end;
  end;
end;

procedure TCalcParTests.TestCalcParFromTableVulnerability;
var
  table: DdTableResults;
  par_temp, par: ParResults;
  result, vuln, res: LongInt;
begin
  result := calc_par(deal0_, 0, @table, @par_temp);
  AssertEquals(RETURN_NO_FAULT, result);

  for vuln := 0 to 3 do
  begin
    res := calc_par_from_table(@table, vuln, @par);
    AssertEquals('Should compute par for vulnerability', RETURN_NO_FAULT, res);
  end;
end;

procedure TCalcParTests.TestInvalidVulnerability;
var
  table: DdTableResults;
  par: ParResults;
  result: LongInt;
begin
  result := calc_par(deal0_, -1, @table, @par);
  Assert((result = RETURN_NO_FAULT) or (result < 0), 'calc_par should return success or error code, not crash');
end;

procedure TCalcParTests.TestEmptyDealHandling;
var
  empty_deal: DdTableDeal;
  table: DdTableResults;
  par: ParResults;
  h, s, result: LongInt;
begin
  for h := 0 to DDS_HANDS - 1 do
    for s := 0 to DDS_SUITS - 1 do
      empty_deal.cards[h, s] := 0;

  result := calc_par(empty_deal, 0, @table, @par);
  Assert(result <> RETURN_NO_FAULT, 'Empty deal should produce an error');
end;

procedure TCalcParTests.TestConsistencyCalcParVsFromTable;
var
  hand_idx, res1, res2: LongInt;
  deal: ^DdTableDeal;
  table1: DdTableResults;
  par1, par2: ParResults;
begin
  for hand_idx := 0 to 2 do
  begin
    if hand_idx = 0 then deal := @deal0_
    else if hand_idx = 1 then deal := @deal1_
    else deal := @deal2_;

    res1 := calc_par(deal^, vulnerability_[hand_idx], @table1, @par1);
    AssertEquals(RETURN_NO_FAULT, res1);

    res2 := calc_par_from_table(@table1, vulnerability_[hand_idx], @par2);
    AssertEquals(RETURN_NO_FAULT, res2);

    AssertEquals('NS score should match', PChar(@par1.par_score[0]), PChar(@par2.par_score[0]));
    AssertEquals('EW score should match', PChar(@par1.par_score[1]), PChar(@par2.par_score[1]));
    AssertEquals('NS contract should match', PChar(@par1.par_contracts_string[0]), PChar(@par2.par_contracts_string[0]));
    AssertEquals('EW contract should match', PChar(@par1.par_contracts_string[1]), PChar(@par2.par_contracts_string[1]));
  end;
end;

procedure TCalcParTests.TestCalcParContextOverloadMatchesNonContext;
var
  hand_idx, res1, res2: LongInt;
  deal: ^DdTableDeal;
  table_no_ctx, table_with_ctx: DdTableResults;
  par_no_ctx, par_with_ctx: ParResults;
  ctx: TSolverContext;
begin
  for hand_idx := 0 to 2 do
  begin
    if hand_idx = 0 then deal := @deal0_
    else if hand_idx = 1 then deal := @deal1_
    else deal := @deal2_;

    res1 := calc_par(deal^, vulnerability_[hand_idx], @table_no_ctx, @par_no_ctx);
    AssertEquals(RETURN_NO_FAULT, res1);

    ctx := TSolverContext.Create;
    try
      res2 := calc_par(ctx, deal^, vulnerability_[hand_idx], @table_with_ctx, @par_with_ctx);
      AssertEquals(RETURN_NO_FAULT, res2);
    finally
      ctx.Free;
    end;

    AssertEquals('NS par score should match', PChar(@par_no_ctx.par_score[0]), PChar(@par_with_ctx.par_score[0]));
    AssertEquals('EW par score should match', PChar(@par_no_ctx.par_score[1]), PChar(@par_with_ctx.par_score[1]));
    AssertEquals('NS contract should match', PChar(@par_no_ctx.par_contracts_string[0]), PChar(@par_with_ctx.par_contracts_string[0]));
    AssertEquals('EW contract should match', PChar(@par_no_ctx.par_contracts_string[1]), PChar(@par_with_ctx.par_contracts_string[1]));
  end;
end;

procedure TCalcParTests.TestContextReusePerformance;
var
  ctx: TSolverContext;
  i, result, vuln: LongInt;
  table: DdTableResults;
  par: ParResults;
  deal: ^DdTableDeal;
begin
  ctx := TSolverContext.Create;
  try
    for i := 0 to 9 do
    begin
      if (i mod 2 = 0) then
      begin
        deal := @deal0_;
        vuln := vulnerability_[0];
      end
      else
      begin
        deal := @deal1_;
        vuln := vulnerability_[1];
      end;
      result := calc_par(ctx, deal^, vuln, @table, @par);
      AssertEquals(RETURN_NO_FAULT, result);
    end;
  finally
    ctx.Free;
  end;
end;

initialization
  RegisterTest(TCalcParTests);
end.
