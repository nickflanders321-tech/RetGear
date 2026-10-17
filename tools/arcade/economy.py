"""Waypath+ card game economy check. Simulates a 1-60 climb: coins earned, packs bought, extras sold back,
and reports how much of the Master Set (every card, any finish) a player owns at level 60.
Usage: python3 tools/arcade/economy.py [income] [coins_per_card] [free_packs] [set_rewards]
Defaults: 10155 coins, 10.4 coins a card, 190 free packs (daily + bonuses + the level 60 gift), 800 from set rewards. Tune COLLECTOR_LUCK in Arcade.lua to hit ~75%.
Card counts per tier and the draw weights mirror Arcade.lua (TIER, FINISH) and ArcadeCards.lua."""
import random, sys, statistics as st
CNT = [220, 272, 143, 410, 161]; W = [44, 26, 14, 12, 4]
FW = [70, 22, 6, 2]; SELL = [1, 3, 10, 30]
N = sum(CNT)
start = [sum(CNT[:t]) for t in range(5)]

def run(q, price_card, income, freepacks, sets_bonus, seed):
    rnd = random.Random(seed)
    own = [[0] * 4 for _ in range(N)]
    missing = list(range(N)); pos = {c: i for i, c in enumerate(missing)}
    coins = 0.0; cards = 0; fp = 0.0
    for _ in range(60):
        coins += income / 60 + sets_bonus / 60
        fp += freepacks / 60
        n_cards = 0
        while fp >= 1: n_cards += 5; fp -= 1
        k = int(coins // price_card); n_cards += k; coins -= k * price_card
        for _ in range(n_cards):
            if missing and rnd.random() < q:
                c = missing[rnd.randrange(len(missing))]
            else:
                x = rnd.random() * sum(W); t = 0
                for i, w in enumerate(W):
                    x -= w
                    if x <= 0: t = i; break
                c = start[t] + rnd.randrange(CNT[t])
            x = rnd.random() * 100; f = 0
            for i, w in enumerate(FW):
                x -= w
                if x <= 0: f = i; break
            if sum(own[c]) == 0:
                i = pos.pop(c); last = missing.pop()
                if last != c: missing[i] = last; pos[last] = i
                own[c][f] = 1
            elif own[c][f] == 0: own[c][f] = 1
            else: coins += SELL[f]
            cards += 1
    return (N - len(missing)) / N, cards

if __name__ == "__main__":
    a = sys.argv[1:] + [None] * 4
    income = float(a[0] or 10155); price = float(a[1] or 10.4); free = float(a[2] or 190); sb = float(a[3] or 800)
    for q in (0, 0.05, 0.10, 0.15, 0.20):
        r = [run(q, price, income, free, sb, s)[0] for s in range(40)]
        print("luck %.2f: median %.0f%%  (10th-90th percentile %.0f%%-%.0f%%)" % (q, 100 * st.median(r), 100 * sorted(r)[4], 100 * sorted(r)[36]))
