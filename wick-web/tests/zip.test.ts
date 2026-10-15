// SPDX-License-Identifier: MPL-2.0
//
//  The stored-only zip writer used for PNG sequences.
//

import { test } from "node:test";
import assert from "node:assert/strict";
import { zipStore, crc32 } from "../src/game/zip.ts";

test("crc32 matches the known value for 'hello'", () => {
  assert.equal(crc32(new TextEncoder().encode("hello")), 0x3610a686);
});

test("a stored zip has the right markers, counts and sizes", () => {
  const a = new TextEncoder().encode("one");
  const b = new TextEncoder().encode("twotwo");
  const z = zipStore([{ name: "a.txt", data: a }, { name: "b.txt", data: b }]);
  const v = new DataView(z.buffer);
  assert.equal(v.getUint32(0, true), 0x04034b50);                 // first local header
  const endAt = z.length - 22;
  assert.equal(v.getUint32(endAt, true), 0x06054b50);             // end of central directory
  assert.equal(v.getUint16(endAt + 8, true), 2);                  // two entries
  const centralAt = v.getUint32(endAt + 16, true);
  assert.equal(v.getUint32(centralAt, true), 0x02014b50);
  // Local header (30 + name) + data for each entry, then the central directory.
  assert.equal(centralAt, (30 + 5 + 3) + (30 + 5 + 6));
  // The second entry's central record points at its local header.
  const second = centralAt + 46 + 5;
  assert.equal(v.getUint32(second + 42, true), 30 + 5 + 3);
});
