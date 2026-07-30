module app;

import std.stdio : writeln;
import beam;

void main()
{
    ensureScheduler();
    writeln("ActorShell Phase 1 bootstrap");
    writeln("libbeam_d scheduler + mailbox ready; UI phases are stubs.");
    writeln("Docs: docs/modules/ROOT/pages/index.adoc");
}
