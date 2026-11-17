leafia-check stick  (READ ONLY - changes nothing on the car)
=============================================================

Root of the stick, nothing in a folder:

  NEMESIS.data       type=execute, path=NEMESIS.sh
  NEMESIS.sh         the diagnostic script (v2)
  README.txt         this file

HOW TO RUN
  1. Insert the stick (Android up).
  2. Say YES to the "execute the compatible item" dialog.
  3. Pull it out, open LEAFIA-CHECK.txt on a computer.
  4. Run it AGAIN after uninstalling Leafia and rebooting. It overwrites
     LEAFIA-CHECK.txt, so rename the first one before you go back to the car.

  To run it a second time on the same stick: unplug it, or delete and rewrite
  NEMESIS.data, so the handler sees a new file identity.

OUTPUT
  LEAFIA-CHECK.txt       report, first line is verdict=
  LEAFIA-CHECK-log.txt   copy of /data/nemesis/wireless.carplay.aa.log

VERDICTS
  NOT-STOCK               files are patched (normal BEFORE the uninstall)
  NOT-REVERTED            live state differs from Leafia's own snapshot (BAD)
  STOCK-BUT-INCOMPLETE    nothing changed, but some item could not be checked
  ALL-STOCK               everything matches and every item was checked (GOAL)

  Exit code 0 only for ALL-STOCK; 3 otherwise, so the unit shows the failure
  dialog when the result needs your attention. The report is written either way.

WHAT IT PROVES
  The strongest section is "revert check: live vs Leafia's own stock snapshot".
  Leafia snapshotted the stock state at install (/data/nemesis/backup/
  wireless.projection). After the uninstall every one of those items must read
  MATCH: the three wifi permission XMLs, the two build.prop lines, the two
  getprops, settings global wifi_on, and the per-model featurexml.cfg.
  That is evidence from the unit's own recorded baseline, not a guess.

  The "file hashes" section is a second, independent check against the stock
  hashes for SG2EV.USA.0000.V015.012.260507. If the unit is not on that build
  the report says so at the top.

LOOK FOR
  part=            must include 5_menu. If it is missing, the BtSettings menu
                   patch was never recorded and the uninstaller will not revert it.
  addon_projection.cardata   if PRESENT-BLOCKS-UNINSTALL, remove that package first.
  backup_dir       must be present BEFORE the uninstall: it is the only way back.
  revert_match / revert_differs   the numbers that decide the verdict.

EXPECTED STOCK HASHES ON THIS UNIT
  2023 Kia Niro EV, SG2EV.USA.0000.V015.012.260507

  HKMC_DiPO.apk               0b04c9d790dfe80e5d33c3be4f3b3f3b
  HKMC_DiPO.odex              6953fa525b2a2fe4252250f38296c837
  HKMC_GPM.apk                c62af648f758dcb01a0acb6c2b901ebf
  HKMC_GPM.odex               c4f751a36be916e72cf93df0436d63c2
  HKMC_Navi_ExSL.apk          19559e742b1d21550aa8f0324e8e6d36
  HKMC_Navi_ExSL.odex         5b55bdee8821d049cedc162b862f64f9
  Iap2ServerApp.apk           fde208439f993986a60396e759797a01
  Iap2ServerApp.odex          f3e22d94150de40f4ed603798358b0e3
  HKMC_BtSettings.apk         no full stock hash known -> reported UNVERIFIED
  HKMC_BtSettings.odex        no full stock hash known -> reported UNVERIFIED
  libautoreceiver_infobank.so 48ee793af8b86052503b8c952b034731

  the three wifi permission XMLs must be absent; the snapshot comparison checks
  that, which matters more than the hashes because it uses the recorded baseline.

NOTES
  - No NEMESIS.emergency file is shipped: while Android is down this stick does
    nothing, which is what you want. It never runs unattended.
  - It only reads. Nothing is written outside this stick.
  - If HKMC_BtSettings.apk reports UNVERIFIED, that is expected: the leafia menu
    patch only recorded a truncated hash. The snapshot comparison covers it.
