module fdb.networkoptions;

import
    std.conv,
    std.exception,
    std.string;

import
    fdb.error,
    fdb.fdb_c,
    fdb.fdb_c_options;

class NetworkOptions
{
    static void init()
    {
        setNetworkOption(NetworkOption.NONE);
    }

    /**
     * Enables trace output to a file in a directory of the clients choosing
     * Params:
     *      value = path to output directory (or NULL for current working
     *              directory)
     */
    static void setTraceEnable(in string value)
    {
        setNetworkOption(NetworkOption.TRACE_ENABLE, value);
    }

    /**
     * Sets the maximum size in bytes of a single trace output file.
     * This value should be in the range ``[0, long.max]``.
     * If the value is set to 0, there is no limit on individual file size.
     * The default is a maximum size of 10,485,760 bytes.
     * Params:
     *      value = max size of a single trace output file
     */
    static void setTraceRollSize(in long value)
    {
        setNetworkOption(NetworkOption.TRACE_ROLL_SIZE, value);
    }

    /**
     * Sets the maximum size of a all the trace output files put together.
     * This value should be in the range ``[0, long.max]``.
     * If the value is set to 0, there is no limit on the total size of the
     * files.
     * The default is a maximum size of 104,857,600 bytes.
     * If the default roll size is used, this means that a maximum of 10 trace
     * files will be written at a time.
     * Params:
     *      value = max total size of trace files
     */
    static void setTraceMaxLogSize(in long value)
    {
        setNetworkOption(NetworkOption.TRACE_MAX_LOG_SIZE, value);
    }

    /**
     * Set internal tuning or debugging knobs
     * Params:
     *      value = knob_name=knob_value
     */
    static void setKnob(in string value)
    {
        setNetworkOption(NetworkOption.KNOB, value);
    }

    /**
     * Set the TLS plugin to load. This option, if used, must be set before any
     * other TLS options
     * Params:
     *      value = file path or linker-resolved name
     */
    static void setTlsPlugin(in string value)
    {
        setNetworkOption(NetworkOption.TLS_PLUGIN, value);
    }

    /**
     * Set the certificate chain
     * Params:
     *      value = certificates
     */
    static void setTlsCertBytes(in ubyte[] value)
    {
        setNetworkOption(NetworkOption.TLS_CERT_BYTES, value);
    }

    /**
     * Set the file from which to load the certificate chain
     * Params:
     *      value = file path
     */
    static void setTlsCertPath(in string value)
    {
        setNetworkOption(NetworkOption.TLS_CERT_PATH, value);
    }

    /**
     * Set the private key corresponding to your own certificate
     * Params:
     *      value = key
     */
    static void setTlsKeyBytes(in ubyte[] value)
    {
        setNetworkOption(NetworkOption.TLS_KEY_BYTES, value);
    }

    /**
     * Set the file from which to load the private key corresponding to your
     * own certificate
     * Params:
     *      value = file path
     */
    static void setTlsKeyPath(in string value)
    {
        setNetworkOption(NetworkOption.TLS_KEY_PATH, value);
    }

    /**
     * Set the peer certificate field verification criteria
     * Params:
     *      value = verification pattern
     */
    static void setTlsVerifyPeers(in ubyte[] value) {
        setNetworkOption(NetworkOption.TLS_VERIFY_PEERS, value);
    }

    private static void setNetworkOption(in NetworkOption op)
    {
        enforceError(fdb_network_set_option(op, null, 0));
    }

    private static void setNetworkOption(in NetworkOption op, in ubyte[] value)
    {
        const auto err = fdb_network_set_option(
            op,
            cast(immutable(char)*)value,
            cast(int)value.length);
        enforceError(err);
    }

    private static void setNetworkOption(in NetworkOption op, in long value)
    {
        const auto err = fdb_network_set_option(
            op,
            cast(immutable(char)*)&value,
            cast(int)value.sizeof);
        enforceError(err);
    }

    private static void setNetworkOption(in NetworkOption op, in string value)
    {
        const auto err = fdb_network_set_option(
            op,
            value.toStringz,
            cast(int)value.length);
        enforceError(err);
    }
};
