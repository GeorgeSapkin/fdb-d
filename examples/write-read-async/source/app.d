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

    try
    {
        "Creating write transaction".writeln;
        auto tr    = db.createTransaction;

        "Setting SomeKey to SomeValue".writeln;
        auto key   = "SomeKey".pack;
        auto value = "SomeValue".pack;
        tr.set(key, value);
        tr.commit((ex)
        {
            if (ex)
                ex.handleException;
            "Committed write transaction".writeln;

            "Creating read transaction".writeln;
            auto tr2 = db.createTransaction;

            "Reading from SomeKey".writeln;
            auto f   = tr.get(key, false);
            f.await((ex2, value)
            {
                if (ex2)
                    ex2.handleException;
                "Received values".writeln;

                auto values = value.unpack;

                if (!values.empty && values[0].isTypeOf!string)
                {
                    auto val = values[0].get!string;
                    ("Got " ~ val).writeln;
                }

                tr2.commit((ex3)
                {
                    if (ex3)
                        ex3.handleException;
                    "Committed read transaction".writeln;

                    "Stopping network".writeln;
                    stopNetwork;
                });
            });
        });
    }
    catch (FDBException ex)
    {
        ex.handleException;
    }
}

void handleException(E)(E ex)
{
    ex.writeln;
    "Stopping network".writeln;
    stopNetwork;
    exit(1);
}
