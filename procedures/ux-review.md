# UX review: how idleflow finds where an end user gets stuck

Read by `idleflow:review-ux`, inside a run and from `/idleflow:ux`. The design reviewer judges how a screen looks against its spec; this review judges whether an end user can get through the app, by using it.

## 1. Whose journeys

Work out who the end users are and what they come to do before opening anything: `prd.md`, the issue or the run's plan, `design.md` and the app's own entry points. Each **journey** is one thing an end user comes to do, from where they arrive to the moment they can tell it is done. A task's review walks the journeys its change touches; an audit walks the journeys the end users depend on most, the first one a new end user takes among them.

Walk each journey as that end user would: knowing the product only from what the screen shows, never from the code, the spec or the conventions. A step that is clear only to someone who read the code is a finding.

## 2. Each step: the four questions

At every step of a journey, ask the four questions of the cognitive walkthrough ([NN/g](https://www.nngroup.com/articles/cognitive-walkthroughs/), [the method](https://en.wikipedia.org/wiki/Cognitive_walkthrough)):

1. Will the end user try to do the right thing here, given what they want and what the screen tells them?
2. Will they notice that the control or path for it is there?
3. Will they connect that control with what they want to do?
4. After they use it, will they see that they moved forward, or what went wrong?

A "no" to any of them is where the end user gets **stuck** (cannot go on), **confused** (cannot tell what to do or what happened) or **misled** (the screen suggests something that is not so).

## 3. Beyond the happy path

A journey is walked more than once, because end users do more than the expected:

- with the input an end user would actually give, wrong and unusual input included;
- with nothing there yet, with a lot there, and with the network or the service slow or failing;
- going back, reloading, leaving halfway and returning;
- at phone and desktop widths, by keyboard alone, and with the browser's zoom raised;
- across every state the journey can reach: empty, loading, error, partial, done.

Judge each against the usability heuristics ([NN/g, ten usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)): the system shows its status; it speaks the end user's language; the end user can undo and leave; it is consistent within itself and with what end users know; it prevents errors before reporting them; it shows options rather than relying on memory; it serves both new and practised end users; it shows only what the step needs; errors say what happened and how to recover; help is there where it is needed.

## 4. A finding

A finding is a place an end user gets stuck, confused or misled, never a matter of taste, and never a code fault the correctness reviewer covers. Each one has:

- the journey and the step, and the width and state it happened in;
- a screenshot of that moment;
- what the end user tried, what they saw, and why it stops, confuses or misleads them, in their terms;
- the cause in the product: the screen, the copy, the order or the missing state that produces it;
- the change that removes it, the smallest that does, in the project's own components and tokens.

Severity, after the usability severity scale ([0 to 4](https://www.cl.cam.ac.uk/teaching/1718/IntDesign/Heuristic.pdf)):

- **blocking**: an end user cannot finish the journey, or is misled into a result they did not want: something lost or sent that they did not mean, or a journey shown as done that is not.
- **major**: most end users get past it only after a wrong try or a guess, or finish without being sure it worked.
- **minor**: it slows end users or makes them hesitate, and they still finish sure of the result.

## 5. Honest about what was walked

A journey or a state that could not be reached, because it needs something the app under review does not have, is reported as not walked, with what was missing. It is never assumed to work. Nothing is entered that could reach anyone real or any real outside system: walk only on the app the review was given, with test data.
