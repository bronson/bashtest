# Running tests in subshells

## Rationale

Running each test in its own subshell and its own directory means that
tests can't possibly stomp on each other's environment variables or
files. It also means that tests can't accidentally leave files behind.
No need to clean up.

## Baseline

```
> ./create-tests 100 500
> ./run-tests-subshell-orig -b
Running 100 testfiles took 0.833 seconds
```

So we're currently running around 45 thousand tests per second.

Can we do something close to that, but firing off subshells in the background?

Quick and dirty modification to launch each test in its own subshell and
directory (but not bothering with collecting results yet)

```
> ./run-tests-subshell-test -b
Running 100 testfiles took 2.400 seconds
```

Well 3X slower is surprisingly decent.

Actually, I need to wait until the last child exits too.

That takes 20 seconds.  :(

O wait, I'm checking the directory to see if the test left files behind.
That's wasted time.

Now I'm down to 7 seconds.

That's not too bad...  I might be able to work with this, but it's not enough.

Running it on a ramdisk (tmpfs) reduced it to 6 seconds. Also not enough.

Running orig on a ramdisk takes 1/10 of a second longer! wtf? Running it
normally takes 0.849 seconds, and on the ramdisk it takes 0.920 seconds.

I think I need to take two parallel paths here:
- run tests serially (possibly with redordering randomly)
- forkbomb

The forkbomb approach feels like it would result in better tests, with
fewer implicit dependencies.
