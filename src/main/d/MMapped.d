import core.sys.posix.sys.types : off_t;

string errstr() {
    return to!string(strerror(errno));
}

class MMapped {
    int fd;
    off_t fileSize;
    void *begin;
    void *end;
    bool writable;
    
    this(int fd, void *begin, void *end, bool writable) {
        this.fd = fd;
        this.begin = begin;
        this.end = end;
        this.writable = writable;
        stat_t theStat;
        if( fstat(fd, &theStat) ) {
            throw new Exception("Failed to fstat.  <TODO: put error message here>");
        }
        this.fileSize = theStat.st_size;
    }
    
    @property off_t size() { return fileSize; }
    
    static MMapped open(string filename, int openFlags, int openMode, int prot, int flags) {
        int fd = fcntl_open(cast(const char*)filename, openFlags, openMode);
        void *begin = MAP_FAILED;
        size_t length = 1<<31;

      attemptMmap:
        begin = mmap(null, length, prot, flags, fd, 0);
        if( begin == MAP_FAILED && length >= 0x200000 ) {
            length >>= 1;
            goto attemptMmap;
        }
        
        if( begin == MAP_FAILED ) throw new Exception(format("Failed to mmap '%s' from 0 to 0x%x", filename, length));
        void *end = begin + length;
        return new MMapped(fd, begin, end, (openFlags&(O_RDWR|O_WRONLY)) != 0);
    }
    
    static MMapped open(string filename, bool writable) {
        // TODO: See if these flags are right
        return open(filename, writable?(O_CREAT|O_RDWR):O_RDONLY, octal!644, PROT_READ|(writable?PROT_WRITE:0), MAP_SHARED);
    }
    
    void *at(long offset) {
        if( begin + offset > end ) {
            return null;
        } else {
            return begin + offset;
        }
    }
    
    byte[] get(off_t offset, size_t size) {
        byte[] result = new byte[size];
        byte *ptr = cast(byte *)at(offset);
        if( ptr == null ) {
            throw new Exception(format("Failed to turn offset 0x%x into a memory location; begin=0x%x, end=0x%x", offset, begin, end));
        }
        result[0..size] = (cast(byte *)at(offset))[0..size];
        return result;
    }
    
    void expandFile( off_t targetSize ) {
        if( fileSize >= targetSize ) return;
            
        if( ftruncate(fd, targetSize) ) {
            throw new Exception(format("ftruncate to %d failed: %s", targetSize, errstr()));
        }
        fileSize = targetSize;
    }
    
    void put(off_t offset, byte[] data) {
        if( !writable ) throw new Exception("Not opened writably.");
        expandFile( offset + data.length );
        // TODO: Crash if can't be casted
        int off = cast(int)offset;
        begin[off..off+data.length] = data;
    }
}

unittest {
    import std.algorithm : fill;
    import std.ascii : letters;
    import std.random : randomCover, rndGen;
    
    string randomString(int length) {
        dchar[] str = new dchar[length];
        fill(str, randomCover(to!(dchar[])(letters), rndGen));
        return to!(string)(str);
    }

    string filename = "." ~ randomString(10) ~ ".temp";
    MMapped raf = MMapped.open(filename, true);
    string randomData = randomString(10);
    raf.put( 20, cast(byte[])randomData );
    assert(raf.size == 30);
    assert(raf.get(0, 20) == new byte[20]);
    assert(raf.get(20, 10) == cast(byte[])randomData);
}
