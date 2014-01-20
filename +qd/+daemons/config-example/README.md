Configuring MATLAB daemons
--------------------------

1. Copy the files in this folder into some folder outside the matlab-qd project.
2. Make sure this folder is on the MATLAB path.
3. Edit *run_some_deamon.m* etc. to fit your setup.

Rationale
---------

If the temperature of a cryostat starts rising, magnets need to be shut down
(to avoid a quench) and users need to be contacted. Therefore we need
continuously running programs that are not tied to data collection. We now
have two programs that need to access this equipment:

* The monitoring daemon
* The MATLAB instance used for the measurement

To synchronize access, we chose to let the daemon own the equipment, and have
all access proxied through it. The *matlab-daemon* library makes it very easy
to write *remote procedure call* servers in MATLAB and is used throughout (it
was written for the matlab-qd framework). The code for the daemon is located
in this folder; the code for the client is in `qd.ins` and is typically a
thin wrapper around a `daemon.Client`.
