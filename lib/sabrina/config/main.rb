Sabrina::Config.load(
  log_file: 'sabrina.log',

  rom_defaults: {
    title: 'Default ROM',

    dex_blank_start: 252,
    dex_blank_length: 25,
    dex_length: 440,

    name_length: 11,
    stats_length: 28,
    item_length: 44,
    ability_length: 13,
    type_length: 7,

    frames: [1, 1],
    special_frames: {
      385 => [4, 4],
      410 => [2, 2]
    },

    free_space_start: '0x740000',

    name_table: '0x245EE0',

    front_table: '0x2350AC',
    back_table: '0x23654C',
    palette_table: '0x23730C',
    shinypal_table: '0x2380cc',

    stats_table: '0x254784',
    item_table: '0x3DB028',
    ability_table: '0x24FC40',
    type_table: '0x24F1A0'
  },

  rom_data: {
    BPRE: {
      title: 'FireRed (E)',

      name_table: '0x245EE0',

      front_table: '0x2350AC',
      back_table: '0x23654C',
      palette_table: '0x23730C',
      shinypal_table: '0x2380cc',

      stats_table: '0x254784',
      item_table: '0x3DB028',
      ability_table: '0x24FC40',
      type_table: '0x24F1A0'
    },

    BPEE: {
      title: 'Emerald (E)',

      frames: [2, 1],

      name_table: '0x3185C8',

      front_table: '0x30A18C',
      back_table: '0x3028B8',
      palette_table: '0x303678',
      shinypal_table: '0x304438',

      stats_table: '0x3203CC',
      item_table: '0x5839A0',
      ability_table: '0x31B6DB',
      type_table: '0x31AE38'
    },

    AXVE: {
      title: 'Ruby (E)',

      name_table: '0x1F716C',

      front_table: '0x1E8354',
      back_table: '0x1E97F4',
      palette_table: '0x1EA5B4',
      shinypal_table: '0x1EB374',

      stats_table: '0x1FEC18',
      item_table: '0x3C5564',
      ability_table: '0x1FA248',
      type_table: '0x1F9870'
    },

    MrDS: {
      title: "MrDollSteak's Decap and Attack Rombase",

      name_table: '0x245EE0',

      front_table: '0x2350AC',
      back_table: '0x23654C',
      palette_table: '0x23730C',
      shinypal_table: '0x2380cc',

      stats_table: '0x254784',
      item_table: '0x3DB028',
      ability_table: '0x950000',
      type_table: '0x961B50'
    }
  }
)
