_expand_directory() {
    local find_args=("$1")
    local excluded_dir

    # prune any excluded directories
    for excluded_dir in "${tsk_excluded_dirs[@]}"; do
        find_args+=("-path" "*/$excluded_dir" "-prune" "-o")
    done
    # match .test and .skip files
    find_args+=("-type" "f" "(" "-name" "*.test" "-o" "-name" "*.skip" ")" "-print0")
    # run find, sort it, and stuff its results into the testfiles array
    while IFS= read -r -d '' testfile; do
        testfiles+=("$testfile")
    done < <(find "${find_args[@]}" | sort -z)
}

# also ensures the number is positive
_ensure_numeric_argument() {
    if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "invalid $1 argument: $2" >&2
        exit 1
    fi
}

_process_arguments() {
    local arguments=()
    testfiles=() # TODO: declare this global list of testfiles
    max_jobs=12  # not the fastest but should be reasonably close

    # If the test harness is being sourced from a testfile, add the testfile.
    if [ -n "$tsk_launched_file" ]; then
        arguments+=("$tsk_launched_file")
    fi

    # TODO: if a directory is specified, add all .test files in that directory
    # TODO: should we care about whether a testfile argument ends in '.test'?
    while (( "$#" )); do case $1 in
        -b|--benchmark) tsk_benchmark_enabled=true; shift;;
        -d|--diff) tsk_use_diff=true; shift;;
        -e|--exclude) exclude_directory "$2"; shift; shift;;
        --exclude=*) exclude_directory "${1#*=}"; shift;;
        -f|--formatter) tsk_test_formatter="$2"; shift; shift;;
        --formatter=*) tsk_test_formatter="${1#*=}"; shift;;
        -j|--jobs) max_jobs="$2"; shift; shift;;
        --jobs=*) max_jobs="${1#*=}"; shift;;
        -k|--keep) tsk_keep_artifacts=true; shift;;
        -m|--matching) tsk_match_utility="grep $2"; shift; shift;;
        --matching=*) tsk_match_utility="grep ${1#*=}"; shift;;
        -r|--repeat) tsk_repeat="$2"; shift; shift;;
        --repeat=*) tsk_repeat="${1#*=}"; shift;;
        -w|--watch) WATCH=true; shift;;               # TODO
        *) arguments+=("$1"); shift;;
    esac; done

    _ensure_numeric_argument "max jobs" "$max_jobs"
    _ensure_numeric_argument "repeat" "$tsk_repeat"

    # If no files or directories were specified, run all files in the cwd.
    if [ ${#arguments[@]} -eq 0 ]; then
        arguments+=(".")
    fi

    # expand the arguments into an array of testfiles
    for arg in "${arguments[@]}"; do
        if [ -d "$arg" ]; then
            _expand_directory "$arg"
        elif [ -f "$arg" ]; then
            testfiles+=("$arg")
        else
            abort "Could not find $arg"
        fi
    done

    if [ ${#testfiles[@]} -eq 0 ]; then
        echo "No testfiles found. Testfile names must end in '.test'." >&2
        exit 120
    fi
}
