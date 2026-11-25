# Lifecycle hunt: the bugs that appear only over time

Read by `idleflow:lifecycle-hunter` from `/idleflow:lifecycle`, and by `idleflow:red-team` when a plan touches a lifecycle. Reading the code catches what is wrong at one moment. These bugs need time to pass, state to build up, or a step to stop partway, so they are found by playing the lifecycle out.

## 1. Map the lifecycles

A **lifecycle** is anything whose behaviour depends on time or on the order of what happened before: a record that moves through statuses, something that expires, is retried, renewed or scheduled, a session or credential with a lifetime, a queue or job that is picked up and finished, a cache that fills and is invalidated, a counter or quota that resets, a migration or backfill that runs in steps, and data that grows without bound.

For each one, from the code (never from its docs alone):

- its **states** and the **transitions** between them, with what triggers each: a call, a time, an event, another lifecycle;
- its **rules**, what must hold in every state and after every transition, written as checkable statements over the stored state;
- its **clocks**: every place it reads the time, which clock, in which timezone, and at what precision;
- what happens when a transition **stops partway**: what was written before the stop and what was not;
- the **outside services** it waits on, and what it does when one answers late, wrongly or never.

A rule the code never states but its behaviour depends on is still a rule: write it down, and say it is inferred.

## 2. Simulate long use

- **Control the clock.** Drive time through the project's own way of faking it: a test library, an injected clock, a time parameter. Never sleep through real time to reach a later moment. Where the code reads the clock directly and nothing lets a test move it, the first finding is that seam: name where the clock is read and what injecting it would take, and test what can be reached without it.
- **Use the project's own harness**: its test framework, its fixtures, its factories, the way its own tests build state. A probe is a test the project could keep.
- **Play out whole lifecycles**, from creation to the end of the longest life the code allows and past it, across many cycles where the lifecycle repeats, with state carried from step to step as real use carries it.
- **Check the rules after every step**, not only at the end. The first step at which a rule fails is the bug's location.

## 3. Probe the edges

- **Time boundaries**: exactly at each limit, one unit before and after, at the boundaries of calendar units, across every change in how local time maps to the clock, with the clock moving backwards or jumping forwards, and with two clocks that disagree.
- **Order**: steps out of their usual order, the same step twice, two runs of one step at once, an event that arrives after the state it refers to has moved on.
- **Interruption**: stop each transition at each point between its writes, then resume, retry or start over, and check the rules.
- **Growth**: the lifecycle after many cycles, with large accumulated state, at the limits of every counter and size.
- **Outside services**: each one answering late, past every timeout the code sets, with an error, with a well-formed wrong answer, and not at all, during each state that waits on it.

## 4. A bug

A bug is a rule that fails at some step of a played-out lifecycle. Each one is reported with:

- the **scenario**: the lifecycle, the starting state, and each step with its simulated time;
- the **rule** that fails and the step where it first fails, with the state at that step;
- a **test that fails on it**, in the project's own framework, using its controlled clock, that passes once the bug is fixed;
- the **cause** in the code: the transition, the check or the clock read that lets it happen;
- **severity**: `blocking` when the failure loses or corrupts data, lets someone act beyond their rights, makes an effect outside the system happen more often or less often than once, or leaves state no later step can repair; `major` when the lifecycle reaches a wrong state that a later step or a human can repair; `minor` when it only delays or misreports.

A lifecycle that could not be played out (a seam missing, a service no test can stand in for) is reported as not hunted, with what was missing; it is never assumed to hold.

## 5. For a plan

When a plan changes a lifecycle (any task whose files hold one of section 1's kinds), the red team checks the plan against sections 1 to 3 without running anything: which states, transitions, rules, clocks, partial stops and service failures the change touches, and whether the plan's tasks and acceptance cover them. A gap is a finding with the scenario that would hit it.
