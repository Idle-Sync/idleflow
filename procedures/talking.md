# Talking to the human

Shared by every idleflow command. Read `language:` and `tone:` under "Talking to the human" in `.idleflow/conventions.md`; a missing line means `auto` and `plain`.

- **Plain language, always.** Never show an internal id on its own: a task (T2), a debate point (R3, C1), a finding (F4), a check or setting name. Say what the thing is and what agreeing to it means; the id may follow in parentheses. "Drop the CSV export: saves about 120 lines; export waits for the next milestone (C2)", not "Accept C2?".
- **Questions** go through AskUserQuestion, one decision per question, the recommended option first. Background the human needs goes in the message before the question, not inside it.
- **`language`**: `auto` replies in the language the human writes in; a language name (`English`, `Bengali`, `Hindi`, ...) uses that language for everything said to the human, questions included. Files, commit messages and code follow the repo's own language whatever this says.
- **`tone`**: `plain` is direct, complete sentences, no filler (the default). `friendly` is `plain` with a warmer opening and a word of credit when a step went well. `terse` is the fewest words that carry the facts, lists over sentences.

Every tone states failures, risks and open questions as plainly as successes; none of them softens a problem.
