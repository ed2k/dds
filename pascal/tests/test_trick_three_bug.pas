unit test_trick_three_bug;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  DDS_Types, DDS_Interface;

type
  TTrickThreeBugTests = class(TTestCase)
  published
    procedure TestDeclarerMakesNineTricks;
  end;

implementation

function dds_max(const fut: FutureTricks): LongInt;
var
  res, i: LongInt;
begin
  res := 0;
  for i := 0 to 12 do
  begin
    if fut.rank[i] > 0 then
    begin
      if fut.score[i] > res then
        res := fut.score[i];
    end;
  end;
  Result := res;
end;

procedure TTrickThreeBugTests.TestDeclarerMakesNineTricks;
var
  target, solutions, mode, thread_index: LongInt;
  fut: FutureTricks;
  dl: Deal;
  ret: LongInt;
  maxScore: LongInt;
begin
  target := 0;
  solutions := 3;
  mode := 0;
  thread_index := 0;

  // Clear FutureTricks structure
  FillChar(fut, SizeOf(FutureTricks), 0);

  // Setup Deal structure
  dl.trump := 4; // No Trump
  dl.first := 2; // South to play
  
  dl.currentTrickSuit[0] := 0;
  dl.currentTrickSuit[1] := 0;
  dl.currentTrickSuit[2] := 0;
  
  dl.currentTrickRank[0] := 5;
  dl.currentTrickRank[1] := 13;
  dl.currentTrickRank[2] := 0;

  // North
  dl.remainCards[0, 0] := 512;
  dl.remainCards[0, 1] := 4096;
  dl.remainCards[0, 2] := 12320;
  dl.remainCards[0, 3] := 27184;

  // East
  dl.remainCards[1, 0] := 256;
  dl.remainCards[1, 1] := 2576;
  dl.remainCards[1, 2] := 16792;
  dl.remainCards[1, 3] := 5120;

  // South
  dl.remainCards[2, 0] := 3076;
  dl.remainCards[2, 1] := 17408;
  dl.remainCards[2, 2] := 580;
  dl.remainCards[2, 3] := 264;

  // West
  dl.remainCards[3, 0] := 192;
  dl.remainCards[3, 1] := 324;
  dl.remainCards[3, 2] := 3072;
  dl.remainCards[3, 3] := 196;

  ret := SolveBoard(dl, target, solutions, mode, @fut, thread_index);
  AssertEquals('SolveBoard return code should be RETURN_NO_FAULT', RETURN_NO_FAULT, ret);

  maxScore := dds_max(fut);
  AssertEquals('Declarer should make exactly 9 tricks', 9, maxScore);
end;

initialization
  RegisterTest(TTrickThreeBugTests);
end.
