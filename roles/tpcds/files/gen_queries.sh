#!/bin/bash

set -ex

# Use the TPC-provided tool, dsqgen to generate a SQL query file for each
# query template
# Each SQL query file is named [Query Number].sql and stored in the
# generated_queries directory

# The queries will be run with timing on instead of using EXPLAIN ANALYZE
# in part due to the differences in timing this produces.
# https://www.postgresql.org/docs/current/using-explain.html#USING-EXPLAIN-CAVEATS

# If you would like the plan in addition to the timing, add in a line to
# this script something like the following:

# sed -i '1 i\EXPLAIN \(ANALYZE, FORMAT JSON\)' query_0.sql

# The dsqgen tool does not provide any options to prefix the query

for i in ../query_templates/query*.tpl; do
  [[ $i =~ query([0-9]*)\.tpl$ ]] || continue
  ./dsqgen \
    -DIRECTORY ../query_templates/ \
    -INPUT ../query_templates/templates.lst \
    -TEMPLATE "$i" \
    -VERBOSE Y \
    -DIALECT netezza
  mv query_0.sql "generated_queries/${BASH_REMATCH[1]}.sql"
done
