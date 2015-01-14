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

    private ulong _length;
    @property auto length()
    {
        return _length;
    }

    private Part _part;
    @property Part part()
    {
        if (_part.hasValue)
            return _part;

        switch (type) with (TupleType)
        {
            case Nil:
                _part = readNull;
                break;
            case Bytes:
                _part = readBytes;
                break;
            case Utf8:
                _part = readStr;
                break;
            case IntNeg8: .. case IntPos8:
                _part = readInt;
                break;
            case Single:
                _part = readFloat!(float, uint, floatSignMask);
                break;
            case Double:
                _part = readFloat!(double, ulong, doubleSignMask);
                break;
            case Uuid128:
                _part = readUUID;
                break;
            default:
                enforce(0, "Type " ~ type.to!string ~ " is not supported");
                break;
        }

        return _part;
    }

    this(Range)(in TupleType type, Range slice) pure
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

    this(Range)(in TupleType type, Range buffer, in ulong offset) pure
    if (isInputRange!(Unqual!Range))
    {
        if (type == TupleType.Nil ||
            type.isFDBIntegral ||
            type.isFDBFloat ||
            type.isFDBDouble ||
            type.isFDBUUID)
        {
            auto size = type.FDBsizeof;
            enforce(offset + size <= buffer.length);

            this.type    = type;
            this.slice   = cast(shared)buffer[offset .. offset + size];
            this._length = size;
        }
        else
        {
            this.type  = type;
            this.slice = cast(shared)buffer[offset .. $];
        }
    }

    private auto readNull() const pure @nogc
    {
        return null;
    }

    private auto readBytes()
    in
    {
        enforce(slice.length > 1);
    }
    body
    {
        ubyte[] result;
        foreach(idx, b; slice)
            if (b != byteArrayEndMarker)
                result ~= b;
            else if (idx > 0 && slice[idx - 1] != 0x00)
            {
                _length = idx + 1;
                break;
            }

        return result;
    }

    private auto readStr()
    {
        auto chars = (cast(char[])slice);
        auto size  = chars.indexOf(0, 0);
        if (size > 0)
        {
            chars   = chars[0..size];
            _length = size + 1;
        }
        return chars.to!string;
    }

    private auto readInt() const
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

    private auto readFloat(F, I, alias M)() const
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

    private auto readUUID() const
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
