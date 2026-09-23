# Third-party notices - zxing-wasm reader

EnactSpace redistributes the reader-only Web artifacts from
[zxing-wasm 3.1.3](https://github.com/Sec-ant/zxing-wasm/tree/v3.1.3):

- `index.js`, derived from `dist/iife/reader/index.js`
- `zxing_reader.wasm`, derived from `dist/reader/zxing_reader.wasm`

## Provenance and integrity

- Upstream package: `zxing-wasm`
- Upstream version/tag: `3.1.3` / `v3.1.3`
- Upstream repository: <https://github.com/Sec-ant/zxing-wasm>
- Embedded ZXing-C++ commit: `a17fd9dc65d6aa0dd2f660fdfca7a6a6613d938f`
- Local `index.js` (repository LF form) SHA-256:
  `AD5E64FAD6ECB81F0526C6B101EE0FE6C2428B68078A24FBFAFC48EA57863986`
- `zxing_reader.wasm` SHA-256:
  `2EBDA08A93EEA3EFCD8399CDA6B276E6A0B1DE4FEC60B4D8988A047DE4C6D1BA`

The repository `.gitattributes` file enforces LF for the vendored `index.js`
and treats the WASM payload as binary so these integrity values remain stable
across supported checkout platforms.

The vendored IIFE script was modified so its `locateFile` override loads
`zxing_reader.wasm` from the same local EnactSpace vendor directory instead
of a public CDN. No ZXing-C++ source file was modified.

## Applicable licenses

- zxing-wasm-specific JavaScript/TypeScript code: MIT License.
- ZXing-C++ and `src/cpp/ZXingWasm.cpp`: Apache License 2.0.

Readable copies of those licenses are distributed beside the artifacts as
`LICENSE-MIT.txt` and `LICENSE-APACHE-2.0.txt`.

The upstream project also documents Zint under the BSD 3-Clause License for
writer functionality. This EnactSpace payload uses the reader-only target,
for which upstream sets `ZXING_WRITERS=OFF`; Zint is therefore not expected
to be linked into `zxing_reader.wasm`. If the vendored payload is later
replaced with the writer or full build, the Zint BSD notice must be added and
the provenance review repeated.
