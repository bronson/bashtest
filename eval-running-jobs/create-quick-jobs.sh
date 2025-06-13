#!/bin/bash

# creates the quick-jobs file

for i in $(seq 10000); do
    echo quickjob $i 0
done > quick-jobs
