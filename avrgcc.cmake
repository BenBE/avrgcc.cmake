set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(AVRGCC_DEFAULT_PROGRAMMER atmelice_isp)

set(AVRGCC_DEFAULT_MCU atmega328pb) # "MCU target chip to compile for")
set(AVRGCC_DEFAULT_FCPU 8000000) # "MCU clock frequency in Hz")
set(AVRGCC_DEFAULT_BAUD 115200) # "Connection baud rate in Baud")

# program names
set(AVRCPP   avr-g++)
set(AVRC     avr-gcc)
set(AVRSTRIP avr-strip)
set(OBJCOPY  avr-objcopy)
set(OBJDUMP  avr-objdump)
set(AVRSIZE  avr-size)
set(AVRDUDE  avrdude)

# Sets the compiler
# Needs to come before the project function
set(CMAKE_SYSTEM_NAME  Generic)
set(CMAKE_CXX_COMPILER ${AVRCPP})
set(CMAKE_C_COMPILER   ${AVRC})
set(CMAKE_ASM_COMPILER ${AVRC})

set(CDEBUG "-gstabs -g -ggdb") # "Compiler options for debugging"
set(CWARN "-Wall -Wextra -Werror -Wstrict-prototypes -Wl,--gc-sections -Wl,--relax") # "Compiler options for warnings"
set(CTUNING "-funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums -ffunction-sections -fdata-sections -fmerge-constants -fmerge-all-constants") # "Compilter options for tuning"
set(COPT "-Os") #"Compiler options for optimization"

set(CFLAGS   "${CDEBUG} ${COPT} ${CWARN} ${CSTANDARD} ${CTUNING}")
set(CXXFLAGS "${CDEBUG} ${COPT} ${CTUNING}")

set(CMAKE_C_FLAGS "${CFLAGS}")
set(CMAKE_CXX_FLAGS "${CXXFLAGS}")
set(CMAKE_ASM_FLAGS "${CFLAGS}")

add_custom_target(flash         true DEPENDS hex)

function(avrgcc_target)
    set(ONE_VAL_ARGS
        AVR_TARGET
        FLASH_TARGET

        SOURCE_DIR
        INCLUDE_DIR

        MCU
        FCPU
        BAUD
        PROGRAMMER

        IMAGE_BASE
    )
    cmake_parse_arguments(AVRGCC "" "${ONE_VAL_ARGS}" "" ${ARGN})

    if("${AVRGCC_AVR_TARGET}" STREQUAL "")
        set(AVRGCC_AVR_TARGET ${ARGV0})
    endif()

    if("${AVRGCC_FLASH_TARGET}" STREQUAL "")
        set(AVRGCC_FLASH_TARGET flash_${AVRGCC_AVR_TARGET})
    endif()

    if("${AVRGCC_IMAGE_BASE}" STREQUAL "")
        set(AVRGCC_IMAGE_BASE 0x0000)
    endif()

    if("${AVRGCC_PROGRAMMER}" STREQUAL "")
        set(AVRGCC_PROGRAMMER ${AVRGCC_DEFAULT_PROGRAMMER})
    endif()

    if("${AVRGCC_MCU}" STREQUAL "")
        set(AVRGCC_MCU ${AVRGCC_DEFAULT_MCU})
    endif()

    if("${AVRGCC_FCPU}" STREQUAL "")
        set(AVRGCC_FCPU ${AVRGCC_DEFAULT_FCPU})
    endif()

    if("${AVRGCC_BAUD}" STREQUAL "")
        set(AVRGCC_BAUD ${AVRGCC_DEFAULT_BAUD})
    endif()

    # Project setup
    target_compile_options(${AVRGCC_AVR_TARGET} PUBLIC -mmcu=${AVRGCC_MCU})
    target_compile_options(${AVRGCC_AVR_TARGET} PUBLIC -DF_CPU=${AVRGCC_FCPU})
    target_compile_options(${AVRGCC_AVR_TARGET} PUBLIC -DBAUD=${AVRGCC_BAUD})

    # Manage image base address
    target_compile_options(${AVRGCC_AVR_TARGET} PUBLIC -DBOOT_TEXT_START=${AVRGCC_IMAGE_BASE})
    target_link_options(${AVRGCC_AVR_TARGET} PUBLIC -mmcu=${AVRGCC_MCU})
    target_link_options(${AVRGCC_AVR_TARGET} PRIVATE -Ttext=${AVRGCC_IMAGE_BASE})
    target_link_options(${AVRGCC_AVR_TARGET} PRIVATE -Wl,-Map=${AVRGCC_AVR_TARGET}.map,--cref)

    # Link Time Optimization
    target_compile_options(${AVRGCC_AVR_TARGET} PUBLIC -flto)
    target_link_options(${AVRGCC_AVR_TARGET} PUBLIC -flto)

    set_property(TARGET ${AVRGCC_AVR_TARGET} PROPERTY OUTPUT_NAME "${AVRGCC_AVR_TARGET}.elf")
    set_property(TARGET ${AVRGCC_AVR_TARGET} PROPERTY ADDITIONAL_CLEAN_FILES
        "${PROJ_NAME}.map"
    )

    add_custom_command(TARGET ${AVRGCC_AVR_TARGET} POST_BUILD
        COMMAND "${OBJDUMP}" -S "${AVRGCC_AVR_TARGET}.elf" > "${AVRGCC_AVR_TARGET}.lst"
        BYPRODUCTS "${AVRGCC_AVR_TARGET}.lst"
        COMMENT "Generating ${AVRGCC_AVR_TARGET}.lst"
    )
    add_custom_command(TARGET ${AVRGCC_AVR_TARGET} POST_BUILD
        COMMAND "${OBJCOPY}" -R .eeprom -O ihex "${AVRGCC_AVR_TARGET}.elf" "${AVRGCC_AVR_TARGET}.hex"
        BYPRODUCTS "${AVRGCC_AVR_TARGET}.hex"
        COMMENT "Generating ${AVRGCC_AVR_TARGET}.hex"
    )
    add_custom_command(TARGET ${AVRGCC_AVR_TARGET} POST_BUILD
        COMMAND "${OBJCOPY}" -R .eeprom -R .fuse -O binary "${AVRGCC_AVR_TARGET}.elf" "${AVRGCC_AVR_TARGET}.bin"
        BYPRODUCTS "${AVRGCC_AVR_TARGET}.bin"
        COMMENT "Generating ${AVRGCC_AVR_TARGET}.bin"
    )
    add_custom_command(TARGET ${AVRGCC_AVR_TARGET} POST_BUILD
        COMMAND "${OBJCOPY}" -j .eeprom --change-section-lma .eeprom=0 -O ihex "${AVRGCC_AVR_TARGET}.elf" "${AVRGCC_AVR_TARGET}.eeprom"
        BYPRODUCTS "${AVRGCC_AVR_TARGET}.eeprom"
        COMMENT "Generating ${AVRGCC_AVR_TARGET}.eeprom"
    )
    add_custom_command(TARGET ${AVRGCC_AVR_TARGET} POST_BUILD
        COMMAND "${AVRSTRIP}" -o "${AVRGCC_AVR_TARGET}.stripped.elf" "${AVRGCC_AVR_TARGET}.elf"
        BYPRODUCTS "${AVRGCC_AVR_TARGET}.stripped.elf"
        COMMENT "Stripping ${AVRGCC_AVR_TARGET}.elf"
    )
    add_custom_command(TARGET ${AVRGCC_AVR_TARGET} POST_BUILD
        COMMAND "${AVRSIZE}"
        "${AVRGCC_AVR_TARGET}.elf"
    )

    # Compiler flags
    set_property(TARGET ${AVRGCC_AVR_TARGET} PROPERTY C_STANDARD 11)
    set_property(TARGET ${AVRGCC_AVR_TARGET} PROPERTY C_STANDARD_REQUIRED 11)
    set_property(TARGET ${AVRGCC_AVR_TARGET} PROPERTY C_EXTENSIONS OFF)

    # Compiling targets
    add_custom_target(${AVRGCC_FLASH_TARGET}
        ${AVRDUDE} -c ${AVRGCC_PROGRAMMER} -p ${AVRGCC_MCU} -U flash:w:${AVRGCC_AVR_TARGET}.hex
        DEPENDS ${AVRGCC_HEX_TARGET}
        COMMENT "Flashing ${AVRGCC_AVR_TARGET}"
    )

    # Register dependencies globally
    add_dependencies(flash ${AVRGCC_FLASH_TARGET})

    # Proper build cleanup
    set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES "${AVRGCC_AVR_TARGET}.hex;${AVRGCC_AVR_TARGET}.eeprom;${AVRGCC_AVR_TARGET}.lst")
endfunction()
