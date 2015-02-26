import
    std.algorithm,
    std.array,
    std.c.stdlib,
    std.conv,
    std.parallelism,
    std.range,
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

    auto prefix = "SomeKey";
    db.clearRange(prefix.pack.range);

    "Setting values using concurrent transactions".writeln;
    foreach(idx; iota(0, 10).parallel)
        db.run((tr)
        {
            auto key = pack(prefix, cast(long)idx);
            tr[key]  = pack(cast(long)idx);
        });

    "Getting SomeKey range".writeln;
    db.run((tr)
    {
        auto r = tr[prefix.pack.range];
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
    });

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
