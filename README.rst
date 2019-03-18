WireGuard support for Synology NAS
==================================
This package adds WireGuard support for Synology NAS drives. It provides the
WireGuard kernel module and the ``wg``/``wg-quick`` commands.


Disclaimer
----------
You use everything here at your own risk. I am responsible if this breaks your
NAS.


Compatibility list
------------------
The following drives have been tested:

===== ========= =========== ===========
Model Platform  DSM Version Is working?
----- --------- ----------- -----------
D218j armada38x 6.2         Yes
===== ========= =========== ===========


Installation
------------
Check the `releases <https://github.com/runfalk/synology-wireguard/releases>`_
page for SPKs for your platform. If there is no SPK you have to compile it
yourself using the instructions below.

1. In the Synology DSM web admin UI, open the Package Center and press the
   *Settings* button.
2. Set the trust level to *Any publisher* and press *OK* to confirm.
3. Press the *Manual install* button and provide the SPK file. Follow the
   instructions until done.

Now you just need to figure out how to configure WireGuard. There are lots of
good guides on how to do that.

To put my WireGuard configuration on the NAS I SSHed into my NAS and created
a ``wg-quick`` configuration in ``/etc/wireguard/wg0.conf``.  Then I opened
the *Control panel*, opened the *Task scheduler* and created *Triggered task*
that runs ``wg-quick up wg0`` on startup.


Compiling
---------
I've used docker to compile everything as ``pkgscripts-ng`` clutters the file
system quite a bit. Start by setting up a new docker container and enter a bash
prompt inside it:

.. code-block:: bash

    sudo docker create -it --privileged --name synobuild ubuntu
    sudo docker start synobuild
    sudo docker exec -it synobuild bash

Now we can setup the build toolchain inside the Docker container:

.. code-block:: bash

    apt-get update
    apt-get install git python3 wget ca-certificates
    git clone https://github.com/SynologyOpenSource/pkgscripts-ng
    mkdir source
    git clone https://github.com/runfalk/synology-wireguard /source/WireGuard

The next step is figuring out which platform and DSM version to compile for.
Using `this table <https://www.synology.com/en-global/knowledgebase/DSM/tutorial/General/What_kind_of_CPU_does_my_NAS_have>`_
you can figure out how the next command should look like. In my case it's:

.. code-block:: bash

    pkgscripts-ng/EnvDeploy -p armada38x -v 6.2
    cp /etc/ssl/certs/ca-certificates.crt /build_env/*/etc/ssl/certs/

The second command is very important, or the package build will fail on SSL
errors. Now we can build an SPK package:

.. code-block:: bash

    pkgscripts-ng/PkgCreate.py -p armada38x -v 6.2 -S --build-opt=-J --print-log -c WireGuard

There should now be an SPK in ``/result_spk``. You can now exit the docker
container and extract the SPKs:

.. code-block:: bash

    sudo docker cp synobuild:/result_spk/WireGuard-0.0.20190227/WireGuard-armada38x-0.0.20190227.spk .
    sudo docker cp synobuild:/result_spk/WireGuard-0.0.20190227/WireGuard-armada38x-0.0.20190227_debug.spk .


Credits
-------
I based a lot of this work on
`this guide <https://www.reddit.com/r/synology/comments/a2erre/guide_intermediate_how_to_install_wireguard_vpn/>`_
by Reddit user `akhener <https://www.reddit.com/user/akhener>`_. However, I had
to modify their instructions a lot since my NAS has an ARM which made cross
compilation a lot trickier.
