unit DDS_TransTable;

{$mode objfpc}{$H+}
{$POINTERMATH ON}

interface

uses
  SysUtils, Classes, DDS_Types;

const
  NSIZE = 50000;
  WSIZE = 50000;
  NINIT = 60000;
  WINIT = 170000;
  LSIZE = 200; // Per trick and first hand

type
  PWinCard = ^WinCard;
  PPWinCard = ^PWinCard;
  WinCard = packed record
    order_set_: Cardinal;
    win_mask_: Cardinal;
    first_: PNodeCards;
    prev_win_: PWinCard;
    next_win_: PWinCard;
    next_: PWinCard;
  end;

  PPosSearchSmall = ^PosSearchSmall;
  PPPosSearchSmall = ^PPosSearchSmall;
  PosSearchSmall = packed record
    pos_search_point_: PWinCard;
    suit_lengths_: Int64;
    left_: PPosSearchSmall;
    right_: PPosSearchSmall;
  end;

  PTtAggr = ^TtAggr;
  TtAggr = packed record
    aggr_ranks_: array[0..DDS_SUITS - 1] of Cardinal;
    win_mask_: array[0..DDS_SUITS - 1] of Cardinal;
  end;

  StatsResets = packed record
    no_of_resets_: LongInt;
    aggr_resets_: array[0..Ord(ResetReason_Count) - 1] of LongInt;
  end;

  TTransTableS = class
  private
    aggr_len_sets_: array[1..13] of Int64;
    stats_resets_: StatsResets;
    temp_win_: array[0..4] of WinCard;
    node_set_size_limit_: LongInt;
    win_set_size_limit_: LongInt;
    maxmem_: QWord;
    allocmem_: QWord;
    summem_: QWord;
    wmem_: LongInt;
    nmem_: LongInt;
    max_index_: LongInt;
    wcount_: LongInt;
    ncount_: LongInt;
    clear_tt_flag_: Boolean;
    windex_: LongInt;
    aggp_: PTtAggr;
    rootnp_: array[1..13, 0..DDS_HANDS - 1] of PPosSearchSmall;
    pw_: PPWinCard;
    pn_: PPNodeCards;
    pl_: array[1..13, 0..DDS_HANDS - 1] of PPPosSearchSmall;
    node_cards_: PNodeCards;
    win_cards_: PWinCard;
    pos_search_: array[1..13, 0..DDS_HANDS - 1] of PPosSearchSmall;
    node_set_size_: LongInt;
    win_set_size_: LongInt;
    len_set_ind_: array[1..13, 0..DDS_HANDS - 1] of LongInt;
    lcount_: array[1..13, 0..DDS_HANDS - 1] of LongInt;
    suit_lengths_: array[0..13] of Int64;
    tt_in_use_: LongInt;

    procedure wipe;
    procedure init_tt;
    procedure add_win_set;
    procedure add_node_set;
    procedure add_len_set(trick: LongInt; first_hand: LongInt);
    procedure build_sop(
      const our_win_ranks: array of Word;
      const aggr_arg: array of Word;
      const first: NodeCards;
      lengths: Int64;
      tricks: LongInt;
      first_hand: LongInt;
      flag: Boolean
    );
    function build_path(
      const win_mask_: array of LongInt;
      const win_order_set: array of LongInt;
      u_bound: LongInt;
      l_bound: LongInt;
      best_move_suit: ShortInt;
      best_move_rank: ShortInt;
      node_ptr: PPosSearchSmall;
      var resultVal: Boolean
    ): PNodeCards;
    function search_len_and_insert(
      root_ptr: PPosSearchSmall;
      key: Int64;
      insert_node: Boolean;
      trick: LongInt;
      first_hand: LongInt;
      var resultVal: Boolean
    ): PPosSearchSmall;
    function update_sop(
      u_bound: LongInt;
      l_bound: LongInt;
      best_move_suit: ShortInt;
      best_move_rank: ShortInt;
      node_ptr: PNodeCards
    ): PNodeCards;
    function find_sop(
      const order_set_: array of LongInt;
      limit: LongInt;
      nodeP: PWinCard;
      var lower_flag: Boolean
    ): PNodeCards;
  public
    constructor Create;
    destructor Destroy; override;
    procedure init(const hand_lookup: THandLookup);
    procedure set_memory_default(megabytes: LongInt);
    procedure set_memory_maximum(megabytes: LongInt);
    procedure make_tt;
    procedure reset_memory(reason: ResetReason);
    procedure return_all_memory;
    function memory_in_use: Double;
    function lookup(
      trick: LongInt;
      hand: LongInt;
      const aggr_target: array of Word;
      const hand_dist: array of LongInt;
      limit: LongInt;
      var lower_flag: Boolean
    ): PNodeCards;
    procedure add(
      tricks: LongInt;
      hand: LongInt;
      const aggr_target: array of Word;
      const our_win_ranks: array of Word;
      const first: NodeCards;
      flag: Boolean
    );
  end;

var
  tt_lowest_rank_table: array[0..8191] of LongInt;

implementation

procedure init_lowest_rank_table;
var
  top_bit_rank, ind: LongInt;
begin
  top_bit_rank := 1;
  tt_lowest_rank_table[0] := 15;
  for ind := 1 to 8191 do
  begin
    if ind >= (top_bit_rank + top_bit_rank) then
      top_bit_rank := top_bit_rank shl 1;
    tt_lowest_rank_table[ind] := tt_lowest_rank_table[ind xor top_bit_rank] - 1;
  end;
end;

constructor TTransTableS.Create;
begin
  inherited Create;
  tt_in_use_ := 0;
  maxmem_ := 167772160; // 160 MB default
  make_tt;
end;

destructor TTransTableS.Destroy;
begin
  return_all_memory;
  inherited Destroy;
end;

procedure TTransTableS.wipe;
var
  m, k, h: LongInt;
begin
  for m := 1 to wcount_ do
  begin
    if pw_[m] <> nil then
      FreeMem(pw_[m]);
    pw_[m] := nil;
  end;
  for m := 1 to ncount_ do
  begin
    if pn_[m] <> nil then
      FreeMem(pn_[m]);
    pn_[m] := nil;
  end;

  for k := 1 to 13 do
  begin
    for h := 0 to DDS_HANDS - 1 do
    begin
      for m := 1 to lcount_[k, h] do
      begin
        if pl_[k, h][m] <> nil then
          FreeMem(pl_[k, h][m]);
        pl_[k, h][m] := nil;
      end;
    end;
  end;

  allocmem_ := summem_;
end;

procedure TTransTableS.init_tt;
var
  k, h: LongInt;
begin
  win_set_size_limit_ := WINIT;
  node_set_size_limit_ := NINIT;
  allocmem_ := (WINIT + 1) * SizeOf(WinCard);
  allocmem_ := allocmem_ + (NINIT + 1) * SizeOf(NodeCards);
  allocmem_ := allocmem_ + (LSIZE + 1) * 52 * SizeOf(PosSearchSmall);
  win_cards_ := pw_[0];
  node_cards_ := pn_[0];
  wcount_ := 0;
  ncount_ := 0;

  node_set_size_ := 0;
  win_set_size_ := 0;

  clear_tt_flag_ := false;
  windex_ := -1;

  for k := 1 to 13 do
    for h := 0 to DDS_HANDS - 1 do
    begin
      pos_search_[k, h] := pl_[k, h][0];
      len_set_ind_[k, h] := 1;
      lcount_[k, h] := 0;
      pos_search_[k, h][0].suit_lengths_ := 0;
      pos_search_[k, h][0].pos_search_point_ := nil;
      pos_search_[k, h][0].left_ := nil;
      pos_search_[k, h][0].right_ := nil;
      rootnp_[k, h] := @(pos_search_[k, h][0]);
    end;
end;

procedure TTransTableS.init(const hand_lookup: THandLookup);
var
  top_bit_rank, top_bit_no, ind, s: LongInt;
begin
  top_bit_rank := 1;
  top_bit_no := 2;

  for s := 0 to DDS_SUITS - 1 do
  begin
    aggp_[0].aggr_ranks_[s] := 0;
    aggp_[0].win_mask_[s] := 0;
  end;

  for ind := 1 to 8191 do
  begin
    if ind >= (top_bit_rank + top_bit_rank) then
    begin
      top_bit_rank := top_bit_rank shl 1;
      Inc(top_bit_no);
    end;
    aggp_[ind] := aggp_[ind xor top_bit_rank];

    for s := 0 to 3 do
    begin
      aggp_[ind].aggr_ranks_[s] :=
        (aggp_[ind].aggr_ranks_[s] shr 2) or
        (Cardinal(hand_lookup[s][top_bit_no]) shl 24);

      aggp_[ind].win_mask_[s] :=
        (aggp_[ind].win_mask_[s] shr 2) or (3 shl 24);
    end;
  end;
end;

procedure TTransTableS.set_memory_default(megabytes: LongInt);
begin
end;

procedure TTransTableS.set_memory_maximum(megabytes: LongInt);
begin
  maxmem_ := 1000000 * QWord(megabytes);
end;

procedure TTransTableS.make_tt;
var
  k, h: LongInt;
begin
  if tt_in_use_ = 0 then
  begin
    summem_ := (QWord(WINIT + 1) * SizeOf(WinCard)) +
      (QWord(NINIT + 1) * SizeOf(NodeCards)) +
      (QWord(LSIZE + 1) * 52 * SizeOf(PosSearchSmall));
    wmem_ := (WSIZE + 1) * SizeOf(WinCard);
    nmem_ := (NSIZE + 1) * SizeOf(NodeCards);

    if maxmem_ <= summem_ then
      max_index_ := 0
    else
    begin
      max_index_ := (maxmem_ - summem_) div wmem_;
      if max_index_ < 0 then
        max_index_ := 0;
    end;

    pw_ := PPWinCard(AllocMem((max_index_ + 1) * SizeOf(PWinCard)));
    pn_ := PPNodeCards(AllocMem((max_index_ + 1) * SizeOf(PNodeCards)));

    for k := 1 to 13 do
      for h := 0 to DDS_HANDS - 1 do
      begin
        pl_[k, h] := PPPosSearchSmall(AllocMem((max_index_ + 1) * SizeOf(PPosSearchSmall)));
      end;

    pw_[0] := PWinCard(AllocMem((WINIT + 1) * SizeOf(WinCard)));
    pn_[0] := PNodeCards(AllocMem((NINIT + 1) * SizeOf(NodeCards)));

    for k := 1 to 13 do
      for h := 0 to DDS_HANDS - 1 do
      begin
        pl_[k, h][0] := PPosSearchSmall(AllocMem((LSIZE + 1) * SizeOf(PosSearchSmall)));
      end;

    aggp_ := PTtAggr(AllocMem(8192 * SizeOf(TtAggr)));

    tt_in_use_ := 1;
    init_tt;

    for k := 1 to 13 do
      aggr_len_sets_[k] := 0;
    stats_resets_.no_of_resets_ := 0;
    FillChar(stats_resets_.aggr_resets_, SizeOf(stats_resets_.aggr_resets_), 0);
  end;
end;

procedure TTransTableS.reset_memory(reason: ResetReason);
var
  k, h: LongInt;
begin
  wipe;
  init_tt;

  for k := 1 to 13 do
  begin
    for h := 0 to DDS_HANDS - 1 do
    begin
      rootnp_[k, h] := @(pos_search_[k, h][0]);
      pos_search_[k, h][0].suit_lengths_ := 0;
      pos_search_[k, h][0].pos_search_point_ := nil;
      pos_search_[k, h][0].left_ := nil;
      pos_search_[k, h][0].right_ := nil;
      len_set_ind_[k, h] := 1;
    end;
  end;

  Inc(stats_resets_.no_of_resets_);
  Inc(stats_resets_.aggr_resets_[Ord(reason)]);
end;

procedure TTransTableS.return_all_memory;
var
  k, h: LongInt;
begin
  if tt_in_use_ = 0 then
    Exit;
  tt_in_use_ := 0;

  wipe;

  if pw_[0] <> nil then
    FreeMem(pw_[0]);
  pw_[0] := nil;

  if pn_[0] <> nil then
    FreeMem(pn_[0]);
  pn_[0] := nil;

  for k := 1 to 13 do
  begin
    for h := 0 to DDS_HANDS - 1 do
    begin
      if pl_[k, h] <> nil then
      begin
        if pl_[k, h][0] <> nil then
          FreeMem(pl_[k, h][0]);
        pl_[k, h][0] := nil;
        FreeMem(pl_[k, h]);
        pl_[k, h] := nil;
      end;
    end;
  end;

  if pw_ <> nil then
    FreeMem(pw_);
  pw_ := nil;

  if pn_ <> nil then
    FreeMem(pn_);
  pn_ := nil;

  if aggp_ <> nil then
    FreeMem(aggp_);
  aggp_ := nil;
end;

function TTransTableS.memory_in_use: Double;
var
  ttMem, aggrMem: LongInt;
begin
  ttMem := allocmem_;
  aggrMem := 8192 * SizeOf(TtAggr);
  Result := (ttMem + aggrMem) / 1024.0;
end;

function TTransTableS.lookup(
  trick: LongInt;
  hand: LongInt;
  const aggr_target: array of Word;
  const hand_dist: array of LongInt;
  limit: LongInt;
  var lower_flag: Boolean
): PNodeCards;
var
  res: Boolean;
  pp: PPosSearchSmall;
  order_set_: array[0..DDS_SUITS - 1] of LongInt;
  cardsP: PNodeCards;
  ss: LongInt;
begin
  suit_lengths_[trick] :=
    (Int64(hand_dist[0]) shl 36) or
    (Int64(hand_dist[1]) shl 24) or
    (Int64(hand_dist[2]) shl 12) or
    (Int64(hand_dist[3]));

  pp := search_len_and_insert(
    rootnp_[trick, hand],
    suit_lengths_[trick],
    false,
    trick,
    hand,
    res
  );

  if (pp <> nil) and res then
  begin
    for ss := 0 to DDS_SUITS - 1 do
    begin
      order_set_[ss] := aggp_[aggr_target[ss]].aggr_ranks_[ss];
    end;

    if pp^.pos_search_point_ = nil then
      cardsP := nil
    else
    begin
      cardsP := find_sop(order_set_, limit, pp^.pos_search_point_, lower_flag);
      if cardsP = nil then
      begin
        Result := nil;
        Exit;
      end;
    end;
  end
  else
  begin
    cardsP := nil;
  end;

  Result := cardsP;
end;

procedure TTransTableS.add(
  tricks: LongInt;
  hand: LongInt;
  const aggr_target: array of Word;
  const our_win_ranks: array of Word;
  const first: NodeCards;
  flag: Boolean
);
begin
  build_sop(
    our_win_ranks,
    aggr_target,
    first,
    suit_lengths_[tricks],
    tricks,
    hand,
    flag
  );

  if clear_tt_flag_ then
    reset_memory(ResetReason_MemoryExhausted);
end;

procedure TTransTableS.add_win_set;
begin
  if clear_tt_flag_ then
  begin
    Inc(windex_);
    win_set_size_ := windex_;
    win_cards_ := @(temp_win_[windex_]);
  end
  else if win_set_size_ >= win_set_size_limit_ then
  begin
    if ((allocmem_ + QWord(wmem_)) > maxmem_) or (wcount_ >= max_index_) or (win_set_size_ > SIMILARMAXWINNODES) then
    begin
      Inc(windex_);
      win_set_size_ := windex_;
      clear_tt_flag_ := true;
      win_cards_ := @(temp_win_[windex_]);
    end
    else
    begin
      Inc(wcount_);
      win_set_size_limit_ := WSIZE;
      pw_[wcount_] := PWinCard(AllocMem((WSIZE + 1) * SizeOf(WinCard)));
      if pw_[wcount_] = nil then
      begin
        clear_tt_flag_ := true;
        Inc(windex_);
        win_set_size_ := windex_;
        win_cards_ := @(temp_win_[windex_]);
      end
      else
      begin
        allocmem_ := allocmem_ + (WSIZE + 1) * SizeOf(WinCard);
        win_set_size_ := 0;
        win_cards_ := pw_[wcount_];
      end;
    end;
  end
  else
    Inc(win_set_size_);
end;

procedure TTransTableS.add_node_set;
begin
  if node_set_size_ >= node_set_size_limit_ then
  begin
    if ((allocmem_ + QWord(nmem_)) > maxmem_) or (ncount_ >= max_index_) then
    begin
      clear_tt_flag_ := true;
    end
    else
    begin
      Inc(ncount_);
      node_set_size_limit_ := NSIZE;
      pn_[ncount_] := PNodeCards(AllocMem((NSIZE + 1) * SizeOf(NodeCards)));
      if pn_[ncount_] = nil then
      begin
        clear_tt_flag_ := true;
      end
      else
      begin
        allocmem_ := allocmem_ + (NSIZE + 1) * SizeOf(NodeCards);
        node_set_size_ := 0;
        node_cards_ := pn_[ncount_];
      end;
    end;
  end
  else
    Inc(node_set_size_);
end;

procedure TTransTableS.add_len_set(trick: LongInt; first_hand: LongInt);
var
  incr: LongInt;
begin
  if len_set_ind_[trick, first_hand] < LSIZE then
  begin
    Inc(len_set_ind_[trick, first_hand]);
    Exit;
  end;

  incr := (LSIZE + 1) * SizeOf(PosSearchSmall);
  if (allocmem_ + incr > maxmem_) or (lcount_[trick, first_hand] >= max_index_) then
  begin
    clear_tt_flag_ := true;
    Exit;
  end;

  Inc(lcount_[trick, first_hand]);
  pl_[trick, first_hand][lcount_[trick, first_hand]] := PPosSearchSmall(AllocMem(incr));

  if pl_[trick, first_hand][lcount_[trick, first_hand]] = nil then
  begin
    clear_tt_flag_ := true;
    Exit;
  end;

  allocmem_ := allocmem_ + incr;
  len_set_ind_[trick, first_hand] := 0;
  pos_search_[trick, first_hand] := pl_[trick, first_hand][lcount_[trick, first_hand]];
end;

procedure TTransTableS.build_sop(
  const our_win_ranks: array of Word;
  const aggr_arg: array of Word;
  const first: NodeCards;
  lengths: Int64;
  tricks: LongInt;
  first_hand: LongInt;
  flag: Boolean
);
var
  win_mask_: array[0..DDS_SUITS - 1] of LongInt;
  win_order_set: array[0..DDS_SUITS - 1] of LongInt;
  low: array[0..DDS_SUITS - 1] of ShortInt;
  ss, w, k: LongInt;
  temp: Word;
  res: Boolean;
  np: PPosSearchSmall;
  cardsP: PNodeCards;
begin
  for ss := 0 to DDS_SUITS - 1 do
  begin
    w := our_win_ranks[ss];
    if w = 0 then
    begin
      win_mask_[ss] := 0;
      win_order_set[ss] := 0;
      low[ss] := 15;
    end
    else
    begin
      w := w and (-w);
      temp := aggr_arg[ss] and (-w);
      win_mask_[ss] := aggp_[temp].win_mask_[ss];
      win_order_set[ss] := aggp_[temp].aggr_ranks_[ss];
      low[ss] := tt_lowest_rank_table[temp];
    end;
  end;

  np := search_len_and_insert(
    rootnp_[tricks, first_hand], lengths, true, tricks, first_hand, res);

  cardsP := build_path(
    win_mask_,
    win_order_set,
    first.upper_bound,
    first.lower_bound,
    first.best_move_suit,
    first.best_move_rank,
    np,
    res
  );

  if res then
  begin
    cardsP^.upper_bound := first.upper_bound;
    cardsP^.lower_bound := first.lower_bound;

    if flag then
    begin
      cardsP^.best_move_suit := first.best_move_suit;
      cardsP^.best_move_rank := first.best_move_rank;
    end
    else
    begin
      cardsP^.best_move_suit := 0;
      cardsP^.best_move_rank := 0;
    end;

    for k := 0 to DDS_SUITS - 1 do
      cardsP^.least_win[k] := 15 - low[k];
  end;
end;

function TTransTableS.build_path(
  const win_mask_: array of LongInt;
  const win_order_set: array of LongInt;
  u_bound: LongInt;
  l_bound: LongInt;
  best_move_suit: ShortInt;
  best_move_rank: ShortInt;
  node_ptr: PPosSearchSmall;
  var resultVal: Boolean
): PNodeCards;
var
  found: Boolean;
  np, p2, nprev: PWinCard;
  p: PNodeCards;
  suit: LongInt;
begin
  np := node_ptr^.pos_search_point_;
  nprev := nil;
  suit := 0;

  if np = nil then
  begin
    p2 := @(win_cards_[win_set_size_]);
    add_win_set;
    p2^.next_ := nil;
    p2^.next_win_ := nil;
    p2^.prev_win_ := nil;
    node_ptr^.pos_search_point_ := p2;
    p2^.win_mask_ := win_mask_[suit];
    p2^.order_set_ := win_order_set[suit];
    p2^.first_ := nil;
    np := p2;
    Inc(suit);
    while suit < DDS_SUITS do
    begin
      p2 := @(win_cards_[win_set_size_]);
      add_win_set;
      np^.next_win_ := p2;
      p2^.prev_win_ := np;
      p2^.next_ := nil;
      p2^.next_win_ := nil;
      p2^.win_mask_ := win_mask_[suit];
      p2^.order_set_ := win_order_set[suit];
      p2^.first_ := nil;
      np := p2;
      Inc(suit);
    end;
    p := @(node_cards_[node_set_size_]);
    add_node_set;
    np^.first_ := p;
    resultVal := true;
    Result := p;
    Exit;
  end
  else
  begin
    while true do
    begin
      found := false;
      while true do
      begin
        if (np^.win_mask_ = win_mask_[suit]) and (np^.order_set_ = win_order_set[suit]) then
        begin
          found := true;
          nprev := np;
          break;
        end;
        if np^.next_ <> nil then
          np := np^.next_
        else
          break;
      end;
      if found then
      begin
        Inc(suit);
        if suit >= DDS_SUITS then
        begin
          resultVal := false;
          Result := update_sop(u_bound, l_bound, best_move_suit, best_move_rank, np^.first_);
          Exit;
        end
        else
        begin
          np := np^.next_win_;
          continue;
        end;
      end
      else
        break;
    end;

    p2 := @(win_cards_[win_set_size_]);
    add_win_set;
    p2^.prev_win_ := nprev;
    if nprev <> nil then
    begin
      p2^.next_ := nprev^.next_win_;
      nprev^.next_win_ := p2;
    end
    else
    begin
      p2^.next_ := node_ptr^.pos_search_point_;
      node_ptr^.pos_search_point_ := p2;
    end;
    p2^.next_win_ := nil;
    p2^.win_mask_ := win_mask_[suit];
    p2^.order_set_ := win_order_set[suit];
    p2^.first_ := nil;
    np := p2;
    Inc(suit);

    while suit < 4 do
    begin
      p2 := @(win_cards_[win_set_size_]);
      add_win_set;
      np^.next_win_ := p2;
      p2^.prev_win_ := np;
      p2^.next_ := nil;
      p2^.win_mask_ := win_mask_[suit];
      p2^.order_set_ := win_order_set[suit];
      p2^.first_ := nil;
      p2^.next_win_ := nil;
      np := p2;
      Inc(suit);
    end;

    p := @(node_cards_[node_set_size_]);
    add_node_set;
    np^.first_ := p;
    resultVal := true;
    Result := p;
  end;
end;

function TTransTableS.search_len_and_insert(
  root_ptr: PPosSearchSmall;
  key: Int64;
  insert_node: Boolean;
  trick: LongInt;
  first_hand: LongInt;
  var resultVal: Boolean
): PPosSearchSmall;
var
  np, p, sp: PPosSearchSmall;
begin
  sp := nil;
  if insert_node then
    sp := @(pos_search_[trick, first_hand][len_set_ind_[trick, first_hand]]);

  np := root_ptr;
  while true do
  begin
    if key = np^.suit_lengths_ then
    begin
      resultVal := true;
      Result := np;
      Exit;
    end
    else if key < np^.suit_lengths_ then
    begin
      if np^.left_ <> nil then
        np := np^.left_
      else if insert_node then
      begin
        p := sp;
        add_len_set(trick, first_hand);
        np^.left_ := p;
        p^.pos_search_point_ := nil;
        p^.suit_lengths_ := key;
        p^.left_ := nil;
        p^.right_ := nil;
        resultVal := true;
        Result := p;
        Exit;
      end
      else
      begin
        resultVal := false;
        Result := nil;
        Exit;
      end;
    end
    else
    begin
      if np^.right_ <> nil then
        np := np^.right_
      else if insert_node then
      begin
        p := sp;
        add_len_set(trick, first_hand);
        np^.right_ := p;
        p^.pos_search_point_ := nil;
        p^.suit_lengths_ := key;
        p^.left_ := nil;
        p^.right_ := nil;
        resultVal := true;
        Result := p;
        Exit;
      end
      else
      begin
        resultVal := false;
        Result := nil;
        Exit;
      end;
    end;
  end;
end;

function TTransTableS.update_sop(
  u_bound: LongInt;
  l_bound: LongInt;
  best_move_suit: ShortInt;
  best_move_rank: ShortInt;
  node_ptr: PNodeCards
): PNodeCards;
begin
  if l_bound > node_ptr^.lower_bound then
    node_ptr^.lower_bound := l_bound;
  if u_bound < node_ptr^.upper_bound then
    node_ptr^.upper_bound := u_bound;

  node_ptr^.best_move_suit := best_move_suit;
  node_ptr^.best_move_rank := best_move_rank;

  Result := node_ptr;
end;

function TTransTableS.find_sop(
  const order_set_: array of LongInt;
  limit: LongInt;
  nodeP: PWinCard;
  var lower_flag: Boolean
): PNodeCards;
var
  np: PWinCard;
  s: LongInt;
begin
  np := nodeP;
  s := 0;

  while np <> nil do
  begin
    if (np^.win_mask_ and order_set_[s]) = np^.order_set_ then
    begin
      if s <> 3 then
      begin
        np := np^.next_win_;
        Inc(s);
        continue;
      end;

      if np^.first_^.lower_bound > limit then
      begin
        lower_flag := true;
        Result := np^.first_;
        Exit;
      end
      else if np^.first_^.upper_bound <= limit then
      begin
        lower_flag := false;
        Result := np^.first_;
        Exit;
      end;
    end;

    while np^.next_ = nil do
    begin
      np := np^.prev_win_;
      Dec(s);
      if np = nil then
      begin
        Result := nil;
        Exit;
      end;
    end;
    np := np^.next_;
  end;
  Result := nil;
end;

initialization
  init_lowest_rank_table;

end.
