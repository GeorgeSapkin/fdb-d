import
    std.array,
    std.c.stdlib,
    std.stdio;

import
    fdb,
    fdb.tuple;

void main()
{
    "Starting network".writeln;
    startNetwork;

    Cluster  cluster;
    Database db;
    try
    {
        "Creating cluster".writeln;
        cluster = createCluster;

        "Opening database".writeln;
        db = cluster.openDatabase;
    }
    catch (FDBException ex)
    {
        ex.handleException;
    }

    auto key = "SomeKey".pack;
    try
    {
        "Creating write transaction".writeln;
        auto tr    = db.createTransaction;

        "Setting SomeKey to SomeValue".writeln;
        auto value = "SomeValue".pack;
        tr.set(key, value);
        tr.commit;
    }
    catch (FDBException ex)
    {
        ex.handleException;
    }

    try
    {
        "Creating read transaction".writeln;
        auto tr     = db.createTransaction;

        "Reading from SomeKey".writeln;
        auto f      = tr.get(key, false);
        auto values = f.await.unpack;

        if (!values.empty && values[0].isTypeOf!string)
        {
            auto value = values[0].get!string;
            ("Got " ~ value).writeln;
        }

        tr.commit;
    }
    catch (FDBException ex)
    {
        ex.handleException;
    }

    "Stopping network".writeln;
    stopNetwork;
}

void handleException(E)(E ex)
{
    ex.writeln;
    "Stopping network".writeln;
    stopNetwork;
    exit(1);
}
