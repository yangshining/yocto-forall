# Fix GLIBCXX version compatibility issue
# cmake requires GLIBCXX_3.4.26 but Vitis toolchain's libstdc++ is too old
# Use LD_PRELOAD to force cmake to use system libstdc++ without affecting xsct

do_configure:prepend() {
    # Use LD_PRELOAD to preload system libstdc++ for all child processes
    # This only affects programs that need libstdc++, not the entire environment
    if [ -f /usr/lib/x86_64-linux-gnu/libstdc++.so.6 ]; then
        # Save original LD_PRELOAD if it exists
        ORIG_LD_PRELOAD="${LD_PRELOAD}"
        if [ -n "${ORIG_LD_PRELOAD}" ]; then
            export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libstdc++.so.6:${ORIG_LD_PRELOAD}"
        else
            export LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libstdc++.so.6"
        fi
    fi
}
