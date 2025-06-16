# 18 first bytes of a .jmp file
# 704 area code for Charlotte, NC ? 07040112 ?
const MAGIC_JMP = [0xff, 0xff, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x02, 0x00]

# Gzip section starts with this byte sequence
const GZIP_SECTION_START = [0xef, 0xbe, 0xfe, 0xca] # cafebeef

# JMP uses 1904 date system
const JMP_STARTDATE = DateTime(1904, 1, 1)

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
