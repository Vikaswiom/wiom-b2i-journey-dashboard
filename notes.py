"""Group the free-text notes CSPs type when they decline or report a failure into themes.
build(rows, key_fields) -> rows of {key fields..., theme, tasks, examples, notes_total} for the dashboard.
Examples are public: only generic phrases are shown (a note seen 2+ times, or a short note with no digits)."""
import re, collections
LATER=r"not at home|\bhome\b|ghar pe nahi|out of station|bahar hai|delhi se bahar|later|\bnext\b|\bkal\b|tomorrow|week|month|busy|shift|baad|tarikh|tareekh|\bdate\b|saturday|sunday|monday|tuesday|wednesday|thursday|friday|\d+ ?nov|\d+ ?dec|time (nahi|ni|nhi|short)|no time|drill|for few days|aaunga|lagaega|lagwayega"
THEMES=[
 ('CSP side: no team, technician or device', r"team|staff|staaf|technician|installer|engineer|ladka|ladke|banda|\bboy|router|netbox|net box|\bdevice|stock|\bont\b|\bonu\b|lco issue|my side"),
 ('Complaint about Wiom (pricing, mis-selling, leads)', r"cheat|chwat|wiom द्वारा|galat jankari|गलत जानकारी|issues with wiom|frji|farzi|fake lead|rating down|wiom laga|10 ?rs|₹10|10 rupe"),
 ('Already has another connection or booked twice', r"already|pahle se|pehle se|पहले|existing|other isp|other opretor|other operator|dusr|duse?ri company|other company|jio|airtel|bloom|vyom|2 booking|same address|lagva liya|lagwa liya|lag wa|3 baar"),
 ('Wrong or fake booking details', r"fake|fraud|wrong|galt|galat|by mistake|galti|duplicate|test|dummy|bbbb|zasd|xyz"),
 ('Customer unreachable (call not picked, phone off)', r"call|pick|respon|sw\w*ch ?off|swich|contact|incoming|answer|phone|ph\b|number|\bno\.|unreach|ring|utha|rply|reply|milta (hi )?nahi|मिलता ही नहीं"),
 ('Customer not interested, cancelled or won\'t pay', r"interest|intrest|cancel|cencel|not agree|chahiye|don'?t want|dont want|not want|\bpay|price|amount|charge|costly|mehng|mahng|refund|\bmana\b|\bmna\b|मना|मन कर|deny|denied|not ready|refus|nahi lena|nhi lena|recharge|money|paise|said no|says no"),
 ('Customer not at home or asked for later', LATER),
 ('No coverage at the address (no line, wire, fiber, signal; out of area)', r"fe?a?s|fis|fes|fiz|fig|physbl|visib|vis|line|lain|wire|wayar|waire|taar|\btar\b|fib|fbr|फाइबर|cable|power|pawar|pwr|optic|signal|dbm|out of|area|aria|ariya|aeria|range|renj|distance|\bfar\b|दूर|\bkm\b|\bdoor|rfs|splitter|\bpon\b|\bport|point|poll|pole|\bjc\b|\bbox\b|location|loction|lokation|coverage|connectivity|vonnect|connect vt|reach|tower|network|servic|gali|jagah|road|building|floor|terrace|यहां का नहीं|yaha ka nahi|mera connection nahin|connection nahin hai|hmara .* me hai|\bnf\b|nf\.|not possible|nahi lag|nhi lg|nhi lag"),
 ('Customer not at home or asked for later', r"not available|available nahi|nhi mil|nahi mil"),
]
UNCLEAR='Unclear or too vague'
def theme(t):
    for name,pat in THEMES:
        if re.search(pat,t): return name
    return UNCLEAR
def _safe(t, n):
    t=re.sub(r'\s+',' ',t).strip()
    if not t or re.search(r'\d{5,}', t) or '@' in t: return None
    if n>=2 or (len(t.split())<=6 and not re.search(r'\d', t)): return t[:80]
    return None
def build(rows, key_fields):
    """rows: dicts with key_fields + 'note' (lowercased text or None) + 'n'."""
    tot=collections.Counter(); agg=collections.defaultdict(collections.Counter); ex=collections.defaultdict(collections.Counter)
    for r in rows:
        k=tuple(r[f] for f in key_fields); tot[k]+=r['n']
        note=(r.get('note') or '').strip()
        if not note or note in ('none','null'): continue
        th=theme(note); agg[k][th]+=r['n']; ex[(k,th)][note]+=r['n']
    out=[]
    for k,c in agg.items():
        with_note=sum(c.values())
        for th,n in c.most_common():
            exs=[]
            for note,cnt in ex[(k,th)].most_common():
                s=_safe(note,cnt)
                if s and s not in exs: exs.append(s)
                if len(exs)>=4: break
            row=dict(zip(key_fields,k)); row.update(theme=th,tasks=n,examples=' | '.join(exs),notes_total=with_note,reason_total=tot[k])
            out.append(row)
    return out
