# 4 first bytes of a .jmp file
const MAGIC_JMP = [0xff, 0xff, 0x00, 0x00]

# Gzip section starts with this byte sequence
const GZIP_SECTION_START = [0xef, 0xbe, 0xfe, 0xca] # cafebeef

# JMP uses 1904 date system
const JMP_STARTDATE = DateTime(1904, 1, 1)

# column formats
# 0x6c=":day:hr:m" and 0x6d=":day:hr:m:s" could be time or duration, here they are duration
const DATE_FORMATS = (0x65, 0x66, 0x67, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x75, 0x76, 0x7a, 0x7f, 0x88, 0x8b)
const DATETIME_FORMATS = (0x69, 0x6a, 0x73, 0x74, 0x77, 0x78, 0x79, 0x7b, 0x7c, 0x7d, 0x7e, 0x80, 0x81, 0x82, 0x86, 0x87, 0x89, 0x8a)
const DURATION_FORMATS = (0x6c, 0x6d, 0x83, 0x84, 0x85) # 0x0c, 0x6b ?
const CURRENCY_FORMATS = (0x5f, )
const LONGITUDE_FORMATS = (0x54, 0x55, 0x56)
const LATITUDE_FORMATS = (0x51, 0x52, 0x53)

# row state
const rowstatemarkers = [
    '•', '+', 'X', '□',
    '◊', '△', 'Y', 'Z',
    '◯', '▭', '▯', '*',
    '⚫', '▬', '▮', '■',
    '⧫', '▽', '◁', '▷',
    '▲', '▼', '◀', '▶',
    '∧', '∨', '<', '>',
    '∣', '─', '/', '\\',
    ]

const rowstatecolors = [
    "#000000", "#555555", "#787878", "#C0C0C0", "#FFFFFF",
    "#A00922", "#C91629", "#F03246", "#FF5C76", "#FF98A6",
    "#904700", "#BC5B03", "#E57406", "#FF9138", "#FFB17D",
    "#706F00", "#AFA502", "#DAD109", "#F0E521", "#FFF977",
    "#516A00", "#729400", "#90BF04", "#A2DC06", "#C1FF3D",
    "#00670C", "#11981B", "#21BC2D", "#23E72E", "#6AFF6B",

    "#007254", "#019970", "#04C791", "#06E3AA", "#0FFFBC",
    "#006D71", "#01989C", "#0CBCBC", "#06E2E3", "#67FFF7",
    "#00638F", "#0380B4", "#05A1D2", "#08C5F7", "#75E4FF",
    "#034AB0", "#0557D6", "#2867FD", "#4E9CFF", "#7E89FF",

    "#6A02A7", "#8C05CF", "#AB08FC", "#C170FF", "#D29AFF",
    "#930195", "#B803B9", "#DC06E1", "#FA50FF", "#FD96FF",
    "#9D0170", "#C5048D", "#E906A4", "#FF49BC", "#FF8CCD",
    ]
