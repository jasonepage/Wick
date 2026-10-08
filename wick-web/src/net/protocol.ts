//
//  protocol.ts — the WS /match wire contract for the web client.
//
//  Single source of truth = the server. These types are RE-EXPORTED directly
//  from wick-api's own protocol/room modules (via the "@server/*" path alias in
//  tsconfig → ../wick-api/src). They're type-only, so nothing from the server's
//  runtime is bundled into the browser — but the web client and the server can
//  never drift out of sync on the frame shapes. This is the payoff of building
//  both in TypeScript.
//
//  (When we later extract a shared package, this file becomes that package's
//  entry point; for now the alias gives us the same guarantee with zero churn to
//  the deployed service.)
//

export type {
  ClientFrame,
  ServerFrame,
  QueueFrame,
  GuessFrame,
  QuestionFrame,
  AskFrame,
  HeartbeatFrame,
  PairedFrame,
  QueuedFrame,
  StateFrame,
  ResultFrame,
  ScoredFrame,
  AnswerFrame,
  OpponentLeftFrame,
  ErrorFrame,
} from "@server/protocol";

export type {
  MatchMode,
  OpponentKind,
  MatchResult,
  StateSnapshot,
  PlayerResult,
} from "@server/room";
