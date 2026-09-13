# Contributing to EnactSpace

EnactSpace is currently a private Enactus ESP repository. Contributions require authorized repository access and review.

## Integration model

Until V1.0.0 and PR-8 closure, integration work remains on `feat/product-readiness-v1`. The long-term target after release is pull-request-based integration into `main`. Branch protection and required checks are not currently enabled; do not describe local success as equivalent to protected-branch enforcement.

Create focused changes, link the relevant issue or decision context, and preserve unrelated work. Never commit production credentials, real environment files, private member data, provider configuration files, private keys, or mobile signing material.

## Expected checks

Run the checks relevant to the change and record exact results in the pull request. Application changes normally require backend compilation/tests and/or Flutter analysis/tests. Schema changes require an Alembic migration with upgrade/downgrade validation on PostgreSQL. Operational changes require documentation and rollback review.

The repository workflows are the intended shared gate once GitHub Actions billing/execution is restored. A reviewer must still assess security, privacy, migrations, release impact, and external gates.

## Review and merge

At least one authorized review is the target policy for `main`. After CI is functional, administrators should require the application and security checks, prohibit force pushes and branch deletion, and select one documented merge strategy. Until those controls can be enforced, the repository owner must apply the same checks manually and preserve evidence.

Do not merge or release solely because a checklist is present. Release authority and production access remain with Enactus ESP.
