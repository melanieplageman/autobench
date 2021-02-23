autobench
=========

# About
autobench is a tool to configure and run various benchmarks on cloud VMs or local machines.

autobench supports provisioning Azure VMs.

autobench supports running [fio](https://fio.readthedocs.io/en/latest/fio_doc.html) jobs. Specifically, autobench allows you to create a profile of specific kernel settings and fio job parameters and will configure the VM with those settings and generate an fio job file with those parameters.
autobench supports building Postgres from source from a specific revision.

autobench supports running the [TPC-DS](https://www.tpc.org/tpcds/default5.asp) benchmark either on an Azure VM or on a user-managed machine (not provisioned by autobench).

# Setup

Install Python 3.

```sh
git clone --recurse-submodules git@github.com:melanieplageman/autobench.git
cd autobench
pip3 install -r requirements.txt
```

# Getting Started

If you need to create an Azure VM and need the Azure CLI:
```sh
./setup
```

## Provisioning an Azure VM

To create the Azure VM with your own private key (if you don't provide one, it will be generated):
```sh
ansible-playbook site.yaml -e "privatekey=PRIVATE_KEY_FILE"
```

The instance size, location, subscription, and resource group name are all parameterizable.
Edit the `roles/vm/defaults/main.yaml` file. You can also override the defaults without editing the file when running the playbook. See the [ansible docs](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#defining-variables-at-runtime) for more info.

If this is the first time you are running site.yaml, you may want to comment out the `Remote setup` tasks. You should first provision the machines and then add them to the ansible inventory. By default the group of hosts on which the remote setup tasks will execute is called `azure_vms`. Change this to the name of the host or hosts on which you plan to run later plays.

## Running an fio job

Results from running fio jobs are stored in a Postgres database. Before running fio jobs, create the Postgres results database, and run `roles/fio/files/schema.sql` to create the tables used for fio results. 

Once the fio results database is set up, provide the database connection information either by altering `roles/fio/defaults/main.yaml` or by providing these parameters as extra vars to the `ansible-playbook` command when running `fio.yaml` or `fio_combinations.yaml`. 

The fio plays are meant to test the effect of different block device settings on overall performance of a given VM with a given disk.

As such, both `fio.yaml` and `fio_combinations.yaml` will leverage the `disk_kernel` role which sets these settings.

There are two ways to run fio jobs on VMs in autobench.

### Method 1

The intent of the first way of running fio (with `fio.yaml`) is to run specific target settings calculated from formulas for each VM and disk size. 

First create a CSV with the following fields:

```
vm_instance_type,vm_cpus,disk_size_gb,vm_disk,disk_kernel_rotational,disk_kernel_max_sectors_kb,disk_kernel_queue_depth,disk_kernel_read_ahead_kb,disk_kernel_nr_requests,disk_kernel_wbt_lat_usec,disk_kernel_io_scheduler,disk_kernel_mq-deadline_fifo_batch,disk_kernel_mq-deadline_writes_starved,disk_kernel_bfq_low_latency
Standard_F2s_v2,2,4,Standard_F2s_v2_4,1,20,10,140,10,0,mq-deadline,16,2,NULL
Standard_F8s_v2,8,4,Standard_F8s_v2_4,1,65,11,520,11,0,bfq,NULL,NULL,1
```

Then modify the included `load.py` script to point to the location of the CSV and run `load.py`. This will create a JSON file (if you specify `to_file=True`) which will be used in `fio.yaml`.
Alternatively, you can create the JSON file yourself using the same schema as described in `load.py`.
The result should be a JSON file in the top-level autobench directory.

Next you should update `fio.yaml` `vars`:
`schedtool` should remain `False` unless you have also updated the task "Run fio jobs" in `roles/fio/tasks/main.yaml` to use Schedtool.

`workload_id` refers to the workload you wish to run. Workloads are added in `roles/fio/templates/workloads/` and should follow the naming convention `[workload_id]_[size].j2` where size must match the size specified in `fio.yaml` under `vars` and called `workload_size`.

`ideal_settings` should be set to the basename of the JSON settings file you created and put in the top-level autobench directory in the above step.

`delete_fio_read_files` determines whether or not the files created by fio for read jobs are deleted after each run. Reusing the files makes it faster to do multiple runs, but, if you are running multiple different workloads on the VM, you may run out of disk space, so setting this to `1` may be desirable.

Assuming you have already provisioned VMs and updated the inventory, you may now run `fio.yaml`. The results will be populated in the specified results database.

Set the number of [forks](https://docs.ansible.com/ansible/latest/user_guide/playbooks_strategies.html#setting-the-number-of-forks) to leverage parallelism. 

```sh
ansible-playbook fio.yaml -e "privatekey=PRIVATE_KEY_FILE"
```

### Method 2

The second way to run fio is to run `fio_combinations.yaml`. The intent of this method is to explore the relationship between different combinations of block device settings. It is easier to use and can also be used to run a single fio job on a single host by editing the combinations down to one setting for each `product()` call.

To run one or more fio jobs, edit the `fio_job_file` var in `fio_combinations.yaml`. 
Note that you should confirm that the `filesize` fio job parameters are appropriate for the disk size under test.

To change the existing kernel parameters' values, edit the `fio_loop_agenda` var in `fio.yaml`.
The `loop_fio` role included in `fio_combinations.yaml` will run every combination of the settings specified in the `fio_loop_agenda` var.

To change which kernel parameters are under test, you will also need to add code to set the new parameter in the `disk_kernel` role and add this setting to the `run` table in the `fio` role, both in the `run` table schema in `roles/fio/files/schema.sql` and the `INSERT` statement in the "Insert run settings and fio results to database" task in `roles/fio/tasks.main.yaml`.

Assuming you have already provisioned VMs and updated the inventory, you may now run `fio_combinations.yaml`. The results will be populated in the specified results database.

```sh
ansible-playbook fio_combinations.yaml -e "privatekey=PRIVATE_KEY_FILE"
```

## Running TPC-DS
To run the TPC-DS benchmark on a certain revision of Postgres:

### Summary
1. Update default parameters in Postgres and TPC-DS roles
2. Add the target host to the Ansible inventory
3. Run the TPC-DS playbook on only that host

### Step-by-step

The TPC-DS role has a dependency on the Postgres role. This ensures that there is a running Postgres instance on the target host on which to run TPC-DS.

The Postgres role will install, build, and run a Postgres instance based off of a specific git revision.

In the Postgres role, specify the PostgreSQL target repository (e.g. your fork of Postgres) and git revision (e.g. branch name, tag, or commit) in the role's defaults:
`roles/postgres/defaults/main.yaml`

If this is the first time Postgres role is running on this target host, you should set `postgresql_redo` in `roles/postgres/defaults/main.yaml` to `yes`. After running this play once, you may want to change `postgresql_redo` to `no` so that the database is not reinitialized.

Once the Postgres role has set up a running Postgres instance, the TPC-DS role will copy over the TPC-DS tools and generate data and queries.

To specify the TPC-DS scale, alter it in `roles/postgres/defaults/main.yaml`. By default it is set to `1` (units are in GB).

Once you have specified the git revision and TPC-DS scale, you can run the TPC-DS play on any host in your host inventory.

If you would like to run TPC-DS on an Azure VM, first create the Azure VM as specified above. This will add it to you hosts inventory. Then, you can run TPC-DS like this:

```sh
ansible-playbook tpcds.yaml -e "privatekey=PRIVATE_KEY" -l azure_vm
```

If you would like to run TPC-DS on a Linux workstation (Debian or Ubuntu) that you have SSH access to, you should add an entry to Ansible inventory by adding a line to a `hosts` file that looks like the following:
```sh
workstation ansible_host=IP_ADDRESS ansible_ssh_private_key=PRIVATE_KEY
```

Then, you can run the TPC-DS role in the same way as on the Azure VM, changing the specified target host:

```sh
ansible-playbook tpcds.yaml -l workstation
```

Note that the Postgres role will attempt to install dependencies on the target host and assumes sudo access. If your user is not a sudo-er and you already have the required dependencies installed, skip the dependencies installation task like this:
```sh
ansible-playbook tpcds.yaml -l workstation --skip-tags "dependencies"
```

Note that this will run all tasks in the TPC-DS role. If you have run TPC-DS on this host before and would like to only regenerate data and run the queries:

```sh
ansible-playbook tpcds.yaml -e "privatekey=PRIVATE_KEY" -l azure_vm --tags "datagen,run"
```

If you have run TPC-DS on this host before and would like to only run the queries:
```sh
ansible-playbook tpcds.yaml -e "privatekey=PRIVATE_KEY" -l azure_vm --tags "run"
```

Ansible project directory layout hints
--------------------------------------

`hosts`: the user's inventory of hosts. This must be created and updated by the user after running `site.yaml`

`site.yaml`: the main Ansible playbook in this project currently. It runs the VM role tasks. First it provisions the VMs and associated resources, then it runs a set up tasks to do setup on the provisioned VM, including loading a newer Linux kernel and restarting the VM. Though you can run the Postgres and TPC-DS roles on other hosts, currently the playbook is geared toward an environment where you can provision a brand new VM for the explicit purpose of doing this work.

`tpcds.yaml`, `fio.yaml`, `fio_combinations.yaml`, `postgres.yaml`: These are the four main playbooks that currently exist. `fio.yaml` and `fio_combinations.yaml` will run the tasks in the `fio` role, as well as the dependent `disk_kernel` role which sets the kernel settings to those under test. Currently it is set to run only on an `azure_vm` host, however it is easy to change that. `postgres.yaml` will run the tasks in the `postgres` role as well as those in the `systemd-user` and `git` roles. `tpcds.yaml` will run the tasks in both the `postgres` role (and its dependencies) as well as the `tpcds` role.

If we start working on various TPC-DS performance experiments, it could be advantageous to create a profile with both various Postgres and TPC-DS settings which will be consumed by the `tpcds` role as well as used to generate a modified `postgresql.conf` file using a template in the `postgres` role. These could go in a new directory in the `profiles` directory.

`results` directory:
This is the target for the formatted output which will be fetched from the target host and copied to the user's local machine. Results copied here are usually in JSON format. However, fio results metadata are stored in a database and the original JSON is deleted.

`roles` directory:
This directory houses most of the tasks for all of the plays in this project.
- `vm` role:
  - `defaults` contain parameters that the user may want to set
  - `tasks`
    - `main.yaml` provisions the VM and associated resources as well as provisioning and attaching the data disk
    - `teardown.yaml` unmounts, detaches, and deletes the disks associated with the VMs specified
  - `templates`
    - `info.j2` templates the `host_vars` used by tasks in other roles run on the VMs provisioned by this role
  - `vars` contains variables that should not be changed by the playbook user - in this case the name of the data disk device after provisioning the VM and data disk
  - `files` contains the specs for the disks and VMs provisioned by this role. This metadata is not available through querying the provisioned VMs, so it must be hard-coded here for reference.
- `kernel` role: This role installs a newer Linux kernel and reboots the target host.
- `data_disk` role:
  - `defaults` contain parameters that the user may want to set
  - `tasks`
    - `main.yaml` partitions, formats, and mounts a data disk on the target host
    - `trim.yaml` trims the file system and is meant to be used between write-heavy benchmarking runs
    - `teardown.yaml` unmounts the file system
  - `templates` contain templates for host vars to be set on the target hosts
- `fio` role:
  - `defaults` contain parameters that the user may want to set
  - `tasks`
    - `main.yaml` contains all of the tasks for setting up and running an fio job on the target host
  - `templates` contains templates for fio workloads (in the `workloads` sub-directory) which are used by `fio.yaml` to gernerate fio job files copied to the target VM
  - `files` contains scripts for setting up the fio results database
- `loop_fio` role: This runs the fio role with every combination of kernel parameters from `fio.yaml`
- `disk_kernel` role: This sets kernel parameters on the target host.
- `git` role: This just installs git
- `postgres` role:
  - `defaults` contain parameters that the user may want to set
  - `tasks` contains the main tasks file
  - `meta` contains dependencies (in this case `systemd-user` and `git`)
  - `templates` contains a template for generating the Postgres service unit file for systemd
  - `vars` contains variables that should not be changed by the playbook user
- `systemd-user` role: this just sets up systemd on the target host
- `tpcds` role:
  - `defaults` contain parameters that the user may want to set
  - `files` these are files that are referenced in the tasks (e.g. scripts to run or files to copy to the target host)
  - `meta` contains dependencies (in this case `postgres`)
  - `tasks` contains the main tasks file
  - `templates`
  - `vars` contains variables that should not be changed by the playbook user

# TODO
- Add a pgbench role which depends on Postgres
