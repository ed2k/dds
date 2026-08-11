program dds_tests;

{$mode objfpc}{$H+}

uses
  consoletestrunner,
  test_trick_three_bug,
  test_calc_par;

var
  runner: TTestRunner;
begin
  runner := TTestRunner.Create(nil);
  try
    runner.Initialize;
    runner.Run;
  finally
    runner.Free;
  end;
end.
