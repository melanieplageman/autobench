#!/bin/bash

set -ex

# Run each of the SQL queries (some files contain multiple queries)

output_filename="$2"

wrap() {
  for i in generated_queries/*.sql; do
    [[ $i =~ ([0-9]*)\.sql$ ]] || continue
    number="${BASH_REMATCH[1]}"
    filename="output/$number.out"

    echo $i

    # Timing on gives us the execution time including psql time. The psql
    # options are:
    #   -A, --no-align:    mostly useful when outputting plans to avoid line
    #                      continuation '+'
    #   -q, --quiet:       less output so messages like 'Timing on' don't print
    #   -t, --tuples-only: similarly for capturing EXPLAIN plans since in this
    #                      case we are piping the resulting tuples to /dev/null
    #   -X, --no-psqlrc:   don't read .psqlrc (in case target host has an
    #                      unexpected setting)
    psql -AqtX -c '\timing' -f "$i" -o /dev/null > "$filename"

    # Write the execution time out to a file
    # This isn't especially useful now, since we are collating all of
    # these files into a CSV with execution time for each query in a run
    # However, this makes it easier to switch to capturing output tuples
    # or query plans for each query
    time=()
    while IFS= read -r line; do
      time+=("$line")
    done < <(grep 'Time: ' "$filename" | sed -e 's/Time:\s*//' -e 's/\s*ms\b.*//')

    # Given an output file named like [QUERY NUMBER].out, append all execution
    # times for queries from this query file.
    for i in "${time[@]}"; do
      echo "$number,$i" | tee -a "output/$output_filename.csv"
    done
  done
}

# The output of this script isn't streamed to Ansible
wrap 2> ~/log
