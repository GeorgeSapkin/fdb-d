module fdb.tuple.unpacker;

import
    fdb.tuple.tupletype,
    fdb.tuple.var;

auto unpack(const ubyte[] bytes)
{
    ulong pos = 0;
    FDBVariant[] variants;
    while (pos < bytes.length)
    {
        auto marker = cast(TupleType)bytes[pos++];
        auto var = variant(marker, bytes, pos);
        pos += var.size;
        variants ~= var;
    }
    return variants;
}
