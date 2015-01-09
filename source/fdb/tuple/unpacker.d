module fdb.tuple.unpacker;

import
    std.array,
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

    @property auto length()
    {
        return slice.length;
    }

    private Part _part;
    @property Part part()
    {
        if (_part.hasValue)
            return _part;

        switch (type) with (TupleType)
        {
            case Nil:
                _part = getNull;
                break;
            case Bytes:
                _part = getBytes;
                break;
            case Utf8:
                _part  = getStr;
                break;
            case IntNeg8: .. case IntPos8:
                _part = getInt;
                break;
            case Single:
                _part = getFloat!(float, uint, floatSignMask);
                break;
            case Double:
                _part = getFloat!(double, ulong, doubleSignMask);
                break;
            case Uuid128:
                _part = getUUID;
                break;
            default:
                enforce(0, "Type " ~ type.to!string ~ " is not supported");
                break;
        }

        return _part;
    }

    this(Range)(
        const TupleType type,
        Range           slice) pure
    if (isInputRange!(Unqual!Range))
    in
    {
        with (type)
            if (isFDBIntegral || isFDBFloat || isFDBDouble || isFDBUUID)
                enforce(FDBsizeof == slice.length);
    }
    body
    {
        this.type  = type;
        this.slice = slice;
    }

    this(Range)(
        const TupleType type,
        Range           buffer,
        const ulong     offset) pure
    if (isInputRange!(Unqual!Range))
    {
        if (type.isFDBIntegral)
        {
            auto size = type.FDBsizeof;
            enforce(offset + size <= buffer.length);

            this.type  = type;
            this.slice = cast(shared)buffer[offset .. offset + size];
        }
        else
        {
            this.type  = type;
            this.slice = cast(shared)buffer[offset .. $];
        }
    }

    private auto getNull() const pure @nogc
    {
        return null;
    }

    private auto getBytes() const
    in
    {
        enforce(slice.length > 1);
        enforce(slice[$ - 1] == byteArrayEndMarker);
    }
    body
    {
        ubyte[] result;
        foreach(i, b; slice[0..$-1])
            if (b != byteArrayEndMarker || i == 0 || slice[i - 1] != 0x00)
                result ~= b;
        return result;
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
        Segmented!ulong dbValue;
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

auto unpack(Range)(Range bytes)
if (isInputRange!(Unqual!Range))
{
    ulong pos = 0;
    Part[] parts;
    while (pos < bytes.length)
    {
        auto marker = cast(TupleType)bytes[pos++];
        auto var    = FDBVariant(marker, bytes, pos);

        parts ~= var.part;
        pos   += var.length;
    }
    return parts;
}

/**
 * Returns single value if type matches T
 */
auto unpack(T, size_t i = 0, Range)(Range bytes)
{
    auto unpacked = unpack(bytes);
    auto value    = unpacked[i].get!T;
    return value;
}
