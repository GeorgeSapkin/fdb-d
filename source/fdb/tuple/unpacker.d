module fdb.tuple.unpacker;

import
    std.range,
    std.traits;

import
    fdb.tuple.tupletype,
    fdb.tuple.var;

auto unpack(Range)(Range bytes) if (isInputRange!(Unqual!Range))
{
    ulong pos = 0;
    FDBTuple variants;
    while (pos < bytes.length)
    {
        auto marker = cast(TupleType)bytes[pos++];
        auto var = variant(marker, bytes, pos);
        pos += var.size;
        variants ~= var;
    }
    return variants;
}
