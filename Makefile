#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/3ds_rules


#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# DATA is a list of directories containing data files
# INCLUDES is a list of directories containing header files
# GRAPHICS is a list of directories containing graphics files
# GFXBUILD is the directory where converted graphics files will be placed
#   If set to $(BUILD), it will statically link in the converted
#   files as if they were data files.
#
# NO_SMDH: if set to anything, no SMDH file is generated.
# ROMFS is the directory which contains the RomFS, relative to the Makefile (Optional)
# APP_TITLE is the name of the app stored in the SMDH file (Optional)
# APP_DESCRIPTION is the description of the app stored in the SMDH file (Optional)
# APP_AUTHOR is the author of the app stored in the SMDH file (Optional)
# ICON is the filename of the icon (.png), relative to the project folder.
#   If not set, it attempts to use one of the following (in this order):
#     - <Project name>.png
#     - icon.png
#     - <libctru folder>/default_icon.png
#---------------------------------------------------------------------------------
TARGET		:=	3hs
BUILD			:=	build
SOURCES		:= 	source source/ui source/widgets source/hlink 3rd/nnc/source
DATA			:=	data
INCLUDES	:=	include 3rd 3rd/3rd .
GRAPHICS	:=	gfx gfx/bun
ROMFS			:=	romfs
GFXBUILD	:=	$(ROMFS)/gfx

CIA_PREFIX			:=	cia_stuff
ICON						:=	$(CIA_PREFIX)/icon.png
APP_TITLE				:=	3hs
APP_DESCRIPTION	:=	An on-device client for hShop
APP_AUTHOR			:=	hShop

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
ARCH	:=	-march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CFLAGS	:= -pedantic -Wall -Wextra -mword-relocations \
			-fcompare-debug-second -ffunction-sections $(ARCH) \

CFLAGS	+=	$(INCLUDE) -DARM11 -D__3DS__ -D_3DS

ASFLAGS	:=	$(ARCH)
LDFLAGS	=	-specs=3dsx.specs $(ARCH) -Wl,-Map,$(notdir $*.map)

ifneq ($(RELEASE),)
	CFLAGS	+= -DRELEASE -O2
else
	CFLAGS  += -ggdb3
endif

ifneq ($(HS_DEBUG_SERVER),)
	CFLAGS	+=	-DHS_DEBUG_SERVER=\"$(HS_DEBUG_SERVER)\"
endif

ifneq ($(HS_UPDATE_BASE),)
	CFLAGS	+=	-DHS_UPDATE_BASE=\"$(HS_UPDATE_BASE)\"
endif

ifneq ($(HS_BASE_LOC),)
	CFLAGS	+=	-DHS_BASE_LOC=\"$(HS_BASE_LOC)\"
endif

ifneq ($(HS_CDN_BASE),)
	CFLAGS	+=	-DHS_CDN_BASE=\"$(HS_CDN_BASE)\"
endif

ifneq ($(HS_SITE_LOC),)
	CFLAGS	+=	-DHS_SITE_LOC=\"$(HS_SITE_LOC)\"
endif

ifneq ($(DEVICE_ID),)
	CFLAGS	+=	"-DDEVICE_ID=$(DEVICE_ID)"
endif

ifeq ($(VERSION),)
	VERSION	=	0
endif

CXXFLAGS	:= $(CFLAGS) -fno-rtti -fno-exceptions -std=gnu++14

LIBS	:= -lmbedcrypto -lcitro2d -lcitro3d -lctru -lm

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS	:= $(PORTLIBS) $(CTRULIB)

#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT	:=	$(CURDIR)/$(TARGET)
export TOPDIR	:=	$(CURDIR)

export VPATH	:=	$(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
			$(foreach dir,$(GRAPHICS),$(CURDIR)/$(dir)) \
			$(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR	:=	$(CURDIR)/$(BUILD)

CFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cc)))
SFILES		:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
PICAFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.v.pica)))
SHLISTFILES	:=	$(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.shlist)))
FONTFILES	:=	$(foreach dir,$(GRAPHICS),$(notdir $(wildcard $(dir)/*.ttf)))
GFXFILES	:=	$(foreach dir,$(GRAPHICS),$(notdir $(wildcard $(dir)/*.t3s)))
BINFILES	:=	$(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))
ROMFS_FILES := $(shell find $(ROMFS))

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
#---------------------------------------------------------------------------------
	export LD	:=	$(CC)
#---------------------------------------------------------------------------------
else
#---------------------------------------------------------------------------------
	export LD	:=	$(CXX)
#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
ifeq ($(GFXBUILD),$(BUILD))
#---------------------------------------------------------------------------------
export T3XFILES :=  $(GFXFILES:.t3s=.t3x)
#---------------------------------------------------------------------------------
else
#---------------------------------------------------------------------------------
export ROMFS_FONTFILES  :=      $(patsubst %.ttf, $(GFXBUILD)/%.bcfnt, $(FONTFILES))
export ROMFS_T3XFILES	:=	$(patsubst %.t3s, $(GFXBUILD)/%.t3x, $(GFXFILES))
export T3XHFILES		:=	$(patsubst %.t3s, $(BUILD)/%.h, $(GFXFILES))
#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------

export OFILES_SOURCES 	:=	$(CPPFILES:.cc=.o) $(CFILES:.c=.o) $(SFILES:.s=.o)

export OFILES_BIN	:=	$(addsuffix .o,$(BINFILES)) \
			$(PICAFILES:.v.pica=.shbin.o) $(SHLISTFILES:.shlist=.shbin.o) \
			$(addsuffix .o,$(T3XFILES))

export OFILES := $(OFILES_BIN) $(OFILES_SOURCES) hscert.o

export HFILES	:=	$(PICAFILES:.v.pica=_shbin.h) $(SHLISTFILES:.shlist=_shbin.h) \
			$(addsuffix .h,$(subst .,_,$(BINFILES))) \
			$(GFXFILES:.t3s=.h)

# We use isystem here because
# citro3d has a **fuckton**
# Of warnings because pedantic
export INCLUDE	:=	$(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
			$(foreach dir,$(LIBDIRS),-isystem$(dir)/include) \
			-I$(CURDIR)/$(BUILD)

export LIBPATHS	:=	$(foreach dir,$(LIBDIRS),-L$(dir)/lib)

export _3DSXDEPS	:=	$(if $(NO_SMDH),,$(OUTPUT).smdh)

ifeq ($(strip $(ICON)),)
	icons := $(wildcard *.png)
	ifneq (,$(findstring $(TARGET).png,$(icons)))
		export APP_ICON := $(TOPDIR)/$(TARGET).png
	else
		ifneq (,$(findstring icon.png,$(icons)))
			export APP_ICON := $(TOPDIR)/icon.png
		endif
	endif
else
	export APP_ICON := $(TOPDIR)/$(ICON)
endif

ifeq ($(strip $(NO_SMDH)),)
	export _3DSXFLAGS += --smdh=$(CURDIR)/$(TARGET).smdh
endif

ifneq ($(ROMFS),)
	export _3DSXFLAGS += --romfs=$(CURDIR)/$(ROMFS)
endif

.PHONY: all clean

INT_ALL 	:=	$(BUILD)/i18n_tab.cc $(BUILD) $(GFXBUILD) $(DEPSDIR) $(ROMFS_T3XFILES) $(ROMFS_FONTFILES) $(T3XHFILES)
REAL_ALL	:=	$(INT_ALL)
ifeq ($(RELEASE),)
	REAL_ALL	:=	$(REAL_ALL) _build_all
else
	REAL_ALL	:=	$(REAL_ALL) cia
endif

#---------------------------------------------------------------------------------
all: $(REAL_ALL)
_build_all:
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

$(BUILD)/romfs.bin: $(ROMFS_FILES)
	$(SILENTCMD) 3dstool -ctf romfs $(BUILD)/romfs.bin --romfs-dir romfs
	$(SILENTMSG) built ... romfs.bin

$(BUILD)/icon.smdh: $(CIA_PREFIX)/icon.png
	$(SILENTCMD) bannertool makesmdh -f visible,nosavebackups -i $(CIA_PREFIX)/icon.png -s "3hs" -l "3hs" -p "hShop" -o $(BUILD)/icon.smdh >/dev/null
	$(SILENTMSG) built ... icon.smdh

$(BUILD)/banner.bnr: $(CIA_PREFIX)/banner.cgfx $(CIA_PREFIX)/audio.cwav
	$(SILENTCMD) bannertool makebanner -ca $(CIA_PREFIX)/audio.cwav -ci $(CIA_PREFIX)/banner.cgfx -o $(BUILD)/banner.bnr >/dev/null
	$(SILENTMSG) built ... banner.bnr

cia: $(INT_ALL) $(BUILD)/banner.bnr $(BUILD)/icon.smdh $(BUILD)/romfs.bin
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile
	$(SILENTCMD) makerom -f cia -o $(TARGET).cia -target t -elf $(TARGET).elf -icon $(BUILD)/icon.smdh -banner $(BUILD)/banner.bnr -rsf $(CIA_PREFIX)/$(TARGET).rsf -romfs $(BUILD)/romfs.bin -ver $(VERSION)
	$(SILENTMSG) built ... $(TARGET).cia

$(BUILD)/i18n_tab.cc: $(shell find $(TOPDIR)/lang/ -not -name '*.pl' -type f)
	$(SILENTCMD) mkdir -p $(BUILD)
	$(SILENTCMD) cd $(TOPDIR); ./lang/make.pl
	$(SILENTMSG) generated ... i18n_tab.cc
	$(SILENTMSG) generated ... i18n_tab.hh

$(BUILD):
	@mkdir -p $@

ifneq ($(GFXBUILD),$(BUILD))
$(GFXBUILD):
	@mkdir -p $@
endif

ifneq ($(DEPSDIR),$(BUILD))
$(DEPSDIR):
	@mkdir -p $@
endif

#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).3dsx $(OUTPUT).smdh $(TARGET).elf $(GFXBUILD) $(OUTPUT).cia $(BUILD)/romfs.bin $(BUILD)/banner.bnr $(BUILD)/icon.smdh

#---------------------------------------------------------------------------------
$(GFXBUILD)/%.t3x	$(BUILD)/%.h	:	%.t3s
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@tex3ds -i $< -H $(BUILD)/$*.h -d $(DEPSDIR)/$*.d -o $(GFXBUILD)/$*.t3x


#---------------------------------------------------------------------------------
$(GFXBUILD)/%.bcfnt :           %.ttf
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@mkbcfnt -o $(GFXBUILD)/$*.bcfnt $<

#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
else

#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
$(OUTPUT).3dsx	:	$(OUTPUT).elf $(_3DSXDEPS)

$(OFILES_SOURCES) : $(HFILES)

$(OUTPUT).elf	:	$(OFILES)

#---------------------------------------------------------------------------------
# you need a rule like this for each extension you use as binary data
#---------------------------------------------------------------------------------
%.bin.o	%_bin.h :	%.bin
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

#---------------------------------------------------------------------------------
.PRECIOUS	:	%.t3x
#---------------------------------------------------------------------------------
%.t3x.o	%_t3x.h :	%.t3x
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

#---------------------------------------------------------------------------------
# rules for assembling GPU shaders
#---------------------------------------------------------------------------------
define shader-as
	$(eval CURBIN := $*.shbin)
	$(eval DEPSFILE := $(DEPSDIR)/$*.shbin.d)
	echo "$(CURBIN).o: $< $1" > $(DEPSFILE)
	echo "extern const u8" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`"_end[];" > `(echo $(CURBIN) | tr . _)`.h
	echo "extern const u8" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`"[];" >> `(echo $(CURBIN) | tr . _)`.h
	echo "extern const u32" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`_size";" >> `(echo $(CURBIN) | tr . _)`.h
	picasso -o $(CURBIN) $1
	bin2s $(CURBIN) | $(AS) -o $*.shbin.o
endef

%.shbin.o %_shbin.h : %.v.pica %.g.pica
	@echo $(notdir $^)
	@$(call shader-as,$^)

%.shbin.o %_shbin.h : %.v.pica
	@echo $(notdir $<)
	@$(call shader-as,$<)

%.shbin.o %_shbin.h : %.shlist
	@echo $(notdir $<)
	@$(call shader-as,$(foreach file,$(shell cat $<),$(dir $<)$(file)))

%.o: %.cc
	$(SILENTMSG) $(notdir $<)
	$(SILENTCMD)$(CXX) -MMD -MP -MF $(DEPSDIR)/$*.d $(CXXFLAGS) -c $< -o $@ $(ERROR_FILTER)

ifneq ($(wildcard ../hscert.der),)
# If hscert.der exists we use that ...
hscert.o: ../hscert.der
	$(SILENTCMD) cd $(TOPDIR); xxd -i hscert.der > $(BUILD)/hscert.c
	$(SILENTMSG) generated ... hscert.c
	$(SILENTCMD)$(CXX) -MMD -MP -MF $(DEPSDIR)/$*.d $(CXXFLAGS) -c hscert.c -o hscert.o $(ERROR_FILTER)
	$(SILENTMSG) hscert.o
else
# ... else we install a dummy
hscert.o:
	$(SILENTCMD) echo 'unsigned int hscert_der_len = 0; unsigned char hscert_der[] = { 0x00 };' > hscert.c
	$(SILENTMSG) stubbed ... hscert.c
	$(SILENTCMD)$(CXX) -MMD -MP -MF $(DEPSDIR)/$*.d $(CXXFLAGS) -c hscert.c -o hscert.o $(ERROR_FILTER)
	$(SILENTMSG) hscert.o
endif
#---------------------------------------------------------------------------------
%.t3x	%.h	:	%.t3s
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@tex3ds -i $< -H $*.h -d $*.d -o $*.t3x

-include $(DEPSDIR)/*.d

#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------
