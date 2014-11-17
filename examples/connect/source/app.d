import
    std.stdio;

import
    fdb;

void main()
{
    "Starting network".writeln;
    startNetwork;

    try
    {
        "Creating cluster".writeln;
        auto cluster = createCluster;

        "Opening database".writeln;
        auto db = cluster.openDatabase;
    }
    catch (FDBException ex)
    {
        ex.writeln;
    }

    "Stopping network".writeln;
    stopNetwork;
}
