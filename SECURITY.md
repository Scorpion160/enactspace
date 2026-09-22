# Security policy

## Reporting a vulnerability

Report suspected vulnerabilities privately to the designated Pôle IT security contact or, until that contact is formally mapped, to the current repository fallback owner `@Scorpion160`. Do not open a public issue containing exploit details, credentials, private user information, or production logs.

Include a concise impact description, affected version/commit, reproducible sanitized steps, and suggested containment if known. The recipient should acknowledge the report, restrict evidence access, assess exposure, rotate affected secrets, and coordinate remediation and disclosure with Enactus ESP.

## Supported release

The active release target is V1.0.0. Security fixes are assessed against the deployed version and the current product-readiness branch. Support windows and response-time commitments must be approved by Enactus ESP; none are implied by this document.

## Repository controls

CI includes dependency, tracked-secret-material, environment-file, and immutable-action-reference guards. These controls do not replace review or provider-side protections. CodeQL, GitHub Advanced Security, secret scanning, branch protection, and required checks are optional administrative controls until repository capability and configuration are explicitly verified.

The dependency audit has one explicit exception for `PYSEC-2026-1325`: the transitive `ecdsa` library has no fixed release, while EnactSpace runtime configuration enforces `HS256` and rejects algorithms that could use the affected ECDSA signing operation. Any change to `ALGORITHM`, `python-jose`, or signing behavior must first remove or re-justify this exception. The exception must also be reconsidered during PR-8 and each dependency review.

Never place secrets or signing assets in issues, pull requests, workflow YAML, build artifacts, or source control. Follow [Secrets and environments](docs/SECRETS_AND_ENVIRONMENTS.md) for storage and incident response.
