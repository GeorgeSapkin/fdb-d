module fdb.tuple.var;

import
    std.conv,
    std.exception,
    std.range,
    std.string,
    std.traits;

import
    fdb.tuple.segmented,
    fdb.tuple.tupletype;

struct FDBVariant
{
    const TupleType type;
    const shared ubyte[] slice;

    @property auto size()
    {
        if (type.isFDBIntegral)
            return type.FDBsizeof;
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
        if (type.isFDBIntegral)
            enforce(type.FDBsizeof == slice.length);
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
}

alias variant = FDBVariant.create;
