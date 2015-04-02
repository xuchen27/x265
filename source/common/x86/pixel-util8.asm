;*****************************************************************************
;* Copyright (C) 2013 x265 project
;*
;* Authors: Min Chen <chenm003@163.com> <min.chen@multicorewareinc.com>
;*          Nabajit Deka <nabajit@multicorewareinc.com>
;*          Rajesh Paulraj <rajesh@multicorewareinc.com>
;*
;* This program is free software; you can redistribute it and/or modify
;* it under the terms of the GNU General Public License as published by
;* the Free Software Foundation; either version 2 of the License, or
;* (at your option) any later version.
;*
;* This program is distributed in the hope that it will be useful,
;* but WITHOUT ANY WARRANTY; without even the implied warranty of
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;* GNU General Public License for more details.
;*
;* You should have received a copy of the GNU General Public License
;* along with this program; if not, write to the Free Software
;* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
;*
;* This program is also available under a commercial proprietary license.
;* For more information, contact us at license @ x265.com.
;*****************************************************************************/

%include "x86inc.asm"
%include "x86util.asm"

SECTION_RODATA 32

%if BIT_DEPTH == 10
ssim_c1:   times 4 dd 6697.7856    ; .01*.01*1023*1023*64
ssim_c2:   times 4 dd 3797644.4352 ; .03*.03*1023*1023*64*63
pf_64:     times 4 dd 64.0
pf_128:    times 4 dd 128.0
%elif BIT_DEPTH == 9
ssim_c1:   times 4 dd 1671         ; .01*.01*511*511*64
ssim_c2:   times 4 dd 947556       ; .03*.03*511*511*64*63
%else ; 8-bit
ssim_c1:   times 4 dd 416          ; .01*.01*255*255*64
ssim_c2:   times 4 dd 235963       ; .03*.03*255*255*64*63
%endif

mask_ff:                times 16 db 0xff
                        times 16 db 0
deinterleave_shuf:      times  2 db 0, 2, 4, 6, 8, 10, 12, 14, 1, 3, 5, 7, 9, 11, 13, 15
deinterleave_word_shuf: times  2 db 0, 1, 4, 5, 8, 9, 12, 13, 2, 3, 6, 7, 10, 11, 14, 15
hmul_16p:               times 16 db 1
                        times  8 db 1, -1
hmulw_16p:              times  8 dw 1
                        times  4 dw 1, -1

trans8_shuf:            dd 0, 4, 1, 5, 2, 6, 3, 7

SECTION .text

cextern pw_1
cextern pw_0_15
cextern pb_1
cextern pw_00ff
cextern pw_1023
cextern pw_3fff
cextern pw_2000
cextern pw_pixel_max
cextern pd_1
cextern pd_32767
cextern pd_n32768
cextern pb_2
cextern pb_4
cextern pb_8
cextern pb_16
cextern pb_32
cextern pb_64

;-----------------------------------------------------------------------------
; void getResidual(pixel *fenc, pixel *pred, int16_t *residual, intptr_t stride)
;-----------------------------------------------------------------------------
INIT_XMM sse2
%if HIGH_BIT_DEPTH
cglobal getResidual4, 4,4,4
    add      r3,    r3

    ; row 0-1
    movh         m0, [r0]
    movh         m1, [r0 + r3]
    movh         m2, [r1]
    movh         m3, [r1 + r3]
    punpcklqdq   m0, m1
    punpcklqdq   m2, m3
    psubw        m0, m2

    movh         [r2], m0
    movhps       [r2 + r3], m0
    lea          r0, [r0 + r3 * 2]
    lea          r1, [r1 + r3 * 2]
    lea          r2, [r2 + r3 * 2]

    ; row 2-3
    movh         m0, [r0]
    movh         m1, [r0 + r3]
    movh         m2, [r1]
    movh         m3, [r1 + r3]
    punpcklqdq   m0, m1
    punpcklqdq   m2, m3
    psubw        m0, m2
    movh        [r2], m0
    movhps      [r2 + r3], m0
    RET
%else
cglobal getResidual4, 4,4,5
    pxor        m0, m0

    ; row 0-1
    movd        m1, [r0]
    movd        m2, [r0 + r3]
    movd        m3, [r1]
    movd        m4, [r1 + r3]
    punpckldq   m1, m2
    punpcklbw   m1, m0
    punpckldq   m3, m4
    punpcklbw   m3, m0
    psubw       m1, m3
    movh        [r2], m1
    movhps      [r2 + r3 * 2], m1
    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 4]

    ; row 2-3
    movd        m1, [r0]
    movd        m2, [r0 + r3]
    movd        m3, [r1]
    movd        m4, [r1 + r3]
    punpckldq   m1, m2
    punpcklbw   m1, m0
    punpckldq   m3, m4
    punpcklbw   m3, m0
    psubw       m1, m3
    movh        [r2], m1
    movhps      [r2 + r3 * 2], m1
    RET
%endif


INIT_XMM sse2
%if HIGH_BIT_DEPTH
cglobal getResidual8, 4,4,4
    add      r3,    r3

%assign x 0
%rep 8/2
    ; row 0-1
    movu        m1, [r0]
    movu        m2, [r0 + r3]
    movu        m3, [r1]
    movu        m4, [r1 + r3]
    psubw       m1, m3
    psubw       m2, m4
    movu        [r2], m1
    movu        [r2 + r3], m2
%assign x x+1
%if (x != 4)
    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 2]
%endif
%endrep
    RET
%else
cglobal getResidual8, 4,4,5
    pxor        m0, m0

%assign x 0
%rep 8/2
    ; row 0-1
    movh        m1, [r0]
    movh        m2, [r0 + r3]
    movh        m3, [r1]
    movh        m4, [r1 + r3]
    punpcklbw   m1, m0
    punpcklbw   m2, m0
    punpcklbw   m3, m0
    punpcklbw   m4, m0
    psubw       m1, m3
    psubw       m2, m4
    movu        [r2], m1
    movu        [r2 + r3 * 2], m2
%assign x x+1
%if (x != 4)
    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 4]
%endif
%endrep
    RET
%endif


%if HIGH_BIT_DEPTH
INIT_XMM sse2
cglobal getResidual16, 4,5,6
    add         r3, r3
    mov         r4d, 16/4
.loop:
    ; row 0-1
    movu        m0, [r0]
    movu        m1, [r0 + 16]
    movu        m2, [r0 + r3]
    movu        m3, [r0 + r3 + 16]
    movu        m4, [r1]
    movu        m5, [r1 + 16]
    psubw       m0, m4
    psubw       m1, m5
    movu        m4, [r1 + r3]
    movu        m5, [r1 + r3 + 16]
    psubw       m2, m4
    psubw       m3, m5
    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]

    movu        [r2], m0
    movu        [r2 + 16], m1
    movu        [r2 + r3], m2
    movu        [r2 + r3 + 16], m3
    lea         r2, [r2 + r3 * 2]

    ; row 2-3
    movu        m0, [r0]
    movu        m1, [r0 + 16]
    movu        m2, [r0 + r3]
    movu        m3, [r0 + r3 + 16]
    movu        m4, [r1]
    movu        m5, [r1 + 16]
    psubw       m0, m4
    psubw       m1, m5
    movu        m4, [r1 + r3]
    movu        m5, [r1 + r3 + 16]
    psubw       m2, m4
    psubw       m3, m5

    movu        [r2], m0
    movu        [r2 + 16], m1
    movu        [r2 + r3], m2
    movu        [r2 + r3 + 16], m3

    dec         r4d

    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 2]
    jnz        .loop
    RET
%else
INIT_XMM sse4
cglobal getResidual16, 4,5,8
    mov         r4d, 16/4
    pxor        m0, m0
.loop:
    ; row 0-1
    movu        m1, [r0]
    movu        m2, [r0 + r3]
    movu        m3, [r1]
    movu        m4, [r1 + r3]
    pmovzxbw    m5, m1
    punpckhbw   m1, m0
    pmovzxbw    m6, m2
    punpckhbw   m2, m0
    pmovzxbw    m7, m3
    punpckhbw   m3, m0
    psubw       m5, m7
    psubw       m1, m3
    pmovzxbw    m7, m4
    punpckhbw   m4, m0
    psubw       m6, m7
    psubw       m2, m4

    movu        [r2], m5
    movu        [r2 + 16], m1
    movu        [r2 + r3 * 2], m6
    movu        [r2 + r3 * 2 + 16], m2

    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 4]

    ; row 2-3
    movu        m1, [r0]
    movu        m2, [r0 + r3]
    movu        m3, [r1]
    movu        m4, [r1 + r3]
    pmovzxbw    m5, m1
    punpckhbw   m1, m0
    pmovzxbw    m6, m2
    punpckhbw   m2, m0
    pmovzxbw    m7, m3
    punpckhbw   m3, m0
    psubw       m5, m7
    psubw       m1, m3
    pmovzxbw    m7, m4
    punpckhbw   m4, m0
    psubw       m6, m7
    psubw       m2, m4

    movu        [r2], m5
    movu        [r2 + 16], m1
    movu        [r2 + r3 * 2], m6
    movu        [r2 + r3 * 2 + 16], m2

    dec         r4d

    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 4]
    jnz        .loop
    RET
%endif

%if HIGH_BIT_DEPTH
INIT_YMM avx2
cglobal getResidual16, 4,4,5
    add         r3, r3
    pxor        m0, m0

%assign x 0
%rep 16/2
    movu        m1, [r0]
    movu        m2, [r0 + r3]
    movu        m3, [r1]
    movu        m4, [r1 + r3]

    psubw       m1, m3
    psubw       m2, m4
    movu        [r2], m1
    movu        [r2 + r3], m2
%assign x x+1
%if (x != 8)
    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 2]
%endif
%endrep
    RET
%else
INIT_YMM avx2
cglobal getResidual16, 4,5,8
    lea         r4, [r3 * 2]
    add         r4d, r3d
%assign x 0
%rep 4
    pmovzxbw    m0, [r0]
    pmovzxbw    m1, [r0 + r3]
    pmovzxbw    m2, [r0 + r3 * 2]
    pmovzxbw    m3, [r0 + r4]
    pmovzxbw    m4, [r1]
    pmovzxbw    m5, [r1 + r3]
    pmovzxbw    m6, [r1 + r3 * 2]
    pmovzxbw    m7, [r1 + r4]
    psubw       m0, m4
    psubw       m1, m5
    psubw       m2, m6
    psubw       m3, m7
    movu        [r2], m0
    movu        [r2 + r3 * 2], m1
    movu        [r2 + r3 * 2 * 2], m2
    movu        [r2 + r4 * 2], m3
%assign x x+1
%if (x != 4)
    lea         r0, [r0 + r3 * 2 * 2]
    lea         r1, [r1 + r3 * 2 * 2]
    lea         r2, [r2 + r3 * 4 * 2]
%endif
%endrep
    RET
%endif

%if HIGH_BIT_DEPTH
INIT_XMM sse2
cglobal getResidual32, 4,5,6
    add         r3, r3
    mov         r4d, 32/2
.loop:
    ; row 0
    movu        m0, [r0]
    movu        m1, [r0 + 16]
    movu        m2, [r0 + 32]
    movu        m3, [r0 + 48]
    movu        m4, [r1]
    movu        m5, [r1 + 16]
    psubw       m0, m4
    psubw       m1, m5
    movu        m4, [r1 + 32]
    movu        m5, [r1 + 48]
    psubw       m2, m4
    psubw       m3, m5

    movu        [r2], m0
    movu        [r2 + 16], m1
    movu        [r2 + 32], m2
    movu        [r2 + 48], m3

    ; row 1
    movu        m0, [r0 + r3]
    movu        m1, [r0 + r3 + 16]
    movu        m2, [r0 + r3 + 32]
    movu        m3, [r0 + r3 + 48]
    movu        m4, [r1 + r3]
    movu        m5, [r1 + r3 + 16]
    psubw       m0, m4
    psubw       m1, m5
    movu        m4, [r1 + r3 + 32]
    movu        m5, [r1 + r3 + 48]
    psubw       m2, m4
    psubw       m3, m5

    movu        [r2 + r3], m0
    movu        [r2 + r3 + 16], m1
    movu        [r2 + r3 + 32], m2
    movu        [r2 + r3 + 48], m3

    dec         r4d

    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 2]
    jnz        .loop
    RET
%else
INIT_XMM sse4
cglobal getResidual32, 4,5,7
    mov         r4d, 32/2
    pxor        m0, m0
.loop:
    movu        m1, [r0]
    movu        m2, [r0 + 16]
    movu        m3, [r1]
    movu        m4, [r1 + 16]
    pmovzxbw    m5, m1
    punpckhbw   m1, m0
    pmovzxbw    m6, m3
    punpckhbw   m3, m0
    psubw       m5, m6
    psubw       m1, m3
    movu        [r2 + 0 * 16], m5
    movu        [r2 + 1 * 16], m1

    pmovzxbw    m5, m2
    punpckhbw   m2, m0
    pmovzxbw    m6, m4
    punpckhbw   m4, m0
    psubw       m5, m6
    psubw       m2, m4
    movu        [r2 + 2 * 16], m5
    movu        [r2 + 3 * 16], m2

    movu        m1, [r0 + r3]
    movu        m2, [r0 + r3 + 16]
    movu        m3, [r1 + r3]
    movu        m4, [r1 + r3 + 16]
    pmovzxbw    m5, m1
    punpckhbw   m1, m0
    pmovzxbw    m6, m3
    punpckhbw   m3, m0
    psubw       m5, m6
    psubw       m1, m3
    movu        [r2 + r3 * 2 + 0 * 16], m5
    movu        [r2 + r3 * 2 + 1 * 16], m1

    pmovzxbw    m5, m2
    punpckhbw   m2, m0
    pmovzxbw    m6, m4
    punpckhbw   m4, m0
    psubw       m5, m6
    psubw       m2, m4
    movu        [r2 + r3 * 2 + 2 * 16], m5
    movu        [r2 + r3 * 2 + 3 * 16], m2

    dec         r4d

    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 4]
    jnz        .loop
    RET
%endif


%if HIGH_BIT_DEPTH
INIT_YMM avx2
cglobal getResidual32, 4,4,5
    add         r3, r3
    pxor        m0, m0

%assign x 0
%rep 32
    movu        m1, [r0]
    movu        m2, [r0 + 32]
    movu        m3, [r1]
    movu        m4, [r1 + 32]

    psubw       m1, m3
    psubw       m2, m4
    movu        [r2], m1
    movu        [r2 + 32], m2
%assign x x+1
%if (x != 32)
    lea         r0, [r0 + r3]
    lea         r1, [r1 + r3]
    lea         r2, [r2 + r3]
%endif
%endrep
    RET
%else
INIT_YMM avx2
cglobal getResidual32, 4,5,8
    lea         r4, [r3 * 2]
%assign x 0
%rep 16
    pmovzxbw    m0, [r0]
    pmovzxbw    m1, [r0 + 16]
    pmovzxbw    m2, [r0 + r3]
    pmovzxbw    m3, [r0 + r3 + 16]

    pmovzxbw    m4, [r1]
    pmovzxbw    m5, [r1 + 16]
    pmovzxbw    m6, [r1 + r3]
    pmovzxbw    m7, [r1 + r3 + 16]

    psubw       m0, m4
    psubw       m1, m5
    psubw       m2, m6
    psubw       m3, m7

    movu        [r2 + 0 ], m0
    movu        [r2 + 32], m1
    movu        [r2 + r4 + 0], m2
    movu        [r2 + r4 + 32], m3
%assign x x+1
%if (x != 16)
    lea         r0, [r0 + r3 * 2]
    lea         r1, [r1 + r3 * 2]
    lea         r2, [r2 + r3 * 4]
%endif
%endrep
    RET
%endif
;-----------------------------------------------------------------------------
; uint32_t quant(int16_t *coef, int32_t *quantCoeff, int32_t *deltaU, int16_t *qCoef, int qBits, int add, int numCoeff);
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal quant, 5,6,8
    ; fill qbits
    movd        m4, r4d         ; m4 = qbits

    ; fill qbits-8
    sub         r4d, 8
    movd        m6, r4d         ; m6 = qbits8

    ; fill offset
    movd        m5, r5m
    pshufd      m5, m5, 0       ; m5 = add

    lea         r5, [pd_1]

    mov         r4d, r6m
    shr         r4d, 3
    pxor        m7, m7          ; m7 = numZero
.loop:
    ; 4 coeff
    pmovsxwd    m0, [r0]        ; m0 = level
    pabsd       m1, m0
    pmulld      m1, [r1]        ; m0 = tmpLevel1
    paddd       m2, m1, m5
    psrad       m2, m4          ; m2 = level1

    pslld       m3, m2, 8
    psrad       m1, m6
    psubd       m1, m3          ; m1 = deltaU1

    movu        [r2], m1
    psignd      m3, m2, m0
    pminud      m2, [r5]
    paddd       m7, m2
    packssdw    m3, m3
    movh        [r3], m3

    ; 4 coeff
    pmovsxwd    m0, [r0 + 8]    ; m0 = level
    pabsd       m1, m0
    pmulld      m1, [r1 + 16]   ; m0 = tmpLevel1
    paddd       m2, m1, m5
    psrad       m2, m4          ; m2 = level1
    pslld       m3, m2, 8
    psrad       m1, m6
    psubd       m1, m3          ; m1 = deltaU1
    movu        [r2 + 16], m1
    psignd      m3, m2, m0
    pminud      m2, [r5]
    paddd       m7, m2
    packssdw    m3, m3
    movh        [r3 + 8], m3

    add         r0, 16
    add         r1, 32
    add         r2, 32
    add         r3, 16

    dec         r4d
    jnz        .loop

    pshufd      m0, m7, 00001110b
    paddd       m0, m7
    pshufd      m1, m0, 00000001b
    paddd       m0, m1
    movd        eax, m0
    RET


%if ARCH_X86_64 == 1
INIT_YMM avx2
cglobal quant, 5,5,10
    ; fill qbits
    movd            xm4, r4d            ; m4 = qbits

    ; fill qbits-8
    sub             r4d, 8
    movd            xm6, r4d            ; m6 = qbits8

    ; fill offset
    vpbroadcastd    m5, r5m             ; m5 = add

    vpbroadcastw    m9, [pw_1]          ; m9 = word [1]

    mov             r4d, r6m
    shr             r4d, 4
    pxor            m7, m7              ; m7 = numZero
.loop:
    ; 8 coeff
    pmovsxwd        m0, [r0]            ; m0 = level
    pabsd           m1, m0
    pmulld          m1, [r1]            ; m0 = tmpLevel1
    paddd           m2, m1, m5
    psrad           m2, xm4             ; m2 = level1

    pslld           m3, m2, 8
    psrad           m1, xm6
    psubd           m1, m3              ; m1 = deltaU1
    movu            [r2], m1
    psignd          m2, m0

    ; 8 coeff
    pmovsxwd        m0, [r0 + mmsize/2] ; m0 = level
    pabsd           m1, m0
    pmulld          m1, [r1 + mmsize]   ; m0 = tmpLevel1
    paddd           m3, m1, m5
    psrad           m3, xm4             ; m2 = level1

    pslld           m8, m3, 8
    psrad           m1, xm6
    psubd           m1, m8              ; m1 = deltaU1
    movu            [r2 + mmsize], m1
    psignd          m3, m0

    packssdw        m2, m3
    vpermq          m2, m2, q3120
    movu            [r3], m2

    ; count non-zero coeff
    ; TODO: popcnt is faster, but some CPU can't support
    pminuw          m2, m9
    paddw           m7, m2

    add             r0, mmsize
    add             r1, mmsize*2
    add             r2, mmsize*2
    add             r3, mmsize

    dec             r4d
    jnz            .loop

    ; sum count
    xorpd           m0, m0
    psadbw          m7, m0
    vextracti128    xm1, m7, 1
    paddd           xm7, xm1
    movhlps         xm0, xm7
    paddd           xm7, xm0
    movd            eax, xm7
    RET

%else ; ARCH_X86_64 == 1
INIT_YMM avx2
cglobal quant, 5,6,8
    ; fill qbits
    movd            xm4, r4d        ; m4 = qbits

    ; fill qbits-8
    sub             r4d, 8
    movd            xm6, r4d        ; m6 = qbits8

    ; fill offset
    vpbroadcastd    m5, r5m         ; m5 = ad

    lea             r5, [pd_1]

    mov             r4d, r6m
    shr             r4d, 4
    pxor            m7, m7          ; m7 = numZero
.loop:
    ; 8 coeff
    pmovsxwd        m0, [r0]        ; m0 = level
    pabsd           m1, m0
    pmulld          m1, [r1]        ; m0 = tmpLevel1
    paddd           m2, m1, m5
    psrad           m2, xm4         ; m2 = level1

    pslld           m3, m2, 8
    psrad           m1, xm6
    psubd           m1, m3          ; m1 = deltaU1

    movu            [r2], m1
    psignd          m3, m2, m0
    pminud          m2, [r5]
    paddd           m7, m2
    packssdw        m3, m3
    vpermq          m3, m3, q0020
    movu            [r3], xm3

    ; 8 coeff
    pmovsxwd        m0, [r0 + mmsize/2]        ; m0 = level
    pabsd           m1, m0
    pmulld          m1, [r1 + mmsize]        ; m0 = tmpLevel1
    paddd           m2, m1, m5
    psrad           m2, xm4         ; m2 = level1

    pslld           m3, m2, 8
    psrad           m1, xm6
    psubd           m1, m3          ; m1 = deltaU1

    movu            [r2 + mmsize], m1
    psignd          m3, m2, m0
    pminud          m2, [r5]
    paddd           m7, m2
    packssdw        m3, m3
    vpermq          m3, m3, q0020
    movu            [r3 + mmsize/2], xm3

    add             r0, mmsize
    add             r1, mmsize*2
    add             r2, mmsize*2
    add             r3, mmsize

    dec             r4d
    jnz            .loop

    xorpd           m0, m0
    psadbw          m7, m0
    vextracti128    xm1, m7, 1
    paddd           xm7, xm1
    movhlps         xm0, xm7
    paddd           xm7, xm0
    movd            eax, xm7
    RET
%endif ; ARCH_X86_64 == 1


;-----------------------------------------------------------------------------
; uint32_t nquant(int16_t *coef, int32_t *quantCoeff, int16_t *qCoef, int qBits, int add, int numCoeff);
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal nquant, 3,5,8
    movd        m6, r4m
    mov         r4d, r5m
    pxor        m7, m7          ; m7 = numZero
    movd        m5, r3m         ; m5 = qbits
    pshufd      m6, m6, 0       ; m6 = add
    mov         r3d, r4d        ; r3 = numCoeff
    shr         r4d, 3

.loop:
    pmovsxwd    m0, [r0]        ; m0 = level
    pmovsxwd    m1, [r0 + 8]    ; m1 = level

    pabsd       m2, m0
    pmulld      m2, [r1]        ; m0 = tmpLevel1 * qcoeff
    paddd       m2, m6
    psrad       m2, m5          ; m0 = level1
    psignd      m2, m0

    pabsd       m3, m1
    pmulld      m3, [r1 + 16]   ; m1 = tmpLevel1 * qcoeff
    paddd       m3, m6
    psrad       m3, m5          ; m1 = level1
    psignd      m3, m1

    packssdw    m2, m3

    movu        [r2], m2
    add         r0, 16
    add         r1, 32
    add         r2, 16

    pxor        m4, m4
    pcmpeqw     m2, m4
    psubw       m7, m2

    dec         r4d
    jnz         .loop

    packuswb    m7, m7
    psadbw      m7, m4
    mov         eax, r3d
    movd        r4d, m7
    sub         eax, r4d        ; numSig
    RET


INIT_YMM avx2
cglobal nquant, 3,5,7
    vpbroadcastd m4, r4m
    vpbroadcastd m6, [pw_1]
    mov         r4d, r5m
    pxor        m5, m5              ; m7 = numZero
    movd        xm3, r3m            ; m5 = qbits
    mov         r3d, r4d            ; r3 = numCoeff
    shr         r4d, 4

.loop:
    pmovsxwd    m0, [r0]            ; m0 = level
    pabsd       m1, m0
    pmulld      m1, [r1]            ; m0 = tmpLevel1 * qcoeff
    paddd       m1, m4
    psrad       m1, xm3             ; m0 = level1
    psignd      m1, m0

    pmovsxwd    m0, [r0 + mmsize/2] ; m0 = level
    pabsd       m2, m0
    pmulld      m2, [r1 + mmsize]   ; m0 = tmpLevel1 * qcoeff
    paddd       m2, m4
    psrad       m2, xm3             ; m0 = level1
    psignd      m2, m0

    packssdw    m1, m2
    vpermq      m2, m1, q3120

    movu        [r2], m2
    add         r0, mmsize
    add         r1, mmsize * 2
    add         r2, mmsize

    pminuw      m1, m6
    paddw       m5, m1

    dec         r4d
    jnz         .loop

    pxor        m0, m0
    psadbw      m5, m0
    vextracti128 xm0, m5, 1
    paddd       xm5, xm0
    pshufd      xm0, xm5, 2
    paddd       xm5, xm0
    movd        eax, xm5
    RET


;-----------------------------------------------------------------------------
; void dequant_normal(const int16_t* quantCoef, int32_t* coef, int num, int scale, int shift)
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal dequant_normal, 5,5,5
    mova        m2, [pw_1]
%if HIGH_BIT_DEPTH
    cmp         r3d, 32767
    jle         .skip
    shr         r3d, 2
    sub         r4d, 2
.skip:
%endif
    movd        m0, r4d             ; m0 = shift
    add         r4d, 15
    bts         r3d, r4d
    movd        m1, r3d
    pshufd      m1, m1, 0           ; m1 = dword [add scale]
    ; m0 = shift
    ; m1 = scale
    ; m2 = word [1]
.loop:
    movu        m3, [r0]
    punpckhwd   m4, m3, m2
    punpcklwd   m3, m2
    pmaddwd     m3, m1              ; m3 = dword (clipQCoef * scale + add)
    pmaddwd     m4, m1
    psrad       m3, m0
    psrad       m4, m0
    packssdw    m3, m4
    mova        [r1], m3

    add         r0, 16
    add         r1, 16

    sub         r2d, 8
    jnz        .loop
    RET


INIT_YMM avx2
cglobal dequant_normal, 5,5,7
    vpbroadcastd    m2, [pw_1]          ; m2 = word [1]
    vpbroadcastd    m5, [pd_32767]      ; m5 = dword [32767]
    vpbroadcastd    m6, [pd_n32768]     ; m6 = dword [-32768]
%if HIGH_BIT_DEPTH
    cmp             r3d, 32767
    jle            .skip
    shr             r3d, 2
    sub             r4d, 2
.skip:
%endif
    movd            xm0, r4d            ; m0 = shift
    add             r4d, -1+16
    bts             r3d, r4d
    vpbroadcastd    m1, r3d             ; m1 = dword [add scale]

    ; m0 = shift
    ; m1 = scale
    ; m2 = word [1]
    shr             r2d, 4
.loop:
    movu            m3, [r0]
    punpckhwd       m4, m3, m2
    punpcklwd       m3, m2
    pmaddwd         m3, m1              ; m3 = dword (clipQCoef * scale + add)
    pmaddwd         m4, m1
    psrad           m3, xm0
    psrad           m4, xm0
    pminsd          m3, m5
    pmaxsd          m3, m6
    pminsd          m4, m5
    pmaxsd          m4, m6
    packssdw        m3, m4
    mova            [r1 + 0 * mmsize/2], xm3
    vextracti128    [r1 + 1 * mmsize/2], m3, 1

    add             r0, mmsize
    add             r1, mmsize

    dec             r2d
    jnz            .loop
    RET


;-----------------------------------------------------------------------------
; int x265_count_nonzero_4x4_ssse3(const int16_t *quantCoeff);
;-----------------------------------------------------------------------------
INIT_XMM ssse3
cglobal count_nonzero_4x4, 1,1,2
    pxor            m0, m0

    mova            m1, [r0 + 0]
    packsswb        m1, [r0 + 16]
    pcmpeqb         m1, m0
    paddb           m1, [pb_1]

    psadbw          m1, m0
    pshufd          m0, m1, 2
    paddd           m0, m1
    movd            eax, m0
    RET


;-----------------------------------------------------------------------------
; int x265_count_nonzero_4x4_avx2(const int16_t *quantCoeff);
;-----------------------------------------------------------------------------
INIT_YMM avx2
cglobal count_nonzero_4x4, 1,1,2
    pxor            m0, m0

    mova            m1, [r0 + 0]
    packsswb        m1, [r0 + 16]
    pcmpeqb         m1, m0
    paddb           m1, [pb_1]

    psadbw          m1, m0
    pshufd          m0, m1, 2
    paddd           m1, m0
    movd            eax, xm1
    RET


;-----------------------------------------------------------------------------
; int x265_count_nonzero_8x8_ssse3(const int16_t *quantCoeff);
;-----------------------------------------------------------------------------
INIT_XMM ssse3
cglobal count_nonzero_8x8, 1,1,3
    pxor            m0, m0
    movu            m1, [pb_4]

%rep 4
    mova            m2, [r0 + 0]
    packsswb        m2, [r0 + 16]
    add             r0, 32
    pcmpeqb         m2, m0
    paddb           m1, m2
%endrep

    psadbw          m1, m0
    pshufd          m0, m1, 2
    paddd           m0, m1
    movd            eax, m0
    RET


;-----------------------------------------------------------------------------
; int x265_count_nonzero_8x8_avx2(const int16_t *quantCoeff);
;-----------------------------------------------------------------------------
INIT_YMM avx2
cglobal count_nonzero_8x8, 1,1,3
    pxor            m0, m0
    movu            m1, [pb_2]

    mova            m2, [r0]
    packsswb        m2, [r0 + 32]
    pcmpeqb         m2, m0
    paddb           m1, m2

    mova            m2, [r0 + 64]
    packsswb        m2, [r0 + 96]
    pcmpeqb         m2, m0
    paddb           m1, m2
 
    psadbw          m1, m0
    vextracti128    xm0, m1, 1
    paddd           m0, m1
    pshufd          m1, m0, 2
    paddd           m0, m1
    movd            eax, xm0
    RET


;-----------------------------------------------------------------------------
; int x265_count_nonzero_16x16_ssse3(const int16_t *quantCoeff);
;-----------------------------------------------------------------------------
INIT_XMM ssse3
cglobal count_nonzero_16x16, 1,1,3
    pxor            m0, m0
    movu            m1, [pb_16]

%rep 16
    mova            m2, [r0 + 0]
    packsswb        m2, [r0 + 16]
    add             r0, 32
    pcmpeqb         m2, m0
    paddb           m1, m2
%endrep

    psadbw          m1, m0
    pshufd          m0, m1, 2
    paddd           m0, m1
    movd            eax, m0
    RET


;-----------------------------------------------------------------------------
; int x265_count_nonzero_16x16_avx2(const int16_t *quantCoeff);
;-----------------------------------------------------------------------------
INIT_YMM avx2
cglobal count_nonzero_16x16, 1,1,3
    pxor            m0, m0
    movu            m1, [pb_8]

%assign x 0
%rep 8
    mova            m2, [r0 + x]
    packsswb        m2, [r0 + x + 32]
%assign x x+64
    pcmpeqb         m2, m0
    paddb           m1, m2
%endrep 

    psadbw          m1, m0
    vextracti128    xm0, m1, 1
    paddd           m0, m1
    pshufd          m1, m0, 2
    paddd           m0, m1
    movd            eax, xm0
    RET


;-----------------------------------------------------------------------------
; int x265_count_nonzero_32x32_ssse3(const int16_t *quantCoeff);
;-----------------------------------------------------------------------------
INIT_XMM ssse3
cglobal count_nonzero_32x32, 1,1,3
    pxor            m0, m0
    movu            m1, [pb_64]

%rep 64 
    mova            m2, [r0 + 0]
    packsswb        m2, [r0 + 16]
    add             r0, 32
    pcmpeqb         m2, m0
    paddb           m1, m2
%endrep

    psadbw          m1, m0
    pshufd          m0, m1, 2
    paddd           m0, m1
    movd            eax, m0
    RET


;-----------------------------------------------------------------------------
; int x265_count_nonzero_32x32_avx2(const int16_t *quantCoeff);
;-----------------------------------------------------------------------------
INIT_YMM avx2
cglobal count_nonzero_32x32, 1,1,3
    pxor            m0, m0
    movu            m1, [pb_32]

%assign x 0
%rep 32
    mova            m2, [r0 + x]
    packsswb        m2, [r0 + x + 32]
%assign x x+64
    pcmpeqb         m2, m0
    paddb           m1, m2
%endrep 

    psadbw          m1, m0
    vextracti128    xm0, m1, 1
    paddd           m0, m1
    pshufd          m1, m0, 2
    paddd           m0, m1
    movd            eax, xm0
    RET


;-----------------------------------------------------------------------------------------------------------------------------------------------
;void weight_pp(pixel *src, pixel *dst, intptr_t stride, int width, int height, int w0, int round, int shift, int offset)
;-----------------------------------------------------------------------------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
INIT_XMM sse4
cglobal weight_pp, 4,7,7
%define correction      (14 - BIT_DEPTH)
%if BIT_DEPTH == 10
    mova        m6, [pw_1023]
%elif BIT_DEPTH == 12
    mova        m6, [pw_3fff]
%else
  %error Unsupported BIT_DEPTH!
%endif
    mov         r6d, r6m
    mov         r4d, r4m
    mov         r5d, r5m
    shl         r6d, 16 - correction
    or          r6d, r5d    ; assuming both (w0) and round are using maximum of 16 bits each.
    movd        m0, r6d
    pshufd      m0, m0, 0   ; m0 = [w0, round]
    mov         r5d, r7m
    sub         r5d, correction
    movd        m1, r5d
    movd        m2, r8m
    pshufd      m2, m2, 0
    mova        m5, [pw_1]
    sub         r2d, r3d
    add         r2d, r2d
    shr         r3d, 4

.loopH:
    mov         r5d, r3d

.loopW:
    movu        m4, [r0]
    punpcklwd   m3, m4, m5
    pmaddwd     m3, m0
    psrad       m3, m1
    paddd       m3, m2      ; TODO: we can put Offset into Round, but we have to analyze Dynamic Range before that.

    punpckhwd   m4, m5
    pmaddwd     m4, m0
    psrad       m4, m1
    paddd       m4, m2

    packusdw    m3, m4
    pminuw      m3, m6
    movu        [r1], m3

    movu        m4, [r0 + mmsize]
    punpcklwd   m3, m4, m5
    pmaddwd     m3, m0
    psrad       m3, m1
    paddd       m3, m2

    punpckhwd   m4, m5
    pmaddwd     m4, m0
    psrad       m4, m1
    paddd       m4, m2

    packusdw    m3, m4
    pminuw      m3, m6
    movu        [r1 + mmsize], m3

    add         r0, 2 * mmsize
    add         r1, 2 * mmsize

    dec         r5d
    jnz        .loopW

    add         r0, r2
    add         r1, r2

    dec         r4d
    jnz         .loopH
    RET

%else   ; end of (HIGH_BIT_DEPTH == 1)

INIT_XMM sse4
cglobal weight_pp, 6,7,6
    shl         r5d, 6      ; m0 = [w0<<6]
    mov         r6d, r6m
    shl         r6d, 16
    or          r6d, r5d    ; assuming both (w0<<6) and round are using maximum of 16 bits each.
    movd        m0, r6d
    pshufd      m0, m0, 0   ; m0 = [w0<<6, round]
    movd        m1, r7m
    movd        m2, r8m
    pshufd      m2, m2, 0
    mova        m5, [pw_1]
    sub         r2d, r3d
    shr         r3d, 4

.loopH:
    mov         r5d, r3d

.loopW:
    pmovzxbw    m4, [r0]
    punpcklwd   m3, m4, m5
    pmaddwd     m3, m0
    psrad       m3, m1
    paddd       m3, m2

    punpckhwd   m4, m5
    pmaddwd     m4, m0
    psrad       m4, m1
    paddd       m4, m2

    packssdw    m3, m4
    packuswb    m3, m3
    movh        [r1], m3

    pmovzxbw    m4, [r0 + 8]
    punpcklwd   m3, m4, m5
    pmaddwd     m3, m0
    psrad       m3, m1
    paddd       m3, m2

    punpckhwd   m4, m5
    pmaddwd     m4, m0
    psrad       m4, m1
    paddd       m4, m2

    packssdw    m3, m4
    packuswb    m3, m3
    movh        [r1 + 8], m3

    add         r0, 16
    add         r1, 16

    dec         r5d
    jnz         .loopW

    lea         r0, [r0 + r2]
    lea         r1, [r1 + r2]

    dec         r4d
    jnz         .loopH
    RET
%endif  ; end of (HIGH_BIT_DEPTH == 0)



INIT_YMM avx2
cglobal weight_pp, 6, 7, 6

    shl          r5d, 6            ; m0 = [w0<<6]
    mov          r6d, r6m
    shl          r6d, 16
    or           r6d, r5d          ; assuming both (w0<<6) and round are using maximum of 16 bits each.

    vpbroadcastd m0, r6d

    movd         xm1, r7m
    vpbroadcastd m2, r8m
    mova         m5, [pw_1]
    sub          r2d, r3d
    shr          r3d, 4

.loopH:
    mov          r5d, r3d

.loopW:
    pmovzxbw    m4, [r0]
    punpcklwd   m3, m4, m5
    pmaddwd     m3, m0
    psrad       m3, xm1
    paddd       m3, m2

    punpckhwd   m4, m5
    pmaddwd     m4, m0
    psrad       m4, xm1
    paddd       m4, m2

    packssdw    m3, m4
    vextracti128 xm4, m3, 1
    packuswb    xm3, xm4
    movu        [r1], xm3

    add         r0, 16
    add         r1, 16

    dec         r5d
    jnz         .loopW

    lea         r0, [r0 + r2]
    lea         r1, [r1 + r2]

    dec         r4d
    jnz         .loopH
    RET

;-------------------------------------------------------------------------------------------------------------------------------------------------
;void weight_sp(int16_t *src, pixel *dst, intptr_t srcStride, intptr_t dstStride, int width, int height, int w0, int round, int shift, int offset)
;-------------------------------------------------------------------------------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
INIT_XMM sse4
cglobal weight_sp, 6,7,8
%if BIT_DEPTH == 10
    mova        m1, [pw_1023]
%elif BIT_DEPTH == 12
    mova        m1, [pw_3fff]
%else
  %error Unsupported BIT_DEPTH!
%endif
    mova        m2, [pw_1]
    mov         r6d, r7m
    shl         r6d, 16
    or          r6d, r6m    ; assuming both (w0) and round are using maximum of 16 bits each.
    movd        m3, r6d
    pshufd      m3, m3, 0   ; m3 = [round w0]

    movd        m4, r8m     ; m4 = [shift]
    movd        m5, r9m
    pshufd      m5, m5, 0   ; m5 = [offset]

    ; correct row stride
    add         r3d, r3d
    add         r2d, r2d
    mov         r6d, r4d
    and         r6d, ~(mmsize / SIZEOF_PIXEL - 1)
    sub         r3d, r6d
    sub         r3d, r6d
    sub         r2d, r6d
    sub         r2d, r6d

    ; generate partial width mask (MUST BE IN XMM0)
    mov         r6d, r4d
    and         r6d, (mmsize / SIZEOF_PIXEL - 1)
    movd        m0, r6d
    pshuflw     m0, m0, 0
    punpcklqdq  m0, m0
    pcmpgtw     m0, [pw_0_15]

.loopH:
    mov         r6d, r4d

.loopW:
    movu        m6, [r0]
    paddw       m6, [pw_2000]

    punpcklwd   m7, m6, m2
    pmaddwd     m7, m3
    psrad       m7, m4
    paddd       m7, m5

    punpckhwd   m6, m2
    pmaddwd     m6, m3
    psrad       m6, m4
    paddd       m6, m5

    packusdw    m7, m6
    pminuw      m7, m1

    sub         r6d, (mmsize / SIZEOF_PIXEL)
    jl         .widthLess8
    movu        [r1], m7
    lea         r0, [r0 + mmsize]
    lea         r1, [r1 + mmsize]
    je         .nextH
    jmp        .loopW

.widthLess8:
    movu        m6, [r1]
    pblendvb    m6, m6, m7, m0
    movu        [r1], m6

.nextH:
    add         r0, r2
    add         r1, r3

    dec         r5d
    jnz         .loopH
    RET

%else   ; end of (HIGH_BIT_DEPTH == 1)

INIT_XMM sse4
%if ARCH_X86_64
cglobal weight_sp, 6, 7+2, 7
    %define tmp_r0      r7
    %define tmp_r1      r8
%else ; ARCH_X86_64 = 0
cglobal weight_sp, 6, 7, 7, 0-(2*4)
    %define tmp_r0      [(rsp + 0 * 4)]
    %define tmp_r1      [(rsp + 1 * 4)]
%endif ; ARCH_X86_64

    movd        m0, r6m         ; m0 = [w0]

    movd        m1, r7m         ; m1 = [round]
    punpcklwd   m0, m1
    pshufd      m0, m0, 0       ; m0 = [w0 round]

    movd        m1, r8m         ; m1 = [shift]

    movd        m2, r9m
    pshufd      m2, m2, 0       ; m2 =[offset]

    mova        m3, [pw_1]
    mova        m4, [pw_2000]

    add         r2d, r2d

.loopH:
    mov         r6d, r4d

    ; save old src and dst
    mov         tmp_r0, r0
    mov         tmp_r1, r1
.loopW:
    movu        m5, [r0]
    paddw       m5, m4

    punpcklwd   m6,m5, m3
    pmaddwd     m6, m0
    psrad       m6, m1
    paddd       m6, m2

    punpckhwd   m5, m3
    pmaddwd     m5, m0
    psrad       m5, m1
    paddd       m5, m2

    packssdw    m6, m5
    packuswb    m6, m6

    sub         r6d, 8
    jl          .width4
    movh        [r1], m6
    je          .nextH
    add         r0, 16
    add         r1, 8

    jmp         .loopW

.width4:
    cmp         r6d, -4
    jl          .width2
    movd        [r1], m6
    je          .nextH
    add         r1, 4
    pshufd      m6, m6, 1

.width2:
    pextrw      [r1], m6, 0

.nextH:
    mov         r0, tmp_r0
    mov         r1, tmp_r1
    lea         r0, [r0 + r2]
    lea         r1, [r1 + r3]

    dec         r5d
    jnz         .loopH
    RET

%if ARCH_X86_64
INIT_YMM avx2
cglobal weight_sp, 6, 9, 7
    mov             r7d, r7m
    shl             r7d, 16
    or              r7d, r6m
    vpbroadcastd    m0, r7d            ; m0 = times 8 dw w0, round
    movd            xm1, r8m            ; m1 = [shift]
    vpbroadcastd    m2, r9m            ; m2 = times 16 dw offset
    vpbroadcastw    m3, [pw_1]
    vpbroadcastw    m4, [pw_2000]

    add             r2d, r2d            ; 2 * srcstride

    mov             r7, r0
    mov             r8, r1
.loopH:
    mov             r6d, r4d            ; width

    ; save old src and dst
    mov             r0, r7              ; src
    mov             r1, r8              ; dst
.loopW:
    movu            m5, [r0]
    paddw           m5, m4

    punpcklwd       m6,m5, m3
    pmaddwd         m6, m0
    psrad           m6, xm1
    paddd           m6, m2

    punpckhwd       m5, m3
    pmaddwd         m5, m0
    psrad           m5, xm1
    paddd           m5, m2

    packssdw        m6, m5
    packuswb        m6, m6
    vpermq          m6, m6, 10001000b

    sub             r6d, 16
    jl              .width8
    movu            [r1], xm6
    je              .nextH
    add             r0, 32
    add             r1, 16
    jmp             .loopW

.width8:
    add             r6d, 16
    cmp             r6d, 8
    jl              .width4
    movq            [r1], xm6
    je              .nextH
    psrldq          m6, 8
    sub             r6d, 8
    add             r1, 8

.width4:
    cmp             r6d, 4
    jl              .width2
    movd            [r1], xm6
    je              .nextH
    add             r1, 4
    pshufd          m6, m6, 1

.width2:
    pextrw          [r1], xm6, 0

.nextH:
    lea             r7, [r7 + r2]
    lea             r8, [r8 + r3]

    dec             r5d
    jnz             .loopH
    RET
%endif
%endif  ; end of (HIGH_BIT_DEPTH == 0)
    

;-----------------------------------------------------------------
; void transpose_4x4(pixel *dst, pixel *src, intptr_t stride)
;-----------------------------------------------------------------
INIT_XMM sse2
cglobal transpose4, 3, 3, 4, dest, src, stride
%if HIGH_BIT_DEPTH == 1
    add          r2,    r2
    movh         m0,    [r1]
    movh         m1,    [r1 + r2]
    movh         m2,    [r1 + 2 * r2]
    lea          r1,    [r1 + 2 * r2]
    movh         m3,    [r1 + r2]
    punpcklwd    m0,    m1
    punpcklwd    m2,    m3
    punpckhdq    m1,    m0,    m2
    punpckldq    m0,    m2
    movu         [r0],       m0
    movu         [r0 + 16],  m1
%else ;HIGH_BIT_DEPTH == 0
    movd         m0,    [r1]
    movd         m1,    [r1 + r2]
    movd         m2,    [r1 + 2 * r2]
    lea          r1,    [r1 + 2 * r2]
    movd         m3,    [r1 + r2]

    punpcklbw    m0,    m1
    punpcklbw    m2,    m3
    punpcklwd    m0,    m2
    movu         [r0],    m0
%endif
    RET

;-----------------------------------------------------------------
; void transpose_8x8(pixel *dst, pixel *src, intptr_t stride)
;-----------------------------------------------------------------
%if HIGH_BIT_DEPTH == 1
%if ARCH_X86_64 == 1
INIT_YMM avx2
cglobal transpose8, 3, 5, 5
    add          r2, r2
    lea          r3, [3 * r2]
    lea          r4, [r1 + 4 * r2]
    movu         xm0, [r1]
    vinserti128  m0, m0, [r4], 1
    movu         xm1, [r1 + r2]
    vinserti128  m1, m1, [r4 + r2], 1
    movu         xm2, [r1 + 2 * r2]
    vinserti128  m2, m2, [r4 + 2 * r2], 1
    movu         xm3, [r1 + r3]
    vinserti128  m3, m3, [r4 + r3], 1

    punpcklwd    m4, m0, m1          ;[1 - 4][row1row2;row5row6]
    punpckhwd    m0, m1              ;[5 - 8][row1row2;row5row6]

    punpcklwd    m1, m2, m3          ;[1 - 4][row3row4;row7row8]
    punpckhwd    m2, m3              ;[5 - 8][row3row4;row7row8]

    punpckldq    m3, m4, m1          ;[1 - 2][row1row2row3row4;row5row6row7row8]
    punpckhdq    m4, m1              ;[3 - 4][row1row2row3row4;row5row6row7row8]

    punpckldq    m1, m0, m2          ;[5 - 6][row1row2row3row4;row5row6row7row8]
    punpckhdq    m0, m2              ;[7 - 8][row1row2row3row4;row5row6row7row8]

    vpermq       m3, m3, 0xD8        ;[1 ; 2][row1row2row3row4row5row6row7row8]
    vpermq       m4, m4, 0xD8        ;[3 ; 4][row1row2row3row4row5row6row7row8]
    vpermq       m1, m1, 0xD8        ;[5 ; 6][row1row2row3row4row5row6row7row8]
    vpermq       m0, m0, 0xD8        ;[7 ; 8][row1row2row3row4row5row6row7row8]

    movu         [r0 + 0 * 32], m3
    movu         [r0 + 1 * 32], m4
    movu         [r0 + 2 * 32], m1
    movu         [r0 + 3 * 32], m0
    RET
%endif

INIT_XMM sse2
%macro TRANSPOSE_4x4 1
    movh         m0,    [r1]
    movh         m1,    [r1 + r2]
    movh         m2,    [r1 + 2 * r2]
    lea          r1,    [r1 + 2 * r2]
    movh         m3,    [r1 + r2]
    punpcklwd    m0,    m1
    punpcklwd    m2,    m3
    punpckhdq    m1,    m0,    m2
    punpckldq    m0,    m2
    movh         [r0],             m0
    movhps       [r0 + %1],        m0
    movh         [r0 + 2 * %1],    m1
    lea            r0,               [r0 + 2 * %1]
    movhps         [r0 + %1],        m1
%endmacro
cglobal transpose8_internal
    TRANSPOSE_4x4 r5
    lea    r1,    [r1 + 2 * r2]
    lea    r0,    [r3 + 8]
    TRANSPOSE_4x4 r5
    lea    r1,    [r1 + 2 * r2]
    neg    r2
    lea    r1,    [r1 + r2 * 8 + 8]
    neg    r2
    lea    r0,    [r3 + 4 * r5]
    TRANSPOSE_4x4 r5
    lea    r1,    [r1 + 2 * r2]
    lea    r0,    [r3 + 8 + 4 * r5]
    TRANSPOSE_4x4 r5
    ret
cglobal transpose8, 3, 6, 4, dest, src, stride
    add    r2,    r2
    mov    r3,    r0
    mov    r5,    16
    call   transpose8_internal
    RET
%else ;HIGH_BIT_DEPTH == 0
%if ARCH_X86_64 == 1
INIT_YMM avx2
cglobal transpose8, 3, 4, 4
    lea          r3, [r2 * 3]
    movq         xm0, [r1]
    movhps       xm0, [r1 + 2 * r2]
    movq         xm1, [r1 + r2]
    movhps       xm1, [r1 + r3]
    lea          r1, [r1 + 4 * r2]
    movq         xm2, [r1]
    movhps       xm2, [r1 + 2 * r2]
    movq         xm3, [r1 + r2]
    movhps       xm3, [r1 + r3]

    vinserti128  m0, m0, xm2, 1             ;[row1 row3 row5 row7]
    vinserti128  m1, m1, xm3, 1             ;[row2 row4 row6 row8]

    punpcklbw    m2, m0, m1                 ;[1 - 8; 1 - 8][row1row2; row5row6]
    punpckhbw    m0, m1                     ;[1 - 8; 1 - 8][row3row4; row7row8]

    punpcklwd    m1, m2, m0                 ;[1 - 4; 1 - 4][row1row2row3row4; row5row6row7row8]
    punpckhwd    m2, m0                     ;[5 - 8; 5 - 8][row1row2row3row4; row5row6row7row8]

    mova         m0, [trans8_shuf]

    vpermd       m1, m0, m1                 ;[1 - 2; 3 - 4][row1row2row3row4row5row6row7row8]
    vpermd       m2, m0, m2                 ;[4 - 5; 6 - 7][row1row2row3row4row5row6row7row8]

    movu         [r0], m1
    movu         [r0 + 32], m2
    RET
%endif

INIT_XMM sse2
cglobal transpose8, 3, 5, 8, dest, src, stride
    lea          r3,    [2 * r2]
    lea          r4,    [3 * r2]
    movh         m0,    [r1]
    movh         m1,    [r1 + r2]
    movh         m2,    [r1 + r3]
    movh         m3,    [r1 + r4]
    movh         m4,    [r1 + 4 * r2]
    lea          r1,    [r1 + 4 * r2]
    movh         m5,    [r1 + r2]
    movh         m6,    [r1 + r3]
    movh         m7,    [r1 + r4]

    punpcklbw    m0,    m1
    punpcklbw    m2,    m3
    punpcklbw    m4,    m5
    punpcklbw    m6,    m7

    punpckhwd    m1,    m0,    m2
    punpcklwd    m0,    m2
    punpckhwd    m5,    m4,    m6
    punpcklwd    m4,    m6
    punpckhdq    m2,    m0,    m4
    punpckldq    m0,    m4
    punpckhdq    m3,    m1,    m5
    punpckldq    m1,    m5

    movu         [r0],         m0
    movu         [r0 + 16],    m2
    movu         [r0 + 32],    m1
    movu         [r0 + 48],    m3
    RET
%endif

%macro TRANSPOSE_8x8 1

    movh         m0,    [r1]
    movh         m1,    [r1 + r2]
    movh         m2,    [r1 + 2 * r2]
    lea          r1,    [r1 + 2 * r2]
    movh         m3,    [r1 + r2]
    movh         m4,    [r1 + 2 * r2]
    lea          r1,    [r1 + 2 * r2]
    movh         m5,    [r1 + r2]
    movh         m6,    [r1 + 2 * r2]
    lea          r1,    [r1 + 2 * r2]
    movh         m7,    [r1 + r2]

    punpcklbw    m0,    m1
    punpcklbw    m2,    m3
    punpcklbw    m4,    m5
    punpcklbw    m6,    m7

    punpckhwd    m1,    m0,    m2
    punpcklwd    m0,    m2
    punpckhwd    m5,    m4,    m6
    punpcklwd    m4,    m6
    punpckhdq    m2,    m0,    m4
    punpckldq    m0,    m4
    punpckhdq    m3,    m1,    m5
    punpckldq    m1,    m5

    movh           [r0],             m0
    movhps         [r0 + %1],        m0
    movh           [r0 + 2 * %1],    m2
    lea            r0,               [r0 + 2 * %1]
    movhps         [r0 + %1],        m2
    movh           [r0 + 2 * %1],    m1
    lea            r0,               [r0 + 2 * %1]
    movhps         [r0 + %1],        m1
    movh           [r0 + 2 * %1],    m3
    lea            r0,               [r0 + 2 * %1]
    movhps         [r0 + %1],        m3

%endmacro


;-----------------------------------------------------------------
; void transpose_16x16(pixel *dst, pixel *src, intptr_t stride)
;-----------------------------------------------------------------
%if HIGH_BIT_DEPTH == 1
%if ARCH_X86_64 == 1
INIT_YMM avx2
cglobal transpose16x8_internal
    movu         m0, [r1]
    movu         m1, [r1 + r2]
    movu         m2, [r1 + 2 * r2]
    movu         m3, [r1 + r3]
    lea          r1, [r1 + 4 * r2]

    movu         m4, [r1]
    movu         m5, [r1 + r2]
    movu         m6, [r1 + 2 * r2]
    movu         m7, [r1 + r3]

    punpcklwd    m8, m0, m1                 ;[1 - 4; 9 - 12][1 2]
    punpckhwd    m0, m1                     ;[5 - 8; 13 -16][1 2]

    punpcklwd    m1, m2, m3                 ;[1 - 4; 9 - 12][3 4]
    punpckhwd    m2, m3                     ;[5 - 8; 13 -16][3 4]

    punpcklwd    m3, m4, m5                 ;[1 - 4; 9 - 12][5 6]
    punpckhwd    m4, m5                     ;[5 - 8; 13 -16][5 6]

    punpcklwd    m5, m6, m7                 ;[1 - 4; 9 - 12][7 8]
    punpckhwd    m6, m7                     ;[5 - 8; 13 -16][7 8]

    punpckldq    m7, m8, m1                 ;[1 - 2; 9 -  10][1 2 3 4]
    punpckhdq    m8, m1                     ;[3 - 4; 11 - 12][1 2 3 4]

    punpckldq    m1, m3, m5                 ;[1 - 2; 9 -  10][5 6 7 8]
    punpckhdq    m3, m5                     ;[3 - 4; 11 - 12][5 6 7 8]

    punpckldq    m5, m0, m2                 ;[5 - 6; 13 - 14][1 2 3 4]
    punpckhdq    m0, m2                     ;[7 - 8; 15 - 16][1 2 3 4]

    punpckldq    m2, m4, m6                 ;[5 - 6; 13 - 14][5 6 7 8]
    punpckhdq    m4, m6                     ;[7 - 8; 15 - 16][5 6 7 8]

    punpcklqdq   m6, m7, m1                 ;[1 ; 9 ][1 2 3 4 5 6 7 8]
    punpckhqdq   m7, m1                     ;[2 ; 10][1 2 3 4 5 6 7 8]

    punpcklqdq   m1, m8, m3                 ;[3 ; 11][1 2 3 4 5 6 7 8]
    punpckhqdq   m8, m3                     ;[4 ; 12][1 2 3 4 5 6 7 8]

    punpcklqdq   m3, m5, m2                 ;[5 ; 13][1 2 3 4 5 6 7 8]
    punpckhqdq   m5, m2                     ;[6 ; 14][1 2 3 4 5 6 7 8]

    punpcklqdq   m2, m0, m4                 ;[7 ; 15][1 2 3 4 5 6 7 8]
    punpckhqdq   m0, m4                     ;[8 ; 16][1 2 3 4 5 6 7 8]

    movu         [r0 + 0 * 32], xm6
    vextracti128 [r0 + 8 * 32], m6, 1
    movu         [r0 + 1  * 32], xm7
    vextracti128 [r0 + 9  * 32], m7, 1
    movu         [r0 + 2  * 32], xm1
    vextracti128 [r0 + 10 * 32], m1, 1
    movu         [r0 + 3  * 32], xm8
    vextracti128 [r0 + 11 * 32], m8, 1
    movu         [r0 + 4  * 32], xm3
    vextracti128 [r0 + 12 * 32], m3, 1
    movu         [r0 + 5  * 32], xm5
    vextracti128 [r0 + 13 * 32], m5, 1
    movu         [r0 + 6  * 32], xm2
    vextracti128 [r0 + 14 * 32], m2, 1
    movu         [r0 + 7  * 32], xm0
    vextracti128 [r0 + 15 * 32], m0, 1
    ret

cglobal transpose16, 3, 4, 9
    add          r2, r2
    lea          r3, [r2 * 3]
    call         transpose16x8_internal
    lea          r1, [r1 + 4 * r2]
    add          r0, 16
    call         transpose16x8_internal
    RET
%endif
INIT_XMM sse2
cglobal transpose16, 3, 7, 4, dest, src, stride
    add    r2,    r2
    mov    r3,    r0
    mov    r4,    r1
    mov    r5,    32
    mov    r6,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r4 + 16]
    lea    r0,    [r6 + 8 * r5]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * r5 + 16]
    mov    r3,    r0
    call   transpose8_internal
    RET
%else ;HIGH_BIT_DEPTH == 0
%if ARCH_X86_64 == 1
INIT_YMM avx2
cglobal transpose16, 3, 5, 9
    lea          r3, [r2 * 3]
    lea          r4, [r1 + 8 * r2]

    movu         xm0, [r1]
    movu         xm1, [r1 + r2]
    movu         xm2, [r1 + 2 * r2]
    movu         xm3, [r1 + r3]
    vinserti128  m0,  m0, [r4], 1
    vinserti128  m1,  m1, [r4 + r2], 1
    vinserti128  m2,  m2, [r4 + 2 * r2], 1
    vinserti128  m3,  m3, [r4 + r3], 1
    lea          r1,  [r1 + 4 * r2]
    lea          r4,  [r4 + 4 * r2]

    movu         xm4, [r1]
    movu         xm5, [r1 + r2]
    movu         xm6, [r1 + 2 * r2]
    movu         xm7, [r1 + r3]
    vinserti128  m4,  m4, [r4], 1
    vinserti128  m5,  m5, [r4 + r2], 1
    vinserti128  m6,  m6, [r4 + 2 * r2], 1
    vinserti128  m7,  m7, [r4 + r3], 1

    punpcklbw    m8, m0, m1                 ;[1 - 8 ; 1 - 8 ][1 2  9 10]
    punpckhbw    m0, m1                     ;[9 - 16; 9 - 16][1 2  9 10]

    punpcklbw    m1, m2, m3                 ;[1 - 8 ; 1 - 8 ][3 4 11 12]
    punpckhbw    m2, m3                     ;[9 - 16; 9 - 16][3 4 11 12]

    punpcklbw    m3, m4, m5                 ;[1 - 8 ; 1 - 8 ][5 6 13 14]
    punpckhbw    m4, m5                     ;[9 - 16; 9 - 16][5 6 13 14]

    punpcklbw    m5, m6, m7                 ;[1 - 8 ; 1 - 8 ][7 8 15 16]
    punpckhbw    m6, m7                     ;[9 - 16; 9 - 16][7 8 15 16]

    punpcklwd    m7, m8, m1                 ;[1 - 4 ; 1 - 4][1 2 3 4 9 10 11 12]
    punpckhwd    m8, m1                     ;[5 - 8 ; 5 - 8][1 2 3 4 9 10 11 12]

    punpcklwd    m1, m3, m5                 ;[1 - 4 ; 1 - 4][5 6 7 8 13 14 15 16]
    punpckhwd    m3, m5                     ;[5 - 8 ; 5 - 8][5 6 7 8 13 14 15 16]

    punpcklwd    m5, m0, m2                 ;[9 - 12; 9 -  12][1 2 3 4 9 10 11 12]
    punpckhwd    m0, m2                     ;[13- 16; 13 - 16][1 2 3 4 9 10 11 12]

    punpcklwd    m2, m4, m6                 ;[9 - 12; 9 -  12][5 6 7 8 13 14 15 16]
    punpckhwd    m4, m6                     ;[13- 16; 13 - 16][5 6 7 8 13 14 15 16]

    punpckldq    m6, m7, m1                 ;[1 - 2 ; 1 - 2][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhdq    m7, m1                     ;[3 - 4 ; 3 - 4][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpckldq    m1, m8, m3                 ;[5 - 6 ; 5 - 6][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhdq    m8, m3                     ;[7 - 8 ; 7 - 8][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpckldq    m3, m5, m2                 ;[9 - 10; 9 -  10][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhdq    m5, m2                     ;[11- 12; 11 - 12][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpckldq    m2, m0, m4                 ;[13- 14; 13 - 14][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhdq    m0, m4                     ;[15- 16; 15 - 16][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    vpermq       m6, m6, 0xD8
    vpermq       m7, m7, 0xD8
    vpermq       m1, m1, 0xD8
    vpermq       m8, m8, 0xD8
    vpermq       m3, m3, 0xD8
    vpermq       m5, m5, 0xD8
    vpermq       m2, m2, 0xD8
    vpermq       m0, m0, 0xD8

    movu         [r0 + 0 *  16], m6
    movu         [r0 + 2 *  16], m7
    movu         [r0 + 4 *  16], m1
    movu         [r0 + 6 *  16], m8
    movu         [r0 + 8 *  16], m3
    movu         [r0 + 10 * 16], m5
    movu         [r0 + 12 * 16], m2
    movu         [r0 + 14 * 16], m0
    RET
%endif
INIT_XMM sse2
cglobal transpose16, 3, 5, 8, dest, src, stride
    mov    r3,    r0
    mov    r4,    r1
    TRANSPOSE_8x8 16
    lea    r1,    [r1 + 2 * r2]
    lea    r0,    [r3 + 8]
    TRANSPOSE_8x8 16
    lea    r1,    [r4 + 8]
    lea    r0,    [r3 + 8 * 16]
    TRANSPOSE_8x8 16
    lea    r1,    [r1 + 2 * r2]
    lea    r0,    [r3 + 8 * 16 + 8]
    TRANSPOSE_8x8 16
    RET
%endif

cglobal transpose16_internal
    TRANSPOSE_8x8 r6
    lea    r1,    [r1 + 2 * r2]
    lea    r0,    [r5 + 8]
    TRANSPOSE_8x8 r6
    lea    r1,    [r1 + 2 * r2]
    neg    r2
    lea    r1,    [r1 + r2 * 8]
    lea    r1,    [r1 + r2 * 8 + 8]
    neg    r2
    lea    r0,    [r5 + 8 * r6]
    TRANSPOSE_8x8 r6
    lea    r1,    [r1 + 2 * r2]
    lea    r0,    [r5 + 8 * r6 + 8]
    TRANSPOSE_8x8 r6
    ret

;-----------------------------------------------------------------
; void transpose_32x32(pixel *dst, pixel *src, intptr_t stride)
;-----------------------------------------------------------------
%if HIGH_BIT_DEPTH == 1
%if ARCH_X86_64 == 1
INIT_YMM avx2
cglobal transpose8x32_internal
    movu         m0, [r1]
    movu         m1, [r1 + 32]
    movu         m2, [r1 + r2]
    movu         m3, [r1 + r2 + 32]
    movu         m4, [r1 + 2 * r2]
    movu         m5, [r1 + 2 * r2 + 32]
    movu         m6, [r1 + r3]
    movu         m7, [r1 + r3 + 32]
    lea          r1, [r1 + 4 * r2]

    punpcklwd    m8, m0, m2               ;[1 - 4;  9 - 12][1 2]
    punpckhwd    m0, m2                   ;[5 - 8; 13 - 16][1 2]

    punpcklwd    m2, m4, m6               ;[1 - 4;  9 - 12][3 4]
    punpckhwd    m4, m6                   ;[5 - 8; 13 - 16][3 4]

    punpcklwd    m6, m1, m3               ;[17 - 20; 25 - 28][1 2]
    punpckhwd    m1, m3                   ;[21 - 24; 29 - 32][1 2]

    punpcklwd    m3, m5, m7               ;[17 - 20; 25 - 28][3 4]
    punpckhwd    m5, m7                   ;[21 - 24; 29 - 32][3 4]

    punpckldq    m7, m8, m2               ;[1 - 2;  9 - 10][1 2 3 4]
    punpckhdq    m8, m2                   ;[3 - 4; 11 - 12][1 2 3 4]

    punpckldq    m2, m0, m4               ;[5 - 6; 13 - 14][1 2 3 4]
    punpckhdq    m0, m4                   ;[7 - 8; 15 - 16][1 2 3 4]

    punpckldq    m4, m6, m3               ;[17 - 18; 25 - 26][1 2 3 4]
    punpckhdq    m6, m3                   ;[19 - 20; 27 - 28][1 2 3 4]

    punpckldq    m3, m1, m5               ;[21 - 22; 29 - 30][1 2 3 4]
    punpckhdq    m1, m5                   ;[23 - 24; 31 - 32][1 2 3 4]

    movq         [r0 + 0  * 64], xm7
    movhps       [r0 + 1  * 64], xm7
    vextracti128 xm5, m7, 1
    movq         [r0 + 8 * 64], xm5
    movhps       [r0 + 9 * 64], xm5

    movu         m7,  [r1]
    movu         m9,  [r1 + 32]
    movu         m10, [r1 + r2]
    movu         m11, [r1 + r2 + 32]
    movu         m12, [r1 + 2 * r2]
    movu         m13, [r1 + 2 * r2 + 32]
    movu         m14, [r1 + r3]
    movu         m15, [r1 + r3 + 32]

    punpcklwd    m5, m7, m10              ;[1 - 4;  9 - 12][5 6]
    punpckhwd    m7, m10                  ;[5 - 8; 13 - 16][5 6]

    punpcklwd    m10, m12, m14            ;[1 - 4;  9 - 12][7 8]
    punpckhwd    m12, m14                 ;[5 - 8; 13 - 16][7 8]

    punpcklwd    m14, m9, m11             ;[17 - 20; 25 - 28][5 6]
    punpckhwd    m9, m11                  ;[21 - 24; 29 - 32][5 6]

    punpcklwd    m11, m13, m15            ;[17 - 20; 25 - 28][7 8]
    punpckhwd    m13, m15                 ;[21 - 24; 29 - 32][7 8]

    punpckldq    m15, m5, m10             ;[1 - 2;  9 - 10][5 6 7 8]
    punpckhdq    m5, m10                  ;[3 - 4; 11 - 12][5 6 7 8]

    punpckldq    m10, m7, m12             ;[5 - 6; 13 - 14][5 6 7 8]
    punpckhdq    m7, m12                  ;[7 - 8; 15 - 16][5 6 7 8]

    punpckldq    m12, m14, m11            ;[17 - 18; 25 - 26][5 6 7 8]
    punpckhdq    m14, m11                 ;[19 - 20; 27 - 28][5 6 7 8]

    punpckldq    m11, m9, m13             ;[21 - 22; 29 - 30][5 6 7 8]
    punpckhdq    m9, m13                  ;[23 - 24; 31 - 32][5 6 7 8]

    movq         [r0 + 0 * 64 + 8], xm15
    movhps       [r0 + 1 * 64 + 8], xm15
    vextracti128 xm13, m15, 1
    movq         [r0 + 8 * 64 + 8], xm13
    movhps       [r0 + 9 * 64 + 8], xm13

    punpcklqdq   m13, m8, m5              ;[3 ; 11][1 2 3 4 5 6 7 8]
    punpckhqdq   m8, m5                   ;[4 ; 12][1 2 3 4 5 6 7 8]

    punpcklqdq   m5, m2, m10              ;[5 ; 13][1 2 3 4 5 6 7 8]
    punpckhqdq   m2, m10                  ;[6 ; 14][1 2 3 4 5 6 7 8]

    punpcklqdq   m10, m0, m7              ;[7 ; 15][1 2 3 4 5 6 7 8]
    punpckhqdq   m0, m7                   ;[8 ; 16][1 2 3 4 5 6 7 8]

    punpcklqdq   m7, m4, m12              ;[17 ; 25][1 2 3 4 5 6 7 8]
    punpckhqdq   m4, m12                  ;[18 ; 26][1 2 3 4 5 6 7 8]

    punpcklqdq   m12, m6, m14             ;[19 ; 27][1 2 3 4 5 6 7 8]
    punpckhqdq   m6, m14                  ;[20 ; 28][1 2 3 4 5 6 7 8]

    punpcklqdq   m14, m3, m11             ;[21 ; 29][1 2 3 4 5 6 7 8]
    punpckhqdq   m3, m11                  ;[22 ; 30][1 2 3 4 5 6 7 8]

    punpcklqdq   m11, m1, m9              ;[23 ; 31][1 2 3 4 5 6 7 8]
    punpckhqdq   m1, m9                   ;[24 ; 32][1 2 3 4 5 6 7 8]

    movu         [r0 + 2  * 64], xm13
    vextracti128 [r0 + 10 * 64], m13, 1

    movu         [r0 + 3  * 64], xm8
    vextracti128 [r0 + 11 * 64], m8, 1

    movu         [r0 + 4  * 64], xm5
    vextracti128 [r0 + 12 * 64], m5, 1

    movu         [r0 + 5  * 64], xm2
    vextracti128 [r0 + 13 * 64], m2, 1

    movu         [r0 + 6  * 64], xm10
    vextracti128 [r0 + 14 * 64], m10, 1

    movu         [r0 + 7  * 64], xm0
    vextracti128 [r0 + 15 * 64], m0, 1

    movu         [r0 + 16 * 64], xm7
    vextracti128 [r0 + 24 * 64], m7, 1

    movu         [r0 + 17 * 64], xm4
    vextracti128 [r0 + 25 * 64], m4, 1

    movu         [r0 + 18 * 64], xm12
    vextracti128 [r0 + 26 * 64], m12, 1

    movu         [r0 + 19 * 64], xm6
    vextracti128 [r0 + 27 * 64], m6, 1

    movu         [r0 + 20 * 64], xm14
    vextracti128 [r0 + 28 * 64], m14, 1

    movu         [r0 + 21 * 64], xm3
    vextracti128 [r0 + 29 * 64], m3, 1

    movu         [r0 + 22 * 64], xm11
    vextracti128 [r0 + 30 * 64], m11, 1

    movu         [r0 + 23 * 64], xm1
    vextracti128 [r0 + 31 * 64], m1, 1
    ret

cglobal transpose32, 3, 4, 16
    add          r2, r2
    lea          r3, [r2 * 3]
    call         transpose8x32_internal
    add          r0, 16
    lea          r1, [r1 + 4 * r2]
    call         transpose8x32_internal
    add          r0, 16
    lea          r1, [r1 + 4 * r2]
    call         transpose8x32_internal
    add          r0, 16
    lea          r1, [r1 + 4 * r2]
    call         transpose8x32_internal
    RET
%endif
INIT_XMM sse2
cglobal transpose32, 3, 7, 4, dest, src, stride
    add    r2,    r2
    mov    r3,    r0
    mov    r4,    r1
    mov    r5,    64
    mov    r6,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r4 + 16]
    lea    r0,    [r6 + 8 * 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 64 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 64 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 64 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r4 + 32]
    lea    r0,    [r6 + 16 * 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 64 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 64 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 64 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r4 + 48]
    lea    r0,    [r6 + 24 * 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 64 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 64 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 64 + 48]
    mov    r3,    r0
    call   transpose8_internal
    RET
%else ;HIGH_BIT_DEPTH == 0
INIT_XMM sse2
cglobal transpose32, 3, 7, 8, dest, src, stride
    mov    r3,    r0
    mov    r4,    r1
    mov    r5,    r0
    mov    r6,    32
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 16]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r4 + 16]
    lea    r0,    [r3 + 16 * 32]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 16 * 32 + 16]
    mov    r5,    r0
    call   transpose16_internal
    RET

%if ARCH_X86_64 == 1
INIT_YMM avx2
cglobal transpose32, 3, 5, 16
    lea          r3, [r2 * 3]
    mov          r4d, 2

.loop:
    movu         m0, [r1]
    movu         m1, [r1 + r2]
    movu         m2, [r1 + 2 * r2]
    movu         m3, [r1 + r3]
    lea          r1, [r1 + 4 * r2]

    movu         m4, [r1]
    movu         m5, [r1 + r2]
    movu         m6, [r1 + 2 * r2]
    movu         m7, [r1 + r3]

    punpcklbw    m8, m0, m1                 ;[1 - 8 ; 17 - 24][1 2]
    punpckhbw    m0, m1                     ;[9 - 16; 25 - 32][1 2]

    punpcklbw    m1, m2, m3                 ;[1 - 8 ; 17 - 24][3 4]
    punpckhbw    m2, m3                     ;[9 - 16; 25 - 32][3 4]

    punpcklbw    m3, m4, m5                 ;[1 - 8 ; 17 - 24][5 6]
    punpckhbw    m4, m5                     ;[9 - 16; 25 - 32][5 6]

    punpcklbw    m5, m6, m7                 ;[1 - 8 ; 17 - 24][7 8]
    punpckhbw    m6, m7                     ;[9 - 16; 25 - 32][7 8]

    punpcklwd    m7, m8, m1                 ;[1 - 4 ; 17 - 20][1 2 3 4]
    punpckhwd    m8, m1                     ;[5 - 8 ; 20 - 24][1 2 3 4]

    punpcklwd    m1, m3, m5                 ;[1 - 4 ; 17 - 20][5 6 7 8]
    punpckhwd    m3, m5                     ;[5 - 8 ; 20 - 24][5 6 7 8]

    punpcklwd    m5, m0, m2                 ;[9 - 12; 25 - 28][1 2 3 4]
    punpckhwd    m0, m2                     ;[13- 15; 29 - 32][1 2 3 4]

    punpcklwd    m2, m4, m6                 ;[9 - 12; 25 - 28][5 6 7 8]
    punpckhwd    m4, m6                     ;[13- 15; 29 - 32][5 6 7 8]

    punpckldq    m6, m7, m1                 ;[1 - 2 ; 17 - 18][1 2 3 4 5 6 7 8]
    punpckhdq    m7, m1                     ;[3 - 4 ; 19 - 20][1 2 3 4 5 6 7 8]

    punpckldq    m1, m8, m3                 ;[5 - 6 ; 21 - 22][1 2 3 4 5 6 7 8]
    punpckhdq    m8, m3                     ;[7 - 8 ; 23 - 24][1 2 3 4 5 6 7 8]

    punpckldq    m3, m5, m2                 ;[9 - 10; 25 - 26][1 2 3 4 5 6 7 8]
    punpckhdq    m5, m2                     ;[11- 12; 27 - 28][1 2 3 4 5 6 7 8]

    punpckldq    m2, m0, m4                 ;[13- 14; 29 - 30][1 2 3 4 5 6 7 8]
    punpckhdq    m0, m4                     ;[15- 16; 31 - 32][1 2 3 4 5 6 7 8]

    movq         [r0 + 0  * 32], xm6
    movhps       [r0 + 1  * 32], xm6
    vextracti128 xm4, m6, 1
    movq         [r0 + 16 * 32], xm4
    movhps       [r0 + 17 * 32], xm4

    lea          r1,  [r1 + 4 * r2]
    movu         m9,  [r1]
    movu         m10, [r1 + r2]
    movu         m11, [r1 + 2 * r2]
    movu         m12, [r1 + r3]
    lea          r1,  [r1 + 4 * r2]

    movu         m13, [r1]
    movu         m14, [r1 + r2]
    movu         m15, [r1 + 2 * r2]
    movu         m6,  [r1 + r3]

    punpcklbw    m4, m9, m10                ;[1 - 8 ; 17 - 24][9 10]
    punpckhbw    m9, m10                    ;[9 - 16; 25 - 32][9 10]

    punpcklbw    m10, m11, m12              ;[1 - 8 ; 17 - 24][11 12]
    punpckhbw    m11, m12                   ;[9 - 16; 25 - 32][11 12]

    punpcklbw    m12, m13, m14              ;[1 - 8 ; 17 - 24][13 14]
    punpckhbw    m13, m14                   ;[9 - 16; 25 - 32][13 14]

    punpcklbw    m14, m15, m6               ;[1 - 8 ; 17 - 24][15 16]
    punpckhbw    m15, m6                    ;[9 - 16; 25 - 32][15 16]

    punpcklwd    m6, m4, m10                ;[1 - 4 ; 17 - 20][9 10 11 12]
    punpckhwd    m4, m10                    ;[5 - 8 ; 20 - 24][9 10 11 12]

    punpcklwd    m10, m12, m14              ;[1 - 4 ; 17 - 20][13 14 15 16]
    punpckhwd    m12, m14                   ;[5 - 8 ; 20 - 24][13 14 15 16]

    punpcklwd    m14, m9, m11               ;[9 - 12; 25 - 28][9 10 11 12]
    punpckhwd    m9, m11                    ;[13- 16; 29 - 32][9 10 11 12]

    punpcklwd    m11, m13, m15              ;[9 - 12; 25 - 28][13 14 15 16]
    punpckhwd    m13, m15                   ;[13- 16; 29 - 32][13 14 15 16]

    punpckldq    m15, m6, m10               ;[1 - 2 ; 17 - 18][9 10 11 12 13 14 15 16]
    punpckhdq    m6, m10                    ;[3 - 4 ; 19 - 20][9 10 11 12 13 14 15 16]

    punpckldq    m10, m4, m12               ;[5 - 6 ; 21 - 22][9 10 11 12 13 14 15 16]
    punpckhdq    m4, m12                    ;[7 - 8 ; 23 - 24][9 10 11 12 13 14 15 16]

    punpckldq    m12, m14, m11              ;[9 - 10; 25 - 26][9 10 11 12 13 14 15 16]
    punpckhdq    m14, m11                   ;[11- 12; 27 - 28][9 10 11 12 13 14 15 16]

    punpckldq    m11, m9, m13               ;[13- 14; 29 - 30][9 10 11 12 13 14 15 16]
    punpckhdq    m9, m13                    ;[15- 16; 31 - 32][9 10 11 12 13 14 15 16]


    punpcklqdq   m13, m7, m6                ;[3 ; 19][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m7, m6                     ;[4 ; 20][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m6, m1, m10                ;[5 ; 21][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m1, m10                    ;[6 ; 22][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m10, m8, m4                ;[7 ; 23][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m8, m4                     ;[8 ; 24][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m4, m3, m12                ;[9 ; 25][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m3, m12                    ;[10; 26][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m12, m5, m14               ;[11; 27][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m5, m14                    ;[12; 28][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m14, m2, m11               ;[13; 29][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m2, m11                    ;[14; 30][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m11, m0, m9                ;[15; 31][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m0, m9                     ;[16; 32][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    movq         [r0 + 0  * 32 + 8], xm15
    movhps       [r0 + 1  * 32 + 8], xm15
    vextracti128 xm9, m15, 1
    movq         [r0 + 16 * 32 + 8], xm9
    movhps       [r0 + 17 * 32 + 8], xm9

    movu         [r0 + 2  * 32], xm13
    vextracti128 [r0 + 18 * 32], m13, 1

    movu         [r0 + 3  * 32], xm7
    vextracti128 [r0 + 19 * 32], m7, 1

    movu         [r0 + 4  * 32], xm6
    vextracti128 [r0 + 20 * 32], m6, 1

    movu         [r0 + 5  * 32], xm1
    vextracti128 [r0 + 21 * 32], m1, 1

    movu         [r0 + 6  * 32], xm10
    vextracti128 [r0 + 22 * 32], m10, 1

    movu         [r0 + 7  * 32], xm8
    vextracti128 [r0 + 23 * 32], m8, 1

    movu         [r0 + 8  * 32], xm4
    vextracti128 [r0 + 24 * 32], m4, 1

    movu         [r0 + 9  * 32], xm3
    vextracti128 [r0 + 25 * 32], m3, 1

    movu         [r0 + 10 * 32], xm12
    vextracti128 [r0 + 26 * 32], m12, 1

    movu         [r0 + 11 * 32], xm5
    vextracti128 [r0 + 27 * 32], m5, 1

    movu         [r0 + 12 * 32], xm14
    vextracti128 [r0 + 28 * 32], m14, 1

    movu         [r0 + 13 * 32], xm2
    vextracti128 [r0 + 29 * 32], m2, 1

    movu         [r0 + 14 * 32], xm11
    vextracti128 [r0 + 30 * 32], m11, 1

    movu         [r0 + 15 * 32], xm0
    vextracti128 [r0 + 31 * 32], m0, 1

    add          r0, 16
    lea          r1,  [r1 + 4 * r2]
    dec          r4d
    jnz          .loop
    RET
%endif
%endif

;-----------------------------------------------------------------
; void transpose_64x64(pixel *dst, pixel *src, intptr_t stride)
;-----------------------------------------------------------------
%if HIGH_BIT_DEPTH == 1
%if ARCH_X86_64 == 1
INIT_YMM avx2
cglobal transpose8x32_64_internal
    movu         m0, [r1]
    movu         m1, [r1 + 32]
    movu         m2, [r1 + r2]
    movu         m3, [r1 + r2 + 32]
    movu         m4, [r1 + 2 * r2]
    movu         m5, [r1 + 2 * r2 + 32]
    movu         m6, [r1 + r3]
    movu         m7, [r1 + r3 + 32]
    lea          r1, [r1 + 4 * r2]

    punpcklwd    m8, m0, m2               ;[1 - 4;  9 - 12][1 2]
    punpckhwd    m0, m2                   ;[5 - 8; 13 - 16][1 2]

    punpcklwd    m2, m4, m6               ;[1 - 4;  9 - 12][3 4]
    punpckhwd    m4, m6                   ;[5 - 8; 13 - 16][3 4]

    punpcklwd    m6, m1, m3               ;[17 - 20; 25 - 28][1 2]
    punpckhwd    m1, m3                   ;[21 - 24; 29 - 32][1 2]

    punpcklwd    m3, m5, m7               ;[17 - 20; 25 - 28][3 4]
    punpckhwd    m5, m7                   ;[21 - 24; 29 - 32][3 4]

    punpckldq    m7, m8, m2               ;[1 - 2;  9 - 10][1 2 3 4]
    punpckhdq    m8, m2                   ;[3 - 4; 11 - 12][1 2 3 4]

    punpckldq    m2, m0, m4               ;[5 - 6; 13 - 14][1 2 3 4]
    punpckhdq    m0, m4                   ;[7 - 8; 15 - 16][1 2 3 4]

    punpckldq    m4, m6, m3               ;[17 - 18; 25 - 26][1 2 3 4]
    punpckhdq    m6, m3                   ;[19 - 20; 27 - 28][1 2 3 4]

    punpckldq    m3, m1, m5               ;[21 - 22; 29 - 30][1 2 3 4]
    punpckhdq    m1, m5                   ;[23 - 24; 31 - 32][1 2 3 4]

    movq         [r0 + 0  * 128], xm7
    movhps       [r0 + 1  * 128], xm7
    vextracti128 xm5, m7, 1
    movq         [r0 + 8 * 128], xm5
    movhps       [r0 + 9 * 128], xm5

    movu         m7,  [r1]
    movu         m9,  [r1 + 32]
    movu         m10, [r1 + r2]
    movu         m11, [r1 + r2 + 32]
    movu         m12, [r1 + 2 * r2]
    movu         m13, [r1 + 2 * r2 + 32]
    movu         m14, [r1 + r3]
    movu         m15, [r1 + r3 + 32]

    punpcklwd    m5, m7, m10              ;[1 - 4;  9 - 12][5 6]
    punpckhwd    m7, m10                  ;[5 - 8; 13 - 16][5 6]

    punpcklwd    m10, m12, m14            ;[1 - 4;  9 - 12][7 8]
    punpckhwd    m12, m14                 ;[5 - 8; 13 - 16][7 8]

    punpcklwd    m14, m9, m11             ;[17 - 20; 25 - 28][5 6]
    punpckhwd    m9, m11                  ;[21 - 24; 29 - 32][5 6]

    punpcklwd    m11, m13, m15            ;[17 - 20; 25 - 28][7 8]
    punpckhwd    m13, m15                 ;[21 - 24; 29 - 32][7 8]

    punpckldq    m15, m5, m10             ;[1 - 2;  9 - 10][5 6 7 8]
    punpckhdq    m5, m10                  ;[3 - 4; 11 - 12][5 6 7 8]

    punpckldq    m10, m7, m12             ;[5 - 6; 13 - 14][5 6 7 8]
    punpckhdq    m7, m12                  ;[7 - 8; 15 - 16][5 6 7 8]

    punpckldq    m12, m14, m11            ;[17 - 18; 25 - 26][5 6 7 8]
    punpckhdq    m14, m11                 ;[19 - 20; 27 - 28][5 6 7 8]

    punpckldq    m11, m9, m13             ;[21 - 22; 29 - 30][5 6 7 8]
    punpckhdq    m9, m13                  ;[23 - 24; 31 - 32][5 6 7 8]

    movq         [r0 + 0 * 128 + 8], xm15
    movhps       [r0 + 1 * 128 + 8], xm15
    vextracti128 xm13, m15, 1
    movq         [r0 + 8 * 128 + 8], xm13
    movhps       [r0 + 9 * 128 + 8], xm13

    punpcklqdq   m13, m8, m5              ;[3 ; 11][1 2 3 4 5 6 7 8]
    punpckhqdq   m8, m5                   ;[4 ; 12][1 2 3 4 5 6 7 8]

    punpcklqdq   m5, m2, m10              ;[5 ; 13][1 2 3 4 5 6 7 8]
    punpckhqdq   m2, m10                  ;[6 ; 14][1 2 3 4 5 6 7 8]

    punpcklqdq   m10, m0, m7              ;[7 ; 15][1 2 3 4 5 6 7 8]
    punpckhqdq   m0, m7                   ;[8 ; 16][1 2 3 4 5 6 7 8]

    punpcklqdq   m7, m4, m12              ;[17 ; 25][1 2 3 4 5 6 7 8]
    punpckhqdq   m4, m12                  ;[18 ; 26][1 2 3 4 5 6 7 8]

    punpcklqdq   m12, m6, m14             ;[19 ; 27][1 2 3 4 5 6 7 8]
    punpckhqdq   m6, m14                  ;[20 ; 28][1 2 3 4 5 6 7 8]

    punpcklqdq   m14, m3, m11             ;[21 ; 29][1 2 3 4 5 6 7 8]
    punpckhqdq   m3, m11                  ;[22 ; 30][1 2 3 4 5 6 7 8]

    punpcklqdq   m11, m1, m9              ;[23 ; 31][1 2 3 4 5 6 7 8]
    punpckhqdq   m1, m9                   ;[24 ; 32][1 2 3 4 5 6 7 8]

    movu         [r0 + 2  * 128], xm13
    vextracti128 [r0 + 10 * 128], m13, 1

    movu         [r0 + 3  * 128], xm8
    vextracti128 [r0 + 11 * 128], m8, 1

    movu         [r0 + 4  * 128], xm5
    vextracti128 [r0 + 12 * 128], m5, 1

    movu         [r0 + 5  * 128], xm2
    vextracti128 [r0 + 13 * 128], m2, 1

    movu         [r0 + 6  * 128], xm10
    vextracti128 [r0 + 14 * 128], m10, 1

    movu         [r0 + 7  * 128], xm0
    vextracti128 [r0 + 15 * 128], m0, 1

    movu         [r0 + 16 * 128], xm7
    vextracti128 [r0 + 24 * 128], m7, 1

    movu         [r0 + 17 * 128], xm4
    vextracti128 [r0 + 25 * 128], m4, 1

    movu         [r0 + 18 * 128], xm12
    vextracti128 [r0 + 26 * 128], m12, 1

    movu         [r0 + 19 * 128], xm6
    vextracti128 [r0 + 27 * 128], m6, 1

    movu         [r0 + 20 * 128], xm14
    vextracti128 [r0 + 28 * 128], m14, 1

    movu         [r0 + 21 * 128], xm3
    vextracti128 [r0 + 29 * 128], m3, 1

    movu         [r0 + 22 * 128], xm11
    vextracti128 [r0 + 30 * 128], m11, 1

    movu         [r0 + 23 * 128], xm1
    vextracti128 [r0 + 31 * 128], m1, 1
    ret

cglobal transpose64, 3, 6, 16
    add          r2, r2
    lea          r3, [3 * r2]
    lea          r4, [r1 + 64]
    lea          r5, [r0 + 16]

    call         transpose8x32_64_internal
    mov          r1, r4
    lea          r0, [r0 + 32 * 128]
    call         transpose8x32_64_internal
    mov          r0, r5
    lea          r5, [r0 + 16]
    lea          r4, [r1 + 4 * r2]
    lea          r1, [r4 - 64]
    call         transpose8x32_64_internal
    mov          r1, r4
    lea          r0, [r0 + 32 * 128]
    call         transpose8x32_64_internal
    mov          r0, r5
    lea          r5, [r0 + 16]
    lea          r4, [r1 + 4 * r2]
    lea          r1, [r4 - 64]
    call         transpose8x32_64_internal
    mov          r1, r4
    lea          r0, [r0 + 32 * 128]
    call         transpose8x32_64_internal
    mov          r0, r5
    lea          r5, [r0 + 16]
    lea          r4, [r1 + 4 * r2]
    lea          r1, [r4 - 64]
    call         transpose8x32_64_internal
    mov          r1, r4
    lea          r0, [r0 + 32 * 128]
    call         transpose8x32_64_internal
    mov          r0, r5
    lea          r5, [r0 + 16]
    lea          r4, [r1 + 4 * r2]
    lea          r1, [r4 - 64]
    call         transpose8x32_64_internal
    mov          r1, r4
    lea          r0, [r0 + 32 * 128]
    call         transpose8x32_64_internal
    mov          r0, r5
    lea          r5, [r0 + 16]
    lea          r4, [r1 + 4 * r2]
    lea          r1, [r4 - 64]
    call         transpose8x32_64_internal
    mov          r1, r4
    lea          r0, [r0 + 32 * 128]
    call         transpose8x32_64_internal
    mov          r0, r5
    lea          r5, [r0 + 16]
    lea          r4, [r1 + 4 * r2]
    lea          r1, [r4 - 64]
    call         transpose8x32_64_internal
    mov          r1, r4
    lea          r0, [r0 + 32 * 128]
    call         transpose8x32_64_internal
    mov          r0, r5
    lea          r4, [r1 + 4 * r2]
    lea          r1, [r4 - 64]
    call         transpose8x32_64_internal
    mov          r1, r4
    lea          r0, [r0 + 32 * 128]
    call         transpose8x32_64_internal
    RET
%endif
INIT_XMM sse2
cglobal transpose64, 3, 7, 4, dest, src, stride
    add    r2,    r2
    mov    r3,    r0
    mov    r4,    r1
    mov    r5,    128
    mov    r6,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 80]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 96]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 112]
    mov    r3,    r0
    call   transpose8_internal

    lea    r1,    [r4 + 16]
    lea    r0,    [r6 + 8 * 128]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 128 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 128 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 128 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 128 + 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 128 + 80]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 128 + 96]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 8 * 128 + 112]
    mov    r3,    r0
    call   transpose8_internal

    lea    r1,    [r4 + 32]
    lea    r0,    [r6 + 16 * 128]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 128 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 128 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 128 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 128 + 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 128 + 80]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 128 + 96]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 16 * 128 + 112]
    mov    r3,    r0
    call   transpose8_internal

    lea    r1,    [r4 + 48]
    lea    r0,    [r6 + 24 * 128]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 128 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 128 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 128 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 128 + 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 128 + 80]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 128 + 96]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 24 * 128 + 112]
    mov    r3,    r0
    call   transpose8_internal

    lea    r1,    [r4 + 64]
    lea    r0,    [r6 + 32 * 128]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32 * 128 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32 * 128 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32 * 128 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32 * 128 + 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32 * 128 + 80]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32 * 128 + 96]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 32 * 128 + 112]
    mov    r3,    r0
    call   transpose8_internal

    lea    r1,    [r4 + 80]
    lea    r0,    [r6 + 40 * 128]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 40 * 128 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 40 * 128 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 40 * 128 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 40 * 128 + 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 40 * 128 + 80]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 40 * 128 + 96]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 40 * 128 + 112]
    mov    r3,    r0
    call   transpose8_internal

    lea    r1,    [r4 + 96]
    lea    r0,    [r6 + 48 * 128]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48 * 128 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48 * 128 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48 * 128 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48 * 128 + 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48 * 128 + 80]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48 * 128 + 96]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 48 * 128 + 112]
    mov    r3,    r0
    call   transpose8_internal

    lea    r1,    [r4 + 112]
    lea    r0,    [r6 + 56 * 128]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 56 * 128 + 16]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 56 * 128 + 32]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 56 * 128 + 48]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 56 * 128 + 64]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 56 * 128 + 80]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 56 * 128 + 96]
    mov    r3,    r0
    call   transpose8_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r6 + 56 * 128 + 112]
    mov    r3,    r0
    call   transpose8_internal
    RET
%else ;HIGH_BIT_DEPTH == 0
%if ARCH_X86_64 == 1
INIT_YMM avx2

cglobal transpose16x32_avx2
    movu         m0, [r1]
    movu         m1, [r1 + r2]
    movu         m2, [r1 + 2 * r2]
    movu         m3, [r1 + r3]
    lea          r1, [r1 + 4 * r2]

    movu         m4, [r1]
    movu         m5, [r1 + r2]
    movu         m6, [r1 + 2 * r2]
    movu         m7, [r1 + r3]

    punpcklbw    m8, m0, m1                 ;[1 - 8 ; 17 - 24][1 2]
    punpckhbw    m0, m1                     ;[9 - 16; 25 - 32][1 2]

    punpcklbw    m1, m2, m3                 ;[1 - 8 ; 17 - 24][3 4]
    punpckhbw    m2, m3                     ;[9 - 16; 25 - 32][3 4]

    punpcklbw    m3, m4, m5                 ;[1 - 8 ; 17 - 24][5 6]
    punpckhbw    m4, m5                     ;[9 - 16; 25 - 32][5 6]

    punpcklbw    m5, m6, m7                 ;[1 - 8 ; 17 - 24][7 8]
    punpckhbw    m6, m7                     ;[9 - 16; 25 - 32][7 8]

    punpcklwd    m7, m8, m1                 ;[1 - 4 ; 17 - 20][1 2 3 4]
    punpckhwd    m8, m1                     ;[5 - 8 ; 20 - 24][1 2 3 4]

    punpcklwd    m1, m3, m5                 ;[1 - 4 ; 17 - 20][5 6 7 8]
    punpckhwd    m3, m5                     ;[5 - 8 ; 20 - 24][5 6 7 8]

    punpcklwd    m5, m0, m2                 ;[9 - 12; 25 - 28][1 2 3 4]
    punpckhwd    m0, m2                     ;[12- 15; 29 - 32][1 2 3 4]

    punpcklwd    m2, m4, m6                 ;[9 - 12; 25 - 28][5 6 7 8]
    punpckhwd    m4, m6                     ;[12- 15; 29 - 32][5 6 7 8]

    punpckldq    m6, m7, m1                 ;[1 - 2 ; 17 - 18][1 2 3 4 5 6 7 8]
    punpckhdq    m7, m1                     ;[3 - 4 ; 19 - 20][1 2 3 4 5 6 7 8]

    punpckldq    m1, m8, m3                 ;[5 - 6 ; 21 - 22][1 2 3 4 5 6 7 8]
    punpckhdq    m8, m3                     ;[7 - 8 ; 23 - 24][1 2 3 4 5 6 7 8]

    punpckldq    m3, m5, m2                 ;[9 - 10; 25 - 26][1 2 3 4 5 6 7 8]
    punpckhdq    m5, m2                     ;[11- 12; 27 - 28][1 2 3 4 5 6 7 8]

    punpckldq    m2, m0, m4                 ;[13- 14; 29 - 30][1 2 3 4 5 6 7 8]
    punpckhdq    m0, m4                     ;[15- 16; 31 - 32][1 2 3 4 5 6 7 8]

    movq         [r0 + 0  * 64], xm6
    movhps       [r0 + 1  * 64], xm6
    vextracti128 xm4, m6, 1
    movq         [r0 + 16 * 64], xm4
    movhps       [r0 + 17 * 64], xm4

    lea          r1,  [r1 + 4 * r2]
    movu         m9,  [r1]
    movu         m10, [r1 + r2]
    movu         m11, [r1 + 2 * r2]
    movu         m12, [r1 + r3]
    lea          r1,  [r1 + 4 * r2]

    movu         m13, [r1]
    movu         m14, [r1 + r2]
    movu         m15, [r1 + 2 * r2]
    movu         m6,  [r1 + r3]

    punpcklbw    m4, m9, m10                ;[1 - 8 ; 17 - 24][9 10]
    punpckhbw    m9, m10                    ;[9 - 16; 25 - 32][9 10]

    punpcklbw    m10, m11, m12              ;[1 - 8 ; 17 - 24][11 12]
    punpckhbw    m11, m12                   ;[9 - 16; 25 - 32][11 12]

    punpcklbw    m12, m13, m14              ;[1 - 8 ; 17 - 24][13 14]
    punpckhbw    m13, m14                   ;[9 - 16; 25 - 32][13 14]

    punpcklbw    m14, m15, m6               ;[1 - 8 ; 17 - 24][15 16]
    punpckhbw    m15, m6                    ;[9 - 16; 25 - 32][15 16]

    punpcklwd    m6, m4, m10                ;[1 - 4 ; 17 - 20][9 10 11 12]
    punpckhwd    m4, m10                    ;[5 - 8 ; 20 - 24][9 10 11 12]

    punpcklwd    m10, m12, m14              ;[1 - 4 ; 17 - 20][13 14 15 16]
    punpckhwd    m12, m14                   ;[5 - 8 ; 20 - 24][13 14 15 16]

    punpcklwd    m14, m9, m11               ;[9 - 12; 25 - 28][9 10 11 12]
    punpckhwd    m9, m11                    ;[13- 16; 29 - 32][9 10 11 12]

    punpcklwd    m11, m13, m15              ;[9 - 12; 25 - 28][13 14 15 16]
    punpckhwd    m13, m15                   ;[13- 16; 29 - 32][13 14 15 16]

    punpckldq    m15, m6, m10               ;[1 - 2 ; 17 - 18][9 10 11 12 13 14 15 16]
    punpckhdq    m6, m10                    ;[3 - 4 ; 19 - 20][9 10 11 12 13 14 15 16]

    punpckldq    m10, m4, m12               ;[5 - 6 ; 21 - 22][9 10 11 12 13 14 15 16]
    punpckhdq    m4, m12                    ;[7 - 8 ; 23 - 24][9 10 11 12 13 14 15 16]

    punpckldq    m12, m14, m11              ;[9 - 10; 25 - 26][9 10 11 12 13 14 15 16]
    punpckhdq    m14, m11                   ;[11- 12; 27 - 28][9 10 11 12 13 14 15 16]

    punpckldq    m11, m9, m13               ;[13- 14; 29 - 30][9 10 11 12 13 14 15 16]
    punpckhdq    m9, m13                    ;[15- 16; 31 - 32][9 10 11 12 13 14 15 16]


    punpcklqdq   m13, m7, m6                ;[3 ; 19][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m7, m6                     ;[4 ; 20][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m6, m1, m10                ;[5 ; 21][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m1, m10                    ;[6 ; 22][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m10, m8, m4                ;[7 ; 23][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m8, m4                     ;[8 ; 24][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m4, m3, m12                ;[9 ; 25][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m3, m12                    ;[10; 26][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m12, m5, m14               ;[11; 27][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m5, m14                    ;[12; 28][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m14, m2, m11               ;[13; 29][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m2, m11                    ;[14; 30][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    punpcklqdq   m11, m0, m9                ;[15; 31][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]
    punpckhqdq   m0, m9                     ;[16; 32][1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]

    movq         [r0 + 0  * 64 + 8], xm15
    movhps       [r0 + 1  * 64 + 8], xm15
    vextracti128 xm9, m15, 1
    movq         [r0 + 16 * 64 + 8], xm9
    movhps       [r0 + 17 * 64 + 8], xm9

    movu         [r0 + 2  * 64], xm13
    vextracti128 [r0 + 18 * 64], m13, 1

    movu         [r0 + 3  * 64], xm7
    vextracti128 [r0 + 19 * 64], m7, 1

    movu         [r0 + 4  * 64], xm6
    vextracti128 [r0 + 20 * 64], m6, 1

    movu         [r0 + 5  * 64], xm1
    vextracti128 [r0 + 21 * 64], m1, 1

    movu         [r0 + 6  * 64], xm10
    vextracti128 [r0 + 22 * 64], m10, 1

    movu         [r0 + 7  * 64], xm8
    vextracti128 [r0 + 23 * 64], m8, 1

    movu         [r0 + 8  * 64], xm4
    vextracti128 [r0 + 24 * 64], m4, 1

    movu         [r0 + 9  * 64], xm3
    vextracti128 [r0 + 25 * 64], m3, 1

    movu         [r0 + 10 * 64], xm12
    vextracti128 [r0 + 26 * 64], m12, 1

    movu         [r0 + 11 * 64], xm5
    vextracti128 [r0 + 27 * 64], m5, 1

    movu         [r0 + 12 * 64], xm14
    vextracti128 [r0 + 28 * 64], m14, 1

    movu         [r0 + 13 * 64], xm2
    vextracti128 [r0 + 29 * 64], m2, 1

    movu         [r0 + 14 * 64], xm11
    vextracti128 [r0 + 30 * 64], m11, 1

    movu         [r0 + 15 * 64], xm0
    vextracti128 [r0 + 31 * 64], m0, 1
    ret

cglobal transpose64, 3, 6, 16

    lea          r3, [r2 * 3]
    lea          r4, [r0 + 16]

    lea          r5, [r1 + 32]
    call         transpose16x32_avx2
    lea          r0, [r0 + 32 * 64]
    mov          r1, r5
    call         transpose16x32_avx2

    mov          r0, r4
    lea          r5, [r1 + 4 * r2]

    lea          r1, [r5 - 32]
    call         transpose16x32_avx2
    lea          r0, [r0 + 32 * 64]
    mov          r1, r5
    call         transpose16x32_avx2

    lea          r0, [r4 + 16]
    lea          r5, [r1 + 4 * r2]

    lea          r1, [r5 - 32]
    call         transpose16x32_avx2
    lea          r0, [r0 + 32 * 64]
    mov          r1, r5
    call         transpose16x32_avx2

    lea          r5, [r1 + 4 * r2]
    lea          r0, [r4 + 32]

    lea          r1, [r5 - 32]
    call         transpose16x32_avx2
    lea          r0, [r0 + 32 * 64]
    mov          r1, r5
    call         transpose16x32_avx2
    RET
%endif

INIT_XMM sse2
cglobal transpose64, 3, 7, 8, dest, src, stride
    mov    r3,    r0
    mov    r4,    r1
    mov    r5,    r0
    mov    r6,    64
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 16]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 32]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 48]
    mov    r5,    r0
    call   transpose16_internal

    lea    r1,    [r4 + 16]
    lea    r0,    [r3 + 16 * 64]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 16 * 64 + 16]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 16 * 64 + 32]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 16 * 64 + 48]
    mov    r5,    r0
    call   transpose16_internal

    lea    r1,    [r4 + 32]
    lea    r0,    [r3 + 32 * 64]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 32 * 64 + 16]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 32 * 64 + 32]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 32 * 64 + 48]
    mov    r5,    r0
    call   transpose16_internal

    lea    r1,    [r4 + 48]
    lea    r0,    [r3 + 48 * 64]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 48 * 64 + 16]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 48 * 64 + 32]
    mov    r5,    r0
    call   transpose16_internal
    lea    r1,    [r1 - 8 + 2 * r2]
    lea    r0,    [r3 + 48 * 64 + 48]
    mov    r5,    r0
    call   transpose16_internal
    RET
%endif


;=============================================================================
; SSIM
;=============================================================================

;-----------------------------------------------------------------------------
; void pixel_ssim_4x4x2_core( const uint8_t *pix1, intptr_t stride1,
;                             const uint8_t *pix2, intptr_t stride2, int sums[2][4] )
;-----------------------------------------------------------------------------
%macro SSIM_ITER 1
%if HIGH_BIT_DEPTH
    movdqu    m5, [r0+(%1&1)*r1]
    movdqu    m6, [r2+(%1&1)*r3]
%else
    movq      m5, [r0+(%1&1)*r1]
    movq      m6, [r2+(%1&1)*r3]
    punpcklbw m5, m0
    punpcklbw m6, m0
%endif
%if %1==1
    lea       r0, [r0+r1*2]
    lea       r2, [r2+r3*2]
%endif
%if %1==0
    movdqa    m1, m5
    movdqa    m2, m6
%else
    paddw     m1, m5
    paddw     m2, m6
%endif
    pmaddwd   m7, m5, m6
    pmaddwd   m5, m5
    pmaddwd   m6, m6
    ACCUM  paddd, 3, 5, %1
    ACCUM  paddd, 4, 7, %1
    paddd     m3, m6
%endmacro

%macro SSIM 0
cglobal pixel_ssim_4x4x2_core, 4,4,8
    FIX_STRIDES r1, r3
    pxor      m0, m0
    SSIM_ITER 0
    SSIM_ITER 1
    SSIM_ITER 2
    SSIM_ITER 3
    ; PHADDW m1, m2
    ; PHADDD m3, m4
    movdqa    m7, [pw_1]
    pshufd    m5, m3, q2301
    pmaddwd   m1, m7
    pmaddwd   m2, m7
    pshufd    m6, m4, q2301
    packssdw  m1, m2
    paddd     m3, m5
    pshufd    m1, m1, q3120
    paddd     m4, m6
    pmaddwd   m1, m7
    punpckhdq m5, m3, m4
    punpckldq m3, m4

%if UNIX64
    %define t0 r4
%else
    %define t0 rax
    mov t0, r4mp
%endif

    movq      [t0+ 0], m1
    movq      [t0+ 8], m3
    movhps    [t0+16], m1
    movq      [t0+24], m5
    RET

;-----------------------------------------------------------------------------
; float pixel_ssim_end( int sum0[5][4], int sum1[5][4], int width )
;-----------------------------------------------------------------------------
cglobal pixel_ssim_end4, 2,3
    mov       r2d, r2m
    mova      m0, [r0+ 0]
    mova      m1, [r0+16]
    mova      m2, [r0+32]
    mova      m3, [r0+48]
    mova      m4, [r0+64]
    paddd     m0, [r1+ 0]
    paddd     m1, [r1+16]
    paddd     m2, [r1+32]
    paddd     m3, [r1+48]
    paddd     m4, [r1+64]
    paddd     m0, m1
    paddd     m1, m2
    paddd     m2, m3
    paddd     m3, m4
    TRANSPOSE4x4D  0, 1, 2, 3, 4

;   s1=m0, s2=m1, ss=m2, s12=m3
%if BIT_DEPTH == 10
    cvtdq2ps  m0, m0
    cvtdq2ps  m1, m1
    cvtdq2ps  m2, m2
    cvtdq2ps  m3, m3
    mulps     m4, m0, m1  ; s1*s2
    mulps     m0, m0      ; s1*s1
    mulps     m1, m1      ; s2*s2
    mulps     m2, [pf_64] ; ss*64
    mulps     m3, [pf_128] ; s12*128
    addps     m4, m4      ; s1*s2*2
    addps     m0, m1      ; s1*s1 + s2*s2
    subps     m2, m0      ; vars
    subps     m3, m4      ; covar*2
    movaps    m1, [ssim_c1]
    addps     m4, m1      ; s1*s2*2 + ssim_c1
    addps     m0, m1      ; s1*s1 + s2*s2 + ssim_c1
    movaps    m1, [ssim_c2]
    addps     m2, m1      ; vars + ssim_c2
    addps     m3, m1      ; covar*2 + ssim_c2
%else
    pmaddwd   m4, m1, m0  ; s1*s2
    pslld     m1, 16
    por       m0, m1
    pmaddwd   m0, m0  ; s1*s1 + s2*s2
    pslld     m4, 1
    pslld     m3, 7
    pslld     m2, 6
    psubd     m3, m4  ; covar*2
    psubd     m2, m0  ; vars
    mova      m1, [ssim_c1]
    paddd     m0, m1
    paddd     m4, m1
    mova      m1, [ssim_c2]
    paddd     m3, m1
    paddd     m2, m1
    cvtdq2ps  m0, m0  ; (float)(s1*s1 + s2*s2 + ssim_c1)
    cvtdq2ps  m4, m4  ; (float)(s1*s2*2 + ssim_c1)
    cvtdq2ps  m3, m3  ; (float)(covar*2 + ssim_c2)
    cvtdq2ps  m2, m2  ; (float)(vars + ssim_c2)
%endif
    mulps     m4, m3
    mulps     m0, m2
    divps     m4, m0  ; ssim

    cmp       r2d, 4
    je .skip ; faster only if this is the common case; remove branch if we use ssim on a macroblock level
    neg       r2

%ifdef PIC
    lea       r3, [mask_ff + 16]
    %xdefine %%mask r3
%else
    %xdefine %%mask mask_ff + 16
%endif
%if cpuflag(avx)
    andps     m4, [%%mask + r2*4]
%else
    movups    m0, [%%mask + r2*4]
    andps     m4, m0
%endif

.skip:
    movhlps   m0, m4
    addps     m0, m4
%if cpuflag(ssse3)
    movshdup  m4, m0
%else
     pshuflw   m4, m0, q0032
%endif
    addss     m0, m4
%if ARCH_X86_64 == 0
    movss    r0m, m0
    fld     dword r0m
%endif
    RET
%endmacro ; SSIM

INIT_XMM sse2
SSIM
INIT_XMM avx
SSIM

%macro SCALE1D_128to64_HBD 0
    movu        m0,      [r1]
    palignr     m1,      m0,    2
    movu        m2,      [r1 + 16]
    palignr     m3,      m2,    2
    movu        m4,      [r1 + 32]
    palignr     m5,      m4,    2
    movu        m6,      [r1 + 48]
    pavgw       m0,      m1
    palignr     m1,      m6,    2
    pavgw       m2,      m3
    pavgw       m4,      m5
    pavgw       m6,      m1
    pshufb      m0,      m0,    m7
    pshufb      m2,      m2,    m7
    pshufb      m4,      m4,    m7
    pshufb      m6,      m6,    m7
    punpcklqdq    m0,           m2
    movu          [r0],         m0
    punpcklqdq    m4,           m6
    movu          [r0 + 16],    m4

    movu        m0,      [r1 + 64]
    palignr     m1,      m0,    2
    movu        m2,      [r1 + 80]
    palignr     m3,      m2,    2
    movu        m4,      [r1 + 96]
    palignr     m5,      m4,    2
    movu        m6,      [r1 + 112]
    pavgw       m0,      m1
    palignr     m1,      m6,    2
    pavgw       m2,      m3
    pavgw       m4,      m5
    pavgw       m6,      m1
    pshufb      m0,      m0,    m7
    pshufb      m2,      m2,    m7
    pshufb      m4,      m4,    m7
    pshufb      m6,      m6,    m7
    punpcklqdq    m0,           m2
    movu          [r0 + 32],    m0
    punpcklqdq    m4,           m6
    movu          [r0 + 48],    m4

    movu        m0,      [r1 + 128]
    palignr     m1,      m0,    2
    movu        m2,      [r1 + 144]
    palignr     m3,      m2,    2
    movu        m4,      [r1 + 160]
    palignr     m5,      m4,    2
    movu        m6,      [r1 + 176]
    pavgw       m0,      m1
    palignr     m1,      m6,    2
    pavgw       m2,      m3
    pavgw       m4,      m5
    pavgw       m6,      m1
    pshufb      m0,      m0,    m7
    pshufb      m2,      m2,    m7
    pshufb      m4,      m4,    m7
    pshufb      m6,      m6,    m7

    punpcklqdq    m0,           m2
    movu          [r0 + 64],    m0
    punpcklqdq    m4,           m6
    movu          [r0 + 80],    m4

    movu        m0,      [r1 + 192]
    palignr     m1,      m0,    2
    movu        m2,      [r1 + 208]
    palignr     m3,      m2,    2
    movu        m4,      [r1 + 224]
    palignr     m5,      m4,    2
    movu        m6,      [r1 + 240]
    pavgw       m0,      m1
    palignr     m1,      m6,    2
    pavgw       m2,      m3
    pavgw       m4,      m5
    pavgw       m6,      m1
    pshufb      m0,      m0,    m7
    pshufb      m2,      m2,    m7
    pshufb      m4,      m4,    m7
    pshufb      m6,      m6,    m7

    punpcklqdq    m0,           m2
    movu          [r0 + 96],    m0
    punpcklqdq    m4,           m6
    movu          [r0 + 112],    m4
%endmacro

;-----------------------------------------------------------------
; void scale1D_128to64(pixel *dst, pixel *src, intptr_t /*stride*/)
;-----------------------------------------------------------------
INIT_XMM ssse3
cglobal scale1D_128to64, 2, 2, 8, dest, src1, stride
%if HIGH_BIT_DEPTH
    mova        m7,      [deinterleave_word_shuf]

    ;Top pixel
    SCALE1D_128to64_HBD

    ;Left pixel
    add         r1,      256
    add         r0,      128
    SCALE1D_128to64_HBD

%else
    mova        m7,      [deinterleave_shuf]

    ;Top pixel
    movu        m0,      [r1]
    palignr     m1,      m0,    1
    movu        m2,      [r1 + 16]
    palignr     m3,      m2,    1
    movu        m4,      [r1 + 32]
    palignr     m5,      m4,    1
    movu        m6,      [r1 + 48]

    pavgb       m0,      m1

    palignr     m1,      m6,    1

    pavgb       m2,      m3
    pavgb       m4,      m5
    pavgb       m6,      m1

    pshufb      m0,      m0,    m7
    pshufb      m2,      m2,    m7
    pshufb      m4,      m4,    m7
    pshufb      m6,      m6,    m7

    punpcklqdq    m0,           m2
    movu          [r0],         m0
    punpcklqdq    m4,           m6
    movu          [r0 + 16],    m4

    movu        m0,      [r1 + 64]
    palignr     m1,      m0,    1
    movu        m2,      [r1 + 80]
    palignr     m3,      m2,    1
    movu        m4,      [r1 + 96]
    palignr     m5,      m4,    1
    movu        m6,      [r1 + 112]

    pavgb       m0,      m1

    palignr     m1,      m6,    1

    pavgb       m2,      m3
    pavgb       m4,      m5
    pavgb       m6,      m1

    pshufb      m0,      m0,    m7
    pshufb      m2,      m2,    m7
    pshufb      m4,      m4,    m7
    pshufb      m6,      m6,    m7

    punpcklqdq    m0,           m2
    movu          [r0 + 32],    m0
    punpcklqdq    m4,           m6
    movu          [r0 + 48],    m4

    ;Left pixel
    movu        m0,      [r1 + 128]
    palignr     m1,      m0,    1
    movu        m2,      [r1 + 144]
    palignr     m3,      m2,    1
    movu        m4,      [r1 + 160]
    palignr     m5,      m4,    1
    movu        m6,      [r1 + 176]

    pavgb       m0,      m1

    palignr     m1,      m6,    1

    pavgb       m2,      m3
    pavgb       m4,      m5
    pavgb       m6,      m1

    pshufb      m0,      m0,    m7
    pshufb      m2,      m2,    m7
    pshufb      m4,      m4,    m7
    pshufb      m6,      m6,    m7

    punpcklqdq    m0,           m2
    movu          [r0 + 64],    m0
    punpcklqdq    m4,           m6
    movu          [r0 + 80],    m4

    movu        m0,      [r1 + 192]
    palignr     m1,      m0,    1
    movu        m2,      [r1 + 208]
    palignr     m3,      m2,    1
    movu        m4,      [r1 + 224]
    palignr     m5,      m4,    1
    movu        m6,      [r1 + 240]

    pavgb       m0,      m1

    palignr     m1,      m6,    1

    pavgb       m2,      m3
    pavgb       m4,      m5
    pavgb       m6,      m1

    pshufb      m0,      m0,    m7
    pshufb      m2,      m2,    m7
    pshufb      m4,      m4,    m7
    pshufb      m6,      m6,    m7

    punpcklqdq    m0,           m2
    movu          [r0 + 96],    m0
    punpcklqdq    m4,           m6
    movu          [r0 + 112],   m4
%endif
RET

%if HIGH_BIT_DEPTH == 1
INIT_YMM avx2
cglobal scale1D_128to64, 2, 2, 3
    pxor            m2, m2

    ;Top pixel
    movu            m0, [r1]
    movu            m1, [r1 + 32]
    phaddw          m0, m1
    pavgw           m0, m2
    vpermq          m0, m0, 0xD8
    movu            [r0], m0

    movu            m0, [r1 + 64]
    movu            m1, [r1 + 96]
    phaddw          m0, m1
    pavgw           m0, m2
    vpermq          m0, m0, 0xD8
    movu            [r0 + 32], m0

    movu            m0, [r1 + 128]
    movu            m1, [r1 + 160]
    phaddw          m0, m1
    pavgw           m0, m2
    vpermq          m0, m0, 0xD8
    movu            [r0 + 64], m0

    movu            m0, [r1 + 192]
    movu            m1, [r1 + 224]
    phaddw          m0, m1
    pavgw           m0, m2
    vpermq          m0, m0, 0xD8
    movu            [r0 + 96], m0

    ;Left pixel
    movu            m0, [r1 + 256]
    movu            m1, [r1 + 288]
    phaddw          m0, m1
    pavgw           m0, m2
    vpermq          m0, m0, 0xD8
    movu            [r0 + 128], m0

    movu            m0, [r1 + 320]
    movu            m1, [r1 + 352]
    phaddw          m0, m1
    pavgw           m0, m2
    vpermq          m0, m0, 0xD8
    movu            [r0 + 160], m0

    movu            m0, [r1 + 384]
    movu            m1, [r1 + 416]
    phaddw          m0, m1
    pavgw           m0, m2
    vpermq          m0, m0, 0xD8
    movu            [r0 + 192], m0

    movu            m0, [r1 + 448]
    movu            m1, [r1 + 480]
    phaddw          m0, m1
    pavgw           m0, m2
    vpermq          m0, m0, 0xD8
    movu            [r0 + 224], m0

    RET
%else ; HIGH_BIT_DEPTH == 0
INIT_YMM avx2
cglobal scale1D_128to64, 2, 2, 4
    pxor            m2, m2
    mova            m3, [pb_1]

    ;Top pixel
    movu            m0, [r1]
    pmaddubsw       m0, m0, m3
    pavgw           m0, m2
    movu            m1, [r1 + 32]
    pmaddubsw       m1, m1, m3
    pavgw           m1, m2
    packuswb        m0, m1
    vpermq          m0, m0, 0xD8
    movu            [r0], m0

    movu            m0, [r1 + 64]
    pmaddubsw       m0, m0, m3
    pavgw           m0, m2
    movu            m1, [r1 + 96]
    pmaddubsw       m1, m1, m3
    pavgw           m1, m2
    packuswb        m0, m1
    vpermq          m0, m0, 0xD8
    movu            [r0 + 32], m0

    ;Left pixel
    movu            m0, [r1 + 128]
    pmaddubsw       m0, m0, m3
    pavgw           m0, m2
    movu            m1, [r1 + 160]
    pmaddubsw       m1, m1, m3
    pavgw           m1, m2
    packuswb        m0, m1
    vpermq          m0, m0, 0xD8
    movu            [r0 + 64], m0

    movu            m0, [r1 + 192]
    pmaddubsw       m0, m0, m3
    pavgw           m0, m2
    movu            m1, [r1 + 224]
    pmaddubsw       m1, m1, m3
    pavgw           m1, m2
    packuswb        m0, m1
    vpermq          m0, m0, 0xD8
    movu            [r0 + 96], m0
    RET
%endif

;-----------------------------------------------------------------
; void scale2D_64to32(pixel *dst, pixel *src, intptr_t stride)
;-----------------------------------------------------------------
%if HIGH_BIT_DEPTH
INIT_XMM ssse3
cglobal scale2D_64to32, 3, 4, 8, dest, src, stride
    mov       r3d,    32
    mova      m7,    [deinterleave_word_shuf]
    add       r2,    r2
.loop:
    movu      m0,    [r1]                  ;i
    psrld     m1,    m0,    16             ;j
    movu      m2,    [r1 + r2]             ;k
    psrld     m3,    m2,    16             ;l
    movu      m4,    m0
    movu      m5,    m2
    pxor      m4,    m1                    ;i^j
    pxor      m5,    m3                    ;k^l
    por       m4,    m5                    ;ij|kl
    pavgw     m0,    m1                    ;s
    pavgw     m2,    m3                    ;t
    movu      m5,    m0
    pavgw     m0,    m2                    ;(s+t+1)/2
    pxor      m5,    m2                    ;s^t
    pand      m4,    m5                    ;(ij|kl)&st
    pand      m4,    [hmulw_16p]
    psubw     m0,    m4                    ;Result
    movu      m1,    [r1 + 16]             ;i
    psrld     m2,    m1,    16             ;j
    movu      m3,    [r1 + r2 + 16]        ;k
    psrld     m4,    m3,    16             ;l
    movu      m5,    m1
    movu      m6,    m3
    pxor      m5,    m2                    ;i^j
    pxor      m6,    m4                    ;k^l
    por       m5,    m6                    ;ij|kl
    pavgw     m1,    m2                    ;s
    pavgw     m3,    m4                    ;t
    movu      m6,    m1
    pavgw     m1,    m3                    ;(s+t+1)/2
    pxor      m6,    m3                    ;s^t
    pand      m5,    m6                    ;(ij|kl)&st
    pand      m5,    [hmulw_16p]
    psubw     m1,    m5                    ;Result
    pshufb    m0,    m7
    pshufb    m1,    m7

    punpcklqdq    m0,       m1
    movu          [r0],     m0

    movu      m0,    [r1 + 32]             ;i
    psrld     m1,    m0,    16             ;j
    movu      m2,    [r1 + r2 + 32]        ;k
    psrld     m3,    m2,    16             ;l
    movu      m4,    m0
    movu      m5,    m2
    pxor      m4,    m1                    ;i^j
    pxor      m5,    m3                    ;k^l
    por       m4,    m5                    ;ij|kl
    pavgw     m0,    m1                    ;s
    pavgw     m2,    m3                    ;t
    movu      m5,    m0
    pavgw     m0,    m2                    ;(s+t+1)/2
    pxor      m5,    m2                    ;s^t
    pand      m4,    m5                    ;(ij|kl)&st
    pand      m4,    [hmulw_16p]
    psubw     m0,    m4                    ;Result
    movu      m1,    [r1 + 48]             ;i
    psrld     m2,    m1,    16             ;j
    movu      m3,    [r1 + r2 + 48]        ;k
    psrld     m4,    m3,    16             ;l
    movu      m5,    m1
    movu      m6,    m3
    pxor      m5,    m2                    ;i^j
    pxor      m6,    m4                    ;k^l
    por       m5,    m6                    ;ij|kl
    pavgw     m1,    m2                    ;s
    pavgw     m3,    m4                    ;t
    movu      m6,    m1
    pavgw     m1,    m3                    ;(s+t+1)/2
    pxor      m6,    m3                    ;s^t
    pand      m5,    m6                    ;(ij|kl)&st
    pand      m5,    [hmulw_16p]
    psubw     m1,    m5                    ;Result
    pshufb    m0,    m7
    pshufb    m1,    m7

    punpcklqdq    m0,           m1
    movu          [r0 + 16],    m0

    movu      m0,    [r1 + 64]             ;i
    psrld     m1,    m0,    16             ;j
    movu      m2,    [r1 + r2 + 64]        ;k
    psrld     m3,    m2,    16             ;l
    movu      m4,    m0
    movu      m5,    m2
    pxor      m4,    m1                    ;i^j
    pxor      m5,    m3                    ;k^l
    por       m4,    m5                    ;ij|kl
    pavgw     m0,    m1                    ;s
    pavgw     m2,    m3                    ;t
    movu      m5,    m0
    pavgw     m0,    m2                    ;(s+t+1)/2
    pxor      m5,    m2                    ;s^t
    pand      m4,    m5                    ;(ij|kl)&st
    pand      m4,    [hmulw_16p]
    psubw     m0,    m4                    ;Result
    movu      m1,    [r1 + 80]             ;i
    psrld     m2,    m1,    16             ;j
    movu      m3,    [r1 + r2 + 80]        ;k
    psrld     m4,    m3,    16             ;l
    movu      m5,    m1
    movu      m6,    m3
    pxor      m5,    m2                    ;i^j
    pxor      m6,    m4                    ;k^l
    por       m5,    m6                    ;ij|kl
    pavgw     m1,    m2                    ;s
    pavgw     m3,    m4                    ;t
    movu      m6,    m1
    pavgw     m1,    m3                    ;(s+t+1)/2
    pxor      m6,    m3                    ;s^t
    pand      m5,    m6                    ;(ij|kl)&st
    pand      m5,    [hmulw_16p]
    psubw     m1,    m5                    ;Result
    pshufb    m0,    m7
    pshufb    m1,    m7

    punpcklqdq    m0,           m1
    movu          [r0 + 32],    m0

    movu      m0,    [r1 + 96]             ;i
    psrld     m1,    m0,    16             ;j
    movu      m2,    [r1 + r2 + 96]        ;k
    psrld     m3,    m2,    16             ;l
    movu      m4,    m0
    movu      m5,    m2
    pxor      m4,    m1                    ;i^j
    pxor      m5,    m3                    ;k^l
    por       m4,    m5                    ;ij|kl
    pavgw     m0,    m1                    ;s
    pavgw     m2,    m3                    ;t
    movu      m5,    m0
    pavgw     m0,    m2                    ;(s+t+1)/2
    pxor      m5,    m2                    ;s^t
    pand      m4,    m5                    ;(ij|kl)&st
    pand      m4,    [hmulw_16p]
    psubw     m0,    m4                    ;Result
    movu      m1,    [r1 + 112]            ;i
    psrld     m2,    m1,    16             ;j
    movu      m3,    [r1 + r2 + 112]       ;k
    psrld     m4,    m3,    16             ;l
    movu      m5,    m1
    movu      m6,    m3
    pxor      m5,    m2                    ;i^j
    pxor      m6,    m4                    ;k^l
    por       m5,    m6                    ;ij|kl
    pavgw     m1,    m2                    ;s
    pavgw     m3,    m4                    ;t
    movu      m6,    m1
    pavgw     m1,    m3                    ;(s+t+1)/2
    pxor      m6,    m3                    ;s^t
    pand      m5,    m6                    ;(ij|kl)&st
    pand      m5,    [hmulw_16p]
    psubw     m1,    m5                    ;Result
    pshufb    m0,    m7
    pshufb    m1,    m7

    punpcklqdq    m0,           m1
    movu          [r0 + 48],    m0
    lea    r0,    [r0 + 64]
    lea    r1,    [r1 + 2 * r2]
    dec    r3d
    jnz    .loop
    RET
%else

INIT_XMM ssse3
cglobal scale2D_64to32, 3, 4, 8, dest, src, stride
    mov       r3d,    32
    mova        m7,      [deinterleave_shuf]
.loop:

    movu        m0,      [r1]                  ;i
    psrlw       m1,      m0,    8              ;j
    movu        m2,      [r1 + r2]             ;k
    psrlw       m3,      m2,    8              ;l
    movu        m4,      m0
    movu        m5,      m2

    pxor        m4,      m1                    ;i^j
    pxor        m5,      m3                    ;k^l
    por         m4,      m5                    ;ij|kl

    pavgb       m0,      m1                    ;s
    pavgb       m2,      m3                    ;t
    movu        m5,      m0
    pavgb       m0,      m2                    ;(s+t+1)/2
    pxor        m5,      m2                    ;s^t
    pand        m4,      m5                    ;(ij|kl)&st
    pand        m4,      [hmul_16p]
    psubb       m0,      m4                    ;Result

    movu        m1,      [r1 + 16]             ;i
    psrlw       m2,      m1,    8              ;j
    movu        m3,      [r1 + r2 + 16]        ;k
    psrlw       m4,      m3,    8              ;l
    movu        m5,      m1
    movu        m6,      m3

    pxor        m5,      m2                    ;i^j
    pxor        m6,      m4                    ;k^l
    por         m5,      m6                    ;ij|kl

    pavgb       m1,      m2                    ;s
    pavgb       m3,      m4                    ;t
    movu        m6,      m1
    pavgb       m1,      m3                    ;(s+t+1)/2
    pxor        m6,      m3                    ;s^t
    pand        m5,      m6                    ;(ij|kl)&st
    pand        m5,      [hmul_16p]
    psubb       m1,      m5                    ;Result

    pshufb      m0,      m0,    m7
    pshufb      m1,      m1,    m7

    punpcklqdq    m0,           m1
    movu          [r0],         m0

    movu        m0,      [r1 + 32]             ;i
    psrlw       m1,      m0,    8              ;j
    movu        m2,      [r1 + r2 + 32]        ;k
    psrlw       m3,      m2,    8              ;l
    movu        m4,      m0
    movu        m5,      m2

    pxor        m4,      m1                    ;i^j
    pxor        m5,      m3                    ;k^l
    por         m4,      m5                    ;ij|kl

    pavgb       m0,      m1                    ;s
    pavgb       m2,      m3                    ;t
    movu        m5,      m0
    pavgb       m0,      m2                    ;(s+t+1)/2
    pxor        m5,      m2                    ;s^t
    pand        m4,      m5                    ;(ij|kl)&st
    pand        m4,      [hmul_16p]
    psubb       m0,      m4                    ;Result

    movu        m1,      [r1 + 48]             ;i
    psrlw       m2,      m1,    8              ;j
    movu        m3,      [r1 + r2 + 48]        ;k
    psrlw       m4,      m3,    8              ;l
    movu        m5,      m1
    movu        m6,      m3

    pxor        m5,      m2                    ;i^j
    pxor        m6,      m4                    ;k^l
    por         m5,      m6                    ;ij|kl

    pavgb       m1,      m2                    ;s
    pavgb       m3,      m4                    ;t
    movu        m6,      m1
    pavgb       m1,      m3                    ;(s+t+1)/2
    pxor        m6,      m3                    ;s^t
    pand        m5,      m6                    ;(ij|kl)&st
    pand        m5,      [hmul_16p]
    psubb       m1,      m5                    ;Result

    pshufb      m0,      m0,    m7
    pshufb      m1,      m1,    m7

    punpcklqdq    m0,           m1
    movu          [r0 + 16],    m0

    lea    r0,    [r0 + 32]
    lea    r1,    [r1 + 2 * r2]
    dec    r3d
    jnz    .loop
    RET
%endif

INIT_YMM avx2
cglobal scale2D_64to32, 3, 5, 8, dest, src, stride
    mov         r3d,     16
    mova        m7,      [deinterleave_shuf]
.loop:
    movu        m0,      [r1]                  ; i
    lea         r4,      [r1 + r2 * 2]
    psrlw       m1,      m0, 8                 ; j
    movu        m2,      [r1 + r2]             ; k
    psrlw       m3,      m2, 8                 ; l

    pxor        m4,      m0, m1                ; i^j
    pxor        m5,      m2, m3                ; k^l
    por         m4,      m5                    ; ij|kl

    pavgb       m0,      m1                    ; s
    pavgb       m2,      m3                    ; t
    mova        m5,      m0
    pavgb       m0,      m2                    ; (s+t+1)/2
    pxor        m5,      m2                    ; s^t
    pand        m4,      m5                    ; (ij|kl)&st
    pand        m4,      [pb_1]
    psubb       m0,      m4                    ; Result

    movu        m1,      [r1 + 32]             ; i
    psrlw       m2,      m1, 8                 ; j
    movu        m3,      [r1 + r2 + 32]        ; k
    psrlw       m4,      m3, 8                 ; l

    pxor        m5,      m1, m2                ; i^j
    pxor        m6,      m3, m4                ; k^l
    por         m5,      m6                    ; ij|kl

    pavgb       m1,      m2                    ; s
    pavgb       m3,      m4                    ; t
    mova        m6,      m1
    pavgb       m1,      m3                    ; (s+t+1)/2
    pxor        m6,      m3                    ; s^t
    pand        m5,      m6                    ; (ij|kl)&st
    pand        m5,      [pb_1]
    psubb       m1,      m5                    ; Result

    pshufb      m0,      m0, m7
    pshufb      m1,      m1, m7

    punpcklqdq  m0,      m1
    vpermq      m0,      m0, 11011000b
    movu        [r0],    m0

    add         r0,      32

    movu        m0,      [r4]                  ; i
    psrlw       m1,      m0, 8                 ; j
    movu        m2,      [r4 + r2]             ; k
    psrlw       m3,      m2, 8                 ; l

    pxor        m4,      m0, m1                ; i^j
    pxor        m5,      m2, m3                ; k^l
    por         m4,      m5                    ; ij|kl

    pavgb       m0,      m1                    ; s
    pavgb       m2,      m3                    ; t
    mova        m5,      m0
    pavgb       m0,      m2                    ; (s+t+1)/2
    pxor        m5,      m2                    ; s^t
    pand        m4,      m5                    ; (ij|kl)&st
    pand        m4,      [pb_1]
    psubb       m0,      m4                    ; Result

    movu        m1,      [r4 + 32]             ; i
    psrlw       m2,      m1, 8                 ; j
    movu        m3,      [r4 + r2 + 32]        ; k
    psrlw       m4,      m3, 8                 ; l

    pxor        m5,      m1, m2                ; i^j
    pxor        m6,      m3, m4                ; k^l
    por         m5,      m6                    ; ij|kl

    pavgb       m1,      m2                    ; s
    pavgb       m3,      m4                    ; t
    mova        m6,      m1
    pavgb       m1,      m3                    ; (s+t+1)/2
    pxor        m6,      m3                    ; s^t
    pand        m5,      m6                    ; (ij|kl)&st
    pand        m5,      [pb_1]
    psubb       m1,      m5                    ; Result

    pshufb      m0,      m0, m7
    pshufb      m1,      m1, m7

    punpcklqdq  m0,      m1
    vpermq      m0,      m0, 11011000b
    movu        [r0],    m0

    lea         r1,      [r1 + 4 * r2]
    add         r0,      32
    dec         r3d
    jnz         .loop
    RET

;-----------------------------------------------------------------------------
; void pixel_sub_ps_4x4(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH
INIT_XMM sse2
cglobal pixel_sub_ps_4x4, 6, 6, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    add     r4,     r4
    add     r5,     r5
    add     r1,     r1
    movh    m0,     [r2]
    movh    m2,     [r2 + r4]
    movh    m1,     [r3]
    movh    m3,     [r3 + r5]
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]
    movh    m4,     [r2]
    movh    m6,     [r2 + r4]
    movh    m5,     [r3]
    movh    m7,     [r3 + r5]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movh    [r0],       m0
    movh    [r0 + r1],  m2
    lea     r0,     [r0 + r1 * 2]
    movh    [r0],       m4
    movh    [r0 + r1],  m6

    RET
%else
INIT_XMM sse4
cglobal pixel_sub_ps_4x4, 6, 6, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    add         r1,     r1
    movd        m0,     [r2]
    movd        m2,     [r2 + r4]
    movd        m1,     [r3]
    movd        m3,     [r3 + r5]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    movd        m4,     [r2]
    movd        m6,     [r2 + r4]
    movd        m5,     [r3]
    movd        m7,     [r3 + r5]
    punpckldq   m0,     m2
    punpckldq   m1,     m3
    punpckldq   m4,     m6
    punpckldq   m5,     m7
    pmovzxbw    m0,     m0
    pmovzxbw    m1,     m1
    pmovzxbw    m4,     m4
    pmovzxbw    m5,     m5

    psubw       m0,     m1
    psubw       m4,     m5

    movh        [r0],           m0
    movhps      [r0 + r1],      m0
    movh        [r0 + r1 * 2],  m4
    lea         r0,     [r0 + r1 * 2]
    movhps      [r0 + r1],      m4

    RET
%endif


;-----------------------------------------------------------------------------
; void pixel_sub_ps_4x%2(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
%macro PIXELSUB_PS_W4_H4 2
%if HIGH_BIT_DEPTH
cglobal pixel_sub_ps_4x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov     r6d,    %2/4
    add     r4,     r4
    add     r5,     r5
    add     r1,     r1
.loop:
    movh    m0,     [r2]
    movh    m2,     [r2 + r4]
    movh    m1,     [r3]
    movh    m3,     [r3 + r5]
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]
    movh    m4,     [r2]
    movh    m6,     [r2 + r4]
    movh    m5,     [r3]
    movh    m7,     [r3 + r5]
    dec     r6d
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movh    [r0],           m0
    movh    [r0 + r1],      m2
    movh    [r0 + r1 * 2],  m4
    lea     r0,     [r0 + r1 * 2]
    movh    [r0 + r1],      m6
    lea     r0,     [r0 + r1 * 2]

    jnz     .loop
    RET
%else
cglobal pixel_sub_ps_4x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov         r6d,    %2/4
    add         r1,     r1
.loop:
    movd        m0,     [r2]
    movd        m2,     [r2 + r4]
    movd        m1,     [r3]
    movd        m3,     [r3 + r5]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    movd        m4,     [r2]
    movd        m6,     [r2 + r4]
    movd        m5,     [r3]
    movd        m7,     [r3 + r5]
    dec         r6d
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    punpckldq   m0,     m2
    punpckldq   m1,     m3
    punpckldq   m4,     m6
    punpckldq   m5,     m7
    pmovzxbw    m0,     m0
    pmovzxbw    m1,     m1
    pmovzxbw    m4,     m4
    pmovzxbw    m5,     m5

    psubw       m0,     m1
    psubw       m4,     m5

    movh        [r0],           m0
    movhps      [r0 + r1],      m0
    movh        [r0 + r1 * 2],  m4
    lea         r0,     [r0 + r1 * 2]
    movhps      [r0 + r1],      m4
    lea         r0,     [r0 + r1 * 2]

    jnz         .loop
    RET
%endif
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PIXELSUB_PS_W4_H4 4, 8
%else
INIT_XMM sse4
PIXELSUB_PS_W4_H4 4, 8
%endif


;-----------------------------------------------------------------------------
; void pixel_sub_ps_8x%2(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
%macro PIXELSUB_PS_W8_H4 2
%if HIGH_BIT_DEPTH
cglobal pixel_sub_ps_8x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov     r6d,    %2/4
    add     r4,     r4
    add     r5,     r5
    add     r1,     r1
.loop:
    movu    m0,     [r2]
    movu    m2,     [r2 + r4]
    movu    m1,     [r3]
    movu    m3,     [r3 + r5]
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]
    movu    m4,     [r2]
    movu    m6,     [r2 + r4]
    movu    m5,     [r3]
    movu    m7,     [r3 + r5]
    dec     r6d
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0],           m0
    movu    [r0 + r1],      m2
    movu    [r0 + r1 * 2],  m4
    lea     r0,     [r0 + r1 * 2]
    movu    [r0 + r1],      m6
    lea     r0,     [r0 + r1 * 2]

    jnz     .loop
    RET
%else
cglobal pixel_sub_ps_8x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov         r6d,    %2/4
    add         r1,     r1
.loop:
    movh        m0,     [r2]
    movh        m2,     [r2 + r4]
    movh        m1,     [r3]
    movh        m3,     [r3 + r5]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    movh        m4,     [r2]
    movh        m6,     [r2 + r4]
    movh        m5,     [r3]
    movh        m7,     [r3 + r5]
    dec         r6d
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    pmovzxbw    m0,     m0
    pmovzxbw    m1,     m1
    pmovzxbw    m2,     m2
    pmovzxbw    m3,     m3
    pmovzxbw    m4,     m4
    pmovzxbw    m5,     m5
    pmovzxbw    m6,     m6
    pmovzxbw    m7,     m7

    psubw       m0,     m1
    psubw       m2,     m3
    psubw       m4,     m5
    psubw       m6,     m7

    movu        [r0],           m0
    movu        [r0 + r1],      m2
    movu        [r0 + r1 * 2],  m4
    lea         r0,     [r0 + r1 * 2]
    movu        [r0 + r1],      m6
    lea         r0,     [r0 + r1 * 2]

    jnz         .loop
    RET
%endif
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PIXELSUB_PS_W8_H4 8, 8
PIXELSUB_PS_W8_H4 8, 16
%else
INIT_XMM sse4
PIXELSUB_PS_W8_H4 8, 8
PIXELSUB_PS_W8_H4 8, 16
%endif


;-----------------------------------------------------------------------------
; void pixel_sub_ps_16x%2(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
%macro PIXELSUB_PS_W16_H4 2
%if HIGH_BIT_DEPTH
cglobal pixel_sub_ps_16x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov     r6d,    %2/4
    add     r4,     r4
    add     r5,     r5
    add     r1,     r1
.loop:
    movu    m0,     [r2]
    movu    m2,     [r2 + 16]
    movu    m1,     [r3]
    movu    m3,     [r3 + 16]
    movu    m4,     [r2 + r4]
    movu    m6,     [r2 + r4 + 16]
    movu    m5,     [r3 + r5]
    movu    m7,     [r3 + r5 + 16]
    dec     r6d
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0],           m0
    movu    [r0 + 16],      m2
    movu    [r0 + r1],      m4
    movu    [r0 + r1 + 16], m6

    movu    m0,     [r2]
    movu    m2,     [r2 + 16]
    movu    m1,     [r3]
    movu    m3,     [r3 + 16]
    movu    m4,     [r2 + r4]
    movu    m5,     [r3 + r5]
    movu    m6,     [r2 + r4 + 16]
    movu    m7,     [r3 + r5 + 16]
    lea     r0,     [r0 + r1 * 2]
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0],           m0
    movu    [r0 + 16],      m2
    movu    [r0 + r1],      m4
    movu    [r0 + r1 + 16], m6
    lea     r0,     [r0 + r1 * 2]

    jnz     .loop
    RET
%else
cglobal pixel_sub_ps_16x%2, 6, 7, 7, dest, deststride, src0, src1, srcstride0, srcstride1
    mov         r6d,    %2/4
    pxor        m6,     m6
    add         r1,     r1
.loop:
    movu        m1,     [r2]
    movu        m3,     [r3]
    pmovzxbw    m0,     m1
    pmovzxbw    m2,     m3
    punpckhbw   m1,     m6
    punpckhbw   m3,     m6

    psubw       m0,     m2
    psubw       m1,     m3

    movu        m5,     [r2 + r4]
    movu        m3,     [r3 + r5]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    pmovzxbw    m4,     m5
    pmovzxbw    m2,     m3
    punpckhbw   m5,     m6
    punpckhbw   m3,     m6

    psubw       m4,     m2
    psubw       m5,     m3

    movu        [r0],           m0
    movu        [r0 + 16],      m1
    movu        [r0 + r1],      m4
    movu        [r0 + r1 + 16], m5

    movu        m1,     [r2]
    movu        m3,     [r3]
    pmovzxbw    m0,     m1
    pmovzxbw    m2,     m3
    punpckhbw   m1,     m6
    punpckhbw   m3,     m6

    psubw       m0,     m2
    psubw       m1,     m3

    movu        m5,     [r2 + r4]
    movu        m3,     [r3 + r5]
    dec         r6d
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    lea         r0,     [r0 + r1 * 2]
    pmovzxbw    m4,     m5
    pmovzxbw    m2,     m3
    punpckhbw   m5,     m6
    punpckhbw   m3,     m6

    psubw       m4,     m2
    psubw       m5,     m3

    movu        [r0],           m0
    movu        [r0 + 16],      m1
    movu        [r0 + r1],      m4
    movu        [r0 + r1 + 16], m5
    lea         r0,     [r0 + r1 * 2]

    jnz         .loop
    RET
%endif
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PIXELSUB_PS_W16_H4 16, 16
PIXELSUB_PS_W16_H4 16, 32
%else
INIT_XMM sse4
PIXELSUB_PS_W16_H4 16, 16
PIXELSUB_PS_W16_H4 16, 32
%endif


;-----------------------------------------------------------------------------
; void pixel_sub_ps_16x16(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
INIT_YMM avx2
cglobal pixel_sub_ps_16x16, 6, 7, 4, dest, deststride, src0, src1, srcstride0, srcstride1
    add         r1,     r1
    lea         r6,     [r1 * 3]

%rep 4
    pmovzxbw    m0,     [r2]
    pmovzxbw    m1,     [r3]
    pmovzxbw    m2,     [r2 + r4]
    pmovzxbw    m3,     [r3 + r5]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]

    psubw       m0,     m1
    psubw       m2,     m3

    movu        [r0],            m0
    movu        [r0 + r1],       m2

    pmovzxbw    m0,     [r2]
    pmovzxbw    m1,     [r3]
    pmovzxbw    m2,     [r2 + r4]
    pmovzxbw    m3,     [r3 + r5]

    psubw       m0,     m1
    psubw       m2,     m3

    movu        [r0 + r1 * 2],   m0
    movu        [r0 + r6],       m2

    lea         r0,     [r0 + r1 * 4]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
%endrep
    RET
;-----------------------------------------------------------------------------
; void pixel_sub_ps_32x%2(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
%macro PIXELSUB_PS_W32_H2 2
%if HIGH_BIT_DEPTH
cglobal pixel_sub_ps_32x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov     r6d,    %2/2
    add     r4,     r4
    add     r5,     r5
    add     r1,     r1
.loop:
    movu    m0,     [r2]
    movu    m2,     [r2 + 16]
    movu    m4,     [r2 + 32]
    movu    m6,     [r2 + 48]
    movu    m1,     [r3]
    movu    m3,     [r3 + 16]
    movu    m5,     [r3 + 32]
    movu    m7,     [r3 + 48]
    dec     r6d

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0],       m0
    movu    [r0 + 16],  m2
    movu    [r0 + 32],  m4
    movu    [r0 + 48],  m6

    movu    m0,     [r2 + r4]
    movu    m2,     [r2 + r4 + 16]
    movu    m4,     [r2 + r4 + 32]
    movu    m6,     [r2 + r4 + 48]
    movu    m1,     [r3 + r5]
    movu    m3,     [r3 + r5 + 16]
    movu    m5,     [r3 + r5 + 32]
    movu    m7,     [r3 + r5 + 48]
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0 + r1],      m0
    movu    [r0 + r1 + 16], m2
    movu    [r0 + r1 + 32], m4
    movu    [r0 + r1 + 48], m6
    lea     r0,     [r0 + r1 * 2]

    jnz     .loop
    RET
%else
cglobal pixel_sub_ps_32x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov         r6d,    %2/2
    add         r1,     r1
.loop:
    movh        m0,     [r2]
    movh        m1,     [r2 + 8]
    movh        m2,     [r2 + 16]
    movh        m6,     [r2 + 24]
    movh        m3,     [r3]
    movh        m4,     [r3 + 8]
    movh        m5,     [r3 + 16]
    movh        m7,     [r3 + 24]
    dec         r6d
    pmovzxbw    m0,     m0
    pmovzxbw    m1,     m1
    pmovzxbw    m2,     m2
    pmovzxbw    m6,     m6
    pmovzxbw    m3,     m3
    pmovzxbw    m4,     m4
    pmovzxbw    m5,     m5
    pmovzxbw    m7,     m7

    psubw       m0,     m3
    psubw       m1,     m4
    psubw       m2,     m5
    psubw       m6,     m7

    movu        [r0],       m0
    movu        [r0 + 16],  m1
    movu        [r0 + 32],  m2
    movu        [r0 + 48],  m6

    movh        m0,     [r2 + r4]
    movh        m1,     [r2 + r4 + 8]
    movh        m2,     [r2 + r4 + 16]
    movh        m6,     [r2 + r4 + 24]
    movh        m3,     [r3 + r5]
    movh        m4,     [r3 + r5 + 8]
    movh        m5,     [r3 + r5 + 16]
    movh        m7,     [r3 + r5 + 24]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    pmovzxbw    m0,     m0
    pmovzxbw    m1,     m1
    pmovzxbw    m2,     m2
    pmovzxbw    m6,     m6
    pmovzxbw    m3,     m3
    pmovzxbw    m4,     m4
    pmovzxbw    m5,     m5
    pmovzxbw    m7,     m7

    psubw       m0,     m3
    psubw       m1,     m4
    psubw       m2,     m5
    psubw       m6,     m7

    movu        [r0 + r1],      m0
    movu        [r0 + r1 + 16], m1
    movu        [r0 + r1 + 32], m2
    movu        [r0 + r1 + 48], m6
    lea         r0,     [r0 + r1 * 2]

    jnz         .loop
    RET
%endif
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PIXELSUB_PS_W32_H2 32, 32
PIXELSUB_PS_W32_H2 32, 64
%else
INIT_XMM sse4
PIXELSUB_PS_W32_H2 32, 32
PIXELSUB_PS_W32_H2 32, 64
%endif


;-----------------------------------------------------------------------------
; void pixel_sub_ps_32x32(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
INIT_YMM avx2
cglobal pixel_sub_ps_32x32, 6, 7, 4, dest, deststride, src0, src1, srcstride0, srcstride1
     mov        r6d,    4
     add        r1,     r1

.loop:
    pmovzxbw    m0,     [r2]
    pmovzxbw    m1,     [r2 + 16]
    pmovzxbw    m2,     [r3]
    pmovzxbw    m3,     [r3 + 16]

    psubw       m0,     m2
    psubw       m1,     m3

    movu        [r0],            m0
    movu        [r0 + 32],       m1

    pmovzxbw    m0,     [r2 + r4]
    pmovzxbw    m1,     [r2 + r4 + 16]
    pmovzxbw    m2,     [r3 + r5]
    pmovzxbw    m3,     [r3 + r5 + 16]

    psubw       m0,     m2
    psubw       m1,     m3

    movu        [r0 + r1],       m0
    movu        [r0 + r1 + 32],  m1

    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2 + r4]
    pmovzxbw    m1,     [r2 + r4 + 16]
    pmovzxbw    m2,     [r3 + r5]
    pmovzxbw    m3,     [r3 + r5 + 16]

    psubw       m0,     m2
    psubw       m1,     m3
    lea         r0,     [r0 + r1 * 2]

    movu        [r0 ],           m0
    movu        [r0 + 32],       m1

    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2 + r4]
    pmovzxbw    m1,     [r2 + r4 + 16]
    pmovzxbw    m2,     [r3 + r5]
    pmovzxbw    m3,     [r3 + r5 + 16]


    psubw       m0,     m2
    psubw       m1,     m3
    add         r0,     r1

    movu        [r0 ],           m0
    movu        [r0 + 32],       m1

    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2 + r4]
    pmovzxbw    m1,     [r2 + r4 + 16]
    pmovzxbw    m2,     [r3 + r5]
    pmovzxbw    m3,     [r3 + r5 + 16]

    psubw       m0,     m2
    psubw       m1,     m3
    add         r0,     r1

    movu        [r0 ],           m0
    movu        [r0 + 32],       m1

    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2 + r4]
    pmovzxbw    m1,     [r2 + r4 + 16]
    pmovzxbw    m2,     [r3 + r5]
    pmovzxbw    m3,     [r3 + r5 + 16]

    psubw       m0,     m2
    psubw       m1,     m3
    add         r0,     r1

    movu        [r0 ],           m0
    movu        [r0 + 32],       m1

    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2 + r4]
    pmovzxbw    m1,     [r2 + r4 + 16]
    pmovzxbw    m2,     [r3 + r5]
    pmovzxbw    m3,     [r3 + r5 + 16]

    psubw       m0,     m2
    psubw       m1,     m3
    add         r0,     r1

    movu        [r0 ],           m0
    movu        [r0 + 32],       m1

    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2 + r4]
    pmovzxbw    m1,     [r2 + r4 + 16]
    pmovzxbw    m2,     [r3 + r5]
    pmovzxbw    m3,     [r3 + r5 + 16]

    psubw       m0,     m2
    psubw       m1,     m3
    add         r0,     r1

    movu        [r0 ],           m0
    movu        [r0 + 32],       m1

    lea         r0,     [r0 + r1]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]

    dec         r6d
    jnz         .loop
    RET

;-----------------------------------------------------------------------------
; void pixel_sub_ps_64x%2(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
%macro PIXELSUB_PS_W64_H2 2
%if HIGH_BIT_DEPTH
cglobal pixel_sub_ps_64x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov     r6d,    %2/2
    add     r4,     r4
    add     r5,     r5
    add     r1,     r1
.loop:
    movu    m0,     [r2]
    movu    m2,     [r2 + 16]
    movu    m4,     [r2 + 32]
    movu    m6,     [r2 + 48]
    movu    m1,     [r3]
    movu    m3,     [r3 + 16]
    movu    m5,     [r3 + 32]
    movu    m7,     [r3 + 48]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0],       m0
    movu    [r0 + 16],  m2
    movu    [r0 + 32],  m4
    movu    [r0 + 48],  m6

    movu    m0,     [r2 + 64]
    movu    m2,     [r2 + 80]
    movu    m4,     [r2 + 96]
    movu    m6,     [r2 + 112]
    movu    m1,     [r3 + 64]
    movu    m3,     [r3 + 80]
    movu    m5,     [r3 + 96]
    movu    m7,     [r3 + 112]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0 + 64],  m0
    movu    [r0 + 80],  m2
    movu    [r0 + 96],  m4
    movu    [r0 + 112], m6

    movu    m0,     [r2 + r4]
    movu    m2,     [r2 + r4 + 16]
    movu    m4,     [r2 + r4 + 32]
    movu    m6,     [r2 + r4 + 48]
    movu    m1,     [r3 + r5]
    movu    m3,     [r3 + r5 + 16]
    movu    m5,     [r3 + r5 + 32]
    movu    m7,     [r3 + r5 + 48]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0 + r1],      m0
    movu    [r0 + r1 + 16], m2
    movu    [r0 + r1 + 32], m4
    movu    [r0 + r1 + 48], m6

    movu    m0,     [r2 + r4 + 64]
    movu    m2,     [r2 + r4 + 80]
    movu    m4,     [r2 + r4 + 96]
    movu    m6,     [r2 + r4 + 112]
    movu    m1,     [r3 + r5 + 64]
    movu    m3,     [r3 + r5 + 80]
    movu    m5,     [r3 + r5 + 96]
    movu    m7,     [r3 + r5 + 112]
    dec     r6d
    lea     r2,     [r2 + r4 * 2]
    lea     r3,     [r3 + r5 * 2]

    psubw   m0,     m1
    psubw   m2,     m3
    psubw   m4,     m5
    psubw   m6,     m7

    movu    [r0 + r1 + 64],     m0
    movu    [r0 + r1 + 80],     m2
    movu    [r0 + r1 + 96],     m4
    movu    [r0 + r1 + 112],    m6
    lea     r0,     [r0 + r1 * 2]

    jnz     .loop
    RET
%else
cglobal pixel_sub_ps_64x%2, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
    mov         r6d,    %2/2
    pxor        m6,     m6
    add         r1,     r1
.loop:
    movu        m1,     [r2]
    movu        m5,     [r2 + 16]
    movu        m3,     [r3]
    movu        m7,     [r3 + 16]

    pmovzxbw    m0,     m1
    pmovzxbw    m4,     m5
    pmovzxbw    m2,     m3
    punpckhbw   m1,     m6
    punpckhbw   m3,     m6
    punpckhbw   m5,     m6

    psubw       m0,     m2
    psubw       m1,     m3
    pmovzxbw    m2,     m7
    punpckhbw   m7,     m6
    psubw       m4,     m2
    psubw       m5,     m7

    movu        m3,     [r2 + 32]
    movu        m7,     [r3 + 32]
    pmovzxbw    m2,     m3
    punpckhbw   m3,     m6

    movu        [r0],       m0
    movu        [r0 + 16],  m1
    movu        [r0 + 32],  m4
    movu        [r0 + 48],  m5

    movu        m1,     [r2 + 48]
    movu        m5,     [r3 + 48]
    pmovzxbw    m0,     m1
    pmovzxbw    m4,     m7
    punpckhbw   m1,     m6
    punpckhbw   m7,     m6

    psubw       m2,     m4
    psubw       m3,     m7

    movu        [r0 + 64],  m2
    movu        [r0 + 80],  m3

    movu        m7,     [r2 + r4]
    movu        m3,     [r3 + r5]
    pmovzxbw    m2,     m5
    pmovzxbw    m4,     m7
    punpckhbw   m5,     m6
    punpckhbw   m7,     m6

    psubw       m0,     m2
    psubw       m1,     m5

    movu        [r0 + 96],  m0
    movu        [r0 + 112], m1

    movu        m2,     [r2 + r4 + 16]
    movu        m5,     [r3 + r5 + 16]
    pmovzxbw    m0,     m3
    pmovzxbw    m1,     m2
    punpckhbw   m3,     m6
    punpckhbw   m2,     m6

    psubw       m4,     m0
    psubw       m7,     m3

    movu        [r0 + r1],      m4
    movu        [r0 + r1 + 16], m7

    movu        m0,     [r2 + r4 + 32]
    movu        m3,     [r3 + r5 + 32]
    dec         r6d
    pmovzxbw    m4,     m5
    pmovzxbw    m7,     m0
    punpckhbw   m5,     m6
    punpckhbw   m0,     m6

    psubw       m1,     m4
    psubw       m2,     m5

    movu        [r0 + r1 + 32], m1
    movu        [r0 + r1 + 48], m2

    movu        m4,     [r2 + r4 + 48]
    movu        m5,     [r3 + r5 + 48]
    lea         r2,     [r2 + r4 * 2]
    lea         r3,     [r3 + r5 * 2]
    pmovzxbw    m1,     m3
    pmovzxbw    m2,     m4
    punpckhbw   m3,     m6
    punpckhbw   m4,     m6

    psubw       m7,     m1
    psubw       m0,     m3

    movu        [r0 + r1 + 64], m7
    movu        [r0 + r1 + 80], m0

    pmovzxbw    m7,     m5
    punpckhbw   m5,     m6
    psubw       m2,     m7
    psubw       m4,     m5

    movu        [r0 + r1 + 96],     m2
    movu        [r0 + r1 + 112],    m4
    lea         r0,     [r0 + r1 * 2]

    jnz         .loop
    RET
%endif
%endmacro

%if HIGH_BIT_DEPTH
INIT_XMM sse2
PIXELSUB_PS_W64_H2 64, 64
%else
INIT_XMM sse4
PIXELSUB_PS_W64_H2 64, 64
%endif


;-----------------------------------------------------------------------------
; void pixel_sub_ps_64x64(int16_t *dest, intptr_t destride, pixel *src0, pixel *src1, intptr_t srcstride0, intptr_t srcstride1);
;-----------------------------------------------------------------------------
INIT_YMM avx2
cglobal pixel_sub_ps_64x64, 6, 7, 8, dest, deststride, src0, src1, srcstride0, srcstride1
     mov        r6d,    16
     add        r1,     r1

.loop:
    pmovzxbw    m0,     [r2]
    pmovzxbw    m1,     [r2 + 16]
    pmovzxbw    m2,     [r2 + 32]
    pmovzxbw    m3,     [r2 + 48]

    pmovzxbw    m4,     [r3]
    pmovzxbw    m5,     [r3 + 16]
    pmovzxbw    m6,     [r3 + 32]
    pmovzxbw    m7,     [r3 + 48]

    psubw       m0,     m4
    psubw       m1,     m5
    psubw       m2,     m6
    psubw       m3,     m7

    movu        [r0],         m0
    movu        [r0 + 32],    m1
    movu        [r0 + 64],    m2
    movu        [r0 + 96],    m3

    add         r0,     r1
    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2]
    pmovzxbw    m1,     [r2 + 16]
    pmovzxbw    m2,     [r2 + 32]
    pmovzxbw    m3,     [r2 + 48]

    pmovzxbw    m4,     [r3]
    pmovzxbw    m5,     [r3 + 16]
    pmovzxbw    m6,     [r3 + 32]
    pmovzxbw    m7,     [r3 + 48]

    psubw       m0,     m4
    psubw       m1,     m5
    psubw       m2,     m6
    psubw       m3,     m7

    movu        [r0],         m0
    movu        [r0 + 32],    m1
    movu        [r0 + 64],    m2
    movu        [r0 + 96],    m3

    add         r0,     r1
    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2]
    pmovzxbw    m1,     [r2 + 16]
    pmovzxbw    m2,     [r2 + 32]
    pmovzxbw    m3,     [r2 + 48]

    pmovzxbw    m4,     [r3]
    pmovzxbw    m5,     [r3 + 16]
    pmovzxbw    m6,     [r3 + 32]
    pmovzxbw    m7,     [r3 + 48]

    psubw       m0,     m4
    psubw       m1,     m5
    psubw       m2,     m6
    psubw       m3,     m7

    movu        [r0],         m0
    movu        [r0 + 32],    m1
    movu        [r0 + 64],    m2
    movu        [r0 + 96],    m3

    add         r0,     r1
    add         r2,     r4
    add         r3,     r5

    pmovzxbw    m0,     [r2]
    pmovzxbw    m1,     [r2 + 16]
    pmovzxbw    m2,     [r2 + 32]
    pmovzxbw    m3,     [r2 + 48]

    pmovzxbw    m4,     [r3]
    pmovzxbw    m5,     [r3 + 16]
    pmovzxbw    m6,     [r3 + 32]
    pmovzxbw    m7,     [r3 + 48]

    psubw       m0,     m4
    psubw       m1,     m5
    psubw       m2,     m6
    psubw       m3,     m7

    movu        [r0],         m0
    movu        [r0 + 32],    m1
    movu        [r0 + 64],    m2
    movu        [r0 + 96],    m3

    add         r0,     r1
    add         r2,     r4
    add         r3,     r5

    dec         r6d
    jnz         .loop
    RET

;=============================================================================
; variance
;=============================================================================

%macro VAR_START 1
    pxor  m5, m5    ; sum
    pxor  m6, m6    ; sum squared
%if HIGH_BIT_DEPTH == 0
%if %1
    mova  m7, [pw_00ff]
%elif mmsize < 32
    pxor  m7, m7    ; zero
%endif
%endif ; !HIGH_BIT_DEPTH
%endmacro

%macro VAR_END 2
%if HIGH_BIT_DEPTH
%if mmsize == 8 && %1*%2 == 256
    HADDUW  m5, m2
%else
%if %1 >= 32
    HADDW     m5,    m2
    movd      m7,    r4d
    paddd     m5,    m7
%else
    HADDW   m5, m2
%endif
%endif
%else ; !HIGH_BIT_DEPTH
%if %1 == 64
    HADDW     m5,    m2
    movd      m7,    r4d
    paddd     m5,    m7
%else
    HADDW   m5, m2
%endif
%endif ; HIGH_BIT_DEPTH
    HADDD   m6, m1
%if ARCH_X86_64
    punpckldq m5, m6
    movq   rax, m5
%else
    movd   eax, m5
    movd   edx, m6
%endif
    RET
%endmacro

%macro VAR_CORE 0
    paddw     m5, m0
    paddw     m5, m3
    paddw     m5, m1
    paddw     m5, m4
    pmaddwd   m0, m0
    pmaddwd   m3, m3
    pmaddwd   m1, m1
    pmaddwd   m4, m4
    paddd     m6, m0
    paddd     m6, m3
    paddd     m6, m1
    paddd     m6, m4
%endmacro

%macro VAR_2ROW 3
    mov      r2d, %2
.loop%3:
%if HIGH_BIT_DEPTH
    movu      m0, [r0]
    movu      m1, [r0+mmsize]
    movu      m3, [r0+%1]
    movu      m4, [r0+%1+mmsize]
%else ; !HIGH_BIT_DEPTH
    mova      m0, [r0]
    punpckhbw m1, m0, m7
    mova      m3, [r0+%1]
    mova      m4, m3
    punpcklbw m0, m7
%endif ; HIGH_BIT_DEPTH
%ifidn %1, r1
    lea       r0, [r0+%1*2]
%else
    add       r0, r1
%endif
%if HIGH_BIT_DEPTH == 0
    punpcklbw m3, m7
    punpckhbw m4, m7
%endif ; !HIGH_BIT_DEPTH
    VAR_CORE
    dec r2d
    jg .loop%3
%endmacro

;-----------------------------------------------------------------------------
; int pixel_var_wxh( uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_MMX mmx2
cglobal pixel_var_16x16, 2,3
    FIX_STRIDES r1
    VAR_START 0
    VAR_2ROW 8*SIZEOF_PIXEL, 16, 1
    VAR_END 16, 16

cglobal pixel_var_8x8, 2,3
    FIX_STRIDES r1
    VAR_START 0
    VAR_2ROW r1, 4, 1
    VAR_END 8, 8

%if HIGH_BIT_DEPTH
%macro VAR 0
cglobal pixel_var_16x16, 2,3,8
    FIX_STRIDES r1
    VAR_START 0
    VAR_2ROW r1, 8, 1
    VAR_END 16, 16

cglobal pixel_var_8x8, 2,3,8
    lea       r2, [r1*3]
    VAR_START 0
    movu      m0, [r0]
    movu      m1, [r0+r1*2]
    movu      m3, [r0+r1*4]
    movu      m4, [r0+r2*2]
    lea       r0, [r0+r1*8]
    VAR_CORE
    movu      m0, [r0]
    movu      m1, [r0+r1*2]
    movu      m3, [r0+r1*4]
    movu      m4, [r0+r2*2]
    VAR_CORE
    VAR_END 8, 8

cglobal pixel_var_32x32, 2,6,8
    FIX_STRIDES r1
    mov       r3,    r0
    VAR_START 0
    VAR_2ROW  r1,    8, 1
    HADDW      m5,    m2
    movd       r4d,   m5
    pxor       m5,    m5
    VAR_2ROW  r1,    8, 2
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    lea       r0,    [r3 + 32]
    VAR_2ROW  r1,    8, 3
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 4
    VAR_END   32,    32

cglobal pixel_var_64x64, 2,6,8
    FIX_STRIDES r1
    mov       r3,    r0
    VAR_START 0
    VAR_2ROW  r1,    8, 1
    HADDW      m5,    m2
    movd       r4d,   m5
    pxor       m5,    m5
    VAR_2ROW  r1,    8, 2
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 3
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 4
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    lea       r0,    [r3 + 32]
    VAR_2ROW  r1,    8, 5
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 6
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 7
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 8
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    lea       r0,    [r3 + 64]
    VAR_2ROW  r1,    8, 9
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 10
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 11
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 12
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    lea       r0,    [r3 + 96]
    VAR_2ROW  r1,    8, 13
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 14
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 15
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    VAR_2ROW  r1,    8, 16
    VAR_END   64,    64
%endmacro ; VAR

INIT_XMM sse2
VAR
INIT_XMM avx
VAR
INIT_XMM xop
VAR
%endif ; HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
%macro VAR 0
cglobal pixel_var_8x8, 2,3,8
    VAR_START 1
    lea       r2,    [r1 * 3]
    movh      m0,    [r0]
    movh      m3,    [r0 + r1]
    movhps    m0,    [r0 + r1 * 2]
    movhps    m3,    [r0 + r2]
    DEINTB    1, 0, 4, 3, 7
    lea       r0,    [r0 + r1 * 4]
    VAR_CORE
    movh      m0,    [r0]
    movh      m3,    [r0 + r1]
    movhps    m0,    [r0 + r1 * 2]
    movhps    m3,    [r0 + r2]
    DEINTB    1, 0, 4, 3, 7
    VAR_CORE
    VAR_END 8, 8

cglobal pixel_var_16x16_internal
    movu      m0,    [r0]
    movu      m3,    [r0 + r1]
    DEINTB    1, 0, 4, 3, 7
    VAR_CORE
    movu      m0,    [r0 + 2 * r1]
    movu      m3,    [r0 + r2]
    DEINTB    1, 0, 4, 3, 7
    lea       r0,    [r0 + r1 * 4]
    VAR_CORE
    movu      m0,    [r0]
    movu      m3,    [r0 + r1]
    DEINTB    1, 0, 4, 3, 7
    VAR_CORE
    movu      m0,    [r0 + 2 * r1]
    movu      m3,    [r0 + r2]
    DEINTB    1, 0, 4, 3, 7
    lea       r0,    [r0 + r1 * 4]
    VAR_CORE
    movu      m0,    [r0]
    movu      m3,    [r0 + r1]
    DEINTB    1, 0, 4, 3, 7
    VAR_CORE
    movu      m0,    [r0 + 2 * r1]
    movu      m3,    [r0 + r2]
    DEINTB    1, 0, 4, 3, 7
    lea       r0,    [r0 + r1 * 4]
    VAR_CORE
    movu      m0,    [r0]
    movu      m3,    [r0 + r1]
    DEINTB    1, 0, 4, 3, 7
    VAR_CORE
    movu      m0,    [r0 + 2 * r1]
    movu      m3,    [r0 + r2]
    DEINTB    1, 0, 4, 3, 7
    VAR_CORE
    ret

cglobal pixel_var_16x16, 2,3,8
    VAR_START 1
    lea     r2,    [r1 * 3]
    call    pixel_var_16x16_internal
    VAR_END 16, 16

cglobal pixel_var_32x32, 2,4,8
    VAR_START 1
    lea     r2,    [r1 * 3]
    mov     r3,    r0
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r3 + 16]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    VAR_END 32, 32

cglobal pixel_var_64x64, 2,6,8
    VAR_START 1
    lea     r2,    [r1 * 3]
    mov     r3,    r0
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    HADDW     m5,    m2
    movd      r4d,   m5
    pxor      m5,    m5
    lea       r0,    [r3 + 16]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    lea       r0,    [r3 + 32]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r3 + 48]
    HADDW     m5,    m2
    movd      r5d,   m5
    add       r4,    r5
    pxor      m5,    m5
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    lea       r0,    [r0 + r1 * 4]
    call    pixel_var_16x16_internal
    VAR_END 64, 64
%endmacro ; VAR

INIT_XMM sse2
VAR
INIT_XMM avx
VAR
INIT_XMM xop
VAR

INIT_YMM avx2
cglobal pixel_var_16x16, 2,4,7
    VAR_START 0
    mov      r2d, 4
    lea       r3, [r1*3]
.loop:
    pmovzxbw  m0, [r0]
    pmovzxbw  m3, [r0+r1]
    pmovzxbw  m1, [r0+r1*2]
    pmovzxbw  m4, [r0+r3]
    lea       r0, [r0+r1*4]
    VAR_CORE
    dec r2d
    jg .loop
    vextracti128 xm0, m5, 1
    vextracti128 xm1, m6, 1
    paddw  xm5, xm0
    paddd  xm6, xm1
    HADDW  xm5, xm2
    HADDD  xm6, xm1
%if ARCH_X86_64
    punpckldq xm5, xm6
    movq   rax, xm5
%else
    movd   eax, xm5
    movd   edx, xm6
%endif
    RET
%endif ; !HIGH_BIT_DEPTH

%macro VAR2_END 3
    HADDW   %2, xm1
    movd   r1d, %2
    imul   r1d, r1d
    HADDD   %3, xm1
    shr    r1d, %1
    movd   eax, %3
    movd  [r4], %3
    sub    eax, r1d  ; sqr - (sum * sum >> shift)
    RET
%endmacro

;int x265_test_func(const uint16_t *scan, const coeff_t *coeff, uint16_t *coeffSign, uint16_t *coeffFlag, uint8_t *coeffNum, int numSig)
;{
;    int scanPosLast = 0;
;    do
;    {
;        const uint32_t cgIdx = (uint32_t)scanPosLast >> MLS_CG_SIZE;
;
;        const uint32_t posLast = scan[scanPosLast++];
;
;        const int curCoeff = coeff[posLast];
;        const uint32_t isNZCoeff = (curCoeff != 0);
;        numSig -= isNZCoeff;
;
;        coeffSign[cgIdx] += (uint16_t)(((uint32_t)curCoeff >> 31) << coeffNum[cgIdx]);
;        coeffFlag[cgIdx] = (coeffFlag[cgIdx] << 1) + (uint16_t)isNZCoeff;
;        coeffNum[cgIdx] += (uint8_t)isNZCoeff;
;    }
;    while (numSig > 0);
;    return scanPosLast - 1;
;}

%if ARCH_X86_64 == 1
INIT_CPUFLAGS
cglobal findPosLast_x64, 5,12
    mov         r5d, r5m
    xor         r11d, r11d                  ; cgIdx
    xor         r7d, r7d                    ; tmp for non-zero flag

.loop:
    xor         r8d, r8d                    ; coeffSign[]
    xor         r9d, r9d                    ; coeffFlag[]
    xor         r10d, r10d                  ; coeffNum[]

%assign x 0
%rep 16
    movzx       r6d, word [r0 + x * 2]
    movsx       r6d, word [r1 + r6 * 2]
    test        r6d, r6d
    setnz       r7b
    shr         r6d, 31
    shlx        r6d, r6d, r10d
    or          r8d, r6d
    lea         r9, [r9 * 2 + r7]
    add         r10d, r7d
%assign x x+1
%endrep

    ; store latest group data
    mov         [r2 + r11 * 2], r8w
    mov         [r3 + r11 * 2], r9w
    mov         [r4 + r11], r10b
    inc         r11d

    add         r0, 16 * 2
    sub         r5d, r10d
    jnz        .loop

    ; store group data
    tzcnt       r6d, r9d
    shrx        r9d, r9d, r6d
    mov         [r3 + (r11 - 1) * 2], r9w

    ; get posLast
    shl         r11d, 4
    sub         r11d, r6d
    lea         eax, [r11d - 1]
    RET
%endif
