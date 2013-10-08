effective_tld_names
    Description:
      Mozilla's table of TLD names. These are used to perform lookups on TLD values
      when validating HTTP cookie domains.

    Version:
      HG revision 06c405ba54b3 downloaded from http://publicsuffix.org/list/

    License:
      MPL (source list).

    Modifications:
      - None

EMKeychain
    Description:
      Simple Cocoa wrapper for the keychain APIs.

    Version:
      1.0.1 downloaded from http://extendmac.com/EMKeychain/

    License:
      MIT

    Modifications:
      - Replaced calls to the now-deprecated GetMacOSStatusErrorString().
      - The _logsErrors BOOL was modified to default to YES.


MAPlistTypeChecking
    Description:
      Conveniences for type-checking and reporting errors in plists, JSON, and other similar structures

    Version:
      861ccff49e888824b5bc22ee87df38db5f045fcc checked out from https://github.com/mikeash/MAPlistTypeChecking

    License:
      BSD

    Modifications:
      - Added a -description method to MAErrorReportingObject.
      
PlausibleDatabase
    Description:
      A SQL database access library for Objective-C, initially focused on SQLite as an application database.

    Version:
      v2.0-beta2 downloaded https://opensource.plausible.coop/wiki/display/PLDB/PLDatabase

    License:
      3-Clause BSD

    Modifications:
      - None

PLFoundation
    Description:
      Plausible Labs ObjC Foundation Library

    Version:
      v0.3 checked out and built from https://opensource.plausible.coop/stash/projects/PLF/repos/plfoundation-objc

    License:
      MIT

    Modifications:
      - None


PXSourceList
    Description:
      A Source List control for use with the Mac OS X 10.5 SDK or above.

    Version:
      c7e5c7930c2aa48470aca9c301712cb41af44f0b checked out from https://github.com/Perspx/PXSourceList

    License:
      BSD

    Modifications:
      - Fixed signed/unsigned comparisons
      - Hacked in support for displaying a progress indicator for -1 badge values.
