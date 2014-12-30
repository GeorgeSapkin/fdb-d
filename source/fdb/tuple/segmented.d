module fdb.tuple.segmented;

union Segmented(V, S = ubyte, A = V) if (V.sizeof == A.sizeof)
{
    enum count(V, S) = (V.sizeof + (S.sizeof - 1)) / S.sizeof;

    V value;
    A alt;

    S[count!(V, S)] segments;
}
