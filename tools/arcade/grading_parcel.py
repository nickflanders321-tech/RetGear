# The return parcel for the grading reveal (our own drawing), as SVG. Used by tools/arcade/art_grading.py for the game's
# textures (game=True: no seal, no names or dates: the add-on writes those) and by the mock-ups.
import sys
def parcel(state="sealed", uid="a", service="STANDARD", who="Scott", game=False):
    W,H=380,500
    tw="#d9c9a0"; tw2="#a8936a"
    s=[]
    s.append(f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-30 -30 {W+60} {H+70}" width="{W+60}" height="{H+70}">
<defs>
 <filter id="paper{uid}" x="0" y="0" width="100%" height="100%">
  <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="3" seed="4" result="n"/>
  <feColorMatrix in="n" type="matrix" values="0 0 0 0 0.35  0 0 0 0 0.25  0 0 0 0 0.12  0 0 0 0.32 0" result="g"/>
  <feTurbulence type="fractalNoise" baseFrequency="0.012 0.08" numOctaves="2" seed="9" result="f"/>
  <feColorMatrix in="f" type="matrix" values="0 0 0 0 0.25  0 0 0 0 0.17  0 0 0 0 0.08  0 0 0 0.26 0" result="fib"/>
  <feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="g"/><feMergeNode in="fib"/></feMerge>
  <feComposite operator="in" in2="SourceAlpha"/>
 </filter>
 <linearGradient id="kraft{uid}" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="#c8a573"/><stop offset=".55" stop-color="#b08a58"/><stop offset="1" stop-color="#8e6b40"/>
 </linearGradient>
 <radialGradient id="vig{uid}" cx=".45" cy=".4" r=".8"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#2a1806" stop-opacity=".45"/></radialGradient>
 <pattern id="rope{uid}" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(35)">
  <rect width="7" height="7" fill="{tw}"/><rect width="3" height="7" fill="{tw2}" opacity=".65"/>
 </pattern>
 <pattern id="ropeV{uid}" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(-55)">
  <rect width="7" height="7" fill="{tw}"/><rect width="3" height="7" fill="{tw2}" opacity=".65"/>
 </pattern>
 <radialGradient id="wax{uid}" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="#d0412f"/><stop offset=".55" stop-color="#9b1f17"/><stop offset="1" stop-color="#5a0d09"/></radialGradient>
 <radialGradient id="waxIn{uid}" cx=".6" cy=".65" r=".7"><stop offset="0" stop-color="#7d1610"/><stop offset="1" stop-color="#b22a1e"/></radialGradient>
 <filter id="sh{uid}" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="14" stdDeviation="14" flood-color="#000" flood-opacity=".6"/></filter>
 <filter id="soft{uid}"><feDropShadow dx="0" dy="2" stdDeviation="1.6" flood-color="#2a1606" flood-opacity=".55"/></filter>
 <filter id="ink{uid}"><feTurbulence type="fractalNoise" baseFrequency="1.6" numOctaves="2" seed="2"/><feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 -2.2 1.5"/><feComposite in="SourceGraphic" operator="in"/></filter>
 <path id="ring{uid}" d="M190,250 m-36,0 a36,36 0 1,1 72,0 a36,36 0 1,1 -72,0"/>
</defs>''')
    # body (open: paper folded back)
    if state=="open":
        s.append(f'''<g filter="url(#sh{uid})">
  <rect x="0" y="0" width="{W}" height="{H}" rx="8" fill="#1d1712"/>
  <rect x="10" y="10" width="{W-20}" height="{H-20}" rx="6" fill="#2a221a"/>
  <path d="M0,0 L-24,-22 L{W*0.5},-6 L{W*0.5},40 Z" fill="url(#kraft{uid})" filter="url(#paper{uid})" opacity=".95"/>
  <path d="M{W},{H} L{W+24},{H+26} L{W*0.5},{H+8} L{W*0.5},{H-36} Z" fill="url(#kraft{uid})" filter="url(#paper{uid})" opacity=".95"/>
  <path d="M0,{H} L-26,{H+18} L-10,{H*0.5} L18,{H*0.5} Z" fill="#9c7848" filter="url(#paper{uid})"/>
  <path d="M{W},0 L{W+26},-16 L{W+10},{H*0.5} L{W-18},{H*0.5} Z" fill="#a8834f" filter="url(#paper{uid})"/>
  <rect x="50" y="60" width="{W-100}" height="{H-120}" rx="10" fill="#e8edf3" opacity=".10" stroke="#cfd8e3" stroke-opacity=".5"/>
  <text x="{W/2}" y="{H/2}" text-anchor="middle" font-family="Cinzel" font-size="13" fill="#cbb98d" letter-spacing="2">THE CASE LIFTS OUT</text>
</g>''')
        s.append('</svg>'); return "".join(s)
    s.append(f'<g filter="url(#sh{uid})"><rect x="0" y="0" width="{W}" height="{H}" rx="7" fill="url(#kraft{uid})" filter="url(#paper{uid})"/></g>')
    # folds and creases
    s.append(f'''<g opacity=".9">
  <path d="M0,0 L{W*0.22},{H*0.06} L{W*0.5},0" fill="none" stroke="#6e5130" stroke-opacity=".35" stroke-width="1.2"/>
  <path d="M0,{H} L{W*0.24},{H*0.94} L{W*0.5},{H}" fill="none" stroke="#6e5130" stroke-opacity=".35" stroke-width="1.2"/>
  <path d="M{W*0.62},{H} L{W*0.8},{H*0.95} L{W},{H}" fill="none" stroke="#6e5130" stroke-opacity=".3" stroke-width="1.2"/>
  <path d="M8,{H*0.32} C{W*0.3},{H*0.36} {W*0.42},{H*0.30} {W*0.7},{H*0.36}" fill="none" stroke="#fff3d6" stroke-opacity=".18" stroke-width="2"/>
  <path d="M{W*0.1},{H*0.72} C{W*0.3},{H*0.68} {W*0.55},{H*0.75} {W-6},{H*0.70}" fill="none" stroke="#4a3018" stroke-opacity=".18" stroke-width="2"/>
  <rect x="0" y="0" width="{W}" height="{H}" rx="7" fill="url(#vig{uid})"/>
  <rect x="1" y="1" width="{W-2}" height="{H-2}" rx="7" fill="none" stroke="#fff0cc" stroke-opacity=".25"/>
</g>''')
    # shipping label (top-left quadrant)
    s.append(f'''<g transform="translate(20,22) rotate(-2.5)" filter="url(#soft{uid})">
  <rect width="138" height="168" rx="3" fill="#f1e8d2"/>
  <rect x="5" y="5" width="128" height="158" rx="2" fill="none" stroke="#8a6a3a" stroke-width="1" stroke-dasharray="3 2"/>
  <text x="69" y="26" text-anchor="middle" font-family="Cinzel" font-weight="700" font-size="11" fill="#5a3a16" letter-spacing="1.2">WAYPOINT</text>
  <text x="69" y="39" text-anchor="middle" font-family="Cinzel" font-size="8.5" fill="#5a3a16" letter-spacing="1.6">GRADING GUILD</text>
  <line x1="16" x2="122" y1="48" y2="48" stroke="#8a6a3a" stroke-width=".8"/>
  <text x="14" y="64" font-family="Inter" font-size="7" fill="#7a6040" letter-spacing=".8">RETURN TO</text>
  {"" if game else f'<text x="14" y="80" font-family="Fraunces" font-size="15" fill="#2b1a0c">{who}</text>'}
  <text x="14" y="98" font-family="Inter" font-size="7" fill="#7a6040" letter-spacing=".8">CONTENTS</text>
  <text x="14" y="110" font-family="InterM" font-size="9" fill="#2b1a0c">1 graded card, cased</text>
  <text x="14" y="128" font-family="Inter" font-size="7" fill="#7a6040" letter-spacing=".8">SERVICE</text>
  {"" if game else f'<text x="14" y="140" font-family="InterS" font-size="9" fill="#2b1a0c" letter-spacing="1">{service}</text>'}
  {"" if game else '<text x="124" y="155" text-anchor="end" font-family="InterM" font-size="7" fill="#7a6040">No. 0004130</text>'}
</g>''')
    # ink stamps (bottom-right quadrant)
    express=(f'<g transform="translate(34,{H-190}) rotate(-6)"><rect width="104" height="34" rx="3" fill="none" stroke="#1f4f9a" stroke-width="2.4" opacity=".85"/><text x="52" y="23" text-anchor="middle" font-family="CinzelX" font-size="14" fill="#1f4f9a" letter-spacing="2" opacity=".85">EXPRESS</text></g>' if service.startswith('EXPRESS') else '')
    s.append(f'''<g filter="url(#ink{uid})">
  <g transform="translate({W-108},{H-128}) rotate(-12)">
    <rect width="92" height="34" rx="3" fill="none" stroke="#8e1d16" stroke-width="2.4" opacity=".85"/>
    <text x="46" y="23" text-anchor="middle" font-family="CinzelX" font-size="15" fill="#8e1d16" letter-spacing="2" opacity=".85">GRADED</text>
  </g>
  <g transform="translate({W-62},{H-50})" opacity=".7">
    <circle r="30" fill="none" stroke="#2f2a4a" stroke-width="2"/><circle r="22" fill="none" stroke="#2f2a4a" stroke-width="1"/>
    {"" if game else '<text y="4" text-anchor="middle" font-family="InterS" font-size="8" fill="#2f2a4a" letter-spacing="1">20 NOV</text>'}
    <path d="M-60,-6 h-40 M-60,0 h-48 M-60,6 h-40" stroke="#2f2a4a" stroke-width="1.6"/>
  </g>
  <text x="{W*0.06}" y="{H*0.93}" font-family="CinzelX" font-size="10" fill="#5c2f12" opacity=".45" letter-spacing="2.5" transform="rotate(-2 {W*0.06} {H*0.93})">HANDLE WITH CARE</text>
  {express}
</g>''')
    # twine: two strands each way
    cx,cy=W*0.5,H*0.5
    for o in (-3.5,3.5):
        s.append(f'<rect x="{cx-3+o}" y="-4" width="6" height="{H+8}" rx="3" fill="url(#ropeV{uid})" filter="url(#soft{uid})"/>')
        s.append(f'<rect x="-4" y="{cy-3+o}" width="{W+8}" height="6" rx="3" fill="url(#rope{uid})" filter="url(#soft{uid})"/>')
    # bow loops and tails
    s.append(f'''<g filter="url(#soft{uid})">
  <path d="M{cx},{cy} C{cx-70},{cy-80} {cx-110},{cy-10} {cx},{cy}" fill="none" stroke="url(#rope{uid})" stroke-width="6" stroke-linecap="round"/>
  <path d="M{cx},{cy} C{cx+70},{cy-80} {cx+110},{cy-10} {cx},{cy}" fill="none" stroke="url(#rope{uid})" stroke-width="6" stroke-linecap="round"/>
  <path d="M{cx},{cy} C{cx-20},{cy+40} {cx-46},{cy+70} {cx-60},{cy+112}" fill="none" stroke="url(#ropeV{uid})" stroke-width="5.5" stroke-linecap="round"/>
  <path d="M{cx},{cy} C{cx+22},{cy+46} {cx+30},{cy+80} {cx+52},{cy+118}" fill="none" stroke="url(#ropeV{uid})" stroke-width="5.5" stroke-linecap="round"/>
</g>''')
    if game:
        s.append('</svg>'); return ''.join(s)
    # wax seal
    blob="M190,196 C214,194 234,206 242,222 C252,238 250,262 240,278 C232,294 214,306 192,306 C168,308 148,296 140,280 C130,262 128,238 140,222 C148,206 166,198 190,196 Z"
    star="M190,226 L196,244 L214,250 L196,256 L190,274 L184,256 L166,250 L184,244 Z"
    face=f'''<path d="{blob}" fill="url(#wax{uid})"/><circle cx="190" cy="251" r="44" fill="url(#waxIn{uid})" opacity=".9"/><circle cx="190" cy="251" r="27" fill="none" stroke="#4d0a06" stroke-opacity=".55"/><path d="{star}" fill="#c9442f"/>'''
    if state=="cracking":
        s.append(f'''<defs><clipPath id="L{uid}"><path d="M120,180 L190,180 L184,214 L196,232 L186,252 L198,272 L188,296 L194,320 L120,320 Z"/></clipPath>
  <clipPath id="R{uid}"><path d="M260,180 L190,180 L184,214 L196,232 L186,252 L198,272 L188,296 L194,320 L260,320 Z"/></clipPath></defs>
<g filter="url(#soft{uid})">
  <g transform="translate(-12,5) rotate(-10 165 250)" clip-path="url(#L{uid})">{face}</g>
  <g transform="translate(13,-4) rotate(9 215 250)" clip-path="url(#R{uid})">{face}</g>
  <circle cx="128" cy="216" r="5" fill="#9b1f17"/><circle cx="256" cy="302" r="4" fill="#9b1f17"/><circle cx="250" cy="204" r="3" fill="#b22a1e"/>
  <path d="M116,250 l-26,-4 M266,246 l28,-6 M190,178 l2,-26 M146,302 l-18,22 M236,304 l16,22" stroke="#ffe3a0" stroke-width="2.4" stroke-linecap="round" opacity=".9"/>
</g>''')
    else:
        s.append(f'''<g filter="url(#soft{uid})">
  <path d="{blob}" fill="url(#wax{uid})"/>
  <circle cx="190" cy="251" r="44" fill="url(#waxIn{uid})" opacity=".9"/>
  <circle cx="190" cy="251" r="44" fill="none" stroke="#e0644e" stroke-opacity=".35" stroke-width="1.2"/>
  <circle cx="190" cy="251" r="27" fill="none" stroke="#4d0a06" stroke-opacity=".55" stroke-width="1"/>
  <path d="{star}" fill="#5a0d09" opacity=".75" transform="translate(1,1.5)"/>
  <path d="{star}" fill="#c9442f"/>
  <text font-family="Cinzel" font-size="7.4" fill="#f1a08a" fill-opacity=".75" letter-spacing="1.6"><textPath href="#ring{uid}" startOffset="2%">WAYPOINT · GRADING · GUILD · EST. 2026 ·</textPath></text>
  <ellipse cx="174" cy="226" rx="16" ry="7" fill="#fff" opacity=".18" transform="rotate(-30 174 226)"/>
</g>''')
    s.append('</svg>')
    return "".join(s)
if __name__=="__main__":
    out=sys.argv[1]
    for st in ("sealed","cracking","open"):
        open(f"{out}/parcel_{st}.svg","w").write(parcel(st,st[:2]))
