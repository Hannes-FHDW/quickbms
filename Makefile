#
# the "new" makefile, because who likes waiting a half hour
# for "all the things" to rebuild when all you did was
# changed one line?
#
# old makefile is still under `src/` but you're going
# to discover, like i did, that quickbms doesn't build
# "as-is".
#

# uncomment to build "quickbms64"
QUICKBMS64 := 1
# uncomment to include openssl in build
USE_OPENSSL := 1
# uncomment to include "amiga stuff" in build
#USE_AMIGASTUFF := 1
# uncomment to include debug info
#DEBUG := 1

# machine operating system and processor architecture vars
MOS := $(shell uname -s)
ifeq ($(MOS),Linux)
	OS := linux
	LINUX := 1
else ifeq ($(MOS),Darwin)
	OS := osx
	DARWIN := 1
else ifeq ($(shell uname -o), Android)
	OS := android
	ANDROID := 1
else
	OS := windows
	WINDOWS := 1
endif
MARCH := $(shell uname -m)
ifeq ($(MARCH),x86_64)
	ARCH := amd64
	AMD64 := 1
else ifeq ($(MARCH),aarch64)
	ARCH := arm64
	ARM64 := 1
else
	ARCH := $(MARCH)	
endif

# baseline tools and their settings, nothing currently changes these but calling them out explicitly anyway
AS := as	    # Assembler
CC := clang		# C compiler
CXX := clang++	# C++ compiler
AR := llvm-ar	# lib tool
LD := clang++	# linker

# baseline options
CFLAGS += -fPIC -emit-llvm
LDFLAGS += -fuse-ld=lld -pie -lpthread -ldl -Wl,--icf=none

# baseline directories / filenames
SRCDIR := src
OBJDIR := obj
BINDIR := bin
PREFIX := /usr/local/bin
ifdef QUICKBMS64
	EXE := quickbms64
else
	EXE := quickbms
endif

DEFINES	+= \
	-DCAPSTONE_HAS_ARM \
	-DCAPSTONE_HAS_ARM64 \
	-DCAPSTONE_HAS_MIPS \
	-DCAPSTONE_HAS_POWERPC \
	-DCAPSTONE_HAS_SPARC \
	-DCAPSTONE_HAS_SYSZ \
	-DCAPSTONE_HAS_X86 \
	-DCAPSTONE_HAS_XCORE \
	-DCAPSTONE_USE_SYS_DYN_MEM \
	-DCAPSTONE_X86_ATT_DISABLE \
	-DDENSITY_FORCE_INLINE=inline \
	-DDISABLE_MCRYPT \
	-DDISABLE_TOMCRYPT \
	-DE_INVALIDARG=-1 \
	-DLZHAM_ANSI_CPLUSPLUS \
	-DMYDOWN_GLOBAL_COOKIE \
	-DMYDOWN_SSL \
	-Dregister=register \
	-DZSTD_DISABLE_ASM \
	-D_7ZIP_ST \
	-D_7Z_TYPES_ \
	-Drestrict=__restrict__

INCLUDE_DIRS += \
	-I$(SRCDIR) \
	-I$(SRCDIR)/libs/capstone/include \
	-I$(SRCDIR)/libs/ecrypt/include \
	-I$(SRCDIR)/libs/libcsc \
	-I$(SRCDIR)/libs/ucl \
	-I$(SRCDIR)/libs/ucl/include \
	-I$(SRCDIR)/encryption \
	-I$(SRCDIR)/extra \
	-I$(SRCDIR)/libs/brieflz/include \
	-I$(SRCDIR)/libs/brotli/include \
	-I$(SRCDIR)/libs/zlib \
	-I$(SRCDIR)/libs/lzham_codec/include \
	-I$(SRCDIR)/libs/lzham_codec/lzhamcomp \
	-I$(SRCDIR)/libs/lzham_codec/lzhamdecomp

ifdef DEBUG
CFLAGS += -Og
LDFLAGS += -Og -Wl,--gdb-index,--print-map
else
CFLAGS += -O2 -w
LDFLAGS += -O2 -Wl,--strip-all
endif

ifdef QUICKBMS64
DEFINES += -DQUICKBMS64
endif

ifdef AMD64
CFLAGS += -msse2
OBJS_LIBS += \
	$(OBJDIR)/cpp_libs_powzix_bitknit.o \
	$(OBJDIR)/cpp_libs_powzix_kraken.o \
	$(OBJDIR)/cpp_libs_powzix_lzna.o
endif

ifdef DARWIN
CFLAGS	+= -Dunix
DEFINES	+= \
	-DFORCE_SATUR_SUB_128 \
	-D__APPLE__
endif

ifdef ANDROID
# -liconv is necessary on Android
LDFLAGS += -liconv
endif

ifndef USE_OPENSSL
DEFINES	+= -DDISABLE_SSL
else
ifndef DARWIN
LDFLAGS	+= -lssl -lcrypto
else
PREFIX_OPENSSL = $(shell brew --prefix openssl)
INCLUDE_DIRS += -I$(PREFIX_OPENSSL)/include
LDFLAGS += -$(PREFIX_OPENSSL)/lib/libssl.a $(PREFIX_OPENSSL)/lib/libcrypto.a
endif
endif

ifdef USE_AMIGASTUFF
DEFINES += __INCLUDE_AMIGASTUFF__
OBJS_LIBS += \
 	$(OBJDIR)/s_libs_amiga/amiga.o
endif

CFLAGS	+= $(DEFINES) $(INCLUDE_DIRS)
CCFLAGS += $(CFLAGS) -std=gnu89 -Wno-error=incompatible-function-pointer-types
CXXFLAGS += $(CFLAGS) -std=gnu++17

LDFLAGS += \
	$(SRCDIR)/compression/jcalg1_static.lib \
	$(SRCDIR)/libs/aplib/lib/coff/aplib.lib

##
# primary build targets
##

.PHONY:
	clean install rebuild all

all: build

build: $(OBJDIR) $(BINDIR) $(BINDIR)/$(EXE)

clean:
	rm -rf $(OBJDIR)
	rm -rf $(BINDIR)

install: build
	chmod 755 $(BINDIR)/$(EXE)
	cp $(BINDIR)/$(EXE) $(PREFIX)/$(EXE)

rebuild: clean build


##
#
# a note on the "wall of text" which follows.
#
# "recursive make" is slower than this approach.
#
# this approach requires more typing, but yields
# significantly faster build times.
#
# if you think you can acheive the same in fewer
# lines without "recursive make", please, do. perhaps
# ninja could be adopted, so long as it is consistent
# on linux, osx, and mingw, i personally don't care
# i will use anything that works well and saves time.
#
#
# TIP: most of this was generated through some variation of find, sed, and awk. for example:
#
# find src/libs -name '*.c' -printf '%p\n' | sed 's/^src/$\(OBJDIR\)/g' | sed 's/\.c.*$/.o \\/g' | sed s/libs/libs\\/c/g
#
##

##
# what to build
##

OBJS_COMPRESSION := \
	$(OBJDIR)/c_compression_E-Decompressor.o \
	$(OBJDIR)/c_compression_FastAri.o \
	$(OBJDIR)/c_compression_K-Decompressor.o \
	$(OBJDIR)/c_compression_N-Decompressor.o \
	$(OBJDIR)/c_compression_S-Decompressor.o \
	$(OBJDIR)/c_compression_Shrinker.o \
	$(OBJDIR)/c_compression__rnc.o \
	$(OBJDIR)/c_compression_alone_unpack.o \
	$(OBJDIR)/c_compression_alz.o \
	$(OBJDIR)/c_compression_alzss.o \
	$(OBJDIR)/c_compression_arithshift.o \
	$(OBJDIR)/c_compression_ash.o \
	$(OBJDIR)/c_compression_ashford.o \
	$(OBJDIR)/c_compression_bgbpaq0.o \
	$(OBJDIR)/c_compression_blast.o \
	$(OBJDIR)/c_compression_bpd.o \
	$(OBJDIR)/c_compression_bpe.o \
	$(OBJDIR)/c_compression_bpe2.o \
	$(OBJDIR)/c_compression_camoto.o \
	$(OBJDIR)/c_compression_compress42.o \
	$(OBJDIR)/c_compression_d3101.o \
	$(OBJDIR)/c_compression_deLZW.o \
	$(OBJDIR)/c_compression_de_compress.o \
	$(OBJDIR)/c_compression_de_huffman.o \
	$(OBJDIR)/c_compression_de_lzah.o \
	$(OBJDIR)/c_compression_de_lzh.o \
	$(OBJDIR)/c_compression_dernc.o \
	$(OBJDIR)/c_compression_dicky_.o \
	$(OBJDIR)/c_compression_dict.o \
	$(OBJDIR)/c_compression_dipperstein.o \
	$(OBJDIR)/c_compression_dmc2.o \
	$(OBJDIR)/c_compression_doomhuff.o \
	$(OBJDIR)/c_compression_fastlz.o \
	$(OBJDIR)/c_compression_glza.o \
	$(OBJDIR)/c_compression_gz_unpack.o \
	$(OBJDIR)/c_compression_hstest.o \
	$(OBJDIR)/c_compression_huffmanlib.o \
	$(OBJDIR)/c_compression_lab313.o \
	$(OBJDIR)/c_compression_libLZR.o \
	$(OBJDIR)/c_compression_lz4x.o \
	$(OBJDIR)/c_compression_lz4x_new.o \
	$(OBJDIR)/c_compression_lzari.o \
	$(OBJDIR)/c_compression_lzd.o \
	$(OBJDIR)/c_compression_lzfx.o \
	$(OBJDIR)/c_compression_lzh8_dec.o \
	$(OBJDIR)/c_compression_lzhuf.o \
	$(OBJDIR)/c_compression_lzhxlib.o \
	$(OBJDIR)/c_compression_lzmat_dec.o \
	$(OBJDIR)/c_compression_lzrw1-a.o \
	$(OBJDIR)/c_compression_lzrw1.o \
	$(OBJDIR)/c_compression_lzrw1kh.o \
	$(OBJDIR)/c_compression_lzrw2.o \
	$(OBJDIR)/c_compression_lzrw3-a.o \
	$(OBJDIR)/c_compression_lzrw3.o \
	$(OBJDIR)/c_compression_lzrw5.o \
	$(OBJDIR)/c_compression_lzss.o \
	$(OBJDIR)/c_compression_lzv1.o \
	$(OBJDIR)/c_compression_m99coder.o \
	$(OBJDIR)/c_compression_mppc.o \
	$(OBJDIR)/c_compression_myfreeze.o \
	$(OBJDIR)/c_compression_nitroCompLib.o \
	$(OBJDIR)/c_compression_openkb.o \
	$(OBJDIR)/c_compression_pithy.o \
	$(OBJDIR)/c_compression_pkware_dcl.o \
	$(OBJDIR)/c_compression_prs_8ing_compress.o \
	$(OBJDIR)/c_compression_pucrunch.o \
	$(OBJDIR)/c_compression_puff8.o \
	$(OBJDIR)/c_compression_quicklz.o \
	$(OBJDIR)/c_compression_rage_xfs.o \
	$(OBJDIR)/c_compression_refpack.o \
	$(OBJDIR)/c_compression_rnc.o \
	$(OBJDIR)/c_compression_romchu.o \
	$(OBJDIR)/c_compression_runzip.o \
	$(OBJDIR)/c_compression_scexpand.o \
	$(OBJDIR)/c_compression_scummvm.o \
	$(OBJDIR)/c_compression_scz_decompress_lib.o \
	$(OBJDIR)/c_compression_sflcomp.o \
	$(OBJDIR)/c_compression_shc.o \
	$(OBJDIR)/c_compression_shclib.o \
	$(OBJDIR)/c_compression_shikadi.o \
	$(OBJDIR)/c_compression_sixpack.o \
	$(OBJDIR)/c_compression_smaz.o \
	$(OBJDIR)/c_compression_splay.o \
	$(OBJDIR)/c_compression_squish.o \
	$(OBJDIR)/c_compression_sqx.o \
	$(OBJDIR)/c_compression_sqz.o \
	$(OBJDIR)/c_compression_sr3c.o \
	$(OBJDIR)/c_compression_srank.o \
	$(OBJDIR)/c_compression_tinflatex.o \
	$(OBJDIR)/c_compression_unace1.o \
	$(OBJDIR)/c_compression_uncompress.o \
	$(OBJDIR)/c_compression_unctw.o \
	$(OBJDIR)/c_compression_undmc.o \
	$(OBJDIR)/c_compression_ungtc.o \
	$(OBJDIR)/c_compression_unjam.o \
	$(OBJDIR)/c_compression_unlzw.o \
	$(OBJDIR)/c_compression_unlzwx.o \
	$(OBJDIR)/c_compression_unlzx.o \
	$(OBJDIR)/c_compression_unmspack.o \
	$(OBJDIR)/c_compression_unq3huff.o \
	$(OBJDIR)/c_compression_unreduce.o \
	$(OBJDIR)/c_compression_unshrink.o \
	$(OBJDIR)/c_compression_unterse.o \
	$(OBJDIR)/c_compression_usq.o \
	$(OBJDIR)/c_compression_wfLZ.o \
	$(OBJDIR)/c_compression_xu4_lzw.o \
	$(OBJDIR)/c_compression_yuke_bpe.o \
	$(OBJDIR)/c_compression_zax.o \
	$(OBJDIR)/c_compression_zx.o \
	$(OBJDIR)/cc_compression_u6decode.o \
	$(OBJDIR)/cpp_compression_CompressedData.o \
	$(OBJDIR)/cpp_compression_LzHuf.o \
	$(OBJDIR)/cpp_compression_PP20.o \
	$(OBJDIR)/cpp_compression_advancecomp.o \
	$(OBJDIR)/cpp_compression_balz.o \
	$(OBJDIR)/cpp_compression_bcm.o \
	$(OBJDIR)/cpp_compression_csc.o \
	$(OBJDIR)/cpp_compression_doboz.o \
	$(OBJDIR)/cpp_compression_filter-lzw.o \
	$(OBJDIR)/cpp_compression_gipfeli.o \
	$(OBJDIR)/cpp_compression_irolz.o \
	$(OBJDIR)/cpp_compression_irolz2.o \
	$(OBJDIR)/cpp_compression_lzpxj.o \
	$(OBJDIR)/cpp_compression_ppmz2.o \
	$(OBJDIR)/cpp_compression_stormlib.o \
	$(OBJDIR)/cpp_compression_stormlib_huff.o \
	$(OBJDIR)/cpp_compression_unazo.o \
	$(OBJDIR)/cpp_compression_undark.o \
	$(OBJDIR)/cpp_compression_unflzp.o \
	$(OBJDIR)/cpp_compression_unlpaq8.o \
	$(OBJDIR)/cpp_compression_unpp20.o \
	$(OBJDIR)/cpp_compression_unquad.o \
	$(OBJDIR)/cpp_compression_unsnappy.o \
	$(OBJDIR)/cpp_compression_unsr3.o \
	$(OBJDIR)/cpp_compression_uo_iris.o \
	$(OBJDIR)/cpp_compression_yalz77.o \
	$(OBJDIR)/cpp_compression_zling.o \
	$(OBJDIR)/cpp_compression_zpaq.o

OBJS_DISASM := \
	$(OBJDIR)/c_disasm_cmdlist.o \
	$(OBJDIR)/c_disasm_disasm.o \
	$(OBJDIR)/c_disasm_assembl_assembl.o

OBJS_ENCRYPTION := \
	$(OBJDIR)/c_encryption_3way.o \
	$(OBJDIR)/c_encryption_abc.o \
	$(OBJDIR)/c_encryption_achterbahn.o \
	$(OBJDIR)/c_encryption_achterbahn128.o \
	$(OBJDIR)/c_encryption_anubis.o \
	$(OBJDIR)/c_encryption_arc4.o \
	$(OBJDIR)/c_encryption_aria.o \
	$(OBJDIR)/c_encryption_chacha20_simple.o \
	$(OBJDIR)/c_encryption_cryptmt.o \
	$(OBJDIR)/c_encryption_crypton.o \
	$(OBJDIR)/c_encryption_d3des.o \
	$(OBJDIR)/c_encryption_dicing.o \
	$(OBJDIR)/c_encryption_dragon.o \
	$(OBJDIR)/c_encryption_edon80.o \
	$(OBJDIR)/c_encryption_ffcsr8.o \
	$(OBJDIR)/c_encryption_frog.o \
	$(OBJDIR)/c_encryption_fubuki.o \
	$(OBJDIR)/c_encryption_gost.o \
	$(OBJDIR)/c_encryption_grain.o \
	$(OBJDIR)/c_encryption_grain128.o \
	$(OBJDIR)/c_encryption_hc128.o \
	$(OBJDIR)/c_encryption_hc256.o \
	$(OBJDIR)/c_encryption_hermes128.o \
	$(OBJDIR)/c_encryption_hermes80.o \
	$(OBJDIR)/c_encryption_ice.o \
	$(OBJDIR)/c_encryption_isaac.o \
	$(OBJDIR)/c_encryption_isaacx.o \
	$(OBJDIR)/c_encryption_leverage_ssc.o \
	$(OBJDIR)/c_encryption_lex.o \
	$(OBJDIR)/c_encryption_lucifer.o \
	$(OBJDIR)/c_encryption_mag.o \
	$(OBJDIR)/c_encryption_mars.o \
	$(OBJDIR)/c_encryption_mickey.o \
	$(OBJDIR)/c_encryption_mickey128.o \
	$(OBJDIR)/c_encryption_mir1.o \
	$(OBJDIR)/c_encryption_misty1.o \
	$(OBJDIR)/c_encryption_molebox.o \
	$(OBJDIR)/c_encryption_mosquito.o \
	$(OBJDIR)/c_encryption_moustique.o \
	$(OBJDIR)/c_encryption_nls.o \
	$(OBJDIR)/c_encryption_NoekeonDirectRef.o \
	$(OBJDIR)/c_encryption_pc1.o \
	$(OBJDIR)/c_encryption_polarbear.o \
	$(OBJDIR)/c_encryption_pomaranch.o \
	$(OBJDIR)/c_encryption_py.o \
	$(OBJDIR)/c_encryption_rabbit.o \
	$(OBJDIR)/c_encryption_rc6.o \
	$(OBJDIR)/c_encryption_rotor.o \
	$(OBJDIR)/c_encryption_safer.o \
	$(OBJDIR)/c_encryption_salsa20.o \
	$(OBJDIR)/c_encryption_seal.o \
	$(OBJDIR)/c_encryption_seed.o \
	$(OBJDIR)/c_encryption_serpent.o \
	$(OBJDIR)/c_encryption_sfinks.o \
	$(OBJDIR)/c_encryption_skipjack.o \
	$(OBJDIR)/c_encryption_sosemanuk.o \
	$(OBJDIR)/c_encryption_sph.o \
	$(OBJDIR)/c_encryption_sss.o \
	$(OBJDIR)/c_encryption_tea.o \
	$(OBJDIR)/c_encryption_trivium.o \
	$(OBJDIR)/c_encryption_tsc3.o \
	$(OBJDIR)/c_encryption_tsc4.o \
	$(OBJDIR)/c_encryption_twofish.o \
	$(OBJDIR)/c_encryption_wg.o \
	$(OBJDIR)/c_encryption_xtea.o \
	$(OBJDIR)/c_encryption_xxtea.o \
	$(OBJDIR)/c_encryption_yamb.o \
	$(OBJDIR)/c_encryption_zipcrypto.o \
	$(OBJDIR)/cc_encryption_city.o

OBJS_EXTRA := \
    $(OBJDIR)/c_extra_mem2mem.o \
    $(OBJDIR)/c_extra_mybits.o \
    $(OBJDIR)/c_extra_quickrva.o \
    $(OBJDIR)/c_extra_xalloc.o

OBJS_INCLUDED := \
    $(OBJDIR)/c_included_asura_huffboh.o \
    $(OBJDIR)/c_included_blackdesert_unpack.o \
    $(OBJDIR)/c_included_boh.o \
    $(OBJDIR)/c_included_compression_unknown.o \
    $(OBJDIR)/c_included_compresslayla.o \
    $(OBJDIR)/c_included_comprlib.o \
    $(OBJDIR)/c_included_crush.o \
    $(OBJDIR)/c_included_deulz.o \
    $(OBJDIR)/c_included_ea_comp.o \
    $(OBJDIR)/c_included_ea_huff.o \
    $(OBJDIR)/c_included_ea_jdlz.o \
    $(OBJDIR)/c_included_ea_madden.o \
    $(OBJDIR)/c_included_elias.o \
    $(OBJDIR)/c_included_enet_compress.o \
    $(OBJDIR)/c_included_fal_codec.o \
    $(OBJDIR)/c_included_falcom_din.o \
    $(OBJDIR)/c_included_ffce.o \
    $(OBJDIR)/c_included_garbro.o \
    $(OBJDIR)/c_included_goldensun.o \
    $(OBJDIR)/c_included_hd2.o \
    $(OBJDIR)/c_included_he3.o \
    $(OBJDIR)/c_included_ilzr.o \
    $(OBJDIR)/c_included_kofdecompress.o \
    $(OBJDIR)/c_included_kzip_old.o \
    $(OBJDIR)/c_included_lego_ixs.o \
    $(OBJDIR)/c_included_luminousarc.o \
    $(OBJDIR)/c_included_lunar.o \
    $(OBJDIR)/c_included_lz77_0.o \
    $(OBJDIR)/c_included_lzbss.o \
    $(OBJDIR)/c_included_lzfu.o \
    $(OBJDIR)/c_included_lzham.o \
    $(OBJDIR)/c_included_lzssx.o \
    $(OBJDIR)/c_included_microvision.o \
    $(OBJDIR)/c_included_mppc.o \
    $(OBJDIR)/c_included_msf.o \
    $(OBJDIR)/c_included_neptunia.o \
    $(OBJDIR)/c_included_nintendo.o \
    $(OBJDIR)/c_included_ntcompress.o \
    $(OBJDIR)/c_included_ntfs_compress.o \
    $(OBJDIR)/c_included_old_bizarre.o \
    $(OBJDIR)/c_included_oodle.o \
    $(OBJDIR)/c_included_puyo.o \
    $(OBJDIR)/c_included_qfs.o \
    $(OBJDIR)/c_included_rdc.o \
    $(OBJDIR)/c_included_rep.o \
    $(OBJDIR)/c_included_rodecompress.o \
    $(OBJDIR)/c_included_sega_lz77.o \
    $(OBJDIR)/c_included_sega_lzs2.o \
    $(OBJDIR)/c_included_stalker_lza.o \
    $(OBJDIR)/c_included_tzar_lzss.o \
    $(OBJDIR)/c_included_un434a.o \
    $(OBJDIR)/c_included_un49g.o \
    $(OBJDIR)/c_included_unanco.o \
    $(OBJDIR)/c_included_undact.o \
    $(OBJDIR)/c_included_undarksector.o \
    $(OBJDIR)/c_included_undflt.o \
    $(OBJDIR)/c_included_undk2.o \
    $(OBJDIR)/c_included_unlz2k.o \
    $(OBJDIR)/c_included_unmeng.o \
    $(OBJDIR)/c_included_unpxp.o \
    $(OBJDIR)/c_included_unrfpk.o \
    $(OBJDIR)/c_included_unrlew.o \
    $(OBJDIR)/c_included_unthandor.o \
    $(OBJDIR)/c_included_unyakuza.o \
    $(OBJDIR)/c_included_wp16.o \
    $(OBJDIR)/c_included_xpksqsh.o \
    $(OBJDIR)/c_included_yappy.o \
    $(OBJDIR)/c_included_yay0dec.o \
    $(OBJDIR)/c_included_zenpxp.o \
    $(OBJDIR)/c_included_zyxel_lzsd.o \
	$(OBJDIR)/cpp_included_prs.o

# NOTE: these are "included" not "linked"
# TODO: consider compiling and linking if it would help build performance
# OBJS_IO := \
# 	$(OBJDIR)/c_io_audio/c.o \
# 	$(OBJDIR)/c_io_process.o \
# 	$(OBJDIR)/c_io_sockets.o \
# 	$(OBJDIR)/c_io_video.o \
# 	$(OBJDIR)/c_io_winmsg.o

OBJS_LIBS += \
	$(OBJDIR)/c_libs_aplib_src_depacks.o \
	$(OBJDIR)/c_libs_bcl_huffman.o \
	$(OBJDIR)/c_libs_bcl_lz.o \
	$(OBJDIR)/c_libs_bcl_rice.o \
	$(OBJDIR)/c_libs_bcl_rle.o \
	$(OBJDIR)/c_libs_bcl_shannonfano.o \
	$(OBJDIR)/c_libs_blosc_blosclz.o \
	$(OBJDIR)/c_libs_blosc_fastcopy.o \
	$(OBJDIR)/c_libs_brieflz_src_brieflz.o \
	$(OBJDIR)/c_libs_brieflz_src_depacks.o \
	$(OBJDIR)/c_libs_brotli_common_constants.o \
	$(OBJDIR)/c_libs_brotli_common_context.o \
	$(OBJDIR)/c_libs_brotli_common_dictionary.o \
	$(OBJDIR)/c_libs_brotli_common_platform.o \
	$(OBJDIR)/c_libs_brotli_common_transform.o \
	$(OBJDIR)/c_libs_brotli_dec_bit_reader.o \
	$(OBJDIR)/c_libs_brotli_dec_decode.o \
	$(OBJDIR)/c_libs_brotli_dec_huffman.o \
	$(OBJDIR)/c_libs_brotli_dec_state.o \
	$(OBJDIR)/c_libs_brotli_enc_backward_references.o \
	$(OBJDIR)/c_libs_brotli_enc_backward_references_hq.o \
	$(OBJDIR)/c_libs_brotli_enc_bit_cost.o \
	$(OBJDIR)/c_libs_brotli_enc_block_splitter.o \
	$(OBJDIR)/c_libs_brotli_enc_brotli_bit_stream.o \
	$(OBJDIR)/c_libs_brotli_enc_cluster.o \
	$(OBJDIR)/c_libs_brotli_enc_command.o \
	$(OBJDIR)/c_libs_brotli_enc_compress_fragment.o \
	$(OBJDIR)/c_libs_brotli_enc_compress_fragment_two_pass.o \
	$(OBJDIR)/c_libs_brotli_enc_dictionary_hash.o \
	$(OBJDIR)/c_libs_brotli_enc_encode.o \
	$(OBJDIR)/c_libs_brotli_enc_encoder_dict.o \
	$(OBJDIR)/c_libs_brotli_enc_entropy_encode.o \
	$(OBJDIR)/c_libs_brotli_enc_fast_log.o \
	$(OBJDIR)/c_libs_brotli_enc_histogram.o \
	$(OBJDIR)/c_libs_brotli_enc_literal_cost.o \
	$(OBJDIR)/c_libs_brotli_enc_memory.o \
	$(OBJDIR)/c_libs_brotli_enc_metablock.o \
	$(OBJDIR)/c_libs_brotli_enc_static_dict.o \
	$(OBJDIR)/c_libs_brotli_enc_utf8_util.o \
	$(OBJDIR)/c_libs_bzip2_blocksort.o \
	$(OBJDIR)/c_libs_bzip2_bzlib.o \
	$(OBJDIR)/c_libs_bzip2_compress.o \
	$(OBJDIR)/c_libs_bzip2_crctable.o \
	$(OBJDIR)/c_libs_bzip2_decompress.o \
	$(OBJDIR)/c_libs_bzip2_huffman.o \
	$(OBJDIR)/c_libs_bzip2_randtable.o \
	$(OBJDIR)/c_libs_capstone_arch_AArch64_AArch64BaseInfo.o \
	$(OBJDIR)/c_libs_capstone_arch_AArch64_AArch64Disassembler.o \
	$(OBJDIR)/c_libs_capstone_arch_AArch64_AArch64InstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_AArch64_AArch64Mapping.o \
	$(OBJDIR)/c_libs_capstone_arch_AArch64_AArch64Module.o \
	$(OBJDIR)/c_libs_capstone_arch_ARM_ARMDisassembler.o \
	$(OBJDIR)/c_libs_capstone_arch_ARM_ARMInstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_ARM_ARMMapping.o \
	$(OBJDIR)/c_libs_capstone_arch_ARM_ARMModule.o \
	$(OBJDIR)/c_libs_capstone_arch_Mips_MipsDisassembler.o \
	$(OBJDIR)/c_libs_capstone_arch_Mips_MipsInstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_Mips_MipsMapping.o \
	$(OBJDIR)/c_libs_capstone_arch_Mips_MipsModule.o \
	$(OBJDIR)/c_libs_capstone_arch_PowerPC_PPCDisassembler.o \
	$(OBJDIR)/c_libs_capstone_arch_PowerPC_PPCInstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_PowerPC_PPCMapping.o \
	$(OBJDIR)/c_libs_capstone_arch_PowerPC_PPCModule.o \
	$(OBJDIR)/c_libs_capstone_arch_Sparc_SparcDisassembler.o \
	$(OBJDIR)/c_libs_capstone_arch_Sparc_SparcInstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_Sparc_SparcMapping.o \
	$(OBJDIR)/c_libs_capstone_arch_Sparc_SparcModule.o \
	$(OBJDIR)/c_libs_capstone_arch_SystemZ_SystemZDisassembler.o \
	$(OBJDIR)/c_libs_capstone_arch_SystemZ_SystemZInstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_SystemZ_SystemZMapping.o \
	$(OBJDIR)/c_libs_capstone_arch_SystemZ_SystemZMCTargetDesc.o \
	$(OBJDIR)/c_libs_capstone_arch_SystemZ_SystemZModule.o \
	$(OBJDIR)/c_libs_capstone_arch_X86_X86ATTInstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_X86_X86Disassembler.o \
	$(OBJDIR)/c_libs_capstone_arch_X86_X86DisassemblerDecoder.o \
	$(OBJDIR)/c_libs_capstone_arch_X86_X86IntelInstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_X86_X86Mapping.o \
	$(OBJDIR)/c_libs_capstone_arch_X86_X86Module.o \
	$(OBJDIR)/c_libs_capstone_arch_XCore_XCoreDisassembler.o \
	$(OBJDIR)/c_libs_capstone_arch_XCore_XCoreInstPrinter.o \
	$(OBJDIR)/c_libs_capstone_arch_XCore_XCoreMapping.o \
	$(OBJDIR)/c_libs_capstone_arch_XCore_XCoreModule.o \
	$(OBJDIR)/c_libs_capstone_cs.o \
	$(OBJDIR)/c_libs_capstone_MCInst.o \
	$(OBJDIR)/c_libs_capstone_MCInstrDesc.o \
	$(OBJDIR)/c_libs_capstone_MCRegisterInfo.o \
	$(OBJDIR)/c_libs_capstone_SStream.o \
	$(OBJDIR)/c_libs_capstone_utils.o \
	$(OBJDIR)/c_libs_clzw_lzw-dec.o \
	$(OBJDIR)/c_libs_clzw_lzw-enc.o \
	$(OBJDIR)/c_libs_cryptohash-sha1_sha1.o \
	$(OBJDIR)/c_libs_ctw_ctw-header.o \
	$(OBJDIR)/c_libs_ctw_ctw-settings.o \
	$(OBJDIR)/c_libs_ctw_ctwencdec.o \
	$(OBJDIR)/c_libs_ctw_ctwlarc.o \
	$(OBJDIR)/c_libs_ctw_ctwmath.o \
	$(OBJDIR)/c_libs_ctw_ctwstep.o \
	$(OBJDIR)/c_libs_ctw_ctwtree.o \
	$(OBJDIR)/c_libs_density_src_algorithms_algorithms.o \
	$(OBJDIR)/c_libs_density_src_algorithms_chameleon_core_chameleon_decode.o \
	$(OBJDIR)/c_libs_density_src_algorithms_chameleon_core_chameleon_encode.o \
	$(OBJDIR)/c_libs_density_src_algorithms_cheetah_core_cheetah_decode.o \
	$(OBJDIR)/c_libs_density_src_algorithms_cheetah_core_cheetah_encode.o \
	$(OBJDIR)/c_libs_density_src_algorithms_dictionaries.o \
	$(OBJDIR)/c_libs_density_src_algorithms_lion_core_lion_decode.o \
	$(OBJDIR)/c_libs_density_src_algorithms_lion_core_lion_encode.o \
	$(OBJDIR)/c_libs_density_src_algorithms_lion_forms_lion_form_model.o \
	$(OBJDIR)/c_libs_density_src_buffers_buffer.o \
	$(OBJDIR)/c_libs_density_src_globals.o \
	$(OBJDIR)/c_libs_density_src_structure_header.o \
	$(OBJDIR)/c_libs_dipperstein_adapt.o \
	$(OBJDIR)/c_libs_dipperstein_arcode.o \
	$(OBJDIR)/c_libs_dipperstein_bitarray.o \
	$(OBJDIR)/c_libs_dipperstein_bitfile.o \
	$(OBJDIR)/c_libs_dipperstein_canonical.o \
	$(OBJDIR)/c_libs_dipperstein_delta.o \
	$(OBJDIR)/c_libs_dipperstein_freqsub.o \
	$(OBJDIR)/c_libs_dipperstein_huffman.o \
	$(OBJDIR)/c_libs_dipperstein_huflocal.o \
	$(OBJDIR)/c_libs_dipperstein_kmp.o \
	$(OBJDIR)/c_libs_dipperstein_lzss.o \
	$(OBJDIR)/c_libs_dipperstein_lzwdecode.o \
	$(OBJDIR)/c_libs_dipperstein_lzwencode.o \
	$(OBJDIR)/c_libs_dipperstein_rice.o \
	$(OBJDIR)/c_libs_dipperstein_rle.o \
	$(OBJDIR)/c_libs_dipperstein_vpackbits.o \
	$(OBJDIR)/c_libs_dmsdos_dblspace_dec.o \
	$(OBJDIR)/c_libs_dmsdos_dstacker_dec.o \
	$(OBJDIR)/c_libs_exodecrunch_exodecr.o \
	$(OBJDIR)/c_libs_exodecrunch_exodecrunch.o \
	$(OBJDIR)/c_libs_glza_GLZAmodel.o \
	$(OBJDIR)/c_libs_grzip_libgrzip.o \
	$(OBJDIR)/c_libs_heatshrink_heatshrink_decoder.o \
	$(OBJDIR)/c_libs_heatshrink_heatshrink_encoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_crc16.o \
	$(OBJDIR)/c_libs_lhasa_lib_lh1_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_lh5_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_lh6_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_lh7_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_lha_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_lhx_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_lh_new_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_lz5_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_lzs_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_null_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_pm1_decoder.o \
	$(OBJDIR)/c_libs_lhasa_lib_pm2_decoder.o \
	$(OBJDIR)/c_libs_libdivsufsort_divsufsort.o \
	$(OBJDIR)/c_libs_libkirk_crypto.o \
	$(OBJDIR)/c_libs_libkirk_kirk_engine.o \
	$(OBJDIR)/c_libs_liblzf_lzf_c_best.o \
	$(OBJDIR)/c_libs_liblzf_lzf_d.o \
	$(OBJDIR)/c_libs_liblzg_src_lib_checksum.o \
	$(OBJDIR)/c_libs_liblzg_src_lib_decode.o \
	$(OBJDIR)/c_libs_liblzg_src_lib_encode.o \
	$(OBJDIR)/c_libs_liblzs_lzs-compression.o \
	$(OBJDIR)/c_libs_liblzs_lzs-decompression.o \
	$(OBJDIR)/c_libs_lizard_lizard_compress.o \
	$(OBJDIR)/c_libs_lizard_lizard_decompress.o \
	$(OBJDIR)/c_libs_lizard_lizard_frame.o \
	$(OBJDIR)/c_libs_lua_src_lapi.o \
	$(OBJDIR)/c_libs_lua_src_lauxlib.o \
	$(OBJDIR)/c_libs_lua_src_lbaselib.o \
	$(OBJDIR)/c_libs_lua_src_lbitlib.o \
	$(OBJDIR)/c_libs_lua_src_lcode.o \
	$(OBJDIR)/c_libs_lua_src_lcorolib.o \
	$(OBJDIR)/c_libs_lua_src_lctype.o \
	$(OBJDIR)/c_libs_lua_src_ldblib.o \
	$(OBJDIR)/c_libs_lua_src_ldebug.o \
	$(OBJDIR)/c_libs_lua_src_ldo.o \
	$(OBJDIR)/c_libs_lua_src_ldump.o \
	$(OBJDIR)/c_libs_lua_src_lfunc.o \
	$(OBJDIR)/c_libs_lua_src_lgc.o \
	$(OBJDIR)/c_libs_lua_src_linit.o \
	$(OBJDIR)/c_libs_lua_src_liolib.o \
	$(OBJDIR)/c_libs_lua_src_llex.o \
	$(OBJDIR)/c_libs_lua_src_lmathlib.o \
	$(OBJDIR)/c_libs_lua_src_lmem.o \
	$(OBJDIR)/c_libs_lua_src_loadlib.o \
	$(OBJDIR)/c_libs_lua_src_lobject.o \
	$(OBJDIR)/c_libs_lua_src_lopcodes.o \
	$(OBJDIR)/c_libs_lua_src_loslib.o \
	$(OBJDIR)/c_libs_lua_src_lparser.o \
	$(OBJDIR)/c_libs_lua_src_lstate.o \
	$(OBJDIR)/c_libs_lua_src_lstring.o \
	$(OBJDIR)/c_libs_lua_src_lstrlib.o \
	$(OBJDIR)/c_libs_lua_src_ltable.o \
	$(OBJDIR)/c_libs_lua_src_ltablib.o \
	$(OBJDIR)/c_libs_lua_src_ltm.o \
	$(OBJDIR)/c_libs_lua_src_lundump.o \
	$(OBJDIR)/c_libs_lua_src_lutf8lib.o \
	$(OBJDIR)/c_libs_lua_src_lvm.o \
	$(OBJDIR)/c_libs_lua_src_lzio.o \
	$(OBJDIR)/c_libs_lz4_lz4.o \
	$(OBJDIR)/c_libs_lz4_lz4file.o \
	$(OBJDIR)/c_libs_lz4_lz4frame.o \
	$(OBJDIR)/c_libs_lz4_lz4hc.o \
	$(OBJDIR)/c_libs_lz5_lz5.o \
	$(OBJDIR)/c_libs_lz5_lz5frame.o \
	$(OBJDIR)/c_libs_lz5_lz5hc.o \
	$(OBJDIR)/c_libs_lzfse_src_lzfse_decode.o \
	$(OBJDIR)/c_libs_lzfse_src_lzfse_decode_base.o \
	$(OBJDIR)/c_libs_lzfse_src_lzfse_encode.o \
	$(OBJDIR)/c_libs_lzfse_src_lzfse_encode_base.o \
	$(OBJDIR)/c_libs_lzfse_src_lzfse_fse.o \
	$(OBJDIR)/c_libs_lzfse_src_lzvn_decode_base.o \
	$(OBJDIR)/c_libs_lzfse_src_lzvn_encode_base.o \
	$(OBJDIR)/c_libs_lzjody_byteplane_xfrm.o \
	$(OBJDIR)/c_libs_lzjody_lzjody.o \
	$(OBJDIR)/c_libs_lzlib_lzlib.o \
	$(OBJDIR)/c_libs_lzma_Bra86.o \
	$(OBJDIR)/c_libs_lzma_CpuArch.o \
	$(OBJDIR)/c_libs_lzma_LzFind.o \
	$(OBJDIR)/c_libs_lzma_Lzma2Dec.o \
	$(OBJDIR)/c_libs_lzma_Lzma2Enc.o \
	$(OBJDIR)/c_libs_lzma_LzmaDec.o \
	$(OBJDIR)/c_libs_lzma_LzmaEnc.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1a.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1a_99.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_3.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_4.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_5.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_6.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_7.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_8.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_9.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_99.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_9x.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_cc.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_d1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_d2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_rr.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1b_xx.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_3.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_4.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_5.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_6.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_7.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_8.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_9.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_99.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_9x.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_cc.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_d1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_d2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_rr.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1c_xx.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1f_1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1f_9x.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1f_d1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1f_d2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_1k.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_1l.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_1o.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_9x.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_d1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_d2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_d3.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1x_o.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1y_1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1y_9x.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1y_d1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1y_d2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1y_d3.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1y_o.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1z_9x.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1z_d1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1z_d2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1z_d3.o \
	$(OBJDIR)/c_libs_lzo_src_lzo1_99.o \
	$(OBJDIR)/c_libs_lzo_src_lzo2a_9x.o \
	$(OBJDIR)/c_libs_lzo_src_lzo2a_d1.o \
	$(OBJDIR)/c_libs_lzo_src_lzo2a_d2.o \
	$(OBJDIR)/c_libs_lzo_src_lzo_crc.o \
	$(OBJDIR)/c_libs_lzo_src_lzo_init.o \
	$(OBJDIR)/c_libs_lzo_src_lzo_ptr.o \
	$(OBJDIR)/c_libs_lzo_src_lzo_str.o \
	$(OBJDIR)/c_libs_lzo_src_lzo_util.o \
	$(OBJDIR)/c_libs_lzw-ab_lzw-lib.o \
	$(OBJDIR)/c_libs_mmini_mmini_huffman.o \
	$(OBJDIR)/c_libs_mmini_mmini_lzl.o \
	$(OBJDIR)/c_libs_mspack_lzssd.o \
	$(OBJDIR)/c_libs_mspack_lzxd.o \
	$(OBJDIR)/c_libs_mspack_mslzhd.o \
	$(OBJDIR)/c_libs_mspack_mszipd.o \
	$(OBJDIR)/c_libs_mspack_qtmd.o \
	$(OBJDIR)/c_libs_mydownlib_mydownlib.o \
	$(OBJDIR)/c_libs_nintendo_ds_blz.o \
	$(OBJDIR)/c_libs_nintendo_ds_huffman.o \
	$(OBJDIR)/c_libs_nintendo_ds_lze.o \
	$(OBJDIR)/c_libs_nintendo_ds_lzss.o \
	$(OBJDIR)/c_libs_nintendo_ds_lzx.o \
	$(OBJDIR)/c_libs_nintendo_ds_mem2mem.o \
	$(OBJDIR)/c_libs_nintendo_ds_rle.o \
	$(OBJDIR)/c_libs_old_cabextract_lzx.o \
	$(OBJDIR)/c_libs_PKLib_explode.o \
	$(OBJDIR)/c_libs_PKLib_implode.o \
	$(OBJDIR)/c_libs_ppmd_7zip_Ppmd7.o \
	$(OBJDIR)/c_libs_ppmd_7zip_Ppmd7Dec.o \
	$(OBJDIR)/c_libs_ppmd_7zip_Ppmd7Enc.o \
	$(OBJDIR)/c_libs_ppmd_7zip_Ppmd8.o \
	$(OBJDIR)/c_libs_ppmd_7zip_Ppmd8Dec.o \
	$(OBJDIR)/c_libs_ppmd_7zip_Ppmd8Enc.o \
	$(OBJDIR)/c_libs_ppmz2_CrbList.o \
	$(OBJDIR)/c_libs_shoco_shoco.o \
	$(OBJDIR)/c_libs_sphlib_c_blake.o \
	$(OBJDIR)/c_libs_sphlib_c_bmw.o \
	$(OBJDIR)/c_libs_sphlib_c_cubehash.o \
	$(OBJDIR)/c_libs_sphlib_c_echo.o \
	$(OBJDIR)/c_libs_sphlib_c_fugue.o \
	$(OBJDIR)/c_libs_sphlib_c_groestl.o \
	$(OBJDIR)/c_libs_sphlib_c_hamsi.o \
	$(OBJDIR)/c_libs_sphlib_c_haval.o \
	$(OBJDIR)/c_libs_sphlib_c_jh.o \
	$(OBJDIR)/c_libs_sphlib_c_keccak.o \
	$(OBJDIR)/c_libs_sphlib_c_luffa.o \
	$(OBJDIR)/c_libs_sphlib_c_md2.o \
	$(OBJDIR)/c_libs_sphlib_c_md4.o \
	$(OBJDIR)/c_libs_sphlib_c_md5.o \
	$(OBJDIR)/c_libs_sphlib_c_panama.o \
	$(OBJDIR)/c_libs_sphlib_c_radiogatun.o \
	$(OBJDIR)/c_libs_sphlib_c_ripemd.o \
	$(OBJDIR)/c_libs_sphlib_c_sha0.o \
	$(OBJDIR)/c_libs_sphlib_c_sha1.o \
	$(OBJDIR)/c_libs_sphlib_c_sha2.o \
	$(OBJDIR)/c_libs_sphlib_c_sha2big.o \
	$(OBJDIR)/c_libs_sphlib_c_sha3nist.o \
	$(OBJDIR)/c_libs_sphlib_c_shabal.o \
	$(OBJDIR)/c_libs_sphlib_c_shavite.o \
	$(OBJDIR)/c_libs_sphlib_c_simd.o \
	$(OBJDIR)/c_libs_sphlib_c_skein.o \
	$(OBJDIR)/c_libs_sphlib_c_tiger.o \
	$(OBJDIR)/c_libs_sphlib_c_whirlpool.o \
	$(OBJDIR)/c_libs_spookyhash_context.o \
	$(OBJDIR)/c_libs_spookyhash_spookyhash.o \
	$(OBJDIR)/c_libs_szip_encoding.o \
	$(OBJDIR)/c_libs_szip_rice.o \
	$(OBJDIR)/c_libs_szip_sz_api.o \
	$(OBJDIR)/c_libs_tdcb_ahuff.o \
	$(OBJDIR)/c_libs_tdcb_arith-n.o \
	$(OBJDIR)/c_libs_tdcb_arith.o \
	$(OBJDIR)/c_libs_tdcb_arith1.o \
	$(OBJDIR)/c_libs_tdcb_arith1e.o \
	$(OBJDIR)/c_libs_tdcb_compand.o \
	$(OBJDIR)/c_libs_tdcb_huff.o \
	$(OBJDIR)/c_libs_tdcb_lzss.o \
	$(OBJDIR)/c_libs_tdcb_lzw12.o \
	$(OBJDIR)/c_libs_tdcb_lzw15v.o \
	$(OBJDIR)/c_libs_tdcb_mn_incs.o \
	$(OBJDIR)/c_libs_tdcb_silence.o \
	$(OBJDIR)/c_libs_tdcb__lzss.o \
	$(OBJDIR)/c_libs_tiny-regex-c_re.o \
	$(OBJDIR)/c_libs_TurboRLE_ext_mrle.o \
	$(OBJDIR)/c_libs_TurboRLE_trlec.o \
	$(OBJDIR)/c_libs_TurboRLE_trled.o \
	$(OBJDIR)/c_libs_ucl_src_alloc.o \
	$(OBJDIR)/c_libs_ucl_src_n2b_99.o \
	$(OBJDIR)/c_libs_ucl_src_n2b_d.o \
	$(OBJDIR)/c_libs_ucl_src_n2b_ds.o \
	$(OBJDIR)/c_libs_ucl_src_n2b_to.o \
	$(OBJDIR)/c_libs_ucl_src_n2d_99.o \
	$(OBJDIR)/c_libs_ucl_src_n2d_d.o \
	$(OBJDIR)/c_libs_ucl_src_n2d_ds.o \
	$(OBJDIR)/c_libs_ucl_src_n2d_to.o \
	$(OBJDIR)/c_libs_ucl_src_n2e_99.o \
	$(OBJDIR)/c_libs_ucl_src_n2e_d.o \
	$(OBJDIR)/c_libs_ucl_src_n2e_ds.o \
	$(OBJDIR)/c_libs_ucl_src_n2e_to.o \
	$(OBJDIR)/c_libs_xxhash_xxhash.o \
	$(OBJDIR)/c_libs_zlib_adler32.o \
	$(OBJDIR)/c_libs_zlib_compress.o \
	$(OBJDIR)/c_libs_zlib_contrib_infback9_infback9.o \
	$(OBJDIR)/c_libs_zlib_contrib_infback9_inftree9.o \
	$(OBJDIR)/c_libs_zlib_crc32.o \
	$(OBJDIR)/c_libs_zlib_deflate.o \
	$(OBJDIR)/c_libs_zlib_gzclose.o \
	$(OBJDIR)/c_libs_zlib_gzlib.o \
	$(OBJDIR)/c_libs_zlib_gzread.o \
	$(OBJDIR)/c_libs_zlib_gzwrite.o \
	$(OBJDIR)/c_libs_zlib_infback.o \
	$(OBJDIR)/c_libs_zlib_inffast.o \
	$(OBJDIR)/c_libs_zlib_inflate.o \
	$(OBJDIR)/c_libs_zlib_inftrees.o \
	$(OBJDIR)/c_libs_zlib_trees.o \
	$(OBJDIR)/c_libs_zlib_uncompr.o \
	$(OBJDIR)/c_libs_zlib_zutil.o \
	$(OBJDIR)/c_libs_zopfli_blocksplitter.o \
	$(OBJDIR)/c_libs_zopfli_cache.o \
	$(OBJDIR)/c_libs_zopfli_deflate.o \
	$(OBJDIR)/c_libs_zopfli_gzip_container.o \
	$(OBJDIR)/c_libs_zopfli_hash.o \
	$(OBJDIR)/c_libs_zopfli_katajainen.o \
	$(OBJDIR)/c_libs_zopfli_lz77.o \
	$(OBJDIR)/c_libs_zopfli_squeeze.o \
	$(OBJDIR)/c_libs_zopfli_tree.o \
	$(OBJDIR)/c_libs_zopfli_util.o \
	$(OBJDIR)/c_libs_zopfli_zlib_container.o \
	$(OBJDIR)/c_libs_zopfli_zopfli_lib.o \
	$(OBJDIR)/c_libs_zstd_aluigi_common_debug.o \
	$(OBJDIR)/c_libs_zstd_aluigi_common_entropy_common.o \
	$(OBJDIR)/c_libs_zstd_aluigi_common_error_private.o \
	$(OBJDIR)/c_libs_zstd_aluigi_common_fse_decompress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_common_pool.o \
	$(OBJDIR)/c_libs_zstd_aluigi_common_threading.o \
	$(OBJDIR)/c_libs_zstd_aluigi_common_zstd_common.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_fse_compress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_hist.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_huf_compress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstdmt_compress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_compress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_compress_literals.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_compress_sequences.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_compress_superblock.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_double_fast.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_fast.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_lazy.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_ldm.o \
	$(OBJDIR)/c_libs_zstd_aluigi_compress_zstd_opt.o \
	$(OBJDIR)/c_libs_zstd_aluigi_decompress_huf_decompress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_decompress_zstd_ddict.o \
	$(OBJDIR)/c_libs_zstd_aluigi_decompress_zstd_decompress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_decompress_zstd_decompress_block.o \
	$(OBJDIR)/c_libs_zstd_aluigi_deprecated_zbuff_common.o \
	$(OBJDIR)/c_libs_zstd_aluigi_deprecated_zbuff_compress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_deprecated_zbuff_decompress.o \
	$(OBJDIR)/c_libs_zstd_aluigi_dictBuilder_cover.o \
	$(OBJDIR)/c_libs_zstd_aluigi_dictBuilder_fastcover.o \
	$(OBJDIR)/c_libs_zstd_aluigi_dictBuilder_zdict.o \
	$(OBJDIR)/c_libs_zstd_aluigi_legacy_zstd_v01.o \
	$(OBJDIR)/c_libs_zstd_aluigi_legacy_zstd_v02.o \
	$(OBJDIR)/c_libs_zstd_aluigi_legacy_zstd_v03.o \
	$(OBJDIR)/c_libs_zstd_aluigi_legacy_zstd_v04.o \
	$(OBJDIR)/c_libs_zstd_aluigi_legacy_zstd_v05.o \
	$(OBJDIR)/c_libs_zstd_aluigi_legacy_zstd_v06.o \
	$(OBJDIR)/c_libs_zstd_aluigi_legacy_zstd_v07.o \
	$(OBJDIR)/c_libs_zziplib_block.o \
	$(OBJDIR)/c_libs_zziplib_bwt.o \
	$(OBJDIR)/c_libs_zziplib_coding.o \
	$(OBJDIR)/c_libs_zziplib_struct_model0.o \
	$(OBJDIR)/c_libs_zziplib_struct_model1.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_7zdeflate.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_7zlzma.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_AriBitCoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_CRC.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_DeflateDecoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_DeflateEncoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_HuffmanEncoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_IInOutStreams.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_InByte.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_LenCoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_LiteralCoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_LSBFDecoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_LSBFEncoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_LZMA.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_LZMADecoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_LZMAEncoder.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_OutByte.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_WindowIn.o \
	$(OBJDIR)/cc_libs_7z_advancecomp_WindowOut.o \
	$(OBJDIR)/cc_libs_gipfeli_decompress.o \
	$(OBJDIR)/cc_libs_gipfeli_entropy.o \
	$(OBJDIR)/cc_libs_gipfeli_entropy_code_builder.o \
	$(OBJDIR)/cc_libs_gipfeli_gipfeli-internal.o \
	$(OBJDIR)/cc_libs_gipfeli_lz77.o \
	$(OBJDIR)/cc_libs_snappy_snappy-c.o \
	$(OBJDIR)/cc_libs_snappy_snappy-sinksource.o \
	$(OBJDIR)/cc_libs_snappy_snappy-stubs-internal.o \
	$(OBJDIR)/cc_libs_snappy_snappy.o \
	$(OBJDIR)/cpp_libs_azo_Common_x86Filter.o \
	$(OBJDIR)/cpp_libs_azo_Decoder_MainCodeD.o \
	$(OBJDIR)/cpp_libs_azo_unAZO.o \
	$(OBJDIR)/cpp_libs_doboz_Compressor.o \
	$(OBJDIR)/cpp_libs_doboz_Decompressor.o \
	$(OBJDIR)/cpp_libs_doboz_Dictionary.o \
	$(OBJDIR)/cpp_libs_hsel_HSEL.o \
	$(OBJDIR)/cpp_libs_hsel_myhsel.o \
	$(OBJDIR)/cpp_libs_iris_iris_btree.o \
	$(OBJDIR)/cpp_libs_iris_iris_decompress.o \
	$(OBJDIR)/cpp_libs_iris_iris_huffman.o \
	$(OBJDIR)/cpp_libs_iris_iris_uo_huffman.o \
	$(OBJDIR)/cpp_libs_libbsc_adler32_adler32.o \
	$(OBJDIR)/cpp_libs_libbsc_bwt_bwt.o \
	$(OBJDIR)/cpp_libs_libbsc_coder_coder.o \
	$(OBJDIR)/cpp_libs_libbsc_coder_qlfc_qlfc.o \
	$(OBJDIR)/cpp_libs_libbsc_coder_qlfc_qlfc_model.o \
	$(OBJDIR)/cpp_libs_libbsc_filters_detectors.o \
	$(OBJDIR)/cpp_libs_libbsc_filters_preprocessing.o \
	$(OBJDIR)/cpp_libs_libbsc_libbsc_libbsc.o \
	$(OBJDIR)/cpp_libs_libbsc_lzp_lzp.o \
	$(OBJDIR)/cpp_libs_libbsc_platform_platform.o \
	$(OBJDIR)/cpp_libs_libbsc_st_st.o \
	$(OBJDIR)/cpp_libs_libcsc_csc_dec.o \
	$(OBJDIR)/cpp_libs_libcsc_csc_default_alloc.o \
	$(OBJDIR)/cpp_libs_libcsc_csc_filters.o \
	$(OBJDIR)/cpp_libs_libcsc_csc_memio.o \
	$(OBJDIR)/cpp_libs_libzling_libzling.o \
	$(OBJDIR)/cpp_libs_libzling_libzling_debug.o \
	$(OBJDIR)/cpp_libs_libzling_libzling_huffman.o \
	$(OBJDIR)/cpp_libs_libzling_libzling_lz.o \
	$(OBJDIR)/cpp_libs_libzling_libzling_utils.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamcomp_lzham_lzbase.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamcomp_lzham_lzcomp.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamcomp_lzham_lzcomp_internal.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamcomp_lzham_lzcomp_state.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamcomp_lzham_match_accel.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamcomp_lzham_pthreads_threading.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamcomp_lzham_win32_threading.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_assert.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_checksum.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_huffman_codes.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_lzdecomp.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_lzdecompbase.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_mem.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_platform.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_prefix_coding.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_symbol_codec.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_timer.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_lzham_vector.o \
	$(OBJDIR)/cpp_libs_lzham_codec_lzhamlib_lzham_lib.o \
	$(OBJDIR)/cpp_libs_lzhl_HuffStat.o \
	$(OBJDIR)/cpp_libs_lzhl_HuffStatTmp.o \
	$(OBJDIR)/cpp_libs_lzhl_LZBuffer.o \
	$(OBJDIR)/cpp_libs_lzhl_LZHL.o \
	$(OBJDIR)/cpp_libs_lzhl_LZHLCompressor.o \
	$(OBJDIR)/cpp_libs_lzhl_LZHLDecoderStat.o \
	$(OBJDIR)/cpp_libs_lzhl_LZHLDecompressor.o \
	$(OBJDIR)/cpp_libs_lzhl_LZHLEncoder.o \
	$(OBJDIR)/cpp_libs_lzhl_LZHLEncoderStat.o \
	$(OBJDIR)/cpp_libs_mrci_GrowBuf.o \
	$(OBJDIR)/cpp_libs_mrci_MRCI.o \
	$(OBJDIR)/cpp_libs_ms-compress_src_lznt1_compress.o \
	$(OBJDIR)/cpp_libs_ms-compress_src_lznt1_decompress.o \
	$(OBJDIR)/cpp_libs_ms-compress_src_mscomp.o \
	$(OBJDIR)/cpp_libs_ms-compress_src_xpress_compress.o \
	$(OBJDIR)/cpp_libs_ms-compress_src_xpress_decompress.o \
	$(OBJDIR)/cpp_libs_ms-compress_src_xpress_huff_compress.o \
	$(OBJDIR)/cpp_libs_ms-compress_src_xpress_huff_decompress.o \
	$(OBJDIR)/cpp_libs_ppmd_unppmdg.o \
	$(OBJDIR)/cpp_libs_ppmd_unppmdj.o \
	$(OBJDIR)/cpp_libs_ppmz2_ArithInfo.o \
	$(OBJDIR)/cpp_libs_ppmz2_Coder.o \
	$(OBJDIR)/cpp_libs_ppmz2_CodingMetrics.o \
	$(OBJDIR)/cpp_libs_ppmz2_Context.o \
	$(OBJDIR)/cpp_libs_ppmz2_ContextData.o \
	$(OBJDIR)/cpp_libs_ppmz2_ContextTrie.o \
	$(OBJDIR)/cpp_libs_ppmz2_Exclude.o \
	$(OBJDIR)/cpp_libs_ppmz2_LocalOrderEstimation.o \
	$(OBJDIR)/cpp_libs_ppmz2_PpmDet.o \
	$(OBJDIR)/cpp_libs_ppmz2_PPMZ2.o \
	$(OBJDIR)/cpp_libs_ppmz2_PpmzEsc.o \
	$(OBJDIR)/cpp_libs_ppmz2_See.o \
	$(OBJDIR)/cpp_libs_ppmz2_Stdafx.o \
	$(OBJDIR)/cpp_libs_ppmz2_Stopwatch.o \
	$(OBJDIR)/cpp_libs_shadowforce_BHUT.o \
	$(OBJDIR)/cpp_libs_shadowforce_Bitstream.o \
	$(OBJDIR)/cpp_libs_shadowforce_Compress.o \
	$(OBJDIR)/cpp_libs_shadowforce_ELSCoder.o \
	$(OBJDIR)/cpp_libs_shadowforce_LZ77.o \
	$(OBJDIR)/cpp_libs_shadowforce_RefPack.o \
	$(OBJDIR)/cpp_libs_shadowforce_shadowforce.o \
	$(OBJDIR)/cpp_libs_tornado_Common.o \
	$(OBJDIR)/cpp_libs_tornado_Tornado.o

OBJS_BMS := \
	$(OBJDIR)/c_quickbms.o

STATIC_ALL := \
	$(OBJDIR)/libs.a \
	$(OBJDIR)/extra.a \
	$(OBJDIR)/disasm.a \
	$(OBJDIR)/compression.a \
	$(OBJDIR)/encryption.a \
	$(OBJDIR)/bms.a

## 
# how to build
##

$(OBJDIR)/c_compression_%.o:
	$(CC) -c $(SRCDIR)/compression/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/cc_compression_%.o:
	$(CXX) -c $(SRCDIR)/compression/$*.cc $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_compression_%.o:
	$(CXX) -c $(SRCDIR)/compression/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/c_disasm_%.o:
	$(CC) -c $(SRCDIR)/disasm/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_disasm_assembl_%.o:
	$(CC) -c $(SRCDIR)/disasm/assembl/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_encryption_%.o:
	$(CC) -c $(SRCDIR)/encryption/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/cc_encryption_%.o:
	$(CXX) -c $(SRCDIR)/encryption/$*.cc $(CXXFLAGS) -o $@

$(OBJDIR)/c_extra_%.o:
	$(CC) -c $(SRCDIR)/extra/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_included_%.o:
	$(CC) -c $(SRCDIR)/included/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/cpp_included_%.o:
	$(CXX) -c $(SRCDIR)/included/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/c_io_%.o:
	$(CC) -c $(SRCDIR)/io/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_aplib_src_%.o:
	$(CC) -c $(SRCDIR)/libs/aplib/src/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_bcl_%.o:
	$(CC) -c $(SRCDIR)/libs/bcl/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_blosc_%.o:
	$(CC) -c $(SRCDIR)/libs/blosc/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_brieflz_src_%.o:
	$(CC) -c $(SRCDIR)/libs/brieflz/src/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_brotli_common_%.o:
	$(CC) -c $(SRCDIR)/libs/brotli/common/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_brotli_dec_%.o:
	$(CC) -c $(SRCDIR)/libs/brotli/dec/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_brotli_enc_%.o:
	$(CC) -c $(SRCDIR)/libs/brotli/enc/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_bzip2_%.o:
	$(CC) -c $(SRCDIR)/libs/bzip2/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_arch_AArch64_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/arch/AArch64/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_arch_ARM_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/arch/ARM/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_arch_Mips_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/arch/Mips/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_arch_PowerPC_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/arch/PowerPC/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_arch_Sparc_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/arch/Sparc/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_arch_SystemZ_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/arch/SystemZ/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_arch_X86_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/arch/X86/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_capstone_arch_XCore_%.o:
	$(CC) -c $(SRCDIR)/libs/capstone/arch/XCore/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_clzw_%.o:
	$(CC) -c $(SRCDIR)/libs/clzw/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_cryptohash-sha1_%.o:
	$(CC) -c $(SRCDIR)/libs/cryptohash-sha1/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_ctw_%.o:
	$(CC) -c $(SRCDIR)/libs/ctw/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_density_src_%.o:
	$(CC) -c $(SRCDIR)/libs/density/src/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_density_src_algorithms_%.o:
	$(CC) -c $(SRCDIR)/libs/density/src/algorithms/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_density_src_algorithms_chameleon_core_%.o:
	$(CC) -c $(SRCDIR)/libs/density/src/algorithms/chameleon/core/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_density_src_algorithms_cheetah_core_%.o:
	$(CC) -c $(SRCDIR)/libs/density/src/algorithms/cheetah/core/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_density_src_algorithms_lion_core_%.o:
	$(CC) -c $(SRCDIR)/libs/density/src/algorithms/lion/core/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_density_src_algorithms_lion_forms_%.o:
	$(CC) -c $(SRCDIR)/libs/density/src/algorithms/lion/forms/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_density_src_buffers_%.o:
	$(CC) -c $(SRCDIR)/libs/density/src/buffers/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_density_src_structure_%.o:
	$(CC) -c $(SRCDIR)/libs/density/src/structure/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_dipperstein_%.o:
	$(CC) -c $(SRCDIR)/libs/dipperstein/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_dmsdos_%.o:
	$(CC) -c $(SRCDIR)/libs/dmsdos/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_exodecrunch_%.o:
	$(CC) -c $(SRCDIR)/libs/exodecrunch/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_glza_%.o:
	$(CC) -c $(SRCDIR)/libs/glza/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_grzip_%.o:
	$(CC) -c $(SRCDIR)/libs/grzip/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_heatshrink_%.o:
	$(CC) -c $(SRCDIR)/libs/heatshrink/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lhasa_lib_%.o:
	$(CC) -c $(SRCDIR)/libs/lhasa/lib/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_libdivsufsort_%.o:
	$(CC) -c $(SRCDIR)/libs/libdivsufsort/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_libkirk_%.o:
	$(CC) -c $(SRCDIR)/libs/libkirk/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_liblzf_%.o:
	$(CC) -c $(SRCDIR)/libs/liblzf/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_liblzg_src_lib_%.o:
	$(CC) -c $(SRCDIR)/libs/liblzg/src/lib/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_liblzs_%.o:
	$(CC) -c $(SRCDIR)/libs/liblzs/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lizard_%.o:
	$(CC) -c $(SRCDIR)/libs/lizard/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lua_src_%.o:
	$(CC) -c $(SRCDIR)/libs/lua/src/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lz4_%.o:
	$(CC) -c $(SRCDIR)/libs/lz4/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lz5_%.o:
	$(CC) -c $(SRCDIR)/libs/lz5/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lzfse_src_%.o:
	$(CC) -c $(SRCDIR)/libs/lzfse/src/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lzjody_%.o:
	$(CC) -c $(SRCDIR)/libs/lzjody/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lzlib_%.o:
	$(CC) -c $(SRCDIR)/libs/lzlib/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lzma_%.o:
	$(CC) -c $(SRCDIR)/libs/lzma/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lzo_src_%.o:
	$(CC) -c $(SRCDIR)/libs/lzo/src/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_lzw-ab_%.o:
	$(CC) -c $(SRCDIR)/libs/lzw-ab/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_mmini_%.o:
	$(CC) -c $(SRCDIR)/libs/mmini/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_mspack_%.o:
	$(CC) -c $(SRCDIR)/libs/mspack/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_mydownlib_%.o:
	$(CC) -c $(SRCDIR)/libs/mydownlib/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_nintendo_ds_%.o:
	$(CC) -c $(SRCDIR)/libs/nintendo_ds/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_old_cabextract_%.o:
	$(CC) -c $(SRCDIR)/libs/old_cabextract/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_PKLib_%.o:
	$(CC) -c $(SRCDIR)/libs/PKLib/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_ppmd_7zip_%.o:
	$(CC) -c $(SRCDIR)/libs/ppmd_7zip/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_ppmz2_%.o:
	$(CC) -c $(SRCDIR)/libs/ppmz2/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_shoco_%.o:
	$(CC) -c $(SRCDIR)/libs/shoco/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_sphlib_c_%.o:
	$(CC) -c $(SRCDIR)/libs/sphlib/c/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_spookyhash_%.o:
	$(CC) -c $(SRCDIR)/libs/spookyhash/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_szip_%.o:
	$(CC) -c $(SRCDIR)/libs/szip/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_tdcb_%.o:
	$(CC) -c $(SRCDIR)/libs/tdcb/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_tiny-regex-c_%.o:
	$(CC) -c $(SRCDIR)/libs/tiny-regex-c/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_TurboRLE_%.o:
	$(CC) -c $(SRCDIR)/libs/TurboRLE/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_TurboRLE_ext_%.o:
	$(CC) -c $(SRCDIR)/libs/TurboRLE/ext/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_ucl_src_%.o:
	$(CC) -c $(SRCDIR)/libs/ucl/src/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_xxhash_%.o:
	$(CC) -c $(SRCDIR)/libs/xxhash/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zlib_%.o:
	$(CC) -c $(SRCDIR)/libs/zlib/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zlib_contrib_infback9_%.o:
	$(CC) -c $(SRCDIR)/libs/zlib/contrib/infback9/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zopfli_%.o:
	$(CC) -c $(SRCDIR)/libs/zopfli/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zstd_aluigi_common_%.o:
	$(CC) -c $(SRCDIR)/libs/zstd_aluigi/common/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zstd_aluigi_compress_%.o:
	$(CC) -c $(SRCDIR)/libs/zstd_aluigi/compress/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zstd_aluigi_decompress_%.o:
	$(CC) -c $(SRCDIR)/libs/zstd_aluigi/decompress/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zstd_aluigi_deprecated_%.o:
	$(CC) -c $(SRCDIR)/libs/zstd_aluigi/deprecated/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zstd_aluigi_dictBuilder_%.o:
	$(CC) -c $(SRCDIR)/libs/zstd_aluigi/dictBuilder/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zstd_aluigi_legacy_%.o:
	$(CC) -c $(SRCDIR)/libs/zstd_aluigi/legacy/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs_zziplib_%.o:
	$(CC) -c $(SRCDIR)/libs/zziplib/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/c_libs__lzhl_%.o:
	$(CC) -c $(SRCDIR)/libs/_lzhl/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/cc_libs_7z_advancecomp_%.o:
	$(CXX) -c $(SRCDIR)/libs/7z_advancecomp/$*.cc $(CXXFLAGS) -o $@

$(OBJDIR)/cc_libs_gipfeli_%.o:
	$(CXX) -c $(SRCDIR)/libs/gipfeli/$*.cc $(CXXFLAGS) -o $@

$(OBJDIR)/cc_libs_snappy_%.o:
	$(CXX) -c $(SRCDIR)/libs/snappy/$*.cc $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_azo_%.o:
	$(CXX) -c $(SRCDIR)/libs/azo/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_azo_Common_%.o:
	$(CXX) -c $(SRCDIR)/libs/azo/Common/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_azo_Decoder_%.o:
	$(CXX) -c $(SRCDIR)/libs/azo/Decoder/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_doboz_%.o:
	$(CXX) -c $(SRCDIR)/libs/doboz/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_hsel_%.o:
	$(CXX) -c $(SRCDIR)/libs/hsel/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_iris_%.o:
	$(CXX) -c $(SRCDIR)/libs/iris/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_adler32_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/adler32/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_bwt_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/bwt/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_coder_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/coder/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_coder_qlfc_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/coder/qlfc/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_filters_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/filters/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_libbsc_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/libbsc/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_lzp_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/lzp/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_platform_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/platform/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libbsc_st_%.o:
	$(CXX) -c $(SRCDIR)/libs/libbsc/st/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libcsc_%.o:
	$(CXX) -c $(SRCDIR)/libs/libcsc/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_libzling_%.o:
	$(CXX) -c $(SRCDIR)/libs/libzling/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_lzham_codec_lzhamcomp_%.o:
	$(CXX) -c $(SRCDIR)/libs/lzham_codec/lzhamcomp/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_lzham_codec_lzhamdecomp_%.o:
	$(CXX) -c $(SRCDIR)/libs/lzham_codec/lzhamdecomp/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_lzham_codec_lzhamlib_%.o:
	$(CXX) -c $(SRCDIR)/libs/lzham_codec/lzhamlib/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_lzhl_%.o:
	$(CXX) -c $(SRCDIR)/libs/lzhl/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_mrci_%.o:
	$(CXX) -c $(SRCDIR)/libs/mrci/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_ms-compress_src_%.o:
	$(CXX) -c $(SRCDIR)/libs/ms-compress/src/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_powzix_%.o:
	$(CXX) -c $(SRCDIR)/libs/powzix/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/s_libs_amiga_%.o:
	$(CC) -c $(SRCDIR)/libs/amiga/$*.s $(CCFLAGS) -I$(SRCDIR)/libs/amiga -o $@

$(OBJDIR)/cpp_libs_ppmd_%.o:
	$(CXX) -c $(SRCDIR)/libs/ppmd/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_ppmz2_%.o:
	$(CXX) -c $(SRCDIR)/libs/ppmz2/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_shadowforce_%.o:
	$(CXX) -c $(SRCDIR)/libs/shadowforce/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs_tornado_%.o:
	$(CXX) -c $(SRCDIR)/libs/tornado/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_libs__lzhl_%.o:
	$(CXX) -c $(SRCDIR)/libs/_lzhl/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/c_%.o:
	$(CC) -c $(SRCDIR)/$*.c $(CCFLAGS) -o $@

$(OBJDIR)/cc_%.o:
	$(CXX) -c $(SRCDIR)/$*.cc $(CXXFLAGS) -o $@

$(OBJDIR)/cpp_%.o:
	$(CXX) -c $(SRCDIR)/$*.cpp $(CXXFLAGS) -o $@

$(OBJDIR)/compression.a: $(OBJS_COMPRESSION)
	$(AR) cr $(OBJDIR)/compression.a $(OBJS_COMPRESSION)

$(OBJDIR)/disasm.a: $(OBJS_DISASM)
	$(AR) cr $(OBJDIR)/disasm.a $(OBJS_DISASM)

$(OBJDIR)/encryption.a: $(OBJS_ENCRYPTION)
	$(AR) cr $(OBJDIR)/encryption.a $(OBJS_ENCRYPTION)

$(OBJDIR)/extra.a: $(OBJS_EXTRA)
	$(AR) cr $(OBJDIR)/extra.a $(OBJS_EXTRA)

$(OBJDIR)/libs.a: $(OBJS_LIBS)
	$(AR) cr $(OBJDIR)/libs.a $(OBJS_LIBS)

$(OBJDIR)/bms.a: $(OBJS_BMS)
	$(AR) cr $(OBJDIR)/bms.a $(OBJS_BMS)

$(BINDIR)/$(EXE): $(STATIC_ALL)
	$(LD) -o $(BINDIR)/$(EXE) $(LDFLAGS) $(STATIC_ALL)

$(BINDIR) $(OBJDIR):
	mkdir -p $@
