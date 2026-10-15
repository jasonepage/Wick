// SPDX-License-Identifier: MPL-2.0
//
//  zip.ts: writes a plain .zip file with no compression ("stored" entries).
//
//  Used by the dance clip exporter to hand over a PNG sequence as one file.
//  PNGs are already compressed, so storing them as they are loses nothing, and
//  it keeps this to a few dozen lines with no library. Pure, so it is tested
//  in tests/zip.test.ts.
//

export interface ZipEntry {
  name: string;
  data: Uint8Array;
}

let crcTable: Uint32Array | null = null;

/** CRC-32 of `data`, the checksum zip files use. */
export function crc32(data: Uint8Array): number {
  if (!crcTable) {
    crcTable = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      crcTable[n] = c >>> 0;
    }
  }
  let crc = 0xffffffff;
  for (let i = 0; i < data.length; i++) crc = crcTable[(crc ^ data[i]!) & 0xff]! ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

/** The bytes of a zip file holding `entries`, in order. */
export function zipStore(entries: ZipEntry[]): Uint8Array<ArrayBuffer> {
  const enc = new TextEncoder();
  const locals: Uint8Array[] = [];
  const centrals: Uint8Array[] = [];
  let offset = 0;
  // A fixed MS-DOS time stamp (1 Jan 2020, 00:00), since the files have no real date.
  const dosTime = 0;
  const dosDate = ((2020 - 1980) << 9) | (1 << 5) | 1;

  for (const e of entries) {
    const name = enc.encode(e.name);
    const crc = crc32(e.data);
    const local = new DataView(new ArrayBuffer(30 + name.length));
    local.setUint32(0, 0x04034b50, true);
    local.setUint16(4, 20, true);              // version needed
    local.setUint16(6, 0x0800, true);          // flags: names are UTF-8
    local.setUint16(8, 0, true);               // method: stored
    local.setUint16(10, dosTime, true);
    local.setUint16(12, dosDate, true);
    local.setUint32(14, crc, true);
    local.setUint32(18, e.data.length, true);
    local.setUint32(22, e.data.length, true);
    local.setUint16(26, name.length, true);
    local.setUint16(28, 0, true);
    new Uint8Array(local.buffer).set(name, 30);

    const central = new DataView(new ArrayBuffer(46 + name.length));
    central.setUint32(0, 0x02014b50, true);
    central.setUint16(4, 20, true);            // made by
    central.setUint16(6, 20, true);            // version needed
    central.setUint16(8, 0x0800, true);
    central.setUint16(10, 0, true);
    central.setUint16(12, dosTime, true);
    central.setUint16(14, dosDate, true);
    central.setUint32(16, crc, true);
    central.setUint32(20, e.data.length, true);
    central.setUint32(24, e.data.length, true);
    central.setUint16(28, name.length, true);
    central.setUint16(30, 0, true);            // extra
    central.setUint16(32, 0, true);            // comment
    central.setUint16(34, 0, true);            // disk
    central.setUint16(36, 0, true);            // internal attributes
    central.setUint32(38, 0, true);            // external attributes
    central.setUint32(42, offset, true);
    new Uint8Array(central.buffer).set(name, 46);

    locals.push(new Uint8Array(local.buffer), e.data);
    centrals.push(new Uint8Array(central.buffer));
    offset += local.byteLength + e.data.length;
  }

  const centralSize = centrals.reduce((n, c) => n + c.length, 0);
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, 0x06054b50, true);
  end.setUint16(4, 0, true);
  end.setUint16(6, 0, true);
  end.setUint16(8, entries.length, true);
  end.setUint16(10, entries.length, true);
  end.setUint32(12, centralSize, true);
  end.setUint32(16, offset, true);
  end.setUint16(20, 0, true);

  const out = new Uint8Array(new ArrayBuffer(offset + centralSize + 22));
  let at = 0;
  for (const part of [...locals, ...centrals, new Uint8Array(end.buffer)]) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}
