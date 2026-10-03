# helium/backup.py's LevelDB reader and writer, checked against real LevelDB.
# Runs on the devbox: uv run --no-project --python 3.12 --with plyvel python tests/test_helium_backup.py
import sys
import tempfile
from pathlib import Path

import plyvel

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'helium'))
from backup import read_leveldb, write_leveldb

items = {f'key{i}'.encode(): f'"value {i} {"x" * (i % 50)}"'.encode() for i in range(5000)}
items[b'big'] = b'"' + b'y' * 100_000 + b'"'   # spans several 32 KiB log blocks

with tempfile.TemporaryDirectory() as tmp:
    ours, theirs = Path(tmp, 'ours'), Path(tmp, 'theirs')

    write_leveldb(ours, items)
    db = plyvel.DB(str(ours), paranoid_checks=True)   # fails on a bad checksum or MANIFEST
    assert dict(db) == items
    db.close()

    db = plyvel.DB(str(theirs), create_if_missing=True)
    for k, v in items.items():
        db.put(k, v)
    db.compact_range()                                 # into snappy-compressed .ldb tables
    db.put(b'key1', b'"changed"')                      # newer entries stay in the .log
    db.delete(b'key2')
    db.close()
    assert any(f.suffix == '.ldb' for f in theirs.iterdir())
    expected = dict(items)
    expected[b'key1'] = b'"changed"'
    del expected[b'key2']
    assert read_leveldb(theirs) == expected

print('ok')
