# GIPHY and shared content

Requires distinct GIPHY client API keys in web/Android defines. Client-side trending, search, pagination, attribution. Only GIF ID is stored as sticker_pack=giphy:ID and content=GIF; rendition URLs are resolved at viewing time, no GIPHY file is copied to the VPS or disk media cache. Keys are not in source. Existing bundled animations/import remain available without a configured key.

Shared-content SQL uses actual ChatMessage.message_type and content columns; attachments are JSON encoded within content. Old query referencing nonexistent attachment_url/sticker_pack columns was corrected before deployment. Tests check query fields against the actual model.

Publish tool derives from current release-43c3c07, replaces only chat route and email privacy service, runs eight Python tests and an actual readonly SQL query in the candidate, verifies a backup, then switches four services with automatic rollback. No migration or environment change. Server reports version 1.0.15 until next complete versioned release.

Flutter tests include provider query preservation, errors and ID resolution. Live GIPHY API verification requires user keys. Provider docs: https://developers.giphy.com/docs/ .
