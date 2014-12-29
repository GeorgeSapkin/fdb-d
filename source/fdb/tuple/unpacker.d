module fdb.tuple.unpacker;

import
    std.range,
    std.traits;

import
    fdb.tuple.part,
    fdb.tuple.tupletype,
    fdb.tuple.var;

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

        parts ~= part;
        pos   += var.size;
    }
    return parts;
}
