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

    auto key = "SomeKey".pack;
    try
    {
        "Creating write transaction".writeln;
        auto tr    = db.createTransaction;

        "Setting SomeKey to SomeValue".writeln;
        auto value = "SomeValue".pack;
        tr.set(key, value);
        tr.commit.await;
    }
    catch (FDBException ex)
    {
        ex.handleException;
    }

    try
    {
        "Creating read transaction".writeln;
        auto tr     = db.createTransaction;

        "Reading from SomeKey".writeln;
        auto f      = tr.get(key, false);
        auto values = f.await.unpack;

        if (!values.empty && values[0].isTypeOf!string)
        {
            auto value = values[0].get!string;
            ("Got " ~ value).writeln;
        }

        tr.commit.await;
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
