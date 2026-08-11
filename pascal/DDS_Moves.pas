unit DDS_Moves;

{$mode objfpc}{$H+}
{$POINTERMATH ON}

interface

uses
  SysUtils, Classes, DDS_Types, DDS_Init;

type
  MgType = (
    MgType_NT0 = 0,
    MgType_TRUMP0 = 1,
    MgType_NT_VOID1 = 2,
    MgType_TRUMP_VOID1 = 3,
    MgType_NT_NOTVOID1 = 4,
    MgType_TRUMP_NOTVOID1 = 5,
    MgType_NT_VOID2 = 6,
    MgType_TRUMP_VOID2 = 7,
    MgType_NT_NOTVOID2 = 8,
    MgType_TRUMP_NOTVOID2 = 9,
    MgType_NT_VOID3 = 10,
    MgType_TRUMP_VOID3 = 11,
    MgType_COMB_NOTVOID3 = 12,
    MgType_SIZE = 13
  );

  WeightCase = (
    WeightCase_Nt0 = 0,
    WeightCase_Trump0 = 1,
    WeightCase_NtNotVoid1 = 4,
    WeightCase_TrumpNotVoid1 = 5,
    WeightCase_NtVoid1 = 6,
    WeightCase_TrumpVoid1 = 7,
    WeightCase_NtNotVoid2 = 8,
    WeightCase_TrumpNotVoid2 = 9,
    WeightCase_NtVoid2 = 10,
    WeightCase_TrumpVoid2 = 11,
    WeightCase_CombinedNotVoid3 = 12,
    WeightCase_CombinedNotVoid3Trump = 13,
    WeightCase_NtVoid3 = 14,
    WeightCase_TrumpVoid3 = 15
  );

  TrackType = packed record
    lead_hand: LongInt;
    lead_suit: LongInt;
    play_suits: array[0..DDS_HANDS - 1] of LongInt;
    play_ranks: array[0..DDS_HANDS - 1] of LongInt;
    trick_data: TrickDataType;
    move: array[0..DDS_HANDS - 1] of ExtCard;
    high: array[0..DDS_HANDS - 1] of LongInt;
    lowest_win: array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of LongInt;
    removed_ranks: array[0..DDS_SUITS - 1] of LongInt;
  end;
  PTrackType = ^TrackType;

  HeuristicContext = record
    tpos_ptr: PPos;
    best_move: MoveType;
    best_move_tt: MoveType;
    thrp_rel: PRelRanksType;
    mply: PMoveType;
    num_moves: LongInt;
    last_num_moves: LongInt;
    trump: LongInt;
    suit: LongInt;
    trackp: PTrackType;
    curr_trick: LongInt;
    curr_hand: LongInt;
    lead_hand: LongInt;
    lead_suit: LongInt;
    removed_ranks: array[0..DDS_SUITS - 1] of LongInt;
    move1_rank: LongInt;
    high1: LongInt;
    move1_suit: LongInt;
    move2_rank: LongInt;
    move2_suit: LongInt;
    high2: LongInt;
    lead0_rank: LongInt;
  end;

  TRankInSuit = array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of Word;

  TMoves = class
  public
    leadHand: LongInt;
    leadSuit: LongInt;
    currHand: LongInt;
    currTrick: LongInt;
    trump: LongInt;
    suit: LongInt;
    numMoves: LongInt;
    lastNumMoves: LongInt;

    track: array[0..12] of TrackType;
    trackp: PTrackType;

    moveList: array[0..12, 0..DDS_HANDS - 1] of MovePlyType;
    mply: PMoveType;

    lastCall: array[0..12, 0..DDS_HANDS - 1] of MgType;

    constructor Create;
    destructor Destroy; override;

    procedure Init(
      const tricks: LongInt;
      const relStartHand: LongInt;
      const initialRanks: array of LongInt;
      const initialSuits: array of LongInt;
      const rank_in_suit: TRankInSuit;
      const our_trump: LongInt;
      const our_lead_hand: LongInt
    );

    procedure Reinit(const tricks: LongInt; const ourLeadHand: LongInt);
    function MoveGen0(
      const tricks: LongInt;
      const tpos: Pos;
      const bestMove: MoveType;
      const bestMoveTT: MoveType;
      const thrp_rel: array of RelRanksType
    ): LongInt;

    function MoveGen123(
      const tricks: LongInt;
      const handRel: LongInt;
      const tpos: Pos
    ): LongInt;

    procedure GetTopNumber(
      const ris: LongInt;
      const prank: LongInt;
      var topNumber: LongInt;
      var mno: LongInt
    );

    function WinningMove(
      const mvp1: MoveType;
      const mvp2: ExtCard;
      const ourTrump: LongInt
    ): Boolean;

    function GetLength(const trick: LongInt; const relHand: LongInt): LongInt;
    procedure MakeSpecific(
      const ourMply: MoveType;
      const trick: LongInt;
      const relHand: LongInt
    );

    function MakeNext(
      const trick: LongInt;
      const relHand: LongInt;
      const ourWinRanks: array of Word
    ): PMoveType;

    function MakeNextSimple(
      const trick: LongInt;
      const relHand: LongInt
    ): PMoveType;

    procedure Step(const tricks: LongInt; const relHand: LongInt);
    procedure Rewind(const tricks: LongInt; const relHand: LongInt);
    procedure Purge(
      const trick: LongInt;
      const ourLeadHand: LongInt;
      const forbiddenMoves: array of MoveType
    );
    procedure Reward(const tricks: LongInt; const relHand: LongInt);
    function GetTrickData(const tricks: LongInt): TrickDataType;
    procedure Sort(const tricks: LongInt; const relHand: LongInt);
    procedure MergeSort;

    function make_heuristic_context(
      const tpos: Pos;
      const best_move: MoveType;
      const best_move_tt: MoveType;
      const thrp_rel: array of RelRanksType;
      const tr: TrackType
    ): HeuristicContext;
  end;

procedure call_heuristic(var context: HeuristicContext; weight_case: WeightCase);

implementation

const
  RegisterList: array[0..15] of MgType = (
    MgType_NT0,           MgType_TRUMP0,
    MgType_SIZE,          MgType_SIZE, // Unused
    MgType_NT_NOTVOID1,   MgType_TRUMP_NOTVOID1,
    MgType_NT_VOID1,      MgType_TRUMP_VOID1,
    MgType_NT_NOTVOID2,   MgType_TRUMP_NOTVOID2,
    MgType_NT_VOID2,      MgType_TRUMP_VOID2,
    MgType_COMB_NOTVOID3, MgType_COMB_NOTVOID3,
    MgType_NT_VOID3,      MgType_TRUMP_VOID3
  );

function trump_winner_bit(const tpos: Pos; trump: LongInt): LongInt;
begin
  if (trump <> DDS_NOTRUMP) and (trump >= 0) and (trump < DDS_SUITS) and (tpos.winner[trump].rank <> 0) then
    Result := 1
  else
    Result := 0;
end;

function weight_case_follow(hand_rel: LongInt; trump_winner: LongInt; is_void: Boolean): WeightCase;
var
  val: LongInt;
begin
  val := 4 * hand_rel + trump_winner;
  if is_void then
    val := val + 2;
  Result := WeightCase(val);
end;

constructor TMoves.Create;
var
  t, h, i: LongInt;
begin
  inherited Create;
  trackp := nil;
  mply := nil;
  leadHand := 0;
  currHand := 0;
  leadSuit := 0;
  currTrick := 0;
  trump := DDS_NOTRUMP;
  suit := 0;
  numMoves := 0;
  lastNumMoves := 0;

  for t := 0 to 12 do
  begin
    for h := 0 to DDS_HANDS - 1 do
    begin
      lastCall[t, h] := MgType_SIZE;
      moveList[t, h].current := 0;
      moveList[t, h].last := 0;
      FillChar(moveList[t, h].move, SizeOf(moveList[t, h].move), 0);
    end;
  end;
end;

destructor TMoves.Destroy;
begin
  inherited Destroy;
end;

procedure TMoves.Init(
  const tricks: LongInt;
  const relStartHand: LongInt;
  const initialRanks: array of LongInt;
  const initialSuits: array of LongInt;
  const rank_in_suit: TRankInSuit;
  const our_trump: LongInt;
  const our_lead_hand: LongInt
);
var
  m, h, s, n: LongInt;
begin
  currTrick := tricks;
  trump := our_trump;

  if relStartHand = 0 then
    track[tricks].lead_hand := our_lead_hand;

  for m := 0 to 12 do
  begin
    for h := 0 to DDS_HANDS - 1 do
    begin
      moveList[m, h].current := 0;
      moveList[m, h].last := 0;
    end;
  end;

  for s := 0 to DDS_SUITS - 1 do
    track[tricks].removed_ranks[s] := $ffff;

  for h := 0 to DDS_HANDS - 1 do
    for s := 0 to DDS_SUITS - 1 do
      track[tricks].removed_ranks[s] := track[tricks].removed_ranks[s] xor rank_in_suit[h, s];

  for n := 0 to relStartHand - 1 do
  begin
    s := initialSuits[n];
    track[tricks].removed_ranks[s] := track[tricks].removed_ranks[s] xor bit_map_rank[initialRanks[n]];
  end;
end;

procedure TMoves.Reinit(const tricks: LongInt; const ourLeadHand: LongInt);
begin
  track[tricks].lead_hand := ourLeadHand;
end;

function TMoves.MoveGen0(
  const tricks: LongInt;
  const tpos: Pos;
  const bestMove: MoveType;
  const bestMoveTT: MoveType;
  const thrp_rel: array of RelRanksType
): LongInt;
var
  mp: PMoveGroupType;
  removed, g, rank, seq, s, s_idx: LongInt;
  lead_case: WeightCase;
  hctx: HeuristicContext;
  ris: Word;
begin
  trackp := @track[tricks];
  leadHand := trackp^.lead_hand;
  currHand := leadHand;
  currTrick := tricks;

  mply := moveList[tricks, 0].move;
  for s := 0 to DDS_SUITS - 1 do
    trackp^.lowest_win[0, s] := 0;

  numMoves := 0;
  lastNumMoves := 0;
  suit := 0;
  leadSuit := 0;

  if trump_winner_bit(tpos, trump) <> 0 then
    lead_case := WeightCase_Trump0
  else
    lead_case := WeightCase_Nt0;

  hctx := make_heuristic_context(tpos, bestMove, bestMoveTT, thrp_rel, track[tricks]);

  for s_idx := 0 to DDS_SUITS - 1 do
  begin
    ris := tpos.rank_in_suit[leadHand, s_idx];
    if ris = 0 then
      continue;

    lastNumMoves := numMoves;
    mp := @group_data[ris];
    g := mp^.last_group_;
    removed := trackp^.removed_ranks[s_idx];

    while g >= 0 do
    begin
      rank := mp^.rank_[g];
      seq := mp^.sequence_[g];

      while (g >= 1) and ((mp^.gap_[g] and removed) = mp^.gap_[g]) do
      begin
        Dec(g);
        seq := seq or mp^.fullseq_[g];
      end;

      mply[numMoves].sequence := seq;
      mply[numMoves].suit := s_idx;
      mply[numMoves].rank := rank;

      Inc(numMoves);
      Dec(g);
    end;

    hctx.suit := s_idx;
    hctx.last_num_moves := lastNumMoves;
    hctx.num_moves := numMoves;
    call_heuristic(hctx, lead_case);
  end;

  lastCall[tricks, 0] := RegisterList[Ord(lead_case)];

  moveList[tricks, 0].current := 0;
  moveList[tricks, 0].last := numMoves - 1;

  if numMoves <> 1 then
    MergeSort;

  Result := numMoves;
end;

function TMoves.MoveGen123(
  const tricks: LongInt;
  const handRel: LongInt;
  const tpos: Pos
): LongInt;
var
  mp: PMoveGroupType;
  removed, g, rank, seq, s, s_idx: LongInt;
  weight_case: WeightCase;
  trump_winner: LongInt;
  empty_move: MoveType;
  hctx: HeuristicContext;
  ris: Word;
  dummy_thrp_rel: array[0..0] of RelRanksType;
begin
  trackp := @track[tricks];
  leadHand := trackp^.lead_hand;
  currHand := (leadHand + handRel) and 3;
  currTrick := tricks;
  leadSuit := track[tricks].lead_suit;

  mply := moveList[tricks, handRel].move;

  for s := 0 to DDS_SUITS - 1 do
    trackp^.lowest_win[handRel, s] := 0;

  numMoves := 0;
  lastNumMoves := 0;
  suit := leadSuit;

  trump_winner := trump_winner_bit(tpos, trump);
  FillChar(empty_move, SizeOf(empty_move), 0);

  ris := tpos.rank_in_suit[currHand, leadSuit];

  if ris <> 0 then
  begin
    mp := @group_data[ris];
    g := mp^.last_group_;
    removed := trackp^.removed_ranks[leadSuit];

    while g >= 0 do
    begin
      rank := mp^.rank_[g];
      seq := mp^.sequence_[g];

      while (g >= 1) and ((mp^.gap_[g] and removed) = mp^.gap_[g]) do
      begin
        Dec(g);
        seq := seq or mp^.fullseq_[g];
      end;

      mply[numMoves].sequence := seq;
      mply[numMoves].suit := leadSuit;
      mply[numMoves].rank := rank;

      Inc(numMoves);
      Dec(g);
    end;

    weight_case := weight_case_follow(handRel, trump_winner, false);
    lastCall[tricks, handRel] := RegisterList[Ord(weight_case)];

    moveList[tricks, handRel].current := 0;
    moveList[tricks, handRel].last := numMoves - 1;
    if numMoves = 1 then
    begin
      Result := numMoves;
      Exit;
    end;

    hctx := make_heuristic_context(tpos, empty_move, empty_move, dummy_thrp_rel, track[tricks]);
    call_heuristic(hctx, weight_case);

    MergeSort;
    Result := numMoves;
    Exit;
  end;

  weight_case := weight_case_follow(handRel, trump_winner, true);
  lastCall[tricks, handRel] := RegisterList[Ord(weight_case)];

  hctx := make_heuristic_context(tpos, empty_move, empty_move, dummy_thrp_rel, track[tricks]);

  for s_idx := 0 to DDS_SUITS - 1 do
  begin
    ris := tpos.rank_in_suit[currHand, s_idx];
    if ris = 0 then
      continue;

    lastNumMoves := numMoves;
    mp := @group_data[ris];
    g := mp^.last_group_;
    removed := trackp^.removed_ranks[s_idx];

    while g >= 0 do
    begin
      rank := mp^.rank_[g];
      seq := mp^.sequence_[g];

      while (g >= 1) and ((mp^.gap_[g] and removed) = mp^.gap_[g]) do
      begin
        Dec(g);
        seq := seq or mp^.fullseq_[g];
      end;

      mply[numMoves].sequence := seq;
      mply[numMoves].suit := s_idx;
      mply[numMoves].rank := rank;

      Inc(numMoves);
      Dec(g);
    end;

    hctx.suit := s_idx;
    hctx.last_num_moves := lastNumMoves;
    hctx.num_moves := numMoves;
    call_heuristic(hctx, weight_case);
  end;

  moveList[tricks, handRel].current := 0;
  moveList[tricks, handRel].last := numMoves - 1;
  if numMoves <> 1 then
    MergeSort;

  Result := numMoves;
end;

procedure TMoves.GetTopNumber(
  const ris: LongInt;
  const prank: LongInt;
  var topNumber: LongInt;
  var mno: LongInt
);
var
  mp: PMoveGroupType;
  removed, g, fullseq: LongInt;
begin
  topNumber := -10;
  mno := 0;
  while (mno < numMoves - 1) and (mply[1 + mno].rank > prank) do
    Inc(mno);

  mp := @group_data[ris];
  g := mp^.last_group_;
  removed := trackp^.removed_ranks[leadSuit] or bit_map_rank[prank];

  fullseq := mp^.fullseq_[g];
  while (g >= 1) and ((mp^.gap_[g] and removed) = mp^.gap_[g]) do
  begin
    Dec(g);
    fullseq := fullseq or mp^.fullseq_[g];
  end;

  topNumber := count_table[fullseq] - 1;
end;

function TMoves.WinningMove(
  const mvp1: MoveType;
  const mvp2: ExtCard;
  const ourTrump: LongInt
): Boolean;
begin
  if mvp1.suit = mvp2.suit then
  begin
    Result := mvp1.rank > mvp2.rank;
  end
  else if mvp1.suit = ourTrump then
    Result := true
  else
    Result := false;
end;

function TMoves.GetLength(const trick: LongInt; const relHand: LongInt): LongInt;
begin
  Result := moveList[trick, relHand].last + 1;
end;

procedure TMoves.MakeSpecific(
  const ourMply: MoveType;
  const trick: LongInt;
  const relHand: LongInt
);
var
  newp: PTrackType;
  h, s, r: LongInt;
begin
  trackp := @track[trick];

  if relHand = 0 then
  begin
    trackp^.move[0].suit := ourMply.suit;
    trackp^.move[0].rank := ourMply.rank;
    trackp^.move[0].sequence := ourMply.sequence;
    trackp^.high[0] := 0;
    trackp^.lead_suit := ourMply.suit;
  end
  else if ourMply.suit = trackp^.move[relHand - 1].suit then
  begin
    if ourMply.rank > trackp^.move[relHand - 1].rank then
    begin
      trackp^.move[relHand].suit := ourMply.suit;
      trackp^.move[relHand].rank := ourMply.rank;
      trackp^.move[relHand].sequence := ourMply.sequence;
      trackp^.high[relHand] := relHand;
    end
    else
    begin
      trackp^.move[relHand] := trackp^.move[relHand - 1];
      trackp^.high[relHand] := trackp^.high[relHand - 1];
    end;
  end
  else if ourMply.suit = trump then
  begin
    trackp^.move[relHand].suit := ourMply.suit;
    trackp^.move[relHand].rank := ourMply.rank;
    trackp^.move[relHand].sequence := ourMply.sequence;
    trackp^.high[relHand] := relHand;
  end
  else
  begin
    trackp^.move[relHand] := trackp^.move[relHand - 1];
    trackp^.high[relHand] := trackp^.high[relHand - 1];
  end;

  trackp^.play_suits[relHand] := ourMply.suit;
  trackp^.play_ranks[relHand] := ourMply.rank;

  if relHand = 3 then
  begin
    newp := @track[trick - 1];
    newp^.lead_hand := (trackp^.lead_hand + trackp^.high[3]) mod 4;

    for s := 0 to DDS_SUITS - 1 do
      newp^.removed_ranks[s] := trackp^.removed_ranks[s];

    for h := 0 to DDS_HANDS - 1 do
    begin
      r := trackp^.play_ranks[h];
      s := trackp^.play_suits[h];
      newp^.removed_ranks[s] := newp^.removed_ranks[s] or bit_map_rank[r];
    end;
  end;
end;

function TMoves.MakeNext(
  const trick: LongInt;
  const relHand: LongInt;
  const ourWinRanks: array of Word
): PMoveType;
var
  lwp: PLongInt;
  list: PMovePlyType;
  currp, prevp: PMoveType;
  found: Boolean;
  low, h, s, r: LongInt;
  newt: PTrackType;
begin
  lwp := @(track[trick].lowest_win[relHand, 0]);
  list := @(moveList[trick, relHand]);
  trackp := @track[trick];

  currp := nil;
  found := false;

  if list^.last = -1 then
  begin
    Result := nil;
    Exit;
  end
  else if list^.current = 0 then
  begin
    currp := @(list^.move[0]);
    found := true;
  end
  else
  begin
    prevp := @(list^.move[list^.current - 1]);
    if lwp[prevp^.suit] = 0 then
    begin
      low := lowest_rank[ourWinRanks[prevp^.suit]];
      if low = 0 then
        low := 15;
      if prevp^.rank < low then
        lwp[prevp^.suit] := low;
    end;

    while (list^.current <= list^.last) and (not found) do
    begin
      currp := @(list^.move[list^.current]);
      if currp^.rank >= lwp[currp^.suit] then
        found := true
      else
        Inc(list^.current);
    end;

    if not found then
    begin
      Result := nil;
      Exit;
    end;
  end;

  if relHand = 0 then
  begin
    trackp^.move[0].suit := currp^.suit;
    trackp^.move[0].rank := currp^.rank;
    trackp^.move[0].sequence := currp^.sequence;
    trackp^.high[0] := 0;
    trackp^.lead_suit := currp^.suit;
  end
  else if currp^.suit = trackp^.move[relHand - 1].suit then
  begin
    if currp^.rank > trackp^.move[relHand - 1].rank then
    begin
      trackp^.move[relHand].suit := currp^.suit;
      trackp^.move[relHand].rank := currp^.rank;
      trackp^.move[relHand].sequence := currp^.sequence;
      trackp^.high[relHand] := relHand;
    end
    else
    begin
      trackp^.move[relHand] := trackp^.move[relHand - 1];
      trackp^.high[relHand] := trackp^.high[relHand - 1];
    end;
  end
  else if currp^.suit = trump then
  begin
    trackp^.move[relHand].suit := currp^.suit;
    trackp^.move[relHand].rank := currp^.rank;
    trackp^.move[relHand].sequence := currp^.sequence;
    trackp^.high[relHand] := relHand;
  end
  else
  begin
    trackp^.move[relHand] := trackp^.move[relHand - 1];
    trackp^.high[relHand] := trackp^.high[relHand - 1];
  end;

  trackp^.play_suits[relHand] := currp^.suit;
  trackp^.play_ranks[relHand] := currp^.rank;

  if relHand = 3 then
  begin
    newt := @track[trick - 1];
    newt^.lead_hand := (trackp^.lead_hand + trackp^.high[3]) mod 4;

    for s := 0 to DDS_SUITS - 1 do
      newt^.removed_ranks[s] := trackp^.removed_ranks[s];

    for h := 0 to DDS_HANDS - 1 do
    begin
      r := trackp^.play_ranks[h];
      s := trackp^.play_suits[h];
      newt^.removed_ranks[s] := newt^.removed_ranks[s] or bit_map_rank[r];
    end;
  end;

  Inc(list^.current);
  Result := currp;
end;

function TMoves.MakeNextSimple(
  const trick: LongInt;
  const relHand: LongInt
): PMoveType;
var
  list: PMovePlyType;
  curr: PMoveType;
begin
  list := @(moveList[trick, relHand]);
  if list^.current > list^.last then
  begin
    Result := nil;
    Exit;
  end;

  curr := @(list^.move[list^.current]);
  trackp := @track[trick];

  if relHand = 0 then
  begin
    trackp^.move[0].suit := curr^.suit;
    trackp^.move[0].rank := curr^.rank;
    trackp^.move[0].sequence := curr^.sequence;
    trackp^.high[0] := 0;
    trackp^.lead_suit := curr^.suit;
  end
  else if curr^.suit = trackp^.move[relHand - 1].suit then
  begin
    if curr^.rank > trackp^.move[relHand - 1].rank then
    begin
      trackp^.move[relHand].suit := curr^.suit;
      trackp^.move[relHand].rank := curr^.rank;
      trackp^.move[relHand].sequence := curr^.sequence;
      trackp^.high[relHand] := relHand;
    end
    else
    begin
      trackp^.move[relHand] := trackp^.move[relHand - 1];
      trackp^.high[relHand] := trackp^.high[relHand - 1];
    end;
  end
  else if curr^.suit = trump then
  begin
    trackp^.move[relHand].suit := curr^.suit;
    trackp^.move[relHand].rank := curr^.rank;
    trackp^.move[relHand].sequence := curr^.sequence;
    trackp^.high[relHand] := relHand;
  end
  else
  begin
    trackp^.move[relHand] := trackp^.move[relHand - 1];
    trackp^.high[relHand] := trackp^.high[relHand - 1];
  end;

  trackp^.play_suits[relHand] := curr^.suit;
  trackp^.play_ranks[relHand] := curr^.rank;

  if relHand = 3 then
  begin
    track[trick - 1].lead_hand := (trackp^.lead_hand + trackp^.high[3]) mod 4;
  end;

  Inc(list^.current);
  Result := curr;
end;

procedure TMoves.Step(const tricks: LongInt; const relHand: LongInt);
begin
  Inc(moveList[tricks, relHand].current);
end;

procedure TMoves.Rewind(const tricks: LongInt; const relHand: LongInt);
begin
  moveList[tricks, relHand].current := 0;
end;

procedure TMoves.Purge(
  const trick: LongInt;
  const ourLeadHand: LongInt;
  const forbiddenMoves: array of MoveType
);
var
  ourMplyPtr: PMovePlyType;
  k, s, rank, r, n: LongInt;
begin
  ourMplyPtr := @(moveList[trick, ourLeadHand]);

  for k := 1 to 13 do
  begin
    s := forbiddenMoves[k].suit;
    rank := forbiddenMoves[k].rank;
    if rank = 0 then
      continue;

    for r := 0 to ourMplyPtr^.last do
    begin
      if (s = ourMplyPtr^.move[r].suit) and (rank = ourMplyPtr^.move[r].rank) then
      begin
        for n := r to ourMplyPtr^.last - 1 do
          ourMplyPtr^.move[n] := ourMplyPtr^.move[n + 1];
        Dec(ourMplyPtr^.last);
      end;
    end;
  end;
end;

procedure TMoves.Reward(const tricks: LongInt; const relHand: LongInt);
begin
  Inc(moveList[tricks, relHand].move[moveList[tricks, relHand].current - 1].weight, 100);
end;

function TMoves.GetTrickData(const tricks: LongInt): TrickDataType;
var
  data: TrickDataType;
  s, relh: LongInt;
begin
  FillChar(data, SizeOf(data), 0);
  for relh := 0 to DDS_HANDS - 1 do
    Inc(data.play_count[trackp^.play_suits[relh]]);

  data.best_rank := trackp^.move[3].rank;
  data.best_suit := trackp^.move[3].suit;
  data.best_sequence := trackp^.move[3].sequence;
  data.rel_winner := trackp^.high[3];
  Result := data;
end;

procedure TMoves.Sort(const tricks: LongInt; const relHand: LongInt);
begin
  numMoves := moveList[tricks, relHand].last + 1;
  mply := moveList[tricks, relHand].move;
  MergeSort;
end;

function TMoves.make_heuristic_context(
  const tpos: Pos;
  const best_move: MoveType;
  const best_move_tt: MoveType;
  const thrp_rel: array of RelRanksType;
  const tr: TrackType
): HeuristicContext;
var
  context: HeuristicContext;
  s, hand_rel: LongInt;
begin
  context.tpos_ptr := @tpos;
  context.best_move := best_move;
  context.best_move_tt := best_move_tt;
  if Length(thrp_rel) > 0 then
    context.thrp_rel := @thrp_rel[0]
  else
    context.thrp_rel := nil;
  context.mply := mply;
  context.num_moves := numMoves;
  context.last_num_moves := lastNumMoves;
  context.trump := trump;
  context.suit := suit;
  context.trackp := @tr;
  context.curr_trick := currTrick;
  context.curr_hand := currHand;
  context.lead_hand := leadHand;
  context.lead_suit := leadSuit;

  for s := 0 to DDS_SUITS - 1 do
    context.removed_ranks[s] := tr.removed_ranks[s];

  if currHand = leadHand then
    hand_rel := 0
  else
    hand_rel := (currHand + 4 - leadHand) mod 4;

  context.move1_rank := 0;
  context.move1_suit := 0;
  context.high1 := 0;
  context.move2_rank := 0;
  context.move2_suit := 0;
  context.high2 := 0;
  context.lead0_rank := 0;

  if hand_rel >= 1 then
    context.lead0_rank := tr.move[0].rank;
  if hand_rel >= 2 then
  begin
    context.move1_rank := tr.move[1].rank;
    context.move1_suit := tr.move[1].suit;
    context.high1 := tr.high[1];
  end;
  if hand_rel >= 3 then
  begin
    context.move2_rank := tr.move[2].rank;
    context.move2_suit := tr.move[2].suit;
    context.high2 := tr.high[2];
  end;

  Result := context;
end;

procedure TMoves.MergeSort;
var
  len, i, j: LongInt;
  tmp: MoveType;

  procedure cmp_swap(i, j: LongInt);
  var
    tmp: MoveType;
  begin
    if mply[i].weight < mply[j].weight then
    begin
      tmp := mply[i];
      mply[i] := mply[j];
      mply[j] := tmp;
    end;
  end;

begin
  len := numMoves;
  case len of
    12:
      begin
        cmp_swap(0, 1); cmp_swap(2, 3); cmp_swap(4, 5); cmp_swap(6, 7); cmp_swap(8, 9); cmp_swap(10, 11);
        cmp_swap(1, 3); cmp_swap(5, 7); cmp_swap(9, 11);
        cmp_swap(0, 2); cmp_swap(4, 6); cmp_swap(8, 10);
        cmp_swap(1, 2); cmp_swap(5, 6); cmp_swap(9, 10);
        cmp_swap(1, 5); cmp_swap(6, 10); cmp_swap(5, 9); cmp_swap(2, 6); cmp_swap(1, 5); cmp_swap(6, 10);
        cmp_swap(0, 4); cmp_swap(7, 11); cmp_swap(3, 7); cmp_swap(4, 8); cmp_swap(0, 4); cmp_swap(7, 11);
        cmp_swap(1, 4); cmp_swap(7, 10); cmp_swap(3, 8); cmp_swap(2, 3); cmp_swap(8, 9); cmp_swap(2, 4);
        cmp_swap(7, 9); cmp_swap(3, 5); cmp_swap(6, 8); cmp_swap(3, 4); cmp_swap(5, 6); cmp_swap(7, 8);
      end;
    11:
      begin
        cmp_swap(0, 1); cmp_swap(2, 3); cmp_swap(4, 5); cmp_swap(6, 7); cmp_swap(8, 9);
        cmp_swap(1, 3); cmp_swap(5, 7); cmp_swap(0, 2); cmp_swap(4, 6); cmp_swap(8, 10);
        cmp_swap(1, 2); cmp_swap(5, 6); cmp_swap(9, 10); cmp_swap(1, 5); cmp_swap(6, 10);
        cmp_swap(5, 9); cmp_swap(2, 6); cmp_swap(1, 5); cmp_swap(6, 10); cmp_swap(0, 4);
        cmp_swap(3, 7); cmp_swap(4, 8); cmp_swap(0, 4); cmp_swap(1, 4); cmp_swap(7, 10);
        cmp_swap(3, 8); cmp_swap(2, 3); cmp_swap(8, 9); cmp_swap(2, 4); cmp_swap(7, 9);
        cmp_swap(3, 5); cmp_swap(6, 8); cmp_swap(3, 4); cmp_swap(5, 6); cmp_swap(7, 8);
      end;
    10:
      begin
        cmp_swap(1, 8); cmp_swap(0, 4); cmp_swap(5, 9); cmp_swap(2, 6); cmp_swap(3, 7);
        cmp_swap(0, 3); cmp_swap(6, 9); cmp_swap(2, 5); cmp_swap(0, 1); cmp_swap(3, 6);
        cmp_swap(8, 9); cmp_swap(4, 7); cmp_swap(0, 2); cmp_swap(4, 8); cmp_swap(1, 5);
        cmp_swap(7, 9); cmp_swap(1, 2); cmp_swap(3, 4); cmp_swap(5, 6); cmp_swap(7, 8);
        cmp_swap(1, 3); cmp_swap(6, 8); cmp_swap(2, 4); cmp_swap(5, 7); cmp_swap(2, 3);
        cmp_swap(6, 7); cmp_swap(3, 5); cmp_swap(4, 6); cmp_swap(4, 5);
      end;
    9:
      begin
        cmp_swap(0, 1); cmp_swap(3, 4); cmp_swap(6, 7); cmp_swap(1, 2); cmp_swap(4, 5);
        cmp_swap(7, 8); cmp_swap(0, 1); cmp_swap(3, 4); cmp_swap(6, 7); cmp_swap(0, 3);
        cmp_swap(3, 6); cmp_swap(0, 3); cmp_swap(1, 4); cmp_swap(4, 7); cmp_swap(1, 4);
        cmp_swap(2, 5); cmp_swap(5, 8); cmp_swap(2, 5); cmp_swap(1, 3); cmp_swap(5, 7);
        cmp_swap(2, 6); cmp_swap(4, 6); cmp_swap(2, 4); cmp_swap(2, 3); cmp_swap(5, 6);
      end;
    8:
      begin
        cmp_swap(0, 1); cmp_swap(2, 3); cmp_swap(4, 5); cmp_swap(6, 7);
        cmp_swap(0, 2); cmp_swap(4, 6); cmp_swap(1, 3); cmp_swap(5, 7);
        cmp_swap(1, 2); cmp_swap(5, 6); cmp_swap(0, 4); cmp_swap(1, 5);
        cmp_swap(2, 6); cmp_swap(3, 7); cmp_swap(2, 4); cmp_swap(3, 5);
        cmp_swap(1, 2); cmp_swap(3, 4); cmp_swap(5, 6);
      end;
    7:
      begin
        cmp_swap(0, 1); cmp_swap(2, 3); cmp_swap(4, 5); cmp_swap(0, 2);
        cmp_swap(4, 6); cmp_swap(1, 3); cmp_swap(1, 2); cmp_swap(5, 6);
        cmp_swap(0, 4); cmp_swap(1, 5); cmp_swap(2, 6); cmp_swap(2, 4);
        cmp_swap(3, 5); cmp_swap(1, 2); cmp_swap(3, 4); cmp_swap(5, 6);
      end;
    6:
      begin
        cmp_swap(0, 1); cmp_swap(2, 3); cmp_swap(4, 5); cmp_swap(0, 2);
        cmp_swap(1, 3); cmp_swap(1, 2); cmp_swap(0, 4); cmp_swap(1, 5);
        cmp_swap(2, 4); cmp_swap(3, 5); cmp_swap(1, 2); cmp_swap(3, 4);
      end;
    5:
      begin
        cmp_swap(0, 1); cmp_swap(2, 3); cmp_swap(0, 2); cmp_swap(1, 3);
        cmp_swap(1, 2); cmp_swap(0, 4); cmp_swap(2, 4); cmp_swap(1, 2);
        cmp_swap(3, 4);
      end;
    4:
      begin
        cmp_swap(0, 1); cmp_swap(2, 3); cmp_swap(0, 2); cmp_swap(1, 3);
        cmp_swap(1, 2);
      end;
    3:
      begin
        cmp_swap(0, 1); cmp_swap(0, 2); cmp_swap(1, 2);
      end;
    2:
      begin
        cmp_swap(0, 1);
      end;
    else
      begin
        for i := 1 to len - 1 do
        begin
          tmp := mply[i];
          j := i;
          while (j > 0) and (tmp.weight > mply[j - 1].weight) do
          begin
            mply[j] := mply[j - 1];
            Dec(j);
          end;
          mply[j] := tmp;
        end;
      end;
  end;
end;

// Standalone heuristic weight allocation functions
function rank_forces_ace(const ctx: HeuristicContext; cards4th: LongInt): LongInt;
var
  mp: PMoveGroupType;
  g, removed, secondRHO, k: LongInt;
begin
  mp := @group_data[cards4th];
  g := mp^.last_group_;
  removed := ctx.removed_ranks[ctx.lead_suit];

  while (g >= 1) and ((mp^.gap_[g] and removed) = mp^.gap_[g]) do
    Dec(g);

  if g <= 0 then
  begin
    Result := -1;
    Exit;
  end;

  if g = 0 then
    secondRHO := 0
  else
    secondRHO := mp^.rank_[g - 1];

  if secondRHO > ctx.move1_rank then
  begin
    k := 0;
    while (k < ctx.num_moves) and (ctx.mply[k].rank > secondRHO) do
      Inc(k);
    if k > 0 then
    begin
      Result := k - 1;
      Exit;
    end;
  end
  else if ctx.high1 = 1 then
  begin
    k := 0;
    while (k < ctx.num_moves) and (ctx.mply[k].rank > ctx.move1_rank) do
      Inc(k);
    if k > 0 then
    begin
      Result := k - 1;
      Exit;
    end;
  end;

  Result := -1;
end;

procedure get_top_number(const ctx: HeuristicContext; const ris: LongInt; const prank: LongInt; var top_number: LongInt; var mno: LongInt);
var
  mp: PMoveGroupType;
  g, removed, fullseq: LongInt;
begin
  top_number := -10;
  mno := 0;
  while (mno < ctx.num_moves - 1) and (ctx.mply[1 + mno].rank > prank) do
    Inc(mno);

  mp := @group_data[ris];
  g := mp^.last_group_;
  removed := ctx.removed_ranks[ctx.lead_suit] or bit_map_rank[prank];

  fullseq := mp^.fullseq_[g];
  while (g >= 1) and ((mp^.gap_[g] and removed) = mp^.gap_[g]) do
  begin
    Dec(g);
    fullseq := fullseq or mp^.fullseq_[g];
  end;

  top_number := count_table[fullseq] - 1;
end;

procedure weight_alloc_trump0(var context: HeuristicContext);
var
  suitCount, suit_count_lh, suit_count_rh, aggr, countLH, countRH, suit_weight_d: LongInt;
  k, suit_bonus, r_rank, thirdBestHand: LongInt;
  win_move: Boolean;
  temp: Word;
begin
  suitCount := context.tpos_ptr^.length[context.lead_hand, context.suit];
  suit_count_lh := context.tpos_ptr^.length[lho[context.lead_hand], context.suit];
  suit_count_rh := context.tpos_ptr^.length[rho[context.lead_hand], context.suit];
  aggr := context.tpos_ptr^.aggr[context.suit];

  if suit_count_lh = 0 then countLH := context.curr_trick + 1 else countLH := suit_count_lh;
  countLH := countLH shl 2;

  if suit_count_rh = 0 then countRH := context.curr_trick + 1 else countRH := suit_count_rh;
  countRH := countRH shl 2;

  suit_weight_d := - (((countLH + countRH) shl 5) div 13);

  for k := context.last_num_moves to context.num_moves - 1 do
  begin
    suit_bonus := 0;
    win_move := false;
    r_rank := rel_rank[aggr, context.mply[k].rank];

    if (context.suit <> context.trump) and
       (((context.tpos_ptr^.rank_in_suit[lho[context.lead_hand], context.suit] = 0) and
         (context.tpos_ptr^.rank_in_suit[lho[context.lead_hand], context.trump] <> 0)) or
        ((context.tpos_ptr^.rank_in_suit[rho[context.lead_hand], context.suit] = 0) and
         (context.tpos_ptr^.rank_in_suit[rho[context.lead_hand], context.trump] <> 0))) then
      suit_bonus := -12;

    if (context.suit <> context.trump) and
       (context.tpos_ptr^.length[partner[context.lead_hand], context.suit] = 0) and
       (context.tpos_ptr^.length[partner[context.lead_hand], context.trump] > 0) and
       (suit_count_rh > 0) then
      suit_bonus := suit_bonus + 17;

    if (context.tpos_ptr^.winner[context.suit].hand = rho[context.lead_hand]) or
       (context.tpos_ptr^.second_best[context.suit].hand = rho[context.lead_hand]) then
    begin
      if suit_count_rh <> 1 then
        suit_bonus := suit_bonus - 12;
    end
    else if (context.tpos_ptr^.winner[context.suit].hand = lho[context.lead_hand]) and
            (context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand]) then
    begin
      if context.tpos_ptr^.length[partner[context.lead_hand], context.suit] <> 1 then
        suit_bonus := suit_bonus + 27;
    end;

    if (context.suit <> context.trump) and (suitCount = 1) and
       (context.tpos_ptr^.length[context.lead_hand, context.trump] > 0) and
       (context.tpos_ptr^.length[partner[context.lead_hand], context.suit] > 1) and
       (context.tpos_ptr^.winner[context.suit].hand = partner[context.lead_hand]) then
      suit_bonus := suit_bonus + 19;

    if context.tpos_ptr^.winner[context.suit].rank = context.mply[k].rank then
    begin
      if context.suit <> context.trump then
      begin
        if (context.tpos_ptr^.length[partner[context.lead_hand], context.suit] <> 0) or
           (context.tpos_ptr^.length[partner[context.lead_hand], context.trump] = 0) then
        begin
          if ((context.tpos_ptr^.length[lho[context.lead_hand], context.suit] <> 0) or
              (context.tpos_ptr^.length[lho[context.lead_hand], context.trump] = 0)) and
             ((context.tpos_ptr^.length[rho[context.lead_hand], context.suit] <> 0) or
              (context.tpos_ptr^.length[rho[context.lead_hand], context.trump] = 0)) then
            win_move := true;
        end
        else if ((context.tpos_ptr^.length[lho[context.lead_hand], context.suit] <> 0) or
                 (context.tpos_ptr^.rank_in_suit[partner[context.lead_hand], context.trump] >
                  context.tpos_ptr^.rank_in_suit[lho[context.lead_hand], context.trump])) and
                ((context.tpos_ptr^.length[rho[context.lead_hand], context.suit] <> 0) or
                 (context.tpos_ptr^.rank_in_suit[partner[context.lead_hand], context.trump] >
                  context.tpos_ptr^.rank_in_suit[rho[context.lead_hand], context.trump])) then
          win_move := true;
      end
      else
        win_move := true;
    end
    else if context.tpos_ptr^.rank_in_suit[partner[context.lead_hand], context.suit] >
            (context.tpos_ptr^.rank_in_suit[lho[context.lead_hand], context.suit] or
             context.tpos_ptr^.rank_in_suit[rho[context.lead_hand], context.suit]) then
    begin
      if context.suit <> context.trump then
      begin
        if ((context.tpos_ptr^.length[lho[context.lead_hand], context.suit] <> 0) or
             (context.tpos_ptr^.length[lho[context.lead_hand], context.trump] = 0)) and
            ((context.tpos_ptr^.length[rho[context.lead_hand], context.suit] <> 0) or
             (context.tpos_ptr^.length[rho[context.lead_hand], context.trump] = 0)) then
          win_move := true;
      end
      else
        win_move := true;
    end
    else if context.suit <> context.trump then
    begin
      if (context.tpos_ptr^.length[partner[context.lead_hand], context.suit] = 0) and
         (context.tpos_ptr^.length[partner[context.lead_hand], context.trump] <> 0) then
      begin
        if (context.tpos_ptr^.length[lho[context.lead_hand], context.suit] = 0) and
           (context.tpos_ptr^.length[lho[context.lead_hand], context.trump] <> 0) and
           (context.tpos_ptr^.length[rho[context.lead_hand], context.suit] = 0) and
           (context.tpos_ptr^.length[rho[context.lead_hand], context.trump] <> 0) then
        begin
          if context.tpos_ptr^.rank_in_suit[partner[context.lead_hand], context.trump] >
              (context.tpos_ptr^.rank_in_suit[lho[context.lead_hand], context.trump] or
               context.tpos_ptr^.rank_in_suit[rho[context.lead_hand], context.trump]) then
            win_move := true;
        end
        else if (context.tpos_ptr^.length[lho[context.lead_hand], context.suit] = 0) and
                 (context.tpos_ptr^.length[lho[context.lead_hand], context.trump] <> 0) then
        begin
          if context.tpos_ptr^.rank_in_suit[partner[context.lead_hand], context.trump]
              > context.tpos_ptr^.rank_in_suit[lho[context.lead_hand], context.trump] then
            win_move := true;
        end
        else if (context.tpos_ptr^.length[rho[context.lead_hand], context.suit] = 0) and
                 (context.tpos_ptr^.length[rho[context.lead_hand], context.trump] <> 0) then
        begin
          if context.tpos_ptr^.rank_in_suit[partner[context.lead_hand], context.trump]
              > context.tpos_ptr^.rank_in_suit[rho[context.lead_hand], context.trump] then
            win_move := true;
        end
        else
          win_move := true;
      end;
    end;

    if win_move then
    begin
      if (suit_count_lh = 1) and
         (context.tpos_ptr^.winner[context.suit].hand = lho[context.lead_hand]) or
         (suit_count_rh = 1) and
         (context.tpos_ptr^.winner[context.suit].hand = rho[context.lead_hand]) then
        context.mply[k].weight := suit_bonus + suit_weight_d + 35 + r_rank
      else if context.tpos_ptr^.winner[context.suit].hand = context.lead_hand then
      begin
        if context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand] then
          context.mply[k].weight := suit_bonus + suit_weight_d + 48 + r_rank
        else if context.tpos_ptr^.winner[context.suit].rank = context.mply[k].rank then
          context.mply[k].weight := suit_bonus + suit_weight_d + 31
        else
          context.mply[k].weight := suit_bonus + suit_weight_d - 3 + r_rank;
      end
      else if context.tpos_ptr^.winner[context.suit].hand = partner[context.lead_hand] then
      begin
        if context.tpos_ptr^.second_best[context.suit].hand = context.lead_hand then
          context.mply[k].weight := suit_bonus + suit_weight_d + 42 + r_rank
        else
          context.mply[k].weight := suit_bonus + suit_weight_d + 28 + r_rank;
      end
      else if (context.mply[k].sequence <> 0) and
               (context.mply[k].rank = context.tpos_ptr^.second_best[context.suit].rank) then
        context.mply[k].weight := suit_bonus + suit_weight_d + 40
      else if context.mply[k].sequence <> 0 then
        context.mply[k].weight := suit_bonus + suit_weight_d + 22 + r_rank
      else
        context.mply[k].weight := suit_bonus + suit_weight_d + 11 + r_rank;

      if (context.best_move.rank > 0) and
          (context.best_move.suit = context.suit) and
          (context.best_move.rank = context.mply[k].rank) then
        context.mply[k].weight := context.mply[k].weight + 55
      else if (context.best_move_tt.rank > 0) and
               (context.best_move_tt.suit = context.suit) and
               (context.best_move_tt.rank = context.mply[k].rank) then
        context.mply[k].weight := context.mply[k].weight + 18;
    end
    else
    begin
      thirdBestHand := context.thrp_rel^.abs_rank[3, context.suit].hand;

      if (context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand]) and
          (partner[context.lead_hand] = thirdBestHand) then
        suit_bonus := suit_bonus + 20
      else if ((context.tpos_ptr^.second_best[context.suit].hand = context.lead_hand) and
                (partner[context.lead_hand] = thirdBestHand) and
                (context.tpos_ptr^.length[partner[context.lead_hand], context.suit] > 1)) or
               ((context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand]) and
                (context.lead_hand = thirdBestHand) and
                (context.tpos_ptr^.length[partner[context.lead_hand], context.suit] > 1)) then
        suit_bonus := suit_bonus + 13;

      if ((suit_count_lh = 1) and
           (context.tpos_ptr^.winner[context.suit].hand = lho[context.lead_hand])) or
          ((suit_count_rh = 1) and
           (context.tpos_ptr^.winner[context.suit].hand = rho[context.lead_hand])) then
        context.mply[k].weight := suit_bonus + suit_weight_d + r_rank + 2
      else if context.tpos_ptr^.winner[context.suit].hand = context.lead_hand then
      begin
        if context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand] then
          context.mply[k].weight := suit_bonus + suit_weight_d + 33 + r_rank
        else if context.tpos_ptr^.winner[context.suit].rank = context.mply[k].rank then
          context.mply[k].weight := suit_bonus + suit_weight_d + 38
        else
          context.mply[k].weight := suit_bonus + suit_weight_d - 14 + r_rank;
      end
      else if context.tpos_ptr^.winner[context.suit].hand = partner[context.lead_hand] then
      begin
        context.mply[k].weight := suit_bonus + suit_weight_d + 34 + r_rank;
      end
      else if (context.mply[k].sequence <> 0) and
               (context.mply[k].rank = context.tpos_ptr^.second_best[context.suit].rank) then
        context.mply[k].weight := suit_bonus + suit_weight_d + 35
      else
        context.mply[k].weight := suit_bonus + suit_weight_d + 17 - context.mply[k].rank;

      if (context.best_move.rank > 0) and
          (context.best_move.suit = context.suit) and
          (context.best_move.rank = context.mply[k].rank) then
        context.mply[k].weight := context.mply[k].weight + 18;
    end;
  end;
end;

procedure weight_alloc_nt0(var context: HeuristicContext);
var
  aggr, countLH, countRH, suit_weight_d, k, suit_weight_delta, r_rank, thirdBestHand: LongInt;
  suit_count_lh, suit_count_rh: Word;
begin
  aggr := context.tpos_ptr^.aggr[context.suit];
  suit_count_lh := context.tpos_ptr^.length[lho[context.lead_hand], context.suit];
  suit_count_rh := context.tpos_ptr^.length[rho[context.lead_hand], context.suit];

  if suit_count_lh = 0 then countLH := context.curr_trick + 1 else countLH := suit_count_lh;
  countLH := countLH shl 2;

  if suit_count_rh = 0 then countRH := context.curr_trick + 1 else countRH := suit_count_rh;
  countRH := countRH shl 2;

  suit_weight_d := - (((countLH + countRH) shl 5) div 19);
  if context.tpos_ptr^.length[partner[context.lead_hand], context.suit] = 0 then
    suit_weight_d := suit_weight_d - 9;

  for k := context.last_num_moves to context.num_moves - 1 do
  begin
    suit_weight_delta := suit_weight_d;
    r_rank := rel_rank[aggr, context.mply[k].rank];

    if (context.tpos_ptr^.winner[context.suit].rank = context.mply[k].rank) or
       (context.tpos_ptr^.rank_in_suit[partner[context.lead_hand], context.suit] >
        (context.tpos_ptr^.rank_in_suit[lho[context.lead_hand], context.suit] or
         context.tpos_ptr^.rank_in_suit[rho[context.lead_hand], context.suit])) then
    begin
      if context.tpos_ptr^.second_best[context.suit].hand = rho[context.lead_hand] then
      begin
        if suit_count_rh <> 1 then
          suit_weight_delta := suit_weight_delta - 1;
      end
      else if context.tpos_ptr^.second_best[context.suit].hand = lho[context.lead_hand] then
      begin
        if suit_count_lh <> 1 then
          suit_weight_delta := suit_weight_delta + 22
        else
          suit_weight_delta := suit_weight_delta + 16;
      end;

      if ((context.tpos_ptr^.second_best[context.suit].hand <> lho[context.lead_hand]) or
          (suit_count_lh = 1)) and
         ((context.tpos_ptr^.second_best[context.suit].hand <> rho[context.lead_hand]) or
          (suit_count_rh = 1)) then
        context.mply[k].weight := suit_weight_delta + 45 + r_rank
      else
        context.mply[k].weight := suit_weight_delta + 18 + r_rank;

      if (context.best_move.rank > 0) and
          (context.best_move.suit = context.suit) and
          (context.best_move.rank = context.mply[k].rank) then
        context.mply[k].weight := context.mply[k].weight + 126
      else if (context.best_move_tt.rank > 0) and
               (context.best_move_tt.suit = context.suit) and
               (context.best_move_tt.rank = context.mply[k].rank) then
        context.mply[k].weight := context.mply[k].weight + 32;
    end
    else
    begin
      if (context.tpos_ptr^.winner[context.suit].hand = rho[context.lead_hand]) or
          (context.tpos_ptr^.second_best[context.suit].hand = rho[context.lead_hand]) then
      begin
        if suit_count_rh <> 1 then
          suit_weight_delta := suit_weight_delta - 10;
      end
      else if (context.tpos_ptr^.winner[context.suit].hand = lho[context.lead_hand]) and
               (context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand]) then
      begin
        if context.tpos_ptr^.length[partner[context.lead_hand], context.suit] <> 1 then
          suit_weight_delta := suit_weight_delta + 31;
      end;

      thirdBestHand := context.thrp_rel^.abs_rank[3, context.suit].hand;

      if (context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand]) and
          (partner[context.lead_hand] = thirdBestHand) then
        suit_weight_delta := suit_weight_delta + 29
      else if ((context.tpos_ptr^.second_best[context.suit].hand = context.lead_hand) and
                (partner[context.lead_hand] = thirdBestHand) and
                (context.tpos_ptr^.length[partner[context.lead_hand], context.suit] > 1)) or
               ((context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand]) and
                (context.lead_hand = thirdBestHand) and
                (context.tpos_ptr^.length[partner[context.lead_hand], context.suit] > 1)) then
        suit_weight_delta := suit_weight_delta + 23;

      if ((suit_count_lh = 1) and
           (context.tpos_ptr^.winner[context.suit].hand = lho[context.lead_hand])) or
          ((suit_count_rh = 1) and
           (context.tpos_ptr^.winner[context.suit].hand = rho[context.lead_hand])) then
        context.mply[k].weight := suit_weight_delta + r_rank
      else if context.tpos_ptr^.winner[context.suit].hand = context.lead_hand then
      begin
        if context.tpos_ptr^.second_best[context.suit].hand = partner[context.lead_hand] then
          context.mply[k].weight := suit_weight_delta + 37 + r_rank
        else if context.tpos_ptr^.winner[context.suit].rank = context.mply[k].rank then
          context.mply[k].weight := suit_weight_delta + 40
        else
          context.mply[k].weight := suit_weight_delta - 11 + r_rank;
      end
      else if context.tpos_ptr^.winner[context.suit].hand = partner[context.lead_hand] then
      begin
        context.mply[k].weight := suit_weight_delta + 35 + r_rank;
      end
      else if (context.mply[k].sequence <> 0) and
               (context.mply[k].rank = context.tpos_ptr^.second_best[context.suit].rank) then
        context.mply[k].weight := suit_weight_delta + 34
      else
        context.mply[k].weight := suit_weight_delta + 18 - context.mply[k].rank;

      if (context.best_move.rank > 0) and
          (context.best_move.suit = context.suit) and
          (context.best_move.rank = context.mply[k].rank) then
        context.mply[k].weight := context.mply[k].weight + 22;
    end;
  end;
end;

procedure weight_alloc_trump_notvoid1(var ctx: HeuristicContext);
var
  max3rd, maxpd, min3rd, minpd, k, r_rank: LongInt;
  win_move: Boolean;
begin
  max3rd := highest_rank[ctx.tpos_ptr^.rank_in_suit[partner[ctx.lead_hand], ctx.lead_suit]];
  maxpd := highest_rank[ctx.tpos_ptr^.rank_in_suit[rho[ctx.lead_hand], ctx.lead_suit]];
  min3rd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[partner[ctx.lead_hand], ctx.lead_suit]];
  minpd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[rho[ctx.lead_hand], ctx.lead_suit]];

  for k := 0 to ctx.num_moves - 1 do
  begin
    win_move := false;
    r_rank := rel_rank[ctx.tpos_ptr^.aggr[ctx.lead_suit], ctx.mply[k].rank];

    if ctx.lead_suit = ctx.trump then
    begin
      if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) then
        win_move := true
      else if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) then
        win_move := true;
    end
    else
    begin
      if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) then
      begin
        if (max3rd <> 0) or (ctx.tpos_ptr^.length[partner[ctx.lead_hand], ctx.trump] = 0) then
          win_move := true
        else if (maxpd = 0) and (ctx.tpos_ptr^.length[rho[ctx.lead_hand], ctx.trump] <> 0) and
                 (ctx.tpos_ptr^.rank_in_suit[rho[ctx.lead_hand], ctx.trump] >
                  ctx.tpos_ptr^.rank_in_suit[partner[ctx.lead_hand], ctx.trump]) then
          win_move := true;
      end
      else if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) then
      begin
        if (max3rd <> 0) or (ctx.tpos_ptr^.length[partner[ctx.lead_hand], ctx.trump] = 0) then
          win_move := true;
      end
      else if (ctx.lead0_rank > maxpd) and (ctx.lead0_rank > max3rd) and (ctx.lead0_rank > ctx.mply[k].rank) then
      begin
        if (maxpd = 0) and (ctx.tpos_ptr^.length[rho[ctx.lead_hand], ctx.trump] <> 0) then
        begin
          if (max3rd <> 0) or (ctx.tpos_ptr^.length[partner[ctx.lead_hand], ctx.trump] = 0) then
            win_move := true
          else if ctx.tpos_ptr^.rank_in_suit[rho[ctx.lead_hand], ctx.trump] >
                   ctx.tpos_ptr^.rank_in_suit[partner[ctx.lead_hand], ctx.trump] then
            win_move := true;
        end;
      end
      else if (maxpd = 0) and (ctx.tpos_ptr^.length[rho[ctx.lead_hand], ctx.trump] <> 0) then
        win_move := true;
    end;

    if win_move then
    begin
      if min3rd > ctx.mply[k].rank then
        ctx.mply[k].weight := 40 + r_rank
      else if (maxpd > ctx.lead0_rank) and
               (ctx.tpos_ptr^.rank_in_suit[ctx.lead_hand, ctx.lead_suit] >
                ctx.tpos_ptr^.rank_in_suit[rho[ctx.lead_hand], ctx.lead_suit]) then
        ctx.mply[k].weight := 41 + r_rank
      else if ctx.mply[k].rank > ctx.lead0_rank then
      begin
        if ctx.mply[k].rank < maxpd then
          ctx.mply[k].weight := 78 - ctx.mply[k].rank
        else if ctx.mply[k].rank > max3rd then
          ctx.mply[k].weight := 73 - ctx.mply[k].rank
        else if ctx.mply[k].sequence <> 0 then
          ctx.mply[k].weight := 62 - ctx.mply[k].rank
        else
          ctx.mply[k].weight := 49 - ctx.mply[k].rank;
      end
      else if maxpd > 0 then
        ctx.mply[k].weight := 47 - ctx.mply[k].rank
      else
        ctx.mply[k].weight := 40 - ctx.mply[k].rank;
    end
    else if (ctx.mply[k].rank < min3rd) or (ctx.mply[k].rank < minpd) then
      ctx.mply[k].weight := -9 + r_rank
    else if ctx.mply[k].rank < ctx.lead0_rank then
      ctx.mply[k].weight := -16 + r_rank
    else if ctx.mply[k].sequence <> 0 then
      ctx.mply[k].weight := 22 - ctx.mply[k].rank
    else
      ctx.mply[k].weight := 10 - ctx.mply[k].rank;
  end;
end;

procedure weight_alloc_nt_notvoid1(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, max3rd, maxpd, min3rd, minpd, k, r_rank: LongInt;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];

  max3rd := highest_rank[ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit]];
  maxpd := highest_rank[ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit]];

  if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) then
  begin
    for k := 0 to ctx.num_moves - 1 do
      ctx.mply[k].weight := -ctx.mply[k].rank;
  end
  else
  begin
    min3rd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit]];
    minpd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit]];

    for k := 0 to ctx.num_moves - 1 do
    begin
      r_rank := rel_rank[ctx.tpos_ptr^.aggr[ctx.lead_suit], ctx.mply[k].rank];

      if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) then
        ctx.mply[k].weight := 81 - ctx.mply[k].rank
      else if (min3rd > ctx.mply[k].rank) or (minpd > ctx.mply[k].rank) then
        ctx.mply[k].weight := -3 + r_rank
      else if ctx.mply[k].rank < ctx.lead0_rank then
        ctx.mply[k].weight := -11 + r_rank
      else if ctx.mply[k].sequence <> 0 then
        ctx.mply[k].weight := 10 + r_rank
      else
        ctx.mply[k].weight := 13 - ctx.mply[k].rank;
    end;
  end;
end;

procedure weight_alloc_trump_void1(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, suitCount, suitAdd, k: LongInt;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];
  suitCount := ctx.tpos_ptr^.length[ctx.curr_hand, ctx.suit];

  if ctx.lead_suit = ctx.trump then
  begin
    if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
       (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank]) then
      suitAdd := (suitCount shl 6) div 44
    else
    begin
      suitAdd := (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;

    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := -ctx.mply[k].rank + suitAdd;
  end
  else if ctx.suit <> ctx.trump then
  begin
    if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
    begin
      if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
         (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank]) then
        suitAdd := 60 + (suitCount shl 6) div 44
      else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
              (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) then
        suitAdd := 60 + (suitCount shl 6) div 44
      else
      begin
        suitAdd := -2 + (suitCount shl 6) div 36;
        if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
          suitAdd := suitAdd - 4;
      end;
    end
    else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
             (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
              ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump]) then
      suitAdd := 60 + (suitCount shl 6) div 44
    else if (ctx.tpos_ptr^.length[partner_lh, ctx.trump] = 0) and
             (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
              bit_map_rank[ctx.lead0_rank]) then
      suitAdd := 60 + (suitCount shl 6) div 44
    else
    begin
      suitAdd := -2 + (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;

    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := -ctx.mply[k].weight + suitAdd;
  end
  else if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
  begin
    suitAdd := (suitCount shl 6) div 44;
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
  end
  else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
           (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) and
           (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
            ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump]) then
  begin
    suitAdd := (suitCount shl 6) div 44;
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
  end
  else
  begin
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
    begin
      if bit_map_rank[ctx.mply[k].rank] > ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump] then
      begin
        suitAdd := (suitCount shl 6) div 44;
        ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
      end
      else
      begin
        suitAdd := (suitCount shl 6) div 36;
        if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
          suitAdd := suitAdd - 4;
        ctx.mply[k].weight := 15 - ctx.mply[k].rank + suitAdd;
      end;
    end;
  end;
end;

procedure weight_alloc_nt_void1(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, suitCount, suitAdd, k: LongInt;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];
  suitCount := ctx.tpos_ptr^.length[ctx.curr_hand, ctx.suit];

  if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
  begin
    if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
       (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank]) then
      suitAdd := (suitCount shl 6) div 44
    else
    begin
      suitAdd := (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;
  end
  else if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] > bit_map_rank[ctx.lead0_rank] then
    suitAdd := (suitCount shl 6) div 44
  else
  begin
    suitAdd := (suitCount shl 6) div 36;
    if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
      suitAdd := suitAdd - 4;
  end;

  for k := ctx.last_num_moves to ctx.num_moves - 1 do
    ctx.mply[k].weight := -ctx.mply[k].rank + suitAdd;
end;

procedure weight_alloc_trump_notvoid2(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, max3rd, maxpd, min3rd, minpd, cards4th, k, r_rank, kBonus: LongInt;
  win_move: Boolean;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];

  max3rd := highest_rank[ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit]];
  maxpd := highest_rank[ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit]];
  min3rd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit]];
  minpd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit]];

  cards4th := ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit];

  for k := 0 to ctx.num_moves - 1 do
  begin
    win_move := false;
    r_rank := rel_rank[ctx.tpos_ptr^.aggr[ctx.lead_suit], ctx.mply[k].rank];

    if ctx.lead_suit = ctx.trump then
    begin
      if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) and (maxpd > ctx.move1_rank) then
        win_move := true
      else if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) and (ctx.mply[k].rank > ctx.move1_rank) then
        win_move := true;
    end
    else
    begin
      if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) and (ctx.mply[k].rank > ctx.move1_rank) then
      begin
        if (max3rd <> 0) or (ctx.tpos_ptr^.length[partner_lh, ctx.trump] = 0) then
          win_move := true
        else if (maxpd = 0) and (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) and
                 (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
                  ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump]) then
          win_move := true;
      end
      else if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) and (maxpd > ctx.move1_rank) then
      begin
        if (max3rd <> 0) or (ctx.tpos_ptr^.length[partner_lh, ctx.trump] = 0) then
          win_move := true;
      end
      else if (ctx.lead0_rank > maxpd) and (ctx.lead0_rank > max3rd) and (ctx.lead0_rank > ctx.move1_rank) and (ctx.lead0_rank > ctx.mply[k].rank) then
      begin
        if (maxpd = 0) and (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) then
        begin
          if (max3rd <> 0) or (ctx.tpos_ptr^.length[partner_lh, ctx.trump] = 0) then
            win_move := true
          else if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
                   ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump] then
            win_move := true;
        end;
      end
      else if (ctx.move1_rank > ctx.lead0_rank) and (ctx.move1_rank > maxpd) and (ctx.move1_rank > max3rd) and (ctx.move1_rank > ctx.mply[k].rank) then
      begin
        if (maxpd = 0) and (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) then
        begin
          if (max3rd <> 0) or (ctx.tpos_ptr^.length[partner_lh, ctx.trump] = 0) then
            win_move := true
          else if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
                   ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump] then
            win_move := true;
        end;
      end
      else if (maxpd = 0) and (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) then
        win_move := true;
    end;

    if win_move then
    begin
      kBonus := rank_forces_ace(ctx, cards4th);
      if kBonus = k then
        ctx.mply[k].weight := 90 - ctx.mply[k].rank
      else if min3rd > ctx.mply[k].rank then
        ctx.mply[k].weight := 40 + r_rank
      else if (maxpd > ctx.lead0_rank) and (maxpd > ctx.move1_rank) and
               (ctx.tpos_ptr^.rank_in_suit[ctx.lead_hand, ctx.lead_suit] >
                ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit]) then
        ctx.mply[k].weight := 41 + r_rank
      else if ctx.mply[k].rank > ctx.lead0_rank then
      begin
        if (ctx.mply[k].rank < maxpd) and (ctx.mply[k].rank > ctx.move1_rank) then
          ctx.mply[k].weight := 78 - ctx.mply[k].rank
        else if ctx.mply[k].rank > max3rd then
          ctx.mply[k].weight := 73 - ctx.mply[k].rank
        else if ctx.mply[k].sequence <> 0 then
          ctx.mply[k].weight := 62 - ctx.mply[k].rank
        else
          ctx.mply[k].weight := 49 - ctx.mply[k].rank;
      end
      else if maxpd > 0 then
        ctx.mply[k].weight := 47 - ctx.mply[k].rank
      else
        ctx.mply[k].weight := 40 - ctx.mply[k].rank;
    end
    else if (ctx.mply[k].rank < min3rd) or (ctx.mply[k].rank < minpd) then
      ctx.mply[k].weight := -9 + r_rank
    else if (ctx.mply[k].rank < ctx.lead0_rank) or (ctx.mply[k].rank < ctx.move1_rank) then
      ctx.mply[k].weight := -16 + r_rank
    else if ctx.mply[k].sequence <> 0 then
      ctx.mply[k].weight := 22 - ctx.mply[k].rank
    else
      ctx.mply[k].weight := 10 - ctx.mply[k].rank;
  end;
end;

procedure weight_alloc_nt_notvoid2(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, max3rd, maxpd, min3rd, minpd, cards4th, k, r_rank, kBonus: LongInt;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];

  max3rd := highest_rank[ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit]];
  maxpd := highest_rank[ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit]];

  if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) and (maxpd > ctx.move1_rank) then
  begin
    for k := 0 to ctx.num_moves - 1 do
      ctx.mply[k].weight := -ctx.mply[k].rank;
  end
  else
  begin
    min3rd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit]];
    minpd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit]];

    cards4th := ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit];

    for k := 0 to ctx.num_moves - 1 do
    begin
      r_rank := rel_rank[ctx.tpos_ptr^.aggr[ctx.lead_suit], ctx.mply[k].rank];

      kBonus := rank_forces_ace(ctx, cards4th);
      if kBonus = k then
        ctx.mply[k].weight := 90 - ctx.mply[k].rank
      else if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) and (ctx.mply[k].rank > ctx.move1_rank) then
        ctx.mply[k].weight := 81 - ctx.mply[k].rank
      else if (min3rd > ctx.mply[k].rank) or (minpd > ctx.mply[k].rank) then
        ctx.mply[k].weight := -3 + r_rank
      else if (ctx.mply[k].rank < ctx.lead0_rank) or (ctx.mply[k].rank < ctx.move1_rank) then
        ctx.mply[k].weight := -11 + r_rank
      else if ctx.mply[k].sequence <> 0 then
        ctx.mply[k].weight := 10 + r_rank
      else
        ctx.mply[k].weight := 13 - ctx.mply[k].rank;
    end;
  end;
end;

procedure weight_alloc_trump_void2(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, suitCount, suitAdd, k: LongInt;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];
  suitCount := ctx.tpos_ptr^.length[ctx.curr_hand, ctx.suit];

  if ctx.lead_suit = ctx.trump then
  begin
    if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
       (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank]) then
      suitAdd := (suitCount shl 6) div 44
    else
    begin
      suitAdd := (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;

    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := -ctx.mply[k].rank + suitAdd;
  end
  else if ctx.suit <> ctx.trump then
  begin
    if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
    begin
      if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
         (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank]) then
        suitAdd := 60 + (suitCount shl 6) div 44
      else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
              (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) then
        suitAdd := 60 + (suitCount shl 6) div 44
      else
      begin
        suitAdd := -2 + (suitCount shl 6) div 36;
        if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
          suitAdd := suitAdd - 4;
      end;
    end
    else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
             (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
              ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump]) then
      suitAdd := 60 + (suitCount shl 6) div 44
    else if (ctx.tpos_ptr^.length[partner_lh, ctx.trump] = 0) and
             (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
              (bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank])) then
      suitAdd := 60 + (suitCount shl 6) div 44
    else
    begin
      suitAdd := -2 + (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;

    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := -ctx.mply[k].rank + suitAdd;
  end
  else if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
  begin
    suitAdd := (suitCount shl 6) div 44;
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
  end
  else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
           (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) and
           (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
            ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump]) then
  begin
    suitAdd := (suitCount shl 6) div 44;
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
  end
  else
  begin
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
    begin
      if bit_map_rank[ctx.mply[k].rank] > ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump] then
      begin
        suitAdd := (suitCount shl 6) div 44;
        ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
      end
      else
      begin
        suitAdd := (suitCount shl 6) div 36;
        if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
          suitAdd := suitAdd - 4;
        ctx.mply[k].weight := 15 - ctx.mply[k].rank + suitAdd;
      end;
    end;
  end;
end;

procedure weight_alloc_nt_void2(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, suitCount, suitAdd, k: LongInt;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];
  suitCount := ctx.tpos_ptr^.length[ctx.curr_hand, ctx.suit];

  if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
  begin
    if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
       (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank]) then
      suitAdd := (suitCount shl 6) div 44
    else
    begin
      suitAdd := (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;
  end
  else if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
          (bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank]) then
    suitAdd := (suitCount shl 6) div 44
  else
  begin
    suitAdd := (suitCount shl 6) div 36;
    if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
      suitAdd := suitAdd - 4;
  end;

  for k := ctx.last_num_moves to ctx.num_moves - 1 do
    ctx.mply[k].weight := -ctx.mply[k].rank + suitAdd;
end;

procedure weight_alloc_combined_notvoid3(var ctx: HeuristicContext);
var
  max3rd, maxpd, min3rd, minpd, k, r_rank, top_number, mno: LongInt;
  ris: Word;
begin
  max3rd := highest_rank[ctx.tpos_ptr^.rank_in_suit[partner[ctx.lead_hand], ctx.lead_suit]];
  maxpd := highest_rank[ctx.tpos_ptr^.rank_in_suit[rho[ctx.lead_hand], ctx.lead_suit]];
  min3rd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[partner[ctx.lead_hand], ctx.lead_suit]];
  minpd := lowest_rank[ctx.tpos_ptr^.rank_in_suit[rho[ctx.lead_hand], ctx.lead_suit]];

  ris := ctx.tpos_ptr^.rank_in_suit[ctx.curr_hand, ctx.lead_suit];

  if ctx.high2 = 2 then
  begin
    if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) and (maxpd > ctx.move1_rank) and (maxpd > ctx.move2_rank) then
    begin
      for k := 0 to ctx.num_moves - 1 do
        ctx.mply[k].weight := -ctx.mply[k].rank;
    end
    else
    begin
      for k := 0 to ctx.num_moves - 1 do
      begin
        r_rank := rel_rank[ctx.tpos_ptr^.aggr[ctx.lead_suit], ctx.mply[k].rank];
        get_top_number(ctx, ris, ctx.move2_rank, top_number, mno);

        if top_number = k then
          ctx.mply[k].weight := 90 - ctx.mply[k].rank
        else if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) and (ctx.mply[k].rank > ctx.move1_rank) and (ctx.mply[k].rank > ctx.move2_rank) then
          ctx.mply[k].weight := 81 - ctx.mply[k].rank
        else if (min3rd > ctx.mply[k].rank) or (minpd > ctx.mply[k].rank) then
          ctx.mply[k].weight := -3 + r_rank
        else if (ctx.mply[k].rank < ctx.lead0_rank) or (ctx.mply[k].rank < ctx.move1_rank) or (ctx.mply[k].rank < ctx.move2_rank) then
          ctx.mply[k].weight := -11 + r_rank
        else if ctx.mply[k].sequence <> 0 then
          ctx.mply[k].weight := 10 + r_rank
        else
          ctx.mply[k].weight := 13 - ctx.mply[k].rank;
      end;
    end;
  end
  else if ctx.high2 = 1 then
  begin
    if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) and (maxpd > ctx.move1_rank) then
    begin
      for k := 0 to ctx.num_moves - 1 do
        ctx.mply[k].weight := -ctx.mply[k].rank;
    end
    else
    begin
      for k := 0 to ctx.num_moves - 1 do
      begin
        r_rank := rel_rank[ctx.tpos_ptr^.aggr[ctx.lead_suit], ctx.mply[k].rank];
        get_top_number(ctx, ris, ctx.move1_rank, top_number, mno);

        if top_number = k then
          ctx.mply[k].weight := 90 - ctx.mply[k].rank
        else if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) and (ctx.mply[k].rank > ctx.move1_rank) then
          ctx.mply[k].weight := 81 - ctx.mply[k].rank
        else if (min3rd > ctx.mply[k].rank) or (minpd > ctx.mply[k].rank) then
          ctx.mply[k].weight := -3 + r_rank
        else if (ctx.mply[k].rank < ctx.lead0_rank) or (ctx.mply[k].rank < ctx.move1_rank) then
          ctx.mply[k].weight := -11 + r_rank
        else if ctx.mply[k].sequence <> 0 then
          ctx.mply[k].weight := 10 + r_rank
        else
          ctx.mply[k].weight := 13 - ctx.mply[k].rank;
      end;
    end;
  end
  else if ctx.high2 = 0 then
  begin
    if (maxpd > ctx.lead0_rank) and (maxpd > max3rd) then
    begin
      for k := 0 to ctx.num_moves - 1 do
        ctx.mply[k].weight := -ctx.mply[k].rank;
    end
    else
    begin
      for k := 0 to ctx.num_moves - 1 do
      begin
        r_rank := rel_rank[ctx.tpos_ptr^.aggr[ctx.lead_suit], ctx.mply[k].rank];
        get_top_number(ctx, ris, ctx.lead0_rank, top_number, mno);

        if top_number = k then
          ctx.mply[k].weight := 90 - ctx.mply[k].rank
        else if (ctx.mply[k].rank > ctx.lead0_rank) and (ctx.mply[k].rank > max3rd) then
          ctx.mply[k].weight := 81 - ctx.mply[k].rank
        else if (min3rd > ctx.mply[k].rank) or (minpd > ctx.mply[k].rank) then
          ctx.mply[k].weight := -3 + r_rank
        else if ctx.mply[k].rank < ctx.lead0_rank then
          ctx.mply[k].weight := -11 + r_rank
        else if ctx.mply[k].sequence <> 0 then
          ctx.mply[k].weight := 10 + r_rank
        else
          ctx.mply[k].weight := 13 - ctx.mply[k].rank;
      end;
    end;
  end;
end;

procedure weight_alloc_trump_void3(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, suitCount, suitAdd, k: LongInt;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];
  suitCount := ctx.tpos_ptr^.length[ctx.curr_hand, ctx.suit];

  if ctx.lead_suit = ctx.trump then
  begin
    if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
       (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank] or bit_map_rank[ctx.move2_rank]) then
      suitAdd := (suitCount shl 6) div 44
    else
    begin
      suitAdd := (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;

    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := -ctx.mply[k].rank + suitAdd;
  end
  else if ctx.suit <> ctx.trump then
  begin
    if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
    begin
      if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
         (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank] or bit_map_rank[ctx.move2_rank]) then
        suitAdd := 60 + (suitCount shl 6) div 44
      else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
              (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) then
        suitAdd := 60 + (suitCount shl 6) div 44
      else
      begin
        suitAdd := -2 + (suitCount shl 6) div 36;
        if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
          suitAdd := suitAdd - 4;
      end;
    end
    else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
             (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
              ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump]) then
      suitAdd := 60 + (suitCount shl 6) div 44
    else if (ctx.tpos_ptr^.length[partner_lh, ctx.trump] = 0) and
             (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
              (bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank] or bit_map_rank[ctx.move2_rank])) then
      suitAdd := 60 + (suitCount shl 6) div 44
    else
    begin
      suitAdd := -2 + (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;

    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := -ctx.mply[k].rank + suitAdd;
  end
  else if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
  begin
    suitAdd := (suitCount shl 6) div 44;
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
  end
  else if (ctx.tpos_ptr^.length[rho_lh, ctx.lead_suit] = 0) and
           (ctx.tpos_ptr^.length[rho_lh, ctx.trump] <> 0) and
           (ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.trump] >
            ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump]) then
  begin
    suitAdd := (suitCount shl 6) div 44;
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
      ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
  end
  else
  begin
    for k := ctx.last_num_moves to ctx.num_moves - 1 do
    begin
      if bit_map_rank[ctx.mply[k].rank] > ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.trump] then
      begin
        suitAdd := (suitCount shl 6) div 44;
        ctx.mply[k].weight := 24 - ctx.mply[k].rank + suitAdd;
      end
      else
      begin
        suitAdd := (suitCount shl 6) div 36;
        if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
          suitAdd := suitAdd - 4;
        ctx.mply[k].weight := 15 - ctx.mply[k].rank + suitAdd;
      end;
    end;
  end;
end;

procedure weight_alloc_nt_void3(var ctx: HeuristicContext);
var
  partner_lh, rho_lh, suitCount, suitAdd, k: LongInt;
begin
  partner_lh := partner[ctx.lead_hand];
  rho_lh := rho[ctx.lead_hand];
  suitCount := ctx.tpos_ptr^.length[ctx.curr_hand, ctx.suit];

  if ctx.tpos_ptr^.length[partner_lh, ctx.lead_suit] <> 0 then
  begin
    if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
       (ctx.tpos_ptr^.rank_in_suit[partner_lh, ctx.lead_suit] or bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank] or bit_map_rank[ctx.move2_rank]) then
      suitAdd := (suitCount shl 6) div 44
    else
    begin
      suitAdd := (suitCount shl 6) div 36;
      if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
        suitAdd := suitAdd - 4;
    end;
  end
  else if ctx.tpos_ptr^.rank_in_suit[rho_lh, ctx.lead_suit] >
          (bit_map_rank[ctx.lead0_rank] or bit_map_rank[ctx.move1_rank] or bit_map_rank[ctx.move2_rank]) then
    suitAdd := (suitCount shl 6) div 44
  else
  begin
    suitAdd := (suitCount shl 6) div 36;
    if (suitCount = 2) and (ctx.tpos_ptr^.second_best[ctx.suit].hand = ctx.curr_hand) then
      suitAdd := suitAdd - 4;
  end;

  for k := ctx.last_num_moves to ctx.num_moves - 1 do
    ctx.mply[k].weight := -ctx.mply[k].rank + suitAdd;
end;

procedure call_heuristic(var context: HeuristicContext; weight_case: WeightCase);
begin
  case weight_case of
    WeightCase_Nt0:                      weight_alloc_nt0(context);
    WeightCase_Trump0:                   weight_alloc_trump0(context);
    WeightCase_NtNotVoid1:               weight_alloc_nt_notvoid1(context);
    WeightCase_TrumpNotVoid1:            weight_alloc_trump_notvoid1(context);
    WeightCase_NtVoid1:                  weight_alloc_nt_void1(context);
    WeightCase_TrumpVoid1:               weight_alloc_trump_void1(context);
    WeightCase_NtNotVoid2:               weight_alloc_nt_notvoid2(context);
    WeightCase_TrumpNotVoid2:            weight_alloc_trump_notvoid2(context);
    WeightCase_NtVoid2:                  weight_alloc_nt_void2(context);
    WeightCase_TrumpVoid2:               weight_alloc_trump_void2(context);
    WeightCase_CombinedNotVoid3,
    WeightCase_CombinedNotVoid3Trump:    weight_alloc_combined_notvoid3(context);
    WeightCase_NtVoid3:                  weight_alloc_nt_void3(context);
    WeightCase_TrumpVoid3:               weight_alloc_trump_void3(context);
    else
      weight_alloc_nt0(context);
  end;
end;

end.
