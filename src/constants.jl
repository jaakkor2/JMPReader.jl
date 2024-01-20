# 8 first bytes of a .jmp file
const MAGIC_JMP = [0xff, 0xff, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00]

# Gzip headers, 
# length of the header is 10, last is operating system ID, omitted here
const MAGIC_GZIP = [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

# JMP uses 1904 date system
const JMP_STARTDATE = DateTime(1904, 1, 1)

# offset for number of rows
const offset_nrows = 368
