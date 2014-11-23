import
    std.algorithm,
    std.array,
    std.exception,
    std.c.stdlib,
    std.stdio;

import
    fdb,
    fdb.tuple;

void main()
{
    Database db;
    try
    {
        "Opening database".writeln;
        db = fdb.open;
    }
    catch (FDBException ex)
    {
        ex.handleException;
    }

    try
    {
        "Creating write transaction".writeln;
        auto tr     = db.createTransaction;

        auto prefix = "SomeKey";

        // packing key into a tuple
        auto key1   = pack(prefix, "1");
        auto value1 = pack("SomeValue1");
        tr.set(key1, value1);

        // packing key into a tuple
        auto key2   = pack(prefix, "2");
        auto value2 = pack("SomeValue2");

        "Setting values".writeln;
        tr.set(key2, value2);

        tr.commit((ex)
        {
            "Creating clear transaction".writeln;
            auto tr2 = db.createTransaction;

            "Clearing set keys".writeln;
            tr2.clearRangeStartsWith(prefix.pack);

            "Trying to get [SomeKey1, SomeKey2] range".writeln;
            auto f  = tr2.getRangeInclusive(key1, key2);
            f.forEach((Record record)
            {
                // This shouldn't be hit
                enforce(false, "Hm, got a record. That's odd.");
            },
            (ex2)
            {
                if (ex2)
                    ex2.handleException;
                "Commiting clear transaction".writeln;
                tr2.commit((ex3)
                {
                   "Stopping network".writeln;
                    fdb.close;
                });
            });
        });
    }
    catch (Exception ex)
    {
        ex.handleException;
    }
}

void handleException(E)(E ex)
{
    ex.writeln;
    "Stopping network".writeln;
    fdb.close;
    exit(1);
}
