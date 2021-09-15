WireGuard support for Synology NAS
==================================
This package adds WireGuard support for Synology NAS drives. It provides the
WireGuard kernel module and the ``wg``/``wg-quick`` commands.


Disclaimer
----------
You use everything here at your own risk. I am not responsible if this breaks
your NAS. Realistically it should not result in data loss, but it could render
your NAS unaccessible if something goes wrong.

If you are not comfortable with removing your drives from the NAS and manually
recover the data, this might not be for you.


FAQ/Known issues
----------------
* The ``Dns = x.x.x.x`` setting is unsupported. If you try it you will get the
  following message:
  ``/usr/local/bin/wg-quick: line 31: resolvconf: command not found``
* IPv6 is probably not supported (at least not using ``wg-quick``). Due to the
  system version of ``iproute2``
  `being too old <https://lists.zx2c4.com/pipermail/wireguard/2018-April/002687.html>`_.
  You'll get the error message
  ``Error: argument "suppress_prefixlength" is wrong: Failed to parse rule type``.
* Everything appears to be OK when running ``wg show`` but no traffic is flowing
  through the tunnel. Apparently there is some kind of race when setting up the
  interface. The simplest known workaround is to append
  ``; sleep 5; ip route add 10.0.0.0/16 dev wg0`` to the ``PostUp`` rule. This
  assumes that your WireGuard IP subnet is ``10.0.x.x``. See
  `issue #10 <https://github.com/runfalk/synology-wireguard/issues/10>`_ for
  more information.

PRs that solve these issues are welcome.


Compatibility list
------------------
All models marked *Is working* have been confirmed by users to work. If your
model has the same platform as one of the working ones, chances are it will
work for you too.

=========== ========== =========== ===========================
Model       Platform   DSM Version Is working?
----------- ---------- ----------- ---------------------------
DS1019+     apollolake 6.2         Yes
DS114       armada370  *N/A*       No (Kernel version too old)
DS115j      armada370  *N/A*       No (Kernel version too old)
DS116       armada38x  6.2         Yes
DS1511+     x64        6.2         Yes
DS1618+     denverton  6.2         Yes
DS1817+     avoton     6.2/7.0     Yes
DS1815+     avoton     6.2         Yes
DS213j      armada370  *N/A*       No (Kernel version too old)
DS213j      armada370  *N/A*       No (Kernel version too old)
DS214play   armada370  *N/A*       No (Kernel version too old)
DS214se     armada370  *N/A*       No (Kernel version too old)
DS216+II    braswell   6.2         Yes
DS216se     armada370  *N/A*       No (Kernel version too old)
DS216Play   monaco     6.2         Yes
DS218       rtd1296    6.2         Yes
DS218+      apollolake 6.2         Yes
DS218j      armada38x  6.2         Yes
DS220+      geminilake 6.2/7.0     Yes
DS3617xs    broadwell  6.2         Yes
DS414slim   armada370  *N/A*       No (Kernel version too old)
DS415+      avoton     6.2         Yes
DS418play   apollolake 6.2         Yes
DS713+      cedarview  6.2         Yes
DS716+II    braswell   6.2         Yes
DS916+      braswell   6.2         Yes
DS918+      apollolake 6.2         Yes
RS214       armada370  *N/A*       No (Kernel version too old)
RS816       armada38x  6.2         Yes
Virtual DSM kvmx64     6.2/7.0     Yes
=========== ========== =========== ===========================

The minimum required kernel version is 3.10. If you have a kernel version lower
than that, WireGuard will not work. You can check your kernel version by
logging in through SSH and running the ``uname -a`` command.

This project is also confirmed to be compatible with other brand NAS stations
using `XPEnology <https://xpenology.com/forum/topic/9392-general-faq/>`_.

========= ================ ========== =========== ===========================
Model     Hardware version Platform   DSM Version Is working?
--------- ---------------- ---------- ----------- ---------------------------
HP54NL    DS3615xs         bromolow   6.2         Yes
========= ================ ========== =========== ===========================


Installation
------------
1. Check the `releases <https://github.com/runfalk/synology-wireguard/releases>`_
   page for SPKs for your platform and DSM version. If there is no SPK you have to compile it
   yourself using the instruction below.

2. (*Not applicable for DSM from 7.0*)
   In the Synology DSM web admin UI, open the Package Center and press the Settings button.
   Set the trust level to Any publisher and press OK to confirm.

3. In the Package Center, press the *Manual install* button and provide the SPK file. Follow the instructions until done.

4. (*Only for DSM from 7.0*)
   From DSM 7.0, an additional step is required for the WireGuard package to start.
   This is related to `preventing  packages not signed by Synology from running with root privileges <https://www.synology.com/en-us/knowledgebase/DSM/tutorial/Third_Party/supported_third_party_packages_beta>`_.
   When installing the package, uncheck the ``run after installation`` option. After installing the package, `connect to the NAS via SSH <https://www.synology.com/en-us/knowledgebase/DSMUC/help/DSMUC/AdminCenter/system_terminal>`_ and run the ``sudo /var/packages/WireGuard/scripts/start`` command.


Now you just need to figure out how to configure WireGuard. There are lots of
good guides on how to do that.

To put my WireGuard configuration on the NAS, I used SSH and created a
``wg-quick`` configuration in ``/etc/wireguard/wg0.conf``. My configuration looks like this:

.. code-block::

    [Interface]
    Address = 10.0.1.1/16
    PrivateKey = <nas-private-key>
    ListenPort = 16666
    PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

    [Peer]
    PublicKey = <peer-public-key>
    AllowedIPs = 10.0.1.2/32

Note that you need to modify the rules if your network interface is not
``eth0``. You can check which name your interface has by running ``ip a`` in an
SSH session.


Adding WireGuard to autostart
-----------------------------
DSM since version 7.0 comes with `systemd unit <https://www.freedesktop.org/software/systemd/man/systemd.unit.html>`_ support, while for previous versions you can use the built-in `upstart <http://upstart.ubuntu.com/>`_.
To standardize the process of adding the WireGuard interface to the autostart, a simple ``wg-autostart`` script has been developed.

**Important note:** before adding the interface to the autostart, start it manually by ``sudo wg-quick up wg0`` ensure that it does not cause the system to crash and that you can still access your NAS properly. Otherwise, you may not be able to start the NAS or you may not be able to access the device after a reboot.

To add the ``wg0`` interface to the autostart, run the command:

.. code-block::

    sudo wg-autostart enable wg0


To remove the ``wg0`` interface from the autostart, run the command:

.. code-block::

    sudo wg-autostart disable wg0


Compiling
---------
I've used docker to compile everything, as ``pkgscripts-ng`` clutters the file
system quite a bit. First create a docker image by running the following
command in this repository:

.. code-block:: bash

    git clone https://github.com/runfalk/synology-wireguard.git
    cd synology-wireguard/
    sudo docker build -t synobuild .

Now we can build for any platform and DSM version using:

.. code-block:: bash

    sudo docker run --rm --privileged --env PACKAGE_ARCH=<arch> --env DSM_VER=<dsm-ver> -v $(pwd)/artifacts:/result_spk synobuild

You should replace ``<arch>`` with your NAS's package arch. Using
`this table <https://www.synology.com/en-global/knowledgebase/DSM/tutorial/General/What_kind_of_CPU_does_my_NAS_have>`_
you can figure out which one to use. Note that the package arch must be
lowercase. ``<dsm-ver>`` should be replaced with the version of DSM you are
compiling for.

For the DS218j that I have, the complete command looks like this:

.. code-block:: bash

    sudo docker run --rm --privileged --env PACKAGE_ARCH=armada38x --env DSM_VER=6.2 -v $(pwd)/artifacts:/result_spk synobuild

If everything worked you should have a directory called ``artifacts`` that
contains your SPK files.


Avoiding timeouts when downloading build files
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
It can take a long time to pull development files from SourceForge, including
occasional timeouts. To get around this, create a folder locally and map it to
the `/toolkit_tarballs` Docker volume using the following command:
`-v $(pwd)/<path/to/folder>:/toolkit_tarballs`
to the `docker run` command listed above. This will allow the development files
to be stored on your host machine instead of ephemerally in the container. The
image will check for existing development files in that folder and will use
them instead of pulling them from SourceForge when possible. You can also
download the files directly and put them in the folder you created by downloading
them from here: https://sourceforge.net/projects/dsgpl/files/toolkit/DSM<DSM_VER>
(e.g. https://sourceforge.net/projects/dsgpl/files/toolkit/DSM6.2)


Credits
-------
I based a lot of this work on
`this guide <https://www.reddit.com/r/synology/comments/a2erre/guide_intermediate_how_to_install_wireguard_vpn/>`_
by Reddit user `akhener <https://www.reddit.com/user/akhener>`_. However, I had
to modify their instructions a lot since my NAS has an ARM CPU which made cross
compilation a lot trickier.

GitHub user `galaxysd <https://github.com/galaxysd>`_ made
`a guide <https://galaxysd.github.io/linux/20170804/2017-08-04-iptables-on-Synology-DSM-6>`_
on how to enable iptables NAT support.
