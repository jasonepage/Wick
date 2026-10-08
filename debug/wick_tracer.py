#!/usr/bin/env python3
"""
Wick deterministic-verdict tracer.

Faithful Python port of the ground-truth path in QuestionService.answer():
  1) leak check (skipped here - not the target)
  2) OfflineKeeper.property(question)  -> StarterProperty
  3) WordAttributes.deterministicVerdict(word, category, property) -> Yes/No/Sort of/None

If step 2 or 3 returns None, the real app falls through to the Foundation Models
LLM (which we cannot run here) -- the tracer reports that as "LLM-FALLBACK".

Purpose: for tagged daily words the deterministic path answers FIRST, identical
on every device. So this tracer tells us EXACTLY what Wick says for those cases,
letting us find + fix wrong verdicts without a device.
"""

# ---------------------------------------------------------------------------
# Word data — SINGLE SOURCE OF TRUTH. Loaded from Hunch/Engine/WordData.json,
# the same file WordAttributes.swift decodes at launch. Do NOT hardcode word
# lists here; edit WordData.json and both Swift and this tracer pick it up.
# ---------------------------------------------------------------------------
import json as _json, os as _os
_DATA = _json.load(open(_os.path.join(_os.path.dirname(__file__), "..", "Hunch", "Engine", "WordData.json"), encoding="utf-8"))
CATEGORIES = dict(_DATA["categories"])
_SETS = {k: set(v) for k, v in _DATA["sets"].items()}
_ALIAS = {'vehicles': 'VEHICLES', 'techObjects': 'TECH_OBJECTS', 'woodenObjects': 'WOODEN_OBJECTS', 'ambiguousWoodObjects': 'AMBIG_WOOD', 'modernObjects': 'MODERN_OBJECTS', 'soundMakingObjects': 'SOUND_OBJECTS', 'silentAnimals': 'SILENT_ANIMALS', 'smallAnimals': 'SMALL_ANIMALS', 'bigAnimals': 'BIG_ANIMALS', 'indoorAnimals': 'INDOOR_ANIMALS', 'smallObjects': 'SMALL_OBJECTS', 'bigObjects': 'BIG_OBJECTS', 'smallBodyParts': 'SMALL_BODYPARTS', 'bigBodyParts': 'BIG_BODYPARTS', 'wearableObjects': 'WEARABLE_OBJECTS', 'metalSubstances': 'METAL_SUBSTANCES', 'rideableAnimals': 'RIDEABLE_ANIMALS', 'lightGivers': 'LIGHT_GIVERS', 'produceFoods': 'PRODUCE_FOODS', 'hugeAnimals': 'HUGE_ANIMALS', 'biggerThanCarObjects': 'BIGGER_THAN_CAR_OBJECTS', 'hotThings': 'HOT_THINGS', 'coldThings': 'COLD_THINGS', 'metalObjects': 'METAL_OBJECTS', 'communicationObjects': 'COMMUNICATION_OBJECTS', 'mechanicalObjects': 'MECHANICAL_OBJECTS', 'kitchenObjects': 'KITCHEN_OBJECTS', 'softObjects': 'SOFT_OBJECTS', 'hardObjects': 'HARD_OBJECTS', 'waterBodies': 'WATER_BODIES', 'liquids': 'LIQUIDS', 'toolObjects': 'TOOL_OBJECTS', 'seasons': 'SEASONS'}
for _k, _const in _ALIAS.items():
    globals()[_const] = _SETS[_k]

PHYSICAL_CATS = {"object","structure","naturalPlace","animal","plant","person","food","substance","bodyPart"}

# ---------------------------------------------------------------------------
# deterministicVerdict  (WordAttributes)
# ---------------------------------------------------------------------------
def deterministic_verdict(w, c, p):
    needs_body = {"biggerThanCar","fitsInHand","smallerThanShoe","edible","wearable","canHold","metal","wood",
                  "soft","liquid","food","inKitchen","nearWater","indoors","outdoors","movesItself","movingParts"}
    bodiless = {"abstract","timePeriod","event","artMusic"}
    if c in bodiless and p in needs_body:
        return "No"

    if p == "physical":
        return "Yes" if c in PHYSICAL_CATS else "No"
    if p == "abstractIdea":
        if c == "abstract": return "Yes"
        if c in ("timePeriod","event","artMusic"): return "Sort of"   # naturalPhenomenon is physical -> No (below)
        return "No"
    if p == "emotion":
        return None if c == "abstract" else "No"
    if p == "action":
        if c == "event": return "Sort of"
        if c == "abstract": return None
        return "No"
    if p == "alive":
        if c in ("animal","plant","person"): return "Yes"
        if c == "bodyPart": return "Sort of"
        return "No"
    if p == "everAlive":
        if c in ("animal","plant","person","bodyPart"): return "Yes"
        if c == "food": return "Sort of"
        return "No"
    if p == "animal":
        return "Yes" if c == "animal" else "No"
    if p == "plant":
        if c == "plant": return "Yes"
        if c == "food": return None
        return "No"
    if p == "manMade":
        if c in ("object","structure"): return "Yes"
        if c in ("artMusic","event"): return "Sort of"
        if c == "food": return None
        return "No"
    if p == "natural":
        if c in ("naturalPlace","animal","plant","naturalPhenomenon","substance","bodyPart","person","timePeriod"): return "Yes"
        if c == "food": return "Sort of"
        return "No"
    if p == "place":
        return "Yes" if c in ("naturalPlace","structure") else "No"
    if p == "bodyPart":
        return "Yes" if c == "bodyPart" else "No"
    if p == "inNature":
        if c in ("naturalPlace","animal","plant","naturalPhenomenon","substance"): return "Yes"
        if c == "bodyPart": return "Sort of"
        if c == "food": return "Yes" if w in PRODUCE_FOODS else "No"
        return "No"
    if p == "wearable":
        if c == "object": return "Yes" if w in WEARABLE_OBJECTS else "No"
        return "No"
    if p == "food":
        return "Yes" if c == "food" else "No"
    if p == "liquid":
        if w in LIQUIDS: return "Yes"                                  # water, oil, soup, magma, blood, rain...
        if c in ("structure","naturalPlace","animal","plant","person","bodyPart","object","substance"): return "No"
        if c == "food": return "No" if w in PRODUCE_FOODS else None   # solid produce No; other foods defer
        return None
    if p == "transport":
        if c == "object": return "Yes" if w in VEHICLES else "No"
        if c == "animal": return "Sort of" if w in RIDEABLE_ANIMALS else "No"
        if c == "structure": return None
        return "No"
    if p == "metal":
        if c in ("food","animal","plant","person","bodyPart","naturalPlace","naturalPhenomenon"): return "No"
        if c == "substance": return "Yes" if w in METAL_SUBSTANCES else "No"
        if c == "object": return "Yes" if w in METAL_OBJECTS else None
        if c == "structure": return None
        return "No"
    if p == "biggerThanCar":
        if c in ("food","bodyPart","substance","person"): return "No"
        if c == "naturalPlace": return "Yes"
        if c == "animal": return "Yes" if w in HUGE_ANIMALS else "No"
        if c == "object": return "Yes" if w in BIGGER_THAN_CAR_OBJECTS else "No"
        if c in ("structure","naturalPhenomenon"): return None
        return "No"
    if p == "givesLight":
        return "Yes" if w in LIGHT_GIVERS else "No"
    if p == "hot":
        if w in HOT_THINGS: return "Yes"
        if w in COLD_THINGS: return "No"
        if c == "food" and w in PRODUCE_FOODS: return "No"
        if c in ("abstract","timePeriod","event","artMusic"): return "No"
        if c == "bodyPart": return "No"
        if c == "object": return "No"
        return None
    if p == "cold":
        if w in COLD_THINGS: return "Yes"
        if w in HOT_THINGS: return "No"
        if c == "food" and w in PRODUCE_FOODS: return "No"
        if c in ("abstract","timePeriod","event","artMusic"): return "No"
        if c == "bodyPart": return "No"
        if c == "object": return "No"
        return None
    if p == "communication":
        if c == "object": return "Yes" if w in COMMUNICATION_OBJECTS else "No"
        return "No"
    if p == "movingParts":
        if c == "object": return "Yes" if w in MECHANICAL_OBJECTS else "No"
        if c == "structure": return None
        return "No"
    if p == "edible":
        if c == "food": return "Yes"
        if c in ("bodyPart","object","structure","substance","naturalPlace","naturalPhenomenon","person"): return "No"
        if c in ("animal","plant"): return None
        return "No"
    if p == "inKitchen":
        if c == "food": return "Yes"
        if c == "object": return "Yes" if w in KITCHEN_OBJECTS else "No"
        return "No"
    if p == "soft":
        if c == "object":
            if w in SOFT_OBJECTS: return "Yes"
            if w in HARD_OBJECTS: return "No"
            return None
        if c == "naturalPlace":
            return None if w in WATER_BODIES else "No"
        return None
    if p == "movesItself":
        if c in ("animal","person"): return "Yes"
        if c == "naturalPhenomenon": return None
        return "No"
    if p == "tech":
        if c == "object": return "Yes" if w in TECH_OBJECTS else "No"
        return "No"
    if p == "wood":
        if c == "object":
            if w in WOODEN_OBJECTS: return "Yes"
            if w in AMBIG_WOOD: return None
            return "No"
        if c in ("structure","plant"): return None
        return "No"
    if p == "indoors":
        if c in ("naturalPlace","naturalPhenomenon"): return "No"
        if c == "animal": return None if w in INDOOR_ANIMALS else "No"
        return None
    if p == "outdoors":
        if c in ("naturalPlace","naturalPhenomenon"): return "Yes"
        if c == "animal": return None if w in INDOOR_ANIMALS else "Yes"
        return None
    if p == "centuriesOld":
        if c in ("naturalPlace","naturalPhenomenon","substance","animal","plant","bodyPart","person","timePeriod","food"): return "Yes"
        if c == "object": return None if w in MODERN_OBJECTS else "Yes"
        return None
    if p == "modern":
        if c in ("naturalPlace","naturalPhenomenon","substance","animal","plant","bodyPart","person","timePeriod","food"): return "No"
        if c == "object": return None if w in MODERN_OBJECTS else "No"
        return None
    if p == "makesSound":
        if c == "object": return "Yes" if w in SOUND_OBJECTS else "No"
        if c == "animal": return "No" if w in SILENT_ANIMALS else "Yes"
        return None
    if p == "smallerThanShoe":
        if c == "animal":
            if w in SMALL_ANIMALS: return "Yes"
            if w in BIG_ANIMALS: return "No"
            return None
        if c == "object":
            if w in SMALL_OBJECTS: return "Yes"
            if w in BIG_OBJECTS: return "No"
            return None
        if c == "bodyPart":
            if w in SMALL_BODYPARTS: return "Yes"
            if w in BIG_BODYPARTS: return "No"
            return None
        return None
    if p == "entertainment":
        # rock, body part, season, phenomenon, raw food are not entertainment.
        if c in ("food","substance","bodyPart","naturalPhenomenon","timePeriod"): return "No"
        return None
    if p == "color":
        if c in PHYSICAL_CATS: return "Yes"
        if c == "naturalPhenomenon": return None
        return "No"
    if p == "tool":
        if c == "object": return "Yes" if w in TOOL_OBJECTS else "No"
        return "No"
    if p == "season":
        if c == "timePeriod": return "Yes" if w in SEASONS else "No"
        if c in ("object","structure","substance","bodyPart","person","abstract","event","artMusic"): return "No"
        return None
    if p == "fitsInHand":
        if c in ("naturalPlace","structure","person","naturalPhenomenon"): return "No"
        if c == "object": return "Yes" if w in SMALL_OBJECTS else ("No" if w in BIG_OBJECTS else None)
        if c == "animal": return "Yes" if w in SMALL_ANIMALS else ("No" if w in BIG_ANIMALS else None)
        if c == "bodyPart": return "Yes" if w in SMALL_BODYPARTS else ("No" if w in BIG_BODYPARTS else None)
        return None
    if p == "job":
        # A job/profession is a people-role, not a thing. Concrete non-person nouns
        # (pumpkin, towel, river, hand) are not a profession -> No. Person, structure
        # (workplace), event/art/abstract defer to the model.
        if c in ("food","plant","animal","bodyPart","naturalPlace",
                 "naturalPhenomenon","substance","object","timePeriod"):
            return "No"
        return None
    # all other properties -> defer to model
    return None

# ---------------------------------------------------------------------------
# OfflineKeeper.property  (English map, most-specific-first)
# ---------------------------------------------------------------------------
PROP_MAP = [
    ("everAlive",   ["ever alive","was it alive","once alive","used to be alive","ever living","once living","was it living"]),
    ("alive",       ["alive","still living","is it living","a living thing"]),
    ("animal",      ["an animal","is it animal","a creature","a beast","a mammal","a bird","an insect","a fish"]),
    ("plant",       ["a plant","is it plant","vegetation","a flower or"]),
    ("bodyPart",    ["body part","part of the body","part of your body","part of a body","anatomy","body-part"]),
    ("emotion",     ["an emotion","is it emotion","a feeling","emotional","how you feel"]),
    ("abstractIdea",["abstract","an idea","a concept","concept","a notion","intangible","in your mind","just an idea"]),
    ("action",      ["an action","something you do","an activity","a verb","is it an action","an act"]),
    ("manMade",     ["man-made","manmade","man made","manufactured","made by people","made by humans","made by man",
                     "artificial","human-made","human made","built by","made in a factory"]),
    ("inNature",    ["in nature","in the wild","in the wilderness","out in nature","in the wild?","found in the wild"]),
    ("natural",     ["occur naturally","occurs naturally","found in nature","naturally occurring","made by nature","natural","naturally"]),
    ("place",       ["a place","is it a place","a location","somewhere you can","geographic","a spot you can go"]),
    ("biggerThanCar",["bigger than a car","bigger than car","larger than a car","bigger than a house","huge","enormous",
                     "gigantic","very big","very large","massive"]),
    ("smallerThanShoe",["smaller than a shoe","smaller than shoe","tiny","very small","smaller than your hand"]),
    ("fitsInHand",  ["fit in your hand","fit in a hand","fit in hand","fits in your hand","fits in a hand","fits in hand",
                     "handheld","hold it in your hand","fit in the palm","fit in your palm"]),
    ("inKitchen",   ["kitchen"]),
    ("nearWater",   ["near water","in water","underwater","by water","around water","in or near water"]),
    ("indoors",     ["indoors","indoor","inside a house","inside a building","found inside"]),
    ("outdoors",    ["outdoors","outdoor","outside"]),
    ("transport",   ["transport","a vehicle","get around","used to travel","for travel","ride in","ride on","for getting around"]),
    ("communication",["communicat","send a message","for talking","used to talk","used for talking"]),
    ("entertainment",["entertain","for fun","play with","for playing","a hobby","a game you play"]),
    ("tool",        ["a tool","is it a tool","a device","an instrument","a utensil","a gadget","tool or device","a piece of equipment"]),
    ("edible",      ["can you eat","edible","can you drink","do you eat","good to eat","safe to eat","eat it","drink it","taste it","eat or drink"]),
    ("wearable",    ["wearable","do you wear","can you wear","is it clothing","clothes","put it on","worn on","worn by"]),
    ("canHold",     ["hold it","can you hold","pick it up","carry it","hold in your hands","held in","can you carry"]),
    ("metal",       ["metal","metallic","made of metal","made of iron","made of steel"]),
    ("wood",        ["wood","wooden","made of wood"]),
    ("soft",        ["soft","fluffy","squishy","soft to the touch"]),
    ("liquid",      ["a liquid","is it liquid","a fluid","is it fluid"]),
    ("givesLight",  ["give off light","gives off light","give light","gives light","glow","glows","shine","shines",
                     "luminous","light up","lights up","emit light","emits light"]),
    ("makesSound",  ["make a sound","makes a sound","make sound","makes noise","make noise","a noise","can you hear it","audible","is it loud"]),
    ("hasSmell",    ["a smell","smell","a scent","scent","odor","odour","aroma","fragran"]),
    ("color",       ["a color","a colour","specific color","specific colour","colorful","colourful","what color","what colour"]),
    ("movingParts", ["moving parts","parts that move","mechanical parts","has parts"]),
    ("movesItself", ["move on its own","move by itself","moves itself","move itself","self-propelled","moves on its own","moves by itself"]),
    ("food",        ["a food","a kind of food","is it food","foodstuff","a dish","a meal","edible food"]),
    ("hot",         ["is it hot","usually hot","very hot","warm to the touch","gives off heat","hot to the touch","is it warm"]),
    ("cold",        ["is it cold","usually cold","very cold","freezing","icy","chilly","cold to the touch"]),
    ("tech",        ["technolog","electronic","digital","a computer","high-tech","is it tech","tech?"]),
    ("job",         ["a job","a profession","an occupation","a career","kind of work","for work","a trade"]),
    ("season",      ["a season","time of year","associated with a season"]),
    ("centuriesOld",["centuries","hundreds of years","ancient","very old","thousands of years","from long ago","old invention"]),
    ("modern",      ["modern","recent invention","invented recently","a new invention","recently invented","a recent invention"]),
    ("physical",    ["physical","can you touch","tangible","a real object","a solid object","an object","touch it",
                     "is it an object","a thing you can touch"]),
]

def map_property(question):
    q = question.lower()
    for prop, triggers in PROP_MAP:
        if any(t in q for t in triggers):
            return prop
    return None

# ---------------------------------------------------------------------------
# Tracer
# ---------------------------------------------------------------------------
def trace(word, question):
    w = word.lower()
    cat = CATEGORIES.get(w)
    prop = map_property(question)
    if cat is None:
        return dict(word=w, category=None, prop=prop, verdict=None, path="LLM-FALLBACK (word untagged)")
    if prop is None:
        return dict(word=w, category=cat, prop=None, verdict=None, path="LLM-FALLBACK (question unmapped)")
    v = deterministic_verdict(w, cat, prop)
    if v is None:
        return dict(word=w, category=cat, prop=prop, verdict=None, path="LLM-FALLBACK (verdict deferred)")
    return dict(word=w, category=cat, prop=prop, verdict=v, path="DETERMINISTIC")

if __name__ == "__main__":
    import sys
    if len(sys.argv) >= 3:
        r = trace(sys.argv[1], " ".join(sys.argv[2:]))
        print(r)
