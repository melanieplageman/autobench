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

Once the fio results database is set up, provide the database connection information either by altering `roles/fio/defaults/main.yaml` or by providing these parameters as extra vars to the `ansible-playbook` command when running `fio.yaml`. 

To run one or more fio jobs, either define your fio job details in `fio.yaml`, define the var `fio_job_file`, or delete this var and edit the fio job file template `roles/fio/templates/profile.fio.j2`.
To change the kernel parameters' values, edit them in `fio.yaml`. To change which kernel parameters are under test, you will also need to add code to set the new parameter in the `disk_kernel` role and add this setting to what is appended to the index file in the `fio` role.
To run the fio jobs, run the top level `fio.yaml` file.

```sh
ansible-playbook fio.yaml -e "privatekey=PRIVATE_KEY_FILE"
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

`tpcds.yaml`, `fio.yaml`, `postgres.yaml`: These are the three main playbooks that currently exist. `fio.yaml` will run the tasks in the `fio` role, as well as the dependent `disk_kernel` role which sets the kernel settings to those under test. Currently it is set to run only on an `azure_vm` host, however it is easy to change that. `postgres.yaml` will run the tasks in the `postgres` role as well as those in the `systemd-user` and `git` roles. `tpcds.yaml` will run the tasks in both the `postgres` role (and its dependencies) as well as the `tpcds` role.

If we start working on various TPC-DS performance experiments, it could be advantageous to create a profile with both various Postgres and TPC-DS settings which will be consumed by the `tpcds` role as well as used to generate a modified `postgresql.conf` file using a template in the `postgres` role. These could go in a new directory in the `profiles` directory.

`results` directory:
This is the target for the formatted output which will be fetched from the target host and copied to the user's local machine. Results copied here are usually in JSON format. However, fio results metadata is stored in a database.

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
    - `reset.yaml` trims the file system and is meant to be used between write-heavy benchmarking runs
    - `teardown.yaml` unmounts the file system
  - `templates` contain templates for host vars to be set on the target hosts
- `fio` role:
  - `defaults` contain parameters that the user may want to set
  - `tasks`
    - `main.yaml` contains all of the tasks for setting up and running an fio job on the target host
  - `templates` contains the template for generating the profile with the fio job settings and kernel parameters specified in profile supplied by the user when running the fio playbook
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
