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
        auto prefix = "SomeKey";
        auto key1   = pack(prefix, "1");
        auto key2   = pack(prefix, "2");

        "Setting values".writeln;
        db[key1] = pack("SomeValue1");
        db[key2] = pack("SomeValue2");

        "Getting [SomeKey1, SomeKey2] range".writeln;
        auto r = db[rangeInclusive(key1, key2)];

        foreach (record; r)
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
        }
    }
    catch (FDBException ex)
    {
        ex.handleException;
    }

    "Stopping network".writeln;
    fdb.close;
}

void handleException(E)(E ex)
{
    ex.writeln;
    "Stopping network".writeln;
    fdb.close;
    exit(1);
}
