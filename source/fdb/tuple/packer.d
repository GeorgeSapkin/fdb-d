module fdb.tuple.packer;

import
    std.algorithm,
    std.exception,
    std.math,
    std.range,
    std.string,
    std.traits,
    std.typecons,
    std.uuid;

import
    fdb.tuple.integral,
    fdb.tuple.part,
    fdb.tuple.segmented,
    fdb.tuple.tupletype;

private class Packer
{
    ubyte[] bytes;

    void write(typeof(null))
    {
        bytes ~= TupleType.Nil;
    }

    void write(const ubyte[] value)
    {
        bytes ~= TupleType.Bytes;
        bytes ~= value
            .map!(a => a ? [a] : cast(ubyte[])[0x00, byteArrayEndMarker])
            .reduce!"a ~ b";
        bytes ~= byteArrayEndMarker;
    }

    void write(const string value)
    {
        bytes ~= TupleType.Utf8;
        bytes ~= cast(ubyte[])(value.toStringz[0..value.length + 1]);
    }

    void write(T)(const T value)
    if (isIntegral!T)
    in
    {
        enforce(value >= long.min,
            "Value cannot exceed minumum 64-bit signed integer");
        enforce(value <= long.max,
            "Value cannot exceed maximum 64-bit signed integer");
    }
    body
    {
        auto size   = value.minsizeof;
        auto marker =
            cast(ubyte)(TupleType.IntBase + ((value > 0) ? size : -size));

        ulong compliment = (value > 0) ? value : ~(-value);
        auto segmented   = Segmented!ulong(compliment);

        bytes ~= marker;
        bytes ~= segmented.segments[0..size].retro.array;
    }

    void write(T)(const T value)
    if (isFloatingPoint!T)
    {
        auto filtered = (!value.isNaN) ? value : T.nan;
        static if (is(T == float))
        {
            auto segmented  = Segmented!(T, ubyte, uint)(filtered);
            auto mask       = floatSignMask;

            bytes ~= TupleType.Single;
        }
        else static if (is(T == double))
        {
            auto segmented  = Segmented!(T, ubyte, ulong)(filtered);
            auto mask       = doubleSignMask;

            bytes ~= TupleType.Double;
        }
        else
            static assert(0, "Type " ~ T.stringof ~ "is not supported");

        // check if value is positive or negative
        if ((segmented.alt & mask) == 0)
            segmented.alt |= mask;
        else // negative
            segmented.alt  = ~segmented.alt;

        bytes ~= segmented.segments[].retro.array;
    }

    void write(const UUID value)
    in
    {
        enforce(!value.data.empty);
    }
    body
    {
        bytes ~= TupleType.Uuid128;
        bytes ~= value.data;
    }

    void write(R)(const R r)
    if(isInputRange!R && !is(R == string))
    {
        foreach (const e; r)
            write(e);
    }

    void write(const Part part)
    {
        foreach (T; Part.AllowedTypes)
            if (auto v = part.peek!T)
            {
                write(*v);
                return;
            }
        enforce(0, "Type " ~ part.type.toString ~ " is not supported");
    }
}

auto pack(T...)(T parts)
{
    auto w = scoped!Packer;
    foreach (const p; parts)
        w.write(p);
    return w.bytes.idup;
}
