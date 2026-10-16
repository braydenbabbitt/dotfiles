# Comments

**The default is no comment.** Comments are not neutral: they add reading
overhead, drift out of sync with the code, and quietly rot into lies. Code that
needs a comment to be understood is usually code that should be rewritten —
clearer names, a smaller function, an extracted helper. Reach for the code
first; a comment is the fallback, not the tool.

So a comment is not something to add unless there is a reason to. **Every
comment must be justified**, and there are exactly **two** justifications:

1. **Non-obvious "why."** The reasoning behind the code is not evident from
   reading the code itself, **and** another developer needs it to work safely in
   this area — a constraint, a workaround, a rejected alternative, a bug being
   guarded against. If the "why" is readable from the code, the comment is
   noise.

2. **In-editor documentation.** Interface docs (JSDoc, docstrings, doc comments)
   for code that is **widely shared** or whose **interface is hard to understand
   from the signature alone**. Document the contract — parameters, return value,
   errors, units, invariants — not the implementation. Not every function needs
   one; a small, obvious, locally-used function does not.

If a comment does not clearly fall into one of those two cases, **do not write
it.** Silence is the correct default, not a gap to be filled. Never comment to
look thorough, to show work, or to fill a perceived documentation quota.

Concretely, do not write: restatements of what the code plainly does, section
banners or decorative dividers, narration of a change or its history (version
control records that), notes addressed to the reader of a diff, or
commented-out code.

The bar applies to code you edit as well as code you write: leave behind only
comments a reviewer would ask you to keep. When in doubt, omit it — an absent
comment costs far less than a misleading one.
