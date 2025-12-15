#!/bin/bash

# Benchmark script to evaluate different ways of testing whether a directory is empty.
#
#         Usage: ./benchmark <directory> <repetitions>
#              Directory: the directory to test for emptiness
#              Repetitions: the number of times to repeat the test
#
# Results: compgen is best for directories with few entries, find is best for directories
# crammed with lots many files and directories. This makes sense because compgen will
# assemble the entire result and immediately throw it away, while find bails after the
# first match. If the result is big, this will be a lot of wasted time.
#
# -----------------------------------------------------------------------------------------------
# Directory              #files   Iters    ls -A         find          test glob     shopt array
# ---------------------- -------- -------- ------------- ------------- ------------- ------------
# /usr/bin               2449     500      1751 (3.0X)   584 (1.0X)    1335 (2.3X)   5124 (8.8X)
# /usr/lib/firmware      525      500      1550 (4.3X)   565 (1.6X)    357 (1.0X)    1503 (4.2X)
# /usr/share             291      500      1481 (5.1X)   888 (3.1X)    289 (1.0X)    1449 (5.0X)
# /tmp                   6        500      780 (15.6X)   518 (10.4X)   50 (1.0X)     392 (7.8X)
# /tmp/onehidden         1        500      748 (46.8X)   513 (32.1X)   16 (1.0X)     266 (16.6X)
# /tmp/empty             0        500      736 (35.0X)   535 (25.5X)   21 (1.0X)     271 (12.9X)
# -----------------------------------------------------------------------------------------------
#
# Overall: _compgen_ tends to be 1/2 the time of testglob. _find_ is much faster than both for very
# large directories, and much slower than both for very small directories. Those are the only methods
# worth considering.
#
# This is definitely not a good microbenchmark! There's a lot of variation even run-to-run,
# but especially when changing filesystem, CPU, and disk type (rust/ssd/ram). That said, it
# stil provides good info on which algorithm to choose.
#
# Note that bash booleans are reversed from most lanugages. To make
# `if is_empty(/tmp/mydir); then`  or `is_empty ~/dir && fill_dir` work,
# is_empty returns 0 if the directory is empty and 1 if it has items in it.
#
# Some of these techniques come from https://superuser.com/questions/352289/bash-scripting-test-for-empty-directory
# Too bad Superuser prevents me from leaving a comment there even though I have 101 reputation.

if [ $# -ne 2 ]; then
    echo "Usage: $0 <directory> <repetitions>"
    exit 1
fi

dir="$1"
reps="$2"

# Validate inputs
if [ ! -d "$dir" ]; then
    echo "Error: '$dir' is not a valid directory"
    exit 1
fi

if ! [[ "$reps" =~ ^[0-9]+$ ]] || [ "$reps" -eq 0 ]; then
    echo "Error: Repetitions must be a positive integer"
    exit 1
fi

# Method 1: Using ls -A
is_empty_ls-A() {
    local dir="$1"
    if [ -z "$(ls -A "$dir")" ]; then
        return 0  # empty
    else
        return 1  # not empty
    fi
}

# Method 2: Using find with -maxdepth 0 -empty
is_empty_find() {
    local dir="$1"
    if [ -n "$(find "$dir" -maxdepth 0 -empty)" ]; then
        return 0  # empty
    else
        return 1  # not empty
    fi
}

# Method 3: Using test -e with glob
is_empty_testglob() {
    local dir="$1"
    # Check for regular files
    test -e "$dir/"* 2>/dev/null
    local regular=$?
    # Check for hidden files (excluding . and ..)
    test -e "$dir/".[!.]* 2>/dev/null || test -e "$dir/".??* 2>/dev/null
    local hidden=$?

    # Directory is empty only if both checks fail (return 1)
    if [ $regular -eq 1 ] && [ $hidden -eq 1 ]; then
        return 0  # empty
    else
        return 1  # not empty
    fi
}

# Method 4: Using shopt nullglob and array
is_empty_shoptarr() {
    local dir="$1"
    local old_nullglob=$(shopt -p nullglob)  # Save current setting
    local old_dotglob=$(shopt -p dotglob)    # Save current setting
    shopt -s nullglob  # Ensure that globs expand to nothing if no match
    shopt -s dotglob   # Include hidden files in glob expansion
    local files=("$dir"/*)
    eval "$old_nullglob"  # Restore previous setting
    eval "$old_dotglob"   # Restore previous setting

    if [ ${#files[@]} -eq 0 ]; then
        return 0  # empty
    else
        return 1  # not empty
    fi
}

# Method 5: Using compgen builtin with early exit
is_empty_compgen() {
    # -G generates filenames matching the pattern
    compgen -G "$1/*" >/dev/null 2>&1 && return 1
    compgen -G "$1/.[!.]*" >/dev/null 2>&1 && return 1
    compgen -G "$1/.??*" >/dev/null 2>&1 && return 1
    return 0
}

run_benchmark() {
    local method="$1"
    local dir="$2"
    local reps="$3"
    local expected_result="$4"

    # Start timing
    local start_time=$(date +%s%N)

    # Run the method multiple times and verify result
    for ((i=1; i<=reps; i++)); do
        if is_empty_$method "$dir"; then
            local actual_result=0  # empty
        else
            local actual_result=1  # not empty
        fi

        if [ "$actual_result" != "$expected_result" ]; then
            echo "ERROR: $method returned wrong result" >&2
            return 1
        fi
    done

    # End timing
    local end_time=$(date +%s%N)

    # Calculate duration in milliseconds
    local duration=$(( (end_time - start_time) / 1000000 ))

    echo -n "${duration}"
}

# Determine the correct value so we can test every is_empty call for correctness
if is_empty_ls-A "$dir"; then
    isempty=0  # empty
else
    isempty=1  # not empty
fi

# Count all entries in directory (files, directories, symlinks, etc., including hidden)
entry_count=$(find "$dir" -maxdepth 1 -mindepth 1 | wc -l)

# Define which benchmarks to run (by default, all are enabled)
# Comment out any line to skip that benchmark
BENCHMARKS=(
    ls-A
    find
    testglob
    shoptarr
    compgen
)

# Run benchmarks and collect timings
declare -A times
for method in "${BENCHMARKS[@]}"; do
    times[$method]=$(run_benchmark "$method" "$dir" "$reps" "$isempty")
    if [ $? -ne 0 ]; then
        exit 1
    fi
done

# Find minimum time
min_time=""
for method in "${!times[@]}"; do
    if [ -z "$min_time" ] || [ "${times[$method]}" -lt "$min_time" ]; then
        min_time="${times[$method]}"
    fi
done

# Calculate relative performance (with 1 decimal place)
declare -A relatives
for method in "${!times[@]}"; do
    if [ "$min_time" -gt 0 ]; then
        relatives[$method]=$(awk "BEGIN {printf \"%.1f\", ${times[$method]} / $min_time}")
    else
        relatives[$method]="1.0"
    fi
done

# Print headers
printf "%-22s %-8s %-8s" "Directory" "#entries" "Iters"
for method in "${BENCHMARKS[@]}"; do
    printf " %-13s" "$method"
done
printf "\n"

# Print data row with timings and relative performance
printf "%-22s %-8s %-8s" "$dir" "$entry_count" "$reps"
for method in "${BENCHMARKS[@]}"; do
    printf " %-13s" "${times[$method]} (${relatives[$method]}X)"
done
printf "\n"
