unit DDS_Init;

{$mode objfpc}{$H+}

interface

uses
  DDS_Types;

var
  highest_rank: array[0..8191] of LongInt;
  lowest_rank: array[0..8191] of LongInt;
  count_table: array[0..8191] of LongInt;
  rel_rank: array[0..8191, 0..14] of ShortInt;
  win_ranks: array[0..8191, 0..13] of Word;
  group_data: array[0..8191] of MoveGroupType;

implementation

procedure init_lookup_tables;
const
  topside: array[0..14] of LongInt = (
    $0000, $0000, $0000, $0001,
    $0003, $0007, $000f, $001f,
    $003f, $007f, $00ff, $01ff,
    $03ff, $07ff, $0fff
  );

  botside: array[0..14] of LongInt = (
    $ffff, $ffff, $1ffe, $1ffc,
    $1ff8, $1ff0, $1fe0, $1fc0,
    $1f80, $1f00, $1e00, $1c00,
    $1800, $1000, $0000
  );
var
  aggregate, rank, least_win, ordinal, resultVal, next_bit_position: LongInt;
  topBitRank, nextBitRank, topBitNo, ris, g: LongInt;
begin
  highest_rank[0] := 0;
  lowest_rank[0] := 0;
  for aggregate := 1 to 8191 do
  begin
    highest_rank[aggregate] := 0;
    for rank := 14 downto 2 do
    begin
      if (aggregate and bit_map_rank[rank]) <> 0 then
      begin
        highest_rank[aggregate] := rank;
        break;
      end;
    end;
    lowest_rank[aggregate] := 0;
    for rank := 2 to 14 do
    begin
      if (aggregate and bit_map_rank[rank]) <> 0 then
      begin
        lowest_rank[aggregate] := rank;
        break;
      end;
    end;
  end;

  for aggregate := 0 to 8191 do
  begin
    count_table[aggregate] := 0;
    for rank := 0 to 12 do
    begin
      if (aggregate and (1 shl rank)) <> 0 then
      begin
        Inc(count_table[aggregate]);
      end;
    end;
  end;

  FillChar(rel_rank, SizeOf(rel_rank), 0);
  for aggregate := 1 to 8191 do
  begin
    ordinal := 0;
    for rank := 14 downto 2 do
    begin
      if (aggregate and bit_map_rank[rank]) <> 0 then
      begin
        Inc(ordinal);
        rel_rank[aggregate, rank] := ordinal;
      end;
    end;
  end;

  for aggregate := 0 to 8191 do
  begin
    win_ranks[aggregate, 0] := 0;
    for least_win := 1 to 13 do
    begin
      resultVal := 0;
      next_bit_position := 1;
      for rank := 14 downto 2 do
      begin
        if (aggregate and bit_map_rank[rank]) <> 0 then
        begin
          if next_bit_position <= least_win then
          begin
            resultVal := resultVal or bit_map_rank[rank];
            Inc(next_bit_position);
          end
          else
            break;
        end;
      end;
      win_ranks[aggregate, least_win] := resultVal;
    end;
  end;

  FillChar(group_data, SizeOf(group_data), 0);
  group_data[0].last_group_ := -1;

  group_data[1].last_group_ := 0;
  group_data[1].rank_[0] := 2;
  group_data[1].sequence_[0] := 0;
  group_data[1].fullseq_[0] := 1;
  group_data[1].gap_[0] := 0;

  topBitRank := 1;
  nextBitRank := 0;
  topBitNo := 2;

  for ris := 2 to 8191 do
  begin
    if ris >= (topBitRank shl 1) then
    begin
      nextBitRank := topBitRank;
      topBitRank := topBitRank shl 1;
      Inc(topBitNo);
    end;

    group_data[ris] := group_data[ris xor topBitRank];

    if (ris and nextBitRank) <> 0 then
    begin
      g := group_data[ris].last_group_;
      Inc(group_data[ris].rank_[g]);
      group_data[ris].sequence_[g] := group_data[ris].sequence_[g] or nextBitRank;
      group_data[ris].fullseq_[g] := group_data[ris].fullseq_[g] or topBitRank;
    end
    else
    begin
      g := group_data[ris].last_group_ + 1;
      group_data[ris].last_group_ := g;
      group_data[ris].rank_[g] := topBitNo;
      group_data[ris].sequence_[g] := 0;
      group_data[ris].fullseq_[g] := topBitRank;
      if g > 0 then
        group_data[ris].gap_[g] := topside[topBitNo] and botside[group_data[ris].rank_[g - 1]]
      else
        group_data[ris].gap_[g] := topside[topBitNo] and botside[0];
    end;
  end;
end;

initialization
  init_lookup_tables;

end.
