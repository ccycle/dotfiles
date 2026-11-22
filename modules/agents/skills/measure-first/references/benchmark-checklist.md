# Benchmark Checklist

Answer these before reporting or acting on any performance number: a before/after, a regression claim, throughput, latency, tokens/sec, or a choice between options.
Each answer needs evidence from a run, not a guess about the code.

For a quick ballpark the user asked for, one run is enough; still answer questions 4 and 7, and say it was one run.
A choice between options is never a ballpark.

## Before running

- Write down the sentence you expect to report ("p50 is 30% lower on the 60k-row dataset"); the questions test that sentence.
- Read the measurement script: what it times, what it counts, what it ignores.
- Check machine load (`uptime`, core count).
  If something else is running and cannot be stopped, interleave the sides so both see the same noise, and say so.

## Questions

1. What limits it?
   Name the bottleneck (CPU per process, I/O wait, a profiler hot spot, the load generator itself).
   Profile in a run you do not report, since profilers slow the work.
   If a change did not move the number, the limiter explains why.
2. Was every side tuned?
   Run each side the way production runs it: release builds, production flags, warm or cold caches as production sees them, same versions and data.
   A limiter that is a setting (debug build, a commit per row, a missing index) means that side is untuned; tune and remeasure before picking a winner.
3. Does it break a physical limit?
   Compare against disk and network bandwidth and core count.
   Removing a piece that takes 10% of the run can make it at most about 11% faster.
   A result past a limit measured a cache, a no-op, or a bug.
4. Did it error?
   Count failures and non-success responses, and check outputs are correct, not just present.
   Fast rejections and slow retries both distort numbers.
5. Does it reproduce?
   At least 5 runs per side, alternating A, B, A, B.
   Report median and range; a gap smaller than run-to-run variation is no measurable difference.
6. Does it matter end to end?
   Next to a micro result, measure the path a user actually waits on, and report the micro result as a share of it.
7. Did the work happen?
   Confirm it ran inside the timed region: the request reached the server, the rows were written, the result was used.
   Lazy evaluation, unawaited work, and timeouts produce numbers for work that never ran.

## Reporting

- Lead with the verdict: faster, slower, no measurable difference, or inconclusive.
- Give the number with unit, run count, range, and limiter.
- Call it inconclusive when the limiter is unknown, a side was untuned, or questions 4 or 7 could not be answered, and name the gap.

## Sources

Adapted (rewritten, not copied) from the `benchmark-checklist` skill in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
