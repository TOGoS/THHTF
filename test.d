#!/usr/bin/env rdmd

import std.algorithm : min;
import std.string : format;
import std.conv : octal;
import std.stdio : SEEK_END;

import core.sys.posix.sys.stat : fstat, stat_t;
import core.sys.posix.sys.mman : mmap, PROT_READ, MAP_SHARED, MAP_FAILED;
import core.sys.posix.sys.types : off_t;
import core.sys.posix.fcntl : fcntl_open = open, O_CREAT;
import core.sys.posix.unistd : write, lseek;

struct Entry {
    byte[] key;
    byte[] value;
}

class RandomAccessFile {
    int fd;
    off_t fileSize;
    void *begin;
    void *end;
    
    this(int fd, void *begin, void *end) {
        this.fd = fd;
        this.begin = begin;
        this.end = end;
        stat_t theStat;
        if( fstat(fd, &theStat) ) {
            throw new Exception("Failed to fstat.  <TODO: put error message here>");
        }
        this.fileSize = theStat.st_size;
    }
    
    @property off_t size() { return fileSize; }
    
    static RandomAccessFile open(string filename, int openFlags, int openMode, int prot, int flags) {
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
        return new RandomAccessFile(fd, begin, end);
    }
    
    static RandomAccessFile open(string filename, bool writable) {
        // TODO: See if these flags are right
        return open(filename, writable?O_CREAT:0, octal!644, PROT_READ, MAP_SHARED);
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
        const int bufSize = 1024;
        byte[bufSize] zeroes;
        lseek(fd, 0, SEEK_END);
        while( fileSize < targetSize ) {
            off_t expandBy = min(bufSize, targetSize - fileSize);
            write(fd, cast(void *)zeroes, cast(uint)expandBy);
            fileSize += expandBy;
        }
    }
    
    void put(off_t offset, byte[] data) {
        expandFile( offset + data.length );
        write(0, format("Expanded to %d\n", fileSize));
        // TODO: Crash if can't be casted
        int off = cast(int)offset;
        begin[off..off+data.length] = data;
    }
}

class THHTFFile : RandomAccessFile {
    this(int fd, void *begin, void *end) {
        super(fd, begin, end);
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
    RandomAccessFile raf = RandomAccessFile.open("blah.dat", false);
    write(0, format("File size: %d\n", raf.size));
    raf.put(raf.size, cast(byte[])"WHAT");
    byte[] data = raf.get(raf.size-4, 4);
    write(0, format("Got some data! %s\n", cast(string)data));
}
