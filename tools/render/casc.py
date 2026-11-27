"""Read files out of a local World of Warcraft install (Blizzard's CASC storage), by FileDataID or by path.

Only the standard library. Local use: the files stay on this machine (cached under tools/harness/.cache/game,
which git ignores) and are never committed.

    from casc import Casc
    c = Casc()                                  # finds the install and the WoW Forever build (product "wowf")
    data = c.read(123456)                       # a FileDataID
    data = c.read("Interface\\Buttons\\WHITE8X8.blp")

The install is found from $WOW_DIR, else the default Battle.net folder on D: or C:. The product is $WOW_PRODUCT
(default "wowf", WoW Forever).
"""
import os, struct, zlib, pickle, glob, hashlib

DEFAULT_DIRS = ["/mnt/d/Program Files (x86)/Battle.net/World of Warcraft", "/mnt/c/Program Files (x86)/World of Warcraft",
                "D:/Program Files (x86)/Battle.net/World of Warcraft", "C:/Program Files (x86)/World of Warcraft"]
HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(HERE, "..", "harness", ".cache", "game")

LOCALE_ENUS = 0x2


def _rot(x, k):
    return ((x << k) | (x >> (32 - k))) & 0xFFFFFFFF


def hashlittle2(data, pc=0, pb=0):
    """Bob Jenkins' lookup3 hashlittle2: the root file's name hash of a path."""
    length = len(data)
    a = b = c = (0xDEADBEEF + length + pc) & 0xFFFFFFFF
    c = (c + pb) & 0xFFFFFFFF
    i = 0
    while length > 12:
        a = (a + struct.unpack_from("<I", data, i)[0]) & 0xFFFFFFFF
        b = (b + struct.unpack_from("<I", data, i + 4)[0]) & 0xFFFFFFFF
        c = (c + struct.unpack_from("<I", data, i + 8)[0]) & 0xFFFFFFFF
        a = (a - c) & 0xFFFFFFFF; a ^= _rot(c, 4); c = (c + b) & 0xFFFFFFFF
        b = (b - a) & 0xFFFFFFFF; b ^= _rot(a, 6); a = (a + c) & 0xFFFFFFFF
        c = (c - b) & 0xFFFFFFFF; c ^= _rot(b, 8); b = (b + a) & 0xFFFFFFFF
        a = (a - c) & 0xFFFFFFFF; a ^= _rot(c, 16); c = (c + b) & 0xFFFFFFFF
        b = (b - a) & 0xFFFFFFFF; b ^= _rot(a, 19); a = (a + c) & 0xFFFFFFFF
        c = (c - b) & 0xFFFFFFFF; c ^= _rot(b, 4); b = (b + a) & 0xFFFFFFFF
        length -= 12
        i += 12
    if length == 0:
        return c, b
    tail = data[i:] + b"\0" * (12 - length)
    x, y, z = struct.unpack("<III", tail)
    if length >= 9: c = (c + z) & 0xFFFFFFFF
    if length >= 5: b = (b + y) & 0xFFFFFFFF
    a = (a + x) & 0xFFFFFFFF
    c ^= b; c = (c - _rot(b, 14)) & 0xFFFFFFFF
    a ^= c; a = (a - _rot(c, 11)) & 0xFFFFFFFF
    b ^= a; b = (b - _rot(a, 25)) & 0xFFFFFFFF
    c ^= b; c = (c - _rot(b, 16)) & 0xFFFFFFFF
    a ^= c; a = (a - _rot(c, 4)) & 0xFFFFFFFF
    b ^= a; b = (b - _rot(a, 14)) & 0xFFFFFFFF
    c ^= b; c = (c - _rot(b, 24)) & 0xFFFFFFFF
    return c, b


def name_hash(path):
    p = path.replace("/", "\\").upper().encode("utf-8")
    c, b = hashlittle2(p)
    return (c << 32) | b


def blte(data):
    """Decode a BLTE blob."""
    if data[:4] != b"BLTE":
        raise ValueError("not BLTE")
    hsize = struct.unpack(">I", data[4:8])[0]
    out = []
    if hsize == 0:
        chunks = [(len(data) - 8, None)]
        pos = 8
    else:
        n = struct.unpack(">I", b"\0" + data[9:12])[0]
        chunks = []
        p = 12
        for _ in range(n):
            cs, ds = struct.unpack(">II", data[p:p + 8])
            chunks.append((cs, ds))
            p += 24
        pos = hsize
    for cs, _ in chunks:
        ch = data[pos:pos + cs]
        pos += cs
        mode = ch[:1]
        if mode == b"N":
            out.append(ch[1:])
        elif mode == b"Z":
            out.append(zlib.decompress(ch[1:]))
        elif mode == b"F":
            out.append(blte(ch[1:]))
        elif mode == b"E":
            raise PermissionError("encrypted")
        else:
            raise ValueError("unknown BLTE chunk mode %r" % mode)
    return b"".join(out)


class Casc:
    def __init__(self, wow_dir=None, product=None):
        self.dir = wow_dir or os.environ.get("WOW_DIR") or next((d for d in DEFAULT_DIRS if os.path.isdir(d)), None)
        if not self.dir:
            raise FileNotFoundError("no WoW install found: set WOW_DIR")
        self.product = product or os.environ.get("WOW_PRODUCT") or "wowf"
        self.data = os.path.join(self.dir, "Data")
        self._files = {}
        self._build_config()
        os.makedirs(CACHE, exist_ok=True)
        self._load_index()
        self._load_encoding()
        self._load_root()

    # -- configuration -----------------------------------------------------
    def _build_config(self):
        rows = open(os.path.join(self.dir, ".build.info"), encoding="utf-8").read().splitlines()
        head = [h.split("!")[0] for h in rows[0].split("|")]
        for r in rows[1:]:
            v = dict(zip(head, r.split("|")))
            if v.get("Product") == self.product:
                self.version = v.get("Version")
                bk = v["Build Key"]
                break
        else:
            raise KeyError("product %s is not installed" % self.product)
        cfg = {}
        for line in open(os.path.join(self.data, "config", bk[:2], bk[2:4], bk), encoding="utf-8"):
            if "=" in line:
                k, _, val = line.partition("=")
                cfg[k.strip()] = val.split()
        self.cfg = cfg
        self.build_key = bk

    def _cache_path(self, what):
        return os.path.join(CACHE, "%s-%s.pickle" % (what, self.build_key))

    # -- local index: encoding key (first 9 bytes) -> (archive, offset, size) --------------
    def _load_index(self):
        best = {}
        for p in glob.glob(os.path.join(self.data, "data", "*.idx")):
            name = os.path.basename(p)
            bucket, ver = int(name[:2], 16), int(name[2:10], 16)
            if bucket not in best or ver > best[bucket][0]:
                best[bucket] = (ver, p)
        self.index = {}
        for _, p in best.values():
            d = open(p, "rb").read()
            hlen = struct.unpack_from("<I", d, 0)[0]
            ver, bucket, extra, slen, olen, klen, obits = struct.unpack_from("<HBBBBBB", d, 8)
            pos = (8 + hlen + 15) & ~15
            dlen = struct.unpack_from("<I", d, pos)[0]
            pos += 8
            esz = klen + olen + slen
            end = pos + dlen
            mask = (1 << obits) - 1
            while pos + esz <= end:
                key = d[pos:pos + klen]
                off = int.from_bytes(d[pos + klen:pos + klen + olen], "big")
                size = struct.unpack_from("<I", d, pos + klen + olen)[0]
                pos += esz
                if key not in self.index:
                    self.index[key] = (off >> obits, off & mask, size)

    def read_ekey(self, ekey):
        e = self.index.get(ekey[:9])
        if not e:
            raise KeyError("not in the local storage: " + ekey.hex())
        arch, off, size = e
        f = self._files.get(arch)
        if not f:
            f = self._files[arch] = open(os.path.join(self.data, "data", "data.%03d" % arch), "rb")
        f.seek(off)
        raw = f.read(size)
        return blte(raw[30:])

    # -- encoding: content key -> encoding key ------------------------------------------------
    def _load_encoding(self):
        cp = self._cache_path("encoding")
        if os.path.exists(cp):
            self.enc = pickle.load(open(cp, "rb"))
            return
        d = self.read_ekey(bytes.fromhex(self.cfg["encoding"][1]))
        assert d[:2] == b"EN"
        ckl, ekl = d[3], d[4]
        cpage = struct.unpack(">H", d[5:7])[0] * 1024
        ccount = struct.unpack(">I", d[9:13])[0]
        espec = struct.unpack(">I", d[18:22])[0]
        pos = 22 + espec + ccount * (ckl + 16)
        enc = {}
        for _ in range(ccount):
            page = d[pos:pos + cpage]
            pos += cpage
            p = 0
            while p + 6 + ckl <= len(page):
                n = page[p]
                if n == 0:
                    break
                ck = page[p + 6:p + 6 + ckl]
                ek = page[p + 6 + ckl:p + 6 + ckl + ekl]
                enc[ck] = ek
                p += 6 + ckl + ekl * n
        self.enc = enc
        pickle.dump(enc, open(cp, "wb"))

    def read_ckey(self, ckey):
        ek = self.enc.get(ckey)
        if not ek:
            raise KeyError("no encoding entry for " + ckey.hex())
        return self.read_ekey(ek)

    # -- root: FileDataID -> content key, name hash -> FileDataID ---------------------------
    def _load_root(self):
        cp = self._cache_path("root")
        if os.path.exists(cp):
            self.fdid, self.names = pickle.load(open(cp, "rb"))
            return
        d = self.read_ckey(bytes.fromhex(self.cfg["root"][0]))
        fdid, names = {}, {}
        pos = 0
        version = 0
        if d[:4] == b"TSFM":
            a, b = struct.unpack_from("<II", d, 4)
            if a == 24 and b in (1, 2):
                version = b
                pos = 24
            else:
                pos = 12
        else:
            raise ValueError("old root format is not supported")
        while pos < len(d):
            if version == 2:
                count, locale, f1, f2 = struct.unpack_from("<IIII", d, pos)
                f3 = d[pos + 16]
                content = f1 | f2 | (f3 << 17)
                pos += 17
            else:
                count, content, locale = struct.unpack_from("<III", d, pos)
                pos += 12
            deltas = struct.unpack_from("<%di" % count, d, pos)
            pos += 4 * count
            ckeys = d[pos:pos + 16 * count]
            pos += 16 * count
            has_names = not (content & 0x10000000)
            hashes = None
            if has_names:
                hashes = struct.unpack_from("<%dQ" % count, d, pos)
                pos += 8 * count
            want = (locale & LOCALE_ENUS) or locale == 0xFFFFFFFF
            fid = -1
            for i in range(count):
                fid = fid + 1 + deltas[i]
                if not want:
                    continue
                ck = ckeys[16 * i:16 * i + 16]
                if fid not in fdid or (content & 0x80) == 0:   # (0x80: low-violence copies)
                    fdid[fid] = ck
                if hashes:
                    names.setdefault(hashes[i], fid)
        self.fdid, self.names = fdid, names
        pickle.dump((fdid, names), open(cp, "wb"))

    # -- reading ----------------------------------------------------------------------------
    def file_id(self, path):
        return self.names.get(name_hash(path))

    def read(self, what):
        """The bytes of a file, by FileDataID (int) or path (str); None if it isn't in this build."""
        fid = what if isinstance(what, int) else self.file_id(what)
        if fid is None or fid not in self.fdid:
            return None
        cp = os.path.join(CACHE, "files", "%d" % fid)
        if os.path.exists(cp):
            return open(cp, "rb").read()
        try:
            data = self.read_ckey(self.fdid[fid])
        except (KeyError, PermissionError):
            return None
        os.makedirs(os.path.dirname(cp), exist_ok=True)
        open(cp, "wb").write(data)
        return data


if __name__ == "__main__":
    import sys, time
    t = time.time()
    c = Casc()
    print("WoW %s (%s): %d index entries, %d encoding, %d files, %d names  (%.1fs)" % (
        c.version, c.product, len(c.index), len(c.enc), len(c.fdid), len(c.names), time.time() - t))
    for a in sys.argv[1:]:
        d = c.read(int(a) if a.isdigit() else a)
        print(a, "->", None if d is None else "%d bytes, starts %r" % (len(d), d[:4]))
