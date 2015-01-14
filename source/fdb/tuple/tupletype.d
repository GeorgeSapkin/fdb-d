module fdb.tuple.tupletype;

import
    std.exception,
    std.uuid;

static const uint  floatSignMask      = 0x80_00_00_00U;
static const ulong doubleSignMask     = 0x80_00_00_00_00_00_00_00UL;
static const ulong byteArrayEndMarker = 0xff;

enum TupleType : ubyte
{
    /**
     * Null/Empty/Void
     */
    Nil     = 0,

    /**
     * ASCII String
     */
    Bytes   = 1,

    /**
     * UTF-8 String
     */
    Utf8    = 2,

    IntNeg8 = 12,
    IntNeg7 = 13,
    IntNeg6 = 14,
    IntNeg5 = 15,
    IntNeg4 = 16,
    IntNeg3 = 17,
    IntNeg2 = 18,
    IntNeg1 = 19,

    /**
     * Base value for integer types (20 +/- n)
     */
    IntBase = 20,
    IntZero = IntBase,

    IntPos1 = 21,
    IntPos2 = 22,
    IntPos3 = 23,
    IntPos4 = 24,
    IntPos5 = 25,
    IntPos6 = 26,
    IntPos7 = 27,
    IntPos8 = 28,

    /**
     * Single precision decimals (32-bit, Big-Endian) [DRAFT]
     */
    Single  = 32,

    /**
     * Double precision decimals (64-bit, Big-Endian) [DRAFT]
     */
    Double  = 33,

    /**
     * RFC4122 UUID (128 bits) [DRAFT]
     */
    Uuid128 = 48,
}

auto FDBsizeof(in TupleType type) pure
in
{
    enforce(
        type == TupleType.Nil ||
        type.isFDBIntegral ||
        type.isFDBFloat ||
        type.isFDBDouble ||
        type.isFDBUUID);
}
body
{
    if (type == TupleType.Nil)
        return 0;
    else if (type.isFDBIntegral)
    {
        if (type > TupleType.IntZero)
            return type - TupleType.IntZero;
        return TupleType.IntZero - type;
    }
    else if (type.isFDBFloat)
        return float.sizeof;
    else if (type.isFDBDouble)
        return double.sizeof;
    else if (type.isFDBUUID)
        return UUID.sizeof;

    assert(0, "Type " ~ type ~ " is not supported");
}

bool isFDBIntegral(in TupleType type) pure @nogc
{
    return type >= TupleType.IntNeg8 && type <= TupleType.IntPos8;
}

bool isFDBFloat(in TupleType type) pure @nogc
{
    return type == TupleType.Single;
}

bool isFDBDouble(in TupleType type) pure @nogc
{
    return type == TupleType.Double;
}

bool isFDBUUID(in TupleType type) pure @nogc
{
    return type == TupleType.Uuid128;
}

unittest
{
    with (TupleType)
    {
        assert(IntNeg8.FDBsizeof == 8);
        assert(IntNeg7.FDBsizeof == 7);
        assert(IntNeg6.FDBsizeof == 6);
        assert(IntNeg5.FDBsizeof == 5);
        assert(IntNeg4.FDBsizeof == 4);
        assert(IntNeg3.FDBsizeof == 3);
        assert(IntNeg2.FDBsizeof == 2);
        assert(IntNeg1.FDBsizeof == 1);

        assert(IntZero.FDBsizeof == 0);

        assert(IntPos1.FDBsizeof == 1);
        assert(IntPos2.FDBsizeof == 2);
        assert(IntPos3.FDBsizeof == 3);
        assert(IntPos4.FDBsizeof == 4);
        assert(IntPos5.FDBsizeof == 5);
        assert(IntPos6.FDBsizeof == 6);
        assert(IntPos7.FDBsizeof == 7);
        assert(IntPos8.FDBsizeof == 8);
    }
}
