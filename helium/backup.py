#!/usr/bin/env python3
"""Backs up Helium's extensions, flags and settings from this Mac into helium/, for setup.ps1 to restore on
laptops. Quit Helium first, then: python3 helium/backup.py [user data folder, if not Helium's on this Mac]

Extension data is LevelDB. It is read here and written back as a fresh database without the keys in DROP, so
user IDs never reach the public repo. Standard library only: macOS's /usr/bin/python3 is 3.9.
"""
import json
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

USER_DATA = Path.home() / 'Library/Application Support/net.imput.helium'
OUT = Path(__file__).resolve().parent

# Preferences copied to laptops, as dotted paths into Default/Preferences.
PREFS = [
    'helium',                        # layout, rounded frame, services consent, onboarding done
    'browser.theme',
    'extensions.theme',
    'extensions.pinned_extensions',
    'vertical_tabs',
    'download.prompt_for_download',
    'search.suggest_enabled',
    'spellcheck.dictionaries',
]

# Web Store extensions whose data is not backed up: 1Password signs in by itself, Privacy Badger only held its
# built-in tracker list. The uBlock Origin built into Helium isn't from the Web Store, so it is skipped too
# (it only held defaults and filter list cache).
SKIP_EXTENSIONS = {
    'aeblfdkhhhdcdjpifhhbdiojplfjncoa',   # 1Password
    'pkehgijcmpdhfbdbbnkijodmdjhbjlgp',   # Privacy Badger
}

# Keys kept out of the public repo: per-install user IDs (SponsorBlock, Return YouTube Dislike) and
# FB Purity's keys, which are named after the Facebook account ID. Dropped IDs found anywhere else stop the backup.
DROP = re.compile(r'^(userID|userId|registrationConfirmed)$|^(fbpoptsjson|lastfriendcheck|lastnewscheck)-\d+$')

STORES = ['Local Extension Settings', 'Sync Extension Settings']


# --- LevelDB reading ---------------------------------------------------------

def varint(buf, pos):
    result = shift = 0
    while True:
        b = buf[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if b < 0x80:
            return result, pos
        shift += 7


def snappy_decompress(buf):
    size, pos = varint(buf, 0)
    out = bytearray()
    while pos < len(buf):
        tag = buf[pos]
        pos += 1
        kind = tag & 3
        if kind == 0:   # literal
            n = tag >> 2
            if n >= 60:
                extra = n - 59
                n = int.from_bytes(buf[pos:pos + extra], 'little')
                pos += extra
            n += 1
            out += buf[pos:pos + n]
            pos += n
            continue
        if kind == 1:
            n = ((tag >> 2) & 7) + 4
            offset = ((tag >> 5) << 8) | buf[pos]
            pos += 1
        elif kind == 2:
            n = (tag >> 2) + 1
            offset = int.from_bytes(buf[pos:pos + 2], 'little')
            pos += 2
        else:
            n = (tag >> 2) + 1
            offset = int.from_bytes(buf[pos:pos + 4], 'little')
            pos += 4
        start = len(out) - offset
        for i in range(n):   # byte by byte: a copy may overlap what it is writing
            out.append(out[start + i])
    assert len(out) == size, 'snappy: bad length'
    return bytes(out)


def log_records(data):
    """Records from a LevelDB log (.log and MANIFEST files): 32 KiB blocks of fragments."""
    record = b''
    pos = 0
    while pos + 7 <= len(data):
        if 32768 - pos % 32768 < 7:   # block trailer too small for a header
            pos += 32768 - pos % 32768
            continue
        length, kind = struct.unpack_from('<HB', data, pos + 4)
        fragment = data[pos + 7:pos + 7 + length]
        pos += 7 + length
        if kind == 0:   # zero padding / preallocated space
            continue
        record = fragment if kind in (1, 2) else record + fragment
        if kind in (1, 4):
            yield record


def batch_entries(batch):
    """(key, seq, value or None for delete) from a write batch."""
    seq, count = struct.unpack_from('<QI', batch, 0)
    pos = 12
    for i in range(count):
        tag = batch[pos]
        n, pos = varint(batch, pos + 1)
        key = batch[pos:pos + n]
        pos += n
        value = None
        if tag == 1:
            n, pos = varint(batch, pos)
            value = batch[pos:pos + n]
            pos += n
        yield key, seq + i, value


def block_entries(block):
    restarts = struct.unpack_from('<I', block, len(block) - 4)[0]
    end = len(block) - 4 - 4 * restarts
    pos, key = 0, b''
    while pos < end:
        shared, pos = varint(block, pos)
        unshared, pos = varint(block, pos)
        size, pos = varint(block, pos)
        key = key[:shared] + block[pos:pos + unshared]
        pos += unshared
        yield key, block[pos:pos + size]
        pos += size


def read_block(data, handle):
    offset, pos = varint(handle, 0)
    size, _ = varint(handle, pos)
    block, compression = data[offset:offset + size], data[offset + size]
    assert compression in (0, 1), f'unknown block compression {compression}'
    return snappy_decompress(block) if compression == 1 else block


def table_entries(data):
    """(key, seq, value or None) from an .ldb table."""
    footer = data[-48:]
    _, pos = varint(footer, 0)
    _, pos = varint(footer, pos)   # skip the metaindex handle
    for _, handle in block_entries(read_block(data, footer[pos:])):
        for ikey, value in block_entries(read_block(data, handle)):
            tag = int.from_bytes(ikey[-8:], 'little')
            yield ikey[:-8], tag >> 8, value if tag & 0xFF == 1 else None


def read_leveldb(path):
    """Current key/value pairs of a closed LevelDB."""
    # ponytail: reads every table and log in the folder rather than the live set from MANIFEST.
    # Fine for a closed database (LevelDB deletes obsolete files right away); parse MANIFEST if that bites.
    latest = {}
    for f in sorted(path.iterdir()):
        data = f.read_bytes()
        if f.suffix == '.ldb':
            entries = table_entries(data)
        elif f.suffix == '.log':
            entries = (e for r in log_records(data) for e in batch_entries(r))
        else:
            continue
        for key, seq, value in entries:
            if key not in latest or seq > latest[key][0]:
                latest[key] = (seq, value)
    return {k: v for k, (_, v) in sorted(latest.items()) if v is not None}


# --- LevelDB writing ---------------------------------------------------------

CRC_TABLE = []
for i in range(256):
    c = i
    for _ in range(8):
        c = (c >> 1) ^ 0x82F63B78 if c & 1 else c >> 1
    CRC_TABLE.append(c)


def masked_crc32c(data):
    c = 0xFFFFFFFF
    for b in data:
        c = CRC_TABLE[(c ^ b) & 0xFF] ^ (c >> 8)
    c ^= 0xFFFFFFFF
    return (((c >> 15) | (c << 17)) + 0xA282EAD8) & 0xFFFFFFFF


def put_varint(n):
    out = bytearray()
    while n >= 0x80:
        out.append(n & 0x7F | 0x80)
        n >>= 7
    out.append(n)
    return bytes(out)


def log_file(records):
    """LevelDB log file holding the given records, fragmented across 32 KiB blocks."""
    out = bytearray()
    for record in records:
        first = True
        while True:
            room = 32768 - len(out) % 32768
            if room < 7:
                out += bytes(room)
                continue
            fragment, record = record[:room - 7], record[room - 7:]
            kind = (1 if not record else 2) if first else (4 if not record else 3)
            out += struct.pack('<IHB', masked_crc32c(bytes([kind]) + fragment), len(fragment), kind) + fragment
            first = False
            if not record:
                break
    return bytes(out)


def write_leveldb(path, items):
    """A new LevelDB holding items: CURRENT, a MANIFEST and one log that LevelDB replays on first open."""
    path.mkdir(parents=True)
    batch = struct.pack('<QI', 1, len(items)) + b''.join(
        b'\x01' + put_varint(len(k)) + k + put_varint(len(v)) + v for k, v in items.items())
    comparator = b'leveldb.BytewiseComparator'
    edit = (b'\x01' + put_varint(len(comparator)) + comparator   # comparator
            + b'\x02' + put_varint(3)                             # log number
            + b'\x03' + put_varint(4)                             # next file number
            + b'\x04' + put_varint(0))                            # last sequence
    (path / 'MANIFEST-000002').write_bytes(log_file([edit]))
    (path / 'CURRENT').write_bytes(b'MANIFEST-000002\n')
    (path / '000003.log').write_bytes(log_file([batch]))


# --- backup ------------------------------------------------------------------

def pick(prefs, dotted):
    value = prefs
    for part in dotted.split('.'):
        if not isinstance(value, dict) or part not in value:
            return None
        value = value[part]
    return value


def nest(dotted, value, into):
    *parents, last = dotted.split('.')
    for part in parents:
        into = into.setdefault(part, {})
    into[last] = value


def extension_name(folder):
    manifest = json.loads((folder / 'manifest.json').read_text(encoding='utf-8-sig'))
    name = manifest['name']
    msg = re.fullmatch(r'__MSG_(\w+)__', name)
    if msg:   # localized: look the name up in the default locale (message keys are case-insensitive)
        messages = json.loads((folder / '_locales' / manifest['default_locale'] / 'messages.json').read_text(encoding='utf-8-sig'))
        name = next(v['message'] for k, v in messages.items() if k.lower() == msg[1].lower())
    return name


def main():
    if subprocess.run(['pgrep', '-x', 'Helium'], capture_output=True).returncode == 0:
        sys.exit('Quit Helium first: its extension data is only consistent while it is closed.')

    user_data = Path(sys.argv[1]) if len(sys.argv) > 1 else USER_DATA
    profile = user_data / 'Default'
    local_state = json.loads((user_data / 'Local State').read_text())
    prefs = json.loads((profile / 'Preferences').read_text())
    secure = json.loads((profile / 'Secure Preferences').read_text())

    extensions = {ext_id: extension_name(profile / 'Extensions' / info['path'])
                  for ext_id, info in sorted(secure['extensions']['settings'].items()) if info.get('from_webstore')}

    picked = {}
    for dotted in PREFS:
        value = pick(prefs, dotted)
        if value is not None:
            nest(dotted, value, picked)

    flags = local_state.get('browser', {})
    config = json.dumps({
        'extensions': extensions,
        'flags': {k: flags[k] for k in ('enabled_labs_experiments', 'enabled_labs_experiments_origin_lists') if k in flags},
        'preferences': picked,
    }, indent=2, ensure_ascii=False) + '\n'

    stores, secrets = {}, set()
    for store in STORES:
        for src in sorted((profile / store).glob('*')):
            if src.name not in extensions or src.name in SKIP_EXTENSIONS:
                continue
            items = read_leveldb(src)
            dropped = [k for k in items if DROP.search(k.decode())]
            for k in dropped:
                value = json.loads(items.pop(k))
                if isinstance(value, str) and len(value) >= 8:
                    secrets.add(value.encode())
                secrets.update(re.findall(rb'-(\d+)$', k))
            stores[store, src.name] = items
            note = f', dropped {b", ".join(dropped).decode()}' if dropped else ''
            print(f'{extensions[src.name][:30]:30} {store.split()[0]:5} {len(items):3} keys{note}')

    blobs = {'helium.json': [config.encode()]}
    for (store, ext_id), items in stores.items():
        blobs[f'{extensions[ext_id]} ({store})'] = [b for kv in items.items() for b in kv]
    leaks = [where for where, bs in blobs.items() if any(s in b for s in secrets for b in bs)]
    if leaks:
        sys.exit(f'Nothing written: a dropped ID also appears in {", ".join(leaks)}. Add those keys to DROP.')

    (OUT / 'helium.json').write_text(config, encoding='utf-8')
    shutil.rmtree(OUT / 'data', ignore_errors=True)
    for (store, ext_id), items in stores.items():
        if items:
            write_leveldb(OUT / 'data' / store / ext_id, items)
    print(f'{len(extensions)} extensions. Check git diff, then commit.')


if __name__ == '__main__':
    main()
