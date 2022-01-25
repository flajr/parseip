import os
import std/[parseutils, re, tables, strutils]
import zip/gzipfiles
import docopt

proc perr(s: string, i: int) =
  writeLine(stderr, "ERROR: " & s)
  flushFile(stderr)
  quit i

proc pinf(s: string, verbose: bool) =
  if verbose:
    writeLine(stderr, "INFO: " & s)
    flushFile(stderr)

proc pwrn(s: string, verbose: bool) =
  if verbose:
    writeLine(stderr, "WARNING: " & s)
    flushFile(stderr)

let doc = """
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
    """.dedent()

let args = docopt(doc, version = "2.0.0", optionsFirst = true)

var
  stdinBool   = true
  counter     = 0
  ipLimit:      int
  unlimitedBool = false
  verboseBool = false
  cleanBool   = false
  ipCount     = initCountTable[string]()
  matches:      seq[string]
  parseRe:      Regex
  parseBool   = false
  excludeRe:    Regex
  excludeBool = false
  ignoreCase  = false
  seekBool    = false
  seekValue:    int
  gzBool      = false
  octetValue:   int
  octetBool   = false

let
  # ipRegexAccurate = re"(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
  ipRegexSimple = re(r"[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}", {reStudy})

if args["--verbose"]: 
  verboseBool = true
  pinf("Verbose output", verboseBool)
if args["--clean"]:
  pinf("Clean output, do not print address counts", verboseBool)
  cleanBool = true
if args["--ignorecase"]:
  pinf("Setting case insensivity", verboseBool)
  ignoreCase = true
if args["--limit"]:
  if parseInt($args["--limit"], ipLimit, 0) == 0:
    perr("Bad limit, must be number", 3)
  else:
    if ipLimit < 0:
      perr("Lowest number for limit is 0", 2)
    elif ipLimit == 0:
      unlimitedBool = true
    pinf("Setting output limit: " & intToStr(ipLimit), verboseBool)
if args["--remove"]:
  if parseInt($args["--remove"], octetValue, 0) == 0:
    perr("Bad seek value: Must be number", 3)
  if octetValue >= 1 and octetValue <= 3:
    octetBool = true
    pinf("Remove octets from IP: " & intToStr(octetValue), verboseBool)
  else:
    perr("Bad octet value: Not in range 1-3", 3)
if args["--seek"]:
  var seekType: int
  let valueTmp: string = $args["--seek"]
  if parseInt(valueTmp, seekValue, 0) == 0:
    perr("Bad seek value: Must be number", 3)

  if seekValue <= 0:
    perr("Bad seek value: Must be higher than 0", 3)

  if   valueTmp.endsWith("K"): seekType = 1024
  elif valueTmp.endsWith("M"): seekType = 1024 * 1024
  elif valueTmp.endsWith("G"): seekType = 1024 * 1024 * 1024
  else:                        seekType = 1

  seekValue = seekValue * seekType
  pinf("Skip " & intToStr(seekValue) & " bytes for input stream", verboseBool)
  seekBool = true

if args["-"]:
  stdinBool = true
elif not args["<FILE>"]:
  perr("Missing input <FILE> or dash '-' to read STDIN", 3)

if args["--parse"]:
  parseBool = true
  pinf("Parse only lines containing: " & $args["--parse"], verboseBool)
  if ignoreCase:
    parseRe = re($args["--parse"], {reStudy, reIgnoreCase})
  else:
    parseRe = re($args["--parse"], {reStudy})

if args["--exclude"]:
  excludeBool = true
  pinf("Exclude lines containing: " & $args["--exclude"], verboseBool)
  if ignoreCase:
    excludeRe = re($args["--exclude"], {reStudy, reIgnoreCase})
  else:
    excludeRe = re($args["--exclude"], {reStudy})

for file in @(args["<FILE>"]):
  if not stdinBool and not fileExists(file):
    pwrn("File is missing or not readable: " & file, verboseBool)
    continue
  let fileIter: Stream = 
    if file.endsWith(".gz"):
      pinf("Found .gz extension", verboseBool)
      gzBool = true
      newGzFileStream(file)
    elif stdinBool and file == "-":
      pinf("Reading stdin...", verboseBool)
      newFileStream(stdin)
    else:
      newFileStream(file)

  if seekBool:
    setPosition(fileIter, seekValue)

  for line in fileIter.lines:
    if excludeBool and contains(line, excludeRe, 0): continue
    if parseBool and not contains(line, parseRe, 0): continue
    matches = findAll(line, ipRegexSimple, 0)
    for match in matches:
      if octetBool:
        case octetValue
        of 1:
          ipCount.inc(match.rsplit({'.'}, maxsplit = 1)[0] & ".0")
        of 2:
          ipCount.inc(match.rsplit({'.'}, maxsplit = 2)[0] & ".0.0")
        of 3:
          ipCount.inc(match.rsplit({'.'}, maxsplit = 3)[0] & ".0.0.0")
        else:
          perr("Unexpected octetValue", 5)
      else:
        ipCount.inc(match)

if args["--nosort"]:
  pinf("Sorting by occurances disabled", verboseBool)
else:
  ipCount.sort()

if cleanBool:
  for k in keys(ipCount):
    # check counter against ipLimit and honor unlimited if ipLimit=0
    if counter == ipLimit:
      if not unlimitedBool: break
    echo k  
    inc counter
else:
  for k, v in pairs(ipCount):
    # check counter against ipLimit and honor unlimited if ipLimit=0
    if counter == ipLimit:
      if not unlimitedBool: break
    echo v, "\t", k
    inc counter
