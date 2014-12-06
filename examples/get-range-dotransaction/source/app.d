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

    auto prefix = "SomeKey";
    auto key1 = pack(prefix, "1");
    auto key2 = pack(prefix, "2");

    "Doing set transaction".writeln;
    auto future = db.doTransaction(
        (tr, commitCallback)
        {
            "Setting values".writeln;
            auto value1 = pack("SomeValue1");
            tr.set(key1, value1);

            auto value2 = pack("SomeValue2");
            tr.set(key2, value2);

            "Committing set transaction".writeln;
            commitCallback(null);
        },
        (ex)
        {
            if (ex)
                ex.handleException;
        });
    future.await;

    "Doing get transaction".writeln;
    auto future2 = db.doTransaction(
        (tr, commitCallback)
        {
            "Getting [SomeKey1, SomeKey2] range".writeln;
            auto f  = tr.getRangeInclusive(key1, key2);
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
            (ex)
            {
                if (ex)
                    ex.handleException;

                "Committing get transaction".writeln;
                commitCallback(null);
            });
        },
        (ex)
        {
            if (ex)
                ex.handleException;

            "Stopping network".writeln;
            fdb.close;
        });
    future2.await;
}

void handleException(E)(E ex)
{
    ex.writeln;
    "Stopping network".writeln;
    fdb.close;
    exit(1);
}
