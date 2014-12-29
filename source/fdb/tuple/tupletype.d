module fdb.tuple.tupletype;

import
    std.exception,
    std.uuid;

const uint  floatSignMask  = 0x80_00_00_00U;
const ulong doubleSignMask = 0x80_00_00_00_00_00_00_00UL;

enum TupleType : ubyte {
    /**
     * Null/Empty/Void
     */
    Nil            = 0,

    /**
     * ASCII String
     */
    Bytes          = 1,

    /**
     * UTF-8 String
     */
    Utf8           = 2,

    /**
     * Nested tuple [DRAFT]
     */
    TupleStart     = 3,

    /**
     * End of a nested tuple [DRAFT]
     */
    TupleEnd       = 4,

    IntNeg8        = 12,
    IntNeg7        = 13,
    IntNeg6        = 14,
    IntNeg5        = 15,
    IntNeg4        = 16,
    IntNeg3        = 17,
    IntNeg2        = 18,
    IntNeg1        = 19,

    /**
     * Base value for integer types (20 +/- n)
     */
    IntBase        = 20,
    IntZero        = 20,

    IntPos1        = 21,
    IntPos2        = 22,
    IntPos3        = 23,
    IntPos4        = 24,
    IntPos5        = 25,
    IntPos6        = 26,
    IntPos7        = 27,
    IntPos8        = 28,

    /**
     * Single precision decimals (32-bit, Big-Endian) [DRAFT]
     */
    Single         = 32,

    /**
     * Double precision decimals (64-bit, Big-Endian) [DRAFT]
     */
    Double         = 33,

    /**
     * RFC4122 UUID (128 bits) [DRAFT]
     */
    Uuid128        = 48,

    /**
     * UUID (64 bits) [DRAFT]
     */
    Uuid64         = 49,

    /**
     * Standard prefix of the Directory Layer
     */
    AliasDirectory = 254,

    /**
     * Standard prefix of the System keys, or frequent suffix with key ranges
     */
    AliasSystem    = 255
}

auto FDBsizeof(const TupleType type) pure
in
{
    enforce(
        type.isFDBIntegral ||
        type.isFDBFloat ||
        type.isFDBDouble ||
        type.isFDBUUID);
}
body
{
    if (type.isFDBIntegral)
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

bool isFDBIntegral(const TupleType type) pure @nogc
{
    return type >= TupleType.IntNeg8 && type <= TupleType.IntPos8;
}

bool isFDBFloat(const TupleType type) pure @nogc
{
    return type == TupleType.Single;
}

bool isFDBDouble(const TupleType type) pure @nogc
{
    return type == TupleType.Double;
}

bool isFDBUUID(const TupleType type) pure @nogc
{
    return type == TupleType.Uuid128;
}

unittest
{
    assert(TupleType.IntNeg8.FDBsizeof == 8);
    assert(TupleType.IntNeg7.FDBsizeof == 7);
    assert(TupleType.IntNeg6.FDBsizeof == 6);
    assert(TupleType.IntNeg5.FDBsizeof == 5);
    assert(TupleType.IntNeg4.FDBsizeof == 4);
    assert(TupleType.IntNeg3.FDBsizeof == 3);
    assert(TupleType.IntNeg2.FDBsizeof == 2);
    assert(TupleType.IntNeg1.FDBsizeof == 1);

    assert(TupleType.IntZero.FDBsizeof == 0);

    assert(TupleType.IntPos1.FDBsizeof == 1);
    assert(TupleType.IntPos2.FDBsizeof == 2);
    assert(TupleType.IntPos3.FDBsizeof == 3);
    assert(TupleType.IntPos4.FDBsizeof == 4);
    assert(TupleType.IntPos5.FDBsizeof == 5);
    assert(TupleType.IntPos6.FDBsizeof == 6);
    assert(TupleType.IntPos7.FDBsizeof == 7);
    assert(TupleType.IntPos8.FDBsizeof == 8);
}
