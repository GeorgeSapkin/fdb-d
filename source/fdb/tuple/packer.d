module fdb.tuple.packer;

import
    std.exception,
    std.math,
    std.range,
    std.string,
    std.traits,
    std.uuid;

import
    fdb.tuple.integral,
    fdb.tuple.part,
    fdb.tuple.segmented,
    fdb.tuple.tupletype;

private class Packer
{
    ubyte[] bytes;

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
        auto segmented   = Segmented!(ulong, ubyte)(compliment);

        bytes ~= marker;
        bytes ~= segmented.segments[0..size].retro.array;
    }

    void write(T)(const T value)
    if (isFloatingPoint!T)
    {
        auto filtered = (!value.isNaN) ? value : T.nan;
        static if (is(T == float))
        {
            auto segmented = Segmented!(T, ubyte, uint)(filtered);

            // check if value is positive or negative
            if ((segmented.alt & floatSignMask) == 0)
                segmented.alt |= floatSignMask;
            else // negative
                segmented.alt  = ~segmented.alt;

            bytes ~= TupleType.Single;
            bytes ~= segmented.segments[].retro.array;
        }
        else static if (is(T == double))
        {
            auto segmented = Segmented!(T, ubyte, ulong)(filtered);

            // check if value is positive or negative
            if ((segmented.alt & doubleSignMask) == 0)
                segmented.alt |= doubleSignMask;
            else // negative
                segmented.alt  = ~segmented.alt;

            bytes ~= TupleType.Double;
            bytes ~= segmented.segments[].retro.array;
        }
        else
            static assert(0, "Type " ~ T.stringof ~ "is not supported");
    }

    void write(const string value)
    {
        bytes ~= TupleType.Utf8;
        bytes ~= cast(ubyte[])(value.toStringz[0..value.length + 1]);
    }

    void write(T : UUID)(const T value)
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
                break;
            }
    }
}

auto pack(T...)(T parts)
{
    scope auto w = new Packer;
    foreach (const p; parts)
        w.write(p);
    return w.bytes.idup;
}
