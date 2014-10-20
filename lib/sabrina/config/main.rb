Sabrina::Config.load(
  rom_defaults: {
    title: 'Default ROM',

    dex_blank_start: 252,
    dex_blank_length: 25,
    dex_length: 440,

    tm_count: 50,
    hm_count: 8,

    name_length: 11,

    enemy_y_length: 4,
    player_y_length: 4,
    enemy_alt_length: 1,

    stats_length: 28,
    moveset_machine_length: 8,
    moveset_level_length: 4,
    moveset_tutor_length: 2,

    item_length: 44,
    machine_length: 2,

    ability_length: 13,
    type_length: 7,
    move_name_length: 13,

    free_space_start: '0x740000',

    name_table: '0x245EE0',

    front_table: '0x2350AC',
    back_table: '0x23654C',
    palette_table: '0x23730C',
    shinypal_table: '0x2380cc',
    frames: [1, 1],
    special_frames: {
      385 => [4, 4],
      410 => [2, 2]
    },

    enemy_y_table: '0x2349CC',
    player_y_table: '0x235E6C',
    enemy_alt_table: '0x23A004',

    stats_table: '0x254784',
    moveset_machine_table: '0x252BC8',
    moveset_level_table: '0x25d7b4',
    moveset_tutor_table: '0x459B7E',

    item_table: '0x3DB028',
    machine_table: '0x45A80C',
    tutor_table: '0x459B60',

    ability_table: '0x24FC40',
    type_table: '0x24F1A0',
    move_name_table: '0x247094'
  },

  rom_data: {
    BPRE: {
      title: 'FireRed (E)',

      name_table: '0x245EE0',

      front_table: '0x2350AC',
      back_table: '0x23654C',
      palette_table: '0x23730C',
      shinypal_table: '0x2380cc',

      enemy_y_table: '0x2349CC',
      player_y_table: '0x235E6C',
      enemy_alt_table: '0x23A004',

      stats_table: '0x254784',
      moveset_machine_table: '0x252BC8',
      moveset_level_table: '0x25d7b4',
      moveset_tutor_table: '0x459B7E',

      item_table: '0x3DB028',
      machine_table: '0x45A80C',
      tutor_table: '0x459B60',

      ability_table: '0x24FC40',
      type_table: '0x24F1A0',
      move_name_table: '0x247094'
    },

    BPEE: {
      title: 'Emerald (E)',

      moveset_tutor_length: 4,

      name_table: '0x3185C8',

      front_table: '0x30A18C',
      back_table: '0x3028B8',
      palette_table: '0x303678',
      shinypal_table: '0x304438',
      frames: [2, 1],

      enemy_y_table: '0x300D38',
      player_y_table: '0x3021D8',
      enemy_alt_table: '0x305DCC',

      stats_table: '0x3203CC',
      moveset_machine_table: '0x31E898',
      moveset_level_table: '0x32937C',
      moveset_tutor_table: '0x615048',

      item_table: '0x5839A0',
      machine_table: '0x616040',
      tutor_table: '0x61500C',

      ability_table: '0x31B6DB',
      type_table: '0x31AE38',
      move_name_table: '0x31977C'
    },

    AXVE: {
      title: 'Ruby (E)',

      moveset_tutor_length: 0,

      name_table: '0x1F716C',

      front_table: '0x1E8354',
      back_table: '0x1E97F4',
      palette_table: '0x1EA5B4',
      shinypal_table: '0x1EB374',

      enemy_y_table: '0x1E7C74',
      player_y_table: '0x1E9114',
      enemy_alt_table: '0x1ECB14',

      stats_table: '0x1FEC18',
      moveset_machine_table: '0x1FD0F0',
      moveset_level_table: '0x207bc8',

      item_table: '0x3C5564',
      machine_table: '0x376504',

      ability_table: '0x1FA248',
      type_table: '0x1F9870',
      move_name_table: '0x1F8320'
    },

    MrDS: {
      title: "MrDollSteak's Decap and Attack Rombase",

      name_table: '0x245EE0',

      front_table: '0x2350AC',
      back_table: '0x23654C',
      palette_table: '0x23730C',
      shinypal_table: '0x2380cc',

      enemy_y_table: '0x2349CC',
      player_y_table: '0x235E6C',
      enemy_alt_table: '0x23A004',

      stats_table: '0x254784',
      moveset_machine_table: '0x252BC8',
      moveset_level_table: '0x25d7b4',
      moveset_tutor_table: '0x459B7E',

      item_table: '0x3DB028',
      machine_table: '0x45A80C',
      tutor_table: '0x459B60',

      ability_table: '0x950000',
      type_table: '0x961B50',
      move_name_table: '0x901800'
    }
  }
)
