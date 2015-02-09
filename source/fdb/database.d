module fdb.database;

import
    std.conv,
    std.exception,
    std.string,
    std.traits;

import
    fdb.cluster,
    fdb.context,
    fdb.disposable,
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.future,
    fdb.range,
    fdb.rangeinfo,
    fdb.transaction;

shared class Database : IDatabaseContext, IDisposable
{
    private const Cluster  cluster;
    private DatabaseHandle dbh;

    private Transaction[]  transactions;

    invariant()
    {
        assert(cluster !is null);
    }

    this(DatabaseHandle dbh, const shared Cluster cluster)
    in
    {
        enforce(cluster !is null, "cluster must be set");
        enforce(dbh !is null, "dbh must be set");
    }
    body
    {
        this.dbh     = cast(shared)dbh;
        this.cluster = cluster;
    }

    ~this()
    {
        dispose;
    }

    void dispose()
    {
        if (!dbh) return;

        fdb_database_destroy(cast(DatabaseHandle)dbh);
        dbh = null;
    }

    private auto createTransactionImpl()
    {
        TransactionHandle th;
        auto err = fdb_database_create_transaction(
            cast(DatabaseHandle)dbh,
            &th);
        enforceError(err);

        auto tr = new shared Transaction(th, this);
        return tr;
    }

    auto createTransaction()
    out (result)
    {
        assert(result !is null);
    }
    body
    {
        auto tr = createTransactionImpl();
        synchronized (this)
            transactions ~= tr;
        return tr;
    }

    /**
     * Set the size of the client location cache. Raising this value can boost
     * performance in very large databases where clients access data in a near-
     * random pattern. Defaults to 100000.
     * Parameter: (Int) Max location cache entries
     */
    void setLocationCacheSize(in long value) const
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
    void setMaxWatches(in long value) const
    {
        setDatabaseOption(DatabaseOption.MAX_WATCHES, value);
    }

    /**
     * Specify the machine ID that was passed to fdbserver processes running on
     * the same machine as this client, for better location-aware load
     * balancing.
     * Parameter: (String) Hexadecimal ID
     */
    void setMachineId(in string value) const
    {
        setDatabaseOption(DatabaseOption.MACHINE_ID, value);
    }

    /**
     * Specify the datacenter ID that was passed to fdbserver processes running
     * in the same datacenter as this client, for better location-aware load
     * balancing.
     * Parameter: (String) Hexadecimal ID
     */
    void setDatacenterId(in string value) const
    {
        setDatabaseOption(DatabaseOption.DATACENTER_ID, value);
    }

    private void setDatabaseOption(in DatabaseOption op, in long value) const
    {
        const auto err = fdb_database_set_option(
            cast(DatabaseHandle)dbh,
            op,
            cast(immutable(char)*)&value,
            cast(int)value.sizeof);
        enforceError(err);
    }

    private void setDatabaseOption(in DatabaseOption op, in string value) const
    {
        const auto err = fdb_database_set_option(
            cast(DatabaseHandle)dbh,
            op,
            value.toStringz,
            cast(int)value.length);
        enforceError(err);
    }

    shared(Value) opIndex(in Key key)
    {
        scope auto tr = createTransactionImpl();
        auto value    = tr[key];
        tr.commit;
        return value;
    }

    RecordRange opIndex(RangeInfo info)
    {
        auto tr    = createTransaction();
        auto value = cast(RecordRange)tr[info];
        tr.commit;
        return value;
    }

    inout(Value) opIndexAssign(inout(Value) value, in Key key)
    {
        scope auto tr = createTransactionImpl();
        tr[key]       = value;
        tr.commit;
        return value;
    }

    void clear(in Key key)
    {
        scope auto tr = createTransactionImpl();
        tr.clear(key);
        tr.commit;
    }

    void clearRange(in RangeInfo info)
    {
        scope auto tr = createTransactionImpl();
        tr.clearRange(info);
        tr.commit;
    }

    void run(in WorkFunc func)
    {
        scope auto tr = createTransactionImpl();
        tr.run(func);
    }

    auto runAsync(in WorkFunc func, in VoidFutureCallback commitCallback)
    {
        auto tr = createTransaction();
        return tr.runAsync(func, commitCallback);
    }
}
