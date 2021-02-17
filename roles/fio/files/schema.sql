CREATE TABLE IF NOT EXISTS disk (
  id INTEGER GENERATED BY DEFAULT AS IDENTITY,
  size_gb INTEGER NOT NULL CHECK (size_gb > 0),
  provisioned_iops INTEGER NOT NULL CHECK (
    provisioned_iops > 0),
  burst_iops INTEGER NOT NULL CHECK (
    burst_iops > 0),
  provisioned_tput_mbps INTEGER NOT NULL CHECK (
    provisioned_tput_mbps > 0),
  burst_tput_mbps INTEGER NOT NULL CHECK (
    burst_tput_mbps > 0),
  PRIMARY KEY(id)
);

CREATE TABLE IF NOT EXISTS vm (
  id INTEGER GENERATED BY DEFAULT AS IDENTITY,
  instance_type TEXT NOT NULL,
  ncpu INTEGER NOT NULL,
  memory_gib INTEGER NOT NULL,
  max_iops INTEGER NOT NULL,
  max_tput_mbps INTEGER NOT NULL,
  default_max_sectors_kb INTEGER NOT NULL,
  default_nr_requests INTEGER NOT NULL,
  default_read_ahead_kb INTEGER NOT NULL,
  default_queue_depth INTEGER NOT NULL,
  default_scheduler TEXT NOT NULL,
  default_wbt_lat_usec INTEGER NOT NULL,
  PRIMARY KEY(id)
);

CREATE TABLE IF NOT EXISTS run_staging (
  index_data JSONB NOT NULL,
  run_data JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS formula (
  id INTEGER GENERATED BY DEFAULT AS IDENTITY,
  description TEXT NOT NULL
  PRIMARY KEY(id)
);

CREATE TABLE IF NOT EXISTS run (
  id INTEGER GENERATED BY DEFAULT AS IDENTITY,

  schedtool BOOLEAN DEFAULT FALSE,

  settings INTEGER NOT NULL REFERENCES formula(id),

  workload_id INTEGER NOT NULL,

  disk_id INTEGER NOT NULL REFERENCES disk(id),
  disk_device TEXT NOT NULL,

  vm_id INTEGER NOT NULL REFERENCES vm(id),

  nr_hw_queues INTEGER,

  kernel_nr_requests    INTEGER NOT NULL,
  kernel_max_sectors_kb INTEGER NOT NULL,
  kernel_read_ahead_kb  INTEGER NOT NULL,
  kernel_queue_depth    INTEGER NOT NULL,
  kernel_io_scheduler   TEXT NOT NULL,
  kernel_wbt_lat_usec   INTEGER NOT NULL,
  kernel_rotational     INTEGER NOT NULL,

  kernel_mqdeadline_fifo_batch     INTEGER,
  kernel_mqdeadline_writes_starved INTEGER,
  kernel_bfq_low_latency            INTEGER,
  CONSTRAINT
  kernel_io_scheduler_configuration CHECK (
    (
      kernel_io_scheduler = 'mq-deadline' AND
      kernel_bfq_low_latency IS NULL AND
      kernel_mqdeadline_fifo_batch IS NOT NULL AND
      kernel_mqdeadline_writes_starved IS NOT NULL
    ) OR
    (
      kernel_io_scheduler = 'bfq' AND
      kernel_bfq_low_latency IS NOT NULL AND
      kernel_mqdeadline_fifo_batch IS NULL AND
      kernel_mqdeadline_writes_starved IS NULL
    ) OR
    (
      kernel_io_scheduler = 'none' AND
      kernel_bfq_low_latency IS NULL AND
      kernel_mqdeadline_fifo_batch IS NULL AND
      kernel_mqdeadline_writes_starved IS NULL
    )
  ),

  data JSONB NOT NULL,
  PRIMARY KEY(id)
);

TRUNCATE disk CASCADE;
INSERT INTO disk (
  size_gb,
  provisioned_iops,
  burst_iops,
  provisioned_tput_mbps,
  burst_tput_mbps) VALUES
  (4,     120, 3500, 25, 170),
  (8,     120, 3500, 25, 170),
  (16,    120, 3500, 25, 170),
  (32,    120, 3500, 25, 170),
  (64,    240, 3500, 50, 170),
  (128,   500, 3500, 100, 170),
  (256,   1100, 3500, 125, 170),
  (512,   2300, 3500, 150, 170),
  (1024, 5000, 5000, 200, 200),
  (4096, 7500, 7500, 250, 250),
  (2048, 7500, 7500, 250, 250),
  (8192, 16000, 16000, 500, 500),
  (16384, 18000, 18000, 750, 750),
  (32767, 20000, 20000, 900, 900);

TRUNCATE vm CASCADE;
-- TODO: add D and E-series
INSERT INTO vm(
  instance_type,
  ncpu,
  memory_gib,
  max_iops,
  max_tput_mbps,
  default_max_sectors_kb,
  default_nr_requests,
  default_read_ahead_kb,
  default_queue_depth,
  default_scheduler,
  default_wbt_lat_usec) VALUES
  ('Standard_F2s_v2', 2, 4, 3200, 47, 512, 332, 128, 2048, 'none', 75000),
  ('Standard_F4s_v2', 4, 8, 6400, 95, 512, 332, 128, 2048, 'none', 75000),
  ('Standard_F8s_v2', 8, 16, 12800, 190, 512, 664, 128, 2048, 'none', 75000),
  ('Standard_F16s_v2', 16, 32, 25600, 380, 512, 1328, 128, 2048, 'none', 75000),
  ('Standard_F32s_v2', 32, 64, 51200, 750, 512, 2656, 128, 2048, 'none', 75000),
  ('Standard_F48s_v2', 48, 96, 76800, 1100, 512, 3985, 128, 2048, 'none', 75000),
  ('Standard_F64s_v2', 64, 128, 80000, 1100, 512, 5313, 128, 2048, 'none', 75000),
  ('Standard_F72s_v2', 72, 144, 80000, 1100, 512, 5977, 128, 2048, 'none', 75000),
  ('Standard_E64s_v3', 64, 432, 80000, 2000, 512, 5068, 128, 2048, 'none', 75000);
