import
    std.stdio;

import
    fdb;

void main()
{
    try
    {
        "Opening database".writeln;
        auto db = fdb.open;
    }
    catch (FDBException ex)
    {
        ex.writeln;
    }

    "Closing connection".writeln;
    fdb.close;
}
