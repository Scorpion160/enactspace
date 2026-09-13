# Store release metadata

This is the canonical repository worksheet for the EnactSpace V1.0.0 store listings. It is a preparation record, not evidence that an application, account, listing, artifact, or release exists in either store.

## Repository-determined identity

| Field | Value | Evidence |
| --- | --- | --- |
| Application name | EnactSpace | Flutter package description and native application metadata |
| Android application ID | `sn.enactusesp.enactspace` | `frontend/android/app/build.gradle.kts` |
| iOS bundle ID | `sn.enactusesp.enactspace` | `frontend/ios/Runner.xcodeproj/project.pbxproj` |
| Release target | V1.0.0 | Canonical repository documentation |
| Flutter version/build | `1.0.0+1` | `frontend/pubspec.yaml` |
| Backend version | `1.0.0` | `backend/app/core/config.py` |

Do not increment the version or build number here. A release authority must approve any change and update the application configuration first.

## Store-owned and institutionally owned fields

| Field | Android / Google Play | iOS / App Store | Status |
| --- | --- | --- | --- |
| Short description / subtitle | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Copy and localization require approval |
| Long description | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Copy and localization require approval |
| Primary and secondary category | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Store decision not present in the repository |
| Support contact | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Do not infer a person or address |
| Support URL | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | No public URL is approved in the repository |
| Privacy policy URL | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | The tracked privacy policy remains a draft |
| Marketing URL, if used | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Optional use and URL require approval |
| Copyright / legal ownership | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL | Legal entity and wording require confirmation |
| Countries and regions | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Distribution territory requires account-owner approval |
| Age rating and content declarations | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Complete in each store from the approved product questionnaire |
| Screenshots, preview media, and feature graphics | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Capture from the approved release candidate without member data |
| Store account ownership | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Google/Apple account authority is external |
| Android release track | TO_CONFIRM_EXTERNAL | Not applicable | Internal, closed, open, or production track requires approval |
| App Store Connect application / numeric ID | Not applicable | TO_CONFIRM_EXTERNAL | Do not create or infer an identifier here |
| Review notes and test access | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Supply only through the approved private store workflow |
| Final public store URL | TO_CONFIRM_EXTERNAL | TO_CONFIRM_EXTERNAL | Record only after the store creates it |

## Submission controls

- Use only an authorized HTTPS production API endpoint.
- Keep signing material, provider files, test credentials, private URLs, and member data outside this repository and ordinary review artifacts.
- Complete the store privacy forms from the approved [privacy disclosure worksheet](PRIVACY_DISCLOSURE_WORKSHEET.md), not from assumptions.
- Record every signed artifact in [artifact provenance](ARTIFACT_PROVENANCE.md) and link accepted evidence through the [release evidence index](RELEASE_EVIDENCE_INDEX.md).
- Android debug builds, unsigned iOS builds, repository metadata, and this worksheet do not close a signing, physical-device, provider, ownership, or store gate.
