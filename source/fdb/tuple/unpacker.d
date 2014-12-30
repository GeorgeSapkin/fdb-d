module fdb.tuple.unpacker;

import
    std.conv,
    std.exception,
    std.range,
    std.string,
    std.traits,
    std.uuid;

import
    fdb.tuple.part,
    fdb.tuple.segmented,
    fdb.tuple.tupletype;

private struct FDBVariant
{
    const TupleType      type;
    const shared ubyte[] slice;

    @property auto size()
    {
        if (type.isFDBIntegral ||
            type.isFDBFloat ||
            type.isFDBDouble ||
            type.isFDBUUID)
        {
            return type.FDBsizeof;
        }
        else
        {
            auto size = (cast(char[])slice).indexOf(0, 0);
            return (size > 0) ? cast(ulong)size + 1 : 0;
        }
    }

    auto static create(Range)(
        const TupleType type,
        Range           slice) pure
        if (isInputRange!(Unqual!Range))
    in
    {
        if (type.isFDBIntegral ||
            type.isFDBFloat ||
            type.isFDBDouble ||
            type.isFDBUUID)
        {
            enforce(type.FDBsizeof == slice.length);
        }
    }
    body
    {
        return FDBVariant(type, slice);
    }

    auto static create(Range)(
        const TupleType type,
        Range           buffer,
        const ulong     offset) pure
    if (isInputRange!(Unqual!Range))
    {
        if (type.isFDBIntegral)
        {
            auto size = type.FDBsizeof;
            enforce(offset + size <= buffer.length);
            return FDBVariant(
                type,
                cast(shared)buffer[offset .. offset + size]);
        }
        return FDBVariant(type, cast(shared)buffer[offset .. $]);
    }

    auto isTypeOf(T)() const
    {
        static if (is(T == typeof(null)))
            return type == TupleType.Nil;
        else static if (is(T == string))
            return type == TupleType.Utf8;
        else static if (is(T == long))
            return type.isFDBIntegral;
        else static if (is(T == float))
            return type.isFDBFloat;
        else static if (is(T == double))
            return type.isFDBDouble;
        else static if (is(T == UUID))
            return type.isFDBUUID;
        else
            static assert(0, "Type " ~ T.to!string ~ " is not supported");
    }

    auto get(T)() const
    in
    {
        enforce(isTypeOf!T);
    }
    body
    {
        static if (is(T == typeof(null)))
            return getNull;
        else static if (is(T == string))
            return getStr;
        else static if (is(T == long))
            return getInt;
        else static if (is(T == float))
            return getFloat!(float, uint, floatSignMask);
        else static if (is(T == double))
            return getFloat!(double, ulong, doubleSignMask);
        else static if (is(T == UUID))
            return getUUID;
        else
            static assert(0, "Type " ~ T.to!string ~ " is not supported");
    }

    private auto getNull() const pure @nogc
    {
        return null;
    }

    private auto getStr() const
    {
        auto chars = (cast(char[])slice);
        auto size  = chars.indexOf(0, 0);
        if (size > 0)
            chars  = chars[0..size];
        return chars.to!string;
    }

    private auto getInt() const
    {
        Segmented!(ulong, ubyte) dbValue;
        dbValue.segments[0..slice.length] = slice.retro.array;

        long value;
        if (type < TupleType.IntBase)
        {
            value = -(~dbValue.value);
            auto size = type.FDBsizeof;
            if (size < long.sizeof)
            value |= (-1L << (size << 3));
        }
        else
            value = dbValue.value;
        return value;
    }

    private auto getFloat(F, I, alias M)() const
    {
        Segmented!(F, ubyte, I) dbValue;
        dbValue.segments[0..slice.length] = slice.retro.array;

        // check if value is positive or negative
        if ((dbValue.alt & M) != 0)
            dbValue.alt ^= M;
        else // negative
            dbValue.alt  = ~dbValue.alt;

        auto value = dbValue.value;
        return value;
    }

    private auto getUUID() const
    {
        UUID value;
        value.data = slice[0..$];
        return value;
    }
}

alias variant = FDBVariant.create;

auto unpack(Range)(Range bytes)
if (isInputRange!(Unqual!Range))
{
    ulong pos = 0;
    Part[] parts;
    while (pos < bytes.length)
    {
        auto marker = cast(TupleType)bytes[pos++];
        auto var    = variant(marker, bytes, pos);

        Part part;
        foreach (T; Part.AllowedTypes)
            if (var.isTypeOf!T)
            {
                part = var.get!T;
                break;
            }

        parts ~= part;
        pos   += var.size;
    }
    return parts;
}
