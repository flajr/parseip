# parseip

Simple IPv4 parser written in Nim with gzip files handling and build compatibility for musl

## `parseip -h`

```
    Parse IPv4 address occurances

    + support for reading *.gz files
    + PATTERN support regex syntax
    + Regex for IPv4 is fast and simple: \b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b
      WARNING: This Regex can obviously parse some non IPv4 addresses
    + Reading STDIN if "-" (dash) specified

    USAGE:
      parseip [options] [--] [<FILE>]...
      parseip [options] [-]

    OPTIONS:
      -c --clean            Cleaner output, do not print address counts
                            + Output is sorted
                            + Honor --limit settings
      -e --exclude=PATTERN  Exclude IP if line contains PATTERN 
                            + usable with -p, exclude has priority
      -h --help             Show this help
      -i --ignorecase       Ignore case for -p and -e options
      -l --limit=NUM        Limit output number of addresses [default: 25]
                            + For no limit set to 0
      -r --remove=NUM       Uniq IPs after removing NUM of octets from IP
                            + NUM can be number in range: 1-3
      -p --parse=PATTERN    Parse IP only if line contains PATTERN
                            + usable with -e, exclude has priority
      -n --nosort           Do not sort output (performance gain is almost zero)
                            + Sorting is by occurances of IPs
      -s --seek=BYTES       Skip BYTES when reading input
                            + [K,M,G] standard unit suffixes can be used
                            + Unit base is 1024
      -V --version          Version of program
      -v --verbose          Show what is going on

    EXAMPLES:
      cat FILE |parseip -
      parseip --clean /var/log/syslog
      parseip --limit 10 FILE.gz
      parseip --parse "123.123.123.1|123.123.123.2" FILE
      parseip --ignorecase --parse "sasl" --exclude "127.0.0.1|127.0.0.2" /var/log/maillog
      parseip --parse "127.0.0.[0-9]+" FILE
      parseip --seek 20M /var/log/messages
      parseip --clean --remove 1 FILE
```

### Build

Use `just` as modern alternative to `make`: https://github.com/casey/just or manually run commands in `Justfile`

```
just pcre
just zlib
just build
```