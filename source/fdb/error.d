module fdb.error;

import
    std.conv,
    std.exception;

import
    fdb.fdb_c;

// https://foundationdb.com/key-value-store/documentation/api-error-codes.html
enum FDBError : uint
{
    SUCCESS                       =    0, // Success
    OPERATION_FAILED              = 1000, // Operation failed
    TIMED_OUT                     = 1004, // Operation timed out
    PAST_VERSION                  = 1007, // Version no longer available
    FUTURE_VERSION                = 1009, // Request for future version
    NOT_COMMITTED                 = 1020, // Transaction not committed
    COMMIT_UNKNOWN_RESULT         = 1021, // Transaction may or may not have
                                          // committed
    TRANSACTION_CANCELLED         = 1025, // Operation aborted because the
                                          // transaction was cancelled
    TRANSACTION_TIMED_OUT         = 1031, // Operation aborted because the
                                          // transaction timed out
    TOO_MANY_WATCHES              = 1032, // Too many watches are currently set
    WATCHES_DISABLED              = 1034, // Disabling read your writes also
                                          // disables watches
    OPERATION_CANCELLED           = 1101, // Asynchronous operation cancelled
    FUTURE_RELEASED               = 1102, // The future has been released
    PLATFORM_ERROR                = 1500, // A platform error occurred
    LARGE_ALLOC_FAILED            = 1501, // Large block allocation failed
    PERFORMANCE_COUNTER_ERROR     = 1502, // QueryPerformanceCounter doesn’t
                                          // work
    IO_ERROR                      = 1510, // A disk i/o operation failed
    FILE_NOT_FOUND                = 1511, // File not found
    BIND_FAILED                   = 1512, // Unable to bind to network
    FILE_NOT_READABLE             = 1513, // File could not be read from
    FILE_NOT_WRITABLE             = 1514, // File could not be written to
    NO_CLUSTER_FILE_FOUND         = 1515, // No cluster file found in current
                                          // directory or default location
    CLUSTER_FILE_TOO_LARGE        = 1516, // Cluster file too large to be read
    CLIENT_INVALID_OPERATION      = 2000, // The client made an invalid API
                                          // call
    COMMIT_READ_INCOMPLETE        = 2002, // Commit with incomplete read
    TEST_SPECIFICATION_INVALID    = 2003, // The test specification is invalid
    KEY_OUTSIDE_LEGAL_RANGE       = 2004, // The specified key was outside the
                                          // legal range
    INVERTED_RANGE                = 2005, // The specified range has a begin
                                          // key larger than the end key
    INVALID_OPTION_VALUE          = 2006, // An invalid value was passed with
                                          // the specified option
    INVALID_OPTION                = 2007, // Option not valid in this context
    NETWORK_NOT_SETUP             = 2008, // Action not possible before the
                                          // network is configured
    NETWORK_ALREADY_SETUP         = 2009, // Network can be configured only
                                          // once
    READ_VERSION_ALREADY_SET      = 2010, // Transaction already has a read
                                          // version set
    VERSION_INVALID               = 2011, // Version not valid
    RANGE_LIMITS_INVALID          = 2012, // getRange limits not valid
    INVALID_DATABASE_NAME         = 2013, // Database name not supported in
                                          // this version
    ATTRIBUTE_NOT_FOUND           = 2014, // Attribute not found in string
    FUTURE_NOT_SET                = 2015, // The future has not been set
    FUTURE_NOT_ERROR              = 2016, // The future is not an error
    USED_DURING_COMMIT            = 2017, // An operation was issued while a
                                          // commit was outstanding
    INVALID_MUTATION_TYPE         = 2018, // An invalid atomic mutation type
                                          // was issued
    INCOMPATIBLE_PROTOCOL_VERSION = 2100, // Incompatible protocol version
    TRANSACTION_TOO_LARGE         = 2101, // Transaction too large
    KEY_TOO_LARGE                 = 2102, // Key too large
    VALUE_TOO_LARGE               = 2103, // Value too large
    CONNECTION_STRING_INVALID     = 2104, // Connection string invalid
    ADDRESS_IN_USE                = 2105, // Local address in use
    INVALID_LOCAL_ADDRESS         = 2106, // Invalid local address
    TLS_ERROR                     = 2107, // TLS error
    API_VERSION_UNSET             = 2200, // API version must be set
    API_VERSION_ALREADY_SET       = 2201, // API version may be set only once
    API_VERSION_INVALID           = 2202, // API version not valid
    API_VERSION_NOT_SUPPORTED     = 2203, // API version not supported in this
                                          // version or binding
    EXACT_MODE_WITHOUT_LIMITS     = 2210, // EXACT streaming mode requires
                                          // limits, but none were given
    UNKNOWN_ERROR                 = 4000, // An unknown error occurred
    INTERNAL_ERROR                = 4100  // An internal error occurred
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
    return enforce(err == FDBError.SUCCESS, err.toException);
}

Exception toException(const fdb_error_t err)
{
    return (err == FDBError.SUCCESS) ? null : new FDBException(err);
}
