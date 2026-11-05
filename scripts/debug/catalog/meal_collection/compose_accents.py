"""Fill in Gimbot's blank accented letters (é, û, ç, ñ ...) from its own base letters and accent marks.

gimbot_regular.otf maps Latin-1 accented letters to empty glyphs. This writes a copy with them
composed, used only by the Meal Collection page (Gimbot-Accented.otf here). Needs fontTools.

    python compose_accents.py assets/fonts/gimbot_regular.otf Gimbot-Accented.otf
"""
import sys, unicodedata
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
src, out = sys.argv[1], sys.argv[2]
f = TTFont(src); cmap = f.getBestCmap(); gs = f.getGlyphSet()
cff = f['CFF '].cff; top = cff.topDictIndex[0]; cs = top.CharStrings
hmtx = f['hmtx']
def bounds(name):
    p = BoundsPen(gs); gs[name].draw(p); return p.bounds
MARKS = {'́': ('acute', 1.0), '̀': ('grave', 1.0), '̂': ('asciicircum', 0.55),
         '̈': ('dieresis', 1.0), '̃': ('asciitilde', 0.55), '\u0327': ('cedilla', 1.0)}
fixed = []
for code, name in cmap.items():
    if not (0xC0 <= code < 0x250) or bounds(name) is not None: continue
    d = unicodedata.decomposition(chr(code)).split()
    if len(d) != 2: continue
    base, mark = chr(int(d[0], 16)), chr(int(d[1], 16))
    if mark not in MARKS or ord(base) not in cmap: continue
    bname = cmap[ord(base)]; bb = bounds(bname)
    if base in 'ij': bb = (bb[0], bb[1], bb[2], 943)
    mname, s = MARKS[mark]; mb = bounds(mname)
    mw, mh = (mb[2]-mb[0])*s, (mb[3]-mb[1])*s
    dx = (bb[0]+bb[2])/2 - mw/2 - mb[0]*s
    dy = bb[3] + 90 - mb[1]*s
    if mark == '\u0327': dy = bb[1] - mh + 20 - mb[1]*s
    width = hmtx[bname][0]
    pen = T2CharStringPen(width, gs)
    rec = RecordingPen()
    if base in 'ij':
        # draw dotless stem: use base but clip not possible; use dotless i if present
        dl = cmap.get(0x131)
        (gs[dl] if dl and bounds(dl) else gs[bname]).draw(rec)
    else:
        gs[bname].draw(rec)
    rec.replay(pen)
    gs[mname].draw(TransformPen(pen, (s, 0, 0, s, dx, dy)))
    c = pen.getCharString(private=top.Private, globalSubrs=cff.GlobalSubrs)
    cs[name] = c; hmtx[name] = (width, int(bb[0]))
    fixed.append(chr(code))
f.save(out); print('fixed', ''.join(fixed))
