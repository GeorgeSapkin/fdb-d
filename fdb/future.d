module fdb.future;

import std.algorithm,
       std.exception,
       std.parallelism,
       std.traits;

import fdb.error,
       fdb.fdb_c;

private alias PKey      = ubyte *;
private alias PValue    = ubyte *;
alias Records           = Value[Key];

shared class Future(C, V) {
    private alias SF = shared(Future!(C, V));
    private alias SH = shared(FutureHandle);
    private alias SE = shared(fdb_error_t);
    private alias T  = Task!(worker, SF);

    private FutureHandle future;
    private C            callbackFunc;

    this(FutureHandle future, C callbackFunc) {
        this.future       = cast(shared)future;
        this.callbackFunc = callbackFunc;
    }

    ~this() {
        destroy;
    }

    void destroy() {
        if (future) {
            // NB : Also releases the memory returned by get functions
            fdb_future_destroy(cast(FutureHandle)future);
            future = null;
        }
    }

    void start() {
        auto err = fdb_future_set_callback(
            cast(FutureHandle) future,
            cast(FDBCallback)  &futureReady,
            cast(void*)        &this);
        enforceError(err);
    }

    static void futureReady(FutureHandle f, SF thiz) {
        auto futureTask = task!worker(thiz);
        // or futureTask.executeInNewThread?
        taskPool.put(futureTask);
    }

    static void worker(SF thiz) {
        scope (exit) delete thiz;

        shared fdb_error_t err;
        with (thiz) {
            static if (is(ReturnType!extractValue == void)) {
                extractValue(future, err);
                callbackFunc(err);
            }
            else {
                auto value = extractValue(future, err);
                callbackFunc(err, value);
            }
        }
    }

    abstract V extractValue(SH future, out SE err);
}

private mixin template FutureCtor(C) {
    this(FutureHandle future, C callbackFunc) {
        super(future, callbackFunc);
    }
}

shared class ValueFuture(C) : Future!(C, Value) {
    mixin FutureCtor!C;

    override Value extractValue(SH future, out SE err) {
        PValue value;
        int    valueLength,
               valuePresent;

        err = fdb_future_get_value(
            cast(FutureHandle)future,
            &valuePresent,
            &value,
            &valueLength);
        if (err != FDBError.NONE || !valuePresent)
            return null;
        return value[0..valueLength];
    }
}

shared class KeyFuture(C) : Future!(C, Key) {
    mixin FutureCtor!C;

    override Value extractValue(SH future, out SE err) {
        PKey key;
        int  keyLength;

        err = fdb_future_get_key(
            cast(FutureHandle)future,
            &key,
            &keyLength);
        if (err != FDBError.NONE)
            return typeof(return).init;
        return key[0..keyLength];
    }
}

shared class VoidFuture(C) : Future!(C, void) {
    mixin FutureCtor!C;

    override void extractValue(SH future, out SE err) {
        err = fdb_future_get_error(
            cast(FutureHandle)future);
    }
}

alias KeyValueResult = Tuple!(Records, bool);
shared class KeyValueFuture(C) : Future!(C, KeyValueResult) {
    mixin FutureCtor!C;

    override KeyValueResult extractValue(SH future, out SE err) {

        FDBKeyValue * kvs;
        int len;
        // Receives true if there are more result, or false if all results have
        // been transmited
        fdb_bool_t more;
        err = fdb_future_get_keyvalue_array(
            cast(FutureHandle)future,
            &kvs,
            &len,
            &more);
        if (err != FDBError.NONE)
            return typeof(return).init;

        auto tuples = reduce!
            ((a, kv) => {
                a[kv.key[0..kv.key_length]] = kv.value[0..kv.value_length];
                return a;
            })
            (new Records, kvs[0..len]);
        return Tuple!(tuples, cast(bool)more);
    }
}

shared class VersionFuture(C) : Future!(C, ulong) {
    mixin FutureCtor!C;

    override ulong extractValue(SH future, out SE err) {
        long ver;
        err = fdb_future_get_version(
            cast(FutureHandle)future,
            &ver);
        if (err != FDBError.NONE)
            return typeof(return).init;
        return ver;
    }
}

shared class StringFuture(C) : Future!(C, string[]) {
    mixin FutureCtor!C;

    override string[] extractValue(SH future, out SE err) {
        ubyte ** stringArr;
        int      count;
        err = fdb_future_get_string_array(
            cast(FutureHandle)future,
            &stringArr,
            &count);
        if (err != FDBError.NONE)
            return typeof(return).init;
        auto strings = stringArr[0..count].map!(to!string).array;
        return strings;
    }
}

shared class WatchFuture(C) : VoidFuture!C {
    mixin FutureCtor!C;

    ~this() {
        cancel;
    }

    void cancel() {
        if (future)
            fdb_future_cancel(future);
    }
}