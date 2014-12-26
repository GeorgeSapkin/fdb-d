module fdb.tuple.segmented;

union Segmented(A, S)
{
    enum count(A, S) = (A.sizeof + (S.sizeof - 1)) / S.sizeof;

    A value;
    S[count!(A, S)] segments;
}
