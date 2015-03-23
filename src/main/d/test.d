#!/usr/bin/env rdmd

import std.conv : to;
import std.string : format;
import core.sys.posix.unistd : write;
import togos.file.mmapped : MMapped;

struct Entry {
    byte[] key;
    byte[] value;
}

class THHTFFile : MMapped {
    this(int fd, void *begin, void *end, bool writable) {
        super(fd, begin, end, writable);
    }
    /*
    static THHTFFile open( string filename, bool writeable ) {
    }
    
    Entry find( byte[] key ) {
    }
    */
}

void write( int fh, string s ) {
    write(fh, cast(byte *)s, s.length);
}

void main() {
    Entry e = Entry( cast(byte[])"abc", cast(byte[])"def" );
    MMapped raf = MMapped.open("blah.dat", true);
    write(0, format("File size: %d\n", raf.size));
    raf.put(raf.size, cast(byte[])"WHAT");
    byte[] data = raf.get(raf.size-4, 4);
    write(0, format("Got some data! %s\n", cast(string)data));
}
