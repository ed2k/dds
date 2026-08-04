unit DDS_Interface;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, DDS_Types, DDS_Init, DDS_SolverContext, DDS_Moves,
  DDS_QuickTricks, DDS_LaterTricks, DDS_ABSearch, DDS_Par;

type
  TCardsArray = array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of Cardinal;

function SolveBoard(
  dl: Deal;
  target: LongInt;
  solutions: LongInt;
  mode: LongInt;
  futp: PFutureTricks;
  thrId: LongInt
): LongInt; stdcall;

function SolveBoardPBN(
  dlpbn: DealPBN;
  target: LongInt;
  solutions: LongInt;
  mode: LongInt;
  futp: PFutureTricks;
  thrId: LongInt
): LongInt; stdcall;

function CalcDDtable(
  tableDeal: DdTableDeal;
  tablep: PDdTableResults
): LongInt; stdcall;

function CalcDDtablePBN(
  tableDealPBN: DdTableDealPBN;
  tablep: PDdTableResults
): LongInt; stdcall;

function CalcAllTablesPBN(
  dealsp: PDdTableDealsPBN;
  mode: LongInt;
  trumpFilter: PTrumpFilter;
  resp: PDdTablesRes;
  presp: PBobAllParResults
): LongInt; stdcall;

function convert_from_pbn(
  const dealBuff: array of AnsiChar;
  var remainCards: TCardsArray
): LongInt;

function SolveBoardBin(
  dldbin: Pointer;
  target: LongInt;
  solutions: LongInt;
  mode: LongInt;
  futp: PFutureTricks;
  thrId: LongInt
): LongInt; stdcall;

function SolveAllChunksBin(
  bop: Pointer;
  solvedp: Pointer;
  maxThreads: LongInt
): LongInt; stdcall;

function SolveAllChunksPBN(
  bop: Pointer;
  solvedp: Pointer;
  maxThreads: LongInt
): LongInt; stdcall;

function calc_par(
  const table_deal: DdTableDeal;
  vulnerable: LongInt;
  table_results: PDdTableResults;
  par_results: PParResults
): LongInt; stdcall; overload;

function calc_par(
  ctx: TSolverContext;
  const table_deal: DdTableDeal;
  vulnerable: LongInt;
  table_results: PDdTableResults;
  par_results: PParResults
): LongInt; stdcall; overload;

function calc_par_from_table(
  const table_results: PDdTableResults;
  vulnerable: LongInt;
  par_results: PParResults
): LongInt; stdcall;

implementation

function is_card(const cardChar: AnsiChar): LongInt;
begin
  case cardChar of
    '2': Result := 2;
    '3': Result := 3;
    '4': Result := 4;
    '5': Result := 5;
    '6': Result := 6;
    '7': Result := 7;
    '8': Result := 8;
    '9': Result := 9;
    'T', 't': Result := 10;
    'J', 'j': Result := 11;
    'Q', 'q': Result := 12;
    'K', 'k': Result := 13;
    'A', 'a': Result := 14;
    else Result := 0;
  end;
end;

function convert_from_pbn(
  const dealBuff: array of AnsiChar;
  var remainCards: TCardsArray
): LongInt;
var
  bp, first, hand_rel_first, suitInHand, card, hand, h, s: LongInt;
begin
  for h := 0 to DDS_HANDS - 1 do
    for s := 0 to DDS_SUITS - 1 do
      remainCards[h, s] := 0;

  bp := 0;
  while (bp < 3) and (dealBuff[bp] <> 'W') and (dealBuff[bp] <> 'N') and
        (dealBuff[bp] <> 'E') and (dealBuff[bp] <> 'S') and
        (dealBuff[bp] <> 'w') and (dealBuff[bp] <> 'n') and
        (dealBuff[bp] <> 'e') and (dealBuff[bp] <> 's') do
    Inc(bp);

  if bp >= 3 then
  begin
    Result := 0;
    Exit;
  end;

  if (dealBuff[bp] = 'N') or (dealBuff[bp] = 'n') then
    first := 0
  else if (dealBuff[bp] = 'E') or (dealBuff[bp] = 'e') then
    first := 1
  else if (dealBuff[bp] = 'S') or (dealBuff[bp] = 's') then
    first := 2
  else
    first := 3;

  Inc(bp, 2);

  hand_rel_first := 0;
  suitInHand := 0;

  while (bp < 80) and (dealBuff[bp] <> #0) do
  begin
    card := is_card(dealBuff[bp]);
    if card <> 0 then
    begin
      case first of
        0: hand := hand_rel_first;
        1:
          if hand_rel_first = 0 then hand := 1
          else if hand_rel_first = 3 then hand := 0
          else hand := hand_rel_first + 1;
        2:
          if hand_rel_first = 0 then hand := 2
          else if hand_rel_first = 1 then hand := 3
          else hand := hand_rel_first - 2;
        else
          if hand_rel_first = 0 then hand := 3
          else hand := hand_rel_first - 1;
      end;

      remainCards[hand, suitInHand] := remainCards[hand, suitInHand] or (bit_map_rank[card] shl 2);
    end
    else if dealBuff[bp] = '.' then
      Inc(suitInHand)
    else if dealBuff[bp] = ' ' then
    begin
      Inc(hand_rel_first);
      suitInHand := 0;
    end;
    Inc(bp);
  end;
  Result := RETURN_NO_FAULT;
end;

function board_range_checks(
  const dl: Deal;
  const target: LongInt;
  const solutions: LongInt;
  const mode: LongInt
): LongInt;
var
  k, r, h, s: LongInt;
  rankSeen: array[0..2] of LongInt;
  c: Cardinal;
begin
  if target < -1 then
  begin
    Result := RETURN_TARGET_WRONG_LO;
    Exit;
  end;

  if target > 13 then
  begin
    Result := RETURN_TARGET_WRONG_HI;
    Exit;
  end;

  if solutions < 1 then
  begin
    Result := RETURN_SOLNS_WRONG_LO;
    Exit;
  end;

  if solutions > 3 then
  begin
    Result := RETURN_SOLNS_WRONG_HI;
    Exit;
  end;

  if mode < 0 then
  begin
    Result := RETURN_MODE_WRONG_LO;
    Exit;
  end;

  if mode > 2 then
  begin
    Result := RETURN_MODE_WRONG_HI;
    Exit;
  end;

  if (dl.trump < 0) or (dl.trump > 4) then
  begin
    Result := RETURN_TRUMP_WRONG;
    Exit;
  end;

  if (dl.first < 0) or (dl.first > 3) then
  begin
    Result := RETURN_FIRST_WRONG;
    Exit;
  end;

  rankSeen[0] := 0; rankSeen[1] := 0; rankSeen[2] := 0;
  for k := 0 to 2 do
  begin
    r := dl.currentTrickRank[k];
    if r = 0 then
      continue;

    rankSeen[k] := 1;

    if (r < 2) or (r > 14) then
    begin
      Result := RETURN_SUIT_OR_RANK;
      Exit;
    end;

    if (dl.currentTrickSuit[k] < 0) or (dl.currentTrickSuit[k] > 3) then
    begin
      Result := RETURN_SUIT_OR_RANK;
      Exit;
    end;
  end;

  if ((rankSeen[2] <> 0) and ((rankSeen[1] = 0) or (rankSeen[0] = 0))) or
     ((rankSeen[1] <> 0) and (rankSeen[0] = 0)) then
  begin
    Result := RETURN_SUIT_OR_RANK;
    Exit;
  end;

  for h := 0 to DDS_HANDS - 1 do
  begin
    for s := 0 to DDS_SUITS - 1 do
    begin
      c := dl.remainCards[h, s];
      if (c <> 0) and ((c < $0004) or (c >= $8000)) then
      begin
        Result := RETURN_SUIT_OR_RANK;
        Exit;
      end;
    end;
  end;

  Result := RETURN_NO_FAULT;
end;

function board_value_checks(
  ctx: TSolverContext;
  const dl: Deal;
  const target: LongInt;
  const solutions: LongInt;
  const mode: LongInt
): LongInt;
var
  cardCount, totalTricks, hand_rel_first, h, s, r, k: LongInt;
  noOfCardsPerHand: array[0..DDS_HANDS - 1] of LongInt;
  thrp: PThreadData;
  aggrRemain: Word;
  found: Boolean;
begin
  thrp := ctx.thread_ptr;
  cardCount := thrp^.iniDepth + 4;
  if cardCount <= 0 then
  begin
    Result := RETURN_ZERO_CARDS;
    Exit;
  end;

  if cardCount > 52 then
  begin
    Result := RETURN_TOO_MANY_CARDS;
    Exit;
  end;

  if (cardCount mod 4) <> 0 then
    totalTricks := ((cardCount - 4) >> 2) + 2
  else
    totalTricks := ((cardCount - 4) >> 2) + 1;

  if totalTricks < target then
  begin
    Result := RETURN_TARGET_TOO_HIGH;
    Exit;
  end;

  hand_rel_first := thrp^.lookAheadPos.hand_rel_first;

  for h := 0 to DDS_HANDS - 1 do
    noOfCardsPerHand[h] := 0;

  for k := 0 to hand_rel_first - 1 do
    noOfCardsPerHand[(dl.first + k) and 3] := 1;

  for h := 0 to DDS_HANDS - 1 do
    for s := 0 to DDS_SUITS - 1 do
      noOfCardsPerHand[h] := noOfCardsPerHand[h] + count_table[thrp^.suit[h, s]];

  for h := 1 to DDS_HANDS - 1 do
  begin
    if noOfCardsPerHand[h] <> noOfCardsPerHand[0] then
    begin
      Result := RETURN_CARD_COUNT;
      Exit;
    end;
  end;

  for k := 0 to hand_rel_first - 1 do
  begin
    aggrRemain := 0;
    for h := 0 to DDS_HANDS - 1 do
      aggrRemain := aggrRemain or (dl.remainCards[h, dl.currentTrickSuit[k]] >> 2);

    if (aggrRemain and bit_map_rank[dl.currentTrickRank[k]]) <> 0 then
    begin
      Result := RETURN_PLAYED_CARD;
      Exit;
    end;
  end;

  for s := 0 to DDS_SUITS - 1 do
  begin
    for r := 2 to 14 do
    begin
      found := false;
      for h := 0 to DDS_HANDS - 1 do
      begin
        if (thrp^.suit[h, s] and bit_map_rank[r]) <> 0 then
        begin
          if found then
          begin
            Result := RETURN_DUPLICATE_CARDS;
            Exit;
          end
          else
            found := true;
        end;
      end;
    end;
  end;

  Result := RETURN_NO_FAULT;
end;

procedure last_trick_winner(
  const dl: Deal;
  thrp: PThreadData;
  const handToPlay: LongInt;
  const hand_rel_first: LongInt;
  var leadRank: LongInt;
  var leadSuit: LongInt;
  var leadSideWins: LongInt
);
var
  lastTrickSuit, lastTrickRank: array[0..DDS_HANDS - 1] of LongInt;
  h, hp, s, maxRank, maxSuit, maxHand: LongInt;
begin
  for h := 0 to hand_rel_first - 1 do
  begin
    hp := (dl.first + h) and 3;
    lastTrickSuit[hp] := dl.currentTrickSuit[h];
    lastTrickRank[hp] := dl.currentTrickRank[h];
  end;

  for h := hand_rel_first to DDS_HANDS - 1 do
  begin
    hp := (dl.first + h) and 3;
    for s := 0 to DDS_SUITS - 1 do
    begin
      if thrp^.suit[hp, s] <> 0 then
      begin
        lastTrickSuit[hp] := s;
        lastTrickRank[hp] := highest_rank[thrp^.suit[hp, s]];
        break;
      end;
    end;
  end;

  maxRank := 0;
  maxSuit := 0;
  maxHand := -1;

  if dl.trump <> DDS_NOTRUMP then
  begin
    for h := 0 to DDS_HANDS - 1 do
    begin
      if (lastTrickSuit[h] = dl.trump) and (lastTrickRank[h] > maxRank) then
      begin
        maxRank := lastTrickRank[h];
        maxSuit := dl.trump;
        maxHand := h;
      end;
    end;
  end;

  if maxRank = 0 then
  begin
    maxRank := lastTrickRank[dl.first];
    maxSuit := lastTrickSuit[dl.first];
    maxHand := dl.first;

    for h := 0 to DDS_HANDS - 1 do
    begin
      if (lastTrickSuit[h] = maxSuit) and (lastTrickRank[h] > maxRank) then
      begin
        maxHand := h;
        maxRank := lastTrickRank[h];
      end;
    end;
  end;

  hp := (dl.first + hand_rel_first) and 3;
  leadRank := lastTrickRank[hp];
  leadSuit := lastTrickSuit[hp];

  if (handToPlay = maxHand) or (partner[handToPlay] = maxHand) then
    leadSideWins := 1
  else
    leadSideWins := 0;
end;

procedure SetDeal(thrp: PThreadData);
var
  h, s: LongInt;
begin
  for h := 0 to DDS_HANDS - 1 do
  begin
    thrp^.lookAheadPos.hand_dist[h] := 0;
    for s := 0 to DDS_SUITS - 1 do
    begin
      thrp^.lookAheadPos.length[h, s] := count_table[thrp^.suit[h, s]];
      thrp^.lookAheadPos.rank_in_suit[h, s] := thrp^.suit[h, s];
      thrp^.lookAheadPos.hand_dist[h] := thrp^.lookAheadPos.hand_dist[h] or (thrp^.lookAheadPos.length[h, s] shl (s * 4));
    end;
  end;
end;

procedure SetDealTables(ctx: TSolverContext);
var
  thrp: PThreadData;
  topBitRank: Cardinal;
  topBitNo: LongInt;
  s, ord, r, h, c, weight: LongInt;
  aggr: Cardinal;
  handLookup: THandLookup;
  relp: PRelRanksType;
begin
  thrp := ctx.thread_ptr;
  topBitRank := 1;
  topBitNo := 2;

  for s := 0 to DDS_SUITS - 1 do
  begin
    for ord := 1 to 13 do
    begin
      thrp^.rel[0].abs_rank[ord, s].hand := -1;
      thrp^.rel[0].abs_rank[ord, s].rank := 0;
    end;
  end;

  for s := 0 to DDS_SUITS - 1 do
  begin
    for r := 14 downto 2 do
    begin
      handLookup[s, r] := 0;
      for h := 0 to DDS_HANDS - 1 do
      begin
        if (thrp^.suit[h, s] and bit_map_rank[r]) <> 0 then
        begin
          handLookup[s, r] := h;
          break;
        end;
      end;
    end;
  end;

  ctx.trans_table.init(handLookup);

  for aggr := 1 to 8191 do
  begin
    if aggr >= (topBitRank shl 1) then
    begin
      topBitRank := topBitRank shl 1;
      Inc(topBitNo);
    end;

    thrp^.rel[aggr] := thrp^.rel[aggr xor topBitRank];
    relp := @(thrp^.rel[aggr]);

    weight := count_table[aggr];
    for c := weight downto 2 do
    begin
      for s := 0 to DDS_SUITS - 1 do
      begin
        relp^.abs_rank[c, s].hand := relp^.abs_rank[c - 1, s].hand;
        relp^.abs_rank[c, s].rank := relp^.abs_rank[c - 1, s].rank;
      end;
    end;
    for s := 0 to DDS_SUITS - 1 do
    begin
      relp^.abs_rank[1, s].hand := handLookup[s, topBitNo];
      relp^.abs_rank[1, s].rank := topBitNo;
    end;
  end;

  for s := 0 to DDS_SUITS - 1 do
  begin
    aggr := 0;
    for h := 0 to DDS_HANDS - 1 do
      aggr := aggr or thrp^.suit[h, s];
    thrp^.lookAheadPos.aggr[s] := aggr;

    thrp^.lookAheadPos.winner[s].rank := thrp^.rel[aggr].abs_rank[1, s].rank;
    thrp^.lookAheadPos.winner[s].hand := thrp^.rel[aggr].abs_rank[1, s].hand;
    thrp^.lookAheadPos.second_best[s].rank := thrp^.rel[aggr].abs_rank[2, s].rank;
    thrp^.lookAheadPos.second_best[s].hand := thrp^.rel[aggr].abs_rank[2, s].hand;
  end;
end;

procedure InitWinners(const dl: Deal; var pos: Pos; thrp: PThreadData);
var
  h, s, k, hand, suit, rank, aggr: LongInt;
  startMovesBitMap: array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of Word;
begin
  for h := 0 to DDS_HANDS - 1 do
    for s := 0 to DDS_SUITS - 1 do
      startMovesBitMap[h, s] := 0;

  for k := 0 to pos.hand_rel_first - 1 do
  begin
    hand := (dl.first + k) and 3;
    suit := dl.currentTrickSuit[k];
    rank := dl.currentTrickRank[k];
    startMovesBitMap[hand, suit] := startMovesBitMap[hand, suit] or bit_map_rank[rank];
  end;

  for s := 0 to DDS_SUITS - 1 do
  begin
    aggr := 0;
    for h := 0 to DDS_HANDS - 1 do
      aggr := aggr or startMovesBitMap[h, s] or thrp^.suit[h, s];

    pos.winner[s].rank := thrp^.rel[aggr].abs_rank[1, s].rank;
    pos.winner[s].hand := thrp^.rel[aggr].abs_rank[1, s].hand;
    pos.second_best[s].rank := thrp^.rel[aggr].abs_rank[2, s].rank;
    pos.second_best[s].hand := thrp^.rel[aggr].abs_rank[2, s].hand;
  end;
end;

function solve_board_internal(
  ctx: TSolverContext;
  const dl: Deal;
  const target: LongInt;
  const solutions: LongInt;
  const mode: LongInt;
  futp: PFutureTricks
): LongInt;
var
  i, ret, cardCount, h, s, ini_depth, trick, hand_rel_first, handToPlay, noMoves, guess, upperbound, lowerbound, mno, j, forb, ind, num, k, r: LongInt;
  thrp: PThreadData;
  newDeal, newTrump, similarDeal, val: Boolean;
  c, diffDeal, aggDeal, suit_ranks: Cardinal;
  mv, forbidden_mv: MoveType;
  leadRank, leadSuit, leadSideWins: LongInt;
  mply: PMoveType;
  hand_lookup: THandLookup;
begin
  ret := board_range_checks(dl, target, solutions, mode);
  if ret <> RETURN_NO_FAULT then
  begin
    Result := ret;
    Exit;
  end;

  thrp := ctx.thread_ptr;
  newDeal := false;
  newTrump := false;
  diffDeal := 0;
  aggDeal := 0;
  cardCount := 0;

  for h := 0 to DDS_HANDS - 1 do
  begin
    for s := 0 to DDS_SUITS - 1 do
    begin
      c := dl.remainCards[h, s] >> 2;
      cardCount := cardCount + count_table[c];
      diffDeal := diffDeal + (c xor thrp^.suit[h, s]);
      aggDeal := aggDeal + c;

      if thrp^.suit[h, s] <> c then
      begin
        thrp^.suit[h, s] := c;
        newDeal := true;
      end;
    end;
  end;

  if newDeal then
  begin
    if diffDeal = 0 then
      similarDeal := true
    else if (Double(aggDeal) / Double(diffDeal)) > SIMILARDEALLIMIT then
      similarDeal := true
    else
      similarDeal := false;
  end
  else
    similarDeal := false;

  if cardCount <= 0 then
  begin
    Result := RETURN_ZERO_CARDS;
    Exit;
  end;

  if cardCount > 52 then
  begin
    Result := RETURN_TOO_MANY_CARDS;
    Exit;
  end;

  if dl.trump <> thrp^.trump then
    newTrump := true;

  thrp^.trump := dl.trump;
  thrp^.iniDepth := cardCount - 4;
  ini_depth := thrp^.iniDepth;
  trick := (ini_depth + 3) >> 2;
  hand_rel_first := (48 - ini_depth) mod 4;
  handToPlay := (dl.first + hand_rel_first) and 3;
  thrp^.trickNodes := 0;

  thrp^.lookAheadPos.hand_rel_first := hand_rel_first;
  thrp^.lookAheadPos.first[ini_depth] := dl.first;
  thrp^.lookAheadPos.tricks_max := 0;

  mv.suit := 0; mv.rank := 0; mv.sequence := 0; mv.weight := 0;

  for k := 0 to 13 do
  begin
    thrp^.forbiddenMoves[k].suit := 0;
    thrp^.forbiddenMoves[k].rank := 0;
  end;

  ret := board_value_checks(ctx, dl, target, solutions, mode);
  if ret <> RETURN_NO_FAULT then
  begin
    Result := ret;
    Exit;
  end;

  if cardCount <= 4 then
  begin
    last_trick_winner(dl, thrp, handToPlay, hand_rel_first, leadRank, leadSuit, leadSideWins);
    futp^.nodes := 0;
    futp^.cards := 1;
    futp^.suit[0] := leadSuit;
    futp^.rank[0] := leadRank;
    futp^.equals[0] := 0;
    if (target = 0) and (solutions < 3) then
      futp^.score[0] := 0
    else
      futp^.score[0] := leadSideWins;

    Result := RETURN_NO_FAULT;
    Exit;
  end;

  if newDeal and (not similarDeal) then
    ctx.trans_table.reset_memory(ResetReason_NewDeal);

  if newDeal then
  begin
    for s := 0 to DDS_SUITS - 1 do
      for r := 0 to 14 do
        hand_lookup[s, r] := 0;

    for h := 0 to DDS_HANDS - 1 do
    begin
      for s := 0 to DDS_SUITS - 1 do
      begin
        suit_ranks := dl.remainCards[h, s] >> 2;
        for r := 2 to 14 do
        begin
          if (suit_ranks and bit_map_rank[r]) <> 0 then
            hand_lookup[s, r] := h;
        end;
      end;
    end;

    ctx.trans_table.init(hand_lookup);

    SetDeal(thrp);
    SetDealTables(ctx);
  end;

  if (handToPlay = 0) or (handToPlay = 2) then
  begin
    thrp^.nodeTypeStore[0] := MAXNODE;
    thrp^.nodeTypeStore[1] := MINNODE;
    thrp^.nodeTypeStore[2] := MAXNODE;
    thrp^.nodeTypeStore[3] := MINNODE;
  end
  else
  begin
    thrp^.nodeTypeStore[0] := MINNODE;
    thrp^.nodeTypeStore[1] := MAXNODE;
    thrp^.nodeTypeStore[2] := MINNODE;
    thrp^.nodeTypeStore[3] := MAXNODE;
  end;

  for k := 0 to hand_rel_first - 1 do
  begin
    mv.rank := dl.currentTrickRank[k];
    mv.suit := dl.currentTrickSuit[k];
    mv.sequence := 0;

    TMoves(ctx.move_gen).Init(trick, k, dl.currentTrickRank, dl.currentTrickSuit, thrp^.lookAheadPos.rank_in_suit, thrp^.trump, thrp^.lookAheadPos.first[ini_depth]);

    if k = 0 then
      TMoves(ctx.move_gen).MoveGen0(trick, thrp^.lookAheadPos, thrp^.bestMove[ini_depth], thrp^.bestMoveTT[ini_depth], thrp^.rel)
    else
      TMoves(ctx.move_gen).MoveGen123(trick, k, thrp^.lookAheadPos);

    thrp^.lookAheadPos.move[ini_depth + hand_rel_first - k] := mv;
    TMoves(ctx.move_gen).MakeSpecific(mv, trick, k);
  end;

  InitWinners(dl, thrp^.lookAheadPos, thrp);

  TMoves(ctx.move_gen).Init(trick, hand_rel_first, dl.currentTrickRank, dl.currentTrickSuit, thrp^.lookAheadPos.rank_in_suit, thrp^.trump, thrp^.lookAheadPos.first[ini_depth]);

  if hand_rel_first = 0 then
    TMoves(ctx.move_gen).MoveGen0(trick, thrp^.lookAheadPos, thrp^.bestMove[ini_depth], thrp^.bestMoveTT[ini_depth], thrp^.rel)
  else
    TMoves(ctx.move_gen).MoveGen123(trick, hand_rel_first, thrp^.lookAheadPos);

  noMoves := TMoves(ctx.move_gen).GetLength(trick, hand_rel_first);

  if (mode = 0) and (noMoves = 1) and (solutions <> 3) then
  begin
    mply := TMoves(ctx.move_gen).MakeNextSimple(trick, hand_rel_first);
    futp^.nodes := 0;
    futp^.cards := 1;
    futp^.suit[0] := mply^.suit;
    futp^.rank[0] := mply^.rank;
    futp^.equals[0] := mply^.sequence << 2;
    futp^.score[0] := -2;
    Result := RETURN_NO_FAULT;
    Exit;
  end;

  if solutions = 3 then
  begin
    guess := 7 - (handToPlay and 1);
    upperbound := 13;
    lowerbound := 0;
    futp^.cards := noMoves;

    for mno := 0 to noMoves - 1 do
    begin
      repeat
        thrp^.bestMove[ini_depth].rank := 0;
        thrp^.bestMoveTT[ini_depth].rank := 0;

        case hand_rel_first of
          0: val := ab_search_0(thrp^.lookAheadPos, guess, ini_depth, ctx);
          1: val := ab_search_1(thrp^.lookAheadPos, guess, ini_depth, ctx);
          2: val := ab_search_2(thrp^.lookAheadPos, guess, ini_depth, ctx);
          else val := ab_search_3(thrp^.lookAheadPos, guess, ini_depth, ctx);
        end;

        if val then
        begin
          mv := thrp^.bestMove[ini_depth];
          lowerbound := guess;
          Inc(guess);
        end
        else
        begin
          Dec(guess);
          upperbound := guess;
        end;
      until lowerbound >= upperbound;

      if lowerbound <> 0 then
      begin
        thrp^.bestMove[ini_depth] := mv;
        futp^.suit[mno] := mv.suit;
        futp^.rank[mno] := mv.rank;
        futp^.equals[mno] := mv.sequence << 2;
        futp^.score[mno] := lowerbound;

        thrp^.forbiddenMoves[mno + 1].suit := mv.suit;
        thrp^.forbiddenMoves[mno + 1].rank := mv.rank;

        guess := lowerbound;
        lowerbound := 0;
      end
      else
      begin
        j := TMoves(ctx.move_gen).GetLength(trick, hand_rel_first);
        TMoves(ctx.move_gen).Rewind(trick, hand_rel_first);
        for k := 0 to j - 1 do
        begin
          mply := TMoves(ctx.move_gen).MakeNextSimple(trick, hand_rel_first);
          futp^.suit[mno + k] := mply^.suit;
          futp^.rank[mno + k] := mply^.rank;
          futp^.equals[mno + k] := mply^.sequence << 2;
          futp^.score[mno + k] := 0;
        end;
        break;
      end;
    end;
  end
  else if target = 0 then
  begin
    futp^.nodes := 0;
    if solutions = 1 then futp^.cards := 1 else futp^.cards := noMoves;
    for mno := 0 to noMoves - 1 do
    begin
      mply := TMoves(ctx.move_gen).MakeNextSimple(trick, hand_rel_first);
      futp^.suit[mno] := mply^.suit;
      futp^.rank[mno] := mply^.rank;
      futp^.equals[mno] := mply^.sequence << 2;
      futp^.score[mno] := 0;
    end;
  end
  else if target = -1 then
  begin
    guess := 7 - (handToPlay and 1);
    upperbound := 13;
    lowerbound := 0;
    repeat
      thrp^.bestMove[ini_depth].rank := 0;
      thrp^.bestMoveTT[ini_depth].rank := 0;

      case hand_rel_first of
        0: val := ab_search_0(thrp^.lookAheadPos, guess, ini_depth, ctx);
        1: val := ab_search_1(thrp^.lookAheadPos, guess, ini_depth, ctx);
        2: val := ab_search_2(thrp^.lookAheadPos, guess, ini_depth, ctx);
        else val := ab_search_3(thrp^.lookAheadPos, guess, ini_depth, ctx);
      end;

      if val then
      begin
        mv := thrp^.bestMove[ini_depth];
        lowerbound := guess;
        Inc(guess);
      end
      else
      begin
        Dec(guess);
        upperbound := guess;
      end;
    until lowerbound >= upperbound;

    thrp^.bestMove[ini_depth] := mv;

    if lowerbound = 0 then
    begin
      if solutions = 1 then futp^.cards := 1 else futp^.cards := noMoves;
      TMoves(ctx.move_gen).Rewind(trick, hand_rel_first);
      for i := 0 to noMoves - 1 do
      begin
        mply := TMoves(ctx.move_gen).MakeNextSimple(trick, hand_rel_first);
        futp^.score[i] := 0;
        futp^.suit[i] := mply^.suit;
        futp^.rank[i] := mply^.rank;
        futp^.equals[i] := mply^.sequence << 2;
      end;
    end
    else
    begin
      futp^.cards := 1;
      futp^.score[0] := lowerbound;
      futp^.suit[0] := mv.suit;
      futp^.rank[0] := mv.rank;
      futp^.equals[0] := mv.sequence << 2;

      if solutions = 2 then
      begin
        forb := 1;
        ind := 1;
        while ind < noMoves do
        begin
          TMoves(ctx.move_gen).Rewind(trick, hand_rel_first);
          num := TMoves(ctx.move_gen).GetLength(trick, hand_rel_first);
          for k := 0 to num - 1 do
          begin
            mply := TMoves(ctx.move_gen).MakeNextSimple(trick, hand_rel_first);
            thrp^.forbiddenMoves[forb] := mply^;
            Inc(forb);
            if (thrp^.bestMove[ini_depth].suit = mply^.suit) and
               (thrp^.bestMove[ini_depth].rank = mply^.rank) then
              break;
          end;

          case hand_rel_first of
            0: val := ab_search_0(thrp^.lookAheadPos, futp^.score[0], ini_depth, ctx);
            1: val := ab_search_1(thrp^.lookAheadPos, futp^.score[0], ini_depth, ctx);
            2: val := ab_search_2(thrp^.lookAheadPos, futp^.score[0], ini_depth, ctx);
            else val := ab_search_3(thrp^.lookAheadPos, futp^.score[0], ini_depth, ctx);
          end;

          if not val then
            break;

          futp^.cards := ind + 1;
          futp^.suit[ind] := thrp^.bestMove[ini_depth].suit;
          futp^.rank[ind] := thrp^.bestMove[ini_depth].rank;
          futp^.equals[ind] := thrp^.bestMove[ini_depth].sequence << 2;
          futp^.score[ind] := futp^.score[0];
          Inc(ind);
        end;
      end;
    end;
  end
  else
  begin
    case hand_rel_first of
      0: val := ab_search_0(thrp^.lookAheadPos, target, ini_depth, ctx);
      1: val := ab_search_1(thrp^.lookAheadPos, target, ini_depth, ctx);
      2: val := ab_search_2(thrp^.lookAheadPos, target, ini_depth, ctx);
      else val := ab_search_3(thrp^.lookAheadPos, target, ini_depth, ctx);
    end;

    if not val then
    begin
      futp^.cards := 0;
      if target > 1 then futp^.score[0] := -1 else futp^.score[0] := 0;
    end
    else
    begin
      futp^.cards := 1;
      futp^.suit[0] := thrp^.bestMove[ini_depth].suit;
      futp^.rank[0] := thrp^.bestMove[ini_depth].rank;
      futp^.equals[0] := thrp^.bestMove[ini_depth].sequence << 2;
      futp^.score[0] := target;

      if solutions = 2 then
      begin
        forb := 1;
        ind := 1;
        while ind < noMoves do
        begin
          TMoves(ctx.move_gen).Rewind(trick, hand_rel_first);
          num := TMoves(ctx.move_gen).GetLength(trick, hand_rel_first);
          for k := 0 to num - 1 do
          begin
            mply := TMoves(ctx.move_gen).MakeNextSimple(trick, hand_rel_first);
            thrp^.forbiddenMoves[forb] := mply^;
            Inc(forb);
            if (thrp^.bestMove[ini_depth].suit = mply^.suit) and
               (thrp^.bestMove[ini_depth].rank = mply^.rank) then
              break;
          end;

          case hand_rel_first of
            0: val := ab_search_0(thrp^.lookAheadPos, futp^.score[0], ini_depth, ctx);
            1: val := ab_search_1(thrp^.lookAheadPos, futp^.score[0], ini_depth, ctx);
            2: val := ab_search_2(thrp^.lookAheadPos, futp^.score[0], ini_depth, ctx);
            else val := ab_search_3(thrp^.lookAheadPos, futp^.score[0], ini_depth, ctx);
          end;

          if not val then
            break;

          futp^.cards := ind + 1;
          futp^.suit[ind] := thrp^.bestMove[ini_depth].suit;
          futp^.rank[ind] := thrp^.bestMove[ini_depth].rank;
          futp^.equals[ind] := thrp^.bestMove[ini_depth].sequence << 2;
          futp^.score[ind] := futp^.score[0];
          Inc(ind);
        end;
      end;
    end;
  end;

  for k := 0 to 13 do
  begin
    thrp^.forbiddenMoves[k].suit := 0;
    thrp^.forbiddenMoves[k].rank := 0;
  end;

  futp^.nodes := thrp^.trickNodes;
  Result := RETURN_NO_FAULT;
end;

function solve_same_board(
  ctx: TSolverContext;
  const dl: Deal;
  futp: PFutureTricks;
  const hint: LongInt
): LongInt;
var
  thrp: PThreadData;
  ini_depth, trick, guess, lowerbound, upperbound: LongInt;
  val: Boolean;
begin
  thrp := ctx.thread_ptr;
  ini_depth := thrp^.iniDepth;
  trick := (ini_depth + 3) >> 2;
  thrp^.trickNodes := 0;
  thrp^.lookAheadPos.first[ini_depth] := dl.first;

  if (dl.first = 0) or (dl.first = 2) then
  begin
    thrp^.nodeTypeStore[0] := MAXNODE;
    thrp^.nodeTypeStore[1] := MINNODE;
    thrp^.nodeTypeStore[2] := MAXNODE;
    thrp^.nodeTypeStore[3] := MINNODE;
  end
  else
  begin
    thrp^.nodeTypeStore[0] := MINNODE;
    thrp^.nodeTypeStore[1] := MAXNODE;
    thrp^.nodeTypeStore[2] := MINNODE;
    thrp^.nodeTypeStore[3] := MAXNODE;
  end;

  TMoves(ctx.move_gen).Reinit(trick, dl.first);

  guess := hint;
  lowerbound := 0;
  upperbound := 13;

  repeat
    case (48 - ini_depth) mod 4 of
      0: val := ab_search_0(thrp^.lookAheadPos, guess, ini_depth, ctx);
      1: val := ab_search_1(thrp^.lookAheadPos, guess, ini_depth, ctx);
      2: val := ab_search_2(thrp^.lookAheadPos, guess, ini_depth, ctx);
      else val := ab_search_3(thrp^.lookAheadPos, guess, ini_depth, ctx);
    end;

    if val then
    begin
      lowerbound := guess;
      Inc(guess);
    end
    else
    begin
      Dec(guess);
      upperbound := guess;
    end;
  until lowerbound >= upperbound;

  futp^.cards := 1;
  futp^.score[0] := lowerbound;
  futp^.nodes := thrp^.trickNodes;

  Result := RETURN_NO_FAULT;
end;

function SolveBoard(
  dl: Deal;
  target: LongInt;
  solutions: LongInt;
  mode: LongInt;
  futp: PFutureTricks;
  thrId: LongInt
): LongInt; stdcall;
var
  ctx: TSolverContext;
begin
  ctx := TSolverContext.Create;
  try
    Result := solve_board_internal(ctx, dl, target, solutions, mode, futp);
  finally
    ctx.Free;
  end;
end;

function SolveBoardPBN(
  dlpbn: DealPBN;
  target: LongInt;
  solutions: LongInt;
  mode: LongInt;
  futp: PFutureTricks;
  thrId: LongInt
): LongInt; stdcall;
var
  dl: Deal;
  k: LongInt;
begin
  if convert_from_pbn(dlpbn.remainCards, dl.remainCards) <> RETURN_NO_FAULT then
  begin
    Result := RETURN_PBN_FAULT;
    Exit;
  end;

  for k := 0 to 2 do
  begin
    dl.currentTrickRank[k] := dlpbn.currentTrickRank[k];
    dl.currentTrickSuit[k] := dlpbn.currentTrickSuit[k];
  end;
  dl.first := dlpbn.first;
  dl.trump := dlpbn.trump;

  Result := SolveBoard(dl, target, solutions, mode, futp, thrId);
end;

function calc_single_common_internal(
  ctx: TSolverContext;
  const dl_orig: Deal;
  var table: DdTableResults;
  var fut: FutureTricks
): LongInt;
var
  localDeal: Deal;
  res, k, hint: LongInt;
begin
  localDeal := dl_orig;
  localDeal.first := 0;

  res := solve_board_internal(ctx, localDeal, -1, 1, 1, @fut);
  if res = RETURN_NO_FAULT then
    table.res_table[localDeal.trump, rho[0]] := 13 - fut.score[0]
  else
  begin
    Result := res;
    Exit;
  end;

  for k := 1 to 3 do
  begin
    if k = 2 then hint := fut.score[0] else hint := 13 - fut.score[0];
    localDeal.first := k;
    res := solve_same_board(ctx, localDeal, @fut, hint);
    if res = RETURN_NO_FAULT then
      table.res_table[localDeal.trump, rho[k]] := 13 - fut.score[0]
    else
    begin
      Result := res;
      Exit;
    end;
  end;

  Result := RETURN_NO_FAULT;
end;

function CalcDDtable(
  tableDeal: DdTableDeal;
  tablep: PDdTableResults
): LongInt; stdcall;
var
  ctx: TSolverContext;
  dl: Deal;
  fut: FutureTricks;
  tr, h, s, res: LongInt;
begin
  ctx := TSolverContext.Create;
  try
    for h := 0 to DDS_HANDS - 1 do
      for s := 0 to DDS_SUITS - 1 do
        dl.remainCards[h, s] := tableDeal.cards[h, s];

    for tr := 0 to 2 do
    begin
      dl.currentTrickRank[tr] := 0;
      dl.currentTrickSuit[tr] := 0;
    end;

    for tr := DDS_STRAINS - 1 downto 0 do
    begin
      dl.trump := tr;
      res := calc_single_common_internal(ctx, dl, tablep^, fut);
      if res <> RETURN_NO_FAULT then
      begin
        Result := res;
        Exit;
      end;
    end;
    Result := RETURN_NO_FAULT;
  finally
    ctx.Free;
  end;
end;

function CalcDDtablePBN(
  tableDealPBN: DdTableDealPBN;
  tablep: PDdTableResults
): LongInt; stdcall;
var
  tableDeal: DdTableDeal;
begin
  if convert_from_pbn(tableDealPBN.cards, tableDeal.cards) <> RETURN_NO_FAULT then
  begin
    Result := RETURN_PBN_FAULT;
    Exit;
  end;

  Result := CalcDDtable(tableDeal, tablep);
end;

function CalcAllTablesPBN(
  dealsp: PDdTableDealsPBN;
  mode: LongInt;
  trumpFilter: PTrumpFilter;
  resp: PDdTablesRes;
  presp: PBobAllParResults
): LongInt; stdcall;
var
  tableDealPBN: DdTableDealPBN;
  tablep: DdTableResults;
  m, tr, res, count, k: LongInt;
  tf: array[0..4] of LongInt;
  okey: Boolean;
  dealerParRes: ParResultsDealer;
begin
  okey := false;
  count := 0;
  for k := 0 to DDS_STRAINS - 1 do
  begin
    if trumpFilter^[k] = 0 then
    begin
      okey := true;
      Inc(count);
    end;
  end;

  if not okey then
  begin
    Result := RETURN_NO_SUIT;
    Exit;
  end;

  resp^.no_of_boards := dealsp^.no_of_tables;

  for m := 0 to dealsp^.no_of_tables - 1 do
  begin
    tableDealPBN := dealsp^.deals[m];
    res := CalcDDtablePBN(tableDealPBN, @tablep);
    if res <> RETURN_NO_FAULT then
    begin
      Result := res;
      Exit;
    end;

    resp^.results[m] := tablep;

    if (mode > -1) and (mode < 4) and (count = 5) then
    begin
      res := DealerPar(@(resp^.results[m]), @dealerParRes, 0, mode);
      // Copy par string format from DealerPar output to par_results
      // Vulnerability 0: None 1: Both 2: NS 3: EW
      if res = RETURN_NO_FAULT then
      begin
        // Format the par score and string for Bob's testing (e.g. presp^[m].parScore[0])
        StrToCharArray(IntToStr(dealerParRes.score), presp^[m].parScore[0].AScore);
        StrToCharArray(dealerParRes.contracts[0], presp^[m].ParStr[0].aContract);
      end
      else
      begin
        Result := res;
        Exit;
      end;
    end;
  end;

  Result := RETURN_NO_FAULT;
end;

function SolveBoardBin(
  dldbin: Pointer;
  target: LongInt;
  solutions: LongInt;
  mode: LongInt;
  futp: PFutureTricks;
  thrId: LongInt
): LongInt; stdcall;
var
  dealBin: PDeal;
begin
  dealBin := PDeal(dldbin);
  Result := SolveBoard(dealBin^, target, solutions, mode, futp, thrId);
end;

function SolveAllChunksBin(
  bop: Pointer;
  solvedp: Pointer;
  maxThreads: LongInt
): LongInt; stdcall;
var
  bds: PBoards;
  solved: PSolvedBoards;
  bno, res: LongInt;
  ctx: TSolverContext;
  fut: FutureTricks;
begin
  bds := PBoards(bop);
  solved := PSolvedBoards(solvedp);

  if bds^.no_of_boards > MAXNOOFBOARDS then
  begin
    Result := RETURN_TOO_MANY_BOARDS;
    Exit;
  end;

  for bno := 0 to MAXNOOFBOARDS - 1 do
    solved^.solved_board[bno].cards := 0;

  ctx := TSolverContext.Create;
  try
    for bno := 0 to bds^.no_of_boards - 1 do
    begin
      res := solve_board_internal(ctx, bds^.deals[bno], bds^.target[bno], bds^.solutions[bno], bds^.mode[bno], @fut);
      if res = RETURN_NO_FAULT then
        solved^.solved_board[bno] := fut
      else
      begin
        Result := res;
        Exit;
      end;
    end;
    solved^.no_of_boards := bds^.no_of_boards;
    Result := RETURN_NO_FAULT;
  finally
    ctx.Free;
  end;
end;

function SolveAllChunksPBN(
  bop: Pointer;
  solvedp: Pointer;
  maxThreads: LongInt
): LongInt; stdcall;
var
  bdsPBN: PBoardsPBN;
  solved: PSolvedBoards;
  bo: Boards;
  k, i, rc: LongInt;
begin
  bdsPBN := PBoardsPBN(bop);
  solved := PSolvedBoards(solvedp);

  bo.no_of_boards := bdsPBN^.no_of_boards;
  if bo.no_of_boards > MAXNOOFBOARDS then
  begin
    Result := RETURN_TOO_MANY_BOARDS;
    Exit;
  end;

  for k := 0 to bdsPBN^.no_of_boards - 1 do
  begin
    bo.mode[k] := bdsPBN^.mode[k];
    bo.solutions[k] := bdsPBN^.solutions[k];
    bo.target[k] := bdsPBN^.target[k];
    bo.deals[k].first := bdsPBN^.deals[k].first;
    bo.deals[k].trump := bdsPBN^.deals[k].trump;

    for i := 0 to 2 do
    begin
      bo.deals[k].currentTrickSuit[i] := bdsPBN^.deals[k].currentTrickSuit[i];
      bo.deals[k].currentTrickRank[i] := bdsPBN^.deals[k].currentTrickRank[i];
    end;

    rc := convert_from_pbn(bdsPBN^.deals[k].remainCards, bo.deals[k].remainCards);
    if rc <> RETURN_NO_FAULT then
    begin
      Result := RETURN_PBN_FAULT;
      Exit;
    end;
  end;

  Result := SolveAllChunksBin(@bo, solved, maxThreads);
end;

function calc_par(
  const table_deal: DdTableDeal;
  vulnerable: LongInt;
  table_results: PDdTableResults;
  par_results: PParResults
): LongInt; stdcall;
var
  res: LongInt;
begin
  res := CalcDDtable(table_deal, table_results);
  if res <> RETURN_NO_FAULT then
  begin
    Result := res;
    Exit;
  end;
  Result := Par(table_results, par_results, vulnerable);
end;

function calc_par(
  ctx: TSolverContext;
  const table_deal: DdTableDeal;
  vulnerable: LongInt;
  table_results: PDdTableResults;
  par_results: PParResults
): LongInt; stdcall;
var
  dl: Deal;
  fut: FutureTricks;
  tr, h, s, res: LongInt;
begin
  for h := 0 to DDS_HANDS - 1 do
    for s := 0 to DDS_SUITS - 1 do
      dl.remainCards[h, s] := table_deal.cards[h, s];

  for tr := 0 to 2 do
  begin
    dl.currentTrickRank[tr] := 0;
    dl.currentTrickSuit[tr] := 0;
  end;

  for tr := DDS_STRAINS - 1 downto 0 do
  begin
    dl.trump := tr;
    res := calc_single_common_internal(ctx, dl, table_results^, fut);
    if res <> RETURN_NO_FAULT then
    begin
      Result := res;
      Exit;
    end;
  end;
  
  Result := Par(table_results, par_results, vulnerable);
end;

function calc_par_from_table(
  const table_results: PDdTableResults;
  vulnerable: LongInt;
  par_results: PParResults
): LongInt; stdcall;
begin
  Result := Par(table_results, par_results, vulnerable);
end;

end.
