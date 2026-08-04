unit DDS_Types;

{$mode objfpc}{$H+}

interface

const
  MAXNOOFBOARDS = 200;
  MAXNOOFTABLES = 40;
  SIMILARMAXWINNODES = 700000;
  SIMILARDEALLIMIT = 10;
  DDS_STRAINS = 5;
  DDS_HANDS = 4;
  DDS_SUITS = 4;
  DDS_NOTRUMP = 4;

  MAXNODE = 1;
  MINNODE = 0;

  // Error codes
  RETURN_NO_FAULT = 1;
  RETURN_UNKNOWN_FAULT = -1;
  RETURN_ZERO_CARDS = -2;
  RETURN_TARGET_TOO_HIGH = -3;
  RETURN_DUPLICATE_CARDS = -4;
  RETURN_TARGET_WRONG_LO = -5;
  RETURN_TARGET_WRONG_HI = -7;
  RETURN_SOLNS_WRONG_LO = -8;
  RETURN_SOLNS_WRONG_HI = -9;
  RETURN_TOO_MANY_CARDS = -10;
  RETURN_SUIT_OR_RANK = -12;
  RETURN_PLAYED_CARD = -13;
  RETURN_CARD_COUNT = -14;
  RETURN_THREAD_INDEX = -15;
  RETURN_MODE_WRONG_LO = -16;
  RETURN_MODE_WRONG_HI = -17;
  RETURN_TRUMP_WRONG = -18;
  RETURN_FIRST_WRONG = -19;
  RETURN_PLAY_FAULT = -98;
  RETURN_PBN_FAULT = -99;
  RETURN_TOO_MANY_BOARDS = -101;
  RETURN_THREAD_CREATE = -102;
  RETURN_THREAD_WAIT = -103;
  RETURN_THREAD_MISSING = -104;
  RETURN_NO_SUIT = -201;
  RETURN_TOO_MANY_TABLES = -202;
  RETURN_CHUNK_SIZE = -301;

const
  lho: array[0..DDS_HANDS - 1] of LongInt = (1, 2, 3, 0);
  rho: array[0..DDS_HANDS - 1] of LongInt = (3, 0, 1, 2);
  partner: array[0..DDS_HANDS - 1] of LongInt = (2, 3, 0, 1);

  bit_map_rank: array[0..15] of Word = (
    $0000, $0000, $0001, $0002, $0004, $0008, $0010, $0020,
    $0040, $0080, $0100, $0200, $0400, $0800, $1000, $2000
  );

  card_rank: array[0..15] of AnsiChar = (
    'x', 'x', '2', '3', '4', '5', '6', '7',
    '8', '9', 'T', 'J', 'Q', 'K', 'A', '-'
  );

  card_suit: array[0..DDS_STRAINS - 1] of AnsiChar = ('S', 'H', 'D', 'C', 'N');
  card_hand: array[0..DDS_HANDS - 1] of AnsiChar = ('N', 'E', 'S', 'W');

type
  ResetReason = (
    ResetReason_Unknown = 0,
    ResetReason_TooManyNodes = 1,
    ResetReason_NewDeal = 2,
    ResetReason_NewTrump = 3,
    ResetReason_MemoryExhausted = 4,
    ResetReason_FreeMemory = 5,
    ResetReason_Count = 6
  );

  THandLookup = array[0..DDS_SUITS - 1, 0..14] of LongInt;

  MoveGroupType = packed record
    last_group_: LongInt;
    rank_: array[0..6] of LongInt;
    sequence_: array[0..6] of LongInt;
    fullseq_: array[0..6] of LongInt;
    gap_: array[0..6] of LongInt;
  end;
  PMoveGroupType = ^MoveGroupType;

type
  MoveType = packed record
    suit: LongInt;      // 0-3
    rank: LongInt;      // 2-14
    sequence: LongInt;
    weight: LongInt;
  end;
  PMoveType = ^MoveType;

  MovePlyType = packed record
    move: array[0..13] of MoveType;
    current: LongInt;
    last: LongInt;
  end;
  PMovePlyType = ^MovePlyType;

  HighCardType = packed record
    rank: LongInt;
    hand: LongInt;
  end;

  Pos = packed record
    rank_in_suit: array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of Word;
    aggr: array[0..DDS_SUITS - 1] of Word;
    length: array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of Byte;
    hand_dist: array[0..DDS_HANDS - 1] of LongInt;
    win_ranks: array[0..49, 0..DDS_SUITS - 1] of Word;
    first: array[0..49] of LongInt;
    move: array[0..49] of MoveType;
    hand_rel_first: LongInt;
    tricks_max: LongInt;
    winner: array[0..DDS_SUITS - 1] of HighCardType;
    second_best: array[0..DDS_SUITS - 1] of HighCardType;
  end;
  PPos = ^Pos;

  TrickDataType = packed record
    play_count: array[0..DDS_SUITS - 1] of LongInt;
    best_rank: LongInt;
    best_suit: LongInt;
    best_sequence: LongInt;
    rel_winner: LongInt;
    next_lead_hand: LongInt;
  end;

  EvalType = packed record
    tricks: LongInt;
    win_ranks: array[0..DDS_SUITS - 1] of Word;
  end;

  Card = packed record
    suit: LongInt;
    rank: LongInt;
  end;

  ExtCard = packed record
    suit: LongInt;
    rank: LongInt;
    sequence: LongInt;
  end;

  FutureTricks = packed record
    nodes: LongInt;
    cards: LongInt;
    suit: array[0..12] of LongInt;
    rank: array[0..12] of LongInt;
    equals: array[0..12] of LongInt;
    score: array[0..12] of LongInt;
  end;
  PFutureTricks = ^FutureTricks;

  Deal = packed record
    trump: LongInt;
    first: LongInt;
    currentTrickSuit: array[0..2] of LongInt;
    currentTrickRank: array[0..2] of LongInt;
    remainCards: array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of Cardinal;
  end;
  PDeal = ^Deal;

  DealPBN = packed record
    trump: LongInt;
    first: LongInt;
    currentTrickSuit: array[0..2] of LongInt;
    currentTrickRank: array[0..2] of LongInt;
    remainCards: array[0..79] of AnsiChar;
  end;

  Boards = packed record
    no_of_boards: LongInt;
    deals: array[0..MAXNOOFBOARDS - 1] of Deal;
    target: array[0..MAXNOOFBOARDS - 1] of LongInt;
    solutions: array[0..MAXNOOFBOARDS - 1] of LongInt;
    mode: array[0..MAXNOOFBOARDS - 1] of LongInt;
  end;
  PBoards = ^Boards;

  BoardsPBN = packed record
    no_of_boards: LongInt;
    deals: array[0..MAXNOOFBOARDS - 1] of DealPBN;
    target: array[0..MAXNOOFBOARDS - 1] of LongInt;
    solutions: array[0..MAXNOOFBOARDS - 1] of LongInt;
    mode: array[0..MAXNOOFBOARDS - 1] of LongInt;
  end;
  PBoardsPBN = ^BoardsPBN;

  SolvedBoards = packed record
    no_of_boards: LongInt;
    solved_board: array[0..MAXNOOFBOARDS - 1] of FutureTricks;
  end;
  PSolvedBoards = ^SolvedBoards;

  DdTableDeal = packed record
    cards: array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of Cardinal;
  end;

  DdTableDeals = packed record
    no_of_tables: LongInt;
    deals: array[0..MAXNOOFTABLES * DDS_STRAINS - 1] of DdTableDeal;
  end;
  PDdTableDeals = ^DdTableDeals;

  DdTableDealPBN = packed record
    cards: array[0..79] of AnsiChar;
  end;

  DdTableDealsPBN = packed record
    no_of_tables: LongInt;
    deals: array[0..MAXNOOFTABLES * DDS_STRAINS - 1] of DdTableDealPBN;
  end;
  PDdTableDealsPBN = ^DdTableDealsPBN;

  DdTableResults = packed record
    res_table: array[0..DDS_STRAINS - 1, 0..DDS_HANDS - 1] of LongInt;
  end;
  PDdTableResults = ^DdTableResults;

  DdTablesRes = packed record
    no_of_boards: LongInt;
    results: array[0..MAXNOOFTABLES * DDS_STRAINS - 1] of DdTableResults;
  end;
  PDdTablesRes = ^DdTablesRes;

  ParResults = packed record
    par_score: array[0..1, 0..15] of AnsiChar;
    par_contracts_string: array[0..1, 0..127] of AnsiChar;
  end;
  PParResults = ^ParResults;

  AllParResults = packed record
    par_results: array[0..MAXNOOFTABLES - 1] of ParResults;
  end;
  PAllParResults = ^AllParResults;

  TTrumpFilter = array[0..DDS_STRAINS - 1] of LongInt;
  PTrumpFilter = ^TTrumpFilter;

  TBobParScore = packed record
    AScore: array[0..15] of AnsiChar;
  end;

  TBobParContract = packed record
    aContract: array[0..127] of AnsiChar;
  end;

  TBobParResults = packed record
    parScore: array[0..1] of TBobParScore;
    ParStr: array[0..1] of TBobParContract;
  end;

  TBobAllParResults = array[0..MAXNOOFTABLES - 1] of TBobParResults;
  PBobAllParResults = ^TBobAllParResults;


  ParResultsDealer = packed record
    number: LongInt;
    score: LongInt;
    contracts: array[0..9, 0..9] of AnsiChar;
  end;
  PParResultsDealer = ^ParResultsDealer;

  ContractType = packed record
    under_tricks: LongInt;
    over_tricks: LongInt;
    level: LongInt;
    denom: LongInt;
    seats: LongInt;
  end;

  ParResultsMaster = packed record
    score: LongInt;
    number: LongInt;
    contracts: array[0..9] of ContractType;
  end;
  PParResultsMaster = ^ParResultsMaster;

  ParTextResults = packed record
    par_text: array[0..1, 0..127] of AnsiChar;
    equal: Boolean;
  end;
  PParTextResults = ^ParTextResults;

  PlayTraceBin = packed record
    number: LongInt;
    suit: array[0..51] of LongInt;
    rank: array[0..51] of LongInt;
  end;

  PlayTracePBN = packed record
    number: LongInt;
    cards: array[0..105] of AnsiChar;
  end;

  SolvedPlay = packed record
    number: LongInt;
    tricks: array[0..52] of LongInt;
  end;
  PSolvedPlay = ^SolvedPlay;

  PlayTracesBin = packed record
    no_of_boards: LongInt;
    plays: array[0..MAXNOOFBOARDS - 1] of PlayTraceBin;
  end;

  PlayTracesPBN = packed record
    no_of_boards: LongInt;
    plays: array[0..MAXNOOFBOARDS - 1] of PlayTracePBN;
  end;

  SolvedPlays = packed record
    no_of_boards: LongInt;
    solved: array[0..MAXNOOFBOARDS - 1] of SolvedPlay;
  end;
  PSolvedPlays = ^SolvedPlays;

  NodeCards = packed record
    upper_bound: ShortInt;
    lower_bound: ShortInt;
    best_move_suit: ShortInt;
    best_move_rank: ShortInt;
    least_win: array[0..DDS_SUITS - 1] of ShortInt;
  end;
  PNodeCards = ^NodeCards;
  PPNodeCards = ^PNodeCards;

  AbsRankType = packed record
    rank: ShortInt;
    hand: ShortInt;
  end;

  RelRanksType = packed record
    abs_rank: array[0..14, 0..DDS_SUITS - 1] of AbsRankType;
  end;
  PRelRanksType = ^RelRanksType;

  WinnerEntryType = packed record
    suit: LongInt;
    winnerRank: LongInt;
    winnerHand: LongInt;
    secondRank: LongInt;
    secondHand: LongInt;
  end;

  WinnersType = packed record
    number: LongInt;
    winner: array[0..3] of WinnerEntryType;
  end;

  ThreadData = packed record
    nodeTypeStore: array[0..DDS_HANDS - 1] of LongInt;
    iniDepth: LongInt;
    val: Boolean;
    suit: array[0..DDS_HANDS - 1, 0..DDS_SUITS - 1] of Word;
    trump: LongInt;
    lookAheadPos: Pos;
    analysisFlag: Boolean;
    lowestWin: array[0..49, 0..DDS_SUITS - 1] of Word;
    winners: array[0..12] of WinnersType;
    forbiddenMoves: array[0..13] of MoveType;
    bestMove: array[0..49] of MoveType;
    bestMoveTT: array[0..49] of MoveType;
    memUsed: Double;
    nodes: LongInt;
    trickNodes: LongInt;
    rel: array[0..8191] of RelRanksType;
  end;
  PThreadData = ^ThreadData;

implementation

end.
