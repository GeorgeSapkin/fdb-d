module fdb.error;

import
    std.conv,
    std.exception;

import
    fdb.fdb_c;

enum FDBError : uint
{
    NONE            = 0,
    UNSUPPORTED_API = 2033,
}

class FDBException : Exception
{
    const fdb_error_t err;

    this(const fdb_error_t err)
    {
        auto msg = err.message;
        super(msg, "", 0, null);
        this.err = err;
    }
}

auto message(const fdb_error_t err)
{
    return fdb_get_error(err).to!string;
}

auto enforceError(const fdb_error_t err)
{
    return enforce(err == FDBError.NONE, new FDBException(err));
}