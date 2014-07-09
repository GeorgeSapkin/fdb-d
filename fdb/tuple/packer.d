module fdb.tuple.packer;

import
    std.exception,
    std.string,
    std.traits;

import
    fdb.tuple.integral,
    fdb.tuple.tupletype;

private class Packer {
    ubyte[] bytes;

    void write(T)(const T value)
    if (isIntegral!T)
    {
        enforce(value >= long.min,
            "Value cannot exceed minumum 64-bit signed integer");
        enforce(value <= long.max,
            "Value cannot exceed maximum 64-bit signed integer");

        auto size = value.minsizeof;
        auto marker =
            cast(ubyte)(TupleType.IntBase + ((value > 0) ? size : -size));
        bytes ~= marker;

        ulong compliment = (value > 0) ? value : -value;
        while (compliment != 0)
        {
            bytes ~= compliment & 0xff;
            compliment >>= 8;
        }
    }

    void write(const string value)
    {
        bytes ~= TupleType.Utf8;
        bytes ~= cast(ubyte[])(value.toStringz[0..value.length + 1]);
    }
}

auto pack(T...)(T parts)
{
    scope auto w = new Packer;
    foreach (const p; parts)
        w.write(p);
    return w.bytes.idup;
}