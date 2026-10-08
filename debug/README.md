# Wick verdict tracer (dev-only, not shipped)

Python port of the DETERMINISTIC ground-truth path in `QuestionService.answer()`
(`WordAttributes.deterministicVerdict` + `OfflineKeeper.property`). Lets us check
exactly what Wick answers for tagged words WITHOUT a device/Xcode build.

Paths:
- DETERMINISTIC  = answered identically on every device, no model. Verify these here.
- LLM-FALLBACK   = handed to Foundation Models; we can't run it, but the per-word
                   report shows the facts injected into the prompt (the #1 driver
                   of a right/wrong model answer).

## Usage
    python3 debug/wick_tracer.py boot "is it made of metal?"     # single trace
    python3 debug/report.py entropy rainbow money                # per-word debug view

Keep in sync with WordAttributes.swift / OfflineKeeper.swift when tags/rules change.
