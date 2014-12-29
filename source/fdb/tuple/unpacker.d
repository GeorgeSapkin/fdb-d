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
        static if (is(T == long))
            return type.isFDBIntegral;
        else static if (is(T == string))
            return type == TupleType.Utf8 || type == TupleType.Bytes;
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
        static if (is(T == long))
            return getInt;
        else static if (is(T == string))
            return getStr;
        else static if (is(T == float))
            return getFloat;
        else static if (is(T == double))
            return getDouble;
        else static if (is(T == UUID))
            return getUUID;
        else
            static assert(0, "Type " ~ T.to!string ~ " is not supported");
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

    private auto getStr() const
    {
        auto chars = (cast(char[])slice);
        auto size = chars.indexOf(0, 0);
        if (size > 0)
            chars = chars[0..size];
        return chars.to!string;
    }

    private auto getFloat() const
    {
        Segmented!(float, ubyte, uint) dbValue;
        dbValue.segments[0..slice.length] = slice.retro.array;

        // check if value is positive or negative
        if ((dbValue.alt & floatSignMask) != 0)
            dbValue.alt ^= floatSignMask;
        else // negative
            dbValue.alt  = ~dbValue.alt;

        auto value = dbValue.value;
        return value;
    }

    private auto getDouble() const
    {
        Segmented!(double, ubyte, ulong) dbValue;
        dbValue.segments[0..slice.length] = slice.retro.array;

        // check if value is positive or negative
        if ((dbValue.alt & doubleSignMask) != 0)
            dbValue.alt ^= doubleSignMask;
        else // negative
            dbValue.alt = ~dbValue.alt;

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
        if (var.isTypeOf!long)
            part = var.get!long;
        else if (var.isTypeOf!string)
            part = var.get!string;
        else if (var.isTypeOf!float)
            part = var.get!float;
        else if (var.isTypeOf!double)
            part = var.get!double;
        else if (var.isTypeOf!UUID)
            part = var.get!UUID;

        parts ~= part;
        pos   += var.size;
    }
    return parts;
}
