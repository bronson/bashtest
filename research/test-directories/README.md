This directory tests the overhead of changing directories.

### Example

First create a baseline.

```sh
./create-tests 200 500
./run-tests -b
```

That establishes how fast the tests will run. On my machine, it takes 8 seconds
plus or minus to run all 100,000 tests.

Now, let's try changing directories in every test and see how much it slows down.

```sh
./create-tests 200 500 'cd /tmp'
./run-tests -b
```

I still see around 8 seconds to run all tests. Interesting! That cd is almost free.
The overhead of running the test functions is much higher.

Let's try a deeper nested directory.

```sh
./create-tests 200 500 'cd ~/".var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/1161580/pfx/drive_c/users/steamuser/AppData/LocalLow/Blackbird Interactive/Hardspace_ Shipbreaker/Unity/local.cf1a53891f9cc1b478d6f7016e31f1e3/Analytics/ArchivedEvents/175661420600012.05ebb3ee"'
./run-tests -b
```

And that's still around 8 seconds.

It's clear: running cd before every test is not a problem. There's no need to be clever
about caching and restoring the cwd inside tests.
