import numpy as np, wave, struct

SR = 44100

def note(freq, dur, harmonics=(1.0,0.5,0.25), h_decay=(4,7,11), attack=0.006, decay=6.0, warmth=1.0):
    """Bell/mallet-ish tone: fundamental + fast-decaying harmonics, soft attack, exp decay."""
    n = int(SR*dur); t = np.linspace(0, dur, n, endpoint=False)
    sig = np.zeros(n)
    for k,(amp,hd) in enumerate(zip(harmonics, h_decay), start=1):
        sig += amp*np.sin(2*np.pi*freq*k*t)*np.exp(-hd*t)   # each harmonic decays at its own rate
    env = np.exp(-decay*t)                                   # overall body decay
    a = int(SR*attack)                                       # soft attack (no click)
    if a>0: env[:a] *= np.linspace(0,1,a)
    r = int(SR*0.008)                                        # tiny release fade (no click)
    if r>0: env[-r:] *= np.linspace(1,0,r)
    sig *= env*warmth
    return sig

def seq(notes, gap=0.0):
    parts=[]; 
    for i,nn in enumerate(notes):
        parts.append(nn)
        if gap>0 and i<len(notes)-1: parts.append(np.zeros(int(SR*gap)))
    return np.concatenate(parts)

def norm(sig, peak=0.5):
    m=np.max(np.abs(sig)) or 1.0
    return sig/m*peak

def save(name, sig, peak=0.5):
    sig=norm(sig, peak)
    data=(sig*32767).astype('<i2').tobytes()
    with wave.open(f"{name}.wav","w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)
    print(f"{name}.wav  {len(sig)/SR*1000:.0f}ms  peak={peak}")

# --- closeness ticks: soft, dull "tock", rising pitch/brightness with warmth ---
save("guess_cold", note(196, 0.13, harmonics=(1.0,0.18), h_decay=(9,16), decay=9), peak=0.32)   # G3, muted
save("guess_warm", note(330, 0.12, harmonics=(1.0,0.30), h_decay=(8,14), decay=9), peak=0.38)   # E4
save("guess_hot",  note(494, 0.12, harmonics=(1.0,0.45,0.2), h_decay=(7,12,18), decay=9), peak=0.42) # B4, brighter

# --- newClosest: bright rewarding "ting" ---
save("closest", note(880, 0.20, harmonics=(1.0,0.5,0.28,0.14), h_decay=(5,8,12,18), decay=6), peak=0.5) # A5

# --- solved: gentle ascending arpeggio C5-E5-G5-C6, bell-like, warm ---
save("solved", seq([
    note(523.25,0.16, harmonics=(1,0.5,0.25), h_decay=(5,9,14), decay=7),
    note(659.25,0.16, harmonics=(1,0.5,0.25), h_decay=(5,9,14), decay=7),
    note(783.99,0.16, harmonics=(1,0.5,0.25), h_decay=(5,9,14), decay=7),
    note(1046.5,0.42, harmonics=(1,0.55,0.3,0.15), h_decay=(4,7,11,16), decay=4.5),
], gap=0.005), peak=0.5)

# --- gaveUp: soft descending two-note, gentle (not harsh) ---
save("gaveup", seq([
    note(392.00,0.20, harmonics=(1,0.25), h_decay=(7,12), decay=6),   # G4
    note(261.63,0.34, harmonics=(1,0.22), h_decay=(7,12), decay=4.5), # C4
], gap=0.01), peak=0.34)

# --- coin: quick light two-note up blip ---
save("coin", seq([
    note(880,0.07, harmonics=(1,0.4), h_decay=(8,14), decay=12),      # A5
    note(1174.66,0.12, harmonics=(1,0.5,0.25), h_decay=(6,10,15), decay=9), # D6
], gap=0.0), peak=0.44)

# --- montage: all sounds in sequence with labels-worth-of-gap, for quick audition ---
files=["guess_cold","guess_warm","guess_hot","closest","solved","gaveup","coin"]
import numpy as _np
mont=[]
for f in files:
    with wave.open(f"{f}.wav") as w:
        d=_np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').astype(float)/32767
    mont.append(d); mont.append(_np.zeros(int(SR*0.6)))
save("_ALL_preview", _np.concatenate(mont), peak=0.9)
