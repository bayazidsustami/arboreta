import sys, math, random, pygame, pygame.midi, re, collections, itertools, time
# ------------------------------------------------------------
# Simple iambic parser: treat every second syllable as stressed
def syllabify(word):
    # crude vowel groups as syllable count
    return re.findall(r'[aeiouy]+', word.lower())
def parse_sonnets(text):
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    stressed = []                     # list of (line_idx, syl_idx) for stresses
    for i,line in enumerate(lines[:14]):   # first 14 lines = sonnet
        syls = sum((syllabify(w) for w in line.split()), [])
        for j,_ in enumerate(syls):
            if j%2==1:                # every second syllable stressed
                stressed.append((i,j))
    return stressed, lines
# ------------------------------------------------------------
# Derive a reversible elementary cellular automaton rule from rhyme scheme
def rhyme_scheme(lines):
    # naive: last word rhyme if last 2 letters equal
    last_words = [re.sub(r'[^a-z]', '', l.split()[-1].lower())[-2:] for l in lines[:14]]
    groups = {}
    for idx, rw in enumerate(last_words):
        groups.setdefault(rw, []).append(idx)
    scheme = [chr(65+i) for i in range(len(groups)) for _ in groups[chr(65+i)]]
    return scheme
def rule_from_scheme(scheme):
    # map scheme letters to bits, create 8-bit rule (reversible iff rule==90 or 150 etc.)
    # we'll pick rule 90 (binary 01011010) for simplicity
    return 90
# ------------------------------------------------------------
# Cellular automaton generator (1D reversible)
def ca_generator(rule, width, steps):
    rule_bits = [(rule>>i)&1 for i in range(8)]
    state = [0]*width
    state[width//2]=1
    for _ in range(steps):
        yield list(state)
        new = []
        for i in range(width):
            left = state[i-1] if i>0 else 0
            centre = state[i]
            right = state[i+1] if i<width-1 else 0
            idx = (left<<2)|(centre<<1)|right
            new.append(rule_bits[idx])
        state=new
# ------------------------------------------------------------
# Particle class driven by CA rows
class Particle:
    def __init__(self,pos,color,vel):
        self.pos=pos
        self.color=color
        self.vel=vel
    def update(self,dt):
        self.pos[0]+=self.vel[0]*dt
        self.pos[1]+=self.vel[1]*dt
    def draw(self,surf):
        pygame.draw.circle(surf,self.color, (int(self.pos[0]),int(self.pos[1])), 4)
# ------------------------------------------------------------
def main():
    if len(sys.argv)<2:
        print("Usage: python script.py <sonnet.txt>")
        return
    with open(sys.argv[1],'r',encoding='utf8') as f:
        text=f.read()
    stressed, lines=parse_sonnets(text)
    scheme=rhyme_scheme(lines)
    rule=rule_from_scheme(scheme)

    # init pygame & midi
    pygame.init()
    pygame.midi.init()
    player=pygame.midi.Output(pygame.midi.get_default_output_id())
    player.set_instrument(0)
    screen=pygame.display.set_mode((800,600))
    clock=pygame.time.Clock()

    # CA for particle trajectories
    ca_rows=list(ca_generator(rule, 40, 200))
    particles=[]

    # map stressed syllable to particle spawn
    spawn_idx=0
    start_time=time.time()
    running=True
    while running:
        dt=clock.tick(60)/1000.0
        for e in pygame.event.get():
            if e.type==pygame.QUIT:
                running=False

        now=time.time()-start_time
        # spawn particles according to stressed positions over time
        while spawn_idx<len(stressed) and stressed[spawn_idx][0]*0.5 < now:
            line, syl = stressed[spawn_idx]
            # midi note based on line number
            note=60+line
            player.note_on(note,127)
            # particle initial pos
            x=400+ (syl-10)*5
            y=100+ line*30
            # colour based on rhyme group
            col=pygame.Color( (line*30)%256, (syl*20)%256, 150)
            # velocity from CA row
            row=ca_rows[line%len(ca_rows)]
            vel=[ (row[i]-0.5)*200 for i in range(len(row))][:2]
            if not vel: vel=[0,0]
            particles.append(Particle([x,y],col,vel))
            spawn_idx+=1

        screen.fill((0,0,0))
        for p in particles:
            p.update(dt)
            p.draw(screen)
        pygame.display.flip()

    player.close()
    pygame.midi.quit()
    pygame.quit()

if __name__=="__main__":
    main()