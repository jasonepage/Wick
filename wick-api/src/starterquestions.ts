// SPDX-License-Identifier: MPL-2.0
//
//  starterquestions.ts: the English text of the 45 suggested questions (3.7).
//
//  Both apps send the English text of a suggested question to the Keeper,
//  whatever language they show it in (wick-web/src/game/starters.ts and
//  Hunch/Engine/StarterQuestions.swift). The daily warm-up (keeperwarm.ts)
//  asks all of them about the daily word, so a tapped suggestion is answered
//  straight from the saved answers. starterquestions.test.ts fails if this
//  list drifts from the web bank.
//

export const STARTER_QUESTIONS: readonly string[] = [
  "Is it a physical object you can touch?",
  "Is it an abstract idea?",
  "Is it an emotion or feeling?",
  "Is it something you do?",
  "Is it alive?",
  "Was it ever alive?",
  "Is it an animal?",
  "Is it a plant?",
  "Is it man-made?",
  "Does it occur naturally?",
  "Is it bigger than a car?",
  "Could it fit in your hand?",
  "Is it smaller than a shoe?",
  "Is it usually found indoors?",
  "Is it found outdoors in nature?",
  "Would you find it in a kitchen?",
  "Is it found in or near water?",
  "Is it a tool or device?",
  "Is it used for transportation?",
  "Is it used for communication?",
  "Is it used for entertainment?",
  "Can you eat or drink it?",
  "Can you wear it?",
  "Can you hold it in your hands?",
  "Is it typically made of metal?",
  "Is it usually made of wood?",
  "Is it soft to the touch?",
  "Does it make a sound?",
  "Does it have a noticeable smell?",
  "Is it usually a specific color?",
  "Does it give off light?",
  "Can it move on its own?",
  "Does it have moving parts?",
  "Is it a liquid?",
  "Is it usually hot?",
  "Is it usually cold?",
  "Is it a kind of food?",
  "Is it related to technology?",
  "Is it related to a job or profession?",
  "Is it associated with a particular season?",
  "Has it existed for hundreds of years?",
  "Is it a modern invention?",
  "Is it a place?",
  "Is it a part of the body?",
  "Is it something found in nature?",
];
