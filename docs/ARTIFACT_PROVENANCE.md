# Artifact provenance

This document defines the evidence record for future EnactSpace release artifacts. It does not claim that a signed release artifact, store upload, tag, deployment, or public release exists.

## One record per artifact

Copy this table for each artifact after it is built in the authorized environment. Do not pre-fill hashes, signatures, authorities, timestamps, or upload references.

| Field | Recorded value |
| --- | --- |
| Source commit | TO_CONFIRM_EXTERNAL |
| Version / build | TO_CONFIRM_EXTERNAL |
| Platform | TO_CONFIRM_EXTERNAL |
| Artifact filename | TO_CONFIRM_EXTERNAL |
| Build environment and toolchain | TO_CONFIRM_EXTERNAL |
| Signed / unsigned | TO_CONFIRM_EXTERNAL |
| Signing authority / custody reference | TO_CONFIRM_EXTERNAL |
| SHA-256 | TO_CONFIRM_EXTERNAL |
| Build timestamp with timezone | TO_CONFIRM_EXTERNAL |
| Builder / operator | TO_CONFIRM_EXTERNAL |
| Reviewer | TO_CONFIRM_EXTERNAL |
| Store / upload reference | TO_CONFIRM_EXTERNAL |
| Controlled evidence location | TO_CONFIRM_EXTERNAL |

Never record a password, key alias secret, certificate private material, provider file, token, private URL, member data, or signing credential. A signing authority field identifies an approved role or custody record, not the secret or key material.

## Safe checksum commands

Run the checksum on the exact immutable artifact after the build has completed and before transfer. Quote paths; do not hash an entire directory.

PowerShell:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath '.\path\to\artifact' |
    Select-Object Algorithm, Hash, Path
```

macOS/Linux:

```bash
shasum -a 256 -- './path/to/artifact'
```

Record the resulting hexadecimal SHA-256 through the approved evidence process. A checksum proves byte identity, not who signed the artifact or whether a store accepted it.

## Platform evidence

For Android, retain the approved release task, application ID, version name/code, artifact type, signer verification output, checksum, and Play Console track/upload reference. Debug signing is never release evidence, and the repository intentionally fails release packaging when external signing is absent.

For iOS, retain the authorized macOS/Xcode version, bundle ID, marketing/build version, archive/export method, distribution-signature and entitlement verification, checksum, and App Store Connect upload reference. An unsigned or `--no-codesign` build does not close signing, APNs, archive, device, or store gates.

For web/backend artifacts, retain the source commit, dependency lock/input, build or image identity, checksum/digest, environment class, registry/storage reference, operator, reviewer, and deployment decision. Repository build output is not evidence of production deployment.

## Review and linkage

The reviewer must independently match the source commit, version, identifier, signature status, checksum, and upload reference. Link the accepted record from [the release evidence index](RELEASE_EVIDENCE_INDEX.md). Keep sensitive build logs and store-console evidence in the approved restricted evidence store, not in Git.
