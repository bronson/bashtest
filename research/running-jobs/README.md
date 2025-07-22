# Job Test

This directory contains some quick benchmarks to decide how
to implement parallel job execution when running tests.

* job-test-baseline: an oversimplified job runner that doesn't actually ensure
  each job is run in its own directory.
- job-test-newdirs: Creates and deletes a directory for each job. Seems like high overhead?
- job-test-waitp: Monitors jobs with `wait -p` to reuse their directories when they exit.
- job-test-fifo: Unfinished, uses a named pipe to coordinate job execution and directories.

Select the runner you want, supply the number of simultaneous jobs on the command
line, and feed it a text file of jobs.

### Timed Jobs

The timed-jobs file ensures that the job runner executes the jobs
in parallel correctly.

To run four simultaneous jobs, and execute all the jobs in the timed-jobs file:

```bash
./job-test 4 < timed-jobs
```

This should take at least 7 seconds to complete (but not much more; test overhead should be well under 100ms).

When you're writing a new job runner, first run it with timed-jobs to
ensure it schedules the jobs correctly. Each job must be run once
and only once (look at the output to be sure) and, if it runs tests
sequentially, it should take exactly the following amount of time:

| Simultaneous Jobs | Duration (seconds) |
|-------------------|----------|
| 1                 | 26 |
| 2                 | 13 |
| 3                 | 9 |
| 4                 | 7 |
| 6                 | 6 |
| 8                 | 4 |
| 10                | 4 |

(and if it doesn't run tests sequentially, how are you predicting how
long each test will take so you can reorder them optimally?))

### Quick Jobs

Now that you're convinced that your new job runner is correct, and
running each job exactly once in its own directory, you can benchmark it
with the quick jobs. The idea is to run 10,000 tests, each test in its
 own test directory.  (it's fine to re-use directories, as tests are expected
to leave their directory empty, but it is NOT ok for two tests to use
the same directory simultaneously).

Because 10,000 jobs is a moderatly big file, we'll use a script to create it,
and then run the job runner:

```bash
bash create-quick-jobs.sh
./job-test 8 < quick-jobs
```

On a reasonable 2020s laptop, this should finish somewhere between 1
and 10 seconds.

## Evaluating Runnerns

There's a script that runs each of the job runners across a range
of maximum simultaneous jobs.

```bash
./create-job-table quick-jobs
```

And it formats its results in a Markdown table (times are in milliseconds):

| test | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 | 256 |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| job-test-baseline | 6190 | 3247 | 2350 | 2333 | 2353 | 2418 | 2451 | 2526 | 2629 |
| job-test-newdirs | 28573 | 14685 | 6382 | 3321 | 2546 | 2546 | 2605 | 2677 | 2746 |
| job-test-waitp | 11967 | 6266 | 3523 | 3198 | 3335 | 3453 | 3724 | 4158 | 5168 |

## Findings

job-test-baseline's results show that, with no other overhead, the plain job scheduler
hits maximum throughput around 4 simultaneous jobs, and tops out at around
4000 jobs per second. That makes sense. Bash is no speed demon but it's
fine for what we need.

job-test-newdirs (creating and removing a directory for each job)
is slow as all heck ... until you start slamming jobs in parallel.
At 16 simultaneous jobs, the time to create and destroy test directories
is swamped by the rest of the test overhead. It basically disappears.
(These numbers are so close to the baseline that I'm amazed that they're accurate,
but I've checked the results and they look fine.)

job-test-waitp (creating n directories and sharing them among running tests)
starts out reasonably quick, only 2X slower than baseline, and continues
pretty well... until 8 simultaneous jobs. At 16 simultaneous jobs, creating and
destroying a directory becomes much faster than sharing directories.

I guess the kernel filesystem has more optimization opportunities than the
kernel scheduler? Also, bash job scheduling works but is probably not meant
to be very quick.

Here's some corroboration...

```txt
❯ time ./job-test-newdirs 20 < quick-jobs
All jobs completed.
Total execution time: 2 seconds

real	0m2.088s
user	0m6.700s
sys	0m18.716s
```

So the test run took 2.1 seconds to complete, and it took 18.7 seconds
of CPU time to do that.

That test always requires at least 16 seconds of CPU time to complete.
On a modern OS, however, it parallels really well.

job-test-waitp only requires around 5 seconds of CPU time to do the same job
(so less than 1/3 of that required by job-test-newdirs), but it doesn't actually
run any faster. If anything, it's consistently a little slower, presumably because
it's doing more coordination in Bash rather than the kernel.

```txt
❯ time ./job-test-waitp 2 < quick-jobs
All jobs completed.
Total execution time: 5 seconds

real	0m5.061s
user	0m5.833s
sys	0m5.054s
```

## Conclusion

The simpler implementation is also the fastest! And, if you're running
the operations in parallel, it's surprisingly fast.

The implications of this are surprising. It appears we should offload as much complexity
as we can onto the filesystem and run the tests massively in parallel. That's much
easier code to write and debug.

This is unexpected good news. Today, at least, there's no need to choose between
speed and code complexity. The simple algorithm is effectively as fast as the complex one.
