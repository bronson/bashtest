Here are some tiny research projects that steered the design
of bashtest.

## running-jobs

This evaluates different methods to run tests in parallel.
It turned out that the simplest algorithm had very little overhead
compared to the tests so there wasn't much point to optimizing
the job runner further. The simple algorithm is good enough.

## test-directories

There are different ways of setting up and tearing down the test
environments. These tests ensure we do a complete job without causing
undue delay.
