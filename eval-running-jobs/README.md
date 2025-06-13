# Job Test

This directory contains a quick benchmark to decide how
to implement parallel job execution.

* job-test: a simple job runner that doesn't actually ensure each job is
  run in its own directory. Establishes a baseline for the actual implementations..
- job-test-newdirs: Creates and deletes a directory for each job. High overhead?
- job-test-waitp: Monitors jobs with `wait -p` to reuse directories when jobs exit.
- job-test-fifo: Unfinished, uses a named pipe to coordinate job execution and directories.

Select the runner you want, supply the number of simultaneous jobs on the command
line, and feed it a text file of jobs.

### Timed Jobs

The timed-jobs file ensures that the job runner executes the jobs
in parallel correctly.

```bash
./job-test 4 < timed-jobs
```

This should take 7 seconds.

When writing a job runner, first run it with timed-jobs to
ensure it schedules the jobs correctly. Each job must be run once
and only once (look at the output to be sure) and, in theory, it
must take exactly the following amount of time:

| Simultaneous Jobs | Duration (seconds) |
|-------------------|----------|
| 1                 | 26 |
| 2                 | 13 |
| 3                 | 9 |
| 4                 | 7 |
| 6                 | 6 |
| 8                 | 4 |
| 10                | 4 |

### Quick Jobs

```bash
bash create-quick-jobs.sh
./job-test 8 < quick-jobs
```

On a reasonable 2020s laptop, this should finish somewhere between 1
and 10 seconds.

## Evaluating Runnerns

4 simultaneous jobs seems to be a good test.

```bash
./job-test-newdirs 4 < quick-jobs
```

DISCOVERY: for 10,000 tests:

- Sharing directories takes 3 seconds to complete all tests.
- Creating directories takes 4 seconds.
- Creating and deleting directories takes 5 seconds.

So everything is within a factor of 2. Pretty close!
