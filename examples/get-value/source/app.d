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
        "Setting SomeKey to SomeValue".writeln;
        db[key] = "SomeValue".pack;
    }
    catch (FDBException ex)
    {
        ex.handleException;
    }

    try
    {
        "Reading from SomeKey".writeln;
        auto values = db[key].unpack;

        if (!values.empty && values[0].isTypeOf!string)
        {
            auto value = values[0].get!string;
            ("Got " ~ value).writeln;
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
