unit DDS_ABSearch;

{$mode objfpc}{$H+}
{$R-}{$Q-}

interface

uses
  SysUtils, Math, DDS_Types, DDS_Init, DDS_SolverContext, DDS_Moves,
  DDS_QuickTricks, DDS_LaterTricks;

function ab_search(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;

function ab_search_0(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;

function ab_search_1(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;

function ab_search_2(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;

function ab_search_3(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;

implementation

const
  handDelta: array[0..DDS_SUITS - 1] of LongInt = ( 256, 16, 1, 0 );

// Forward declarations of local helper search routines
function ab_search_0_ctx(var posPoint: Pos; const target: LongInt; const depth: LongInt; ctx: TSolverContext): Boolean; forward;
function ab_search_1_ctx(var posPoint: Pos; const target: LongInt; const depth: LongInt; ctx: TSolverContext): Boolean; forward;
function ab_search_2_ctx(var posPoint: Pos; const target: LongInt; const depth: LongInt; ctx: TSolverContext): Boolean; forward;
function ab_search_3_ctx(var posPoint: Pos; const target: LongInt; const depth: LongInt; ctx: TSolverContext): Boolean; forward;

procedure make_0(var posPoint: Pos; const depth: LongInt; const mply: PMoveType);
var
  h, s, r: LongInt;
begin
  h := posPoint.first[depth];
  s := mply^.suit;
  r := mply^.rank;

  posPoint.first[depth - 1] := h;
  posPoint.move[depth] := mply^;

  posPoint.rank_in_suit[h, s] := posPoint.rank_in_suit[h, s] and (not bit_map_rank[r]);
  posPoint.aggr[s] := posPoint.aggr[s] xor bit_map_rank[r];
  posPoint.hand_dist[h] := posPoint.hand_dist[h] - handDelta[s];
  Dec(posPoint.length[h, s]);
end;

procedure make_1(var posPoint: Pos; const depth: LongInt; const mply: PMoveType);
var
  firstHand, h, s, r: LongInt;
begin
  firstHand := posPoint.first[depth];
  posPoint.first[depth - 1] := firstHand;

  h := (firstHand + 1) and 3;
  s := mply^.suit;
  r := mply^.rank;

  posPoint.rank_in_suit[h, s] := posPoint.rank_in_suit[h, s] and (not bit_map_rank[r]);
  posPoint.aggr[s] := posPoint.aggr[s] xor bit_map_rank[r];
  posPoint.hand_dist[h] := posPoint.hand_dist[h] - handDelta[s];
  Dec(posPoint.length[h, s]);
end;

procedure make_2(var posPoint: Pos; const depth: LongInt; const mply: PMoveType);
var
  firstHand, h, s, r: LongInt;
begin
  firstHand := posPoint.first[depth];
  posPoint.first[depth - 1] := firstHand;

  h := (firstHand + 2) and 3;
  s := mply^.suit;
  r := mply^.rank;

  posPoint.rank_in_suit[h, s] := posPoint.rank_in_suit[h, s] and (not bit_map_rank[r]);
  posPoint.aggr[s] := posPoint.aggr[s] xor bit_map_rank[r];
  posPoint.hand_dist[h] := posPoint.hand_dist[h] - handDelta[s];
  Dec(posPoint.length[h, s]);
end;

procedure make_3_ctx(
  var posPoint: Pos;
  var trickCards: array of Word;
  const depth: LongInt;
  const mply: PMoveType;
  ctx: TSolverContext
);
var
  firstHand, h, r, s, ss, rr, suit, st, n, aggr: LongInt;
  data: TrickDataType;
  wp: ^WinnersType;
  thrp: PThreadData;
begin
  thrp := ctx.thread_ptr;
  firstHand := posPoint.first[depth];

  data := TMoves(ctx.move_gen).GetTrickData((depth + 3) >> 2);

  posPoint.first[depth - 1] := (firstHand + data.rel_winner) and 3;
  h := (firstHand + 3) and 3;

  for suit := 0 to DDS_SUITS - 1 do
    trickCards[suit] := 0;

  ss := data.best_suit;
  if data.play_count[ss] >= 2 then
  begin
    rr := data.best_rank;
    trickCards[ss] := bit_map_rank[rr] or data.best_sequence;
  end;

  r := mply^.rank;
  s := mply^.suit;
  posPoint.rank_in_suit[h, s] := posPoint.rank_in_suit[h, s] and (not bit_map_rank[r]);
  posPoint.aggr[s] := posPoint.aggr[s] xor bit_map_rank[r];
  posPoint.hand_dist[h] := posPoint.hand_dist[h] - handDelta[s];
  Dec(posPoint.length[h, s]);

  wp := @(thrp^.winners[(depth + 3) >> 2]);
  wp^.number := 0;

  for st := 0 to 3 do
  begin
    if data.play_count[st] <> 0 then
    begin
      n := wp^.number;
      wp^.winner[n].suit := st;
      wp^.winner[n].winnerRank := posPoint.winner[st].rank;
      wp^.winner[n].winnerHand := posPoint.winner[st].hand;
      wp^.winner[n].secondRank := posPoint.second_best[st].rank;
      wp^.winner[n].secondHand := posPoint.second_best[st].hand;
      Inc(wp^.number);

      aggr := posPoint.aggr[st];

      posPoint.winner[st].rank := thrp^.rel[aggr].abs_rank[1, st].rank;
      posPoint.winner[st].hand := thrp^.rel[aggr].abs_rank[1, st].hand;
      posPoint.second_best[st].rank := thrp^.rel[aggr].abs_rank[2, st].rank;
      posPoint.second_best[st].hand := thrp^.rel[aggr].abs_rank[2, st].hand;
    end;
  end;
end;

procedure undo_0_ctx(
  var posPoint: Pos;
  const depth: LongInt;
  const mply: MoveType;
  ctx: TSolverContext
);
var
  h, s, r, n, st: LongInt;
  wp: ^WinnersType;
begin
  h := (posPoint.first[depth] + 3) and 3;
  s := mply.suit;
  r := mply.rank;

  posPoint.rank_in_suit[h, s] := posPoint.rank_in_suit[h, s] or bit_map_rank[r];
  posPoint.aggr[s] := posPoint.aggr[s] or bit_map_rank[r];
  posPoint.hand_dist[h] := posPoint.hand_dist[h] + handDelta[s];
  Inc(posPoint.length[h, s]);

  wp := @(ctx.thread_ptr^.winners[(depth + 3) >> 2]);

  for n := 0 to wp^.number - 1 do
  begin
    st := wp^.winner[n].suit;
    posPoint.winner[st].rank := wp^.winner[n].winnerRank;
    posPoint.winner[st].hand := wp^.winner[n].winnerHand;
    posPoint.second_best[st].rank := wp^.winner[n].secondRank;
    posPoint.second_best[st].hand := wp^.winner[n].secondHand;
  end;
end;

procedure undo_1(var posPoint: Pos; const depth: LongInt; const mply: MoveType);
var
  h, s, r: LongInt;
begin
  h := posPoint.first[depth];
  s := mply.suit;
  r := mply.rank;

  posPoint.rank_in_suit[h, s] := posPoint.rank_in_suit[h, s] or bit_map_rank[r];
  posPoint.aggr[s] := posPoint.aggr[s] or bit_map_rank[r];
  posPoint.hand_dist[h] := posPoint.hand_dist[h] + handDelta[s];
  Inc(posPoint.length[h, s]);
end;

procedure undo_2(var posPoint: Pos; const depth: LongInt; const mply: MoveType);
var
  h, s, r: LongInt;
begin
  h := (posPoint.first[depth] + 1) and 3;
  s := mply.suit;
  r := mply.rank;

  posPoint.rank_in_suit[h, s] := posPoint.rank_in_suit[h, s] or bit_map_rank[r];
  posPoint.aggr[s] := posPoint.aggr[s] or bit_map_rank[r];
  posPoint.hand_dist[h] := posPoint.hand_dist[h] + handDelta[s];
  Inc(posPoint.length[h, s]);
end;

procedure undo_3(var posPoint: Pos; const depth: LongInt; const mply: MoveType);
var
  h, s, r: LongInt;
begin
  h := (posPoint.first[depth] + 2) and 3;
  s := mply.suit;
  r := mply.rank;

  posPoint.rank_in_suit[h, s] := posPoint.rank_in_suit[h, s] or bit_map_rank[r];
  posPoint.aggr[s] := posPoint.aggr[s] or bit_map_rank[r];
  posPoint.hand_dist[h] := posPoint.hand_dist[h] + handDelta[s];
  Inc(posPoint.length[h, s]);
end;

function evaluate_with_context(
  var posPoint: Pos;
  const trump: LongInt;
  ctx: TSolverContext
): EvalType;
var
  s, h, hmax, count, k, firstHand, ss: LongInt;
  rmax: Word;
  eval: EvalType;
begin
  hmax := 0;
  count := 0;
  rmax := 0;
  firstHand := posPoint.first[0];

  for s := 0 to DDS_SUITS - 1 do
    eval.win_ranks[s] := 0;

  if trump <> DDS_NOTRUMP then
  begin
    for h := 0 to DDS_HANDS - 1 do
    begin
      if posPoint.rank_in_suit[h, trump] <> 0 then
        Inc(count);
      if posPoint.rank_in_suit[h, trump] > rmax then
      begin
        hmax := h;
        rmax := posPoint.rank_in_suit[h, trump];
      end;
    end;

    if rmax > 0 then
    begin
      if count >= 2 then
        eval.win_ranks[trump] := rmax;

      if ctx.search.node_type_store(hmax) = MAXNODE then
      begin
        eval.tricks := posPoint.tricks_max + 1;
        Result := eval;
        Exit;
      end
      else
      begin
        eval.tricks := posPoint.tricks_max;
        Result := eval;
        Exit;
      end;
    end;
  end;

  k := 0;
  while k <= 3 do
  begin
    if posPoint.rank_in_suit[firstHand, k] <> 0 then
      break;
    Inc(k);
  end;

  for h := 0 to DDS_HANDS - 1 do
  begin
    if posPoint.rank_in_suit[h, k] <> 0 then
      Inc(count);
    if posPoint.rank_in_suit[h, k] > rmax then
    begin
      hmax := h;
      rmax := posPoint.rank_in_suit[h, k];
    end;
  end;

  if count >= 2 then
    eval.win_ranks[k] := rmax;

  if ctx.search.node_type_store(hmax) = MAXNODE then
    eval.tricks := posPoint.tricks_max + 1
  else
    eval.tricks := posPoint.tricks_max;

  Result := eval;
end;

function ab_search(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
begin
  Result := ab_search_0_ctx(posPoint, target, depth, ctx);
end;

function ab_search_0(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
begin
  Result := ab_search_0_ctx(posPoint, target, depth, ctx);
end;

function ab_search_1(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
begin
  Result := ab_search_1_ctx(posPoint, target, depth, ctx);
end;

function ab_search_2(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
begin
  Result := ab_search_2_ctx(posPoint, target, depth, ctx);
end;

function ab_search_3(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
begin
  Result := ab_search_3_ctx(posPoint, target, depth, ctx);
end;

function ab_search_0_ctx(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
label
  ABexitLabel;
var
  thrp: PThreadData;
  trump, hand, tricks, limit, ss: LongInt;
  cardsP: PNodeCards;
  lowerFlag, scoreFlag, res, success, value: Boolean;
  evalData: EvalType;
  qtricks: LongInt;
  mply: PMoveType;
  first: NodeCards;
  flag: Boolean;
begin
  thrp := ctx.thread_ptr;
  trump := thrp^.trump;
  hand := posPoint.first[depth];
  tricks := depth >> 2;

  Inc(thrp^.nodes);

  for ss := 0 to DDS_SUITS - 1 do
    posPoint.win_ranks[depth][ss] := 0;

  if depth >= 20 then
  begin
    if ctx.search.node_type_store(0) = MAXNODE then
      limit := target - posPoint.tricks_max - 1
    else
      limit := tricks - (target - posPoint.tricks_max - 1);

    cardsP := ctx.trans_table.lookup(tricks, hand, posPoint.aggr, posPoint.hand_dist, limit, lowerFlag);

    if cardsP <> nil then
    begin
      for ss := 0 to DDS_SUITS - 1 do
        posPoint.win_ranks[depth][ss] := win_ranks[posPoint.aggr[ss]][cardsP^.least_win[ss]];

      if cardsP^.best_move_rank <> 0 then
      begin
        thrp^.bestMoveTT[depth].suit := cardsP^.best_move_suit;
        thrp^.bestMoveTT[depth].rank := cardsP^.best_move_rank;
      end;

      if ctx.search.node_type_store(0) = MAXNODE then
        scoreFlag := lowerFlag
      else
        scoreFlag := not lowerFlag;

      Result := scoreFlag;
      Exit;
    end;
  end;

  if posPoint.tricks_max >= target then
  begin
    Result := true;
    Exit;
  end
  else if posPoint.tricks_max + tricks + 1 < target then
  begin
    Result := false;
    Exit;
  end
  else if depth = 0 then
  begin
    evalData := evaluate_with_context(posPoint, trump, ctx);
    value := evalData.tricks >= target;

    for ss := 0 to DDS_SUITS - 1 do
      posPoint.win_ranks[depth][ss] := evalData.win_ranks[ss];

    Result := value;
    Exit;
  end;

  qtricks := QuickTricks(posPoint, hand, depth, target, trump, res, ctx);

  if ctx.search.node_type_store(hand) = MAXNODE then
  begin
    if res then
    begin
      if qtricks = 0 then Result := false else Result := true;
      Exit;
    end;

    res := LaterTricksMIN(posPoint, hand, depth, target, trump, ctx);
    if not res then
    begin
      Result := false;
      Exit;
    end;
  end
  else
  begin
    if res then
    begin
      if qtricks = 0 then Result := true else Result := false;
      Exit;
    end;

    res := LaterTricksMAX(posPoint, hand, depth, target, trump, ctx);
    if res then
    begin
      Result := true;
      Exit;
    end;
  end;

  if depth < 20 then
  begin
    if ctx.search.node_type_store(0) = MAXNODE then
      limit := target - posPoint.tricks_max - 1
    else
      limit := tricks - (target - posPoint.tricks_max - 1);

    cardsP := ctx.trans_table.lookup(tricks, hand, posPoint.aggr, posPoint.hand_dist, limit, lowerFlag);

    if cardsP <> nil then
    begin
      for ss := 0 to DDS_SUITS - 1 do
        posPoint.win_ranks[depth][ss] := win_ranks[posPoint.aggr[ss]][cardsP^.least_win[ss]];

      if cardsP^.best_move_rank <> 0 then
      begin
        thrp^.bestMoveTT[depth].suit := cardsP^.best_move_suit;
        thrp^.bestMoveTT[depth].rank := cardsP^.best_move_rank;
      end;

      if ctx.search.node_type_store(0) = MAXNODE then
        scoreFlag := lowerFlag
      else
        scoreFlag := not lowerFlag;

      Result := scoreFlag;
      Exit;
    end;
  end;

  if ctx.search.node_type_store(hand) = MAXNODE then success := true else success := false;
  value := not success;

  for ss := 0 to DDS_SUITS - 1 do
    thrp^.lowestWin[depth, ss] := 0;

  TMoves(ctx.move_gen).MoveGen0(tricks, posPoint, thrp^.bestMove[depth], thrp^.bestMoveTT[depth], thrp^.rel);

  for ss := 0 to DDS_SUITS - 1 do
    posPoint.win_ranks[depth][ss] := 0;

  while true do
  begin
    mply := TMoves(ctx.move_gen).MakeNext(tricks, 0, posPoint.win_ranks[depth]);
    if mply = nil then
      break;

    make_0(posPoint, depth, mply);

    value := ab_search_1_ctx(posPoint, target, depth - 1, ctx);

    undo_1(posPoint, depth, mply^);

    if value = success then
    begin
      for ss := 0 to DDS_SUITS - 1 do
        posPoint.win_ranks[depth][ss] := posPoint.win_ranks[depth - 1][ss];

      thrp^.bestMove[depth] := mply^;
      goto ABexitLabel;
    end;

    for ss := 0 to DDS_SUITS - 1 do
      posPoint.win_ranks[depth][ss] := posPoint.win_ranks[depth][ss] or posPoint.win_ranks[depth - 1][ss];
  end;

ABexitLabel:
  if value then
  begin
    if ctx.search.node_type_store(0) = MAXNODE then
    begin
      first.upper_bound := tricks + 1;
      first.lower_bound := target - posPoint.tricks_max;
    end
    else
    begin
      first.upper_bound := tricks + 1 - target + posPoint.tricks_max;
      first.lower_bound := 0;
    end;
  end
  else
  begin
    if ctx.search.node_type_store(0) = MAXNODE then
    begin
      first.upper_bound := target - posPoint.tricks_max - 1;
      first.lower_bound := 0;
    end
    else
    begin
      first.upper_bound := tricks + 1;
      first.lower_bound := tricks + 1 - target + posPoint.tricks_max + 1;
    end;
  end;

  first.best_move_suit := thrp^.bestMove[depth].suit;
  first.best_move_rank := thrp^.bestMove[depth].rank;

  if (ctx.search.node_type_store(hand) = MAXNODE) and value or
     (ctx.search.node_type_store(hand) = MINNODE) and (not value) then
    flag := true
  else
    flag := false;

  ctx.trans_table.add(tricks, hand, posPoint.aggr, posPoint.win_ranks[depth], first, flag);

  Result := value;
end;

function ab_search_1_ctx(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
var
  thrp: PThreadData;
  trump, hand, tricks, ss: LongInt;
  success, value: Boolean;
  mply: PMoveType;
begin
  thrp := ctx.thread_ptr;
  trump := thrp^.trump;
  hand := (posPoint.first[depth] + 1) and 3;
  if ctx.search.node_type_store(hand) = MAXNODE then success := true else success := false;
  value := not success;

  Inc(thrp^.nodes);

  for ss := 0 to DDS_SUITS - 1 do
    thrp^.lowestWin[depth, ss] := 0;
  tricks := depth >> 2;

  TMoves(ctx.move_gen).MoveGen123(tricks, 1, posPoint);
  if depth = ctx.search.ini_depth then
    TMoves(ctx.move_gen).Purge(tricks, 1, thrp^.forbiddenMoves);

  for ss := 0 to DDS_SUITS - 1 do
    posPoint.win_ranks[depth][ss] := 0;

  while true do
  begin
    mply := TMoves(ctx.move_gen).MakeNext(tricks, 1, posPoint.win_ranks[depth]);
    if mply = nil then
      break;

    make_1(posPoint, depth, mply);

    value := ab_search_2_ctx(posPoint, target, depth - 1, ctx);

    undo_2(posPoint, depth, mply^);

    if value = success then
    begin
      for ss := 0 to DDS_SUITS - 1 do
        posPoint.win_ranks[depth][ss] := posPoint.win_ranks[depth - 1][ss];

      thrp^.bestMove[depth] := mply^;
      Result := value;
      Exit;
    end;

    for ss := 0 to DDS_SUITS - 1 do
      posPoint.win_ranks[depth][ss] := posPoint.win_ranks[depth][ss] or posPoint.win_ranks[depth - 1][ss];
  end;

  Result := value;
end;

function ab_search_2_ctx(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
var
  thrp: PThreadData;
  trump, hand, tricks, ss: LongInt;
  success, value: Boolean;
  mply: PMoveType;
begin
  thrp := ctx.thread_ptr;
  trump := thrp^.trump;
  hand := (posPoint.first[depth] + 2) and 3;
  if ctx.search.node_type_store(hand) = MAXNODE then success := true else success := false;
  value := not success;

  Inc(thrp^.nodes);

  for ss := 0 to DDS_SUITS - 1 do
    thrp^.lowestWin[depth, ss] := 0;
  tricks := depth >> 2;

  TMoves(ctx.move_gen).MoveGen123(tricks, 2, posPoint);
  if depth = ctx.search.ini_depth then
    TMoves(ctx.move_gen).Purge(tricks, 2, thrp^.forbiddenMoves);

  for ss := 0 to DDS_SUITS - 1 do
    posPoint.win_ranks[depth][ss] := 0;

  while true do
  begin
    mply := TMoves(ctx.move_gen).MakeNext(tricks, 2, posPoint.win_ranks[depth]);
    if mply = nil then
      break;

    make_2(posPoint, depth, mply);

    value := ab_search_3_ctx(posPoint, target, depth - 1, ctx);

    undo_3(posPoint, depth, mply^);

    if value = success then
    begin
      for ss := 0 to DDS_SUITS - 1 do
        posPoint.win_ranks[depth][ss] := posPoint.win_ranks[depth - 1][ss];

      thrp^.bestMove[depth] := mply^;
      Result := value;
      Exit;
    end;

    for ss := 0 to DDS_SUITS - 1 do
      posPoint.win_ranks[depth][ss] := posPoint.win_ranks[depth][ss] or posPoint.win_ranks[depth - 1][ss];
  end;

  Result := value;
end;

function ab_search_3_ctx(
  var posPoint: Pos;
  const target: LongInt;
  const depth: LongInt;
  ctx: TSolverContext
): Boolean;
var
  makeWinRank: array[0..DDS_SUITS - 1] of Word;
  thrp: PThreadData;
  hand, tricks, ss: LongInt;
  success, value: Boolean;
  mply: PMoveType;
begin
  thrp := ctx.thread_ptr;
  hand := (posPoint.first[depth] + 3) and 3;
  if ctx.search.node_type_store(hand) = MAXNODE then success := true else success := false;
  value := not success;

  Inc(thrp^.nodes);

  for ss := 0 to DDS_SUITS - 1 do
    thrp^.lowestWin[depth, ss] := 0;
  tricks := (depth + 3) >> 2;

  TMoves(ctx.move_gen).MoveGen123(tricks, 3, posPoint);
  if depth = ctx.search.ini_depth then
    TMoves(ctx.move_gen).Purge(tricks, 3, thrp^.forbiddenMoves);

  for ss := 0 to DDS_SUITS - 1 do
    posPoint.win_ranks[depth][ss] := 0;

  while true do
  begin
    mply := TMoves(ctx.move_gen).MakeNext(tricks, 3, posPoint.win_ranks[depth]);
    if mply = nil then
      break;

    make_3_ctx(posPoint, makeWinRank, depth, mply, ctx);

    Inc(thrp^.trickNodes);

    if ctx.search.node_type_store(posPoint.first[depth - 1]) = MAXNODE then
      Inc(posPoint.tricks_max);

    value := ab_search_0_ctx(posPoint, target, depth - 1, ctx);

    undo_0_ctx(posPoint, depth, mply^, ctx);

    if ctx.search.node_type_store(posPoint.first[depth - 1]) = MAXNODE then
      Dec(posPoint.tricks_max);

    if value = success then
    begin
      for ss := 0 to DDS_SUITS - 1 do
        posPoint.win_ranks[depth][ss] := posPoint.win_ranks[depth - 1][ss] or makeWinRank[ss];

      thrp^.bestMove[depth] := mply^;
      Result := value;
      Exit;
    end;

    for ss := 0 to DDS_SUITS - 1 do
      posPoint.win_ranks[depth][ss] := posPoint.win_ranks[depth][ss] or posPoint.win_ranks[depth - 1][ss] or makeWinRank[ss];
  end;

  Result := value;
end;

end.
