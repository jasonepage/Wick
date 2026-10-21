# Wick Privacy Policy

_Last updated: October 2026_

Wick is built to be private by design. There are no accounts, no logins, no
advertising, and no cross-app tracking. The only things we count are a handful
of anonymous play events and, since version 3.6, anonymous weekly word counts,
both described below.

## iOS single-player (Daily and Practice): on your device

- Your guesses, stats, and streaks are stored **only on your device**. Your
  questions are kept on your device too, and are also sent to be answered
  (see below).
- Closeness ("warmth") scoring uses word models that run on your device:
  Apple's built-in Natural Language model for English, and models bundled
  with the app for Spanish, French, Italian and German.
- **Since version 3.7, questions you ask the Keeper are answered by Wick's
  server**, the same way as on the web. The app sends the question, the secret
  word, the round's language, and your earlier questions and answers in that
  round, with no id of any kind. To answer, the server may pass that text to
  **Google's Gemini API**. The server saves the answer to a question about a
  word, but not who asked it, so the same question gets the same answer for
  everyone. If the server can't be reached, Apple Intelligence (Foundation
  Models) answers on your device instead, when your iPhone has it.
- Your guesses are never sent to any third party. Since version 3.6, some of
  them may be sent to Wick's own server for the weekly word counts described
  below, unless you turn that off in Settings.

## The web game at guesswick.com

A web browser has no word model of its own, so the web game scores every
round on Wick's server, including the daily puzzle and practice:

- Each **word you guess and question you ask** is sent to Wick's server to be
  scored or answered. To do that, the server may pass the text to **Google's
  Gemini API**. It is used only to play the round and, as anonymous counts,
  for the weekly word counts below. It is not linked to your identity, not
  stored in a profile, and not sold.
- Since version 3.7, the server saves the answer to a question about a word,
  but not who asked it, so the same question gets the same answer for
  everyone. Your earlier questions and answers in the round are sent along
  with each new question so the Keeper stays consistent.
- Your stats and streaks on the web are saved **only in your browser**.

## Live Race

Live multiplayer needs a server to pair players and score fairly, so when you
play a live Race, on iOS or on the web:

- The **words and questions you type** are sent to Wick's server to be scored
  (warmth) and answered (the Keeper).
- To compute warmth and answers, the server passes that text to **Google's
  Gemini API**. It is used solely to score the round; it is not used to train
  models on your identity, and it is not sold.
- A **random, per-install identifier** (not tied to your name, email, Apple ID,
  or contacts) is used only to route your match. No account is created.
- Your guesses are **not linked to your identity** and are **never used for
  tracking or advertising**.
- The server keeps only what a live match needs while it is in progress; it does
  not build a profile of you.
- When you wait in the Quick Match queue, the server may send the developer a
  phone notification that says someone is waiting and in which language, so he
  can come race you. It contains nothing else about you.

On iOS, if you never play a live mode and turn off "Add my words to weekly
stats" in Settings, no guess you type ever leaves your device. Questions you
ask the Keeper are sent to be answered (see above), and the anonymous play
counts below are sent too.

## Play counts (since version 3.3)

To know whether the game is working, the app and the website send a few
anonymous events: that a daily puzzle was started, solved, or given up (with
the puzzle number and how many guesses it took), and that a share or race link
was used. Each event carries a random per-install id so we can count players;
the server hashes that id before storing it, and it is not tied to your name,
email, Apple ID, or contacts. No word, question, or anything you type is ever
included. These counts are used only to improve the game and are not shared
or sold. (The weekly word counts in the next section are separate and carry
no id at all.)

## Weekly word counts (since version 3.6)

The Stats page shows "Top guesses this week" and "Most asked questions" across
all players. To build those lists:

- **On iOS**, while "Add my words to weekly stats" is on in Settings (it is on
  unless you turn it off), the app sends Wick's server a guessed word that
  read Cool or colder, or a question you typed to the Keeper. Each one is sent
  with its language and the time, and nothing else: no id, no account, no
  device identifier. Guesses that were close to the answer, the answer
  itself, questions that name the answer, and starter questions you tap are
  never sent.
- **On the web and in live Races**, the words and questions already reach the
  server to be scored (see above). The server counts the same kinds of words
  and questions from there.
- The server keeps **counts only**: the word or question and how many times it
  came up this week. It does not store who sent it. To stop one person from
  filling a list, the server briefly remembers a scrambled, one-way code for
  each sender in memory only; it is never written to disk and is thrown away
  every week.
- A question is shown only after at least three different players have asked
  it, and questions with numbers, links, email addresses, or crude words are
  dropped. The lists reset every Monday (UTC).

## Today's race board (since version 3.6)

Nothing goes on the board unless you choose to. After you finish the daily
puzzle, you can tap Submit. Only then does the app or the website send Wick's
server the puzzle number, how many guesses and hints you used, how long you played,
and the language, with the random per-install id used for live races. The
server keeps a scrambled, one-way version of that id (so you get one spot a
day), never the id itself. You show up on the board under an auto name like
"Violet Otter", picked from a word list, and you can roll a new one. Nothing
you typed is sent. Board entries are kept for about a week and then deleted.

## Solve Replay videos (since version 3.4)

"Share replay" turns a finished round into a short video. The video is made
entirely on your device or in your browser, and nothing is uploaded. It shows
your guesses with their ranks and heat colors, and the questions you asked.
On a daily puzzle the answer and your closest guesses are hidden, so posting
it does not spoil the day; a practice replay shows everything, including the
answer. On iOS the video is saved to your Photos only when you tap "Save to
Photos", and Wick asks for add-only access, so it can save the video but can
never see your photo library. You choose where to post it.

## Your data

If you delete the app, all of its on-device data is removed with it. Clearing
your browser's site data does the same for the web game. Because we hold no
account and no persistent profile, there is no stored personal data to
request, export, or delete from us.

**Questions?** Contact: support@guesswick.com
