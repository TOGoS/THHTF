# TOGoS's Homogenous Hash Table Format

Size of each entry and number of entries must be provided out of band, e.g. in the filename.

Therefore a standard filename format is needed.

Standard filename format: ```<whatever>.<key size>-<payload size>-<table size>.thht```

e.g. ```stored-blobs.20-0-1024.thht```

Primary use cases:

- Record a set of blobs by SHA-1: 20-0-1024.
- Record offsets/sizes of blobs in another file: 20-8-1024

Insertion is done by somehow hashing the key to an integer < $tablesize
and seeing if the value currently stored there has a key of all
zeroes, indicating 'nothing yet stored here'.  $tablesize will
be added to the index until a free space is found, at which point
the key and value (concatenated together) will be stored there.

Since the primary use case is using SHA-1 hashes as keys, the hash function
of these hashes may be trivial, such as using the upper several bits.
