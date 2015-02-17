module fdb.traits;

package auto share(T)(T val) @nogc pure
{
    return cast(shared)val;
}

package auto unshare(T)(shared T val) @nogc pure
{
    return cast(T)val;
}
