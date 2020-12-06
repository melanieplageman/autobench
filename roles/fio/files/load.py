import psycopg2
import os
import json

target_dir = ''
index_files = [ target_dir + fname for fname in os.listdir(target_dir) if fname.endswith('.json') and fname.startswith('index')]
print(index_files)
host=""
port=5432
dbname=""
user=""
password=""
sslmode="require"
conn_string = "host={0} user={1} dbname={2} password={3} sslmode={4}".format(host, user, dbname, password, sslmode)

xform_query = """
INSERT INTO run (schedtool, disk_id, disk_device, vm_id, kernel_nr_requests, kernel_max_sectors_kb, kernel_read_ahead_kb, kernel_queue_depth, kernel_wbt_lat_usec, kernel_io_scheduler, data)
  SELECT
    (index_data->'settings'->>'schedtool')::bool as schedtool,
    disk.id as disk_id,
    index_data->'settings'->'IUT'->'disk'->>'device' as disk_device,
    vm.id as vm_id,
    (index_data->'settings'->'kernel'->>'nr_requests')::int AS kernel_nr_requests,
    (index_data->'settings'->'kernel'->>'max_sectors_kb')::int AS kernel_max_sectors_kb,
    (index_data->'settings'->'kernel'->>'read_ahead_kb')::int AS kernel_read_ahead_kb,
    (index_data->'settings'->'kernel'->>'queue_depth')::int AS kernel_queue_depth,
    (index_data->'settings'->'kernel'->>'wbt_lat_usec')::int AS kernel_wbt_lat_usec,
    index_data->'settings'->'kernel'->>'io_scheduler' AS kernel_io_scheduler,
    run_data
  FROM run_staging
  INNER JOIN
  vm
  ON index_data->'settings'->'IUT'->'vm'->'specs'->>'instance_type' = instance_type
  INNER JOIN
  disk
  ON (index_data->'settings'->'IUT'->'disk'->>'size_gb')::int = disk.size_gb;
"""

conn = psycopg2.connect(conn_string)
print("Connection established")
cur = conn.cursor()

for index_file in index_files:
    with open(index_file) as idxf:
        index_data = json.loads(idxf.read())
        print("About to load results from %s" % index_file)

        with open(target_dir + index_item["result_file"]) as result_file:
            result = json.loads(result_file.read())

            cur.execute("INSERT INTO run_staging (index_data, run_data) VALUES (%s, %s);",
                        (json.dumps(index_item), json.dumps(result)))

            print("Loaded file %s" % index_item["result_file"])

cur.execute(xform_query)
print("Transformed data and loaded into run, vm, and disk tables.")
cur.execute("TRUNCATE run_staging;")
print("Truncated run_staging table")

conn.commit()
cur.close()
conn.close()
