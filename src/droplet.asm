INCLUDE "gbhw.inc"

INITIAL_DROPLETS   EQU 2

SECTION "droplet vars", WRAM0

droplets:: DS 40 * 4
total_droplets:: DS 1
sprite_x: DS 1
sprite_y: DS 1
tile: DS 1


SECTION "droplet", ROM0

init_droplets::
    ld      a,INITIAL_DROPLETS
    ld      [total_droplets],a
    ld      hl, droplets

    ; clear memory
    ld      bc, 40 * 4
    ld      a,0
    call    mem_Set

    ld      hl, droplets
    ld      bc, 0
init_droplets_loop

    push bc



    ; y
    call    get_random_y
    ld      a, e
    ld      [hl], a

    ; x - there are 16 columns, so use sprite offset * 8
    inc     hl

    push    hl
    ld      e,c
    ld      h, 8
    call mul_8b      ; hl = e * h
    ld      a,l
    add     8

    pop hl
    ld      [hl],a


    ; tile
    inc     hl

    call fast_random

    ld     a,e
    ld      [hl],a

    ; attributes
    inc hl
    inc hl

    pop bc
    inc bc

    ld      a,[total_droplets]
    cp      c

    jr	nz,init_droplets_loop	;then loop.
    ret			;done


get_random_y

    call fast_random

    ld     a,e

    push hl
    and     %00001111
    ld      e,a
    ld      h,10
    call mul_8b      ; l now has e * 10
    ld      a,l
    add     16

    pop hl

    ret


move_droplets::
    ld      hl, droplets
    ld      bc, 0

move_droplets_loop

    ; load variables with current record
    ld      a, [hl+]
    ld      [sprite_y], a
    inc     hl
    ld      a, [hl]
    ld      [tile], a
    dec     hl
    dec     hl



.   ; determine droplet type 0-3
    ld      a,c
    and     %00000011

    jp      z,.droplet_type_0
    cp      1
    jp      z,.droplet_type_1
    cp      2
    jp      z,.droplet_type_2
    ;jp      .droplet_type_1

; type 3 - move every fourth frame
.droplet_type_3
    ld      a,  [frame_count]
    and     %00000011
    cp      %00000011
    jp      nz, .dont_move
    ld      e, 1
    jp      .inc_y

; type 2 - move two pixels each frame
.droplet_type_2
    ld      e, 2
    jp      .inc_y

; type 1 - move every other frame
.droplet_type_1

    ld      a,  [frame_count]
    and     %00000001           ; is this an even frame?
    jp      nz, .dont_move
    ld      e, 1
    jp      .inc_y

; type 0 - move every frame
.droplet_type_0
    ld      e, 1

.inc_y

    ld      a, [sprite_y]
    add     e
    ld      [sprite_y],a
.dont_move:

    ld      a,  [frame_count]
    and     %00000011
    cp      %00000011
    jp      nz, .dont_cycle_character

    ld      a,  [sprite_y]
    cp      16
    jp      nz, .skip_tile_reset
    call    fast_random
    ld      a, e
    ld      [tile],a
.skip_tile_reset
    ld      a,  [tile]
    inc     a
    ld      [tile],a
.dont_cycle_character

    ; burn tile to background
    ld      a, [sprite_y]

    ; are we onscreen?
    ; visible range is 16 -> 159
    cp      a, 16   ; carry flag set if 16 > y
    jp      c, .write_to_bg_skip

    cp      a, 159   ; carry flag set if 159 > y
    jp      nc, .write_to_bg_skip

    ; adjust to non-OAM coords
    sub     16

    ; does the y coord align to a tile?
    ld      e, a    ; a is destroyed
    ; mod 8
    and     %00000111

    jp      nz, .write_to_bg_skip


    ; divide by 8 to get y tile coord (0 - 9)
    push    hl
    ld      h, 0
    ld      l, e
    ld      d, 8
    push    bc
    call    div_8b    ; hl = hl / d
    pop     bc

    ld      a, [tile]
    ld      d, a
    ld      a, l
    ld      e, c

    push    bc
    call    set_bg_tile     ; a = y, e = x, d = tile
    pop     bc
    pop     hl


.write_to_bg_skip


    ; burn current character to tile map
    ld      a, [sprite_y]
    ld      [hl+], a
    inc     hl
    ld      a, [tile]
    ld      [hl+], a
    inc     hl

    inc bc
    ld      a,[total_droplets]
    cp      c
    ;ld	a,b		;if b or c != 0,
    ;or	c		;
    jp	nz,move_droplets_loop	;then loop.
    ret
