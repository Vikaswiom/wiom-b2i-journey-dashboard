import re, collections
rows=[l.split('\t') for l in open('other_text.tsv').read().strip().split('\n')[1:]]
rows=[(t,int(n)) for t,n in rows if n.isdigit()]
LATER=r"not at home|\bhome\b|ghar pe nahi|out of station|bahar hai|delhi se bahar|later|\bnext\b|\bkal\b|tomorrow|week|month|busy|shift|baad|tarikh|tareekh|\bdate\b|saturday|sunday|monday|tuesday|wednesday|thursday|friday|\d+ ?nov|\d+ ?dec|time (nahi|ni|nhi|short)|no time|drill|for few days|aaunga|lagaega|lagwayega"
T=[
 ('CSP side: no team / technician / device', r"team|staff|staaf|technician|installer|engineer|ladka|ladke|banda|\bboy|router|netbox|net box|\bdevice|stock|\bont\b|\bonu\b|lco issue|my side"),
 ('Complaint about Wiom (pricing / mis-selling / leads)', r"cheat|chwat|wiom द्वारा|galat jankari|गलत जानकारी|issues with wiom|frji|farzi|fake lead|rating down|wiom laga|10 ?rs|₹10|10 rupe"),
 ('Already has another connection / booked twice', r"already|pahle se|pehle se|पहले|existing|other isp|other opretor|other operator|dusr|duse?ri company|other company|jio|airtel|bloom|vyom|2 booking|same address|lagva liya|lagwa liya|lag wa|3 baar"),
 ('Wrong or fake booking details', r"fake|fraud|wrong|galt|galat|by mistake|galti|duplicate|test|dummy|bbbb|zasd|xyz"),
 ('Customer unreachable (call not picked / phone off)', r"call|pick|respon|sw\w*ch ?off|swich|contact|incoming|answer|phone|ph\b|number|\bno\.|unreach|ring|utha|rply|reply|milta (hi )?nahi|मिलता ही नहीं"),
 ('Customer not interested / cancelled / won\'t pay', r"interest|intrest|cancel|cencel|not agree|chahiye|don'?t want|dont want|not want|\bpay|price|amount|charge|costly|mehng|mahng|refund|\bmana\b|\bmna\b|मना|मन कर|deny|denied|not ready|refus|nahi lena|nhi lena|recharge|money|paise"),
 ('Customer not at home / asked for later', LATER),
 ('No coverage at address (no line / wire / fiber / signal / out of area)', r"fe?a?s|fis|fes|fiz|fig|physbl|visib|vis|line|lain|wire|wayar|waire|taar|\btar\b|fib|fbr|फाइबर|cable|power|pawar|pwr|optic|signal|dbm|out of|area|aria|ariya|aeria|range|renj|distance|\bfar\b|दूर|\bkm\b|\bdoor|rfs|splitter|\bpon\b|\bport|point|poll|pole|\bjc\b|\bbox\b|location|loction|lokation|coverage|connectivity|vonnect|connect vt|reach|tower|network|servic|gali|jagah|road|building|floor|terrace|यहां का नहीं|yaha ka nahi|mera connection nahin|connection nahin hai|hmara .* me hai|\bnf\b|nf\.|not possible|nahi lag|nhi lg|nhi lag"),
 ('Customer not at home / asked for later', r"not available|available nahi|nhi mil|nahi mil"),
]
agg=collections.Counter(); ex=collections.defaultdict(list); tot=0; unc=[]
for t,n in rows:
    tot+=n; lab='Unclear (gibberish / too vague)'
    for name,pat in T:
        if re.search(pat,t): lab=name; break
    agg[lab]+=n
    if len(ex[lab])<6: ex[lab].append(t[:65])
    if lab.startswith('Unclear'): unc.append((n,t))
for k,v in agg.most_common(): print(f'{v:5} {100*v/tot:5.1f}%  {k}\n        e.g. '+' | '.join(ex[k][:5]))
print('total',tot); print('unclear sample:', [t[:50] for n,t in sorted(unc,reverse=True)[:15]])
