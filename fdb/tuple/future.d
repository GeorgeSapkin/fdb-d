module fdb.tuple.future;

import
    std.exception;

import
    fdb.tuple.unpacker,
    fdb.tuple.var;

auto value(T, F)(F f)
{
    auto unpacked = f.getValue.unpack;
    static if (is(T == FDBTuple))
    {
        return unpacked;
    }
    else static if (is(T == long) || is(T == string))
    {
        enforce(unpacked.length == 1);
        return unpacked[0].get!T;
    }
    else
        static assert(0, "Type " ~ T.to!string ~ " is not supported");
}