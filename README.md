autobench
====================

Setup
-----

Install Python 3.

```sh
git clone git@github.com:melanieplageman/autobench.git
cd autobench
git submodule init
git submodule update
pip3 install -r requirements.txt
```

If you need to create an Azure VM and need the Azure CLI:

```sh
./setup

```

To create the Azure VM with your own private key:
```sh
ansible-playbook site.yaml -e "privatekey=PRIVATE_KEY"
```

To run fio with certain kernel settings, make a profile in `profiles` (see `profiles/default.yaml` for an example) and run it:
```sh
ansible-playbook fio.yaml -e "privatekey=PRIVATE_KEY" -e "profile_name=PROFILE_NAME"
```

To view a graph of completion latencies for all fio jobs run this way, run `jupyter notebook` in this directory and check out `clat.ipynb`.
You'll need to replace the `json_source_dir` to point to your own.
