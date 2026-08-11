unit DDS_LaterTricks;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, DDS_Types, DDS_Init, DDS_SolverContext;

function LaterTricksMIN(
  var tpos: Pos;
  const hand: LongInt;
  const depth: LongInt;
  const target: LongInt;
  const trump: LongInt;
  ctx: TSolverContext
): Boolean;

function LaterTricksMAX(
  var tpos: Pos;
  const hand: LongInt;
  const depth: LongInt;
  const target: LongInt;
  const trump: LongInt;
  ctx: TSolverContext
): Boolean;

implementation

function LaterTricksMIN(
  var tpos: Pos;
  const hand: LongInt;
  const depth: LongInt;
  const target: LongInt;
  const trump: LongInt;
  ctx: TSolverContext
): Boolean;
var
  depth_ok: Boolean;
  sum, ss, hh, win_hand, r2, h: LongInt;
  aggr: Word;
begin
  depth_ok := (depth >= 0) and (depth < 50);

  if (trump = DDS_NOTRUMP) or (tpos.winner[trump].rank = 0) then
  begin
    sum := 0;
    for ss := 0 to DDS_SUITS - 1 do
    begin
      hh := tpos.winner[ss].hand;
      if hh <> -1 then
      begin
        if (hh < DDS_HANDS) and (ctx.search.node_type_store(hh) = MAXNODE) then
          sum := sum + Max(tpos.length[hh, ss], tpos.length[partner[hh], ss]);
      end;
    end;

    if (tpos.tricks_max + sum < target) and (sum > 0) then
    begin
      if (tpos.tricks_max + (depth >> 2) >= target) then
      begin
        Result := true;
        Exit;
      end;

      for ss := 0 to DDS_SUITS - 1 do
      begin
        win_hand := tpos.winner[ss].hand;
        if win_hand = -1 then
        begin
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        end
        else if win_hand >= DDS_HANDS then
        begin
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
          continue;
        end
        else if ctx.search.node_type_store(win_hand) = MINNODE then
        begin
          if (tpos.rank_in_suit[partner[win_hand], ss] = 0) and
             (tpos.rank_in_suit[lho[win_hand], ss] = 0) and
             (tpos.rank_in_suit[rho[win_hand], ss] = 0) then
          begin
            if depth_ok then tpos.win_ranks[depth][ss] := 0;
          end
          else
          begin
            if depth_ok then tpos.win_ranks[depth][ss] := bit_map_rank[tpos.winner[ss].rank];
          end;
        end
        else
        begin
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        end;
      end;
      Result := false;
      Exit;
    end;
  end
  else if ctx.search.node_type_store(tpos.winner[trump].hand) = MINNODE then
  begin
    if (tpos.length[hand, trump] = 0) and (tpos.length[partner[hand], trump] = 0) then
    begin
      if ((tpos.tricks_max + (depth >> 2) + 1 - Max(tpos.length[lho[hand], trump], tpos.length[rho[hand], trump])) < target) then
      begin
        for ss := 0 to DDS_SUITS - 1 do
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        Result := false;
        Exit;
      end;
    end
    else if (tpos.tricks_max + (depth >> 2)) < target then
    begin
      for ss := 0 to DDS_SUITS - 1 do
        if depth_ok then tpos.win_ranks[depth][ss] := 0;
      if depth_ok then tpos.win_ranks[depth][trump] := bit_map_rank[tpos.winner[trump].rank];
      Result := false;
      Exit;
    end
    else if tpos.tricks_max + (depth >> 2) = target then
    begin
      hh := tpos.second_best[trump].hand;
      if hh = -1 then
      begin
        Result := true;
        Exit;
      end;
      if hh >= DDS_HANDS then
      begin
        Result := true;
        Exit;
      end;

      r2 := tpos.second_best[trump].rank;
      if (ctx.search.node_type_store(hh) = MINNODE) and (r2 <> 0) then
      begin
        if (tpos.length[hh, trump] > 1) or (tpos.length[partner[hh], trump] > 1) then
        begin
          for ss := 0 to DDS_SUITS - 1 do
            if depth_ok then tpos.win_ranks[depth][ss] := 0;
          if depth_ok then tpos.win_ranks[depth][trump] := bit_map_rank[r2];
          Result := false;
          Exit;
        end;
      end;
    end;
  end
  else
  begin
    hh := tpos.second_best[trump].hand;
    if hh = -1 then
    begin
      Result := true;
      Exit;
    end;
    if hh >= DDS_HANDS then
    begin
      Result := true;
      Exit;
    end;

    if (ctx.search.node_type_store(hh) <> MINNODE) or (tpos.length[hh, trump] <= 1) then
    begin
      Result := true;
      Exit;
    end;

    if tpos.winner[trump].hand = rho[hh] then
    begin
      if (tpos.tricks_max + (depth >> 2)) < target then
      begin
        for ss := 0 to DDS_SUITS - 1 do
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        if depth_ok then tpos.win_ranks[depth][trump] := bit_map_rank[tpos.second_best[trump].rank];
        Result := false;
        Exit;
      end;
    end
    else
    begin
      aggr := tpos.aggr[trump];
      if aggr >= 8192 then
      begin
        Result := true;
        Exit;
      end;
      h := ctx.thread_ptr^.rel[aggr].abs_rank[3, trump].hand;
      if h = -1 then
      begin
        Result := true;
        Exit;
      end;
      if h >= DDS_HANDS then
      begin
        Result := true;
        Exit;
      end;

      if (ctx.search.node_type_store(h) = MINNODE) and ((tpos.tricks_max + (depth >> 2)) < target) then
      begin
        for ss := 0 to DDS_SUITS - 1 do
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        if depth_ok then tpos.win_ranks[depth][trump] := bit_map_rank[ctx.thread_ptr^.rel[aggr].abs_rank[3, trump].rank];
        Result := false;
        Exit;
      end;
    end;
  end;

  Result := true;
end;

function LaterTricksMAX(
  var tpos: Pos;
  const hand: LongInt;
  const depth: LongInt;
  const target: LongInt;
  const trump: LongInt;
  ctx: TSolverContext
): Boolean;
var
  depth_ok: Boolean;
  sum, ss, hh, win_hand, maxlen, r2, h: LongInt;
  aggr: Word;
begin
  depth_ok := (depth >= 0) and (depth < 50);

  if (trump = DDS_NOTRUMP) or (tpos.winner[trump].rank = 0) then
  begin
    sum := 0;
    for ss := 0 to DDS_SUITS - 1 do
    begin
      hh := tpos.winner[ss].hand;
      if hh <> -1 then
      begin
        if (hh < DDS_HANDS) and (ctx.search.node_type_store(hh) = MINNODE) then
          sum := sum + Max(tpos.length[hh, ss], tpos.length[partner[hh], ss]);
      end;
    end;

    if (tpos.tricks_max + (depth >> 2) + 1 - sum >= target) and (sum > 0) then
    begin
      if (tpos.tricks_max + 1 < target) then
      begin
        Result := false;
        Exit;
      end;

      for ss := 0 to DDS_SUITS - 1 do
      begin
        win_hand := tpos.winner[ss].hand;
        if win_hand = -1 then
        begin
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        end
        else if win_hand >= DDS_HANDS then
        begin
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
          continue;
        end
        else if ctx.search.node_type_store(win_hand) = MAXNODE then
        begin
          if (tpos.rank_in_suit[partner[win_hand], ss] = 0) and
             (tpos.rank_in_suit[lho[win_hand], ss] = 0) and
             (tpos.rank_in_suit[rho[win_hand], ss] = 0) then
          begin
            if depth_ok then tpos.win_ranks[depth][ss] := 0;
          end
          else
          begin
            if depth_ok then tpos.win_ranks[depth][ss] := bit_map_rank[tpos.winner[ss].rank];
          end;
        end
        else
        begin
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        end;
      end;
      Result := true;
      Exit;
    end;
  end
  else if ctx.search.node_type_store(tpos.winner[trump].hand) = MAXNODE then
  begin
    if (tpos.length[hand, trump] = 0) and (tpos.length[partner[hand], trump] = 0) then
    begin
      maxlen := Max(tpos.length[lho[hand], trump], tpos.length[rho[hand], trump]);
      if (tpos.tricks_max + maxlen) >= target then
      begin
        for ss := 0 to DDS_SUITS - 1 do
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        Result := true;
        Exit;
      end;
    end
    else if (tpos.tricks_max + 1) >= target then
    begin
      for ss := 0 to DDS_SUITS - 1 do
        if depth_ok then tpos.win_ranks[depth][ss] := 0;
      if depth_ok then tpos.win_ranks[depth][trump] := bit_map_rank[tpos.winner[trump].rank];
      Result := true;
      Exit;
    end
    else
    begin
      hh := tpos.second_best[trump].hand;
      if hh = -1 then
      begin
        Result := false;
        Exit;
      end;
      if hh >= DDS_HANDS then
      begin
        Result := false;
        Exit;
      end;

      if (ctx.search.node_type_store(hh) = MAXNODE) and (tpos.second_best[trump].rank <> 0) then
      begin
        if ((tpos.length[hh, trump] > 1) or (tpos.length[partner[hh], trump] > 1)) and
           ((tpos.tricks_max + 2) >= target) then
        begin
          for ss := 0 to DDS_SUITS - 1 do
            if depth_ok then tpos.win_ranks[depth][ss] := 0;
          if depth_ok then tpos.win_ranks[depth][trump] := bit_map_rank[tpos.second_best[trump].rank];
          Result := true;
          Exit;
        end;
      end;
    end;
  end
  else
  begin
    hh := tpos.second_best[trump].hand;
    if hh = -1 then
    begin
      Result := false;
      Exit;
    end;
    if hh >= DDS_HANDS then
    begin
      Result := false;
      Exit;
    end;

    if (ctx.search.node_type_store(hh) <> MAXNODE) or (tpos.length[hh, trump] <= 1) then
    begin
      Result := false;
      Exit;
    end;

    if tpos.winner[trump].hand = rho[hh] then
    begin
      if (tpos.tricks_max + 1) >= target then
      begin
        for ss := 0 to DDS_SUITS - 1 do
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        if depth_ok then tpos.win_ranks[depth][trump] := bit_map_rank[tpos.second_best[trump].rank];
        Result := true;
        Exit;
      end;
    end
    else
    begin
      aggr := tpos.aggr[trump];
      if aggr >= 8192 then
      begin
        Result := false;
        Exit;
      end;
      h := ctx.thread_ptr^.rel[aggr].abs_rank[3, trump].hand;
      if h = -1 then
      begin
        Result := false;
        Exit;
      end;
      if h >= DDS_HANDS then
      begin
        Result := false;
        Exit;
      end;

      if (ctx.search.node_type_store(h) = MAXNODE) and ((tpos.tricks_max + 1) >= target) then
      begin
        for ss := 0 to DDS_SUITS - 1 do
          if depth_ok then tpos.win_ranks[depth][ss] := 0;
        if depth_ok then tpos.win_ranks[depth][trump] := bit_map_rank[ctx.thread_ptr^.rel[aggr].abs_rank[3, trump].rank];
        Result := true;
        Exit;
      end;
    end;
  end;

  Result := false;
end;

end.
