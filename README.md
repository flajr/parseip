# parseip

Simple IPv4 parser written in Nim with gzip files handling and build compatibility for musl

## Help `parseip -h`

```
    parseip [OPTIONS] [FILE[ FILE]]

    + support for reading *.gz files
    + PATTERN support regex syntax
    + Regex for IPv4 is fast and simple: \b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b
      WARNING: This Regex can obviously parse some non IPv4 addresses
    + Reading STDIN if no file is present

    SYNTAX for OPTIONS:
      -o:ARG        # OK
      -o=ARG        # OK
      -oARG         # OK
      -o ARG        # ERROR
      --option:ARG  # OK
      --option=ARG  # OK
      --optionARG   # ERROR
      --option ARG  # OK

    OPTIONS:
      -c|--clean              Cleaner output, do not print address counts
                              + Output is sorted
                              + Honor --limit settings
      -e|--exclude=PATTERN    Exclude IP if line contains PATTERN 
                              + usable with -p, exclude has priority
      -h|--help               Show this help
      -i|--ignorecase         Ignore case for -p and -e options
      -l|--limit=NUM          Limit output number of addresses
                              + Default: 25
                              + For no limit set to 0
      -p|--parse=PATTERN      Parse IP only if line contains PATTERN
                              + usable with -e, exclude has priority
      -n|--nosort             Do not sort output (performance gain is almost zero)
                              + Sorting is by occurances of IPs
      -s|--seek=BYTES[K,M,G]  Skip BYTES when reading input
                              + No suffix means standard bytes
                              + [K,M,G] are standard unit suffixes of Byte
                              + Base is 1024 (NOT 1000)
      --version               Version of program
      -v|--verbose            Show what is going on
```

### Examples

```
parseip -c FILE
parseip -l=10 FILE.gz
cat FILE |parseip
parseip --parse "123.123.123.1|123.123.123.2" FILE
parseip -p"sasl" -e"127.0.0.1|123.123.123|123.123.124" FILE
parseip -p="127.0.0.[0-9]+" FILE
parseip -s20M /var/log/messages
```

### Build

Use `just` as modern alternative to `make`: https://github.com/casey/just or manually run commands in `Justfile`

```
just pcre
just zlib
just build
```