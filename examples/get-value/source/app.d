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
        "SomeKey = ".write;
        auto values = db[key].unpack;

        if (!values.empty)
            if (auto value = values[0].peek!string)
                (*value).write;
        writeln;
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
