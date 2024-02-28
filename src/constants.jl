# 8 first bytes of a .jmp file
const MAGIC_JMP = [0xff, 0xff, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00]

# Gzip section starts with this byte sequence
const GZIP_SECTION_START = [0xef, 0xbe, 0xfe, 0xca] # cafebeef

# JMP uses 1904 date system
const JMP_STARTDATE = DateTime(1904, 1, 1)

# offset for number of rows
const OFFSET_NROWS = 368
