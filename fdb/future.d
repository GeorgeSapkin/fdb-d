module fdb.future;

import std.algorithm,
       std.exception,
       std.parallelism;

import fdb.error,
       fdb.fdb_c;

private alias PKey      = ubyte *;
private alias PValue    = ubyte *;
alias Records           = Value[Key];

class Future(C, V) {
    private alias P = Future!(C, V);
    private alias T = Task!(worker, P);

    private shared FutureHandle future;
    private C                   callbackFunc;
    private T *                 futureTask;

    @disable this();
    this(FutureHandle future, C callbackFunc) {
        this.future       = future;
        this.callbackFunc = callbackFunc;
    }

    ~this() {
        destroy;
    }

    void destroy() {
        if (future) {
            // NB : Also releases the memory returned by get functions
            fdb_future_destroy(future);
            future = null;
        }
    }

    void start() {
        enforceError(fdb_future_set_callback(future, futureReady, this));
    }

    private static void futureReady(P thiz) {
        futureTask = task!worker(this);
        // or futureTask.executeInNewThread?
        taskPoll.put(futureTask);
    }

    private static void worker(P thiz) {
        scope (exit) delete thiz;

        fdb_error_t err;
        auto value = thiz.extractValue(thiz.future, err);
        thiz.callbackFunc(err, value);
    }

    abstract V extractValue(FutureHandle future, out fdb_error_t err = 0);
}

private mixin template FutureCtor(C) {
    this(FutureHandle future, C callbackFunc) {
        super(future, callbackFunc);
    }
}

class ValueFuture(C) : Future!(C, Value) {
    mixin FutureCtor!C;

    override Value extractValue(FutureHandle future, out fdb_error_t err) {
        PValue value;
        int    valueLength,
               valuePresent;

        err = fdb_future_get_value(future,
                                   &valuePresent,
                                   cast(PValue *) &value,
                                   &valueLength);
        if (err != FDBError.NONE || !valuePresent)
            return null;
        return value[0..valueLength];
    }
}

class KeyFuture(C) : Future!(C, Key) {
    mixin FutureCtor!C;

    override Value extractValue(FutureHandle future, out fdb_error_t err) {
        PKey key;
        int  keyLength;

        err = fdb_future_get_key(future, cast(PValue *) &key, &keyLength);
        if (err != FDBError.NONE)
            return typeof(return).init;
        return key[0..keyLength];
    }
}

class VoidFuture(C) : Future!(C, void) {
    mixin FutureCtor!C;

    override void extractValue(FutureHandle future, out fdb_error_t err) {
        err = fdb_future_get_error(future);
    }
}

alias KeyValueResult = Tuple!(Records, bool);
class KeyValueFuture(C) : Future!(C, KeyValueResult) {
    mixin FutureCtor!C;

    override KeyValueResult extractValue(
        FutureHandle future,
        out fdb_error_t err) {

        FDBKeyValue * kvs;
        int len;
        // Receives true if there are more result, or false if all results have
        // been transmited
        fdb_bool_t more;
        err = fdb_future_get_keyvalue_array(future, &kvs, &len, &more);
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

class VersionFuture(C) : Future!(C, ulong) {
    mixin FutureCtor!C;

    override ulong extractValue(FutureHandle future, out fdb_error_t err) {
        ulong ver;
        err = fdb_future_get_version(future, &ver);
        if (err != FDBError.NONE)
            return typeof(return).init;
        return ver;
    }
}

class StringFuture(C) : Future!(C, string[]) {
    mixin FutureCtor!C;

    override string[] extractValue(FutureHandle future, out fdb_error_t err) {
        ubyte ** stringArr;
        int      count;
        err = fdb_future_get_string_array(future, &stringArr, &count);
        if (err != FDBError.NONE)
            return typeof(return).init;
        auto strings = stringArr[0..count].map!(to!string).array;
        return strings;
    }
}

class WatchFuture(C) : VoidFuture!C {
    mixin FutureCtor!C;

    ~this() {
        cancel;
    }

    void cancel() {
        if (future)
            fdb_future_cancel(future);
    }
}