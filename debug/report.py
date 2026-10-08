from wick_tracer import trace, CATEGORIES, deterministic_verdict

FACTS = {
 "object":"tangible man-made object, not alive.",
 "structure":"man-made place/building, not alive, too big to hold.",
 "naturalPlace":"natural place/landform/body, not man-made, not alive, too large to hold.",
 "animal":"living animal.",
 "plant":"living plant, not man-made.",
 "person":"a living human being, not man-made.",
 "food":"food or drink you can eat/taste, may be natural.",
 "substance":"physical material/substance, not alive.",
 "bodyPart":"part of a living body, not man-made.",
 "naturalPhenomenon":"natural phenomenon/event, not solid, not man-made, not alive.",
 "timePeriod":"a period of time, no size/color/material, not alive/man-made.",
 "event":"event/occasion/activity, not a holdable object, no material/color.",
 "artMusic":"art/music form, abstract human creation, not solid, not alive.",
 "abstract":"abstract concept/quality/feeling, not physical, not alive, no size/color.",
}

STD = [
 ("physical","is it a physical object you can touch?"),
 ("alive","is it alive?"),
 ("everAlive","was it ever alive?"),
 ("manMade","is it man-made?"),
 ("natural","does it occur naturally?"),
 ("abstractIdea","is it an abstract idea?"),
 ("emotion","is it an emotion?"),
 ("place","is it a place?"),
 ("edible","can you eat it?"),
 ("wearable","can you wear it?"),
 ("canHold","can you hold it?"),
 ("metal","is it made of metal?"),
 ("wood","is it made of wood?"),
 ("liquid","is it a liquid?"),
 ("color","does it have a color?"),
 ("hasSmell","does it have a smell?"),
 ("makesSound","does it make a sound?"),
 ("givesLight","does it give off light?"),
 ("hot","is it hot?"),
 ("cold","is it cold?"),
 ("smallerThanShoe","is it smaller than a shoe?"),
 ("biggerThanCar","is it bigger than a car?"),
 ("tech","is it technology?"),
 ("transport","is it a vehicle?"),
 ("tool","is it a tool?"),
 ("movesItself","does it move on its own?"),
 ("centuriesOld","is it centuries old?"),
 ("modern","is it a modern invention?"),
]

def report(word):
    w=word.lower(); cat=CATEGORIES.get(w)
    print("="*66)
    print(f"WORD: {w}    CATEGORY: {cat}")
    print(f"INJECTED FACTS: {FACTS.get(cat,'(untagged - model reasons alone)')}")
    print("-"*66)
    det=[]; llm=[]
    for prop,q in STD:
        r=trace(w,q)
        if r["path"]=="DETERMINISTIC": det.append((q,r["verdict"]))
        else: llm.append((q,r["prop"]))
    print("DETERMINISTIC (identical every device, no model):")
    for q,v in det: print(f"   {v:8} <- {q}")
    print("LLM-DECIDED (Foundation Models; facts above steer it):")
    for q,p in llm: print(f"   [model] <- {q}   (prop={p})")

import sys
for wd in (sys.argv[1:] or ["entropy","nebula","rainbow"]):
    report(wd)
