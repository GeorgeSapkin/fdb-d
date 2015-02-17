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
        "Creating write transaction".writeln;
        auto tr = db.createTransaction;

        auto prefix = "SomeKey";
        tr.clearRange(prefix.pack.range);

        "Setting values".writeln;
        foreach(idx; 0..10)
        {
            auto key = pack(prefix, cast(long)idx);
            tr[key]  = pack(cast(long)idx);
        }

        tr.commitAsync((ex)
        {
            "Creating read transaction".writeln;
            auto tr2 = db.createTransaction;

            "Getting [SomeKey] range".writeln;
            auto f  = tr2.getRangeAsync(prefix.pack.range);
            f.forEach((Record record)
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
            },
            (ex2)
            {
                if (ex2)
                    ex2.handleException;
                tr2.cancel;
                fdb.close;
            });
        });
    }
    catch (FDBException ex)
        ex.handleException;
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
