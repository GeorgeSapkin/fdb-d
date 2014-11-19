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
        auto tr     = db.createTransaction;

        "Setting values".writeln;
        auto key1   = "SomeKey1".pack;
        auto value1 = "SomeValue1".pack;
        tr.set(key1, value1);

        auto key2   = "SomeKey2".pack;
        auto value2 = "SomeValue2".pack;
        tr.set(key2, value2);

        tr.commit((ex)
        {
            "Creating read transaction".writeln;
            auto tr2 = db.createTransaction;

            "Getting [SomeKey1, SomeKey2] range".writeln;
            auto f  = tr2.getRangeInclusive(key1, key2);
            f.forEach((Record record)
            {
                auto keyParts   = record.key.unpack;
                if (!keyParts.empty && keyParts[0].isTypeOf!string)
                {
                    auto key = keyParts[0].get!string;
                    ("Got " ~ key).write;
                }

                auto valueParts = record.value.unpack;
                if (!valueParts.empty && valueParts[0].isTypeOf!string)
                {
                    auto value = valueParts[0].get!string;
                    (" with " ~ value).writeln;
                }
            },
            (ex2)
            {
                if (ex2)
                    ex2.handleException;
                "Commiting read transaction".writeln;
                tr2.commit((ex3)
                {
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
