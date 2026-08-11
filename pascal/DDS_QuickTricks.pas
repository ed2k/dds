unit DDS_QuickTricks;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, DDS_Types, DDS_Init, DDS_SolverContext;

function QuickTricks(
  var tpos: Pos;
  const hand: LongInt;
  const depth: LongInt;
  const target: LongInt;
  const trump: LongInt;
  var resultVal: Boolean;
  ctx: TSolverContext
): LongInt;

function QuickTricksSecondHand(
  var tpos: Pos;
  const hand: LongInt;
  const depth: LongInt;
  const target: LongInt;
  const trump: LongInt;
  ctx: TSolverContext
): Boolean;

implementation

function QtricksLeadHandNT(
  const hand: LongInt;
  var tpos: Pos;
  const cutoff: LongInt;
  const depth: LongInt;
  const countLho: LongInt;
  const countRho: LongInt;
  var lhoTrumpRanks: LongInt;
  var rhoTrumpRanks: LongInt;
  const commPartner: Boolean;
  const commSuit: LongInt;
  const countOwn: LongInt;
  const countPart: LongInt;
  const suit: LongInt;
  const qtricks: LongInt;
  const trump: LongInt;
  var res: LongInt
): LongInt;
var
  qt: LongInt;
begin
  res := 1;
  qt := qtricks;
  tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.winner[suit].rank];

  if commPartner and (suit = commSuit) then
    tpos.win_ranks[depth][commSuit] := tpos.win_ranks[depth][commSuit] or bit_map_rank[tpos.second_best[suit].rank];

  Inc(qt);
  if qt >= cutoff then
  begin
    Result := qt;
    Exit;
  end;

  if (countLho <= 1) and (countRho <= 1) then
  begin
    qt := qt + countOwn - 1;
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;
    res := 2;
    Result := qt;
    Exit;
  end;

  if tpos.second_best[suit].hand = hand then
  begin
    tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.second_best[suit].rank];
    Inc(qt);
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;

    if (countLho <= 2) and (countRho <= 2) then
    begin
      qt := qt + countOwn - 2;
      if qt >= cutoff then
      begin
        Result := qt;
        Exit;
      end;
      res := 2;
      Result := qt;
      Exit;
    end;
  end;

  res := 0;
  Result := qt;
end;

function QtricksLeadHandTrump(
  const hand: LongInt;
  var tpos: Pos;
  const cutoff: LongInt;
  const depth: LongInt;
  const countLho: LongInt;
  const countRho: LongInt;
  const lhoTrumpRanks: LongInt;
  const rhoTrumpRanks: LongInt;
  const countOwn: LongInt;
  const countPart: LongInt;
  const suit: LongInt;
  const qtricks: LongInt;
  var res: LongInt
): LongInt;
var
  qt: LongInt;
begin
  res := 1;
  qt := qtricks;
  tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.winner[suit].rank];
  Inc(qt);
  if qt >= cutoff then
  begin
    Result := qt;
    Exit;
  end;

  if (countLho <= 1) and (countRho <= 1) and (lhoTrumpRanks = 0) and (rhoTrumpRanks = 0) then
  begin
    qt := qt + countOwn - 1;
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;
    res := 2;
    Result := qt;
    Exit;
  end;

  if tpos.second_best[suit].hand = hand then
  begin
    tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.second_best[suit].rank];
    Inc(qt);
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;

    if (countLho <= 2) and (countRho <= 2) and (lhoTrumpRanks = 0) and (rhoTrumpRanks = 0) then
    begin
      qt := qt + countOwn - 2;
      if qt >= cutoff then
      begin
        Result := qt;
        Exit;
      end;
      res := 2;
      Result := qt;
      Exit;
    end;
  end;

  res := 0;
  Result := qt;
end;

function QuickTricksPartnerHandTrump(
  const hand: LongInt;
  var tpos: Pos;
  const cutoff: LongInt;
  const depth: LongInt;
  const countLho: LongInt;
  const countRho: LongInt;
  const lhoTrumpRanks: LongInt;
  const rhoTrumpRanks: LongInt;
  const countOwn: LongInt;
  const countPart: LongInt;
  const suit: LongInt;
  const qtricks: LongInt;
  const commSuit: LongInt;
  const commRank: LongInt;
  var res: LongInt;
  ctx: TSolverContext
): LongInt;
var
  qt, r2: LongInt;
begin
  res := 1;
  qt := qtricks;
  tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.winner[suit].rank];
  tpos.win_ranks[depth][commSuit] := tpos.win_ranks[depth][commSuit] or bit_map_rank[commRank];
  Inc(qt);
  if qt >= cutoff then
  begin
    Result := qt;
    Exit;
  end;

  if (countLho <= 1) and (countRho <= 1) and (countOwn <= 1) and (lhoTrumpRanks = 0) and (rhoTrumpRanks = 0) then
  begin
    qt := qt + countPart - 1;
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;
    res := 2;
    Result := qt;
    Exit;
  end;

  if tpos.second_best[suit].hand = partner[hand] then
  begin
    tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.second_best[suit].rank];
    Inc(qt);
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;

    if (countLho <= 2) and (countRho <= 2) and (countOwn <= 2) and (lhoTrumpRanks = 0) and (rhoTrumpRanks = 0) then
    begin
      qt := qt + countPart - 2;
      if qt >= cutoff then
      begin
        Result := qt;
        Exit;
      end;
      res := 2;
      Result := qt;
      Exit;
    end;
  end;

  res := 0;
  Result := qt;
end;

function QuickTricksPartnerHandNT(
  const hand: LongInt;
  var tpos: Pos;
  const cutoff: LongInt;
  const depth: LongInt;
  const countLho: LongInt;
  const countRho: LongInt;
  const countOwn: LongInt;
  const countPart: LongInt;
  const suit: LongInt;
  const qtricks: LongInt;
  const commSuit: LongInt;
  const commRank: LongInt;
  var res: LongInt;
  ctx: TSolverContext
): LongInt;
var
  qt, ss, h, r_val: LongInt;
  ranks: Word;
begin
  res := 1;
  qt := qtricks;
  tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.winner[suit].rank];
  tpos.win_ranks[depth][commSuit] := tpos.win_ranks[depth][commSuit] or bit_map_rank[commRank];
  Inc(qt);
  if qt >= cutoff then
  begin
    Result := qt;
    Exit;
  end;

  if (countLho <= 1) and (countRho <= 1) and (countOwn <= 1) then
  begin
    qt := qt + countPart - 1;
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;
    res := 2;
    Result := qt;
    Exit;
  end;

  if tpos.second_best[suit].hand = partner[hand] then
  begin
    tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.second_best[suit].rank];
    Inc(qt);
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;

    if (countLho <= 2) and (countRho <= 2) and (countOwn <= 2) then
    begin
      qt := qt + countPart - 2;
      if qt >= cutoff then
      begin
        Result := qt;
        Exit;
      end;
      res := 2;
      Result := qt;
      Exit;
    end;
  end
  else if (tpos.second_best[suit].hand = hand) and (countPart > 1) and (countOwn > 1) then
  begin
    tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[tpos.second_best[suit].rank];
    Inc(qt);
    if qt >= cutoff then
    begin
      Result := qt;
      Exit;
    end;

    if (countLho <= 2) and (countRho <= 2) and ((countOwn <= 2) or (countPart <= 2)) then
    begin
      qt := qt + Max(countPart - 2, countOwn - 2);
      if qt >= cutoff then
      begin
        Result := qt;
        Exit;
      end;
      res := 2;
      Result := qt;
      Exit;
    end;
  end
  else if (suit = commSuit) and (tpos.second_best[suit].hand = lho[hand]) then
  begin
    ranks := 0;
    for h := 0 to DDS_HANDS - 1 do
      ranks := ranks or tpos.rank_in_suit[h, suit];

    if ctx.thread_ptr^.rel[ranks].abs_rank[3, suit].hand = partner[hand] then
    begin
      r_val := ctx.thread_ptr^.rel[ranks].abs_rank[3, suit].rank;
      tpos.win_ranks[depth][suit] := tpos.win_ranks[depth][suit] or bit_map_rank[r_val];
      Inc(qt);
      if qt >= cutoff then
      begin
        Result := qt;
        Exit;
      end;

      if (countOwn <= 2) and (countLho <= 2) and (countRho <= 2) then
      begin
        qt := qt + countPart - 2;
        if qt >= cutoff then
        begin
          Result := qt;
          Exit;
        end;
      end;
    end;
  end;

  res := 0;
  Result := qt;
end;

function QuickTricksPartnerHand(
  const hand: LongInt;
  var tpos: Pos;
  const cutoff: LongInt;
  const depth: LongInt;
  const countLho: LongInt;
  const countRho: LongInt;
  const lhoTrumpRanks: LongInt;
  const rhoTrumpRanks: LongInt;
  const countOwn: LongInt;
  const countPart: LongInt;
  const suit: LongInt;
  const qtricks: LongInt;
  const commSuit: LongInt;
  const commRank: LongInt;
  var res: LongInt;
  ctx: TSolverContext
): LongInt;
begin
  if ctx.thread_ptr^.trump <> DDS_NOTRUMP then
  begin
    Result := QuickTricksPartnerHandTrump(
      hand, tpos, cutoff, depth, countLho, countRho,
      lhoTrumpRanks, rhoTrumpRanks, countOwn, countPart, suit, qtricks,
      commSuit, commRank, res, ctx);
  end
  else
  begin
    Result := QuickTricksPartnerHandNT(
      hand, tpos, cutoff, depth, countLho, countRho,
      countOwn, countPart, suit, qtricks, commSuit, commRank, res, ctx);
  end;
end;

function QuickTricks(
  var tpos: Pos;
  const hand: LongInt;
  const depth: LongInt;
  const target: LongInt;
  const trump: LongInt;
  var resultVal: Boolean;
  ctx: TSolverContext
): LongInt;
var
  suit, commRank, commSuit, res, cutoff, qtricks, lowestQtricks: LongInt;
  commPartner: Boolean;
  s, countOwn, countLho, countRho, countPart, opps, lhoTrumpRanks, rhoTrumpRanks: LongInt;
begin
  commRank := 0;
  commSuit := -1;
  lhoTrumpRanks := 0;
  rhoTrumpRanks := 0;
  resultVal := true;
  qtricks := 0;

  if ctx.search.node_type_store(hand) = MAXNODE then
    cutoff := target - tpos.tricks_max
  else
    cutoff := tpos.tricks_max - target + (depth >> 2) + 2;

  commPartner := false;

  for s := 0 to DDS_SUITS - 1 do
  begin
    if (trump <> DDS_NOTRUMP) and (trump <> s) then
    begin
      if tpos.winner[s].hand = partner[hand] then
      begin
        if (tpos.rank_in_suit[hand, s] <> 0) and
           (((tpos.rank_in_suit[lho[hand], s] <> 0) or (tpos.rank_in_suit[lho[hand], trump] = 0)) and
            ((tpos.rank_in_suit[rho[hand], s] <> 0) or (tpos.rank_in_suit[rho[hand], trump] = 0))) then
        begin
          commPartner := true;
          commSuit := s;
          commRank := tpos.winner[s].rank;
          break;
        end;
      end
      else if (tpos.second_best[s].hand = partner[hand]) and
               (tpos.winner[s].hand = hand) and
               (tpos.length[hand, s] >= 2) and
               (tpos.length[partner[hand], s] >= 2) then
      begin
        if ((tpos.rank_in_suit[lho[hand], s] <> 0) or (tpos.rank_in_suit[lho[hand], trump] = 0)) and
           ((tpos.rank_in_suit[rho[hand], s] <> 0) or (tpos.rank_in_suit[rho[hand], trump] = 0)) then
        begin
          commPartner := true;
          commSuit := s;
          commRank := tpos.second_best[s].rank;
          break;
        end;
      end;
    end
    else if trump = DDS_NOTRUMP then
    begin
      if tpos.winner[s].hand = partner[hand] then
      begin
        if tpos.rank_in_suit[hand, s] <> 0 then
        begin
          commPartner := true;
          commSuit := s;
          commRank := tpos.winner[s].rank;
          break;
        end;
      end
      else if (tpos.second_best[s].hand = partner[hand]) and
               (tpos.winner[s].hand = hand) and
               (tpos.length[hand, s] >= 2) and
               (tpos.length[partner[hand], s] >= 2) then
      begin
        commPartner := true;
        commSuit := s;
        commRank := tpos.second_best[s].rank;
        break;
      end;
    end;
  end;

  if (trump <> DDS_NOTRUMP) and (not commPartner) and
     (tpos.rank_in_suit[hand, trump] <> 0) and
     (tpos.winner[trump].hand = partner[hand]) then
  begin
    commPartner := true;
    commSuit := trump;
    commRank := tpos.winner[trump].rank;
  end;

  if trump <> DDS_NOTRUMP then
  begin
    suit := trump;
    lhoTrumpRanks := tpos.length[lho[hand], trump];
    rhoTrumpRanks := tpos.length[rho[hand], trump];
  end
  else
    suit := 0;

  repeat
    countOwn := tpos.length[hand, suit];
    countLho := tpos.length[lho[hand], suit];
    countRho := tpos.length[rho[hand], suit];
    countPart := tpos.length[partner[hand], suit];
    opps := countLho or countRho;

    if (opps = 0) and (countPart = 0) then
    begin
      if countOwn = 0 then
      begin
        if (trump <> DDS_NOTRUMP) and (trump <> suit) then
        begin
          Inc(suit);
          if (trump <> DDS_NOTRUMP) and (suit = trump) then
            Inc(suit);
        end
        else
        begin
          if (trump <> DDS_NOTRUMP) and (trump = suit) then
          begin
            if trump = 0 then suit := 1 else suit := 0;
          end
          else
            Inc(suit);
        end;
        continue;
      end;

      if (trump <> DDS_NOTRUMP) and (trump <> suit) then
      begin
        if (lhoTrumpRanks = 0) and (rhoTrumpRanks = 0) then
        begin
          qtricks := qtricks + countOwn;
          if qtricks >= cutoff then
          begin
            Result := qtricks;
            Exit;
          end;
          Inc(suit);
          if (trump <> DDS_NOTRUMP) and (suit = trump) then
            Inc(suit);
          continue;
        end
        else
        begin
          Inc(suit);
          if (trump <> DDS_NOTRUMP) and (suit = trump) then
            Inc(suit);
          continue;
        end;
      end
      else
      begin
        qtricks := qtricks + countOwn;
        if qtricks >= cutoff then
        begin
          Result := qtricks;
          Exit;
        end;

        if (trump <> DDS_NOTRUMP) and (suit = trump) then
        begin
          if trump = 0 then suit := 1 else suit := 0;
        end
        else
        begin
          Inc(suit);
          if (trump <> DDS_NOTRUMP) and (suit = trump) then
            Inc(suit);
        end;
        continue;
      end;
    end;

    if tpos.winner[suit].hand = hand then
    begin
      if trump <> DDS_NOTRUMP then
      begin
        if trump = suit then
        begin
          qtricks := QtricksLeadHandTrump(
            hand, tpos, cutoff, depth, countLho, countRho,
            lhoTrumpRanks, rhoTrumpRanks, countOwn, countPart, suit, qtricks, res);
        end
        else
        begin
          qtricks := QtricksLeadHandNT(
            hand, tpos, cutoff, depth, countLho, countRho,
            lhoTrumpRanks, rhoTrumpRanks, commPartner, commSuit, countOwn, countPart,
            suit, qtricks, trump, res);
        end;
      end
      else
      begin
        qtricks := QtricksLeadHandNT(
          hand, tpos, cutoff, depth, countLho, countRho,
          lhoTrumpRanks, rhoTrumpRanks, commPartner, commSuit, countOwn, countPart,
          suit, qtricks, trump, res);
      end;

      if qtricks >= cutoff then
      begin
        Result := qtricks;
        Exit;
      end;

      if res = 2 then
      begin
        if (trump <> DDS_NOTRUMP) and (trump <> suit) then
        begin
          Inc(suit);
          if (trump <> DDS_NOTRUMP) and (suit = trump) then
            Inc(suit);
        end
        else
        begin
          if (trump <> DDS_NOTRUMP) and (trump = suit) then
          begin
            if trump = 0 then suit := 1 else suit := 0;
          end
          else
            Inc(suit);
        end;
        continue;
      end;
    end;

    if (tpos.winner[suit].hand = partner[hand]) and commPartner then
    begin
      qtricks := QuickTricksPartnerHand(
        hand, tpos, cutoff, depth, countLho, countRho,
        lhoTrumpRanks, rhoTrumpRanks, countOwn, countPart, suit, qtricks,
        commSuit, commRank, res, ctx);

      if qtricks >= cutoff then
      begin
        Result := qtricks;
        Exit;
      end;

      if res = 2 then
      begin
        if (trump <> DDS_NOTRUMP) and (trump <> suit) then
        begin
          Inc(suit);
          if (trump <> DDS_NOTRUMP) and (suit = trump) then
            Inc(suit);
        end
        else
        begin
          if (trump <> DDS_NOTRUMP) and (trump = suit) then
          begin
            if trump = 0 then suit := 1 else suit := 0;
          end
          else
            Inc(suit);
        end;
        continue;
      end;
    end;

    if (trump <> DDS_NOTRUMP) and (trump <> suit) then
    begin
      Inc(suit);
      if (trump <> DDS_NOTRUMP) and (suit = trump) then
        Inc(suit);
    end
    else
    begin
      if (trump <> DDS_NOTRUMP) and (trump = suit) then
      begin
        if trump = 0 then suit := 1 else suit := 0;
      end
      else
        Inc(suit);
    end;
  until (suit >= DDS_SUITS);

  lowestQtricks := qtricks;

  if (cutoff > lowestQtricks) and (cutoff <= lowestQtricks + (depth >> 2)) then
    resultVal := false;

  Result := lowestQtricks;
end;

function QuickTricksSecondHand(
  var tpos: Pos;
  const hand: LongInt;
  const depth: LongInt;
  const target: LongInt;
  const trump: LongInt;
  ctx: TSolverContext
): Boolean;
var
  ss, s, rr, qtricks, cutoff, hh: LongInt;
  ranks: Word;
begin
  if depth = ctx.search.ini_depth then
  begin
    Result := false;
    Exit;
  end;

  ss := tpos.move[depth + 1].suit;
  ranks := tpos.rank_in_suit[hand, ss] or tpos.rank_in_suit[partner[hand], ss];

  for s := 0 to DDS_SUITS - 1 do
    tpos.win_ranks[depth][s] := 0;

  if (trump <> DDS_NOTRUMP) and (ss <> trump) and
     (((tpos.rank_in_suit[hand, ss] = 0) and (tpos.rank_in_suit[hand, trump] <> 0)) or
      ((tpos.rank_in_suit[partner[hand], ss] = 0) and (tpos.rank_in_suit[partner[hand], trump] <> 0))) then
  begin
    if (tpos.rank_in_suit[lho[hand], ss] = 0) and (tpos.rank_in_suit[lho[hand], trump] <> 0) then
    begin
      Result := false;
      Exit;
    end;
  end
  else if ranks > (bit_map_rank[tpos.move[depth + 1].rank] or tpos.rank_in_suit[lho[hand], ss]) then
  begin
    if (trump <> DDS_NOTRUMP) and (ss <> trump) and
       (tpos.rank_in_suit[lho[hand], trump] <> 0) and (tpos.rank_in_suit[lho[hand], ss] = 0) then
    begin
      Result := false;
      Exit;
    end;

    rr := highest_rank[ranks];
    tpos.win_ranks[depth][ss] := bit_map_rank[rr];
  end
  else
  begin
    Result := false;
    Exit;
  end;

  qtricks := 1;

  if ctx.search.node_type_store(hand) = MAXNODE then
    cutoff := target - tpos.tricks_max
  else
    cutoff := tpos.tricks_max - target + (depth >> 2) + 3;

  if qtricks >= cutoff then
  begin
    Result := true;
    Exit;
  end;

  if trump <> DDS_NOTRUMP then
  begin
    Result := false;
    Exit;
  end;

  if tpos.rank_in_suit[hand, ss] > tpos.rank_in_suit[partner[hand], ss] then
    hh := hand
  else
    hh := partner[hand];

  if (tpos.winner[ss].hand = hh) and (tpos.second_best[ss].rank <> 0) and (tpos.second_best[ss].hand = hh) then
  begin
    Inc(qtricks);
    tpos.win_ranks[depth][ss] := tpos.win_ranks[depth][ss] or bit_map_rank[tpos.second_best[ss].rank];

    if qtricks >= cutoff then
    begin
      Result := true;
      Exit;
    end;
  end;

  for s := 0 to DDS_SUITS - 1 do
  begin
    if (s = ss) or (tpos.length[hh, s] = 0) then
      continue;

    if (tpos.length[lho[hh], s] = 0) and
       (tpos.length[rho[hh], s] = 0) and
       (tpos.length[partner[hh], s] = 0) then
    begin
      qtricks := qtricks + count_table[tpos.rank_in_suit[hh, s]];
      if qtricks >= cutoff then
      begin
        Result := true;
        Exit;
      end;
    end
    else if (tpos.winner[s].rank <> 0) and (tpos.winner[s].hand = hh) then
    begin
      Inc(qtricks);
      tpos.win_ranks[depth][s] := tpos.win_ranks[depth][s] or bit_map_rank[tpos.winner[s].rank];

      if qtricks >= cutoff then
      begin
        Result := true;
        Exit;
      end;
    end;
  end;

  Result := false;
end;

end.
