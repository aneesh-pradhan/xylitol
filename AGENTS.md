# Agent rules — xylitol

Hard constraints for **every** AI coding agent working in this repository
(Cursor, Claude, Copilot, ChatGPT, Gemini, etc.).

## Git commits — authorship identity (HARD RULE)

Upstream maintainers are strict about copyright / DCO attribution. Every commit
in this repo — **and every patch re-rolled from it for upstream submission**
(kernel `Signed-off-by`, DTS `Copyright` headers, etc.) — MUST be authored as
**exactly**:

```
Aneesh Pradhan <aneeshpradhan@acm.org>
```

- This is the ONLY acceptable author name + email. Do not use any other address
  (`apradhan5@horizon.csueastbay.edu`, `zen7370@outlook.com`, `perry@xylitol.local`,
  etc.) for authorship, `Signed-off-by`, or source-file copyright lines.
- Set it and keep it: `git config user.name "Aneesh Pradhan"` /
  `git config user.email "aneeshpradhan@acm.org"`.
- This must never slip past — verify before every push with
  `git log --format='%an <%ae>' origin/main..HEAD`.

## Git commits — no AI attribution

- **Never** add `Co-authored-by` / `Co-Authored-By` for any AI or bot.
- **Never** set author/committer identity to Cursor, Claude, Copilot, or any AI.
- If the host environment auto-appends an AI trailer on `git commit`, do **not**
  use that path for the final commit — use `git commit-tree`, or strip the
  trailer before the object is created, then verify with
  `git log -1 --format=%B` that no AI trailer remains.
- **Never push** a commit that contains an AI co-author trailer.

Enforced by:

- `scripts/git-hooks/pre-commit` (rejects any author != `Aneesh Pradhan <aneeshpradhan@acm.org>`)
- `.cursor/rules/no-ai-commit-attribution.mdc` (alwaysApply)
- `scripts/git-hooks/prepare-commit-msg` (strips AI trailers)
- `scripts/git-hooks/commit-msg` (rejects remaining AI trailers)
- Enable with: `git config core.hooksPath scripts/git-hooks`

## Sacred device partitions

Never wipe, flash, or repartition `persist`, `modemst1`, or `modemst2`.

## Do not commit

Lineage tree, `out/`, ccache, vendor blobs, device extracts, or AI co-author
metadata.
