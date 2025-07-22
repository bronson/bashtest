# Bash Test

A simple way to test CLI tools and bash scripts.

## Features

- Fast
- Lightweight
- Easy to Install
- Bash Dialect
- No Filesystem Shenanigans
- Simple -- reasonably small, easy to understand
- Permissive License -- no need to sweat license issues
- Mature -- complete feature set, stable

This project was extracted from [Portkey](https://github.com/bronson/portkey).

## Usage

### Running Tests

```bash
./run-tests                   # Run all .test files recursively
./run-tests t1.test t2.test   # Run specific test files
./run-tests dir               # Run all tests in a directory
```

### Arguments

* -b --benchmark, show execution time: `./run-tests -b file.test`

### Configuration File

```
tsk_benchmark_enabled=true   # always show the benchmark
```
