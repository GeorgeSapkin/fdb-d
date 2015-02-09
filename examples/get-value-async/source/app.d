import
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
        auto tr = db.createTransaction;

        "Setting SomeKey to SomeValue".writeln;
        auto key = "SomeKey".pack;
        tr[key]  = "SomeValue".pack;
        tr.commitAsync((ex)
        {
            if (ex)
                ex.handleException;
            "Committed write transaction".writeln;

            "Creating read transaction".writeln;
            auto tr2 = db.createTransaction;

            "Reading from SomeKey".writeln;
            auto f = tr.getAsync(key);
            f.await((ex2, value)
            {
                if (ex2)
                    ex2.handleException;

                writeln("SomeKey = " ~ value.unpack!string);

                tr2.cancel;

                "Stopping network".writeln;
                fdb.close;
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
