module fdb.tuple.integral;

import
    std.traits;

ulong minsizeof(T)(in T value)
if (isIntegral!T)
{
    ulong compliment = (value > 0) ? value : -value;
    ulong size = 0;
    while (compliment != 0)
    {
        compliment >>= 8;
        ++size;
    }
    return size;
}
