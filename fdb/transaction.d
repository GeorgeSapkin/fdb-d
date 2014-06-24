module fdb.transaction;

import std.conv,
       std.exception;

import fdb.fdb_c,
       fdb.fdb_c_options,
       fdb.future;

struct RangeEndpoint {
    ubyte[] value;
    bool    orEqual;
    int     offset;
}

class Transaction {
    private FDBTransaction * tr;

    private static auto start(F, C)(C callback) pure {
        auto _future = new F(f, callback);
        _future.start();
        return _future;
    }

    this(FDBTransaction * ptr) { this.tr = ptr; }

    ~this() { destroy; }

    void destroy() { fdb_transaction_destroy(tr); }

    void set(ubyte[] key, ubyte[] value) {
        fdb_transaction_set(
            tr,
            &key[0],
            cast(int)key.length,
            &value[0],
            cast(int)value.length);
    }

    void commit(C)(C callback) {
        FDBFuture * f = fdb_transaction_commit(tr);
        return start!VoidFuture(f, callback);
    }

    void clear(ubyte[] key) {
        fdb_transaction_clear(tr, &key[0], cast(int)key.length);
    }

    void clearRange(ubyte[] begin, ubyte[] end) {
        fdb_transaction_clear_range(
            tr,
            &begin[0],
            cast(int)begin.length,
            &end[0],
            cast(int)end.length);
    }

    auto getKey(C)(
        ubyte[] key,
        int     selectorOrEqual,
        int     selectorOffset,
        bool    snapshot,
        C       callback) {

        FDBFuture * f = fdb_transaction_get_key(
            tr,
            &key[0],
            key.length,
            cast(fdb_bool_t)selectorOrEqual,
            selectorOffset,
            snapshot);

        return start!KeyFuture(f, callback);
    }

    voud get(C)(ubyte[] key, bool snapshot, C callback) {
        FDBFuture * f = fdb_transaction_get(
            tr,
            &key[0],
            key.length,
            snapshot);
        return start!ValueFuture(f, callback);
    }

    void getRange(C)(
        RangeEndpoint start,
        RangeEndpoint end,
        int           limit,
        StreamingMode mode,
        int           iteration,
        bool          snapshot,
        bool          reverse,
        C             callback) {

        FDBFuture * f = fdb_transaction_get_range(
            tr,

            &start.value[0],
            start.value.length,
            cast(fdb_bool_t)start.orEqual,
            start.offset,

            &end.value[0],
            end.value.length,
            cast(fdb_bool_t)end.orEqual,
            end.offset,

            limit,
            0,
            mode,
            iteration,
            snapshot,
            reverse);

        return start!KeyValueFuture(f, callback);
    }

    auto watch(C)(ubyte[] key, C callback) {
        FDBFuture * f = fdb_transaction_watch(tr, &key[0], key.length);
        return start!WatchFuture(callback);
    }

    private void addConflictRange(
        ubyte[]           start,
        ubyte[]           end,
        ConflictRangeType type) {

        auto err = fdb_transaction_add_conflict_range(
            tr,
            &start[0],
            cast(int)start.length,
            &end[0],
            cast(int)end.length,
            type);
        enforce(!err, fdb_get_error(err).to!string);
    }

    void addReadConflictRange(ubyte[] start, ubyte[] end) {
        addConflictRange(start, end, ConflictRangeType.READ);
    }

    void addWriteConflictRange(ubyte[] start, ubyte[] end) {
        addConflictRange(start, end, ConflictRangeType.WRITE);
    }

    void onError(C)(auto err, C callback) {
        FDBFuture * f = fdb_transaction_on_error(tr, err);
        return start!VoidFuture(f, callback);
    }

    void reset() { fdb_transaction_reset(tr); }

    void setReadVersion(int ver) { fdb_transaction_set_read_version(tr, ver); }

    void getReadVersion(C)(C callback) {
        FDBFuture * f = fdb_transaction_get_read_version(tr);
        return start!VersionFuture(f, callback);
    }

    auto getCommittedVersion() {
        long ver;
        auto err = fdb_transaction_get_committed_version(tr, &ver);
        enforce(!err, fdb_get_error(err).to!string);
        return ver;
    }

    void cancel() { fdb_transaction_cancel(tr); }

    void getAddressesForKey(C)(ubyte[] key, C callback) {
        FDBFuture * f = fdb_transaction_get_addresses_for_key(
            tr,
            &key[0],
            key.length);
        return start!StringFuture(f, callback);
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
    void add(ubyte[] key, ubyte[] value) {
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
    void bitAnd(ubyte[] key, ubyte[] value) {
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
    void bitOr(ubyte[] key, ubyte[] value) {
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
    void bitXor(ubyte[] key, ubyte[] value) {
        callAtomicOperation(key, value, MutationType.BIT_XOR);
    }

    private void callAtomicOperation(
        ubyte[]      key,
        ubyte[]      value,
        MutationType type) {

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
    void setCausalWriteRisky() {
        setTransactionOption(TransactionOption.CAUSAL_WRITE_RISKY);
    }

    /* The read version will be committed, and usually will be the latest
     * committed, but might not be the latest committed in the event of a fault
     * or partition
     * Parameter: Option takes no parameter
     */
    void setCausalReadRisky() {
        setTransactionOption(TransactionOption.CAUSAL_READ_RISKY);
    }

    // Parameter: Option takes no parameter
    void setCausalReadDisable() {
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
    void setNextWriteNoWriteConflictRange() {
        setTransactionOption(
            TransactionOption.NEXT_WRITE_NO_WRITE_CONFLICT_RANGE);
    }

    // Parameter: Option takes no parameter
    void setCheckWritesEnable() {
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
    void setReadYourWritesDisable() {
        setTransactionOption(TransactionOption.READ_YOUR_WRITES_DISABLE);
    }

    /* Disables read-ahead caching for range reads. Under normal operation, a
     * transaction will read extra rows from the database into cache if range
     * reads are used to page through a series of data one row at a time (i.e.
     * if a range read with a one row limit is followed by another one row range
     * read starting immediately after the result of the first).
     * Parameter: Option takes no parameter
     */
    void setReadAheadDisable() {
        setTransactionOption(TransactionOption.READ_AHEAD_DISABLE);
    }

    // Parameter: Option takes no parameter
    void setDurabilityDatacenter() {
        setTransactionOption(TransactionOption.DURABILITY_DATACENTER);
    }

    // Parameter: Option takes no parameter
    void setDurabilityRisky() {
        setTransactionOption(TransactionOption.DURABILITY_RISKY);
    }

    // Parameter: Option takes no parameter
    void setDurabilityDevNullIsWebScale() {
        setTransactionOption(
            TransactionOption.DURABILITY_DEV_NULL_IS_WEB_SCALE);
    }

    /* Specifies that this transaction should be treated as highest priority and
     * that lower priority transactions should block behind this one. Use is
     * discouraged outside of low-level tools
     * Parameter: Option takes no parameter
     */
    void setPrioritySystemImmediate() {
        setTransactionOption(TransactionOption.PRIORITY_SYSTEM_IMMEDIATE);
    }

    /* Specifies that this transaction should be treated as low priority and
     * that default priority transactions should be processed first. Useful for
     * doing batch work simultaneously with latency-sensitive work
     * Parameter: Option takes no parameter
     */
    void setPriorityBatch() {
        setTransactionOption(TransactionOption.PRIORITY_BATCH);
    }

    /* This is a write-only transaction which sets the initial configuration
     * Parameter: Option takes no parameter
     */
    void setInitializeNewDatabase() {
        setTransactionOption(TransactionOption.INITIALIZE_NEW_DATABASE);
    }

    /* Allows this transaction to read and modify system keys (those that start
     * with the byte 0xFF)
     * Parameter: Option takes no parameter
     */
    void setAccessSystemKeys() {
        setTransactionOption(TransactionOption.ACCESS_SYSTEM_KEYS);
    }

    // Parameter: Option takes no parameter
    void setDebugDump() {
        setTransactionOption(TransactionOption.DEBUG_DUMP);
    }

    /* Set a timeout in milliseconds which, when elapsed, will cause the
     * transaction automatically to be cancelled. Valid parameter values are
     * ``[0, INT_MAX]``. If set to 0, will disable all timeouts. All pending and
     * any future uses of the transaction will throw an exception. The
     * transaction can be used again after it is reset.
     * Parameter: (Int) value in milliseconds of timeout
     */
    void setTimeout(int value) {
        setTransactionOption(TransactionOption.TIMEOUT, value);
    }

    /* Set a maximum number of retries after which additional calls to onError
     * will throw the most recently seen error code. Valid parameter values are
     * ``[-1, INT_MAX]``. If set to -1, will disable the retry limit.
     * Parameter: (Int) number of times to retry
     */
    void setRetryLimit(int value) {
        setTransactionOption(TransactionOption.RETRY_LIMIT, value);
    }

    private void setTransactionOption(TransactionOption op, int value = 0) {
        auto err = fdb_transaction_set_option(
            tr,
            op,
            cast(immutable(char)*)&value,
            cast(int)int.sizeof);
        enforce(!err, fdb_get_error(err).to!string);
    }
}