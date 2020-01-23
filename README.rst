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
* The error ``error: redefinition of 'crypto_memneq'`` means that you architecture
  does not need the memneq workaround in wireguard. To work around the issue you
  can pass ``--env HAS_MEMNEQ=1`` as an additional argument to you docker build.
  If it works, please create an issue or send a PR to fix it properly for your
  architecture.
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

========= ========== =========== ===========================
Model     Platform   DSM Version Is working?
--------- ---------- ----------- ---------------------------
DS1019+   apollolake 6.2         Yes
DS114     armada370  *N/A*       No (Kernel version too old)
DS115j    armada370  *N/A*       No (Kernel version too old)
DS1618+   denverton  6.2         Yes
DS1817+   avoton     6.2         Yes
DS213j    armada370  *N/A*       No (Kernel version too old)
DS213j    armada370  *N/A*       No (Kernel version too old)
DS214play armada370  *N/A*       No (Kernel version too old)
DS214se   armada370  *N/A*       No (Kernel version too old)
DS216se   armada370  *N/A*       No (Kernel version too old)
DS218+    apollolake 6.2         Yes
DS218j    armada38x  6.2         Yes
DS414slim armada370  *N/A*       No (Kernel version too old)
DS415+    avoton     6.2         Yes
DS713+    cedarview  6.2         Yes
DS716+II  braswell   6.2         Yes
DS718+    apollolake 6.2         Yes
DS918+    apollolake 6.2         Yes
RS214     armada370  *N/A*       No (Kernel version too old)
RS816     armada38x  6.2         Yes
DS216+II  braswell   6.2         Yes
DS418play apollolake 6.2         Yes
DS916+    braswell   6.2         Yes
DS1511+   x86        6.2         Yes
========= ========== =========== ===========================

The minimum required kernel version is 3.10. If you have a kernel version lower
than that, WireGuard will not work. You can check your kernel version by
logging in through SSH and running the ``uname -a`` command.


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

To put my WireGuard configuration on the NAS, I used SSH and created a
``wg-quick`` configuration in ``/etc/wireguard/wg0.conf``.  Then I opened the
*Control panel*, opened the *Task scheduler* and created *Triggered task* that
runs ``wg-quick up wg0`` on startup.

When running ``iptables`` in the ``PostUp`` and ``PostDown`` rules I needed to
toggle the interface to make it work. My full startup task looks like this:

.. code-block:: bash

    sleep 60
    wg-quick up wg0
    sleep 5
    wg-quick down wg0
    sleep 5
    wg-quick up wg0

My ``/etc/wireguard/wg0.conf`` looks like this:

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
