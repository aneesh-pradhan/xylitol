# Agent rules — xylitol

Hard constraints for **every** AI coding agent working in this repository
(Cursor, Claude, Copilot, ChatGPT, Gemini, etc.).

## Git commits — no AI attribution

- **Never** add `Co-authored-by` / `Co-Authored-By` for any AI or bot.
- **Never** set author/committer identity to Cursor, Claude, Copilot, or any AI.
- Commits must use the human maintainer's configured `user.name` / `user.email` only.
- If the host environment auto-appends an AI trailer on `git commit`, do **not**
  use that path for the final commit — use `git commit-tree`, or strip the
  trailer before the object is created, then verify with
  `git log -1 --format=%B` that no AI trailer remains.
- **Never push** a commit that contains an AI co-author trailer.

Enforced by:

- `.cursor/rules/no-ai-commit-attribution.mdc` (alwaysApply)
- `scripts/git-hooks/prepare-commit-msg` (strips AI trailers)
- `scripts/git-hooks/commit-msg` (rejects remaining AI trailers)
- Enable with: `git config core.hooksPath scripts/git-hooks`

## Sacred device partitions

Never wipe, flash, or repartition `persist`, `modemst1`, or `modemst2`.

## Do not commit

Lineage tree, `out/`, ccache, vendor blobs, device extracts, or AI co-author
metadata.
