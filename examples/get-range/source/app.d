import
    std.algorithm,
    std.array,
    std.c.stdlib,
    std.conv,
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
        auto prefix = "SomeKey";
        auto key1   = pack(prefix, 1);
        auto key2   = pack(prefix, 2);

        "Setting values".writeln;
        db[key1] = pack("SomeValue1");
        db[key2] = pack("SomeValue2");

        "Getting [SomeKey.1, SomeKey.2] range".writeln;
        auto r = db[rangeInclusive(key1, key2)];

        foreach (record; r)
        {
            "Got ".write;
            auto keyVars = record.key.unpack;
            if (!keyVars.empty)
            {
                auto key = reduce!aggregate("", keyVars);
                key.write;
            }
            else
                "no key".write;

            " with ".write;
            auto valueVars = record.value.unpack;
            if (!valueVars.empty)
            {
                auto value = reduce!aggregate("", valueVars);
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

auto aggregate(A, B)(A a, B b)
{
    string r;
    if (auto v = b.peek!long)
        r = (*v).to!string;
    else if (auto v = b.peek!string)
        r = *v;
    if (a.empty)
        return r;
    return a ~ "." ~ r;
}
