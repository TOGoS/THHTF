module togos.debugutil;

import std.string : format;
import core.sys.posix.unistd : write;

void logDebug(string str) {
    byte[] b = cast(byte[])(str ~ "\n");
    write(1, cast(byte*)b, b.length);
}
