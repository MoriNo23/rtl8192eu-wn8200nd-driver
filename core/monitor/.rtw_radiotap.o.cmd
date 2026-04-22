savedcmd_/home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.o :=  x86_64-linux-gnu-gcc-14 -Wp,-MMD,/home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/.rtw_radiotap.o.d -nostdinc -I/usr/src/linux-headers-6.12.74+deb13+1-common/arch/x86/include -I./arch/x86/include/generated -I/usr/src/linux-headers-6.12.74+deb13+1-common/include -I./include -I/usr/src/linux-headers-6.12.74+deb13+1-common/arch/x86/include/uapi -I./arch/x86/include/generated/uapi -I/usr/src/linux-headers-6.12.74+deb13+1-common/include/uapi -I./include/generated/uapi -include /usr/src/linux-headers-6.12.74+deb13+1-common/include/linux/compiler-version.h -include /usr/src/linux-headers-6.12.74+deb13+1-common/include/linux/kconfig.h -include /usr/src/linux-headers-6.12.74+deb13+1-common/include/linux/compiler_types.h -D__KERNEL__ -fmacro-prefix-map=/usr/src/linux-headers-6.12.74+deb13+1-common/= -std=gnu11 -fshort-wchar -funsigned-char -fno-common -fno-PIE -fno-strict-aliasing -mno-sse -mno-mmx -mno-sse2 -mno-3dnow -mno-avx -fcf-protection=branch -fno-jump-tables -m64 -falign-jumps=1 -falign-loops=1 -mno-80387 -mno-fp-ret-in-387 -mpreferred-stack-boundary=3 -mskip-rax-setup -mtune=generic -mno-red-zone -mcmodel=kernel -Wno-sign-compare -fno-asynchronous-unwind-tables -mindirect-branch=thunk-extern -mindirect-branch-register -mindirect-branch-cs-prefix -mfunction-return=thunk-extern -fno-jump-tables -mharden-sls=all -fpatchable-function-entry=16,16 -fno-delete-null-pointer-checks -O2 -fno-allow-store-data-races -fstack-protector-strong -ftrivial-auto-var-init=zero -fno-stack-clash-protection -pg -mrecord-mcount -mfentry -DCC_USING_FENTRY -fmin-function-alignment=16 -fstrict-flex-arrays=3 -fno-strict-overflow -fno-stack-check -fconserve-stack -fno-builtin-wcslen -fno-builtin-wcslen -Wall -Wextra -Wundef -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Werror=strict-prototypes -Wno-format-security -Wno-trigraphs -Wno-frame-address -Wno-address-of-packed-member -Wmissing-declarations -Wmissing-prototypes -Wframe-larger-than=2048 -Wno-main -Wno-dangling-pointer -Wvla -Wno-pointer-sign -Wcast-function-type -Wno-array-bounds -Wno-stringop-overflow -Wno-alloc-size-larger-than -Wimplicit-fallthrough=5 -Werror=date-time -Werror=incompatible-pointer-types -Werror=designated-init -Wenum-conversion -Wunused -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-packed-not-aligned -Wno-format-overflow -Wno-format-truncation -Wno-stringop-truncation -Wno-override-init -Wno-missing-field-initializers -Wno-type-limits -Wno-shift-negative-value -Wno-maybe-uninitialized -Wno-sign-compare -Wno-unused-parameter -g -O1 -Wno-error=date-time -Wno-unused-variable -Wno-unused-function -Wno-date-time -I/home/fullmetal/InstalarDriver/rtl8192eu-linux/include -I/home/fullmetal/InstalarDriver/rtl8192eu-linux/platform -I/home/fullmetal/InstalarDriver/rtl8192eu-linux/hal/btc -I/home/fullmetal/InstalarDriver/rtl8192eu-linux/hal/phydm -DCONFIG_RTL8192E -DCONFIG_TRAFFIC_PROTECT -DCONFIG_LOAD_PHY_PARA_FROM_FILE -DREALTEK_CONFIG_PATH=\"/lib/firmware/\" -DCONFIG_TXPWR_BY_RATE=1 -DCONFIG_TXPWR_BY_RATE_EN=0 -DCONFIG_TXPWR_LIMIT=0 -DCONFIG_TXPWR_LIMIT_EN=0 -DCONFIG_RTW_CHPLAN=0x34 -DCONFIG_RTW_ADAPTIVITY_EN=1 -DCONFIG_RTW_ADAPTIVITY_MODE=1 -DCONFIG_SIGNAL_SCALE_MAPPING -DCONFIG_IEEE80211W -DHIGH_ACTIVE_HST2DEV=0 -DCONFIG_REDUCE_TX_CPU_LOADING -DCONFIG_BR_EXT '-DCONFIG_BR_EXT_BRNAME="'br0'"' -DCONFIG_RTW_NAPI -DCONFIG_RTW_NETIF_SG -DCONFIG_ICMP_VOQ -DCONFIG_RTW_UP_MAPPING_RULE=0 -DDM_ODM_SUPPORT_TYPE=0x04 -DCONFIG_LITTLE_ENDIAN -DCONFIG_IOCTL_CFG80211 -DRTW_USE_CFG80211_STA_EVENT -I/home/fullmetal/InstalarDriver/rtl8192eu-linux/core/crypto -I/home/fullmetal/InstalarDriver/rtl8192eu-linux/hal/phydm  -DMODULE  -DKBUILD_BASENAME='"rtw_radiotap"' -DKBUILD_MODNAME='"8192eu"' -D__KBUILD_MODNAME=kmod_8192eu -c -o /home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.o /home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.c  

source_/home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.o := /home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.c

deps_/home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.o := \
    $(wildcard include/config/WIFI_MONITOR) \
  /usr/src/linux-headers-6.12.74+deb13+1-common/include/linux/compiler-version.h \
    $(wildcard include/config/CC_VERSION_TEXT) \
  /usr/src/linux-headers-6.12.74+deb13+1-common/include/linux/kconfig.h \
    $(wildcard include/config/CPU_BIG_ENDIAN) \
    $(wildcard include/config/BOOGER) \
    $(wildcard include/config/FOO) \
  /usr/src/linux-headers-6.12.74+deb13+1-common/include/linux/compiler_types.h \
    $(wildcard include/config/DEBUG_INFO_BTF) \
    $(wildcard include/config/PAHOLE_HAS_BTF_TAG) \
    $(wildcard include/config/FUNCTION_ALIGNMENT) \
    $(wildcard include/config/CC_HAS_SANE_FUNCTION_ALIGNMENT) \
    $(wildcard include/config/X86_64) \
    $(wildcard include/config/ARM64) \
    $(wildcard include/config/LD_DEAD_CODE_DATA_ELIMINATION) \
    $(wildcard include/config/LTO_CLANG) \
    $(wildcard include/config/HAVE_ARCH_COMPILER_H) \
    $(wildcard include/config/CC_HAS_COUNTED_BY) \
    $(wildcard include/config/UBSAN_SIGNED_WRAP) \
    $(wildcard include/config/CC_HAS_ASM_INLINE) \
  /usr/src/linux-headers-6.12.74+deb13+1-common/include/linux/compiler_attributes.h \
  /usr/src/linux-headers-6.12.74+deb13+1-common/include/linux/compiler-gcc.h \
    $(wildcard include/config/MITIGATION_RETPOLINE) \
    $(wildcard include/config/ARCH_USE_BUILTIN_BSWAP) \
    $(wildcard include/config/SHADOW_CALL_STACK) \
    $(wildcard include/config/KCOV) \

/home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.o: $(deps_/home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.o)

$(deps_/home/fullmetal/InstalarDriver/rtl8192eu-linux/core/monitor/rtw_radiotap.o):
