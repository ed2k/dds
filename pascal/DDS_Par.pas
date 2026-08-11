unit DDS_Par;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, DDS_Types;

type
  data_type = record
    primacy: LongInt;
    highest_making_no: LongInt;
    dearest_making_no: LongInt;
    dearest_score: LongInt;
    vul_no: LongInt;
  end;

  list_type = record
    score: LongInt;
    dno: LongInt;
    no: LongInt;
    tricks: LongInt;
    down: LongInt;
  end;

  TListArray = array[0..1, 0..DDS_STRAINS - 1] of list_type;
  TSacrTable = array[0..DDS_STRAINS - 1, 0..DDS_STRAINS - 1] of LongInt;
  TContractsArray = array[0..9, 0..9] of AnsiChar;

function DealerPar(
  const tablep: PDdTableResults;
  presp: PParResultsDealer;
  dealer: LongInt;
  vulnerable: LongInt
): LongInt; stdcall;

function Par(
  const tablep: PDdTableResults;
  presp: PParResults;
  vulnerable: LongInt
): LongInt; stdcall;

procedure StrToCharArray(const S: string; var Arr: array of Char);

implementation

const
  BIGNUM = 9999;

  DOUBLED_SCORES: array[0..1, 0..13] of LongInt = (
    (0, 100, 300, 500, 800, 1100, 1400, 1700, 2000, 2300, 2600, 2900, 3200, 3500),
    (0, 200, 500, 800, 1100, 1400, 1700, 2000, 2300, 2600, 2900, 3200, 3500, 3800)
  );

  SCORES: array[0..35, 0..1] of LongInt = (
    (   0,   0),
    (  70,  70), (  70,  70), (  80,  80), (  80,  80), (  90,  90),
    (  90,  90), (  90,  90), ( 110, 110), ( 110, 110), ( 120, 120),
    ( 110, 110), ( 110, 110), ( 140, 140), ( 140, 140), ( 400, 600),
    ( 130, 130), ( 130, 130), ( 420, 620), ( 420, 620), ( 430, 630),
    ( 400, 600), ( 400, 600), ( 450, 650), ( 450, 650), ( 460, 660),
    ( 920, 1370), ( 920, 1370), ( 980, 1430), ( 980, 1430), ( 990, 1440),
    (1440, 2140), (1440, 2140), (1510, 2210), (1510, 2210), (1520, 2220)
  );

  DOWN_TARGET: array[0..35, 0..3] of LongInt = (
    (0, 0, 0, 0),
    (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0), (0, 0, 0, 0),
    (0, 0, 0, 0), (0, 0, 0, 0), (1, 0, 1, 0), (1, 0, 1, 0), (1, 0, 1, 0),
    (1, 0, 1, 0), (1, 0, 1, 0), (1, 0, 1, 0), (1, 0, 1, 0), (2, 1, 3, 2),
    (1, 0, 1, 0), (1, 0, 1, 0), (2, 1, 3, 2), (2, 1, 3, 2), (2, 1, 3, 2),
    (2, 1, 3, 2), (2, 1, 3, 2), (2, 1, 3, 2), (2, 1, 3, 2), (2, 1, 3, 2),
    (4, 3, 5, 4), (4, 3, 5, 4), (4, 3, 6, 5), (4, 3, 6, 5), (4, 3, 6, 5),
    (6, 5, 8, 7), (6, 5, 8, 7), (6, 5, 8, 7), (6, 5, 8, 7), (6, 5, 8, 7)
  );

  FLOOR_CONTRACT: array[0..35] of LongInt = (
     0,  1,  2,  3,  4,  5,  1,  2,  3,  4,  5,
         1,  2,  3,  4, 15,  1,  2, 18, 19, 15,
        21, 22, 18, 19, 15, 26, 27, 28, 29, 30,
        31, 32, 33, 34, 35
  );

  NUMBER_TO_CONTRACT: array[0..35] of string = (
    '0',
    '1C', '1D', '1H', '1S', '1N',
    '2C', '2D', '2H', '2S', '2N',
    '3C', '3D', '3H', '3S', '3N',
    '4C', '4D', '4H', '4S', '4N',
    '5C', '5D', '5H', '5S', '5N',
    '6C', '6D', '6H', '6S', '6N',
    '7C', '7D', '7H', '7S', '7N'
  );

  NUMBER_TO_PLAYER: array[0..3] of string = ( 'N', 'E', 'S', 'W' );

  VUL_LOOKUP: array[0..3, 0..1] of LongInt = (
    (0, 0),
    (1, 1),
    (1, 0),
    (0, 1)
  );

  VUL_TO_NO: array[0..1, 0..1] of LongInt = (
    (0, 1),
    (2, 3)
  );

  DENOM_ORDER: array[0..4] of LongInt = ( 3, 2, 1, 0, 4 );



procedure StrToCharArray(const S: string; var Arr: array of Char);
var
  I: Integer;
begin
  for I := 0 to Min(Length(S), Length(Arr) - 1) do
    Arr[I] := S[I + 1];
  if Length(S) < Length(Arr) then
    Arr[Length(S)] := #0;
end;

function contract_as_text(
  const table: DdTableResults;
  const side: LongInt;
  const no: LongInt;
  const dno: LongInt;
  const delta: LongInt
): string;
var
  ta, tb, t_max: LongInt;
begin
  ta := table.res_table[DENOM_ORDER[dno], side];
  tb := table.res_table[DENOM_ORDER[dno], side + 2];
  t_max := Max(ta, tb);

  Result := NUMBER_TO_CONTRACT[no];
  if delta < 0 then
    Result := Result + '*-'
  else
    Result := Result + '-';

  if ta = t_max then
    Result := Result + NUMBER_TO_PLAYER[side];
  if tb = t_max then
    Result := Result + NUMBER_TO_PLAYER[side + 2];

  if delta > 0 then
    Result := Result + '+' + IntToStr(delta)
  else if delta < 0 then
    Result := Result + IntToStr(-delta);
end;

function sacrifice_as_text(
  const no: LongInt;
  const pno: LongInt;
  const down: LongInt
): string;
begin
  Result := NUMBER_TO_CONTRACT[no] + '-' + NUMBER_TO_PLAYER[pno] + '-' + IntToStr(down);
end;

procedure survey_scores(
  const table: DdTableResults;
  const dealer: LongInt;
  const vul_by_side: array of LongInt;
  var data: data_type;
  var num_candidates: LongInt;
  var list: TListArray
);
var
  stats: array[0..1] of data_type;
  side, dno, highest_making_no, dearest_making_no, dearest_score, a, b, best, no, score: LongInt;
  slist: ^list_type;
  primacy, t_max, pno, dm_no, vul_primacy, vul_other: LongInt;
  n, new_n, i: LongInt;
  temp: list_type;
begin
  for side := 0 to 1 do
  begin
    highest_making_no := 0;
    dearest_making_no := 0;
    dearest_score := 0;

    for dno := 0 to DDS_STRAINS - 1 do
    begin
      slist := @(list[side, dno]);
      a := table.res_table[DENOM_ORDER[dno], side];
      b := table.res_table[DENOM_ORDER[dno], side + 2];
      best := Max(a, b);

      no := 5 * (best - 7) + dno + 1;
      slist^.no := no;

      if best < 7 then
      begin
        slist^.score := 0;
        continue;
      end;

      score := SCORES[no, vul_by_side[side]];
      slist^.score := score;
      slist^.dno := dno;
      slist^.tricks := best;

      if score > dearest_score then
      begin
        dearest_score := score;
        dearest_making_no := no;
      end
      else if (score = dearest_score) and (no < dearest_making_no) then
      begin
        dearest_making_no := no;
      end;

      if no > highest_making_no then
        highest_making_no := no;
    end;

    stats[side].highest_making_no := highest_making_no;
    stats[side].dearest_making_no := dearest_making_no;
    stats[side].dearest_score := dearest_score;
  end;

  primacy := 0;
  if stats[0].highest_making_no > stats[1].highest_making_no then
    primacy := 0;
  if stats[0].highest_making_no < stats[1].highest_making_no then
    primacy := 1;
  if stats[0].highest_making_no = stats[1].highest_making_no then
  begin
    if stats[0].highest_making_no = 0 then
    begin
      data.primacy := -1;
      Exit;
    end;

    dno := (stats[0].highest_making_no - 1) mod 5;
    t_max := list[0, dno].tricks;

    for pno := dealer to dealer + 3 do
    begin
      if table.res_table[DENOM_ORDER[dno], pno mod 4] <> t_max then
        continue;
      primacy := pno mod 2;
      break;
    end;
  end;

  dm_no := stats[primacy].dearest_making_no;
  data.primacy := primacy;
  data.highest_making_no := stats[primacy].highest_making_no;
  data.dearest_making_no := dm_no;
  data.dearest_score := stats[primacy].dearest_score;

  vul_primacy := vul_by_side[primacy];
  vul_other := vul_by_side[1 - primacy];
  data.vul_no := VUL_TO_NO[vul_primacy, vul_other];

  n := DDS_STRAINS;
  repeat
    new_n := 0;
    for i := 1 to n - 1 do
    begin
      if list[primacy, i - 1].no > list[primacy, i].no then
        continue;

      temp := list[primacy, i - 1];
      list[primacy, i - 1] := list[primacy, i];
      list[primacy, i] := temp;
      new_n := i;
    end;
    n := new_n;
  until n <= 0;

  num_candidates := DDS_STRAINS;
  for n := 0 to DDS_STRAINS - 1 do
  begin
    if list[primacy, n].no < dm_no then
      Dec(num_candidates);
  end;
end;

procedure best_sacrifice(
  const table: DdTableResults;
  const side: LongInt;
  const no: LongInt;
  const dno: LongInt;
  const dealer: LongInt;
  const list: TListArray;
  var sacr_table: TSacrTable;
  var best_down: LongInt
);
var
  other, eno, down, t_max, incr_flag, pno, diff, s, local: LongInt;
  sacr: list_type;
begin
  other := 1 - side;
  best_down := BIGNUM;

  for eno := 0 to 4 do
  begin
    sacr := list[other, eno];
    down := BIGNUM;

    if eno = dno then
    begin
      t_max := (no + 34) div 5;
      incr_flag := 0;
      for pno := dealer to dealer + 3 do
      begin
        diff := t_max - table.res_table[DENOM_ORDER[dno], pno mod 4];
        s := pno mod 2;
        if s = side then
        begin
          if diff = 0 then
            incr_flag := 1;
        end
        else
        begin
          local := diff + incr_flag;
          if local < down then
            down := local;
        end;
      end;
      if sacr.no + 5 * down > 35 then
        down := BIGNUM;
    end
    else
    begin
      down := (no - sacr.no + 4) div 5;
      if sacr.no + 5 * down > 35 then
        down := BIGNUM;
    end;

    sacr_table[dno, eno] := down;
    if down < best_down then
      best_down := down;
  end;
end;

procedure sacrifices_as_text(
  const table: DdTableResults;
  const side: LongInt;
  const dealer: LongInt;
  const best_down: LongInt;
  const no_decl: LongInt;
  const dno: LongInt;
  const list: TListArray;
  const sacr: TSacrTable;
  var results: TContractsArray;
  var res_no: LongInt
);
var
  other, eno, down, no_sac, t_max, incr_flag, p_hit, pno, pno_mod, diff, s: LongInt;
  pno_list, sac_list: array[0..1] of LongInt;
  ns0, ns1, p: LongInt;
begin
  other := 1 - side;

  for eno := 0 to 4 do
  begin
    down := sacr[dno, eno];
    if down <> best_down then
      continue;

    if eno <> dno then
    begin
      no_sac := list[other, eno].no + 5 * best_down;
      StrToCharArray(contract_as_text(table, other, no_sac, eno, -best_down), results[res_no]);
      Inc(res_no);
      continue;
    end;

    t_max := (no_decl + 34) div 5;
    incr_flag := 0;
    p_hit := 0;
    for pno := dealer to dealer + 3 do
    begin
      pno_mod := pno mod 4;
      diff := t_max - table.res_table[DENOM_ORDER[dno], pno_mod];
      s := pno mod 2;
      if s = side then
      begin
        if diff = 0 then
          incr_flag := 1;
      end
      else
      begin
        down := diff + incr_flag;
        if down <> best_down then
          continue;
        pno_list[p_hit] := pno_mod;
        sac_list[p_hit] := no_decl + 5 * incr_flag;
        Inc(p_hit);
      end;
    end;

    ns0 := sac_list[0];
    if p_hit = 1 then
    begin
      StrToCharArray(sacrifice_as_text(ns0, pno_list[0], best_down), results[res_no]);
      Inc(res_no);
      continue;
    end;

    ns1 := sac_list[1];
    if ns0 = ns1 then
    begin
      StrToCharArray(contract_as_text(table, other, ns0, eno, -best_down), results[res_no]);
      Inc(res_no);
      continue;
    end;

    if ns0 < ns1 then p := 0 else p := 1;
    StrToCharArray(sacrifice_as_text(sac_list[p], pno_list[p], best_down), results[res_no]);
    Inc(res_no);
  end;
end;

procedure reduce_contract(
  var no: LongInt;
  const sac_gap: LongInt;
  var plus: LongInt
);
var
  flr, no_sac_level, new_no: LongInt;
begin
  if sac_gap >= -1 then
  begin
    plus := 0;
    Exit;
  end;

  flr := FLOOR_CONTRACT[no];
  no_sac_level := no + 5 * (sac_gap + 1);
  if no_sac_level > flr then new_no := no_sac_level else new_no := flr;
  plus := (no - new_no) div 5;
  no := new_no;
end;

function DealerPar(
  const tablep: PDdTableResults;
  presp: PParResultsDealer;
  dealer: LongInt;
  vulnerable: LongInt
): LongInt; stdcall;
var
  vul_by_side: array[0..1] of LongInt;
  data: data_type;
  list: TListArray;
  num_cand, side, vul_no, best_plus, down, sac_found, best_down, n, no, dno, target, res_no, vul_def, plus: LongInt;
  sacr: TSacrTable;
  type_arr, sac_gap: array[0..DDS_STRAINS - 1] of LongInt;
  sac_vul, sac_score: LongInt;
  results_wrapper: array[0..9] of PChar;
  results_char_array: TContractsArray;
  i, j: Integer;
begin
  if (vulnerable < 0) or (vulnerable > 3) then
  begin
    Result := RETURN_UNKNOWN_FAULT;
    Exit;
  end;

  vul_by_side[0] := VUL_LOOKUP[vulnerable, 0];
  vul_by_side[1] := VUL_LOOKUP[vulnerable, 1];

  survey_scores(tablep^, dealer, vul_by_side, data, num_cand, list);
  side := data.primacy;

  if side = -1 then
  begin
    presp^.number := 1;
    StrToCharArray('pass', presp^.contracts[0]);
    Result := RETURN_NO_FAULT;
    Exit;
  end;

  vul_no := data.vul_no;
  best_plus := 0;
  down := 0;
  sac_found := 0;
  best_down := 0;

  for i := 0 to DDS_STRAINS - 1 do
    for j := 0 to DDS_STRAINS - 1 do
      sacr[i, j] := 0;

  for n := 0 to num_cand - 1 do
  begin
    no := list[side, n].no;
    dno := list[side, n].dno;
    target := DOWN_TARGET[no, vul_no];

    best_sacrifice(tablep^, side, no, dno, dealer, list, sacr, down);

    if down <= target then
    begin
      if down > best_down then
        best_down := down;
      if sac_found <> 0 then
      begin
        type_arr[n] := -1;
      end
      else
      begin
        sac_found := 1;
        type_arr[n] := 0;
        list[side, n].down := down;
      end;
    end
    else
    begin
      if list[side, n].score > best_plus then
        best_plus := list[side, n].score;
      type_arr[n] := 1;
      sac_gap[n] := target - down;
    end;
  end;

  res_no := 0;
  vul_def := vul_by_side[1 - side];
  sac_score := DOUBLED_SCORES[vul_def, best_down];

  // Helper arrays for passing presp^.contracts array to open array parameter
  for i := 0 to 9 do
    for j := 0 to 9 do
      results_char_array[i, j] := #0;

  if (sac_found = 0) or (best_plus > sac_score) then
  begin
    presp^.score := best_plus;
    if side <> 0 then
      presp^.score := -best_plus;

    for n := 0 to num_cand - 1 do
    begin
      if (type_arr[n] <> 1) or (list[side, n].score <> best_plus) then
        continue;
      no := list[side, n].no;
      reduce_contract(no, sac_gap[n], plus);

      StrToCharArray(contract_as_text(tablep^, side, no, list[side, n].dno, plus), presp^.contracts[res_no]);
      Inc(res_no);
    end;
  end
  else
  begin
    sac_vul := vul_by_side[1 - side];
    sac_score := DOUBLED_SCORES[sac_vul, best_down];
    presp^.score := sac_score;
    if side <> 0 then
      presp^.score := -sac_score;

    for n := 0 to num_cand - 1 do
    begin
      if (type_arr[n] <> 0) or (list[side, n].down <> best_down) then
        continue;

      // Copying the results row-by-row
      sacrifices_as_text(tablep^, side, dealer, best_down, list[side, n].no, list[side, n].dno, list, sacr, results_char_array, res_no);
    end;

    for i := 0 to res_no - 1 do
      for j := 0 to 9 do
        presp^.contracts[i, j] := results_char_array[i, j];
  end;

    presp^.number := res_no;
    Result := RETURN_NO_FAULT;
  end;

function TranslateContract(const S: string): string;
var
  LevelChar: Char;
  SuitStr: string;
  PlayerStr: string;
  IsDoubled: Boolean;
  i: Integer;
  DashCount: Integer;
  FirstDashPos, SecondDashPos, StarPos: Integer;
begin
  if (S = '') or (S = 'pass') or (SameText(S, 'pass')) then
  begin
    Result := '';
    Exit;
  end;
  
  LevelChar := S[1];
  if S[2] = 'N' then
    SuitStr := 'NT'
  else
    SuitStr := S[2];
    
  IsDoubled := False;
  StarPos := 0;
  FirstDashPos := 0;
  SecondDashPos := 0;
  DashCount := 0;
  
  for i := 1 to Length(S) do
  begin
    if S[i] = '*' then
      StarPos := i
    else if S[i] = '-' then
    begin
      Inc(DashCount);
      if DashCount = 1 then
        FirstDashPos := i
      else if DashCount = 2 then
        SecondDashPos := i;
    end;
  end;
  
  if StarPos > 0 then
    IsDoubled := True;
  if DashCount >= 2 then
    IsDoubled := True;
    
  PlayerStr := '';
  if DashCount = 1 then
  begin
    PlayerStr := Copy(S, FirstDashPos + 1, Length(S) - FirstDashPos);
  end
  else if DashCount >= 2 then
  begin
    PlayerStr := Copy(S, FirstDashPos + 1, SecondDashPos - FirstDashPos - 1);
  end;
  
  Result := PlayerStr + ' ' + LevelChar + SuitStr;
  if IsDoubled then
    Result := Result + 'x';
end;

function Par(
  const tablep: PDdTableResults;
  presp: PParResults;
  vulnerable: LongInt
): LongInt; stdcall;
var
  dealerParRes: ParResultsDealer;
  res: LongInt;
  i: Integer;
  contractStr, joinedContracts, nsScoreStr, ewScoreStr: string;
  cStr: string;
begin
  res := DealerPar(tablep, @dealerParRes, 0, vulnerable);
  if res <> RETURN_NO_FAULT then
  begin
    Result := res;
    Exit;
  end;

  // Format scores
  nsScoreStr := 'NS ' + IntToStr(dealerParRes.score);
  ewScoreStr := 'EW ' + IntToStr(-dealerParRes.score);
  
  // Clear and copy to presp^.par_score
  FillChar(presp^.par_score, SizeOf(presp^.par_score), 0);
  for i := 1 to Length(nsScoreStr) do
    if i <= 16 then presp^.par_score[0, i - 1] := AnsiChar(nsScoreStr[i]);
  for i := 1 to Length(ewScoreStr) do
    if i <= 16 then presp^.par_score[1, i - 1] := AnsiChar(ewScoreStr[i]);

  // Format contracts
  joinedContracts := '';
  if (dealerParRes.number > 0) and (SameText(dealerParRes.contracts[0], 'pass') = False) then
  begin
    for i := 0 to dealerParRes.number - 1 do
    begin
      cStr := string(dealerParRes.contracts[i]);
      // Remove trailing null bytes from cStr
      while (Length(cStr) > 0) and (cStr[Length(cStr)] = #0) do
        Delete(cStr, Length(cStr), 1);
        
      contractStr := TranslateContract(cStr);
      if contractStr <> '' then
      begin
        if joinedContracts <> '' then
          joinedContracts := joinedContracts + ',';
        joinedContracts := joinedContracts + contractStr;
      end;
    end;
  end;

  FillChar(presp^.par_contracts_string, SizeOf(presp^.par_contracts_string), 0);
  
  if joinedContracts <> '' then
  begin
    cStr := 'NS:' + joinedContracts;
    for i := 1 to Length(cStr) do
      if i <= 128 then presp^.par_contracts_string[0, i - 1] := AnsiChar(cStr[i]);
      
    cStr := 'EW:' + joinedContracts;
    for i := 1 to Length(cStr) do
      if i <= 128 then presp^.par_contracts_string[1, i - 1] := AnsiChar(cStr[i]);
  end
  else
  begin
    cStr := 'NS:';
    for i := 1 to Length(cStr) do
      if i <= 128 then presp^.par_contracts_string[0, i - 1] := AnsiChar(cStr[i]);
    cStr := 'EW:';
    for i := 1 to Length(cStr) do
      if i <= 128 then presp^.par_contracts_string[1, i - 1] := AnsiChar(cStr[i]);
  end;

  Result := RETURN_NO_FAULT;
end;

end.
