#!/bin/bash

# Benchmark script to evaluate different ways of testing whether a directory is empty.
#
#         Usage: ./benchmark <directory> <repetitions>
#              Directory: the directory to test for emptiness
#              Repetitions: the number of times to repeat the test
#
# Results: glob is best for directories with few entries, find is best for directories
# crammed with lots many files and directories. This makes sense because the glob will
# assemble the entire result and immediately throw it away, while find bails after the
# first match.
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
# This is definitely not a good microbenchmark! There's a lot of variation even run-to-run,
# but especially when changing filesystem, CPU, and disk type (rust/ssd/ram). That said, it
# stil provides good info on which algorithm to choose.
#

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
method_ls() {
    local dir="$1"
    if [ -z "$(ls -A "$dir")" ]; then
        return 0  # empty
    else
        return 1  # not empty
    fi
}

# Method 2: Using find with -maxdepth 0 -empty
method_find() {
    local dir="$1"
    if [ -n "$(find "$dir" -maxdepth 0 -empty)" ]; then
        return 0  # empty
    else
        return 1  # not empty
    fi
}

# Method 3: Using test -e with glob
method_test_glob() {
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
method_shopt_array() {
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

run_benchmark() {
    local method_name="$1"
    local method_func="$2"
    local dir="$3"
    local reps="$4"
    local expected_result="$5"

    # Start timing
    local start_time=$(date +%s%N)

    # Run the method multiple times and verify result
    for ((i=1; i<=reps; i++)); do
        if $method_func "$dir"; then
            local actual_result=0  # empty
        else
            local actual_result=1  # not empty
        fi

        if [ "$actual_result" != "$expected_result" ]; then
            echo "ERROR: $method_name returned wrong result" >&2
            exit 1
        fi
    done

    # End timing
    local end_time=$(date +%s%N)

    # Calculate duration in milliseconds
    local duration=$(( (end_time - start_time) / 1000000 ))

    echo -n "${duration}"
}

# Main execution
# Check if directory is empty once for the status column
if method_ls "$dir"; then
    isempty=0  # empty
else
    isempty=1  # not empty
fi

# Count files in directory (including hidden files)
file_count=$(find "$dir" -maxdepth 1 | wc -l)

# Run benchmarks and collect timings
time_ls=$(run_benchmark "ls -A method" method_ls "$dir" "$reps" "$isempty")
time_find=$(run_benchmark "find method" method_find "$dir" "$reps" "$isempty")
time_test=$(run_benchmark "test glob method" method_test_glob "$dir" "$reps" "$isempty")
time_shopt=$(run_benchmark "shopt array method" method_shopt_array "$dir" "$reps" "$isempty")

# Find minimum time
min_time=$time_ls
[ $time_find -lt $min_time ] && min_time=$time_find
[ $time_test -lt $min_time ] && min_time=$time_test
[ $time_shopt -lt $min_time ] && min_time=$time_shopt

# Calculate relative performance (with 1 decimal place)
if [ $min_time -gt 0 ]; then
    rel_ls=$(awk "BEGIN {printf \"%.1f\", $time_ls / $min_time}")
    rel_find=$(awk "BEGIN {printf \"%.1f\", $time_find / $min_time}")
    rel_test=$(awk "BEGIN {printf \"%.1f\", $time_test / $min_time}")
    rel_shopt=$(awk "BEGIN {printf \"%.1f\", $time_shopt / $min_time}")
else
    rel_ls="1.0"
    rel_find="1.0"
    rel_test="1.0"
    rel_shopt="1.0"
fi

# Print headers
formatstr="%-22s %-8s %-8s %-13s %-13s %-13s %-13s\n"
printf "$formatstr" "Directory" "#files" "Iters" "ls -A" "find" "test glob" "shopt array"

# Print data row with timings and relative performance
printf "$formatstr" \
    "$dir" "$file_count" "$reps" \
    "${time_ls} (${rel_ls}X)" \
    "${time_find} (${rel_find}X)" \
    "${time_test} (${rel_test}X)" \
    "${time_shopt} (${rel_shopt}X)"
