module fdb.transaction;

import
    std.conv,
    std.exception;

import
    fdb.database,
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options,
    fdb.future,
    fdb.rangeinfo;

class Transaction
{
    private const Database          db;
    private const TransactionHandle tr;

    this(const Database db, const TransactionHandle tr)
    {
        this.db = db;
        this.tr = tr;
    }

    ~this()
    {
        destroy;
    }

    void destroy()
    {
        fdb_transaction_destroy(tr);
    }

    void set(const Key key, const Value value) const
    {
        fdb_transaction_set(
            tr,
            &key[0],
            cast(int)key.length,
            &value[0],
            cast(int)value.length);
    }

    auto commit(VoidFutureCallback callback = null)
    {
        // cancel, commit and reset are mutually exclusive
        synchronized (this)
        {
            auto fh = fdb_transaction_commit(tr);
            auto future = startOrCreateFuture!VoidFuture(fh, this, callback);
            return future;
        }
    }

    void cancel()
    {
        // cancel, commit and reset are mutually exclusive
        synchronized (this)
        {
            fdb_transaction_cancel(tr);
        }
    }

    /**
     * Resets transaction to its initial state
     */
    void reset()
    {
        // cancel, commit and reset are mutually exclusive
        synchronized (this)
        {
            fdb_transaction_reset(tr);
        }
    }

    void clear(const Key key) const
    {
        fdb_transaction_clear(tr, &key[0], cast(int)key.length);
    }

    void clearRange(const Key begin, const Key end) const
    {
        fdb_transaction_clear_range(
            tr,
            &begin[0],
            cast(int)begin.length,
            &end[0],
            cast(int)end.length);
    }

    auto getKey(
        const Selector      selector,
        const bool          snapshot,
        KeyFutureCallback   callback = null) const
    {

        auto fh = fdb_transaction_get_key(
            tr,
            &selector.key[0],
            cast(int)selector.key.length,
            cast(fdb_bool_t)selector.orEqual,
            selector.offset,
            cast(fdb_bool_t)snapshot);

        auto future = startOrCreateFuture!KeyFuture(fh, this, callback);
        return future;
    }

    auto get(
        const Key           key,
        const bool          snapshot,
        ValueFutureCallback callback = null) const
    {

        auto fh = fdb_transaction_get(
            tr,
            &key[0],
            cast(int)key.length,
            snapshot);

        auto future = startOrCreateFuture!ValueFuture(fh, this, callback);
        return future;
    }

    auto getRange(
        RangeInfo               info,
        KeyValueFutureCallback  callback = null) const
    {
        auto fh = fdb_transaction_get_range(
            tr,

            &info.start.key[0],
            cast(int)info.start.key.length,
            cast(fdb_bool_t)info.start.orEqual,
            info.start.offset,

            &info.end.key[0],
            cast(int)info.end.key.length,
            cast(fdb_bool_t)info.end.orEqual,
            info.end.offset,

            info.limit,
            0,
            info.mode,
            info.iteration,
            info.snapshot,
            info.reverse);

        auto future = startOrCreateFuture!KeyValueFuture(
            fh, this, info, callback);
        return future;
    }

    auto getRange(
        Selector                start,
        Selector                end,
        const int               limit       = 0,
        const StreamingMode     mode        = StreamingMode.ITERATOR,
        const bool              snapshot    = false,
        const bool              reverse     = false,
        const int               iteration   = 1,
        KeyValueFutureCallback  callback    = null) const
    {
        auto info = RangeInfo(
            start, end, limit, mode, iteration, snapshot, reverse);
        return getRange(info, callback);
    }

    auto getRange(
        const Key               start,
        const Key               end,
        const int               limit       = 0,
        const StreamingMode     mode        = StreamingMode.ITERATOR,
        const bool              snapshot    = false,
        const bool              reverse     = false,
        const int               iteration   = 1,
        KeyValueFutureCallback  callback    = null) const
    {
        auto startSel = start.firstGreaterOrEqual;
        auto endSel   = end.firstGreaterOrEqual;
        return getRange(
            startSel, endSel, limit, mode, snapshot, reverse, iteration, callback);
    }

    auto getRangeStartsWith(
        const Key               prefix,
        const int               limit       = 0,
        const StreamingMode     mode        = StreamingMode.ITERATOR,
        const bool              snapshot    = false,
        const bool              reverse     = false,
        const int               iteration   = 1,
        KeyValueFutureCallback  callback    = null) const
    {
        auto start = prefix;
        auto end   = prefix.getEndPrefix;
        return getRange(
            start, end, limit, mode, snapshot, reverse, iteration, callback);
    }

    auto watch(const Key key, VoidFutureCallback callback = null) const
    {
        auto fh = fdb_transaction_watch(
            tr,
            &key[0],
            cast(int)key.length);
        auto future = startOrCreateFuture!WatchFuture(fh, this, callback);
        return future;
    }

    private void addConflictRange(
        const Key               start,
        const Key               end,
        const ConflictRangeType type) const
    {
        auto err = fdb_transaction_add_conflict_range(
            tr,
            &start[0],
            cast(int)start.length,
            &end[0],
            cast(int)end.length,
            type);
        enforceError(err);
    }

    void addReadConflictRange(const Key start, const Key end) const
    {
        addConflictRange(start, end, ConflictRangeType.READ);
    }

    void addWriteConflictRange(const Key start, const Key end) const
    {
        addConflictRange(start, end, ConflictRangeType.WRITE);
    }

    auto onError(
        const FDBException  ex,
        VoidFutureCallback  callback = null) const
    {
        auto fh = fdb_transaction_on_error(tr, ex.err);
        auto future = startOrCreateFuture!VoidFuture(fh, this, callback);
        return future;
    }

    void setReadVersion(const int ver) const
    {
        fdb_transaction_set_read_version(tr, ver);
    }

    auto getReadVersion(VersionFutureCallback callback = null) const
    {
        auto fh = fdb_transaction_get_read_version(tr);
        auto future = startOrCreateFuture!VersionFuture(fh, this, callback);
        return future;
    }

    auto getCommittedVersion() const
    {
        long ver;
        enforceError(fdb_transaction_get_committed_version(tr, &ver));
        return ver;
    }

    auto getAddressesForKey(
        const Key               key,
        StringFutureCallback    callback = null) const
    {
        auto fh = fdb_transaction_get_addresses_for_key(
            tr,
            &key[0],
            cast(int)key.length);

        auto future = startOrCreateFuture!StringFuture(fh, this, callback);
        return future;
    }

    /* Performs an addition of little-endian integers. If the existing value
     * in the database is not present or shorter than ``param``, it is first
     * extended to the length of ``param`` with zero bytes.  If ``param`` is
     * shorter than the existing value in the database, the existing value is
     * truncated to match the length of ``param``. The integers to be added
     * must be stored in a little-endian representation.  They can be signed
     * in two's complement representation or unsigned. You can add to an integer
     * at a known offset in the value by prepending the appropriate number of
     * zero bytes to ``param`` and padding with zero bytes to match the length
     * of the value. However, this offset technique requires that you know the
     * addition will not cause the integer field within the value to overflow.
     */
    void add(const Key key, const Value value) const
    {
        callAtomicOperation(key, value, MutationType.ADD);
    }

    // Deprecated
    // ADD_MUTATION_TYPE("and", 6);

    /* Performs a bitwise ``and`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    void bitAnd(const Key key, const Value value) const
    {
        callAtomicOperation(key, value, MutationType.BIT_AND);
    }

    // Deprecated
    //ADD_MUTATION_TYPE("or", 7);

    /* Performs a bitwise ``or`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    void bitOr(const Key key, const Value value) const
    {
        callAtomicOperation(key, value, MutationType.BIT_OR);
    }

    // Deprecated
    // ADD_MUTATION_TYPE("xor", 8);

    /* Performs a bitwise ``xor`` operation.  If the existing value in the
     * database is not present or shorter than ``param``, it is first extended
     * to the length of ``param`` with zero bytes.  If ``param`` is shorter than
     * the existing value in the database, the existing value is truncated to
     * match the length of ``param``.
     */
    void bitXor(const Key key, const Value value) const
    {
        callAtomicOperation(key, value, MutationType.BIT_XOR);
    }

    private void callAtomicOperation(
        const Key           key,
        const Value         value,
        const MutationType  type) const
    {

        fdb_transaction_atomic_op(
            tr,
            &key[0],
            cast(int)key.length,
            &value[0],
            cast(int)value.length,
            type);
    }

    /* The transaction, if not self-conflicting, may be committed a second time
     * after commit succeeds, in the event of a fault
     * Parameter: Option takes no parameter
     */
    void setCausalWriteRisky() const
    {
        setTransactionOption(TransactionOption.CAUSAL_WRITE_RISKY);
    }

    /* The read version will be committed, and usually will be the latest
     * committed, but might not be the latest committed in the event of a fault
     * or partition
     * Parameter: Option takes no parameter
     */
    void setCausalReadRisky() const
    {
        setTransactionOption(TransactionOption.CAUSAL_READ_RISKY);
    }

    // Parameter: Option takes no parameter
    void setCausalReadDisable() const
    {
        setTransactionOption(TransactionOption.CAUSAL_READ_DISABLE);
    }

    /* The next write performed on this transaction will not generate a write
     * conflict range. As a result, other transactions which read the key(s)
     * being modified by the next write will not conflict with this transaction.
     * Care needs to be taken when using this option on a transaction that is
     * shared between multiple threads. When setting this option, write conflict
     * ranges will be disabled on the next write operation, regardless of what
     * thread it is on.
     * Parameter: Option takes no parameter
     */
    void setNextWriteNoWriteConflictRange() const
    {
        setTransactionOption(
            TransactionOption.NEXT_WRITE_NO_WRITE_CONFLICT_RANGE);
    }

    // Parameter: Option takes no parameter
    void setCheckWritesEnable() const
    {
        setTransactionOption(TransactionOption.CHECK_WRITES_ENABLE);
    }

    /* Reads performed by a transaction will not see any prior mutations that
     * occured in that transaction, instead seeing the value which was in the
     * database at the transaction's read version. This option may provide a
     * small performance benefit for the client, but also disables a number of
     * client-side optimizations which are beneficial for transactions which
     * tend to read and write the same keys within a single transaction.
     * Parameter: Option takes no parameter
     */
    void setReadYourWritesDisable() const
    {
        setTransactionOption(TransactionOption.READ_YOUR_WRITES_DISABLE);
    }

    /* Disables read-ahead caching for range reads. Under normal operation, a
     * transaction will read extra rows from the database into cache if range
     * reads are used to page through a series of data one row at a time (i.e.
     * if a range read with a one row limit is followed by another one row range
     * read starting immediately after the result of the first).
     * Parameter: Option takes no parameter
     */
    void setReadAheadDisable() const
    {
        setTransactionOption(TransactionOption.READ_AHEAD_DISABLE);
    }

    // Parameter: Option takes no parameter
    void setDurabilityDatacenter() const
    {
        setTransactionOption(TransactionOption.DURABILITY_DATACENTER);
    }

    // Parameter: Option takes no parameter
    void setDurabilityRisky() const
    {
        setTransactionOption(TransactionOption.DURABILITY_RISKY);
    }

    // Parameter: Option takes no parameter
    void setDurabilityDevNullIsWebScale() const
    {
        setTransactionOption(
            TransactionOption.DURABILITY_DEV_NULL_IS_WEB_SCALE);
    }

    /* Specifies that this transaction should be treated as highest priority and
     * that lower priority transactions should block behind this one. Use is
     * discouraged outside of low-level tools
     * Parameter: Option takes no parameter
     */
    void setPrioritySystemImmediate() const
    {
        setTransactionOption(TransactionOption.PRIORITY_SYSTEM_IMMEDIATE);
    }

    /* Specifies that this transaction should be treated as low priority and
     * that default priority transactions should be processed first. Useful for
     * doing batch work simultaneously with latency-sensitive work
     * Parameter: Option takes no parameter
     */
    void setPriorityBatch() const
    {
        setTransactionOption(TransactionOption.PRIORITY_BATCH);
    }

    /* This is a write-only transaction which sets the initial configuration
     * Parameter: Option takes no parameter
     */
    void setInitializeNewDatabase() const
    {
        setTransactionOption(TransactionOption.INITIALIZE_NEW_DATABASE);
    }

    /* Allows this transaction to read and modify system keys (those that start
     * with the byte 0xFF)
     * Parameter: Option takes no parameter
     */
    void setAccessSystemKeys() const
    {
        setTransactionOption(TransactionOption.ACCESS_SYSTEM_KEYS);
    }

    // Parameter: Option takes no parameter
    void setDebugDump() const
    {
        setTransactionOption(TransactionOption.DEBUG_DUMP);
    }

    /* Set a timeout in milliseconds which, when elapsed, will cause the
     * transaction automatically to be cancelled. Valid parameter values are
     * ``[0, INT_MAX]``. If set to 0, will disable all timeouts. All pending and
     * any future uses of the transaction will throw an exception. The
     * transaction can be used again after it is reset.
     * Parameter: (Int) value in milliseconds of timeout
     */
    void setTimeout(const long value) const
    {
        setTransactionOption(TransactionOption.TIMEOUT, value);
    }

    /* Set a maximum number of retries after which additional calls to onError
     * will throw the most recently seen error code. Valid parameter values are
     * ``[-1, INT_MAX]``. If set to -1, will disable the retry limit.
     * Parameter: (Int) number of times to retry
     */
    void setRetryLimit(const long value) const
    {
        setTransactionOption(TransactionOption.RETRY_LIMIT, value);
    }

    private void setTransactionOption(const TransactionOption op) const
    {
        enforceError(fdb_transaction_set_option(tr, op, null, 0));
    }

    private void setTransactionOption(
        const TransactionOption op,
        const long              value) const
    {
        auto err = fdb_transaction_set_option(
            tr,
            op,
            cast(immutable(char)*)&value,
            cast(int)value.sizeof);
        enforceError(err);
    }
}

private auto getEndPrefix(const Key prefix) pure
{
    ulong i = prefix.length;

    do --i;
    while (i != 0 && prefix[i] == 0xff);

    enforce(prefix[i] != 0xff, "All prefix bytes cannot equal 0xff");

    auto endPrefix = prefix[0 .. i + 1].dup;
    ++endPrefix[i];
    return endPrefix;
}
