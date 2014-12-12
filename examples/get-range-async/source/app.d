import
    std.algorithm,
    std.array,
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
        auto tr     = db.createTransaction;

        "Setting values".writeln;

        auto prefix = "SomeKey";

        // packing key into a tuple
        auto key1   = pack(prefix, "1");
        auto value1 = pack("SomeValue1");
        tr.set(key1, value1);

        // packing key into a tuple
        auto key2   = pack(prefix, "2");
        auto value2 = pack("SomeValue2");

        tr.set(key2, value2);

        tr.commit((ex)
        {
            "Creating read transaction".writeln;
            auto tr2 = db.createTransaction;

            "Getting [SomeKey1, SomeKey2] range".writeln;
            auto f  = tr2.getRange(rangeInclusive(key1, key2));
            f.forEach((Record record)
            {
                "Got ".write;
                auto keyVars = record.key.unpack;
                if (!keyVars.empty)
                {
                    auto key = reduce!
                        ((a, b) => b.isTypeOf!string ? a ~ b.get!string : a)
                        ("", keyVars);
                    key.write;
                }
                else
                    "no key".write;

                " with ".write;
                auto valueVars = record.value.unpack;
                if (!valueVars.empty)
                {
                    auto value = reduce!
                        ((a, b) => b.isTypeOf!string ? a ~ b.get!string : a)
                        ("", valueVars);
                    value.write;
                }
                else
                    "no value".write;

                writeln;
            },
            (ex2)
            {
                if (ex2)
                    ex2.handleException;
                "Commiting read transaction".writeln;
                tr2.commit((ex3)
                {
                   "Stopping network".writeln;
                    fdb.close;
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
    fdb.close;
    exit(1);
}
