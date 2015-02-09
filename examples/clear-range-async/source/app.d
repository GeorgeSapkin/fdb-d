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
    shared Database db;
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
        auto tr = db.createTransaction;

        auto prefix = "SomeKey";

        auto key1 = pack(prefix, 1);
        auto key2 = pack(prefix, 2);

        "Setting values".writeln;
        tr[key1] = pack("SomeValue1");
        tr[key2] = pack("SomeValue2");

        tr.commitAsync((ex)
        {
            "Creating clear transaction".writeln;
            auto tr2 = db.createTransaction;

            "Clearing set keys".writeln;
            tr2.clearRange(prefix.pack.range);

            "Trying to get [SomeKey1, SomeKey2] range".writeln;
            auto f  = tr2.getRangeAsync(rangeInclusive(key1, key2));
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
                tr2.commitAsync((ex3)
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
