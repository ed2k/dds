/*
   WebAssembly Embind bindings for DDS C++ Library API.
   Exposes DDS double-dummy solver capabilities to JavaScript in web browsers.

   Copyright (C) 2006-2026 Bo Haglund, Soren Hein, Adam Wildavsky
   Use of this source code is governed by the MIT license.
*/

#include <algorithm>
#include <array>
#include <cstring>
#include <string>
#include <vector>

#include <emscripten/bind.h>
#include <emscripten/val.h>

#include <api/calc_dd_table.hpp>
#include <api/calc_par.hpp>
#include <api/dds.h>
#include <api/solve_board.hpp>
#include <pbn.hpp>
#include <solver_context/solver_context.hpp>

namespace {

auto throw_on_dds_error(int code) -> void {
  if (code == RETURN_NO_FAULT) {
    return;
  }
  std::array<char, 80> message{};
  ErrorMessage(code, message.data());
  std::string error_text =
      "DDS error " + std::to_string(code) + ": " + std::string(message.data());
  emscripten::val::global("Error").new_(error_text).throw_();
}

auto js_array_to_int_vector(const emscripten::val& js_arr, size_t expected_size)
    -> std::vector<int> {
  std::vector<int> result(expected_size, 0);
  if (js_arr.isNull() || js_arr.isUndefined()) {
    return result;
  }
  const unsigned len = js_arr["length"].as<unsigned>();
  for (unsigned i = 0; i < len && i < expected_size; ++i) {
    result[i] = js_arr[i].as<int>();
  }
  return result;
}

auto future_tricks_to_js_val(const FutureTricks& fut) -> emscripten::val {
  emscripten::val obj = emscripten::val::object();
  obj.set("nodes", fut.nodes);
  obj.set("cards", fut.cards);

  emscripten::val suit_arr = emscripten::val::array();
  emscripten::val rank_arr = emscripten::val::array();
  emscripten::val equals_arr = emscripten::val::array();
  emscripten::val score_arr = emscripten::val::array();

  for (int i = 0; i < fut.cards; ++i) {
    suit_arr.call<void>("push", fut.suit[i]);
    rank_arr.call<void>("push", fut.rank[i]);
    equals_arr.call<void>("push", fut.equals[i]);
    score_arr.call<void>("push", fut.score[i]);
  }

  obj.set("suit", suit_arr);
  obj.set("rank", rank_arr);
  obj.set("equals", equals_arr);
  obj.set("score", score_arr);
  return obj;
}

auto dd_table_results_to_js_val(const DdTableResults& table) -> emscripten::val {
  emscripten::val obj = emscripten::val::object();
  emscripten::val res_table = emscripten::val::array();

  for (int strain = 0; strain < DDS_STRAINS; ++strain) {
    emscripten::val strain_arr = emscripten::val::array();
    for (int hand = 0; hand < DDS_HANDS; ++hand) {
      strain_arr.call<void>("push", table.res_table[strain][hand]);
    }
    res_table.call<void>("push", strain_arr);
  }

  obj.set("resTable", res_table);
  return obj;
}

auto solved_play_to_js_val(const SolvedPlay& solved) -> emscripten::val {
  emscripten::val obj = emscripten::val::object();
  obj.set("number", solved.number);

  emscripten::val tricks_arr = emscripten::val::array();
  for (int i = 0; i < solved.number; ++i) {
    tricks_arr.call<void>("push", solved.tricks[i]);
  }

  obj.set("tricks", tricks_arr);
  return obj;
}

}  // namespace

auto solveBoardPBN(
    const std::string& remain_cards,
    int trump,
    int first,
    emscripten::val current_trick_suit,
    emscripten::val current_trick_rank,
    int target,
    int solutions,
    int mode,
    SolverContext* context_ptr) -> emscripten::val {
  DealPBN native_deal{};
  native_deal.trump = trump;
  native_deal.first = first;

  const auto trick_suit = js_array_to_int_vector(current_trick_suit, 3);
  const auto trick_rank = js_array_to_int_vector(current_trick_rank, 3);

  for (int i = 0; i < 3; ++i) {
    native_deal.currentTrickSuit[i] = trick_suit[i];
    native_deal.currentTrickRank[i] = trick_rank[i];
  }

  std::memset(native_deal.remainCards, 0, sizeof(native_deal.remainCards));
  const size_t copy_size = std::min(remain_cards.size(), sizeof(native_deal.remainCards) - 1U);
  std::memcpy(native_deal.remainCards, remain_cards.c_str(), copy_size);

  FutureTricks fut{};

  int code = RETURN_NO_FAULT;
  if (context_ptr == nullptr) {
    code = SolveBoardPBN(native_deal, target, solutions, mode, &fut, 0);
  } else {
    Deal binary_deal{};
    if (convert_from_pbn(native_deal.remainCards, binary_deal.remainCards) != RETURN_NO_FAULT) {
      code = RETURN_PBN_FAULT;
    } else {
      for (int k = 0; k < 3; ++k) {
        binary_deal.currentTrickRank[k] = native_deal.currentTrickRank[k];
        binary_deal.currentTrickSuit[k] = native_deal.currentTrickSuit[k];
      }
      binary_deal.first = native_deal.first;
      binary_deal.trump = native_deal.trump;
      code = solve_board(*context_ptr, binary_deal, target, solutions, mode, &fut);
    }
  }

  throw_on_dds_error(code);
  return future_tricks_to_js_val(fut);
}

auto calcDDTablePBN(const std::string& remain_cards, SolverContext* context_ptr)
    -> emscripten::val {
  DdTableDealPBN deal_pbn{};
  std::memset(deal_pbn.cards, 0, sizeof(deal_pbn.cards));
  const size_t copy_size = std::min(remain_cards.size(), sizeof(deal_pbn.cards) - 1U);
  std::memcpy(deal_pbn.cards, remain_cards.c_str(), copy_size);

  DdTableResults table{};

  int code = RETURN_NO_FAULT;
  if (context_ptr == nullptr) {
    code = CalcDDtablePBN(deal_pbn, &table);
  } else {
    code = calc_dd_table_pbn(*context_ptr, deal_pbn, &table);
  }

  throw_on_dds_error(code);
  return dd_table_results_to_js_val(table);
}

auto analysePlayPBN(
    const std::string& remain_cards,
    int trump,
    int first,
    const std::string& play_pbn_str,
    SolverContext* context_ptr) -> emscripten::val {
  DealPBN deal_pbn{};
  deal_pbn.trump = trump;
  deal_pbn.first = first;
  std::memset(deal_pbn.remainCards, 0, sizeof(deal_pbn.remainCards));
  const size_t copy_size = std::min(remain_cards.size(), sizeof(deal_pbn.remainCards) - 1U);
  std::memcpy(deal_pbn.remainCards, remain_cards.c_str(), copy_size);

  PlayTracePBN play_pbn{};
  std::memset(play_pbn.cards, 0, sizeof(play_pbn.cards));
  const size_t play_copy = std::min(play_pbn_str.size(), sizeof(play_pbn.cards) - 1U);
  std::memcpy(play_pbn.cards, play_pbn_str.c_str(), play_copy);
  play_pbn.number = static_cast<int>(play_copy > 0 ? (play_copy + 1) / 3 : 0);

  SolvedPlay solved{};
  int code = AnalysePlayPBN(deal_pbn, play_pbn, &solved, 0);
  throw_on_dds_error(code);

  return solved_play_to_js_val(solved);
}

auto calcParPBN(const std::string& remain_cards, int vulnerable) -> emscripten::val {
  DdTableDealPBN deal_pbn{};
  std::memset(deal_pbn.cards, 0, sizeof(deal_pbn.cards));
  const size_t copy_size = std::min(remain_cards.size(), sizeof(deal_pbn.cards) - 1U);
  std::memcpy(deal_pbn.cards, remain_cards.c_str(), copy_size);

  DdTableResults table{};
  ParResults par{};
  int code = CalcParPBN(deal_pbn, &table, vulnerable, &par);
  throw_on_dds_error(code);

  emscripten::val obj = emscripten::val::object();
  emscripten::val scores = emscripten::val::array();
  emscripten::val contracts = emscripten::val::array();

  scores.call<void>("push", std::string(par.par_score[0]));
  scores.call<void>("push", std::string(par.par_score[1]));

  contracts.call<void>("push", std::string(par.par_contracts_string[0]));
  contracts.call<void>("push", std::string(par.par_contracts_string[1]));

  obj.set("parScore", scores);
  obj.set("parContracts", contracts);
  return obj;
}

EMSCRIPTEN_BINDINGS(dds_wasm_api) {
  emscripten::class_<SolverContext>("SolverContext")
      .constructor<>()
      .function("resetForSolve", &SolverContext::reset_for_solve);

  emscripten::function("solveBoardPBN", &solveBoardPBN, emscripten::allow_raw_pointers());
  emscripten::function("calcDDTablePBN", &calcDDTablePBN, emscripten::allow_raw_pointers());
  emscripten::function("analysePlayPBN", &analysePlayPBN, emscripten::allow_raw_pointers());
  emscripten::function("calcParPBN", &calcParPBN);
}
