module fdb.database;

import
    std.conv,
    std.exception,
    std.string;

import
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.transaction;

class Database
{
    private DatabaseHandle db;

    this(DatabaseHandle db)
    {
        this.db = db;
    }

    ~this()
    {
        destroy;
    }

    void destroy()
    {
        fdb_database_destroy(db);
    }

    auto createTransaction()
    {
        TransactionHandle tr;
        enforceError(fdb_database_create_transaction(db, &tr));
        return new Transaction(tr);
    }

    /**
     * Set the size of the client location cache. Raising this value can boost
     * performance in very large databases where clients access data in a near-
     * random pattern. Defaults to 100000.
     * Parameter: (Int) Max location cache entries
     */
    void setLocationCacheSize(long value)
    {
        setDatabaseOption(DatabaseOption.LOCATION_CACHE_SIZE, value);
    }

    /**
     * Set the maximum number of watches allowed to be outstanding on a database
     * connection. Increasing this number could result in increased resource
     * usage. Reducing this number will not cancel any outstanding watches.
     * Defaults to 10000 and cannot be larger than 1000000.
     * Parameter: (Int) Max outstanding watches
     */
    void setMaxWatches(long value)
    {
        setDatabaseOption(DatabaseOption.MAX_WATCHES, value);
    }

    /**
     * Specify the machine ID that was passed to fdbserver processes running on
     * the same machine as this client, for better location-aware load
     * balancing.
     * Parameter: (String) Hexadecimal ID
     */
    void setMachineId(string value)
    {
        setDatabaseOption(DatabaseOption.MACHINE_ID, value);
    }

    /**
     * Specify the datacenter ID that was passed to fdbserver processes running
     * in the same datacenter as this client, for better location-aware load
     * balancing.
     * Parameter: (String) Hexadecimal ID
     */
    void setDatacenterId(string value)
    {
        setDatabaseOption(DatabaseOption.DATACENTER_ID, value);
    }

    private void setDatabaseOption(DatabaseOption op, long value)
    {
        auto err = fdb_database_set_option(
            db,
            op,
            cast(immutable(char)*)&value,
            cast(int)value.sizeof);
        enforceError(err);
    }

    private void setDatabaseOption(DatabaseOption op, string value)
    {
        auto err = fdb_database_set_option(
            db,
            op,
            value.toStringz,
            cast(int)value.length);
        enforceError(err);
    }
}