# Chat and brand layout — 12 October 2026

Source changes; no deployment performed by the sync script.

- The desktop chat fills the available content height and uses a narrower conversation list.
- Desktop navigation closes on entry to chat; the header menu button restores it. Other routes restore navigation. Mobile navigation remains unchanged.
- Photos preserve their proportions, hide filenames and file sizes, and open on tap. Generic automatic captions are hidden; user captions remain. Videos can be downloaded and played inline or opened. Documents retain filenames and download controls.
- Conversation header opens Infos. The avatar in Infos opens a photo and basic profile preview.
- Infos links to Media, Documents and Links. The authenticated /chat/threads/{id}/shared endpoint checks membership, excludes deleted messages, serializes using existing access rules and paginates 100 items at a time. Accessing this endpoint does not mark messages read.
- Association logo enlarged in Flutter and pre-Flutter web splash. Multiply compositing neutralizes the original white square on the shared login panel without altering the source logo.

Validation: Python privacy tests (2) and shared-content SQL tests (2) passed locally. Flutter is not installed in the preparation environment; run analyzer and widget tests using the Windows sync script. Visual validation of the composited logo, media sizes and narrow-window layout is still required in Edge. Backend deployment is required before the shared-content screen can load.
